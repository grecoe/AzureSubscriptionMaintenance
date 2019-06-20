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
	Script used to collect the compliance information on unlocked resource groups only. 
	
	Collects information for ALL subscription unlocked resource groups for a mail. 
	
	Data will be stored in .\ComplianceCheck\Global.json
#>

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

#####################################################
# Parameters for the script
# in - File name containing subscription list
#####################################################
param(
	[string]$in
)

# Load the subscription list from JSON (from _CMP01_CollectSubs.ps1)
$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

<#
	Function to parse out the subscription bucket (unlocked)
#>
function GetGroupInformation{
	Param([System.Collections.ArrayList]$groupBucket,
		  [SubscriptionManager]$subManager,
		  [ResourceGroupManager]$resourceGroupManager,
		  [string] $subName
	)
	$untaggedList = New-Object System.Collections.ArrayList
	
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
	
	$resultsObject = New-Object PSObject -Property @{ 
			Subscription = $subName
			Total = $totalInGroup
			Untagged  = $untaggedInGroup
			Groups = $untaggedList
	}

	
	$resultsObject
}

<#
	Where the work actually occurs (and calls function above.
#>
$scanResults = New-Object System.Collections.ArrayList
$summary = @{}
foreach($sub in $subList.PSObject.Properties)
{
	$subName = $sub.Name
	$subId = $sub.Value

	# Perform a login prior to calling this, first call collects the subscriptions.
	$subManager = [SubscriptionManager]::new()
	$currentSubscription = $null
	$expectedTags = @('alias', 'project', 'expires')
	
	# Filter on subscriptions by a name or partial name 
	Write-Host("Searching for:  " + $subName )
	$result = $subManager.FindSubscriptionById($subId)
	
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
			
			# Process each group
			Write-Host("Processing unlocked groups.....")
			$subResult = GetGroupInformation -groupBucket $groupBuckets.Unlocked -subManager $subManager -resourceGroupManager $resourceGroupManager -subName $subName
			$scanResults.Add($subResult) > $null
			
			$summary.Add($subName,$subResult.Untagged)
		}
		else
		{
			Write-Host("******** Unable to get resource group manager: " + $subName)
		}
	
	}
}

$finalObject = New-Object PSObject -Property @{ 
			Summary = $summary
			Detail = $scanResults
}

$directoryName = '.\ComplianceCheck'
$fileName = $directoryName + '\GlobalCheck.json'
md -ErrorAction Ignore -Name $directoryName
Out-File -FilePath $fileName -InputObject ($finalObject | ConvertTo-Json -depth 100)

Write-Host("Contents written to: " + $fileName)
Write-Host("")
