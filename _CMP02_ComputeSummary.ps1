<#
	Script that tallys across all subscriptions, the number of resource groups 
	in total, and the number that actually have tags applied to them.
	
	$in is the file name of the subscription json file created by _CMP01_CollectSubs.ps1
#>
Using module .\clsSubscription.psm1
Using module .\clsCompute.psm1 

#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$in
)

$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

$total=0
$totalRunning=0
$amlsTotal=0
$amlsTotalRunning=0

$subManager = [SubscriptionManager]::new()

foreach($sub in $subList.PSObject.Properties)
{
	$totalSubs++
	Write-Host("Name: " + $sub.Name)
	Write-Host("ID: " + $sub.Value)

	$result = $subManager.FindSubscriptionById($sub.Value)
	
	if($result.Count -eq 1)
	{
		$currentSubscription = $result[0]
		$subManager.SetSubscription($currentSubscription)

		$azureCompute = [AzureCompute]::new()
		$amlsSummary = $azureCompute.GetAMLSSummary($null)
		$vmSummary = $azureCompute.GetVirtualMachineSummary($null,$null)
		
		Write-Host($sub.Name)
		Write-Host(($amlsSummary | ConvertTo-Json))
		Write-Host(($vmSummary | ConvertTo-Json))
		
		$amlsTotal += $amlsSummary.RunningTotal + $amlsSummary.StoppedTotal + $amlsSummary.DeallocatedTotal
		$amlsTotalRunning += $amlsSummary.RunningTotal
		$total += $vmSummary.RunningTotal + $vmSummary.StoppedTotal + $vmSummary.DeallocatedTotal
		$totalRunning += $vmSummary.RunningTotal
	}
}
Write-Host("VM Total: " + $total)
Write-Host("VM Running: " + $totalRunning)
Write-Host("AMLS Total: " + $amlsTotal)
Write-Host("AMLS Running: " + $amlsTotalRunning)
