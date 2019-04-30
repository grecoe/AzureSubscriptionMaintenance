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


<#
	Script used to collect the compliance information for a specific subscription. 
	
	Data will be stored in .\ComplianceCheck\[subname].json
	
	It includes information on all locked and unlocked (but not special) groups that 
	would be subject to compliance cleanup, or in general are non compliant due to 
	tags. 
#>

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1


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