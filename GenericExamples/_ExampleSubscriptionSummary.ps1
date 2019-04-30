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
#	In this example we will collect information on Virutal Machines and
# 	Azure Machine Learning Service compute.
#############################################################################

# Import the correct class modules
Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResources.psm1
Using module ..\Modules\clsCompute.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null

# Filter on subscriptions by a name or partial name
$subscriptionNameToFind="DevOps"
$result = $subManager.FindSubscription($subscriptionNameToFind)

# Possible to get more than one result, so....be careful. We want to run this ONLY
# if we get a single hit on the subscription name. 
Write-Host("Searching for:  " + $subscriptionNameToFind )
if($result.Count -eq 1)
{
	# Set this subscription as the current subscription to work on.
	$currentSubscription = $result[0]
	$subManager.SetSubscription($currentSubscription)

	
	Write-Host("Working with subscription " + $currentSubscription.Name)

	# Create instance of Azure Compute
	$azureCompute = [AzureCompute]::new()
	$resourceGroupManager = [ResourceGroupManager]::new()

	####################################################################
	# Collect Compute Information
	####################################################################
	$amlsSummary = $azureCompute.GetAMLSSummary($resourceGroupManager)
	$vmSummary = $azureCompute.GetVirtualMachineSummary($null,$null)

	####################################################################
	# Collect Resource Information
	####################################################################
	$resourceList = [AzureResources]::GetAllResources()
	
	####################################################################
	# Collect Resource Group Information
	####################################################################
	$resourceGroupBuckets = $resourceGroupManager.GetGroupBuckets()
	$resourceGroupSummary = $resourceGroupManager.GetGroupSummary()

	Write-Host("***Resource Group Summary***")
	Write-Host(($resourceGroupSummary | ConvertTo-Json -depth 100))	
	Write-Host("***Resource Group Buckets***")
	Write-Host(($resourceGroupBuckets | ConvertTo-Json -depth 100))
	Write-Host("***AMLS Compute***")
	Write-Host(($amlsSummary | ConvertTo-Json -depth 100))
	Write-Host("***Virtual Machines***")
	Write-Host(($vmSummary | ConvertTo-Json -depth 100))
	Write-Host("***Resource Lists***")
	Write-Host(($resourceList | ConvertTo-Json -depth 100))

}