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
    Script used to shut down all compute EXCEPT DataBricks or AKS cluster machines.
#>

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsCompute.psm1
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


$generalLogger = [Logger]::new( 'Overview.txt', "ComputeShutDown")

foreach($sub in $subList)
{
	$generalLogger.AddContent($sub.SubscriptionId + " " + $sub.SubscriptionName)

	# Perform a login prior to calling this, first call collects the subscriptions.
	$subManager = [SubscriptionManager]::new()
	$currentSubscription = $null
	
	# Get the subscription by id 
	$result = $subManager.FindSubscriptionById($sub.SubscriptionId)
	
	# Possible to get more than one result, so....be careful.
	if($result.Count -eq 1)
	{
		$logger = [Logger]::new( $sub.SubscriptionName + '.txt', "ComputeShutDown")

		# Set this subscription as the current subscription to work on.
        $currentSubscription = $result[0]
        $subManager.SetSubscription($currentSubscription)

        $compute = [AzureCompute]::new()
        $vmList = $compute.GetVirtualMachines($null, $null)

		$generalLogger.AddContent(" Number of machines found : " + $vmList.Count)
		
        foreach($vm in $vmList)
        {
            if($vm.Running -eq $true)
            {
                if( ($vm.ResourceGroup -like "databricks-*") -or 
                    ($vm.ResourceGroup -like 'MC_*'))
                {
                    $logger.AddContent("Ignoring Cluster Machine: " + $vm.ResourceGroup + "/" + $vm.MachineName)
				}
				elseif($sub.ExclusionList.Contains($vm.ResourceGroup.ToLower()) -eq $true)
				{
                    $logger.AddContent("Ignoring Excluded Resource Group - Machine: " + $vm.ResourceGroup + "/" + $vm.MachineName)
				}
                else 
                {
                    $logger.AddContent("Shutting down " + $vm.ResourceGroup + "/" + $vm.MachineName)
                    #$vm.Stop($true)
                }
    
            }
		}   
		
		$logger.Flush()
	}
	else {
		$generalLogger.AddContent($sub.SubscriptionId + " not found")
	}
}

$generalLogger.Flush()
Write-Host("Shutdown Script Complete!")
