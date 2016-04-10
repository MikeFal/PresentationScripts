#Login Demo

#Clean Old stuff
$dropquery = @'
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'adw_readonly') DROP LOGIN adw_readonly;
USE AdventureWorks2014;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'adw_readonly') DROP USER adw_readonly;
'@
Invoke-SqlCmd -ServerInstance PICARD -Database tempdb -Query $dropquery
Invoke-SqlCmd -ServerInstance RIKER -Database tempdb -Query $dropquery

$query1 = @"
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'adw_readonly') DROP LOGIN adw_readonly;
CREATE LOGIN adw_readonly WITH PASSWORD='password',CHECK_POLICY=OFF;
USE AdventureWorks2014;
IF EXISTS (SELECT 1 FROM sys.database_principals WHERE name = 'adw_readonly') DROP USER adw_readonly;
CREATE USER adw_readonly FROM LOGIN adw_readonly;
GRANT SELECT ON database::[AdventureWorks2014] to adw_readonly;
"@

Invoke-SqlCmd -ServerInstance ENTERPRISE -Database tempdb -Query $query1

Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database AdventureWorks2014 -Username adw_readonly -Password 'password' -Query 'select top(10) FirstName,LastName,ModifiedDate from person.person;'

Switch-SqlAvailabilityGroup -Path SQLSERVER:\SQL\RIKER\DEFAULT\AvailabilityGroups\ENTERPRISE

Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database AdventureWorks2014 -Username adw_readonly -Password 'password' -Query 'select top(10) FirstName,LastName,ModifiedDate from person.person;'

$query2 = @"
IF EXISTS (SELECT 1 FROM sys.server_principals WHERE name = 'adw_readonly') DROP LOGIN adw_readonly;
CREATE LOGIN adw_readonly WITH PASSWORD='password',CHECK_POLICY=OFF;
"@
Invoke-SqlCmd -ServerInstance ENTERPRISE -Database tempdb -Query $query2

Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database AdventureWorks2014 -Username adw_readonly -Password 'password' -Query 'select top(10) FirstName,LastName,ModifiedDate from person.person;'

. 'C:\Program Files\WindowsPowerShell\Copy-SQLLogins.ps1'

Copy-SQLLogins -source PICARD -logins 'adw_readonly' 
Copy-SQLLogins -source PICARD -logins 'adw_readonly' -ApplyTo RIKER

Invoke-Sqlcmd -ServerInstance ENTERPRISE -Database AdventureWorks2014 -Username adw_readonly -Password 'password' -Query 'select top(10) FirstName,LastName,ModifiedDate from person.person;'

#Failback to PICARD
Switch-SqlAvailabilityGroup -Path SQLSERVER:\SQL\PICARD\DEFAULT\AvailabilityGroups\ENTERPRISE -


#Backup Demo
#cleanup
$dropjobquery = "USE msdb;EXEC sp_delete_job @job_name='Backup AdventureWorks - FULL';"
Invoke-SqlCmd -ServerInstance PICARD -Database tempdb -Query $dropjobquery
Invoke-SqlCmd -ServerInstance RIKER -Database tempdb -Query $dropjobquery

#Let's create a job
$smosrv = New-Object Microsoft.SqlServer.Management.Smo.Server 'PICARD'
$job = New-Object Microsoft.SqlServer.Management.Smo.Agent.Job ($smosrv.JobServer,'Backup AdventureWorks - FULL')
$job.Description = 'Demo Backup Job for AdventureWorks2014'

$jobstep = new-object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($job, 'Execute Script')
$jobstep.SubSystem = 'TransactSQL'
$jobstep.Command = "BACKUP DATABASE AdventureWorks2014 TO DISK = 'C:\Backups\ADW2014_AGs.bak' WITH INIT;"
$jobstep.OnSuccessAction = 'QuitWithSuccess'
$jobstep.OnFailAction = 'QuitWithFailure'
$job.Create()
$jobstep.Create()
$job.ApplyToTargetServer($smosrv.Name)

$job.Start()

#Run SQL query for backup info - PICARD

#Failover
Switch-SqlAvailabilityGroup -Path SQLSERVER:\SQL\RIKER\DEFAULT\AvailabilityGroups\ENTERPRISE

#Let's create a job on RIKER
$smosrv = New-Object Microsoft.SqlServer.Management.Smo.Server 'RIKER'
$job = New-Object Microsoft.SqlServer.Management.Smo.Agent.Job ($smosrv.JobServer,'Backup AdventureWorks - FULL')
$job.Description = 'Demo Backup Job for AdventureWorks2014'

$jobstep = new-object Microsoft.SqlServer.Management.Smo.Agent.JobStep ($job, 'Execute Script')
$jobstep.SubSystem = 'TransactSQL'
$jobstep.Command = "BACKUP DATABASE AdventureWorks2014 TO DISK = 'C:\Backups\ADW2014_AGs.bak' WITH INIT;"
$jobstep.OnSuccessAction = 'QuitWithSuccess'
$jobstep.OnFailAction = 'QuitWithFailure'
$job.Create()
$jobstep.Create()
$job.ApplyToTargetServer($smosrv.Name)

$job.Start()

#Run SQL query for backup info - RIKER


#PATCHING info
Get-Item SQLSERVER:\SQL\PICARD\DEFAULT | select Name,Version
Get-Item SQLSERVER:\SQL\RIKER\DEFAULT | select Name,Version

Get-Item SQLSERVER:\SQL\PICARD\DEFAULT\DATABASES\AdventureWorks2014 | select Name,Version
Get-Item SQLSERVER:\SQL\RIKER\DEFAULT\DATABASES\AdventureWorks2014 | select Name,Version