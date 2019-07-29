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
#	In this example compute, we collect information on Virutal Machines and
# 	Azure Machine Learning Service compute.
#############################################################################

# Import classes
using module ..\Modules\clsSubscription.psm1
using module ..\Modules\clsResourceGroupManager.psm1 
using module ..\Modules\clsCompute.psm1 

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null

# Filter on subscriptions by a name or partial name 
$subscriptionNameToFind="AILe"
Write-Host("Searching for:  " + $subscriptionNameToFind )
$result = $subManager.FindSubscription($subscriptionNameToFind)

# Possible to get more than one result, so....be careful.
if($result.Count -eq 1)
{
	# Set this subscription as the current subscription to work on.
	$currentSubscription = $result[0]
	$subManager.SetSubscription($currentSubscription)

	
	Write-Host("Working with subscription " + $currentSubscription.Name)

	# Create instance of Azure Compute
	$azureCompute = [AzureCompute]::new()
	$rgManager = [ResourceGroupManager]::new()

	####################################################################
	# Collect AMLS Compute cluster information
	####################################################################
	$amlsComputeDetails = $azureCompute.GetAMLSComputeVms($rgManager)
	# Call again and it returns cached information
	$amlsComputeDetails = $azureCompute.GetAMLSComputeVms($rgManager)
	$amlsSummary = $azureCompute.GetAMLSSummary($rgManager)

	####################################################################
	# Collect standard VM information
	####################################################################
	$virtualMachines = $azureCompute.GetVirtualMachines($null,$null)
	# Call again and it returns cached information
	$virtualMachines = $azureCompute.GetVirtualMachines($null,$null)
	$vmSummary = $azureCompute.GetVirtualMachineSummary($null,$null)
	
	
	####################################################################
	# Get a listing of ONLY GPU machines
	####################################################################
	$gpuMachines = $azureCompute.GetVirtualMachines($null,'*nc*')
	
	Write-Host("AMLS Summary:")
	Write-Host(($amlsSummary | ConvertTo-Json -depth 100))
	Write-Host("")
	Write-Host("")
	Write-Host("VirtualMachine Summary:")
	Write-Host(($vmSummary | ConvertTo-Json -depth 100))

	foreach($amlsDetails in $amlsComputeDetails)
	{
		Write-Host("")
		Write-Host("")
		Write-Host("AMLS Workspace Details")
		Write-Host(($amlsDetails|ConvertTo-Json -depth 100))
	}

	Write-Host("")
	Write-Host("")
	Write-Host("Virtual Machines:")
	Write-Host(($virtualMachines | ConvertTo-Json -depth 100))

	Write-Host("")
	Write-Host("")
	Write-Host("GPU Virtual Machines:")
	Write-Host(($gpuMachines | ConvertTo-Json -depth 100))
}