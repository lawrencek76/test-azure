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

## GitHub configuration required (OIDC, no secret login)

This repo uses **Azure OIDC login** (`azure/login@v2`) instead of `AZURE_CREDENTIALS`.

Set these **repository variables** (the 3 values needed for no-secret Azure login):

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`

Also set these **repository variables**:

- `AZURE_ADMIN_SSH_PUBLIC_KEY`: SSH public key deployed to both VMs.
- `AZURE_TRUSTED_SSH_CIDR`: trusted source CIDR for SSH to lab VMs (for example `203.0.113.10/32`).
- `LAB_STACK_NAME` (optional, default `test-azure-lab-stack`): deployment stack name used to manage lab resource groups.
- `LAB_RG_PREFIX` (optional, default `azlearn-rg`): prefix used for lab resource groups.
- `LAB_RG_COUNT` (optional, default `3`): number of managed lab resource groups to maintain.

### Required Azure app setup for OIDC

Create an Entra app/service principal, grant it rights in the target subscription, and add a **Federated credential** for this GitHub repository/branch so Actions can exchange the GitHub OIDC token for Azure access.

## SSH key generation

Generate a key pair locally and set the public key text into `AZURE_ADMIN_SSH_PUBLIC_KEY`:

```bash
ssh-keygen -t ed25519 -C "test-azure-lab" -f ~/.ssh/test-azure-lab
cat ~/.ssh/test-azure-lab.pub
```

## Workflows

### 1) Deploy lab
Workflow: `.github/workflows/deploy-lab.yml`

Manual (`workflow_dispatch`) inputs:
- `operation`
  - `prepare-rgs`: create/update managed lab RGs via Bicep deployment stack and set cleanup tags
  - `deploy-example`: deploy one selected example to a managed RG
- `example` (used for deploy only):
  - `two-vms-separate-vnets`
  - `two-vms-shared-vnet`
- `location`: Azure region (default `eastus`)
  - Used when first creating managed RGs. Existing managed RGs keep their original region.
- `resource_group`: target managed lab RG (default `azlearn-rg-01`)

Deployments use per-example `.bicepparam` files:
- `examples/two-vms-separate-vnets/main.bicepparam`
- `examples/two-vms-shared-vnet/main.bicepparam`

### 2) Cleanup lab (daily)
Workflow: `.github/workflows/cleanup-lab.yml`

- Runs daily at **05:00 UTC** (early AM).
- Checks stack tag `cleanupAfter`.
- When due, deletes the deployment stack with `deleteAll`, which deletes all stack-managed lab resource groups.

### 3) Bicep validation CI
Workflow: `.github/workflows/bicep-validate.yml`

- Runs on pull requests and pushes to `main` when Bicep-related files change.
- Executes `bicep build` + `bicep lint` for all `.bicep` files.
- Executes `bicep build-params` + `bicep lint` for all `.bicepparam` files.

## Diagnostic exercise flow

1. Run **Deploy Azure Lab** with `operation=deploy-example` and choose an example.
2. SSH to `hosta` and `hostb` (public and private IPs are deployment outputs).
3. From `hosta`, test HTTP to `hostb` private IP on port 80 (`curl http://<hostb-private-ip>`).
4. Observe failure and use Azure portal tools (effective security rules, NSG flow logs, connection troubleshoot) to identify the deny rule.
