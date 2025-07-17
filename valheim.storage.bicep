param location string = resourceGroup().location
param storageAccountName string = 'str${uniqueString(resourceGroup().id)}'
@description('The name of the file share mapping to the home directory of the user "steam" within the container. This is where the game files, backups, and save data are stored.')
param fileShareName string

resource storage 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Premium_LRS'
  }
  kind: 'FileStorage'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    sasPolicy: {
      expirationAction: 'Block'
      sasExpirationPeriod: '30.00:00:00'
    }
  }

  resource fileServices 'fileServices' = {
    name: 'default'
    properties: {
      shareDeleteRetentionPolicy: {
        enabled: false
        // days: 1
        // allowPermanentDelete: true
      }
    }

    // resource fsHomeSteam 'shares' = {
    //   name: fileShareName
    //   properties: {
    //     shareQuota: 100
    //     metadata: {
    //       description: 'Mount for the user "steam" home directory'
    //     }
    //   }
    // }

    resource fsSaves 'shares' = {
      name: fileShareName
    }
  }
}
