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
	Script used to collect all available subscriptions for 
	the logged in user. Output is put into a file identified
	by the parameter $out.
	
	Parameter should just be a file name, path will be added
	to it.
	
	Output file is used for the input to _CMP02_Driver.ps1
	
	Modify this output file to run against only the subscriptions
	of interest.

#>

Using module ..\Modules\clsSubscription.psm1

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
