#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<USAGE
Usage: $0 <owner/repo>

Sets required GitHub Actions repository variables for this project.
Requires GitHub CLI (gh) authenticated with repo admin access.
USAGE
}

if [[ "${1:-}" == "" ]]; then
  usage
  exit 1
fi

repo="$1"

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Please run: gh auth login" >&2
  exit 1
fi

read -r -p "AZURE_SUBSCRIPTION_ID: " AZURE_SUBSCRIPTION_ID
read -r -p "AZURE_CLIENT_ID: " AZURE_CLIENT_ID
read -r -p "AZURE_TENANT_ID: " AZURE_TENANT_ID
read -r -p "AZURE_ADMIN_SSH_PUBLIC_KEY: " AZURE_ADMIN_SSH_PUBLIC_KEY
read -r -p "AZURE_TRUSTED_SSH_CIDR (example 2001:db8::1/128): " AZURE_TRUSTED_SSH_CIDR

read -r -p "LAB_STACK_NAME [test-azure-lab-stack]: " LAB_STACK_NAME
LAB_STACK_NAME="${LAB_STACK_NAME:-test-azure-lab-stack}"

read -r -p "LAB_RG_PREFIX [azlearn-rg]: " LAB_RG_PREFIX
LAB_RG_PREFIX="${LAB_RG_PREFIX:-azlearn-rg}"

read -r -p "LAB_RG_COUNT [3]: " LAB_RG_COUNT
LAB_RG_COUNT="${LAB_RG_COUNT:-3}"

set_var() {
  local key="$1"
  local value="$2"
  gh variable set "$key" --repo "$repo" --body "$value"
  echo "Set $key"
}

set_var AZURE_SUBSCRIPTION_ID "$AZURE_SUBSCRIPTION_ID"
set_var AZURE_CLIENT_ID "$AZURE_CLIENT_ID"
set_var AZURE_TENANT_ID "$AZURE_TENANT_ID"
set_var AZURE_ADMIN_SSH_PUBLIC_KEY "$AZURE_ADMIN_SSH_PUBLIC_KEY"
set_var AZURE_TRUSTED_SSH_CIDR "$AZURE_TRUSTED_SSH_CIDR"
set_var LAB_STACK_NAME "$LAB_STACK_NAME"
set_var LAB_RG_PREFIX "$LAB_RG_PREFIX"
set_var LAB_RG_COUNT "$LAB_RG_COUNT"

echo "Done."
