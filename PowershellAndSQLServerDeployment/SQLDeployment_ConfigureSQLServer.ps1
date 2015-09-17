[System.Reflection.Assembly]::LoadWithPartialName('Microsoft.SqlServer.SMO') | Out-Null

$servers = @('KIRK','SPOCK')

foreach ($server in $servers){
    $smosrv = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server $server

    $smosrv.Configuration.MaxServerMemory.ConfigValue = 4000
    $smosrv.Configuration.MinServerMemory.ConfigValue = 0
    $smosrv.Configuration.MaxDegreeOfParallelism.ConfigValue = 2
    $smosrv.Configuration.OptimizeAdhocWorkloads.ConfigValue = 1
    $smosrv.Configuration.Alter()

    $smosrv.JobServer.MaximumHistoryRows = 10000
    $smosrv.JobServer.MaximumJobHistoryRows = 2000
    $smosrv.JobServer.Alter()

}
