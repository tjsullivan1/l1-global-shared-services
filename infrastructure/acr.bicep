targetScope = 'subscription'

@description('Friendly name for resousource group')
param resourceGroupName string

@description('Location for all resources.')
param location string

@minLength(5)
@maxLength(50)
@description('Name of the azure container registry (must be globally unique)')
param acrName string

@description('Enable an admin user that has push/pull permission to the registry.')
param acrAdminUserEnabled bool = false

@allowed([
  'Basic'
  'Standard'
  'Premium'
])
@description('Tier of your Azure Container Registry.')
param acrSku string = 'Basic'

@description('Key/Value pairs for the Azure Metasdata')
param tags object = {}

resource acrRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: resourceGroupName
  location: location
}

module acr 'br:tjsiacdemoacr.azurecr.io/bicep/modules/acr:1.1.0' = {
  name: 'acrDeployment'
	scope: acrRg
	params: {
		acrSku: acrSku
	  acrName: acrName
	  acrAdminUserEnabled: acrAdminUserEnabled
	  location: location
		submitted_tags: tags
	}
}
