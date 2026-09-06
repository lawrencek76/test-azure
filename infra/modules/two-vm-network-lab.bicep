@description('Prefix used for all deployed resource names.')
param namePrefix string = 'azlab'

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('SSH public key used for VM admin authentication.')
@minLength(1)
param adminPublicKey string

@description('Admin username for both Linux VMs.')
param adminUsername string = 'azureuser'

@description('Trusted source CIDR allowed to SSH to lab hosts (for example, 203.0.113.10/32).')
param trustedSshSourceCidr string

@description('Spot VM size to use for both hosts.')
param vmSize string = 'Standard_B1ls'

@description('Set to true to place both VMs in a shared VNet with separate subnets.')
param sameVnet bool

type NetworkLayout = {
  hostAVnetCidr: string
  hostASubnetCidr: string
  hostBVnetCidr: string
  hostBSubnetCidr: string
}

@description('CIDR layout for each host network.')
param networkLayout NetworkLayout

var hostNames = [
  'hosta'
  'hostb'
]

var vmConfigs = [
  {
    name: hostNames[0]
    subnetName: '${hostNames[0]}-subnet'
    vnetName: sameVnet ? '${namePrefix}-shared-vnet' : '${namePrefix}-${hostNames[0]}-vnet'
    nsgName: '${namePrefix}-${hostNames[0]}-nsg'
    pipName: '${namePrefix}-${hostNames[0]}-pip'
    nicName: '${namePrefix}-${hostNames[0]}-nic'
    privateIp: sameVnet ? '10.20.1.4' : '10.10.1.4'
    subnetPrefix: networkLayout.hostASubnetCidr
  }
  {
    name: hostNames[1]
    subnetName: '${hostNames[1]}-subnet'
    vnetName: sameVnet ? '${namePrefix}-shared-vnet' : '${namePrefix}-${hostNames[1]}-vnet'
    nsgName: '${namePrefix}-${hostNames[1]}-nsg'
    pipName: '${namePrefix}-${hostNames[1]}-pip'
    nicName: '${namePrefix}-${hostNames[1]}-nic'
    privateIp: sameVnet ? '10.20.2.4' : '10.11.1.4'
    subnetPrefix: networkLayout.hostBSubnetCidr
  }
]

resource hostANsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: vmConfigs[0].nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh-internet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: trustedSshSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
    ]
  }
}

resource hostBNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: vmConfigs[1].nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh-internet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 100
          protocol: 'Tcp'
          sourceAddressPrefix: trustedSshSourceCidr
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '22'
        }
      }
      {
        name: 'deny-http-from-hosta'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 200
          protocol: 'Tcp'
          sourceAddressPrefix: vmConfigs[0].privateIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'allow-http-vnet'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 300
          protocol: 'Tcp'
          sourceAddressPrefixes: sameVnet
            ? [
                'VirtualNetwork'
              ]
            : [
                networkLayout.hostAVnetCidr
                networkLayout.hostBVnetCidr
              ]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource sharedVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (sameVnet) {
  name: '${namePrefix}-shared-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkLayout.hostAVnetCidr
      ]
    }
    subnets: [for config in vmConfigs: {
      name: config.subnetName
      properties: {
        addressPrefix: config.subnetPrefix
        networkSecurityGroup: {
          id: resourceId('Microsoft.Network/networkSecurityGroups', config.nsgName)
        }
      }
    }]
  }
}

resource hostAVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!sameVnet) {
  name: vmConfigs[0].vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkLayout.hostAVnetCidr
      ]
    }
    subnets: [
      {
        name: vmConfigs[0].subnetName
        properties: {
          addressPrefix: vmConfigs[0].subnetPrefix
          networkSecurityGroup: {
            id: hostANsg.id
          }
        }
      }
    ]
  }
}

resource hostBVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = if (!sameVnet) {
  name: vmConfigs[1].vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        networkLayout.hostBVnetCidr
      ]
    }
    subnets: [
      {
        name: vmConfigs[1].subnetName
        properties: {
          addressPrefix: vmConfigs[1].subnetPrefix
          networkSecurityGroup: {
            id: hostBNsg.id
          }
        }
      }
    ]
  }
}

resource hostAToHostBPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (!sameVnet) {
  name: 'to-${hostBVnet.name}'
  parent: hostAVnet
  properties: {
    remoteVirtualNetwork: {
      id: hostBVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource hostBToHostAPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = if (!sameVnet) {
  name: 'to-${hostAVnet.name}'
  parent: hostBVnet
  properties: {
    remoteVirtualNetwork: {
      id: hostAVnet.id
    }
    allowVirtualNetworkAccess: true
    allowForwardedTraffic: true
  }
}

resource publicIps 'Microsoft.Network/publicIPAddresses@2024-05-01' = [for config in vmConfigs: {
  name: config.pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}]

resource nics 'Microsoft.Network/networkInterfaces@2024-05-01' = [for (config, i) in vmConfigs: {
  name: config.nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: config.privateIp
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', config.vnetName, config.subnetName)
          }
          publicIPAddress: {
            id: publicIps[i].id
          }
        }
      }
    ]
  }
}]

resource virtualMachines 'Microsoft.Compute/virtualMachines@2024-07-01' = [for (config, i) in vmConfigs: {
  name: '${namePrefix}-${config.name}'
  location: location
  properties: {
    priority: 'Spot'
    evictionPolicy: 'Delete'
    billingProfile: {
      maxPrice: -1
    }
    hardwareProfile: {
      vmSize: vmSize
    }
    osProfile: {
      computerName: '${namePrefix}-${config.name}'
      adminUsername: adminUsername
      customData: base64('''
        #cloud-config
        package_update: true
        packages:
          - curl
          - dnsutils
          - iperf3
          - iputils-ping
          - net-tools
          - netcat-openbsd
          - python3
          - traceroute
        runcmd:
          - [bash, -lc, "echo ${config.name} > /etc/lab-hostname"]
          - [bash, -lc, "if [ '${config.name}' = 'hostb' ]; then nohup python3 -m http.server 80 --bind 0.0.0.0 >/var/log/http80.log 2>&1 & fi"]
      ''')
      linuxConfiguration: {
        disablePasswordAuthentication: true
        ssh: {
          publicKeys: [
            {
              path: '/home/${adminUsername}/.ssh/authorized_keys'
              keyData: adminPublicKey
            }
          ]
        }
      }
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nics[i].id
        }
      ]
    }
  }
}]

output hostAPublicIp string? = publicIps[0].properties.ipAddress
output hostBPublicIp string? = publicIps[1].properties.ipAddress
output hostAPrivateIp string = vmConfigs[0].privateIp
output hostBPrivateIp string = vmConfigs[1].privateIp
output blockedFlow string = 'Traffic from ${vmConfigs[0].privateIp} to ${vmConfigs[1].privateIp}:80 is denied by ${hostBNsg.name}/deny-http-from-hosta'
