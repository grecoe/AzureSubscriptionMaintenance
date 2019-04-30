# Azure Subscription Maintenance 
<sub>Author: Daniel Grecoe, A Microsoft employee</sub>

As you and your team begin to utilize Azure, it is easy for resources to become lost and abandonded in the mix. With that loss of control comes the costs associated with it. 

Setting common sense policies, enforcing those policies, and a general understanding of what you have deployed in your subscription can help head off difficult situations with your team about their consumption usage. 

This repository has several tools and a lot of information that can help anyone better manage an Azure Subscrption. From understanding [best practices](Documentation/Best%20Practices.docx) to understanding [cost management](Documentation/CostManagement.docx) 
to implementing policies with [PowerShell](https://docs.microsoft.com/en-us/powershell/scripting/overview?view=powershell-6) scripts, this repo can help.

# Supporting Documentation
Supporting documentation on [best practices](Documentation/Best%20Practices.docx) and [cost management](Documentation/CostManagement.docx) can be found in the [Documentation](Documentation/) folder of this repository.

# Powershell Scripts
The scripts in this repository are broken down into 3 groups. 

|Folder|Contents|
|--------------|----------------|
|[Modules](../Modules)| This folder contains the [PowerShell modules](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_modules?view=powershell-6) that wrap the AzureRM and Az CLI commands to perform tasks against your Azure Subscriptions.| 
|[GenericExamples](../GenericExamples)| This folder contains a series of example scripts using the modules to perform various tasks. These will help you understand the function of the modules.| 
|[Compliance](../Compliance)| This folder contains a more specific use case across several subscriptions to perform tasks on behalf of a specific compliance policy set out by a random team. | 


## Prerequisites
There are a few things you must ensure have occured before running these scripts:

* Ensure you have the latest version of PowerShell. You can determine the version and how to update it using [this](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-windows-powershell?view=powershell-6) link. 
* Ensure you have the latest version of AzureRM modules by following [these](https://www.powershellgallery.com/packages/AzureRM/6.13.1) instructions. 
* Ensure you have the latest Azure CLI by following [these](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest) instructions.

<b>NOTES:</b> 
1. On Powershell updates use the -AllowClobber flag to ensure you get all of the proper updates.
2. Make sure you issue an ***az login*** or ***Login-AzureRMAccount*** prior to running any of the scripts listed below. None of them will ensure you are logged in. 

