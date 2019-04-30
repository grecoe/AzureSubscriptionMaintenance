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


# Perform a login prior to calling this if you are not automatically logged in already.

Using module ..\Modules\clsBlobStorage.psm1
Using module ..\Modules\clsSubscription.psm1

# Information we'll need along the way
$account='YOUR_STORAGE_ACCOUNT'
$key='YOUR_STORAGE_ACCOUNT_KEY'

$containerName = 'classtest'
$localFile ='.\testfile.txt'
$blobName='foo.json'
$downloadLocalFile ='.\testfile2.txt'

# Generate some information and write it to a file
$randomData = @{}
$randomData.Add("first","data")
Out-File -FilePath $localFile -InputObject ($randomData | ConvertTo-Json -depth 100)

# Set up subscription manager
$subManager = [SubscriptionManager]::new()
$currentSubscription = $null

# Filter on subscriptions 
$subscriptionNameToFind="Danielle"
Write-Host("Searching for:  " + $subscriptionNameToFind )
$result = $subManager.FindSubscription($subscriptionNameToFind)

if($result.Count -eq 1)
{
	$currentSubscription = $result[0]
	Write-Host("Working with subscription " + $currentSubscription.Name)
	$subManager.SetSubscription($currentSubscription)

	$blobUtility = [BlobStorage]::new($account, $key)
	$blobUtility.CreateContainer($containerName)
	$blobUtility.UploadFile($containerName,$localFile,$blobName)
	$blobUtility.DownloadBlob($containerName,$localFile,$blobName)
	$contentFile = $blobUtility.DownloadBlobContent($containerName,$localFile,$blobName)
	Write-Host($contentFile)
}
