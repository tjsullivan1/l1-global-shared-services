targetScope = 'subscription'

param location string = 'centralus'
param deploymentIteration string = '22'
param uniqstr string = uniqueString(subscription().subscriptionId)
param acrName string = 'tjsacr${deploymentIteration}${uniqstr}'
param existing_nsg_id string = '/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/rg-core-it/providers/Microsoft.Network/networkSecurityGroups/nsg-tjs'

param hubVnetName string = 'vnet-tjs-hub'
param hubVnetAddressPrefix string = '10.100.0.0/20' 
param hubVnetSubnets array =[
  {
    name: 'ApplicationGatewaySubnet'
    subnetPrefix: '10.100.0.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    nsg_id: '/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/rg-core-it/providers/Microsoft.Network/networkSecurityGroups/nsg-appgw'
  }
  {
    name: 'snet-endpoints'
    subnetPrefix: '10.100.1.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    nsg_id: existing_nsg_id
  }
  {
    name: 'snet-other'
    subnetPrefix: '10.100.2.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    nsg_id: existing_nsg_id
  }
  {
    name: 'AzureBastionSubnet'
    subnetPrefix: '10.100.3.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    nsg_id: '/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/rg-core-it/providers/Microsoft.Network/networkSecurityGroups/nsg-bastion'
  }
]

param privatelinkVnetName string = 'vnet-tjs-aks-pl'
param privatelinkVnetAddressPrefix string = '10.100.0.0/20' 
param privatelinkVnetSubnets array =[
  {
    name: 'snet-aks'
    subnetPrefix: '10.100.0.0/22'
    PEpol:  'Disabled'
    PLSpol: 'Disabled'
    nsg_id: existing_nsg_id
  }
  {
    name: 'snet-other'
    subnetPrefix: '10.100.4.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    nsg_id: existing_nsg_id
  }
]

param sapVnetName string = 'vnet-tjs-aks-sap'
param sapVnetAddressPrefix string = '10.102.0.0/22' 
var sapVnetSubnets  =[
  {
    name: 'snet-db'
    subnetPrefix: '10.102.0.0/24'
    PEpol: 'Disabled'
    PLSpol: 'Disabled'
    natgw_id: natgw.outputs.gw_id
    nsg_id: existing_nsg_id
  }
  {
    name: 'snet-other'
    subnetPrefix: '10.102.1.0/24'
    PEpol:  'Disabled'
    PLSpol:  'Disabled'
    natgw_id: ''
    nsg_id: existing_nsg_id
  }
]

param appgwName string = 'appgw-hub-aks-${deploymentIteration}${uniqstr}'

param db_ilb_name  string = 'ilb-db-${deploymentIteration}${uniqstr}'

resource newRG 'Microsoft.Resources/resourceGroups@2021-01-01' = {
  name: 'rg-aks-${deploymentIteration}${uniqstr}'
  location: location
}

resource existingRg 'Microsoft.Resources/resourceGroups@2021-01-01' existing = {
  name: 'rg-core-it'
}

module aksUserAssignedIdentity 'br:tjsacr01.azurecr.io/bicep/modules/usermi:0.0.2' = {
  scope: newRG
  name: 'identity-aks-${deploymentIteration}${uniqstr}'
  params: {
    name: 'identity-aks-${deploymentIteration}${uniqstr}'
  }
}

// #### VNET DECLARATIONS #####


module privatelinkvnet 'br:tjsacr01.azurecr.io/bicep/modules/vnet:0.2.0' = {
  scope: newRG
  name: 'privatelinkvnet'
  params: {
    virtualNetworkName: privatelinkVnetName
    addressPrefix: privatelinkVnetAddressPrefix
    subnets: privatelinkVnetSubnets
  }  
}

module hubvnet 'br:tjsacr01.azurecr.io/bicep/modules/vnet:0.2.0' = {
  scope: newRG
  name: 'hubvnet'
  params: {
    virtualNetworkName: hubVnetName
    addressPrefix: hubVnetAddressPrefix
    subnets: hubVnetSubnets
  }  
}

module sapvnet 'br:tjsacr01.azurecr.io/bicep/modules/vnet:0.2.1' = {
  scope: newRG
  name: 'sapvnet'
  params: {
    virtualNetworkName: sapVnetName
    addressPrefix: sapVnetAddressPrefix
    subnets: sapVnetSubnets
  }  
}

// #### VNET PEERINGS #####
module hubSapPeering 'br:tjsacr01.azurecr.io/bicep/modules/vnet-peering:0.0.1' = {
  scope: newRG
  name: 'hubSapPeering'
  params: {
    remoteVnetId: sapvnet.outputs.vnet_id
    vnetName: hubVnetName
    remoteVnetName: sapVnetName
  }
  dependsOn: [
    sapvnet
    hubvnet
  ]
}

module sapHubPeering 'br:tjsacr01.azurecr.io/bicep/modules/vnet-peering:0.0.1' = {
  scope: newRG
  name: 'sapHubPeering'
  params: {
    remoteVnetId: hubvnet.outputs.vnet_id
    vnetName: sapVnetName
    remoteVnetName: hubVnetName
  }
  dependsOn: [
    sapvnet
    hubvnet
  ]
}

// #### NETWORK TOOLS DEPLOYMENTS ####

module coreAppGwPL 'br:tjsacr01.azurecr.io/bicep/modules/appgw:0.0.1' = {
  scope: newRG
  name: 'coreappgwpl'
  params: {
    applicationGatewayName: '${appgwName}pl'
    virtualNetworkName: hubVnetName
  }
  dependsOn: [
    hubvnet
  ]
}

module bastion 'br:tjsacr01.azurecr.io/bicep/modules/bastion:0.0.2' = {
  scope: newRG
  name: 'hub-bastion'
  params: {
    subnet_id: hubvnet.outputs.subnets[3].subnet_id
    bastionHostName: 'bst-test-${uniqstr}'
  }
}

module natgw 'br:tjsacr01.azurecr.io/bicep/modules/natgw:0.0.1' = {
  scope: newRG
  name: 'natgw'
  params: {
    natGatewayName: 'natgw-tjs-${uniqstr}'
  }
}

// // #### VM DEPLOYMENTS #####

module testVm 'br:tjsacr01.azurecr.io/bicep/modules/linuxvm:0.0.3' = {
  scope: newRG
  name: 'testvm'
  params: {
    adminPublicKey: loadTextContent('id_rsa.pub')
    subnetId: hubvnet.outputs.subnets[1].subnet_id
    vmName: 'testvm-${uniqstr}'
    adminUsername: 'tjs'
    customData: loadTextContent('config.sh')
  }
}

module testVmAksNet 'br:tjsacr01.azurecr.io/bicep/modules/linuxvm:0.0.3' = {
  scope: newRG
  name: 'testvm-aks'
  params: {
    adminPublicKey: loadTextContent('id_rsa.pub')
    subnetId: privatelinkvnet.outputs.subnets[1].subnet_id
    vmName: 'testvm-aks-${uniqstr}'
    adminUsername: 'tjs'
    customData: loadTextContent('config.sh')
  }
}

module dbVM 'br:tjsacr01.azurecr.io/bicep/modules/linuxvm:0.0.3' = {
  scope: newRG
  name: 'dbvm'
  params: {
    adminPublicKey: loadTextContent('id_rsa.pub')
    subnetId: sapvnet.outputs.subnets[0].subnet_id
    vmName: 'database-${uniqstr}'
    adminUsername: 'tjs'
    customData:  loadTextContent('sql.sh')
    load_balancer_pool_id: db_ilb.outputs.ilb_backend_pool_id
  }
}



// #### AKS DEPLOYMENTS ####

module tmpacr 'br:tjsacr01.azurecr.io/bicep/modules/acr:0.0.1' = {
  scope: newRG
  name: acrName
  params: {
    acrName: acrName
  }
}


module privatelinkaks 'br:tjsacr01.azurecr.io/bicep/modules/aks:0.0.15' = {
  scope: newRG
  name: 'privatelinkaks'
  params:{
    networkPlugin: 'azure'
    dnsServiceIP: '10.190.0.10'
    serviceCidr: '10.190.0.0/16'
    vnetSubnetID: privatelinkvnet.outputs.subnets[0].subnet_id
    resourceName: 'k8s-privatelink'
    dockerBridgeCidr: '172.17.0.1/16'
    acrName: acrName
    dnsPrefix: 'k8s-${deploymentIteration}-${uniqstr}'
    enablePrivateCluster: true
    userIdentity: aksUserAssignedIdentity.outputs.identity_resource_id
    miPrincipalId: aksUserAssignedIdentity.outputs.identity_principal_id
  }
}


// #### Private Links
module db_ilb  'br:tjsacr01.azurecr.io/bicep/modules/ilb:0.0.8' = {
  scope: newRG
  name: db_ilb_name
  params: {
    subnetId: sapvnet.outputs.subnets[0].subnet_id
    loadBalancerName: db_ilb_name
    tcp_port: 3306
  }
}

module db_pls 'br:tjsacr01.azurecr.io/bicep/modules/pls:0.0.1' = {
  scope: newRG
  name: 'pls-mysql'
  params: {
    load_balancer_subnet_id: sapvnet.outputs.subnets[0].subnet_id
    load_balancer_frontend_id: db_ilb.outputs.ilb_frontend_pool_id
  }
}

module peDbtoAKS 'br:tjsacr01.azurecr.io/bicep/modules/privateendpoint:0.0.4' = {
  scope: newRG
  name: 'pe-dbtoaks'
  params: {
    name: 'pe-dbtoaks'
    private_link_service_id: db_pls.outputs.pls_id
    endpoint_subnet_id: privatelinkvnet.outputs.subnets[1].subnet_id
  }
}

module secondAKSApi 'br:tjsacr01.azurecr.io/bicep/modules/privateendpoint:0.0.6' = {
  scope: newRG
  name: 'pe-kube-apiserver'
  params: {
    name: 'pe-kube-apiserver'
    private_link_service_id: privatelinkaks.outputs.aksResourceId
    endpoint_subnet_id: hubvnet.outputs.subnets[1].subnet_id
    group_ids: [
      'management'
    ]
  }
}


var privateDNSZone = 'k8s.privatelink.${location}.azmk8s.io'

module k8sDnsPl 'br:tjsacr01.azurecr.io/bicep/modules/dnszone:0.0.1' = {
  scope: existingRg
  name: 'k8s-dns-for-pl'
  params: {
    zoneName: privateDNSZone
  }
}

module hubDnsLink 'br:tjsacr01.azurecr.io/bicep/modules/privatednslink:0.0.1' = {
  scope: existingRg
  name: 'link-to-hub'
  params: {
    vnetId: hubvnet.outputs.vnet_id
    privateDnsZoneName: privateDNSZone
    vnetName: hubVnetName
  }
}

module k8sHubARecord 'br:tjsacr01.azurecr.io/bicep/modules/pedns:0.0.1' = {
  scope: existingRg
  name: 'k8s-a-record'
  params: {
    pe_ip: '10.100.1.5' //TODO: Need to fix this. I haven't figured out how to get this from my private endpoint. 
    a_record: replace(privatelinkaks.outputs.controlPlanePrivateFQDN, '.${privateDNSZone}', '')
    privateDnsZoneName: privateDNSZone
  }
}
// module aks_pls 'br:tjsacr01.azurecr.io/bicep/modules/pls:0.0.1' = {
//   name: 'pls-todos'
//   params: {
//     privatelinkServiceName: 'pls-todos'
//     load_balancer_subnet_id: privatelinkvnet.outputs.subnets[0].subnet_id
//     load_balancer_frontend_id: '/subscriptions/8b63fe10-d76a-4f8f-81ce-7a5a8b911779/resourceGroups/mc_rg-aks-7_k8s-privatelink_centralus/providers/Microsoft.Network/loadBalancers/kubernetes-internal/frontendIPConfigurations/aa45a095e684f4be283471dc60cb549b'
//   }
// }

// resource peTodos 'Microsoft.Network/privateEndpoints@2021-05-01' = {
//   name: 'pe-todos'
//   location: location
//   properties: {
//     subnet: {
//       id: hubvnet.outputs.subnets[1].subnet_id
//     }
//     privateLinkServiceConnections: [
//       {
//         name: 'pe-todos'
//         properties: {
//           privateLinkServiceId: aks_pls.outputs.pls_id
//         }
//       }
//     ]
//   }
// }
