Clear-Host
$StartTime = Get-Date

#Load Powershell modules
Import-Module FailoverClusters
Import-Module SQLPS -DisableNameChecking

#Create fileshare for witness (Already done for purposes of the demo)
#New-Item -Path 'C:\QWitness' -ItemType Directory 
#New-SmbShare -name QWitness -Path 'C:\QWitness'

#---------------------------------------------------
#Create FailoverCluster
New-Cluster -Name 'NCC1701' -StaticAddress '192.168.10.100' -NoStorage -Node @('KIRK','SPOCK') | Set-ClusterQuorum -FileShareWitness '\\hikarudc\qwitness'

#Make sure new cluster is registered in DNS before proceeding
Start-Sleep -Seconds 60
ipconfig /flushdns
Write-Host -ForegroundColor Cyan "Cluster Built...."

#---------------------------------------------------
#Build AG Group
#Set initial variables

$AGName = 'ENTERPRISE'
$PrimaryNode = 'KIRK'
$IP = '192.168.10.101/255.255.255.0'
$replicas = @()

#Get nodes within the cluster
$cname = (Get-Cluster -name $PrimaryNode).name 
$nodes = (get-clusternode -Cluster $cname).name 

#Enable SQL AlwaysOn for the Service
$nodes | ForEach-Object {Enable-SqlAlwaysOn -path "SQLSERVER:\SQL\$_\DEFAULT" -Force}

#'Gotcha' sql permissions to make an AG work
$sqlperms = @"
use [master];
GRANT ALTER ANY AVAILABILITY GROUP TO [NT AUTHORITY\SYSTEM];
GRANT CONNECT SQL TO [NT AUTHORITY\SYSTEM];
GRANT VIEW SERVER STATE TO [NT AUTHORITY\SYSTEM];

CREATE LOGIN [SDF\sqlsvc] FROM WINDOWS;
GRANT CONNECT ON endpoint::[HADR_Endpoint] to [SDF\sqlsvc];
"@

#Create the Endpoint, replica object, and apply special permissions
foreach($node in $nodes){
     New-SqlHadrEndpoint HADR_Endpoint -Port 5022 -Path SQLSERVER:\SQL\$node\DEFAULT | Set-SqlHadrEndpoint -State 'Started'
     $replicas += New-SqlAvailabilityReplica -Name $node -EndpointUrl "TCP://$($node):5022" -AvailabilityMode 'SynchronousCommit' -FailoverMode 'Automatic' -AsTemplate -Version 12
     Invoke-Sqlcmd -ServerInstance $node -Database master -Query $sqlperms
}

#Create the AG, join the replicas, create the listener
New-SqlAvailabilityGroup -Name $AGName -Path "SQLSERVER:\SQL\$PrimaryNode\DEFAULT" -AvailabilityReplica $replicas
$nodes -ne $PrimaryNode | ForEach-Object {Join-SqlAvailabilityGroup -path "SQLSERVER:\SQL\$_\DEFAULT" -Name $AGName}
New-SqlAvailabilityGroupListener -Name $AGName -staticIP $IP -Port 1433 -Path "SQLSERVER:\Sql\$PrimaryNode\DEFAULT\AvailabilityGroups\$AGName"
Write-Host -ForegroundColor Cyan "AG Built...."

#---------------------------------------------------
#Install AdventureWorks
#prep AdventureWorks
$nodes | ForEach-Object {Restore-SqlDatabase -ServerInstance $_ -Database AdventureWorks2012 -BackupFile '\\HIKARUDC\InstallFiles\Backups\AdventureWorks2012.bak' -ReplaceDatabase -NoRecovery}

#add to AG, primary node first, then secondary nodes
Invoke-Sqlcmd -ServerInstance $PrimaryNode -Query 'RESTORE DATABASE AdventureWorks2012 WITH RECOVERY;'
Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$PrimaryNode\DEFAULT\AvailabilityGroups\$AGName" -Database AdventureWorks2012

$nodes -ne $PrimaryNode | ForEach-Object {Add-SqlAvailabilityDatabase -Path "SQLSERVER:\SQL\$_\DEFAULT\AvailabilityGroups\$AGName" -Database AdventureWorks2012}

Write-Host -ForegroundColor Cyan "AdventureWorks2012 deployed...."

$timestring =  ((Get-Date) - $StartTime).ToString()
Write-Host -ForegroundColor Cyan "AG BUILD TIME: [$timestring]"

#---------------------------------------------------
#Test Failovers
$validatequery = "SELECT @@SERVERNAME [AGNode] ,count(1) [AW_Table_Count] FROM [AdventureWorks2012].[sys].[tables]"

Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database master -Query $validatequery

Invoke-Sqlcmd -ServerInstance SPOCK -Database master -Query "ALTER AVAILABILITY GROUP [ENTERPRISE] FAILOVER"
Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database master -Query $validatequery

Invoke-Sqlcmd -ServerInstance KIRK -Database master -Query "ALTER AVAILABILITY GROUP [ENTERPRISE] FAILOVER"
Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database master -Query $validatequery

Write-Host -ForegroundColor Cyan "AG Validated...."