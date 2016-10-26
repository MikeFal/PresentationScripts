#A few things before we get started(these need to be run as administrator)
Update-Help
Set-ExecutionPolicy RemoteSigned -Force

$PSVersionTable

#Execution policies are a security feature to protect against malicious scripts
get-help about_execution_policies

#----------------------------------------------------------------------
#Cmdlets - the core functionality
Get-Command
Get-Command | Measure-Object #Don't worry about the pipe

Get-Command -Name *New*

#Let's find a cmdlet
Get-Command New-*firewall*

Get-Help New-NetFirewallRule
Get-Help New-NetFirewallRule -Full
Get-Help New-NetFirewallRule -ShowWindow
Get-Help New-NetFirewallRule -Online

#Variables and using variables
get-help about*

Get-Help about_variables -ShowWindow

#----------------------------------------------------------------------
#Powershell variables start with a $
$string="Tea. Earl Grey. Hot."
$string

#We can use Get-Member to find out all the information on our objects
$string | Get-Member

#Powershell is strongly typed and uses .Net objects.
#Not just limited to strings and intgers

$date=Get-Date
$date
$date | Get-Member #gm is the alias of Get-Member

#Because they are .Net types/classes, we can use the methods and properties.
$date.Day
$date.DayOfWeek
$date.DayOfYear
$date.ToUniversalTime()

#Powershell tries to figure out the variable type when it can(implicit types)
#We can also explicitly declare our type
[string]$datestring = Get-Date #could also use [System.String]
$datestring
$datestring|Get-Member

#EVERYTHING is an object.  This means more than just basic types:
$file = New-Item -ItemType File -Path 'C:\TEMP\junkfile.txt'
$file | Get-Member

$file.Name
$file.FullName
$file.Extension
$file.LastWriteTime

Remove-Item $file

#----------------------------------------------------------------------
#Working with the provider
#loaded as part of the SQLPS module (SQL Server 2012 client tools).
#If you're using the SQL 2008 or prior client tools, you need to add the snap-in.  PRO TIP: USe the SQL 2012 client tools.
Import-Module SqlServer 

#See the commands available
Get-Command -Module SqlServer

#Your working "directory" will be set to be the provider.
#let's poke around
Clear-Host
Get-PSDrive

#Change to the SQL Server Provider
CD SQLSERVER:\
dir

#We can browse our SQL Servers as if they were directories
Clear-Host
CD SQL\PICARD\
dir

CD DEFAULT
dir

dir databases

#note that these are SMO objects
dir databases | Get-Member

dir databases -Force | select name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}},LastBackupDate | Format-Table -AutoSize

$servers = @('PICARD','RIKER')
$servers | ForEach-Object {dir SQLSERVER:\SQL\$_\DEFAULT\DATABASES} | select @{n='Server';e={$_.Parent.Name}},name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}} | Format-Table -AutoSize

#Invoke-SqlCmd is the most commonly used cmdlet
Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb `
    -Query "Select name,recovery_model_Desc FROM sys.databases"

#Everything is an object!
$datarow=Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb `
    -Query "Select name,recovery_model_Desc FROM sys.databases"

$datarow | Get-Member

$datarow | Measure-Object

#Write data to a table
$sql = "IF (select object_id('test_data')) IS NOT NULL DROP TABLE test_data;
CREATE TABLE test_data(
    host_name sysname
    ,volume_name varchar(100)
    ,SizeGB NUMERIC(10,2)
    ,FreeGM NUMERIC(10,2))"

Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb -Query $sql

$hostname = @('PICARD','RIKER')
$data = Get-WmiObject win32_volume -ComputerName $hostname  | 
            Where-Object {$_.drivetype -eq 3 -and $_.name -notlike '\\?\*'} | 
            Sort-Object name | 
            Select-Object @{l='host_name';e={$_.PSComputerName}},name,@{l="SizeGB";e={($_.capacity/1gb).ToString("F2")}},@{l="FreeGB";e={($_.freespace/1gb).ToString("F2")}}

Write-SqlTableData -ServerInstance PICARD -DatabaseName tempdb -SchemaName dbo -TableName test_data -InputData $data

Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb -Query 'SELECT * FROM test_data'

#Backups and restores
#Most of them run SQL behind the scenes
Backup-SqlDatabase -ServerInstance PICARD -Database WideWorldImporters -BackupFile C:\Backups\WideWorldImporters_jumpstart.bak -Script

Backup-SqlDatabase -ServerInstance PICARD -Database WideWorldImporters -BackupFile C:\Backups\WideWorldImporters_jumpstart.bak -Initialize -CopyOnly

#Let's get fancy
$instances = @(’PICARD’,’RIKER’)

#Backup up your system databases
foreach($instance in $instances){
    $dbs = Get-ChildItem SQLSERVER:\SQL\$instance\DEFAULT\Databases -Force |Where-Object {$_.IsSystemObject -eq $true -and $_.Name -ne 'TempDB'}
    $dbs |ForEach-Object {Backup-SqlDatabase -ServerInstance $instance -Database $_.Name -BackupFile "C:\Backups\$($_.Name).bak" -Initialize }
    }
$instances |ForEach-Object {Invoke-Command -ComputerName $_ -ScriptBlock {Get-ChildItem C:\Backups\*.bak}}

#Creating a point in time restore script
$LastFull= Get-ChildItem '\\PICARD\C$\Backups\WideWorldImporters\*.bak' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$logs = Get-ChildItem '\\PICARD\C$\Backups\WideWorldImporters\*.trn' | Where-Object {$_.LastWriteTime -gt $LastFull.LastWriteTime} | Sort-Object LastWriteTime

$MoveFiles = @()
$MoveFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('WideWorldImporters_Data','C:\DBFiles\data\WideWorldImportersNew_Data.mdf')
$MoveFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('WideWorldImporters_Log','C:\DBFiles\log\WideWorldImportersNew_Log.ldf')

$db = 'WideWorldImportersNew'
Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -RelocateFile $MoveFiles -BackupFile $LastFull.FullName -RestoreAction Database -NoRecovery -Script | Out-File 'C:\Temp\Restore.sql'
foreach($log in $logs){
    if($log -eq $logs[$logs.Length -1]){
        Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -BackupFile $log.FullName -RestoreAction Log -Script | Out-File 'C:\Temp\Restore.sql' -Append
    }
    else{
        Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -BackupFile $log.FullName -RestoreAction Log -NoRecovery -Script | Out-File 'C:\Temp\Restore.sql' -Append
    }
}

notepad 'C:\Temp\Restore.sql'