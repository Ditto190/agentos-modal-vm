#!/bin/bash

validate_pgsslmode() {
    case "$1" in
        disable|allow|prefer|require|verify-ca|verify-full) ;;
        *)
            local source_name="${2:-modal script}"
            echo "Error in ${source_name}: invalid PGSSLMODE: $1"
            echo "Expected one of: disable, allow, prefer, require, verify-ca, verify-full"
            exit 1
            ;;
    esac
}
