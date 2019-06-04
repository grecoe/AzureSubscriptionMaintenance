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
    Script used to determine how many un-attached disks are in a subscripion. This is done simply by 
    determining if there is a ManagedBy property value on the resource. 

    This can be useful for determining how many unused disks are available. To find out more about managed 
    disk costs:

    https://azure.microsoft.com/en-us/pricing/details/managed-disks/
#>

Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResources.psm1

#####################################################
# Parameters for the script
# out - File name to output subs, path fixed internally
#####################################################
param(
	[string]$in
)


# Load the subscription list from JSON (from _CMP01_CollectSubs.ps1)
$subList = (Get-Content -Path ('.\' + $in) -raw) | ConvertFrom-Json

<#
	Function to parse out the subscription bucket (unlocked)
#>
function GetUnattachedDisks{

    $unAttachedDisks = New-Object System.Collections.ArrayList
    $totalDisks = 0
    $totalUnattachedDisks = 0

    $rgdisks = [AzureResources]::FindDeployments("Microsoft.Compute/disks")
    
    #Write-Host(($rgDisks | ConvertTo-Json))

    foreach($rg in $rgdisks.Keys)
    {
        foreach($resource in $rgdisks[$rg].Keys)
        {
            $totalDisks++
            if($rgdisks[$rg][$resource].ContainsKey("ManagedBy") -eq $False)
            {
                $totalUnattachedDisks++
                $unAttachedDisks.Add($resource) > $null
            }
        }
    }

	$resultsObject = New-Object PSObject -Property @{ 
            Total = $totalDisks
            TotalUnattached = $totalUnattachedDisks
			UnAttached = $unAttachedDisks
	}

	
	$resultsObject
}

<#
	Where the work actually occurs (and calls function above.
#>
$totalDisks = 0
$totalUnattachedDisks = 0
$summary = @{}
foreach($sub in $subList.PSObject.Properties)
{
	$subName = $sub.Name
	$subId = $sub.Value

	# Perform a login prior to calling this, first call collects the subscriptions.
	$subManager = [SubscriptionManager]::new()
	$currentSubscription = $null
	
	# Filter on subscriptions by a name or partial name 
	Write-Host("Searching for:  " + $subName )
	$result = $subManager.FindSubscriptionById($subId)
    
	# Possible to get more than one result, so....be careful.
	if($result.Count -eq 1)
	{
        $subManager.SetSubscription($result[0])
        $diskResults = GetUnattachedDisks
        if($diskResults)
        {
            $totalDisks += $diskResults.Total
            $totalUnattachedDisks += $diskResults.TotalUnattached
            $summary.Add($subName, $diskResults)
        }
	}
}

$finalObject = New-Object PSObject -Property @{ 
            TotalDisks = $totalDisks
            UnattachedDisks = $totalUnattachedDisks
			Summary = $summary
}

Write-Host(($finalObject | ConvertTo-Json))

