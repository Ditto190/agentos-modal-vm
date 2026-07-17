#!/bin/bash

############################################################################
#
#    Agno Modal Environment Sync
#
#    Usage:
#      ./scripts/modal/env-sync.sh             # syncs .env.production
#      ./scripts/modal/env-sync.sh .env        # syncs .env instead
#
#    Rewrites the agentos-secrets Modal secret from the env file (every
#    non-NEON_* key, plus a default PGSSLMODE=require for Neon TLS when the
#    env file doesn't set one) and redeploys —
#    secrets are read at container start, so the redeploy is what applies
#    them. Multi-line values (PEM-formatted JWT_VERIFICATION_KEY) are
#    handled correctly.
#
############################################################################

set -e

CURR_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${CURR_DIR}/common.sh"

# Colors
ORANGE='\033[38;5;208m'
DIM='\033[2m'
BOLD='\033[1m'
NC='\033[0m'

ENV_FILE="${1:-.env.production}"

confirm_dev_runtime_for_modal() {
    if [[ "${RUNTIME_ENV:-prd}" != "dev" ]]; then
        return
    fi
    echo ""
    echo -e "${ORANGE}▸${NC} ${BOLD}RUNTIME_ENV=dev${NC} — JWT auth is disabled in this mode."
    echo -e "${DIM}Use .env.production with RUNTIME_ENV=prd for a public deployment.${NC}"
    if [[ ! -t 0 ]]; then
        echo "Refusing non-interactive Modal secret sync with RUNTIME_ENV=dev."
        echo "Set RUNTIME_ENV=prd (recommended) or rerun interactively to confirm a dev-only sync."
        exit 1
    fi
    printf "Continue syncing an unauthenticated dev config to Modal? [y/N] "
    IFS= read -r CONFIRM_DEV
    if [[ ! "$CONFIRM_DEV" =~ ^[Yy]$ ]]; then
        echo "Aborted. Update your env file to RUNTIME_ENV=prd before syncing public secrets."
        exit 1
    fi
}

if [[ ! -f "$ENV_FILE" ]]; then
    echo "File not found: $ENV_FILE"
    echo "Usage: $0 [path/to/env] (default: .env.production)"
    exit 1
fi
if ! command -v modal &> /dev/null; then
    echo "modal CLI not found. Install: pip install modal   (then: modal token new)"
    exit 1
fi

echo ""
echo -e "${ORANGE}▸${NC} ${BOLD}Syncing env vars${NC}"
echo ""
echo -e "${DIM}> ${ENV_FILE} -> Modal secret agentos-secrets${NC}"
echo ""

# Parse the env file, treating PEM blocks (and other multiline values) as a
# single variable.
SECRET_ARGS=()
count=0
current_key=""
current_value=""
pgsslmode_set=""

while IFS= read -r line || [[ -n "$line" ]]; do
    if [[ -z "$current_key" ]]; then
        [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
    fi

    if [[ -z "$current_key" ]]; then
        current_key="${line%%=*}"
        current_value="${line#*=}"
    else
        current_value="${current_value}
${line}"
    fi

    if [[ "$current_value" == *"-----BEGIN"* && "$current_value" != *"-----END"* ]]; then
        continue
    fi

    current_value="${current_value#\"}"
    current_value="${current_value%\"}"
    current_value="${current_value#\'}"
    current_value="${current_value%\'}"

    case "$current_key" in
        NEON_*)
            # Provisioning config for the scripts, not app environment.
            ;;
        *)
            if [[ "$current_key" == "PGSSLMODE" ]]; then
                validate_pgsslmode "$current_value" "scripts/modal/env-sync.sh"
                pgsslmode_set=1
            fi
            if [[ "$current_key" == "RUNTIME_ENV" ]]; then
                RUNTIME_ENV="$current_value"
            fi
            echo -e "${DIM}  Setting ${current_key}${NC}"
            SECRET_ARGS+=("${current_key}=${current_value}")
            count=$((count + 1))
            ;;
    esac

    current_key=""
    current_value=""
done < "$ENV_FILE"

if [[ "$count" -eq 0 ]]; then
    echo "Nothing to sync from ${ENV_FILE}."
    exit 1
fi

confirm_dev_runtime_for_modal

# Neon requires TLS; libpq honors PGSSLMODE so the portable core needs no change.
if [[ -z "$pgsslmode_set" ]]; then
    SECRET_ARGS+=("PGSSLMODE=require")
fi

modal secret create --force agentos-secrets "${SECRET_ARGS[@]}" > /dev/null

echo ""
echo -e "${ORANGE}▸${NC} ${BOLD}Redeploying so the running container picks the secret up${NC}"
echo -e "${DIM}> modal deploy modal_app.py::modal_app${NC}"
modal deploy modal_app.py::modal_app > /dev/null

echo ""
echo -e "${BOLD}Done.${NC} Synced ${count} variable(s)."
echo ""
