# test-azure

Azure learning repo with Bicep examples designed for experimentation, troubleshooting practice, and exam prep.

## What is in this repo

- **Example 1**: `examples/two-vms-separate-vnets`  
  Two tiny Spot Linux VMs, each in its own VNet, peered together. `hostb` has an NSG deny rule that blocks HTTP (port 80) from `hosta`.
- **Example 2**: `examples/two-vms-shared-vnet`  
  Same troubleshooting scenario, but both VMs are in one VNet with separate subnets.

Both examples use:
- Spot VM priority
- Eviction policy `Delete`
- `maxPrice = -1`
- Standard SSD OS disk
- Ubuntu 22.04 image with network troubleshooting tools (curl, dnsutils, iperf3, ping, traceroute, netcat)

## GitHub configuration required

Set the following **repository secret**:

- `AZURE_CREDENTIALS`: JSON for an Azure service principal with rights to create/delete resource groups and deploy resources in your subscription.

Set the following **repository variables**:

- `AZURE_ADMIN_SSH_PUBLIC_KEY`: SSH public key deployed to both VMs.
- `LAB_STACK_NAME` (optional, default `test-azure-lab-stack`): deployment stack name used to manage lab resource groups.
- `LAB_RG_PREFIX` (optional, default `azlearn-rg`): prefix used for lab resource groups.
- `LAB_RG_COUNT` (optional, default `3`): number of managed lab resource groups to maintain.

## Workflows

### 1) Deploy or cleanup lab
Workflow: `.github/workflows/deploy-lab.yml`

Manual (`workflow_dispatch`) inputs:
- `operation`
  - `prepare-rgs`: create/update managed lab RGs via Bicep deployment stack and set cleanup tags
  - `deploy-example`: deploy one selected example to a managed RG
  - `cleanup-now`: delete the deployment stack (and all managed lab RGs) when cleanup is due
- `example` (used for deploy only):
  - `two-vms-separate-vnets`
  - `two-vms-shared-vnet`
- `location`: Azure region (default `eastus`)
- `resource_group`: target managed lab RG (default `azlearn-rg-01`)

Automatic cleanup:
- The same workflow runs hourly on schedule.
- `prepare-rgs` and `deploy-example` both refresh stack and RG tags with `cleanupAfter = now + 24h`.
- Scheduled cleanup checks the stack cleanup timestamp.
- When due, cleanup deletes the deployment stack with `deleteAll`, which deletes all stack-managed lab resource groups.

### 2) Bicep validation CI
Workflow: `.github/workflows/bicep-validate.yml`

- Runs on pull requests and pushes to `main` when Bicep files change.
- Executes `bicep build` and `bicep lint` across all `.bicep` files to ensure syntax and lint validity.

## Diagnostic exercise flow

1. Run **Deploy or Cleanup Azure Lab** with `operation=deploy-example` and choose an example.
2. SSH to `hosta` and `hostb` (public and private IPs are deployment outputs).
3. From `hosta`, test HTTP to `hostb` private IP on port 80 (`curl http://<hostb-private-ip>`).
4. Observe failure and use Azure portal tools (effective security rules, NSG flow logs, connection troubleshoot) to identify the deny rule.
