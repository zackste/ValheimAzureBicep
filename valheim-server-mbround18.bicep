param resourceName string
param serverName string
param worldName string
@secure()
param serverPass string
param modifiers array = []
param dnshNameLabel string
param location string = resourceGroup().location
param storageAccountName string = 'str${uniqueString(resourceGroup().id)}'
@description('The name of the file share mapping to the home directory of the user "steam" within the container. This is where the game files, backups, and save data are stored.')
param fileShareName string

param containerGroupName string = 'aci-${resourceName}'
param cpuCores int = 3
param memoryInGB int = 8
param restartPolicy string = 'Always'

@secure()
param webHook string = ''

param modDownloads array = []

param containerRegistryName string
param operationalInsightsResourceGroupName string
param operationalInsightsWorkspaceName string

var image = 'mbround18/valheim:latest'

var mountSaveName = 'valheim-server-saves'

var modifiersValue = join(modifiers, ',')
var modDownloadsValue = join(modDownloads, ',')

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' existing = {
  name: storageAccountName

  resource fileServices 'fileServices' existing = {
    name: 'default'

    resource fsSaves 'shares' existing = {
      name: fileShareName
    }
  }
}

resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  // Hardcoded to merge with manually created workspace. This should be parameterized for future fresh deployments.
  name: operationalInsightsWorkspaceName
  scope: resourceGroup(operationalInsightsResourceGroupName)
  //id: 'd6c78a12-6f60-40c3-b8c6-e2f5e7c19e2c'
}

resource containerRegistry 'Microsoft.ContainerRegistry/registries@2022-12-01' = {
  // Must be globally unique
  name: containerRegistryName
  location: location
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: false
  }
}

resource msiContainer 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'msi-${containerGroupName}'
  location: location
}

resource containerShareAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerGroupName, 'Storage File Data SMB Share Contributor')
  scope: storage
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb'
    )
    principalId: msiContainer.properties.principalId
  }
}

resource registryAccess 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerRegistry.name, 'AcrPull')
  scope: containerRegistry
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      '7f951dda-4ed3-4680-a7ca-43fe172d538d'
    )
    principalId: msiContainer.properties.principalId
  }
}

resource containerGroup 'Microsoft.ContainerInstance/containerGroups@2023-05-01' = {
  name: containerGroupName
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${msiContainer.id}': {}
    }
  }
  properties: {
    imageRegistryCredentials: [
      {
        server: containerRegistry.properties.loginServer
        identity: msiContainer.id
      }
    ]
    containers: [
      {
        name: containerGroupName
        properties: {
          image: '${containerRegistry.properties.loginServer}/${image}'
          // image: image
          ports: [
            {
              port: 2456
              protocol: 'UDP'
            }
            {
              port: 2457
              protocol: 'UDP'
            }
            // {
            //   port: 2458
            //   protocol: 'UDP'
            // }
          ]
          resources: {
            requests: {
              cpu: cpuCores
              memoryInGB: memoryInGB
            }
          }
          environmentVariables: [
            { name: 'NAME', value: serverName }
            { name: 'WORLD', value: worldName }
            { name: 'PASSWORD', value: serverPass }
            { name: 'PORT', value: '2456' }
            { name: 'PUBLIC', value: '1' }
            { name: 'ENABLE_CROSSPLAY', value: '0' }
            { name: 'MODIFIERS', value: modifiersValue }
            { name: 'TZ', value: 'America/Los_Angeles' }

            { name: 'AUTO_UPDATE', value: '1' }
            { name: 'AUTO_UPDATE_SCHEDULE', value: '0 6 * * *' }
            { name: 'AUTO_UPDATE_PAUSE_WITH_PLAYERS', value: '1' }

            { name: 'AUTO_BACKUP', value: '0' }
            { name: 'AUTO_BACKUP_SCHEDULE', value: '0 */1 * * *' }
            { name: 'AUTO_BACKUP_NICE_LEVEL', value: '19' }
            { name: 'AUTO_BACKUP_REMOVE_OLD', value: '1' }
            { name: 'AUTO_BACKUP_DAYS_TO_LIVE', value: '2' }
            { name: 'AUTO_BACKUP_ON_UPDATE', value: '1' }
            { name: 'AUTO_BACKUP_ON_SHUTDOWN', value: '1' }
            { name: 'AUTO_BACKUP_PAUSE_WITH_NO_PLAYERS', value: '1' }

            { name: 'WEBHOOK_URL', value: webHook }
            { name: 'SET_KEY', value: 'playerevents' }
            { name: 'PLAYER_EVENT_NOTIFICATIONS', value: '1' }

            { name: 'TYPE', value: 'BepInEx' }
            { name: 'MODS', value: modDownloadsValue }
          ]
          volumeMounts: [
            {
              name: mountSaveName
              mountPath: '/home/steam/.config/unity3d/IronGate/Valheim'
            }
            // {
            //   name: mountBackupName
            //   mountPath: '/home/steam/backups'
            // }
          ]
        }
      }
    ]
    osType: 'Linux'
    restartPolicy: restartPolicy
    ipAddress: {
      type: 'Public'
      dnsNameLabel: dnshNameLabel
      ports: [
        {
          port: 2456
          protocol: 'UDP'
        }
        {
          port: 2457
          protocol: 'UDP'
        }
      ]
    }
    volumes: [
      {
        name: mountSaveName
        azureFile: {
          shareName: storage::fileServices::fsSaves.name
          storageAccountName: storage.name
          storageAccountKey: storage.listKeys().keys[0].value
        }
      }
      // {
      //   name: mountBackupName
      //   azureFile: {
      //     shareName: storage::fileServices::fsBackups.name
      //     storageAccountName: storage.name
      //     storageAccountKey: storage.listKeys().keys[0].value
      //   }
      // }
    ]
    diagnostics: {
      logAnalytics: {
        workspaceId: logAnalyticsWorkspace.properties.customerId
        logType: 'ContainerInstanceLogs'
        workspaceKey: logAnalyticsWorkspace.listKeys().primarySharedKey // listKeys(logAnalyticsWorkspace.id, '2023-09-01').primarySharedKey // containerGroups_aci_crullerheim_eastus_workspaceKey
      }
    }
  }
  dependsOn: [
    containerShareAccess
    registryAccess
  ]
}

output containerInstanceServerName string = containerGroup.properties.ipAddress.fqdn
