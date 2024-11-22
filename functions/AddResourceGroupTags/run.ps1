param($eventGridEvent, $TriggerMetadata)

$caller = $eventGridEvent.data.claims.name
if ($null -eq $caller) {
    if ($eventGridEvent.data.authorization.evidence.principalType -eq "ServicePrincipal") {
        $caller = (Get-AzADServicePrincipal -ObjectId $eventGridEvent.data.authorization.evidence.principalId).DisplayName
        if ($null -eq $caller) {
            Write-Host "MSI may not have permission to read the applications from the directory"
            $caller = $eventGridEvent.data.authorization.evidence.principalId
        }
    }
}

Write-Host "Caller: $caller"
$resourceId = $eventGridEvent.data.resourceUri
Write-Host "ResourceId: $resourceId"

if (($null -eq $caller) -or ($null -eq $resourceId)) {
    Write-Host "ResourceId or Caller is null"
    exit;
}

#Write-Host "Try add Creator tag with user: $caller"

$callerTag = @{
    Creator = $caller
}

$email = $eventGridEvent.data.claims.'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress'
$emailTag = @{
    Email = $email
}

$tags = (Get-AzTag -ResourceId $resourceId)

if ($tags) {
    # Tags supported?
    if ($tags.properties) {
        # if null no tags?
        if ($tags.properties.TagsProperty) {
            if (!($tags.properties.TagsProperty.ContainsKey('Creator')) ) {
                Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $callerTag | Out-Null
                Write-Host "Added Creator tag with user: $caller"
            }
            else {
                Write-Host "Creator tag already exists"
            }
        }
        else {
            Write-Host "Added Creator tag with user: $caller"
            New-AzTag -ResourceId $resourceId -Tag $callerTag | Out-Null
        }

        if (!($tags.properties.TagsProperty.ContainsKey('Email')) ) {
            Update-AzTag -ResourceId $resourceId -Operation Merge -Tag $emailTag | Out-Null
            Write-Host "Added Email tag with user: $email"
        }
        else {
            Write-Host "Email tag already exists"
        }
    }
    else {
        Write-Host "WARNNG! Does $resourceId not support tags? (`$tags.properties is null)"
    }
}
else {
    Write-Host "$resourceId does not support tags"
}
