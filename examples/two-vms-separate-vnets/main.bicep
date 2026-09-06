targetScope = 'resourceGroup'

@description('SSH public key used for VM authentication.')
param adminPublicKey string

@description('Resource name prefix for this example deployment.')
param namePrefix string = 'separatevnet'

@description('Trusted source CIDR allowed to SSH to lab hosts (IPv6 CIDR recommended).')
param trustedSshSourceCidr string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Admin username for both Linux VMs.')
param adminUsername string = 'azureuser'

@description('Spot VM size to use for both hosts.')
param vmSize string = 'Standard_B1ls'

var hostA = {
  name: 'hosta'
  subnetName: 'hosta-subnet'
  vnetName: '${namePrefix}-hosta-vnet'
  nsgName: '${namePrefix}-hosta-nsg'
  pipName: '${namePrefix}-hosta-pip'
  nicName: '${namePrefix}-hosta-nic'
  privateIp: 'fd00:10:1::4'
  vnetCidr: 'fd00:10::/48'
  subnetCidr: 'fd00:10:1::/64'
}

var hostB = {
  name: 'hostb'
  subnetName: 'hostb-subnet'
  vnetName: '${namePrefix}-hostb-vnet'
  nsgName: '${namePrefix}-hostb-nsg'
  pipName: '${namePrefix}-hostb-pip'
  nicName: '${namePrefix}-hostb-nic'
  privateIp: 'fd00:11:1::4'
  vnetCidr: 'fd00:11::/48'
  subnetCidr: 'fd00:11:1::/64'
}

resource hostANsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: hostA.nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
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
  name: hostB.nsgName
  location: location
  properties: {
    securityRules: [
      {
        name: 'allow-ssh'
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
          sourceAddressPrefix: hostA.privateIp
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'allow-http-lab-vnets'
        properties: {
          access: 'Allow'
          direction: 'Inbound'
          priority: 300
          protocol: 'Tcp'
          sourceAddressPrefixes: [
            hostA.vnetCidr
            hostB.vnetCidr
          ]
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource hostAVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hostA.vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hostA.vnetCidr
      ]
    }
    subnets: [
      {
        name: hostA.subnetName
        properties: {
          addressPrefix: hostA.subnetCidr
          networkSecurityGroup: {
            id: hostANsg.id
          }
        }
      }
    ]
  }
}

resource hostBVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: hostB.vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        hostB.vnetCidr
      ]
    }
    subnets: [
      {
        name: hostB.subnetName
        properties: {
          addressPrefix: hostB.subnetCidr
          networkSecurityGroup: {
            id: hostBNsg.id
          }
        }
      }
    ]
  }
}

resource hostAToHostBPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
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

resource hostBToHostAPeering 'Microsoft.Network/virtualNetworks/virtualNetworkPeerings@2024-05-01' = {
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

resource hostAPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: hostA.pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
  }
}

resource hostBPip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: hostB.pipName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
    publicIPAddressVersion: 'IPv6'
  }
}

resource hostANic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: hostA.nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostA.privateIp
          privateIPAddressVersion: 'IPv6'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hostA.vnetName, hostA.subnetName)
          }
          publicIPAddress: {
            id: hostAPip.id
          }
        }
      }
    ]
  }
}

resource hostBNic 'Microsoft.Network/networkInterfaces@2024-05-01' = {
  name: hostB.nicName
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostB.privateIp
          privateIPAddressVersion: 'IPv6'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', hostB.vnetName, hostB.subnetName)
          }
          publicIPAddress: {
            id: hostBPip.id
          }
        }
      }
    ]
  }
}

resource hostAVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${namePrefix}-${hostA.name}'
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
      computerName: '${namePrefix}-${hostA.name}'
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
          - [bash, -lc, "echo hosta > /etc/lab-hostname"]
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
          id: hostANic.id
        }
      ]
    }
  }
}

resource hostBVm 'Microsoft.Compute/virtualMachines@2024-07-01' = {
  name: '${namePrefix}-${hostB.name}'
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
      computerName: '${namePrefix}-${hostB.name}'
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
          - [bash, -lc, "echo hostb > /etc/lab-hostname"]
          - [bash, -lc, "nohup python3 -m http.server 80 --bind :: >/var/log/http80.log 2>&1 &"]
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
          id: hostBNic.id
        }
      ]
    }
  }
}

output hostAPublicIp string? = hostAPip.properties.ipAddress
output hostBPublicIp string? = hostBPip.properties.ipAddress
output hostAPrivateIp string = hostA.privateIp
output hostBPrivateIp string = hostB.privateIp
output blockedFlow string = 'Traffic from ${hostA.privateIp} to ${hostB.privateIp}:80 is denied by ${hostBNsg.name}/deny-http-from-hosta'
