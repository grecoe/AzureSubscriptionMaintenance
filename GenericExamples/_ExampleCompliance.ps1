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

#############################################################################
#	In this example compliance, we look at ONLY unlocked resource groups.
#	If the group does not contain ALL of the following tags, it is deleted:
#	
#	Tags: alias, project, expires
#############################################################################

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null
$expectedTags = @('alias', 'project', 'expires')

# Filter on subscriptions by a name or partial name 
$subscriptionNameToFind="DevOps"
Write-Host("Searching for:  " + $subscriptionNameToFind )
$result = $subManager.FindSubscription($subscriptionNameToFind)

# Possible to get more than one result, so....be careful.
if($result.Count -eq 1)
{
	$currentSubscription = $result[0]
	
	Write-Host("Working with subscription " + $currentSubscription.Name)
	
	# Set this subscription as the current subscription to work on.
	$subManager.SetSubscription($currentSubscription)
	$resourceGroupManager = [ResourceGroupManager]::new()

	# Get a list of all the resource groups in buckets.
	$groupBuckets = $resourceGroupManager.GetGroupBuckets()
	
	# Only unlocked groups AND only ones that have no tags. 
	$uncompliantGroups = New-Object System.Collections.ArrayList
	
	foreach($unlockedGroup in $groupBuckets.Unlocked)
	{
		Write-Host("Unlocked Group: " + $unlockedGroup)
		$ugroup = $resourceGroupManager.GetGroup($unlockedGroup)
		if($ugroup)
		{
			$missing = $ugroup.FindMissingTags($expectedTags)

			if($missing.Count -gt 0)
			{
				# This is where a delete would occur.
				#$ugroup.Delete()
				$uncompliantGroups.Add($unlockedGroup) > $null
			}
		}
	}
	
	Write-Host("Unlocked Groups:")
	Write-Host(($groupBuckets.Unlocked | ConvertTo-Json))
	Write-Host("NonCompliant Groups:")
	Write-Host(($uncompliantGroups | ConvertTo-Json))
}