using './main.bicep'

param entraAdminObjectId = readEnvironmentVariable('AZURE_ENTRA_ADMIN_OBJECT_ID', '2ad450d1-8db6-4198-87a4-8d30febdbe4a')
param adminPublicKey = readEnvironmentVariable('AZURE_ADMIN_SSH_PUBLIC_KEY', '')
param trustedSshSourceCidr = readEnvironmentVariable('AZURE_TRUSTED_SSH_CIDR', '2001:db8::1/128')
param namePrefix = 'sharedvnet'
