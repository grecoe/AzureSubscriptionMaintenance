# Generic Examples 
<sub>Author: Daniel Grecoe, A Microsoft employee</sub>

This folder contains a group of very simple example scripts that you can use to test functionality against your subscriptons while becoming familiar with the [class modules](../Modules). 



## Example Scripts

### _ExampleSubscriptionSummary.ps1
This example shows how to get a summary for a single subscription containing:

* A summary of the resource groups<sup>1</sup>
* A breakdown of groups into buckets (DeleteLocked, ReadOnlyLocked, Unlocked, Special <sup>2</sup>)
* A listing of all AMLS workspaces and the hidden virtual machine compute contained within it.
* A listing of all other virtual machines.
* A listing of every resource type found in the subscripton with the count of the number of times the type of resource was seen across all resource groups.

<sup>1</sup> A resource group summary lists out the total count of groups, locked (ReadOnlyLock or DeleteLock) groups, number of groups older than 60 days, and a listing of regions that resource groups were found in with a total number of resource groups for the region.

<sup>2</sup> A "special" resource group is one that is a default resource group created from some other Auzre operation, contains a managed compute cluster (such as AKS or DataBricks), or any other type of resource group you want to exclude from either of the other three buckets.


### _ExampleResourceGroup.ps1
Resource groups contain all of the resources you have in Azure. It's possible that your team may even set policy on groups. For example, we have a delete script run every N days and ANY resource group we find that has no locks associated with it (unlocked) should get deleted UNLESS it's a special resource group. 

This script does some basic work with resource groups:

* A summary of the resource groups.
* A breakdown of groups into buckets (DeleteLocked, ReadOnlyLocked, Unlocked, Special)

### _ExampleCompute.ps1
For many teams, the cost of compute will be the driving factor behind the costs of a subscription. This is not always true, of course, but for a data science team like the one I work on, it definitely is.

Understanding the compute resources is critical to keeping costs of a subscription under control, so knowing whats out there and whats runnign is vital. 

The costs of a stopped virtual machine versus a deallocated virtual machine can be quite significant based on the hardware underlying the resource. To understand the difference read [this](https://blogs.technet.microsoft.com/gbanin/2015/04/22/difference-between-the-states-of-azure-virtual-machines-stopped-and-stopped-deallocated/) Microsoft blog. 

* A breakdown of the AKS cluster machines found withing AMLS workspaces <sup>1</sup>
* A breakdown of the regular virtual machines found in the subscrption. These can be DSVM machines, exposed AKS machines (not in AMLS workspaces), etc. <sup>1</sup>
* A detailed listing of all AMLS workspaces (including the compute being used).
* A detailed listing of all virtual machines.
* A detailed listing of ONLYL GPU virtual machines.

<sup>1</sup> Breakdowns lists the number of running, stopped, and deallocated machines. Further there is a SKU breakdown field that lists what types of machiens and how many of each are represented in the numbers reported.

### _ExampleStorage.ps1
This is just a simple script that shows how to upload and download files to Azure Blob Storage. Again, this could be useful for keeping a federated configuration.


### _ExampleCompliance.ps1
You made it this far!!! Thank you!

Comlpliance means different things to different groups, and it's up to you and your team to determine what it means to you. 

However, with that generic answer we couldn't write up an example now could we? So, for this example, compliance means:

* A resource group, or one of it's decendants has a ReadOnlyLock or DeleteLock applied to it. 
* A resource group MUST have the following tags applied to it: alias, project, expires

Any resource group that is non-compliant (unlocked and un-tagged) will get deleted. 

But wait, what about that one guy who doesn't follow all the steps. He tagged his resource groups but never locked them up? Ok, we'll give him a break too and add one more rule.

* An unlocked resource group that has ALL three tags applied to it will be spared...for now...

So the steps in this script are:

* Get the buckets of resource groups.
* Go through only the unlocked ones, and if ANY of the three tags are missing, delete it. (Ok, it's not really deleted because the line is commented out but...you get the picture.)

