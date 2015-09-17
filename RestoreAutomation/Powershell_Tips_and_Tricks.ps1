#Pipeline examples

#Investigating your objects
[string]$string ="Earl Grey, hot."
$string | Get-Member

$integer=1
$integer | Get-Member

$datarow=Invoke-Sqlcmd -ServerInstance PICARD -Database tempdb `
    -Query "Select name,recovery_model_Desc FROM sys.databases"
$datarow | Get-Member

$datarow | Measure-Object

#Getting freespace for disk volumes
Get-WmiObject win32_volume | `
    where {$_.drivetype -eq 3} | `
    Sort-Object name | `
    Format-Table name, label,@{l="Size(GB)";e={($_.capacity/1gb).ToString("F2")}},@{l="Free Space(GB)";e={($_.freespace/1gb).ToString("F2")}},@{l="% Free";e={(($_.Freespace/$_.Capacity)*100).ToString("F2")}}

#Remove old backups
cd C:
dir \\PICARD\C$\Backups -Recurse| `
Where-Object {$_.Extension  -eq ".trn" -and $_.LastWriteTime -lt (Get-Date).AddHours(-3)} |`
Remove-Item -WhatIf

#SQL Agent Job example
cd C:\
#Prep the demo by clearing out current backups
dir \\PICARD\C$\Backups\Tips -Recurse| rm -recurse -Force

#backup your databases
#get a collection of databases
$dbs = Invoke-Sqlcmd -ServerInstance localhost -Database tempdb -Query "SELECT name FROM sys.databases WHERE database_id > 4"

#Get a formatted string for the datetime
$datestring =  (Get-Date -Format 'yyyyMMddHHmm')

#loop through the databases
foreach($db in $dbs.name){
    $dir = "C:\Backups\Tips\$db"
    #does the backup directory exist?  If not, create it
    if(!(Test-Path $dir)){New-Item -ItemType Directory -path $dir}
    
    #Get a nice name and backup your database to it
    $filename = "$db-$datestring.bak"
    $backup=Join-Path -Path $dir -ChildPath $filename
    $sql = "BACKUP DATABASE $db TO DISK = N'$backup' WITH COMPRESSION"
    Invoke-Sqlcmd -ServerInstance localhost -Database tempdb -Query $sql -QueryTimeout 6000
    #Delete old backups
    Get-ChildItem $dir\*.bak| Where {$_.LastWriteTime -lt (Get-Date).AddMinutes(-1)}|Remove-Item

}

#now, copy and paste this into an agent job and schedule it!

dir \\PICARD\C$\Backups\Tips -Recurse


#Working with the SQLPS provider
#loaded as part of the SQLPS module (SQL Server 2012 client tools).
#If you're using the SQL 2008 or prior client tools, you need to add the snap-in.  PRO TIP: USe the SQL 2012 client tools.
Import-Module SQLPS

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

dir databases -Force | select name,createdate,@{name='DataSizeMB';expression={$_.dataspaceusage/1024}} | Format-Table -AutoSize

dir databases | Get-Member
#note that these are SMO objects

#let's work with logins
$dblogins = dir logins 
#reset state
foreach($dblogin in $dblogins){
    $dblogin.defaultdatabase = 'master'
}

dir logins | select name,defaultdatabase

#set all default dbs for non-system logins to tempdb
foreach($dblogin in $dblogins){
    $dblogin.defaultdatabase = 'tempdb'
}

dir logins -Force | select name,defaultdatabase


#Let's look at the CMS
CD "SQLSERVER:\SQLRegistration\Central Management Server Group\PICARD"
dir

#we can see all the servers in our CMS
#now let's use it to run all our systemdb backups
cd C:\
dir C:\Backups\ | rm -Force -Recurse

dir C:\Backups\

$CMS='PICARD'
$servers=@((dir "SQLSERVER:\SQLRegistration\Central Management Server Group\$CMS").Name)
$servers+=$cms

foreach($server in $servers){
    
    $dbs = Invoke-SqlCmd -ServerInstance $server -Query "select name from sys.databases where database_id in (1,3,4)"
    $pathname= "\\HikaruDC\Backups\"+$server.Replace('\','_')
    if(!(test-path $pathname)){mkdir $pathname}
    foreach ($db in $dbs.name){
        $dbname = $db.TrimEnd()
        $sql = "BACKUP DATABASE $dbname TO DISK='$pathname\$dbname.bak' WITH COMPRESSION,INIT"
        Invoke-SqlCmd -ServerInstance $server -Query $sql
    }
}

dir C:\Backups\ -rec

#What do functions look like?
function Get-FreeSpace{
    param([string] $hostname = ($env:COMPUTERNAME))

	gwmi win32_volume -computername $hostname  | where {$_.drivetype -eq 3} | Sort-Object name `
	 | ft name,label,@{l="Size(GB)";e={($_.capacity/1gb).ToString("F2")}},@{l="Free Space(GB)";e={($_.freespace/1gb).ToString("F2")}},@{l="% Free";e={(($_.Freespace/$_.Capacity)*100).ToString("F2")}}

}

#They can get pretty advanced
#load assemblies
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
$ErrorActionPreference = 'Inquire'

function Export-SQLDacPacs{
    param([string[]] $Instances = 'localhost',
          [string] $outputdirectory=([Environment]::GetFolderPath("MyDocuments"))
        )

#get the sqlpackage executable
$sqlpackage = get-childitem 'C:\Program Files (x86)\Microsoft SQL Server\120\DAC\bin\sqlpackage.exe'

#declare a select query for databases
$dbsql = @"
SELECT name FROM sys.databases
where database_id >4 and state_desc = 'ONLINE'
"@

#loop through each instance
foreach($instance in $Instances){
    #set processing variables
    $dbs = Invoke-Sqlcmd -ServerInstance $instance -Database tempdb -Query $dbsql
    $datestring =  (Get-Date -Format 'yyyyMMddHHmm')
    $iname = $instance.Replace('\','_')

    #extract each db
    foreach($db in $dbs.name){
        $outfile = Join-Path $outputdirectory -ChildPath "$iname-$db-$datestring.dacpac"
        $cmd = "& '$sqlpackage' /action:Extract /targetfile:'$outfile' /SourceServerName:$instance /SourceDatabaseName:$db"
        Invoke-Expression $cmd
        }
    }
}


#But once you write it, it's easy to call
Export-SQLDacPacs -instances 'PICARD' -outputdirectory '\\HikaruDC\Backups\'

#working with the profile

#The profile may not exist, so you'd have to create it
#Let's rename the profile so we can create it, then we'll clean up afterwards.
$profilebak = "$profile.bak"
Move-Item $profile $profilebak

if(!(Test-Path $profile)){New-Item -Path $profile -ItemType file -Force}

#Add 'Import-Module SQLPS -disablenamechecking'
#Add the following function
function Beam-MeUp{
    param([string] $target)
    "Scotty, beam $target up."
}

#easiest way to edit is...
powershell_ise $profile

#Add Beam-MeUp function

#If we make changes, we can reload by "executing" the profile
. $profile

#Now we can run the function
Beam-MeUp -target Kirk
Beam-MeUp -target Spock

#see, created.  Boom.  Now I'm going to move the previous profile back.
Remove-Item $profile
Move-Item $profilebak $profile

#We can use any of the functions in the profile, they're loaded at session start
Get-FreeSpace -hostname PICARD


#Working with modules
#We can get a listing of all our available modules
Get-Module -ListAvailable

#SQLPS is provided with SQL2012 client tools
#It provides the SQLPS provider as well as some functions
Get-Command -Module sqlcheck

#What gets used a lot is Invoke-SqlCmd, a wrapper for sqlcmd

#We can also write our own modules to extend Powershell
#Open up the SQLCheck module and examine the Test-SQLConnection function
#Now let's load the module
Import-Module SQLCheck

#Now that function is available to us as if
Test-SQLConnection -Instances @('PICARD','RIKER','NotAValidServer')

#Cool. Now let's have some fun
#Enterprise wide connection test
$CMS='PICARD'
$servers=@((dir "SQLSERVER:\SQLRegistration\Central Management Server Group\$CMS").Name)

$servers+=$cms
Test-SQLConnection -Instances $servers
