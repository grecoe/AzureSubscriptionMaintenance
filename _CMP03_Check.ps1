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
	[string]$subName
)

function GetGroupInformation{
	Param([System.Collections.ArrayList]$groupBucket,
		  [SubscriptionManager]$subManager,
		  [string]$description
	)
	$untaggedList = New-Object System.Collections.ArrayList
	$returnList = New-Object System.Collections.ArrayList
	
	$totalInGroup=0
	$untaggedInGroup=0
	
	foreach($group in $groupBucket)
	{
		$totalInGroup++
		$currentGroup = $resourceGroupManager.GetGroup($group)
		if($currentGroup)
		{
			$missing = $currentGroup.FindMissingTags($expectedTags)

			if($missing.Count -gt 0)
			{
				$untaggedInGroup++
				# This is where a delete would occur.
				#$currentGroup.Delete()
				$untaggedList.Add($currentGroup.Name) > $null
			}
		}
	}
	
	$returnList.Add("Description : " + $description) > $null
	$returnList.Add("Total : " + $totalInGroup.ToString()) > $null
	$returnList.Add("Untagged: " + $untaggedInGroup.ToString()) > $null
	$returnList.AddRange($untaggedList)
	
	$returnList
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
			# Collect the buckets of groups
			$groupBuckets = $resourceGroupManager.GetGroupBuckets()
			
			# Create arrays for the results for each processing step
			$unlockedUntagged = New-Object System.Collections.ArrayList
			$delLockedUntagged = New-Object System.Collections.ArrayList
			$roLockedUntagged = New-Object System.Collections.ArrayList
			
			# Process each group
			Write-Host("Processing unlocked groups.....")
			$unlockedUntagged = GetGroupInformation -groupBucket $groupBuckets.Unlocked -subManager $subManager -description "Unlocked and un-tagged resource groups will be deleted on XXXX"
			Write-Host("Processing delete locked groups.....")
			$delLockedUntagged = GetGroupInformation -groupBucket $groupBuckets.DeleteLocked -subManager $subManager -description "Delete Locked and un-tagged resource groups will be unlocked and deleted on on XXXX"
			Write-Host("Processing read only locked groups.....")
			$roLockedUntagged = GetGroupInformation -groupBucket $groupBuckets.ReadOnlyLocked -subManager $subManager -description "Readonly Locked and un-tagged resource groups will be unlocked and deleted on on XXXX"

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
		}
		else
		{
			Write-Host("******** Unable to get resource group manager: " + $subName)
		}
	
	}
}