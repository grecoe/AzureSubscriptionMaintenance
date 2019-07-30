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
    Script used to march through subscriptions and remove all locks and flush out all resources.
#>

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1
Using module ..\Modules\clsLogger.psm1



<#
    Parameters for the script
	in - File name containing subscription list. This is modified from previous iterations It is now a list of objects
		 where each object contains SubscriptionId, SubscriptionName, ExclusionList

		 ExclusionList is a group of resource groups that should NOT be modified. 

		 Format: 
		[
    		{
        		"SubscriptionId":  "ID",
        		"SubscriptionName":  "NAME",
        		"ExclusionList":  [
                		            "list of resource groups to ignore"
                        		  ]
    		},
			...
		]

#>
param(
	[string]$in
)

# Load the subscription list from JSON (from _CMP01_CollectSubs.ps1)
$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()


foreach($sub in $subList)
{
	$logger = [Logger]::new( $sub.SubscriptionName + '.txt', "SubscriptionCleanup")

	$logger.AddContent($sub.SubscriptionId + " " + $sub.SubscriptionName)

	$currentSubscription = $null
	
	# Get the subscription by id 
	Write-Host("Searching for:  " + $sub.SubscriptionName )
	$result = $subManager.FindSubscriptionById($sub.SubscriptionId)
	
	# Possible to get more than one result, so....be careful.
	if($result.Count -eq 1)
	{
        $currentSubscription = $result[0]
    
		# Set this subscription as the current subscription to work on.
		$subManager.SetSubscription($currentSubscription)
		$resourceGroupManager = [ResourceGroupManager]::new()
	
		# Get a list of all the resource groups in buckets.
		if($resourceGroupManager)
		{
            # Unlock every resource group
            foreach($group in $resourceGroupManager.ResourceGroups)
            {
				# If the group is in the exclusion list OR is a special group, bypass it 
				# for now.
				if($sub.ExclusionList.Contains($group.Name.ToLower()) -or 
				   $resourceGroupManager.IsSpecialGroup($group.Name))
				{
					$logger.AddContent("Ignoring excluded or special group - " + $group.Name)
					continue
				}

				# Remove any locks on it if they exist......
                if($group.Locks.Count -gt 0)
                {
                    $logger.AddContent("Removing locks from " + $group.Name)
                    $group.Unlock()
				}
				
				# Delete the group
				$logger.AddContent("Deleting group - " + $group.Name)
                #$group.Delete()
            }

			# Some special groups (clusters/etc) likely dissapeared in the above cleaning
			# so ensure we have the latest snapshot
			$resourceGroupManager.ClearCache()

			# Now go through them again and delete ONLY the special groups
            foreach($group in $resourceGroupManager.ResourceGroups)
            {
				# If the group is in the exclusion list OR is a special group, bypass it 
				# for now.
				if($sub.ExclusionList.Contains($group.Name) -or 
				   ($resourceGroupManager.IsSpecialGroup($group.Name) -eq $false))
				{
					$logger.AddContent("Ignoring excluded or NON-special group - " + $group.Name)
					continue
				}

				# Remove any locks on it if they exist......
                if($group.Locks.Count -gt 0)
                {
                    $logger.AddContent("Removing locks from " + $group.Name)
                    $group.Unlock()
				}
				
				# Delete the group
				$logger.AddContent("Deleting group - " + $group.Name)
                #$group.Delete()
            }

		}
		else
		{
			$logger.AddContent("******** Unable to get resource group manager: " + $subName)
		}
	}
	else {
		$logger.AddContent("Unable to find subscription : " + $sub.SubscriptionId)
	}

	$logger.Flush()
}

Write-Host("Purge Script Complete!")
