#ATTENTION: This script will work for anyone on a server connected to vcenter with their A1 credentials without
#having to type in passwords. So just get the script on your desktop in sanman and then right-click run.

#Import VMware commands
Import-Module Vmware.VimAutomation.Vds

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false

#Get Timestamp
$Timestamp = (Get-Date -Format "yyyy-MM-dd")

#Build array for vCenters
$vCenter = "vcenter.yourdomain.edu",
#Connect to vCenter server
connect-viserver $vCenter[0]

#MEMORY
#Gives you each host's usage data
#Get-Cluster Columbia-TC-VSS3 | Get-VMHost | Select Name, NumCpu, CpuUsageMhz, CPUTotalMhz, MemoryUsageGB, MemoryTotalGB
#Gives you cluster's total SUM usage
#Get-Cluster Columbia-TC-VSS3 | Get-VMHost | Measure-Object -Property MemoryTotalGB -SUM
#If we take a sum total of memory, and a sum of used memory then subtract the two, we can also grab a random host in each cluster and use the "select MemoryTotalGB" to see if the memory is N+1
#CPU is more complicated as it requires a total sum of all the VM's CPU per cluster
#Get-Cluster Columbia-NN-Monitoring | Get-VM | Measure-Object -Property NumCpu -SUM | Select SUM
#Actually that wasn't hard at all
#Number of CPU on a host
#Get-Cluster Columbia-NN-Monitoring | Get-VMHost doit-vm-monitor1.doit.missouri.edu | Select NumCpu
#Number of hosts on Cluster
#Get-Cluster Columbia-NN-Monitoring | Get-VMHost | Measure-Object | Select Count
#If we use a bunch of $'s & foreach's we can have each cluster's total and a random solo host pulled, then subtract the $'s
#$TotalCPU = (Get-Cluster Columbia-NN-Monitoring | Get-VM | Measure-Object -Property NumCpu -SUM | Select Sum).Sum
#$HostCPU = (Get-Cluster Columbia-NN-Monitoring | Get-VMHost doit-vm-monitor1.doit.missouri.edu | Select NumCpu).NumCpu
#Doesn't work because they're not just the number
#$TotalCPU - $HostCPU
#$cluster = Get-Cluster
#$hosts = $cluster[0] | Get-VMHost 
#$TotalHostCPU = Get-Cluster $cluster[0] | Get-VMHost $hosts[0] | Select NumCpu
#$TotalVMCPU = Get-Cluster $cluster[0] | Get-VM | Measure-Object -Property NumCpu -SUM | Select SUM
#$TotalMem = Get-Cluster $cluster[0] | Get-VMHost | Measure-Object -Property MemoryTotalGB -SUM | select SUM
#$UsedMem = Get-Cluster $cluster[0] | Get-VMHost | Measure-Object -Property MemoryUsageGB -SUM | select SUM
#$Hosts = Get-Cluster $cluster[0] | Get-VMHost | Measure-Object | Select Count
#$Name = Get-Cluster $cluster[0] | Select name

$results = foreach($cluster in Get-Cluster){
    $esx = $cluster | Get-VMHost
    $vm = $esx | Get-VM
    $ds = Get-Datastore -VMHost $esx | where {$_.Type -eq "VMFS"}

    $cluster | Select @{N="VCname";E={$cluster.Uid.Split(':@')[1]}},
        #@{N="DCname";E={(Get-Datacenter -Cluster $cluster).Name}},
        @{N="Clustername";E={$cluster.Name}},
       
        @{N="---Memory---"; E={("---")}},
        @{N="Total Memory (GB)";E={($esx | Measure-Object -Property MemoryTotalGB -Sum).Sum}},
        @{N="Used Memory (GB)";E={($esx | Measure-Object -Property MemoryUsageGB -Sum).Sum}},
        #N+1 Maths
        @{N="Available Memory (GB)";E={($esx | Measure-Object -InputObject {$_.MemoryTotalGB - $_.MemoryUsageGB} -Sum).Sum}},
        #Figure out how to get a solo host's memory listed
        @{N="Single Host Memory (GB)";E={($esx | Get-Random | Measure-Object -Property MemoryTotalGB -Sum).Sum}},
        @{N="Available Mem > Single Host Mem"; E={("---")}},
        
        #Example of subtraction
        #@{N="Available Memory (GB)";E={($esx | Measure-Object -InputObject {$_.MemoryTotalGB - $_.MemoryUsageGB} -Sum).Sum}},
        
        @{N="---CPU---"; E={("---")}},
        @{N="Single Host CPU";E={($esx | Get-Random | Measure-Object -Property NumCPU -Sum).Sum}},
        @{N="Hosts in Cluster";E={($esx | Measure-Object -Property name | Select Count).Count}},
        @{N="Total Used CPU (VMs)";E={($esx | Get-VM | Measure-Object -Property NumCPU -Sum).Sum}},
        @{N="Single * (Hosts-1) > Used"; E={("---")}},
        #@{N="Configured CPU (Mhz)";E={($esx | Measure-Object -Property CpuUsageMhz -Sum).Sum}},
        
        @{N="---Disk Space---"; E={("---")}},
        @{N="Total Disk Space (GB)";E={($ds | where {$_.Type -eq "VMFS"} | Measure-Object -Property CapacityGB -Sum).Sum}},
        @{N="Configured Disk Space (GB)";E={($ds | Measure-Object -InputObject {$_.CapacityGB - $_.FreeSpaceGB} -Sum).Sum}},
        @{N="Available Disk Space (GB)";E={($ds | Measure-Object -Property FreeSpaceGB -Sum).Sum}}
	
                }

$results | export-csv -path "C:\clusterinfo.csv"

Send-MailMessage -From 'vCenterReporter <reportsquad@missouri.edu>' -To 'User02 <receiver@yourdomain.edu>' -Subject 'Cluster Report' -Body "Cluster Report is attached." -Attachments .\clusterinfo.csv -Priority High -DeliveryNotificationOption OnSuccess, OnFailure -SmtpServer 'smtpinternal.yourdomain.edu'

