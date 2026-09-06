# Agents Notes

- The lab workflow assumes all demo resource groups are tagged with `managedBy=test-azure-lab`.
- Managed lab resource groups are created and maintained by `infra/stacks/lab-resource-groups.bicep` via `az stack sub create`.
- Cleanup checks deployment stack tag `cleanupAfter` and, when due, runs `az stack sub delete --action-on-unmanage deleteAll` to remove all managed lab RGs in one operation.
- `operation=prepare-rgs` and `operation=deploy-example` both refresh `cleanupAfter` to 24 hours in the future.
- `operation=deploy-example` expects `resource_group` to be one of the managed RG names generated from `LAB_RG_PREFIX` + `LAB_RG_COUNT`.
- `AZURE_ADMIN_SSH_PUBLIC_KEY` is read from repository variables (not secrets) and injected as the VM authorized key.
- `AZURE_TRUSTED_SSH_CIDR` is required and passed to examples to restrict SSH ingress.
- Both examples are entrypoints that call `infra/modules/two-vm-network-lab.bicep`.
