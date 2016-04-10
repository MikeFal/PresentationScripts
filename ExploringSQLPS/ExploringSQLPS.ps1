#Where does the module live?
Get-Module -ListAvailable *SQL*

#Lets look in that location and check out some of the files.
dir 'C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS'

powershell_ise 'C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SQLPS.PS1'
powershell_ise 'C:\Program Files (x86)\Microsoft SQL Server\120\Tools\PowerShell\Modules\SQLPS\SqlPsPostScript.PS1'


#Cool, now load the module
Import-Module SQLPS

#What's that warning?
Import-Module SQLPS -Verbose
Import-Module SQLPS -DisableNameChecking

#Ok, so what's actually in it?
Get-Command -Module SQLPS
Get-Command -Module SQLPS | Measure-Object

#-----------------------------------------
#Using the provider
Get-PSDrive
Get-PSDrive -PSProvider SqlServer

cd SQLSERVER:\
dir

CD SQL
dir
#Only the local machine is visible 

CD PICARD
dir

CD DEFAULT
dir

CD databases
dir

#Notice what type of objects these are
Get-Item AdventureWorks2014 | Get-Member

#We can make use of these objects
dir | select name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}} | Format-Table -AutoSize

#We can drill further down

dir AdventureWorks2014\Tables
dir AdventureWorks2014\StoredProcedures

#How is this different than system views? Going across multiple servers
$servers = @('PICARD','RIKER')
$servers | ForEach-Object {dir SQLSERVER:\SQL\$_\DEFAULT\DATABASES} | select @{n='Server';e={$_.Parent.Name}},name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}} | Format-Table -AutoSize

#-----------------------------------------
#Using the cmdlets

Get-Command -Module SQLPS
Get-Command -Module SQLPS | Measure-Object

Get-SqlDatabase -ServerInstance PICARD -Name AdventureWorks2014

Get-SqlInstance -MachineName PICARD

Backup-SqlDatabase -ServerInstance PICARD -Database AdventureWorks2014  -BackupFile 'C:\TEMP\AdventureWorks2014.bak' -Initialize -CopyOnly -Script

Backup-SqlDatabase -ServerInstance PICARD -Database AdventureWorks2014  -BackupFile 'C:\TEMP\AdventureWorks2014.bak' -Initialize -CopyOnly

$sql=@'
SET NOCOUNT ON
select sp.name,count(1) db_count
from sys.server_principals sp
join sys.databases d on (sp.sid = d.owner_sid)
group by sp.name
'@

$sqlcmdout = sqlcmd -S PICARD -d tempdb -Q $sql
$invokesqlout = Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb -Query $sql


$sqlcmdout
$invokesqlout

$sqlcmdout[0].GetType()
$invokesqlout[0].GetType()

#Practical use
$instances = @(’PICARD’,’RIKER’)

#Check your SQL Server versions
$instances | ForEach-Object {Get-Item “SQLSERVER:\SQL\$_\DEFAULT”} | Select-Object Name,VersionString

#Check your databases for last backup
$instances | ForEach-Object {Get-ChildItem “SQLSERVER:\SQL\$_\DEFAULT\Databases”} |
    Sort-Object Size -Descending | 
    Select-Object @{n='Server';e={$_.parent.Name}},Name,LastBackupDate,Size

#Backup up your system databases
foreach($instance in $instances){
    $dbs = Get-ChildItem SQLSERVER:\SQL\$instance\DEFAULT\Databases -Force |Where-Object {$_.IsSystemObject -eq $true -and $_.Name -ne 'TempDB'}
    $dbs |ForEach-Object {Backup-SqlDatabase -ServerInstance $instance -Database $_.Name -BackupFile "C:\Backups\$($_.Name).bak" -Initialize }
    }
$instances |ForEach-Object {Invoke-Command -ComputerName $_ -ScriptBlock {Get-ChildItem C:\Backups\*.bak}}

#Creating a point in time restore script
Set-Location C:\Temp
$LastFull= Get-ChildItem '\\PICARD\C$\Backups\AdventureWorks2014\*.bak' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$logs = Get-ChildItem '\\PICARD\C$\Backups\AdventureWorks2014\*.trn' | Where-Object {$_.LastWriteTime -gt $LastFull.LastWriteTime} | Sort-Object LastWriteTime

$MoveFiles = @()
$MoveFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('AdventureWorks2014_Data','C:\DBFiles\data\AdventureWorks2014New_Data.mdf')
$MoveFiles += New-Object Microsoft.SqlServer.Management.Smo.RelocateFile ('AdventureWorks2014_Log','C:\DBFiles\log\AdventureWorks2014New_Log.ldf')

$db = 'AdventureWork2014New'
Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -RelocateFile $MoveFiles -BackupFile $LastFull.FullName -RestoreAction Database -NoRecovery -Script | Out-File 'C:\Temp\Restore.sql'
foreach($log in $logs){
    if($log -eq $logs[$logs.Length -1]){
        Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -BackupFile $log.FullName -RestoreAction Log -Script | Out-File 'C:\Temp\Restore.sql' -Append
    }
    else{
        Restore-SqlDatabase -ServerInstance 'PICARD' -Database $db -BackupFile $log.FullName -RestoreAction Log -NoRecovery -Script | Out-File 'C:\Temp\Restore.sql' -Append
    }
}