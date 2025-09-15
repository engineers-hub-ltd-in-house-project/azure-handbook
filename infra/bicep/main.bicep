@description('The name of the storage account. Must be globally unique.')
param storageAccountName string = 'sthdbkiac${uniqueString(resourceGroup().id)}'

@description('The location of the resources.')
param location string = resourceGroup().location

resource stg 'Microsoft.Storage/storageAccounts@2023-01-01' = {
  name: storageAccountName
  location: location
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}
