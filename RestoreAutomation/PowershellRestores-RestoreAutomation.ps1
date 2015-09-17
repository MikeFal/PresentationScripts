#demo 3 - Restore module
#Download module - https://github.com/MikeFal/PowerShell
Import-Module RestoreAutomation
Get-Command -Module RestoreAutomation
Get-Help New-Restore
Get-Help New-Restore -Full
Get-Help New-Restore -Examples

#Restore a copy of AdventureWorks2012
$Server = 'PICARD'
$database = 'AdventureWorks2012_copy'
$RestoreFile =  New-Restore -dir '\\PICARD\C$\Backups\AdventureWorks2012' -server $Server -database $database
notepad $RestoreFile.FullName

#Cleanup the copy database if it exists
If(Test-Path SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database){Remove-Item SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database}

#Restore the database using the module
$RestoreLocation = 'C:\DBFiles\AdventureWorks_demo'
Invoke-Command -ComputerName $Server -ScriptBlock {if(!(Test-Path $using:RestoreLocation)){New-Item -ItemType Directory -Path $using:RestoreLocation}}
New-Restore -dir "\\PICARD\C$\Backups\AdventureWorks2012" -server $Server -database $database -newdata $RestoreLocation -newlog $RestoreLocation -Execute

#Lookup the databases
Get-ChildItem SQLSERVER:\SQL\$Server\DEFAULT\Databases | Select-Object Name,CreateDate,RecoveryModel,Owner| Format-Table -AutoSize

#demo 4 - Migrate database
Get-Help Sync-DBUsers
$database = "AdventureWorks2012_migration"
$Server = "RIKER"
$RestoreLocation = 'C:\DBFiles\AdventureWorks_migration'
Invoke-Command -ComputerName $Server -ScriptBlock {if(!(Test-Path $using:$RestoreLocation)){New-Item -ItemType Directory -Path $using:RestoreLocation}}

#Cleanup the migration database if it exists
If(Test-Path SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database){Remove-Item SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database}

New-Restore -dir "\\PICARD\C$\Backups\AdventureWorks2012" -server $Server -database $database -newdata $RestoreLocation -newlog $RestoreLocation -Owner 'sa' -Execute
#Invoke-Sqlcmd -ServerInstance $Server -Query "ALTER AUTHORIZATION ON database::[$database] TO [sa]"

#Lookup the databases
Get-ChildItem SQLSERVER:\SQL\$Server\DEFAULT\Databases | Select-Object Name,CreateDate,RecoveryModel,Owner| Format-Table -AutoSize

Sync-DBUsers -server $Server -database $database

#Create the logins
$logins=Sync-DBUsers -server $Server -database $database

foreach($login in $logins.name){
    Invoke-Sqlcmd -ServerInstance $Server -Query "CREATE LOGIN [$login] WITH PASSWORD='P@55w0rd'"
}

Sync-DBUsers -server $Server -database $database

#Demo 5 - Restore testing
Get-Help Get-DBCCCheckDB
$database = "CorruptMe_Test"
$Server = "PICARD"
$RestoreLocation = 'C:\DBFiles\CorruptMe_Test'
#Cleanup the test database if it exists
If(Test-Path SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database){Remove-Item SQLSERVER:\SQL\$Server\DEFAULT\Databases\$database}

Invoke-Command -ComputerName $Server -ScriptBlock {if(!(Test-Path $using:RestoreLocation)){New-Item -ItemType Directory -Path $using:RestoreLocation}}
New-Restore -server $Server -database $database -dir "\\PICARD\C$\Backups\corruptme" -newdata $RestoreLocation -newlog $RestoreLocation -Execute

Get-DBCCCheckDB -server $Server -database $database

#messy, let's try that again
Get-DBCCCheckDB -server $Server -database $database | Select level,messagetext,repairlevel | Format-Table -AutoSize

#If we want the full DBCC check
Get-DBCCCheckDB -server $Server -database $database -Full | where {$_.level -gt 10} | Select messagetext,repairlevel | Format-Table

