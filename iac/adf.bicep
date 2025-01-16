param dataFactoryName string 
param location string = resourceGroup().location
param environment string 
// repository parameters
param repositoryName string 
param accountName string 
param collaborationBranch string 
param rootFolder string 

var gitHubRepoConfiguration = {
  accountName: accountName
  repositoryName: repositoryName
  collaborationBranch: collaborationBranch
  rootFolder: rootFolder  
  type: 'FactoryGitHubConfiguration'
}

resource dataFactoryName_resource 'Microsoft.DataFactory/factories@2018-06-01' =  {
  name: dataFactoryName
  location: location
  properties: {
    repoConfiguration: (environment == 'development') ? gitHubRepoConfiguration : {}
  }
  identity: {
    type: 'SystemAssigned'
  }  
}
