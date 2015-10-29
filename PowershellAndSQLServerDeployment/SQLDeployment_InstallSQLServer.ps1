﻿#Load configurations
. C:\Users\Administrator\Documents\DSCConfigurations.ps1

#switch to the right directory and remove old configs if they exist
cd C:\IntroToPowershell
if(test-path .\SQLServer){ Remove-Item .\SQLServer -Recurse -Force }

#Build .MOFs and deploy
SQLServer -ComputerName @('KIRK','SPOCK')
Start-DscConfiguration .\SQLServer -Wait -Verbose -Force