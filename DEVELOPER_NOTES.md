# Developer Notes

## 1. Create local environment

1. Copy `/home/runner/work/agentos-modal-vm/agentos-modal-vm/example.env` to `/home/runner/work/agentos-modal-vm/agentos-modal-vm/.env`.
2. Keep `RUNTIME_ENV=dev` for local Docker validation.
3. Set `OPENAI_API_KEY` and any optional provider metadata you want to track.
4. Before any public deployment, switch `RUNTIME_ENV` to `prd` and add either `JWT_VERIFICATION_KEY` or `JWT_JWKS_FILE`.

## 2. Run the local Docker stack

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
docker compose up -d --build
```

- API: `http://127.0.0.1:8000`
- MCP: `http://127.0.0.1:8000/mcp`
- Docs: `http://127.0.0.1:8000/docs`

## 3. Run the MCP end-to-end smoke check

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
./scripts/mcp_check.sh
```

Optional custom probe:

```bash
./scripts/mcp_check.sh "What does this platform expose over MCP?"
```

## 4. Modal deployment pipeline

### First deploy / provisioning

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
./scripts/modal/up.sh
```

What it does:

1. Loads `.env.production` when present, otherwise `.env`.
2. Reuses an existing external Postgres/pgvector config or provisions a Neon project.
3. Writes the `agentos-secrets` Modal secret.
4. Deploys `modal_app.py` with an always-warm single-container boundary (`min_containers=1`, `max_containers=1`).
5. Pins `AGENTOS_URL`, generates `MCP_CONNECT_SECRET` when missing, and prompts for production JWT verification if needed.
6. Performs a second deploy so the final secret set is live.

### Sync environment changes

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
./scripts/modal/env-sync.sh
```

Use `./scripts/modal/env-sync.sh .env` if you intentionally want to sync the local env file instead of `.env.production`.

### Rolling redeploy

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
./scripts/modal/redeploy.sh
```

### Teardown

```bash
cd /home/runner/work/agentos-modal-vm/agentos-modal-vm
./scripts/modal/down.sh
```

## 5. Production checklist

- Keep `RUNTIME_ENV=prd` in the synced production env.
- Provide `JWT_VERIFICATION_KEY` or `JWT_JWKS_FILE`.
- Keep `PGSSLMODE=require` for Neon unless your external database provider documents a different TLS mode.
- Confirm the public Modal URL responds before connecting MCP clients.
