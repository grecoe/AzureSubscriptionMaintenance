# Compliance 
<sub>Author: Daniel Grecoe, A Microsoft employee</sub>

This folder contains more specific uses of the [class modules](../Modules) to perform compliance checks and compliance actions against one or many subscriptions. 

For these examples, we will use the definitiion of compliance as:

- Resource groups, or one of its sub resources has a DeleteLock or ReadOnlyLock applied to it.
- A resource group must have the following tags appplied to it:
    - alias - The users alias who created the group.
    - project - The project in which this resource group will be utilizes.
    - expires - A date in the form YYYY-MM-DD in which this resource group will no longer be required. 


Of course, compliance will mean different things to different people. Your team may choose different values, different policies, etc. 



## Full Compliance Scenario
The following scripts can be used in conjunction to perform a compliance check across all of the available subscriptions for a logged in user:

|Script| Purpose|
|----------------------|---------------------|
|_CMP01_CollectSubs.ps1| This script collects a list of all available subscriptions into a local file, identified by the caller, to be used as input to the next script. Modify the file to include ONLY the subscriptions you want information from.|
|_CMP02_Driver.ps1| Uses the output (and possibly modified file) from the _CMP01_CollectSubs.ps1 script. Internally calls the final script _CMP03_Check.ps1 for each subscription in the input file.|
|_CMP02_ComputeSummary.ps1| Uses the output (and possibly modified file) from the _CMP01_CollectSubs.ps1 script. Processes each sub to get a compute summary - VMs and AMLS Clusters and outputs a total.|
|_CMP02_TagCompliance.ps1| Uses the output (and possibly modified file) from the _CMP01_CollectSubs.ps1 script. Processes each sub to scan all resource groups counting how many there are and how many are tagged.|
|_CMP03_Check.ps1| This is the script that does the actual compliance check. Driven by another driver file like _CMP02_Driver.ps1. It iterates over all of the resource group buckets, except Special, to determine what has been tagged and what has not.|
|_CMP04_IsolatedDelete.ps1| This is the script that does the actual compliance check. Driven by another driver file like _CMP02_Driver.ps1. Looks for resource groups with a given name pattern and deletes them. Super useful if you have common names on groups you want to ditch.|


***NOTE*** To do actual cleanup, and to specify the required tags for your need, change teh _CMP03_Check.ps1 script.
