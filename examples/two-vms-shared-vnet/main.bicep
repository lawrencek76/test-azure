targetScope = 'resourceGroup'

@description('SSH public key used for VM authentication.')
param adminPublicKey string

@description('Resource name prefix for this example deployment.')
param namePrefix string = 'sharedvnet'

module networkLab '../../infra/modules/two-vm-network-lab.bicep' = {
  name: 'two-vms-shared-vnet'
  params: {
    adminPublicKey: adminPublicKey
    namePrefix: namePrefix
    sameVnet: true
    networkLayout: {
      hostAVnetCidr: '10.20.0.0/16'
      hostASubnetCidr: '10.20.1.0/24'
      hostBVnetCidr: '10.20.0.0/16'
      hostBSubnetCidr: '10.20.2.0/24'
    }
  }
}

output hostAPublicIp string? = networkLab.outputs.?hostAPublicIp
output hostBPublicIp string? = networkLab.outputs.?hostBPublicIp
output hostAPrivateIp string = networkLab.outputs.hostAPrivateIp
output hostBPrivateIp string = networkLab.outputs.hostBPrivateIp
output blockedFlow string = networkLab.outputs.blockedFlow
