<#
	Script that tallys across all subscriptions, the number of resource groups 
	in total, and the number that actually have tags applied to them.
	
	$in is the file name of the subscription json file created by _CMP01_CollectSubs.ps1

#>
Using module .\clsSubscription.psm1
Using module .\clsResourceGroupManager.psm1

#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$in
)

$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

$totalSubs=0
$totalGroups=0
$untaggedGroups=1
$expectedTags = @('alias', 'project', 'expires')

$subManager = [SubscriptionManager]::new()

foreach($sub in $subList.PSObject.Properties)
{
	$totalSubs++
	Write-Host("Name: " + $sub.Name)
	Write-Host("ID: " + $sub.Value)

	$result = $subManager.FindSubscriptionById($sub.Value)
	
	if($result.Count -eq 1)
	{
		$currentSubscription = $result[0]
		
		$subManager.SetSubscription($currentSubscription)
		$resourceGroupManager = [ResourceGroupManager]::new()
		
		foreach($group in $resourceGroupManager.ResourceGroups)
		{
			$totalGroups++
			
			$missing = $group.FindMissingTags($expectedTags)

			if($missing.Count -gt 0)
			{
				$untaggedGroups++
			}
		}
	}
}
Write-Host("Total Subs: " + $totalSubs)
Write-Host("Total Groups: " + $totalGroups)
Write-Host("Untagged Groups: " + $untaggedGroups)
