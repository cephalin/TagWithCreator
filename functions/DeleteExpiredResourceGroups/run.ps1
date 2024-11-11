# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()
$expirationDays = 21

$groups = Get-AzResourceGroup

foreach ($group in $groups)
{
    if($group.Tags.DoNotDelete -ne $null)
    {
        Write-Host "$($group.ResourceGroupName) contains DoNotDelete tag. Skipping..."
    }
    elseif ($group.Tags.CreatedOn -ne $null)
    {
        
        $difference = $currentUTCtime - (Get-Date $group.Tags.CreatedOn)
        $age = $difference.Days;
        if ($age -lt $expirationDays)
        {
            Write-Host "$($group.ResourceGroupName) with CreatedOn=$($group.Tags.CreatedOn) is $age days old (<$expirationDays). Skipping..."
        }
        else
        {
            Write-Host "$($group.ResourceGroupName) with CreatedOn=$($group.Tags.CreatedOn) is expired at $age day(s) old. Deleting..."
            Remove-AzResourceGroup -Name $group.ResourceGroupName -Force
        }
    }
}

