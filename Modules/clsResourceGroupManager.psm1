<#	
	Copyright  Microsoft Corporation ("Microsoft").
	
	Microsoft grants you the right to use this software in accordance with your subscription agreement, if any, to use software 
	provided for use with Microsoft Azure ("Subscription Agreement").  All software is licensed, not sold.  
	
	If you do not have a Subscription Agreement, or at your option if you so choose, Microsoft grants you a nonexclusive, perpetual, 
	royalty-free right to use and modify this software solely for your internal business purposes in connection with Microsoft Azure 
	and other Microsoft products, including but not limited to, Microsoft R Open, Microsoft R Server, and Microsoft SQL Server.  
	
	Unless otherwise stated in your Subscription Agreement, the following applies.  THIS SOFTWARE IS PROVIDED "AS IS" WITHOUT 
	WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL MICROSOFT OR ITS LICENSORS BE LIABLE 
	FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
	TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
	HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
	NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THE SAMPLE CODE, EVEN IF ADVISED OF THE
	POSSIBILITY OF SUCH DAMAGE.
#>

using module .\clsResources.psm1
using module .\clsSubscription.psm1

#############################################################################
#	When the user issues the call to ResourceGroupManager::GetGroupDetails
#	This is used to determine if a group is managed by another group.
#############################################################################
class GroupDetails {
	[string]$ManagedBy	
	[string]$ManagedByResourceGroup
	[System.Collections.HashTable]$Properties
	
	GroupDetails()
	{
		$this.Properties = New-Object System.Collections.HashTable
	}
}


#############################################################################
#	Class that contains information about an individual resource group 
#	with additional functionality to work with the group.
#		[System.Collections.ArrayList]FindMissingTags($expectedTagArray)
#		[void] ModifyTags($newTagHashTable)
#		[void] Unlock()
#		[void] Delete()
#		[bool] OlderThan60Days() WARNING this takes some time.
#############################################################################
class ResourceGroup{
    [string]$Id
    [string]$Name
    [string]$Location
    [System.Collections.HashTable]$Tags
    [System.Collections.HashTable]$Locks
	
	ResourceGroup(){
		$this.Tags = @{}
		$this.Locks = @{}
	}
	
	#########################################################################
	#	Compare tags against an array of tag names being passed in. Returns
	#	a list of expected tags that are not there.
	#########################################################################
	[System.Collections.ArrayList]FindMissingTags($expectedTagArray){
		$returnTable = New-Object System.Collections.ArrayList
		foreach($expectedTag in $expectedTagArray)
		{
			if($this.Tags.ContainsKey($expectedTag) -eq $false)
			{
				$returnTable.Add($expectedTag) > $null
			}
		}
		
		return $returnTable
	}
	
	#########################################################################
	#	Move a resource group to another group inside same subscrition or 
	#	another subscription. 
	#	https://docs.microsoft.com/en-us/azure/virtual-machines/windows/move-vm
	#	https://social.msdn.microsoft.com/Forums/en-US/dfffb059-3c64-4438-aa39-4ad2c7fbd3dc/unable-to-move-resource-groups-to-another-subscription-because-of-plan?forum=DataMarket
	#	https://docs.microsoft.com/en-us/azure/azure-resource-manager/resource-group-move-resources#services-that-do-not-enable-move
	#########################################################################
	[void] Move([string]$destinationGroup, [Subscription]$destinationSubscription)
	{
		$resourceIdList = New-Object System.Collections.ArrayList
		$groupResources = [AzureResources]::GetGroupResources($this.Name)
		foreach($key in $groupResources.Keys)
		{
			if($groupResources[$key].ContainsKey("ResourceId"))
			{
				$resourceIdList.Add($groupResources[$key]["ResourceId"]) > $null
			}
		}
		
		if($resourceIdList.Count -gt 0)
		{
			$command = $null
			$resourceMoveList = $resourceIdList -join ","
			
			if($destinationSubscription)
			{
				$command = "Move-AzureRmResource -DestinationSubscriptionId " + $destinationSubscription.Id + " -DestinationResourceGroupName " + $destinationGroup + " -ResourceId " + $resourceMoveList
			}
			else
			{
				$command = "Move-AzureRmResource -DestinationResourceGroupName " + $destinationGroup + " -ResourceId " + $resourceMoveList
			}
			
			$expression = $command + ' -confirm:$false'

			Write-Host("Executing: " + $expression)
			$result = Invoke-Expression $expression
			Write-Host(($result | ConvertTo-Json -depth 100))
		}
	}	
	
	#########################################################################
	#	Input is a hash table of tagName, tagValue. To clear tags, empty
	# 	the Tags field on this before calling and pass in null. Otherwise,
	#	you can modify the existing tags or add new ones. 
	#########################################################################
	[void] ModifyTags($newTagHashTable)
	{
		$tagsList = New-Object System.Collections.ArrayList

		# Get the existing tags
		if($this.Tags.Count -gt 0)
		{
			Write-Host("Obtaining existing tags ...")
			$this.Tags.Keys | Foreach { $tagsList.Add($_ +"='" + $this.Tags[$_] +"'") > $null }
		}

		# Get any new tags
		if($newTagHashTable)
		{
			$newTagHashTable.Keys | Foreach { $tagsList.Add($_ +"='" + $newTagHashTable[$_] +"'") > $null }
		}

		# Create teh update statement for tags.
		$tagInput = $null
		foreach($tag in $tagsList)
		{	
			$tagInput += " " + $tag
		}
	
		Write-Host("Updating " + $this.Name + " with new tag list " + $tagInput)
		$commandString = "az group update -n " + $this.Name + " --tags " + $tagInput
		Invoke-Expression $commandString
	}
	
	#########################################################################
	#	Remove any readonly or delete lock from a resource group.
	#########################################################################
	[void] Unlock(){
		if($this.Locks.Count -gt 0)
		{
			$rgLocks = Get-AzureRmResourceLock -ResourceGroupName $this.Name
			if($rgLocks)
			{
				foreach($lock in $rgLocks)
				{
					$result = Remove-AzureRmResourceLock -Force -LockId $lock.LockId
				}
			}
		}
	}
	
	#########################################################################
	#	Delete the resource group ONLY if it's unlocked.
	#########################################################################
	[void] Delete(){
	
		if($this.Locks.Count -eq 0)
		{
			Remove-AzureRmResourceGroup -Force -Name $this.Name
		}
	}
	
	#########################################################################
	#	Determine if a group is > 60 days old. 
	#########################################################################
	[bool] OlderThan60Days()
	{
		Write-Host("Checking age of " + $this.Name)
		
		$returnValue = $false
		$resources = Get-AzureRmResource -ResourceGroupName $this.Name
		
		$pointInTime = [DateTime]::Now.AddDays(-60)
		$horizon = $pointInTime.AddDays(-15)
	
		foreach($res in $resources)
		{
			$logs = Get-AzureRmLog -StartTime $horizon -EndTime $pointInTime -Status "Succeeded" -ResourceId $res.ResourceId -WarningAction "SilentlyContinue" `
			
			if($logs.Count -gt 0)
			{
				$returnValue = $true
				break
			}
		}
	
		return $returnValue
	}
}

#############################################################################
#	Returned from ResourceGroupManager::GetGroupBuckets
#############################################################################
class GroupBuckets{
    [System.Collections.ArrayList]$DeleteLocked
    [System.Collections.ArrayList]$ReadOnlyLocked
    [System.Collections.ArrayList]$Unlocked
    [System.Collections.ArrayList]$Special
	
	GroupBuckets(){
		$this.DeleteLocked = New-Object System.Collections.ArrayList
		$this.ReadOnlyLocked = New-Object System.Collections.ArrayList
		$this.Unlocked = New-Object System.Collections.ArrayList
		$this.Special = New-Object System.Collections.ArrayList
	}
}

#############################################################################
#	Returned from ResourceGroupManager::GetGroupSummary
#############################################################################
class GroupSummary{
	[int]$TotalGroups
	[int]$LockedGroups
	[int]$OldGroups
    [System.Collections.HashTable]$GroupDeployments
	
	GroupSummary(){
		$this.GroupDeployments = New-Object System.Collections.HashTable
	}
}

#############################################################################
#	Manager object to load and manage resource groups across a subscription.
#	This should be instantiated AFTER the subscription has been set. 
#		[ResourceGroup] GetGroup([String]$groupName)
#		[GroupDetails] GetGroupDetails([String]$groupName)
#		[GroupBuckets] GetGroupBuckets()
#############################################################################
class ResourceGroupManager {
	[System.Collections.ArrayList]$ResourceGroups=$null

	ResourceGroupManager()
	{
		$this.ClearCache()
	}
	
	###############################################################
	# Clear the internals if you switch subscriptions so that the
	# correct information will be returned.
	###############################################################
	[void] ClearCache() {
		$this.ResourceGroups = New-Object System.Collections.ArrayList
		$this.CollectResourceGroups()
	}

	#########################################################################
	#	Get an individual ResourceGroup based on name.
	#########################################################################
	[ResourceGroup] GetGroup([String]$groupName){
		$returnGroup = $null
		
		$groups = $this.ResourceGroups | Where-Object { $_.Name -eq $groupName}
		if($groups -and ($groups.Count -eq 1))
		{
			$returnGroup = $groups[0]
		}
		
		return $returnGroup
	}
	
	#########################################################################
	#	Get group(s) using a name pattern for -like, may return >1
	#########################################################################
	[System.Collections.ArrayList] FindGroup([String]$groupNamePattern){
		$returnGroup = New-Object System.Collections.ArrayList
		
		$groups = $this.ResourceGroups | Where-Object { $_.Name -like $groupNamePattern}
		foreach($group in $groups)
		{
			$returnGroup.Add($group)
		}
		
		return $returnGroup
	}

	#########################################################################
	#	Get group(s) using an alias, may return >1
	#########################################################################
	[System.Collections.ArrayList] FindGroupByOwner([String]$aliasValue){
		$returnGroup = New-Object System.Collections.ArrayList
		
		$groups = $this.ResourceGroups | Where-Object { $_.Tags.ContainsKey('alias') -and ($_.Tags['alias'] -eq $aliasValue)}
		foreach($group in $groups)
		{
			$returnGroup.Add($group)
		}
		
		return $returnGroup
	}

	#########################################################################
	#	Get group(s) using an alias, may return >1
	#########################################################################
	[System.Collections.ArrayList] FindGroupWithTag([String]$tagName){
		$returnGroup = New-Object System.Collections.ArrayList
		
		$groups = $this.ResourceGroups | Where-Object { $_.Tags.ContainsKey($tagName)}
		foreach($group in $groups)
		{
			$returnGroup.Add($group)
		}
		
		return $returnGroup
	}

	#########################################################################
	#	Get more details on a resource group
	#########################################################################
	[GroupDetails] GetGroupDetails([String]$groupName){
		$returnDetails=[GroupDetails]::new()
		
		$rgObject = (az group show -g $groupName) | ConvertFrom-Json
		
		if($rgObject)
		{
			$managedByGroup=$null
			if($rgObject.managedBy)
			{
				$resourceObject = (az resource show --ids $rgObject.managedBy) | ConvertFrom-Json
				$managedByGroup = $resourceObject.resourceGroup
				
				$returnDetails.ManagedBy = $rgObject.managedBy
				$returnDetails.ManagedByResourceGroup = $managedByGroup
				
				$rgObject.Properties.PSObject.Properties | Foreach { $returnDetails.Properties[$_.Name] = $_.Value }
			}
		}
		return returnDetails
	}
	
	#########################################################################
	#	Get the resource groups broken into buckets.
	#########################################################################
	[GroupBuckets] GetGroupBuckets()
	{
		$returnBuckets = [GroupBuckets]::new()
		foreach($group in $this.ResourceGroups)
		{
			if($this.IsSpecialGroup($group.Name))
			{
				$returnBuckets.Special.Add($group.Name) > $null
			}
			elseif($group.Locks.Count -gt 0)
			{
				foreach($lockName in $group.Locks.Keys)
				{	
					if($group.Locks[$lockName] -like "CanNotDelete")
					{
						$returnBuckets.DeleteLocked.Add($group.Name) > $null
					}
					elseif($group.Locks[$lockName] -like "ReadOnly")
					{
						$returnBuckets.ReadOnlyLocked.Add($group.Name) > $null
					}
				}
			}
			else
			{
				$returnBuckets.Unlocked.Add($group.Name) > $null
			}
		}
		return $returnBuckets
	}
	
	#########################################################################
	#	Gets a summary of the current resource groups.
	#########################################################################
	[GroupSummary] GetGroupSummary(){
		$returnSummary = [GroupSummary]::new()
		
		foreach($rgroup in $this.ResourceGroups)
		{
			$returnSummary.TotalGroups += 1
			
			if($rgroup.Locks.Count -gt 0)
			{
				$returnSummary.LockedGroups += 1
			}
			
			if($rgroup.OlderThan60Days())
			{
				$returnSummary.OldGroups += 1
			}
			
			if($returnSummary.GroupDeployments.ContainsKey($rgroup.Location))
			{
				$returnSummary.GroupDeployments[$rgroup.Location] += 1
			}
			else
			{
				$returnSummary.GroupDeployments.Add($rgroup.Location,1)
			}
		}
		
		return $returnSummary
	}
	
	## PSUEDO PRIVATE
	
	
	#########################################################################
	#	Collect all resource groups into the internal $ResourceGroups param.
	#	This does NOT clear that list first, and is called from the constructor.
	#########################################################################
	hidden [void] CollectResourceGroups()
	{
		Write-Host("Collecting Resource Groups")

		$foundRgs = Get-AzureRmResourceGroup

		foreach($group in $foundRgs)
		{
			[ResourceGroup]$newGroup = [ResourceGroup]::new()
			$newGroup.Name = $group.ResourceGroupName
			$newGroup.Location = $group.Location
			$newGroup.Id = $group.ResourceId
			
			if($group.Tags)
			{
				foreach($key in $group.Tags.Keys)
				{
					$newGroup.Tags.Add($key, $group.Tags[$key])
				}
			}

			$locks = Get-AzureRmResourceLock -ResourceGroupName $group.ResourceGroupName
			if($locks)
			{
				$foundlocks = New-Object System.Collections.ArrayList
				if($locks.Length -gt 0)
				{
					foreach($lock in $locks)
					{	
						$foundlocks.Add($lock) > $null
					}
				}
				else
				{
					$foundlocks.Add($locks) > $null
				}
			
				# It has a lock either ReadOnly or CanNotDelete so it has to 
				# be marked as locked.
				foreach($lock in $foundlocks)
				{
					$properties = $lock.Properties | ConvertTo-Json
					$propobject = ConvertFrom-Json -InputObject $properties
					$lockType = $propobject.psobject.properties["level"].value
					$newGroup.Locks.Add($lock.LockId, $lockType)
				}
			}
			
			$this.ResourceGroups.Add($newGroup) > $null
		}
	}

	#########################################################################
	#	Determines if a group name matches a default Azure RG name.
	#########################################################################
	hidden [bool] IsSpecialGroup([string]$groupName){
		$return = $false
		if($groupName.Contains("cleanup") -or
			$groupName.Contains("Default-Storage-") -or
			( $groupName.Contains("DefaultResourceGroup-") -or
				$groupName.Contains("Default-MachineLearning-") -or
				$groupName.Contains("cloud-shell-storage-") -or
				$groupName.Contains("Default-ServiceBus-") -or
				$groupName.Contains("Default-Web-") -or
				$groupName.Contains("OI-Default-") -or
				$groupName.Contains("Default-SQL") -or
				$groupName.Contains("StreamAnalytics-Default-") -or
				$groupName.Contains("databricks-") -or
				$groupName.Contains("fileserverrg-") -or
				$groupName.Contains("NetworkWatcherRG") -or
				$groupName.Contains("Default-ApplicationInsights-") -or
				$groupName.StartsWith("VS-") -or
				($groupName -like 'MC_*')
				)
			)
		{
			$return = $true
		}
		
		return $return
	}
}