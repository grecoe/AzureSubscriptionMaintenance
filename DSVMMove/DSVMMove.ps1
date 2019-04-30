<#
	This script will create a duplicate VM for you in a seperate subscription. 

	Steps:
	
	1. Modify the content of DSVMMoveConfig.ps1 
		- Get Subscription ID of the source account and put in SubscriptionId
		- Get the source resource group name and put in ResourceGroup
		- Get the name of the Virutal Machine in the resource group and put in VirtualMachine
		- Put either Windows or Linux for the VirtualMachineOs field.
		- Get Subscription ID of the destination account and put in DestinationSubscriptionId
		- Create a new resource group in the destination subscription in the same region as the source 
		  resource group or VM. Put the name in the DestinationResourceGroup field.
		- In the destination resource group, create a Virtual Network in the same location as the source 
		  virtual machine and put it's name in the DestinationVirtualNetworkName field.
	2. Run this script from the command line ensuring that DSVMMoveConfig.json is in the same directory.
	
	Supporting Links:
	https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-managed-disk-from-snapshot
	https://4sysops.com/archives/powershell-script-for-creating-a-new-azure-vm-using-a-disk-snapshot/
	https://docs.microsoft.com/en-us/azure/virtual-machines/scripts/virtual-machines-windows-powershell-sample-create-vm-from-managed-os-disks
#>

<#
	Load the configuration file into $configuration
#>
$configurationFile = '.\DSVMMoveConfig.json'
$configurationObject = Get-Content -Path $configurationFile -raw | ConvertFrom-Json
$configuration = @{}
$configurationObject.psobject.properties | Foreach { $configuration[$_.Name] = $_.Value }

<#
	Values either come from:
	
	- DiskConfiguration.json located in the same directory.
	- Derived from original VM name
	- Collected from the properties of the VM to move.
	- Constant (Storage Account Type Only)
#>

# Values from configuration
$subscriptionId = $configuration['SubscriptionId']
$resourceGroupName = $configuration['ResourceGroup']
$virtualMachine = $configuration['VirtualMachine']
$virtualMachineOs = $configuration['VirtualMachineOs']

$destinationSubscription = $configuration['DestinationSubscriptionId']
$destinationResourceGroup = $configuration['DestinationResourceGroup']
$virtualNetworkName = $configuration['DestinationVirtualNetworkName']

# Constant Values
$storageType = 'Premium_LRS'

# Derived values
$snapshotName = $virtualMachine.ToLower()+'ss'
$diskName = $virtualMachine.ToLower()+'dsk'
$publicIpName = $virtualMachine.ToLower()+'_ip'
$nicName = $virtualMachine.ToLower() + '_nic'

# Values collected from the initial VM
$virtualMachineSize = ""
$diskSize = ""
$location = ""
$planName = ""
$planPublilisher = ""
$planProduct = ""


#####################################################################
# 0 Have to set the subscription to the source subscription
#####################################################################
Write-Host("Set Subscription to : " + $subscriptionId)
Select-AzureRMSubscription -SubscriptionId $subscriptionId

#####################################################################
# 1 Create the snapshot
#####################################################################
Write-Host("Creating a snapshot of the OS disk for machine : " + $virtualMachine)
$existingVM = Get-AzureRmVM -ResourceGroupName $resourceGroupName -Name $virtualMachine

$VMOSDisk= $existingVm.StorageProfile.OsDisk.Name
$virtualMachineSize = $existingVm.HardwareProfile.VmSize
$diskSize = $existingVm.StorageProfile.OsDisk.DiskSizeGB.ToString()
$location = $existingVm.Location
$planName = $existingVm.Plan.Name
$planPublilisher = $existingVm.Plan.Publisher
$planProduct = $existingVm.Plan.Product


$Disk = Get-AzureRmDisk -ResourceGroupName $resourceGroupName -DiskName $VMOSDisk
$SnapshotConfig = New-AzureRmSnapshotConfig -SourceUri $Disk.Id -CreateOption Copy -Location $location
$Snapshot= New-AzureRmSnapshot -Snapshot $SnapshotConfig -SnapshotName $snapshotName -ResourceGroupName $resourceGroupName

#####################################################################
# 2 Create a managed OS disk. 
#####################################################################
Write-Host("Creating an OS disk from the snapshot : " + $snapshotName)
$NewOSDiskConfig = New-AzureRmDiskConfig -AccountType $storageType -Location $location -CreateOption Copy -SourceResourceId $Snapshot.Id
$newOSDisk = New-AzureRmDisk -Disk $NewOSDiskConfig -ResourceGroupName $resourceGroupName -DiskName $diskName

#####################################################################
# 3 Move the disk to the destination subscription
#####################################################################
Write-Host("Moving disk to destination subscription: " + $destinationSubscription + " : " + $destinationResourceGroup )
$moveCommand = "Move-AzureRmResource -DestinationSubscriptionId " + $destinationSubscription + " -DestinationResourceGroupName " + $destinationResourceGroup + " -ResourceId " + $newOSDisk.Id
Invoke-Expression $moveCommand


Write-Host("Disk has been moved to the following location:")
Write-Host("   Subscription  : " + $destinationSubscription)
Write-Host("   Resource Group: " + $destinationResourceGroup)
Write-Host("   OS Disk       : " + $diskName)
Write-Host("")
Write-Host("Creating a VM in location with following information:")
Write-Host("   VM Size       : " + $virtualMachineSize)
Write-Host("   OS            : " + $virtualMachineOs)

#####################################################################
# 4 Have to set the subscription to the destination subscription
#####################################################################
Write-Host("Set Subscription to : " + $subscriptionId)
Select-AzureRMSubscription -SubscriptionId $destinationSubscription

#####################################################################
# 5 Create the new VM
#####################################################################

# Get the disk that we moved to this subscription
$osDiskToRessurect = Get-AzureRmDisk -ResourceGroupName $destinationResourceGroup -DiskName $diskName

#Initialize virtual machine configuration
$newVirtualMachine = New-AzureRMVMConfig -VMName $virtualMachine -VMSize $virtualMachineSize

#Use the Managed Disk Resource Id to attach it to the virtual machine. Please change the OS type to linux if OS disk has linux OS
if($virtualMachineOs.ToLower() -eq 'windows')
{
	$newVirtualMachine = Set-AzureRMVMOSDisk -VM $newVirtualMachine -ManagedDiskId $osDiskToRessurect.Id -CreateOption Attach -Windows
}
else
{
	$newVirtualMachine = Set-AzureRMVMOSDisk -VM $newVirtualMachine -ManagedDiskId $osDiskToRessurect.Id -CreateOption Attach -Linux
}

#Use the MarketPlace plan information
$newVirtualMachine = Set-AzureRmVMPlan -VM $newVirtualMachine -Product $planProduct -Name $planName -Publisher $planPublilisher

#Create a public IP for the VM
$publicIp = New-AzureRMPublicIpAddress -Name $publicIpName -ResourceGroupName $destinationResourceGroup -Location $Snapshot.Location -AllocationMethod Dynamic

#Get the virtual network where virtual machine will be hosted
$vnet = Get-AzureRMVirtualNetwork -Name $virtualNetworkName -ResourceGroupName $destinationResourceGroup

# Create NIC in the first subnet of the virtual network
$nic = New-AzureRMNetworkInterface -Name $nicName -ResourceGroupName $destinationResourceGroup -Location $Snapshot.Location -SubnetId $vnet.Subnets[0].Id -PublicIpAddressId $publicIp.Id

$newVirtualMachine = Add-AzureRMVMNetworkInterface -VM $newVirtualMachine -Id $nic.Id

#Create the virtual machine with Managed Disk
New-AzureRMVM -VM $newVirtualMachine -ResourceGroupName $destinationResourceGroup -Location $Snapshot.Location

Write-Host("Tasks Completed")







