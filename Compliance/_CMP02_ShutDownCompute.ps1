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
$ignoredMachines = @{}

$totalProtectedVMs=0
$totalTargetVMs=0

#$sub = $subManager.FindSubscription("Tao")

#if($sub.Count -gt 0)
foreach($sub in $subList.PSObject.Properties)
{
    #$useSub = $sub[0]

    $result = $subManager.FindSubscriptionById($sub.Value)
    $useSub = $result[0]
    $subManager.SetSubscription($useSub)

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
                if($ignoredMachines.ContainsKey($vm.ResourceGroup) -eq $false)
                {
                    $ignoredMachines.Add($vm.ResourceGroup, (New-Object System.Collections.ArrayList))
                }
                $totalProtectedVMs++
                $ignoredMachines[$vm.ResourceGroup].Add($vm.MachineName) > $null
            }
            else {
                if($activeMachines.ContainsKey($vm.ResourceGroup) -eq $false)
                {
                    $activeMachines.Add($vm.ResourceGroup, (New-Object System.Collections.ArrayList))
                }
                $totalTargetVMs++
                $activeMachines[$vm.ResourceGroup].Add($vm.MachineName) > $null
            }

        }
    }
}


Write-Host("Total Protected : " + $totalProtectedVMs + " Total Targets: " + $totalTargetVMs)

Write-Host("****************** Ignored Machines")
#Write-Host($ignoredMachines | ConvertTo-Json)

Write-Host("****************** Active Machines")
#Write-Host($activeMachines | ConvertTo-Json)
