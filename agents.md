# Agents Notes

- The lab workflow assumes all demo resource groups are tagged with `managedBy=test-azure-lab`.
- Managed lab resource groups are created and maintained by `infra/stacks/lab-resource-groups.bicep` via `az stack sub create`.
- Cleanup checks deployment stack tag `cleanupAfter` and, when due, runs `az stack sub delete --action-on-unmanage deleteAll` to remove all managed lab RGs in one operation.
- `operation=prepare-rgs` and `operation=deploy-example` both refresh `cleanupAfter` to 24 hours in the future.
- `operation=deploy-example` expects `resource_group` to be one of the managed RG names generated from `LAB_RG_PREFIX` + `LAB_RG_COUNT`.
- `AZURE_ADMIN_SSH_PUBLIC_KEY` is read from repository variables (not secrets) and injected as the VM authorized key.
- `AZURE_TRUSTED_SSH_CIDR` is required and passed to examples to restrict SSH ingress.
- Azure auth for workflows uses OIDC (`AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID`) with `azure/login@v2`, not `AZURE_CREDENTIALS`.
- Example deployments now use `.bicepparam` files that read `AZURE_ADMIN_SSH_PUBLIC_KEY` and `AZURE_TRUSTED_SSH_CIDR` from environment variables.
- Cleanup scheduling is handled in a dedicated `.github/workflows/cleanup-lab.yml` workflow (daily 05:00 UTC), separate from deploy workflow.
- Both examples are entrypoints that call `infra/modules/two-vm-network-lab.bicep`.
