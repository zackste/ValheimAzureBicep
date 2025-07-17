targetScope = 'subscription'

param cpuCores int
param memoryInGB int
param worldName string
@secure()
param serverPass string
param serverName string // FDQN: [dnshNameLabel].westeurope.azurecontainer.io
param storageAccountName string
param fileShareName string
param modifiers array
param modDownloads array

@secure()
param webHook string

@description('The subdomain name for the Docker container registry.')
param containerRegistryName string
@description('The name of the resource group for the Log Analytics workspace.')
param operationalInsightsResourceGroupName string
@description('The name of the Log Analytics workspace.')
param operationalInsightsWorkspaceName string

var serverNameLower = toLower(serverName)
var resourceName = '${serverNameLower}-${deployment().location}'

resource resourceGroup 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'rg-${resourceName}'
  location: deployment().location
}

module storage 'valheim.storage.bicep' = {
  name: 'storageModule'
  scope: resourceGroup
  params: {
    location: resourceGroup.location
    storageAccountName: storageAccountName
    fileShareName: fileShareName
  }
}

module valheimServer 'valheim-server-mbround18.bicep' = {
  name: 'valheimServerModule'
  scope: resourceGroup
  params: {
    location: resourceGroup.location
    cpuCores: cpuCores
    memoryInGB: memoryInGB
    dnshNameLabel: serverNameLower
    storageAccountName: storageAccountName
    fileShareName: fileShareName
    serverName: serverName
    resourceName: resourceName
    worldName: worldName
    serverPass: serverPass
    modifiers: modifiers
    modDownloads: modDownloads
    webHook: webHook
    containerRegistryName: containerRegistryName
    operationalInsightsResourceGroupName: operationalInsightsResourceGroupName
    operationalInsightsWorkspaceName: operationalInsightsWorkspaceName
  }
  dependsOn: [
    storage
  ]
}
