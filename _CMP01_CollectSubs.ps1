<#
	Script used to collect all available subscriptions for 
	the logged in user. Output is put into a file identified
	by the parameter $out.
	
	Parameter should just be a file name, path will be added
	to it.
	
	Output file is used for the input to _CMP02_Driver.ps1
	
	Modify this output file to run against only the subscriptions
	of interest.

#>

Using module .\clsSubscription.psm1

#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$out
)



# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()

$subListOut = @{}
foreach($sub in $subManager.Subscriptions)
{
	$subListOut.Add($sub.Name, $sub.Id)
}
$outFileName = '.\' + $out
Write-Host("Subscription List Out To: " + $outFileName)
Out-File -FilePath $outFileName -InputObject ($subListOut | ConvertTo-Json -depth 100)
