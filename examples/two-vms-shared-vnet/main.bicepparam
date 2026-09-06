using './main.bicep'

param adminPublicKey = readEnvironmentVariable('AZURE_ADMIN_SSH_PUBLIC_KEY', 'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFakeKeyForValidationOnly test-azure')
param trustedSshSourceCidr = readEnvironmentVariable('AZURE_TRUSTED_SSH_CIDR', '2001:db8::1/128')
param namePrefix = 'sharedvnet'
