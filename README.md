# test-azure

Azure learning repo with Bicep examples designed for experimentation, troubleshooting practice, and exam prep.

## What is in this repo

- **Example 1**: `examples/two-vms-separate-vnets`  
  Two tiny Spot Linux VMs, each in its own dual-stack VNet, peered together. `hostb` has an NSG deny rule that blocks HTTP (port 80) from `hosta`.
- **Example 2**: `examples/two-vms-shared-vnet`  
  Same troubleshooting scenario, but both VMs are in one dual-stack VNet with separate subnets.

Both examples use:
- Regular (on-demand) VM priority
- Standard SSD OS disk
- Ubuntu 22.04 image with network troubleshooting tools (curl, dnsutils, iperf3, ping, traceroute, netcat)
- Dual-stack (IPv4 + IPv6) VNets/subnets, because Azure NICs require a primary IPv4 configuration
- IPv6-only Standard public IP resources (free; IPv4 PIPs and NAT gateways would add hourly charges)
- Private subnets (`defaultOutboundAccess: false`) so VMs never rely on implicit default outbound access. Explicit internet egress is IPv6 via the NIC-attached PIP; IPv4 is VNet/peering-local only. Redeploy (or stop/deallocate) existing VMs after this change for it to take effect.

## GitHub configuration required (OIDC, no secret login)

This repo uses **Azure OIDC login** (`azure/login@v2`) instead of `AZURE_CREDENTIALS`.

Set these **repository variables** (the 3 values needed for no-secret Azure login):

- `AZURE_SUBSCRIPTION_ID`
- `AZURE_CLIENT_ID`
- `AZURE_TENANT_ID`

Also set these **repository variables**:

- `AZURE_ENTRA_ADMIN_OBJECT_ID` (optional): Entra ID object ID granted **Virtual Machine Administrator Login** on both VMs. Defaults in code to the lab group `2ad450d1-8db6-4198-87a4-8d30febdbe4a`; set the variable only to override. Object IDs are identifiers, not secrets, so keeping the default in code is safe.
- `AZURE_ADMIN_SSH_PUBLIC_KEY` (optional): SSH public key also deployed to both VMs. Empty means Entra ID login only.
- `AZURE_TRUSTED_SSH_CIDR`: trusted source CIDRs for SSH to lab VMs, comma-separated (for example `203.0.113.5/32,2001:db8::1/128`). A single CIDR also works.
- `LAB_STACK_NAME` (optional, default `test-azure-lab-stack`): deployment stack name used to manage lab resource groups.
- `LAB_RG_COUNT` (optional, default `3`): number of managed lab resource groups to maintain (`az-learn-01`, `az-learn-02`, ...). The `az-learn-` prefix is hardcoded.

### Required Azure app setup for OIDC

Create an Entra app/service principal, grant it rights in the target subscription, and add a **Federated credential** for this GitHub repository/branch so Actions can exchange the GitHub OIDC token for Azure access. The deployment identity must also be able to create role assignments (for example `Role Based Access Control Administrator` or `Owner`) because the templates assign **Virtual Machine Administrator Login** on each VM.

## Entra ID login setup (SSH key optional)

VMs authenticate with Microsoft Entra ID via the `AADSSHLoginForLinux` extension plus a **Virtual Machine Administrator Login** role assignment created by the template. An SSH public key can additionally be deployed by setting `AZURE_ADMIN_SSH_PUBLIC_KEY`; leave it empty for Entra-only login.

Get the object ID to put in `AZURE_ENTRA_ADMIN_OBJECT_ID` (only needed to override the group default baked into the `.bicepparam` files):

```bash
az ad signed-in-user show --query id -o tsv
```

For a group (all members can log in), use the group object ID and set `entraAdminPrincipalType` to `Group` in the example `.bicepparam` file (already the default):

```bash
az ad group show --group "lab-admins" --query id -o tsv
```

For IPv6-only public IP labs, include your IPv6 address (for example `2001:db8::1/128`). To allow both stacks, set `AZURE_TRUSTED_SSH_CIDR` to a comma-separated pair (for example `203.0.113.5/32,2001:db8::1/128`).

## Connect with Entra ID (IPv6 example)

```bash
az extension add --name ssh
az login
az ssh vm --ip <host-ipv6>
```

Concrete example (IPv6 address is the `hostAPublicIp` / `hostBPublicIp` deployment output):

```bash
az ssh vm --ip 2603:1030:205:0:0:0:0:4
```

By VM name instead of IP:

```bash
az ssh vm --resource-group az-learn-01 --name sharedvnet-hosta
```

For plain OpenSSH clients, export a config first and then connect:

```bash
az ssh config --ip <host-ipv6> --file ./sshconfig
ssh -F ./sshconfig <host-ipv6>
```

With an SSH key deployed (`AZURE_ADMIN_SSH_PUBLIC_KEY` set), key login also works (note brackets for IPv6):

```bash
ssh -i ~/.ssh/test-azure-lab azureuser@[<host-ipv6>]
```

## Helper script to set repository variables

Use `/home/runner/work/test-azure/test-azure/scripts/set-github-vars.sh` to set required repository variables in one step:

```bash
/home/runner/work/test-azure/test-azure/scripts/set-github-vars.sh lawrencek76/test-azure
```

The script prompts for required values and calls `gh variable set` for the target repository.

## Workflows

### 1) Deploy lab
Workflow: `.github/workflows/deploy-lab.yml`

Manual (`workflow_dispatch`) inputs:
- `operation`
  - `prepare-rgs`: create/update managed lab RGs via Bicep deployment stack and set cleanup tags
  - `deploy-example`: deploy one selected example to `az-learn-01`
- `example` (used for deploy only):
  - `two-vms-separate-vnets`
  - `two-vms-shared-vnet`
- `location`: Azure region (default `eastus`)
  - Used when first creating managed RGs. Existing managed RGs keep their original region.

Example deployments always target `az-learn-01`.

Deployments use per-example `.bicepparam` files:
- `examples/two-vms-separate-vnets/main.bicepparam`
- `examples/two-vms-shared-vnet/main.bicepparam`

Each lab is a standalone Bicep template (`main.bicep`) under its own example folder.

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
2. Connect with Entra ID (`az ssh vm --ip <hostAPublicIp>` and `az ssh vm --ip <hostBPublicIp>`; public and private IPs are deployment outputs).
3. From `hosta`, test HTTP to `hostb` private IP on port 80 (`curl http://<hostb-private-ip>`).
4. Observe failure and use Azure portal tools (effective security rules, NSG flow logs, connection troubleshoot) to identify the deny rule.
