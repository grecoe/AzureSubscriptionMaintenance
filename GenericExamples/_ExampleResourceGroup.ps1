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
#	In this example we will collect information Resource groups 
#	in a specific subscription.
#############################################################################

# Import the correct class modules
Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null

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

	# Uncomment this code and change the group name from unknowngroup
	# to remove all locks from the group (if it's found)
	<#
	$testGroup = $resourceGroupManager.GetGroup('unknowngroup')
	if($testGroup)
	{
		# unlock it, find missing tags, or modify the tags in Azure 
		$testGroup.Unlock()
	}
	#>
	
	# Get a list of all the resource groups in buckets.
	$groupBuckets = $resourceGroupManager.GetGroupBuckets()
	Write-Host("Group Buckets")
	Write-Host(($groupBuckets | ConvertTo-Json))

	# Get a summary of all the resource groups.
	$groupSummary = $resourceGroupManager.GetGroupSummary()
	Write-Host("Group Summary")
	Write-Host(($groupSummary | ConvertTo-Json))
}