#!/bin/bash

validate_pgsslmode() {
    case "$1" in
        disable|allow|prefer|require|verify-ca|verify-full) ;;
        *)
            echo "Invalid PGSSLMODE: $1"
            echo "Expected one of: disable, allow, prefer, require, verify-ca, verify-full"
            exit 1
            ;;
    esac
}
