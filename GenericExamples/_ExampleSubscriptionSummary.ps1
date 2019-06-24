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
$subscriptionNameToFind="Tao"
$result = $subManager.FindSubscription($subscriptionNameToFind)


function GetVmBucket {
	param( [System.String] $resourceGroupName)

	$bucketType = "Standard"
	if( $resourceGroupName -like "databricks-*")
	{
		$bucketType = "DataBricks"
	} 
	elseif( $resourceGroupName -like "MC_*")
	{
		$bucketType = "AKS"
	} 
	elseif($resourceGroupName -like "FILESERVERRG-*")
	{
		$bucketType = "FileServer"
	}

	$bucketType
}

function ParseVirtualMachines {
	param( [System.Collections.ArrayList] $vmList)

	$vmSummary = @{}
	$vmSummary["Total"] = 0
	$vmSummary["Running"] = 0
	$vmSummary["Stopped"] = 0
	$vmSummary["Deallocated"] = 0
	$vmSummary["StandardShutdown"] = 0
	$vmSummary["Use"] = @{}
	$vmSummary["Use"]["Standard"] = 0
	$vmSummary["Use"]["DataBricks"] = 0
	$vmSummary["Use"]["AKS"] = 0
	$vmSummary["Use"]["FIleServer"] = 0

	foreach($vm in $vmList)
	{
		$vmSummary["Total"] += 1
		if($vm.Running)
		{
			$vmSummary["Running"] += 1
		}
		elseif($vm.Stopped)
		{
			$vmSummary["Stopped"] += 1
		}
		elseif($vm.Deallocated)
		{
			$vmSummary["Deallocated"] += 1
		}

		$usageType = GetVmBucket -resourceGroupName $vm.ResourceGroup
		$vmSummary["Use"][$usageType] += 1

		if( ($usageType -eq "Standard") -and ($vm.ShutdownSchedule -eq $true))
		{
			$vmSummary["StandardShutdown"] += 1
		}
	}

	$vmSummary
}

function ParseAmlsCompute {
	param( [System.Collections.ArrayList] $amlsWorkspaceList)

	$amlsComputeSummary = @{}
	$amlsComputeSummary["Total"] = 0
	$amlsComputeSummary["Running"] = 0
	$amlsComputeSummary["Workspaces"] = @{}

	foreach($workspace in $amlsWorkspaceList)
	{
		foreach($cluster in $workspace.Clusters)
		{
			$amlsComputeSummary["Total"] += $cluster.MaxNodes
			$amlsComputeSummary["Running"] += $cluster.CurrentNodes

			if($amlsComputeSummary["Workspaces"].ContainsKey($workspace.Workspace) -eq $false)
			{
				$amlsComputeSummary["Workspaces"].Add($workspace.Workspace, @{})
			}

			$clusterToUseName = $cluster.ComputeName
			if($amlsComputeSummary["Workspaces"][$workspace.Workspace].ContainsKey($clusterToUseName))
			{
				$clusterToUseName += "-" + $workspace.ResourceGroup
			}

			$amlsComputeSummary["Workspaces"][$workspace.Workspace].Add($clusterToUseName, @{})
			$amlsComputeSummary["Workspaces"][$workspace.Workspace][$clusterToUseName].Add("Type", $cluster.ComputeType)
			if($cluster.ComputeType -eq "AKS"){
				$aksNodes = "Unknown"
				if($cluster.AksClusterSummary -ne $null)
				{
					$aksNodes = $cluster.AksClusterSummary.RunningTotal + $cluster.AksClusterSummary.StoppedTotal + $cluster.AksClusterSummary.DeallocatedTotal
				}
				$amlsComputeSummary["Workspaces"][$workspace.Workspace][$clusterToUseName].Add("AksNodes", $aksNodes)
			}
			else {
				$amlsComputeSummary["Workspaces"][$workspace.Workspace][$clusterToUseName].Add("AmlsMaxNodes", $cluster.MaxNodes)
				$amlsComputeSummary["Workspaces"][$workspace.Workspace][$clusterToUseName].Add("AmlsMinNodes", $cluster.MinNodes)
			}
		}
	}

	$amlsComputeSummary
}

function ParseResourceGroups {
	param( [ResourceGroupManager] $rgManager)

	$complianceTags = @('alias', 'project', 'expires')

	$rgDetails = @{}
	$rgDetails["Total"] = $rgManager.ResourceGroups.Count
	$rgDetails["Special"] = 0
	$rgDetails["Resources"] = @{}

	$buckets = $rgManager.GetGroupBuckets()
	$rgDetails["Special"] = $buckets.Special.Count

	foreach($resourceGroup in $rgManager.ResourceGroups)
	{
		$missing = $resourceGroup.FindMissingTags($complianceTags)

		$rsrc = [AzureResources]::GetGroupResources($resourceGroup.Name)
		$rgDetails["Resources"][$resourceGroup.Name] = @{}
		$rgDetails["Resources"][$resourceGroup.Name]["ResourceCount"] = $rsrc.Keys.Count

		if($rgManager.IsSpecialGroup($resourceGroup.Name))
		{
			$rgDetails["Resources"][$resourceGroup.Name]["Compliant"] = "N/A - Special"
		}
		elseif($missing.Count -gt 0){
			$rgDetails["Resources"][$resourceGroup.Name]["Compliant"] = "False"
		}
		else {
			$rgDetails["Resources"][$resourceGroup.Name]["Compliant"] = "True"
		}

	}

	$rgDetails
}

$virtualMachineDetails = @{}
$amlsDetails = @{}
$resourceGroupDetails = @{}

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
	# Virtual Machine Details across sub
	####################################################################
	$virtualMachines = $azureCompute.GetVirtualMachines($null, $null)
	$virtualMachineDetails = ParseVirtualMachines -vmList $virtualMachines


	####################################################################
	# Collect AMLS Compute Information
	####################################################################
	$amlsCompute = $azureCompute.GetAMLSComputeVms($resourceGroupManager)
	$amlsDetails = ParseAmlsCompute -amlsWorkspaceList $amlsCompute

	####################################################################
	# Collect Resource Information
	####################################################################
	$resourceGroupDetails = ParseResourceGroups -rgManager $resourceGroupManager
	

	$subOverview = New-Object PSObject -Property @{
        ResourceGroups   = $resourceGroupDetails
        VirtualMachines  = $virtualMachineDetails
        AMLSCompute      = $amlsDetails
    }

	Write-Host("******************************************************")
	Write-Host("***Resource Group Summary***")
	Write-Host("******************************************************")
	Write-Host(($subOverview | ConvertTo-Json -depth 100))	

	Out-File -FilePath '.\Overview.json' -InputObject ($subOverview | ConvertTo-Json -depth 100)

	#Write-Host(($resourceGroupDetails | ConvertTo-Json -depth 100))	
	#Write-Host("***AMLS Compute***")
	#Write-Host(($amlsDetails | ConvertTo-Json -depth 100))
	#Write-Host("***Virtual Machines***")
	#Write-Host(($virtualMachineDetails | ConvertTo-Json -depth 100))
}

# Number of VMs, running, stopped, deallocated
#	in AKS
#	in databricks

# Number of Azure Compute running, stopped, deallocated

# Number of Resource Groups - Special, normal

# Number of resrouces per group