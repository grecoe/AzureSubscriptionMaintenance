Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResources.psm1

#####################################################
# Parameters for the script
# in - File name containing subscription list
#####################################################
param(
	[string]$in
)

$subList = (Get-Content -Path $in -raw) | ConvertFrom-Json

$totalSubs=0
$subManager = [SubscriptionManager]::new()

Write-Host("Got something")

foreach($sub in $subList.PSObject.Properties)
{
	$totalSubs++
	Write-Host("Name: " + $sub.Name)
    Write-Host("ID: " + $sub.Value)

    $result = $subManager.FindSubscriptionById($sub.Value)

    if($result.Count -eq 1)
    {
        $deploy = [AzureResources]::FindDeployments("Microsoft.BatchAI/workspaces")

        Write-Host( ($deploy | ConvertTo-Json))
    }
}