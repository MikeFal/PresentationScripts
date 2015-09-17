#Import the SMO classes
[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | out-null
[System.Reflection.Assembly]::LoadWithPartialName("Microsoft.SqlServer.SmoExtended") | Out-Null

#Get our same full backup
$LastFull= Get-ChildItem '\\PICARD\C$\Backups\AdventureWorks2012\*.bak' | Sort-Object LastWriteTime -Descending | Select-Object -First 1
$RestoreLocation= 'C:\DBFiles\AWRD'

#Now we declare our SMO objects
$smosrv = New-Object Microsoft.SqlServer.Management.Smo.Server 'PICARD'
$smorestore=New-Object Microsoft.SqlServer.Management.Smo.Restore
$smorestore.Action="Database"
$smorestore.Database="AdventureWorks2012SMO"
$smorestore.Devices.AddDevice($LastFull.FullName, "File")


#Using the SMO, we can flexibly manage the restore by reading the files
$files=$smorestore.ReadFileList($smosrv)
foreach($file in $files){
        $filename = $file.PhysicalName.Substring($file.PhysicalName.LastIndexOf("\")+1).Replace(".","_smo.")
        $newfile = New-Object("Microsoft.SqlServer.Management.Smo.RelocateFile") ($file.LogicalName,"$RestoreLocation\$filename")
        $smorestore.RelocateFiles.Add($newfile) | out-null
}

#We can then script out the restore with the .Script() method or execute the restore with .SqlRestore().
#We need to pass the SMO Server object ($smosrv) for the instance we want to restore on
$smorestore.Script($smosrv)
$smorestore.SqlRestore($smosrv)

#Not to different from the restore cmdlets. This is because the cmdlets are all based on SMO and use it under the scenes.
#Using the SMO directly affords us more control