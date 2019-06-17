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


class AzureResources {


	###############################################################
	# FindDeployments
	#
	#	Find the deploymnets of a specific resource type in an AzureRmContext
	#	subscription.
	#
	#	Params:
	#		resourceType : String resource type to find, i.e. 
	#				-resourceType 'Microsoft.MachineLearningServices/workspaces'
	#
	#	Returns:
	#		HashTable<[string]resource group, HashTable2>
	#			HashTable2<[string]resourceName, HashTable3>
	#				HashTable3{Keys are SKU and Location
	###############################################################
	static [System.Collections.Hashtable] FindDeployments([string]$resourceType) {
		$returnList = @{}
		
		$resources = Get-AzureRmResource -ResourceType $resourceType
		foreach($res in $resources)
		{
			if($returnList.ContainsKey($res.ResourceGroupName) -eq $false)
			{
				$returnList.Add($res.ResourceGroupName,@{})
			}
			
			$details = @{}
			if($res.Sku)
			{
				$details.Add("SKU" , $res.Sku.Name)
			}
			if($res.ManagedBy)
			{
				$details.Add("ManagedBy" , $res.ManagedBy)
			}
			$details.Add("Location" , $res.Location)
			
			$returnList[$res.ResourceGroupName].Add($res.Name, $details)
		}		
		return $returnList
	}
	
	###############################################################
	# GetResources
	#
	#	Get a list of all resources and the count of each resource
	#	type in a subscription. 
	#
	#
	#	Returns:
	#		HashTable<[string]resourceType, [int]resourceCount>
	###############################################################
	static [System.Collections.Hashtable]  GetAllResources() {
	
		$returnTable = @{}
		
		$allResources = Get-AzureRmResource
		foreach($res in $allResources)
		{
			if($returnTable.ContainsKey($res.ResourceType) -eq $false)
			{
				$returnTable.Add($res.ResourceType,1)
			}
			else
			{
				$returnTable[$res.ResourceType]++
			}
		}
		
		return $returnTable
	}	

	###############################################################
	# GetGroupResources
	#
	#	Get a list of resources in a specific group.
	#
	#
	#	Returns:
	#		HashTable<[string]resourceName, HashTable<id, value>
	#			id = ResourceType | ResourceId 
	###############################################################
	static [System.Collections.Hashtable]  GetGroupResources([string]$resourceGroup) {
	
		$returnTable = @{}
		
		$allResources = Get-AzureRmResource -ResourceGroupName $resourceGroup
		foreach($res in $allResources)
		{
			$resourceData = @{}
			$resourceData.Add("ResourceType", $res.ResourceType)
			$resourceData.Add("ResourceId", $res.Id)

			$keyName = $res.Name
			$attempt = 1
			while($returnTable.ContainsKey($keyName) -eq $True)
			{
				$keyName = $keyName + "_DUPE" + $attempt++
			}
			$returnTable.Add($keyName, $resourceData)
		}
		
		return $returnTable
	}	

	###############################################################
	# DeleteResource
	#
	#	Delete a resource
	#
	#
	#	Returns:
	#		HashTable<[string]resourceName, [string]resourceType>
	###############################################################
	static [void]  DeleteResource([string]$resourceName, [string]$resourceType) {
		Remove-AzureRmResource -ResourceName $resourceName -ResourceType $resourceType
	}	

	
}