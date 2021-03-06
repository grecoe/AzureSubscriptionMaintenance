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
    Script that finds virtual machines that are not part of a databricks or AKS cluster and 
    shuts them down.
#>
Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsCompute.psm1

#####################################################
# Parameters for the script
# in - File name containing subscription list
#####################################################
param(
	[string]$in
)

$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

$subManager = [SubscriptionManager]::new()

$activeMachines = @{}
$activeSkus = @{}
$activeSkuCounts = @{}
$utilizationLimit = 2.0
$underUtilizedMachines = New-Object System.Collections.ArrayList

$totalTargetVMs=0
$clusterMachines=0
$shutdownSchedules=0

foreach($sub in $subList.PSObject.Properties)
{

    $result = $subManager.FindSubscriptionById($sub.Value)
    $useSub = $result[0]
    $subManager.SetSubscription($useSub)

    $activeSkuCounts.Add($useSub.Name, 0)

    $compute = [AzureCompute]::new()
    $vmList = $compute.GetVirtualMachines($null, $null)

    foreach($vm in $vmList)
    {
        if($vm.Running -eq $true)
        {
            if( ($vm.ResourceGroup -like "databricks-*") -or 
                ($vm.ResourceGroup -like 'MC_*') -or
                ($vm.ResourceGroup -like 'FILESERVERRG-*'))
            {
                $clusterMachines++
                Write-Host("Ignoring Cluster Machine: " + $vm.ResourceGroup + "/" + $vm.MachineName)
            }
            elseif( $vm.ShutdownSchedule -eq $true)
            {
                $shutdownSchedules++
                Write-Host("Ignoring Machine With Shutdown Schedule: " + $vm.ResourceGroup + "/" + $vm.MachineName)
            }
            else 
            {
                # Active machine sku across all subs
                if($activeSkus.ContainsKey($vm.Sku) -eq $false)
                {
                    $activeSkus.Add($vm.Sku, 0)
                }
                $activeSkus[$vm.Sku]++
                $activeSkuCounts[$useSub.Name]++

                # Add in this subscription
                if($activeMachines.ContainsKey($useSub.Name) -eq $false)
                {
                    $subInfo = @{}
                    $activeMachines.Add($useSub.Name, $subInfo)
                }

                # Active sku per sub
                $totalTargetVMs++
                if($activeMachines[$useSub.Name].ContainsKey($vm.Sku) -eq $false)
                {
                    $activeMachines[$useSub.Name].Add($vm.Sku, 0)
                }
                $activeMachines[$useSub.Name][$vm.Sku]++

                # Find underutilized machines
                $utilization = $vm.GetCpuUtilization(48)
                if($utilization.Average -lt $utilizationLimit)
                {
                    $underMachine = New-Object PSObject -Property @{ 
                        Subscription = $useSub.Name;
                        Machine = $vm.MachineName; 
                        Usage = $utilization.Average}
                    $underUtilizedMachines.Add($underMachine) > $null
                }
            }

        }
    }
}


Write-Host("Ignored Cluster Machines : " + $clusterMachines)
Write-Host("Ignored with Shutdown Schedule : " + $shutdownSchedules)

Write-Host(" Total Targets: " + $totalTargetVMs)

Write-Host("****************** Target Machines")
Write-HOst(($activeSkus | ConvertTo-Json))
Write-Host("****************** Target Machines By Subscription")
Write-HOst(($activeSkuCounts | ConvertTo-Json))
Write-Host("****************** Active Machines")
Write-Host($activeMachines | ConvertTo-Json)
Write-Host("****************** Underutilized")
Write-Host($underUtilizedMachines | ConvertTo-Json)
