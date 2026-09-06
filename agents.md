# Agents Notes

- The lab workflow assumes all demo resource groups are tagged with `managedBy=test-azure-lab`.
- Cleanup uses the RG tag `cleanupAfter` in UTC ISO 8601 format and deletes due RGs every hour.
- `operation=deploy-example` also updates cleanup tags for all managed RGs so one scheduled cleanup pass can remove stale labs.
- `AZURE_ADMIN_SSH_PUBLIC_KEY` is read from repository variables (not secrets) and injected as the VM authorized key.
- Both examples are entrypoints that call `infra/modules/two-vm-network-lab.bicep`.
