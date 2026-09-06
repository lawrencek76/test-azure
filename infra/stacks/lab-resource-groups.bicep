targetScope = 'subscription'

@description('Resource group prefix, such as azlearn-rg.')
param rgPrefix string

@description('How many managed resource groups to create.')
@minValue(1)
param rgCount int = 3

@description('Azure region for managed resource groups.')
param location string

@description('Managed-by tag value for all lab resource groups.')
param managedByTag string = 'test-azure-lab'

@description('UTC ISO8601 timestamp for cleanup scheduling.')
param cleanupAfter string

resource resourceGroups 'Microsoft.Resources/resourceGroups@2024-07-01' = [for i in range(0, rgCount): {
  name: '${rgPrefix}-${padLeft(string(i + 1), 2, '0')}'
  location: location
  tags: {
    managedBy: managedByTag
    cleanupAfter: cleanupAfter
  }
}]

output managedResourceGroupNames array = [for i in range(0, rgCount): resourceGroups[i].name]
