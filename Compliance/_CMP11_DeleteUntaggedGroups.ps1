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



<#
    Parameters for the script
	in - File name containing subscription list. This is modified from previous iterations It is now a list of objects
		 where each object contains SubscriptionId, SubscriptionName, ExclusionList

		 ExclusionList is a group of resource groups that should NOT be modified. 
#>
param(
	[string]$in
)

# Load the subscription list from JSON (from _CMP01_CollectSubs.ps1)
$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()

$expectedTags = @('alias', 'project', 'expires')

foreach($sub in $subList)
{
	Write-Host($sub.SubscriptionId + " " + $sub.SubscriptionName)

	# Perform a login prior to calling this, first call collects the subscriptions.
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
            foreach($group in $resourceGroupManager.ResourceGroups)
            {
                # All un-special groups MUST have the tags applied AND alias and project cannot 
                # be empty. Potential to use exclusion list here to further identify groups to 
                # preserve....
                if($resourceGroupManager.IsSpecialGroup($group.Name) -eq $false)
                {
                    $deleteOnEmptyTag = $false

                    $missing = $group.FindMissingTags($expectedTags)
                    if($missing.Count -gt 0)
                    {
                        $deleteOnEmptyTag = $true
                    }
                    else 
                    {
                        # Verify that there are values in both alias and project
                        if( ($group.Tags["alias"].Length -eq 0) -or ($group.Tags["project"].Length -eq 0))
                        {
                            $deleteOnEmptyTag = $true
                            Write-Host("Required tag is empty")
                        }
                    }

                    if($deleteOnEmptyTag -eq $true)
                    {
                        Write-Host("Delete un/under tagged group - " + $group.Name)
                        #$group.Delete()
                    }
                }
            }
        }
		else
		{
			Write-Host("******** Unable to get resource group manager: " + $subName)
		}
    
    }
}

Write-Host("Delete untagged groups script Complete!")