param location string

var name = 'autodelete'

var resourceToken = toLower(uniqueString(subscription().id, location))
var globalName = '${name}${resourceToken}'

var addTagFunction = 'AddResourceGroupTags'
var deleteRGFunction = 'DeleteExpiredResourceGroups'

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: '${globalName}-appinsights'
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
  }
}

resource hostingPlan 'Microsoft.Web/serverfarms@2024-04-01' = {
  name: '${globalName}-plan'
  location: location
  sku: {
    name: 'Y1'
    tier: 'Dynamic'
  }
}

resource functionApp 'Microsoft.Web/sites@2024-04-01' = {
  name: '${globalName}-functionapp'
  location: location
  kind: 'functionapp'
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: hostingPlan.id
    siteConfig: {
      appSettings: [
        {
          name: 'AzureWebJobsDashboard'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccount.name};EndpointSuffix=${environment().suffixes.storage};AccountKey=${storageAccount.listKeys().keys[0].value}'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'powershell'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
      ]
      powerShellVersion: '7.4'
    }
  }

  resource addResourceGroupTags 'functions' = {
    name: addTagFunction
    properties: {
      config: { 
        bindings: [
          {
            type: 'eventGridTrigger'
            direction: 'in'
            name: 'eventGridEvent'
          }
        ]
      }
      files: {
        '../requirements.psd1': loadTextContent('../functions/requirements.psd1')
        'run.ps1': loadTextContent('../functions/${addTagFunction}/run.ps1')
      }
    }
  }

  resource deleteResourceGroup 'functions' = {
    name: deleteRGFunction
    properties: {
      config: { 
        bindings: [
          {
            type: 'timerTrigger'
            direction: 'in'
            name: 'Timer'
            schedule: '0 0 8 * * *'
          }
        ]
      }
      files: {
        'run.ps1': loadTextContent('../functions/${deleteRGFunction}/run.ps1')
      }
    }
  }
}

resource eventGridTopic 'Microsoft.EventGrid/systemTopics@2024-06-01-preview' = {
  name: '${globalName}-eventGridTopic'
  location: 'global'
  properties: {
    source: subscription().id
    topicType: 'Microsoft.Resources.Subscriptions'
  }

  resource eventGridSubscription 'eventSubscriptions' = {
    name: '${globalName}-eventSub'
    properties: {
      destination: {
        endpointType: 'AzureFunction'
        properties: {
          resourceId: functionApp::addResourceGroupTags.id
        }
      }
      filter: {
        includedEventTypes: [
          'Microsoft.Resources.ResourceWriteSuccess'
        ]
        advancedFilters: [
          {
            key: 'data.operationName'
            operatorType: 'StringIn'
            values: [
              'Microsoft.Resources/subscriptions/resourceGroups/write'
            ]
          }
        ]
        subjectBeginsWith: ''
        subjectEndsWith: ''
      }
      eventDeliverySchema: 'EventGridSchema'
    }
  }
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: globalName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

output functionAppId string = functionApp.identity.principalId
