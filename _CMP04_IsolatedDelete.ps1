<#
	Script used to collect the compliance information for a specific subscription. 
	
	Data will be stored in .\ComplianceCheck\[subname].json
	
	It includes information on all locked and unlocked (but not special) groups that 
	would be subject to compliance cleanup, or in general are non compliant due to 
	tags. 
#>

Using module .\clsSubscription.psm1
Using module .\clsResourceGroupManager.psm1


#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$subId,
	[string]$subName,
	[string]$rgPattern
)

function KillIsolatedGroups{
	Param([ResourceGroupManager]$resourceGroupManager,
		  [string]$pattern
	)

	$groupPattern = '*' + $pattern + '*'
	Write-Host("Search pattern : " + $groupPattern)
	$groupsInPattern = $resourceGroupManager.FindGroup($groupPattern)
	foreach($group in $groupsInPattern)
	{
		Write-Host("Target = " + $group.Name)
		$group.Delete()
	}
}

if($subId -and $subName)
{
	# Perform a login prior to calling this, first call collects the subscriptions.
	$subManager = [SubscriptionManager]::new()
	$currentSubscription = $null
	$expectedTags = @('alias', 'project', 'expires')
	
	# Filter on subscriptions by a name or partial name 
	Write-Host("Searching for:  " + $subName )
	$result = $subManager.FindSubscription($subName)
	
	# PS Special Characters in the name can cause an issue so if we don't find it, use ID.
	if($result.Count -eq 0)
	{
		$result = $subManager.FindSubscriptionById($subId)
	}
	
	# Possible to get more than one result, so....be careful.
	if($result.Count -eq 1)
	{
		$currentSubscription = $result[0]
		
		Write-Host("Working with subscription " + $currentSubscription.Name)
		
		# Set this subscription as the current subscription to work on.
		$subManager.SetSubscription($currentSubscription)
		$resourceGroupManager = [ResourceGroupManager]::new()
	
		# Get a list of all the resource groups in buckets.
		if($resourceGroupManager)
		{
			KillIsolatedGroups -resourceGroupManager $resourceGroupManager -pattern $rgPattern
			# Collect the buckets of groups

			<#
			# Create an output object, then persist it to disk.
			$resultsObject = New-Object PSObject -Property @{ 
				UnlockedUntagged = $unlockedUntagged
				DeleteLockedUntagged  = $delLockedUntagged
				ReadOnlyLockedUntagged = $roLockedUntagged
			}
			
			$directoryName = '.\ComplianceCheck'
			$fileName = $directoryName + '\' + $subName + ".json"
			md -ErrorAction Ignore -Name $directoryName
			Out-File -FilePath $fileName -InputObject ($resultsObject | ConvertTo-Json -depth 100)
			
			Write-Host("Contents written to: " + $fileName)
			Write-Host("")
			#>
		}
		else
		{
			Write-Host("******** Unable to get resource group manager: " + $subName)
		}
	
	}
}