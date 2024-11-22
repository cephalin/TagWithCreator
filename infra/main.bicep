targetScope = 'subscription'

@minLength(1)
@description('Primary location for all resources')
param location string

resource policyAddCreatedOnTag 'Microsoft.Authorization/policyDefinitions@2023-04-01' = {
  name: 'Resource Group Add CreatedOn Tag'
  properties: {
    displayName: 'Resource Group Add CreatedOn Tag'
    description: 'Adds a CreatedOn tag to resource groups that do not have one'
    mode: 'All'
    policyRule: {
      if: {
        allOf: [
          {
            field: 'type'
            equals: 'Microsoft.Resources/subscriptions/resourceGroups'
          }
          {
            field: 'tags[\'CreatedOn\']'
            exists: false
          }
        ]
      }
      then: {
        effect: 'append'
        details: [
          {
            field: 'tags[\'CreatedOn\']'
            value: '[utcNow()]'
          }
        ]
      }
    }
  }
}

resource policyAssignmentAddCreatedOnTag 'Microsoft.Authorization/policyAssignments@2024-04-01' = {
  name: 'Resource Group Add CreatedOn Tag'
  properties: {
    displayName: 'Resource Group Add CreatedOn Tag'
    policyDefinitionId: policyAddCreatedOnTag.id
  }
}

resource resourceGroup 'Microsoft.Resources/resourceGroups@2024-07-01' = {
  name: 'BAMI_CostManagement_DO_NOT_DELETE'
  location: location
  tags: {
    DoNotDelete: ''
  }
}

module resources 'resources.bicep' = {
  name: 'resources'
  scope: resourceGroup
  params: {
    location: location
  }
}

resource groupDeleteRole 'Microsoft.Authorization/roleDefinitions@2022-04-01' = {
  name: guid('Delete Resource Group')
  properties: {
    roleName: 'Delete Resource Group'
    type: 'CustomRole'
    description: 'Allows for the deletion of a resource group'
    assignableScopes: [
      subscription().id
    ]
    permissions: [
      {
        actions: [
          'Microsoft.Resources/subscriptions/resourceGroups/delete'
        ]
        notActions: []
      }
    ]
  }
}

resource groupDeleteRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('groupDeleteRoleAssignment')
  properties: {
    roleDefinitionId: groupDeleteRole.id
    principalId: resources.outputs.functionAppId
  }
}

resource readerRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('readerRoleAssignment')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', 'acdd72a7-3385-48ef-bd42-f606fba81ae7')
    principalId: resources.outputs.functionAppId

  }
}

resource tagContributorRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid('tagContributorRoleAssignment')
  properties: {
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions', '4a9ae827-6dc8-4573-8ac7-8239d42aa03f')
    principalId: resources.outputs.functionAppId
  }
}
