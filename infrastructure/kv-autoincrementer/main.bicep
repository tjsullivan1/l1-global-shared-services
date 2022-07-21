targetScope = 'subscription'

param location string = 'centralus'
param deploymentIteration string
param uniqstr string = uniqueString(subscription().subscriptionId)
param rgName string = 'rg-kv-${deploymentIteration}-${uniqstr}'

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name:  rgName
  location: location
}

module testKv 'br:tjsacr01.azurecr.io/bicep/modules/akv:0.0.3' = {
  name: 'testKv'
  scope: newRG
  params: {
    resourceName: 'testkv${uniqueString(rgName)}'
  }
}
