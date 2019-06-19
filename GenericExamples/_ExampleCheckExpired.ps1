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
# Check to see if (1) there is an 'expires' tag and (2) if it's expired 
#
#   Time format can be one of the other
#       YYYY-MM-DD
#       MM/DD/YYYY
#############################################################################

# Import the correct class modules
Using module ..\Modules\clsSubscription.psm1
Using module ..\Modules\clsResourceGroupManager.psm1

# Tag containing the date we are interested in
$tagName = 'expires'

# Perform a login prior to calling this, first call collects the subscriptions.
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null

# Filter on subscriptions by a name or partial name 
$subscriptionNameToFind="Danielle"
Write-Host("Searching for:  " + $subscriptionNameToFind )
$result = $subManager.FindSubscription($subscriptionNameToFind)

<#
    Function used to parse the date string in either of the supported formats.
#>
function ParseExpiresTag {
    # Parameter help description
    param( [System.String] $expiresValue)

    $dateTimeReturn = $null

    # There are two allowed patterns
    #   YYYY-MM-DD
    #   MM/DD/YYYY

    $parts = $null
    $yearIndex = 0
    $monthIndex = 1
    $dayIndex = 2
    if($expiresValue.Contains('-'))
    {
        $parts = $gp.Tags[$tagName] -split '-'
    }
    elseif($expiresValue.Contains('/'))
    {
        $yearIndex = 2
        $monthIndex = 0
        $dayIndex = 1
        $parts = $gp.Tags[$tagName] -split '/'
    }

    if($parts.Length -eq 3)
    {
        $formatValid = $true
        # first check to see that all of them 
        foreach($part in $parts)
        {
            if( ($part.Trim() -match '^[0-9]+$') -eq $false)
            {
                $formatValid = $false
            }
        }
        
        # validInput tells us if its only got numbers
        if($formatValid)
        {
            $year = [convert]::ToInt32($parts[$yearIndex].Trim(), 10) 
            $month = [convert]::ToInt32($parts[$monthIndex].Trim(), 10)
            $day = [convert]::ToInt32($parts[$dayIndex].Trim(), 10) 
        
            $dateTimeReturn = Get-Date -Year $year -Month $month -Day $day
        }
    }

    $dateTimeReturn
    
}

# Possible to get more than one result, so....be careful.
if($result.Count -eq 1)
{
	$currentSubscription = $result[0]
	
	Write-Host("Working with subscription " + $currentSubscription.Name)
	
	# Set this subscription as the current subscription to work on.
	$subManager.SetSubscription($currentSubscription)
	$resourceGroupManager = [ResourceGroupManager]::new()

    $foundGroups =$resourceGroupManager.FindGroupWithTag($tagName)
    
    Write-Host("Check Expired")
    foreach($gp in $foundGroups)
    {
        $formatValid = $false
        $expired = $false
        
        $expiredDate = ParseExpiresTag -expiresValue $gp.Tags[$tagName]

        if($expiredDate -ne $null)
        {
            $formatValid = $true
            $today = Get-Date
            if($today -gt $expiredDate)
            {
                $expired = $true
            }
        }

        if($formatValid -eq $false)
        {
            Write-Host("    XXXXXX Group " + $gp.Name + " " + $tagName + " invalid format : " + $gp.Tags[$tagName] + " XXXXXX")
        }
        elseif($expired -eq $true)
        {
            Write-Host("    ****** Group " + $gp.Name + " expired on " + $gp.Tags[$tagName] + " ******")
        }
        else 
        {
            Write-Host("    Group " + $gp.Name + " will expire on " + $gp.Tags[$tagName])
        }
    }
}