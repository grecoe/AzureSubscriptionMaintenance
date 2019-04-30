# Modules 
<sub>Author: Daniel Grecoe, A Microsoft employee</sub>

This folder contains the [PowerShell modules](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules?view=powershell-6) that wrap the AzureRM and Az CLI commands to perform tasks against your Azure Subscriptions. 


## Prerequisites
* Ensure you have the latest version of PowerShell. You can determine the version and how to update it using [this](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell?view=powershell-6) link. 
* Ensure you have the latest version of AzureRM modules by following [these](https://www.powershellgallery.com/packages/AzureRM/6.13.1) instructions. 
* Ensure you have the latest Azure CLI by following [these](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) instructions.

<b>NOTES:</b> 
1. On Powershell updates use the -AllowClobber flag to ensure you get all of the proper updates.
2. Make sure you issue an ***az login*** or ***Login-AzureRMAccount*** prior to running any of the scripts listed below. None of them will ensure you are logged in. 

## Class Modules
This is the listing of the class modules that reside in this directory:

|Script Name|Description-Functionality|
|--------------------------|--------------------------------|
|clsSubscription.psm1|Subscription level functionality.|
|...|<b>Classes</b> : SubscriptionManager, Subscription|
|clsResourceGroupManager.psm1|Resource Group functionality.|
|...|<b>Classes</b> : ResourceGroupManager, ResourceGroup, GroupBuckets, GroupSummary, GroupDetails|
|clsResources.psm1|Static functions to find Azure resources.|
|...|<b>Classes</b> : AzureResources
|clsCompute.psm1|Virtual Machine compute resources.|
|...|<b>Classes</b> : AzureCompute, VirtualMachine, AMLSWorkspace, AMLSCluster<sup>1</sup>|
|clsBlobStorage.psm1|Azure Storage functionality.|
|...|<b>Classes</b> : BlobStorage<sup>2</sup>|

<sup>1</sup> With the latest Azure Machine Learning Service (AMLS), AmlCompute clusters based on Azure Kubernetes Service (AKS) do not appear as standard Virtual Machines in the source subscription. The clsCompute.psm1 file searches, specifically, for AMLS workspaces and detects if there are hidden Virtual Machines in your subscription to provide a full picture of compute resources that are out there.

<sup>2</sup> While blob storage functionality will likely not play a big role in any of the tasks you are performing, keeping configuration information to be shared across systems in blob storage is a useful way to share a configuration from one location regardless of where your scripts run. For instance, running cleanup scripts in a DevOps pipeline.



