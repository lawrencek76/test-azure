targetScope = 'resourceGroup'

@description('SSH public key used for VM authentication.')
param adminPublicKey string

@description('Resource name prefix for this example deployment.')
param namePrefix string = 'sharedvnet'

@description('Trusted source CIDRs allowed to SSH to lab hosts. Comma-separated IPv4 and/or IPv6 CIDRs (for example "203.0.113.5/32,2001:db8::1/128").')
param trustedSshSourceCidr string

@description('Azure region for all resources.')
param location string = resourceGroup().location

@description('Admin username for both Linux VMs.')
param adminUsername string = 'azureuser'

@description('VM size to use for both hosts.')
param vmSize string = 'Standard_B2ats_v2'

var trustedSshSourceCidrs = map(split(trustedSshSourceCidr, ','), cidr => trim(cidr))
var trustedSshV4Cidrs = filter(trustedSshSourceCidrs, cidr => !contains(cidr, ':'))
var trustedSshV6Cidrs = filter(trustedSshSourceCidrs, cidr => contains(cidr, ':'))

var sshAllowRules = concat(
  empty(trustedSshV4Cidrs) ? [] : [
    {
      name: 'allow-ssh-v4'
      properties: {
        access: 'Allow'
        direction: 'Inbound'
        priority: 100
        protocol: 'Tcp'
        sourceAddressPrefixes: trustedSshV4Cidrs
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '22'
      }
    }
  ],
  empty(trustedSshV6Cidrs) ? [] : [
    {
      name: 'allow-ssh-v6'
      properties: {
        access: 'Allow'
        direction: 'Inbound'
        priority: 110
        protocol: 'Tcp'
        sourceAddressPrefixes: trustedSshV6Cidrs
        sourcePortRange: '*'
        destinationAddressPrefix: '*'
        destinationPortRange: '22'
      }
    }
  ]
)

var hostA = {
  name: 'hosta'
  subnetName: 'hosta-subnet'
  nsgName: '${namePrefix}-hosta-nsg'
  pipName: '${namePrefix}-hosta-pip'
  nicName: '${namePrefix}-hosta-nic'
  privateIpv4: '10.20.1.4'
  privateIp: 'fd00:20:0:1::4'
  subnetCidrV4: '10.20.1.0/24'
  subnetCidr: 'fd00:20:0:1::/64'
}

var hostB = {
  name: 'hostb'
  subnetName: 'hostb-subnet'
  nsgName: '${namePrefix}-hostb-nsg'
  pipName: '${namePrefix}-hostb-pip'
  nicName: '${namePrefix}-hostb-nic'
  privateIpv4: '10.20.2.4'
  privateIp: 'fd00:20:0:2::4'
  subnetCidrV4: '10.20.2.0/24'
  subnetCidr: 'fd00:20:0:2::/64'
}

var vnetName = '${namePrefix}-shared-vnet'
var vnetCidrV4 = '10.20.0.0/16'
var vnetCidr = 'fd00:20::/48'

resource hostANsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: hostA.nsgName
  location: location
  properties: {
    securityRules: sshAllowRules
  }
}

resource hostBNsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: hostB.nsgName
  location: location
  properties: {
    securityRules: concat(sshAllowRules, [
      {
        name: 'deny-http-from-hosta-v4'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 200
          protocol: 'Tcp'
          sourceAddressPrefix: hostA.privateIpv4
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
      {
        name: 'deny-http-from-hosta-v6'
        properties: {
          access: 'Deny'
          direction: 'Inbound'
          priority: 210
          protocol: 'Tcp'
          sourceAddressPrefix: hostA.privateIp
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
          sourceAddressPrefix: 'VirtualNetwork'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ])
  }
}

resource sharedVnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetCidrV4
        vnetCidr
      ]
    }
    subnets: [
      {
        name: hostA.subnetName
        properties: {
          addressPrefixes: [
            hostA.subnetCidrV4
            hostA.subnetCidr
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: hostANsg.id
          }
        }
      }
      {
        name: hostB.subnetName
        properties: {
          addressPrefixes: [
            hostB.subnetCidrV4
            hostB.subnetCidr
          ]
          defaultOutboundAccess: false
          networkSecurityGroup: {
            id: hostBNsg.id
          }
        }
      }
    ]
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
        name: 'ipconfigv4'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostA.privateIpv4
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, hostA.subnetName)
          }
        }
      }
      {
        name: 'ipconfigv6'
        properties: {
          primary: false
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostA.privateIp
          privateIPAddressVersion: 'IPv6'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, hostA.subnetName)
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
        name: 'ipconfigv4'
        properties: {
          primary: true
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostB.privateIpv4
          privateIPAddressVersion: 'IPv4'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, hostB.subnetName)
          }
        }
      }
      {
        name: 'ipconfigv6'
        properties: {
          primary: false
          privateIPAllocationMethod: 'Static'
          privateIPAddress: hostB.privateIp
          privateIPAddressVersion: 'IPv6'
          subnet: {
            id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, hostB.subnetName)
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
output blockedFlow string = 'Traffic from ${hostA.privateIp} to ${hostB.privateIp}:80 is denied by ${hostBNsg.name}/deny-http-from-hosta-v6'
