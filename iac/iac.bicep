@description('Specifies the name of the secret that you want to create.')
param managedIdentityName string

param dataFactoryName string 
param location string = resourceGroup().location
param environment string 
// repository parameters
param repositoryName string 
param accountName string 
param collaborationBranch string 
param rootFolder string 

@description('Specifies the name of the key vault.')
param keyVaultName string = 'kv${uniqueString(resourceGroup().id)}'

@description('Specifies the SKU to use for the key vault.')
param keyVaultSku object = {
  name: 'standard'
  family: 'A'
}

@description('Specifies the permissions to keys in the vault. Valid values are: all, encrypt, decrypt, wrapKey, unwrapKey, sign, verify, get, list, create, update, import, delete, backup, restore, recover, and purge.')
param keysPermissions array = [
  'all'
]

@description('Specifies the permissions to secrets in the vault. Valid values are: all, get, list, set, delete, backup, restore, recover, and purge.')
param secretsPermissions array = [
  'all'
]

@description('Specifies the value of the secret that you want to create.')
@secure()
param ghAppClientIdValue string

@description('Specifies the value of the secret that you want to create.')
@secure()
param ghAppClientSecretValue string

//******************** Managed Identity ********************//

resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-07-31-preview' = {
  location: location
  name: managedIdentityName
}

//******************** Azure Key Vault ********************//


resource keyVault 'Microsoft.KeyVault/vaults@2021-10-01' = {
  name: keyVaultName
  location: location
  properties: {
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    sku: keyVaultSku
    accessPolicies: [
      {
        objectId: managedIdentity.id
        tenantId: tenant().tenantId
        permissions: {
          keys: keysPermissions
          secrets: secretsPermissions
        }
      }
    ]
  }
}

resource clientId 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'clientId'
  properties: {
    value: ghAppClientIdValue
  }
}

resource clientSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'clientSecret'
  properties: {
    value: ghAppClientSecretValue
  }
}

// Resource: Role Assignment for Managed Identity
// resource keyVaultSecretReaderRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
//   name: 'KeyVaultSecretReaderRole'
//   scope: keyVault
//   properties: {
//     roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'b86a8fe0-442b-45d4-8639-7b7b4e1d07b0') // Key Vault Secrets User role definition ID
//     principalId: managedIdentity.id
//     principalType: 'ServicePrincipal'
//   }
// }


//******************** Azure Data Factory ********************//

var gitHubRepoConfiguration = {
  accountName: accountName
  repositoryName: repositoryName
  collaborationBranch: collaborationBranch
  disablePublish: true
  rootFolder: rootFolder
  clientId: clientId.name
  clientSecret: {
    byoaSecretAkvUrl: keyVault.properties.vaultUri
    byoaSecretName: clientSecret.name
  }
  type: 'FactoryGitHubConfiguration'
}

resource dataFactoryName_resource 'Microsoft.DataFactory/factories@2018-06-01' =  {
  name: dataFactoryName
  location: location
  properties: {
    repoConfiguration: (environment == 'development') ? gitHubRepoConfiguration : {}
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }  
}
