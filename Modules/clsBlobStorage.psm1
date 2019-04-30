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
#	Simple blob storage functionality. 
#############################################################################
class BlobStorage {
	[string]$StorageAccount
	[string]$StorageKey
	$StorageContext
	
	BlobStorage([string]$name, [string]$key) {
		$this.StorageAccount = $name
		$this.StorageKey = $key
		$this.StorageContext = New-AzureStorageContext -StorageAccountName $this.StorageAccount -StorageAccountKey $this.StorageKey
	}

	[bool] CreateContainer([string]$name) {
		$created=$false
		$container=$null
		try
		{
			$container = Get-AzureStorageContainer -Context $this.StorageContext -Name $name -ErrorAction SilentlyContinue
			$created=$true
		}
		catch {
			Write-Host("Exception getting container")
			$_.Exception.Message
		}	
	
		if($container -eq $null)
		{
			$containerData = New-AzureStorageContainer -ErrorAction Stop -Context $this.StorageContext -Name $name -Permission Blob
			$created=$true
		}
		
		return $created
	}
	
	[bool] UploadFile([string]$container, [string]$localPath, [string]$blobName){
		$uploadComplete=$false
		try
		{
			$response = Set-AzureStorageBlobContent -Context $this.StorageContext -File $localPath -Container $container -Blob $blobName -Force
			$uploadComplete=$true
		}
		catch {
			$_.Exception.Message
		}	
		
		return $uploadComplete
	}

	[bool] DownloadBlob([string]$container, [string]$localPath, [string]$blobName){
		$downloadComplete=$false
		try
		{
			$result = Get-AzureStorageBlobContent -Force -Context $this.StorageContext -Container $container -Blob $blobName -Destination $localPath
			$downloadComplete=$true
		}
		catch {
			$_.Exception.Message
		}	
		
		return $downloadComplete
	}

	[string] DownloadBlobContent([string]$container, [string]$localPath, [string]$blobName){
		$downloadContent=$null
		try
		{
			$result = Get-AzureStorageBlobContent -Force -Context $this.StorageContext -Container $container -Blob $blobName -Destination $localPath
			$downloadContent = Get-Content -ErrorAction Stop -Raw -Path $localPath
		}
		catch {
			$_.Exception.Message
		}	
		
		return $downloadContent
	}
}




