#Install to C:\Program File\WindowsPowershell\Modules\DSCConfigurations
Configuration SQLServer{
    param([string[]] $ComputerName)

    #This is a custom SQL Resource available from https://github.com/MikeFal/PowerShell/tree/master/cSQLResources
    Import-DscResource -Module cSQLResources

    #Part of the Microsoft DSC Resource Kit
    Import-DscResource -Module xNetworking

    Node $ComputerName {

        File DataDir{
            DestinationPath = 'C:\DBFiles\Data'
            Type = 'Directory'
            Ensure = 'Present'
        }

        File LogDir{
            DestinationPath = 'C:\DBFiles\Log'
            Type = 'Directory'
            Ensure = 'Present'
        }

        File TempDBDir{
            DestinationPath = 'C:\DBFiles\TempDB'
            Type = 'Directory'
            Ensure = 'Present'
        }

        WindowsFeature NETCore{
            Name = 'NET-Framework-Core'
            Ensure = 'Present'
            IncludeAllSubFeature = $true
            Source = 'D:\sources\sxs'
        }

        WindowsFeature FC{
           Name = 'Failover-Clustering'
            Ensure = 'Present'
            Source = 'D:\source\sxs'
        }

        xFirewall SQLFW{
            Name = 'SQLServer'
            DisplayName = 'SQL Server'
            Ensure = 'Present'
            Access = 'Allow'
            Profile = 'Domain'
            Direction = 'Inbound'
            LocalPort = '1433'
            Protocol = 'TCP'
        }

        xFirewall AGFW{
            Name = 'AGEndpoint'
            DisplayName = 'Availability Group Endpoint'
            Ensure = 'Present'
            Access = 'Allow'
            Profile = 'Domain'
            Direction = 'Inbound'
            LocalPort = '5022'
            Protocol = 'TCP'
        }
        
        cSQLInstall SQLInstall{
            InstanceName = 'MSSQLSERVER'
            InstallPath = '\\HIKARUDC\InstallFiles\SQLServer\SQL2014'
            ConfigPath = '\\HIKARUDC\InstallFiles\SQLServer\SQL2014_Core_DSC.ini'
            UpdateEnabled = $true
            UpdatePath = '\\HIKARUDC\InstallFiles\SQLServer\SQL2014\Updates'
            MixedMode = $true
            DependsOn = @("[File]DataDir","[File]LogDir","[File]TempDBDir","[WindowsFeature]NETCore")
        }
      }
}