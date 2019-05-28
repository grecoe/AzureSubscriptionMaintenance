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
	Script that tallys across all subscriptions, the number of resource groups 
	in total, and the number that actually have tags applied to them.
	
	$in is the file name of the subscription json file created by _CMP01_CollectSubs.ps1

#>
Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$in
)

$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

$totalSubs=0
$expectedTags = @('alias', 'project', 'expires')

$subManager = [SubscriptionManager]::new()

$overallInformation = @{}

foreach($sub in $subList.PSObject.Properties)
{
	$totalSubs++
	Write-Host("Name: " + $sub.Name)
	Write-Host("ID: " + $sub.Value)

	$result = $subManager.FindSubscriptionById($sub.Value)
	
	if($result.Count -eq 1)
	{
		$subGroups=0
		$subUntagged=0
		$untaggedSubInformation = New-Object System.Collections.ArrayList

		$currentSubscription = $result[0]
		
		$subManager.SetSubscription($currentSubscription)
		$resourceGroupManager = [ResourceGroupManager]::new()
		
		Write-Host("Processing groups for " + $sub.Name)
		
		foreach($group in $resourceGroupManager.ResourceGroups)
		{
			if($resourceGroupManager.IsSpecialGroup($group.Name) -eq $false)
			{
				$subGroups++
				$missing = $group.FindMissingTags($expectedTags)

				if($missing.Count -gt 0)
				{
					$untaggedSubInformation.Add($group.Name) > $null
					$subUntagged++
				}
			}
		}

		$subResults = New-Object PSObject -Property @{ 
			Total = $subGroups
			Untagged  = $subUntagged
			Groups = $untaggedSubInformation
		}

		$overallInformation.Add($sub.Name, $subResults)
	}
}

Write-Host("Total Subs: " + $totalSubs)

$outputData = $overallInformation | ConvertTo-Json -depth 100
$outputFile = '.\TagComplianceOverview.json'
Out-File -FilePath $outputFile -InputObject $outputData
