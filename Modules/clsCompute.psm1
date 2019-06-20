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

using module .\clsResources.psm1
using module .\clsResourceGroupManager.psm1

#############################################################################
#	Represents a single virtual machine (not in AMLS Cluster)
#############################################################################
class VirtualMachine {
	[string]$ResourceGroup 
	[string]$MachineName 
	[bool]$Running 
	[bool]$Deallocated  
	[bool]$Stopped
	[bool]$ShutdownSchedule  
	[string]$Sku 

	
	[void] Stop ([bool]$deallocate){
		if($this.Running)
		{
			if($deallocate)
			{
				$result = Stop-AzureRmVM -ResourceGroupName $this.ResourceGroup -Name $this.MachineName -Force
			}
			else
			{
				$result = Stop-AzureRmVM -ResourceGroupName $this.ResourceGroup -Name $this.MachineName -Force -StayProvisioned
			}
		}
	}
	
	[void] Start (){
		if($this.Stopped)
		{
			$result = Start-AzureRmVM -ResourceGroupName $this.ResourceGroup -Name $this.MachineName
		}
	}
}

#############################################################################
#	Represents an Azure Machine Learning Service Workspace
#############################################################################
class AMLSWorkspace {
	[string]$ResourceGroup 
	[string]$Workspace
	[string]$Details
	[System.Collections.ArrayList]$Clusters
	
	AMLSWorkspace(){
		$this.Clusters = New-Object System.Collections.ArrayList
	}
}

#############################################################################
#	Represents an cluster in a Azure Machine Learning Service Workspace
#############################################################################
class AMLSCluster {
	[string]$ComputeName 
	[string]$ComputeLocation
	[string]$ComputeType
	[string]$State
	[string]$Priority
	[string]$SKU
	[int]$CurrentNodes
	[int]$MaxNodes
	[int]$MinNodes
	[ResourceGroup]$AksClusterGroup
	[ComputeSummary]$AksClusterSummary
}

#############################################################################
#	Summary of compute resources used for both VM and AMLS Compute
#############################################################################
class ComputeSummary {
	[int]$RunningTotal
	[int]$StoppedTotal
	[int]$DeallocatedTotal
	[System.Collections.HashTable]$SkuBreakdown
	
	ComputeSummary(){
		$this.SkuBreakdown = New-Object System.Collections.HashTable
	}
}

#############################################################################
#	Auto Shutdown Schedules for Virtual Machines are a seperate, but hidden
#	resource in the resource group. THey are of type Microsoft.DevTestLab/schedule
#
#	Name appears to be shutdown-computevm-[VMNAME]
#############################################################################
class ShutdownSchedule {
	[String]$ResourceGroup
	[String]$Name
	[String]$ResourceType
}


#############################################################################
#	Utility to collect compute resources in the subscription.
#############################################################################
class AzureCompute {
	[System.Collections.HashTable]$VirtualMachines=$null
	[System.Collections.ArrayList]$AMLSCompute=$null
	[System.Collections.ArrayList]$ShutdownSchedules=$null
	
	AzureCompute(){
		$this.ClearCache()
	}
	
	###############################################################
	# Clear the internals if you switch subscriptions so that the
	# correct information will be returned.
	###############################################################
	[void] ClearCache() {
		$this.VirtualMachines = New-Object System.Collections.HashTable
		$this.AMLSCompute = $null
		$this.ShutdownSchedules = New-Object System.Collections.ArrayList

		$schedules = [AzureResources]::FindDeployments("Microsoft.DevTestLab/schedules")
		foreach($rgKey in $schedules.Keys)
		{
			foreach($rsrc in $schedules[$rgKey].Keys)
			{
				$sched = [ShutdownSchedule]::new()
				$sched.ResourceGroup = $rgKey
				$sched.Name = $rsrc
				$sched.ResourceType = "Microsoft.DevTestLab/schedules"
				$this.ShutdownSchedules.Add($sched)
			}
		}
	}

	###############################################################
	# Get an array of AMLSWorkspace instances for all AMLS details
	# across the subscription. If it's already been collected, just
	# return the cached information.
	#
	#
	###############################################################
	[System.Collections.ArrayList] GetAMLSComputeVms([ResourceGroupManager]$groupManager){
		Write-Host("Searching for AMLS Compute Details")
		$returnList = New-Object System.Collections.ArrayList
		
		if($this.AMLSCompute)
		{
			Write-Host("***Returning cached information***")
			$returnList = $this.AMLSCompute.Clone()
		}
		else
		{
			$resourceType = 'Microsoft.MachineLearningServices/workspaces'
			$workspaceDeployments = [AzureResources]::FindDeployments($resourceType)
	
			foreach($resourceGroup in $workspaceDeployments.Keys)
			{
				Write-Host("Group: " + $resourceGroup)
				foreach($workspace in $workspaceDeployments[$resourceGroup].Keys)
				{
					Write-Host("    Workspace: " + $workspace)
					try {
						# Now find out what we want 
						$computeListText = az ml computetarget list -g $resourceGroup -w $workspace
						$computeList = $computeListText | ConvertFrom-Json
			
						$amlsWorkspace = [AMLSWorkspace]::new()
						$amlsWorkspace.ResourceGroup = $resourceGroup
						$amlsWorkspace.Workspace = $workspace
					
						foreach($compute in $computeList)
						{
							try {
								$computeDetailsText = az ml computetarget show -n $compute.name -g $resourceGroup -w $workspace -v
								$computeDetails = $computeDetailsText | ConvertFrom-Json
						
								$amlsCluster = [AMLSCluster]::new()
								$amlsCluster.ComputeName = $compute.name
								$amlsCluster.ComputeLocation = $computeDetails.properties.computeLocation
								$amlsCluster.ComputeType = $computeDetails.properties.computeType
								$amlsCluster.State = $computeDetails.properties.provisioningState
								$amlsCluster.Priority = $computeDetails.properties.properties.vmPriority
								$amlsCluster.SKU = $computeDetails.properties.properties.vmSize
								$amlsCluster.CurrentNodes = $computeDetails.properties.status.currentNodeCount
								$amlsCluster.MaxNodes = $computeDetails.properties.properties.scaleSettings.maxNodeCount
								$amlsCluster.MinNodes = $computeDetails.properties.properties.scaleSettings.minNodeCount
						
								if($groupManager -and ($amlsCluster.ComputeType -eq 'AKS'))
								{
									$groupPattern = "*" + $amlsCluster.ComputeName + "*"
									$associatedClusterGroup = $groupManager.FindGroup($groupPattern)
									if($associatedClusterGroup.Count -eq 1)
									{
										$amlsCluster.AksClusterGroup = $associatedClusterGroup[0]
									}
							
									if($amlsCluster.AksClusterGroup)
									{
										$amlsCluster.AksClusterSummary = $this.GetVirtualMachineSummary($amlsCluster.AksClusterGroup.Name,$null)
									}
								}
						
								$amlsWorkspace.Clusters.Add($amlsCluster) > $null
							}
							catch {
								Write-Host("Failed to show cluster")
							}
						}
					
						$returnList.Add($amlsWorkspace) > $null
					}
					catch {
						Write-Host("Failed to list compute targets") 
					}
				}
									
			}

			$this.AMLSCompute = $returnList.Clone()
		}		
		
		return $returnList
	}
	
	#########################################################################
	#	Collects a summary of AMLS compute resources. 
	# 	
	#	Internally calls GetAMLSComputeVms to see of we can get a cached version
	#	for expediency. 
	#
	#	Returns a ComputeSummary instance
	#	Input parameter is used to track down AKS cluster information to the 
	#	summary. If not present, it only detects the AmlCompute nodes.
	#########################################################################
	[ComputeSummary] GetAMLSSummary([ResourceGroupManager]$groupManager){
	
		$returnSummary = [ComputeSummary]::new()
		
		# If already called, this is the summary, otherwise, collect
		$details = $this.GetAMLSComputeVms($groupManager)
		
		foreach($workspace in $details)
		{
			foreach($cluster in $workspace.Clusters)
			{
				$returnSummary.RunningTotal += $cluster.CurrentNodes
				$returnSummary.DeallocatedTotal += ($cluster.MaxNodes - $cluster.CurrentNodes)
				
				if($cluster.SKU)
				{
					if($returnSummary.SkuBreakdown.ContainsKey($cluster.SKU))
					{
						$returnSummary.SkuBreakdown[$cluster.SKU] += $cluster.MaxNodes
					}
					else
					{
						$returnSummary.SkuBreakdown.Add($cluster.SKU,$cluster.MaxNodes)
					}
				}
				
				# If we have aks summary info here, add it in.
				if($cluster.AksClusterSummary)
				{
					$returnSummary.RunningTotal += $cluster.AksClusterSummary.RunningTotal
					$returnSummary.DeallocatedTotal += $cluster.AksClusterSummary.DeallocatedTotal
					$returnSummary.StoppedTotal += $cluster.AksClusterSummary.StoppedTotal
					
					foreach($key in $cluster.AksClusterSummary.SkuBreakdown.Keys)
					{
						if($returnSummary.SkuBreakdown.ContainsKey($key))
						{
							$returnSummary.SkuBreakdown[$key] += $cluster.AksClusterSummary.SkuBreakdown[$key]
						}
						else
						{
							$returnSummary.SkuBreakdown.Add($key,$cluster.AksClusterSummary.SkuBreakdown[$key])
						}
					}
					
				}
			}
		}
		
		return $returnSummary;
	}
	
	#########################################################################
	#	Collects a list of virtual machines from the subscription. If the
	# 	resource group is null, searches the whole sub. If skuFilter is not
	#	null, sku type is searched with input string using -like
	#
	#	If the full command to issue has been issued already, return cached
	# 	details. 
	#########################################################################
	[System.Collections.ArrayList] GetVirtualMachines([string]$resourceGroup,[string]$skuFilter)
	{
		Write-Host("Searching for Virtual Machines")
		$returnList = New-Object System.Collections.ArrayList
		
		$vms = $null
		$command=$null
		$filter=$null
		# If a sku filter provided, prepare for it.
		if($skuFilter)
		{
			Write-Host("Filter VM with : " + $skuFilter)
			$filter = " | Where-Object {`$_.HardwareProfile.VmSize -like '" + $skuFilter + "'}"
		}
			
		# If a resource group is provided, prepare for that as well.
		if($resourceGroup)
		{
			Write-Host("Get VM Instances in resource group: " + $resourceGroup)
			$command = 'Get-AzureRmVM -ResourceGroupName ' + $resourceGroup
		}
		else
		{
			Write-Host("Get VM Instances in Subscription ")
			$command = 'Get-AzureRmVM '
		}
	
		# Build up the full command and execute it.
		$fullCommand = $command + $filter
		
		#Check to see if we've fulfilled this already
		if($this.VirtualMachines.ContainsKey($fullCommand))
		{
			Write-Host("***Returning cached information***")
			$returnList = $this.VirtualMachines[$fullCommand].Clone()
		}
		else
		{
			Write-Host("Executing: " + $fullCommand)
			$vms = Invoke-Expression $fullCommand
			
			foreach($vminst in $vms)
			{
				$status = $this.GetVirtualMachineStatus($vminst.ResourceGroupName,$vminst.Name)
				
				if($status)
				{
					$status.Sku = $vminst.HardwareProfile.VmSize
					$returnList.Add($status) > $null
				}
			}
			
			$this.VirtualMachines.Add($fullCommand, $returnList.Clone())
		}		
		
		return $returnList
	}
	
	#########################################################################
	#	Collects a summary of Virtual Machine compute resources. 
	# 	
	#	Internally calls GetVirtualMachines to see of we can get a cached version
	#	for expediency. 
	#
	#	Returns a ComputeSummary instance
	#########################################################################
	[ComputeSummary] GetVirtualMachineSummary([string]$resourceGroup,[string]$skuFilter){
	
		$returnSummary = [ComputeSummary]::new()
		
		# If already called, this is the summary, otherwise, collect
		$details = $this.GetVirtualMachines($resourceGroup, $skuFilter)
		
		foreach($machine in $details)
		{
			if($machine.Running)
			{
				$returnSummary.RunningTotal += 1
			}
			elseif($machine.Stopped)
			{
				$returnSummary.StoppedTotal += 1
			}
			else
			{
				$returnSummary.DeallocatedTotal += 1
			}
			
			
			if($machine.Sku)
			{
				if($returnSummary.SkuBreakdown.ContainsKey($machine.Sku))
				{
					$returnSummary.SkuBreakdown[$machine.Sku] += 1
				}
				else
				{
					$returnSummary.SkuBreakdown.Add($machine.Sku,1)
				}
			}
		}
		
		return $returnSummary;
	}
	
	#########################################################################
	#	Gets the detials of a specific virtual machine. 
	#########################################################################
	hidden [VirtualMachine] GetVirtualMachineStatus([string]$resourceGroup,[string]$instanceName) {
		
		$running=$false
		$stopped=$false
		$deallocated=$false
		#$sku=$null
		
		# Using the call below gives you running state but not SKU
		$vmStatus = Get-AzureRmVM -ErrorAction Stop -Status -ResourceGroupName $resourceGroup -Name $instanceName
		if($vmStatus)
		{
			foreach($status in $vmStatus.Statuses)
			{
				if($status.code -eq "PowerState/running")
				{
					$running=$true
				}
	
				if($status.code -eq "PowerState/deallocated")
				{
					$deallocated=$true
				}
			}
			
			$stopped = ( ($running -eq $false) -and ($deallocated -eq $false))
			
			# Get SKU
			# Using the call below doesn't give you running state, but gives you SKU
			#$vmStatusSku = Get-AzureRmVM -ErrorAction Stop -ResourceGroupName $resourceGroup -Name $instanceName
			#$sku=$vmStatusSku.HardwareProfile.VmSize
		}
	
		$vmInformation = [VirtualMachine]::new()
		$vmInformation.ResourceGroup =$resourceGroup
		$vmInformation.MachineName=$instanceName
		$vmInformation.Stopped=$stopped
		$vmInformation.Deallocated=$deallocated
		$vmInformation.Running=$running

		$schedules = $this.ShutdownSchedules | Where-Object { ($_.ResourceGroup -eq $resourceGroup) -and ($_.Name -like "shutdown-*") -and ($_.Name -like "*$instanceName") }
		if($schedules.Count -gt 0)
		{
			$vmInformation.ShutdownSchedule = $true
		}
		
		return $vmInformation
	}	

}