#A few things before we get started(these need to be run as administrator)
Update-Help
Set-ExecutionPolicy RemoteSigned

#Execution policies are a security feature to protect against malicious scripts
get-help about_execution_policies

#Cmdlets - the core functionality
Get-Command
Get-Command | Measure-Object #Don't worry about the pipe

Get-Command -Name *New*

Get-Help Get-Command
Get-Help Get-Command -Full
Get-Help Get-Command -ShowWindow
Get-Help Get-Command -Online

#Variables and using variables
Get-Help about_variables -ShowWindow

get-help about*

#Powershell variables start with a $
$string="This is a variable"
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
$datestring|gm

#EVERYTHING is an object.  This means more than just basic types:
$file = New-Item -ItemType File -Path 'C:\TEMP\junkfile.txt'
$file | gm

$file.Name
$file.FullName
$file.Extension
$file.LastWriteTime

Remove-Item $file

#Working with the SQLPS provider
#loaded as part of the SQLPS module (SQL Server 2012 client tools).
#If you're using the SQL 2008 or prior client tools, you need to add the snap-in.  PRO TIP: USe the SQL 2012 client tools.
Import-Module SQLPS -Verbose #-DisableNameChecking

#Invoke-SqlCmd is the most commonly used cmdlet
Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb `
    -Query "Select name,recovery_model_Desc FROM sys.databases"

#Everything is an object!
$datarow=Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb `
    -Query "Select name,recovery_model_Desc FROM sys.databases"

$datarow | Get-Member

$datarow | Measure-Object

#See the commands available
Get-Command -Module SQLPS

#You're working "directory" will be set to be the provider.
#let's poke around
cls
Get-PSDrive

#Change to the SQL Server Provider
CD SQLSERVER:\
dir

#We can browse our SQL Servers as if they were directories
cls
CD SQL\PICARD\
dir

CD DEFAULT
dir

dir databases -Force | select name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}},LastBackupDate | Format-Table -AutoSize

dir databases | Get-Member
#note that these are SMO objects

#There are cmdlets in the provider
Backup-SqlDatabase -ServerInstance PICARD -Database AdventureWorks2012 -BackupFile C:\Backups\AdventureWorks2012_jumpstart.bak -Initialize

#Most of them run SQL behind the scenes
Backup-SqlDatabase -ServerInstance PICARD -Database AdventureWorks2012 -BackupFile C:\Backups\AdventureWorks2012_jumpstart.bak -Script

#Combining the 
dir Databases | ForEach-Object {Backup-SqlDatabase -ServerInstance PICARD -Database $_.Name -BackupFile "C:\Backups\$($_.Name).bak" -Initialize}
cd c:\
dir '\\PICARD\C$\Backups'