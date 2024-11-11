$resourceGroupName = "BAMI_CostManagement_DO_NOT_DELETE"            # <-- REPLACE the variable values with your own values.
$location = "centralus"                 # <-- Ensure that the location is a valid Azure location
$storageAccountName = "bamicostmanagement8dc0"           # <-- Ensure the storage account name is unique
$appServicePlanName = "ASP-BAMICostManagement-bb9b"   # <--
$appInsightsName = "bamiResourceActionsDev"              # <--
$functionName = "bamiResourceActions"                 # <--
$eventGridSubscriptionName = "ResourceCreation"

New-AzResourceGroup -Name $resourceGroupName -Location $location -Force -Verbose

$params = @{
    storageAccountName = $storageAccountName.ToLower()
    appServicePlanName = $appServicePlanName
    appInsightsName    = $appInsightsName
    functionName       = $functionName
    eventGridSubscriptionName = $eventGridSubscriptionName
}

$output = New-AzResourceGroupDeployment -ResourceGroupName $resourceGroupName -TemplateFile .\azuredeploy.json -TemplateParameterObject $params -Verbose

Push-Location
Set-Location ..\functions
Compress-Archive -Path * -DestinationPath ..\environment\functions.zip -Force -Verbose
Pop-Location

$file = (Get-ChildItem .\functions.zip).FullName

Publish-AzWebApp -ResourceGroupName $resourceGroupName -Name $functionName -ArchivePath $file -Verbose -Force

Remove-Item $file -Force
