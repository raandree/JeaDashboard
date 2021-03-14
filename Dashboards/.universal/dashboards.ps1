New-PSUDashboard -Name "JeaTabs" -FilePath "JeaTabs.ps1" -BaseUrl "/JeaTabs" -Framework "UniversalDashboard:3.2.0" -SessionTimeout 0 
New-PSUDashboard -Name "Test1" -FilePath "Test1.ps1" -BaseUrl "/Test1" -Framework "UniversalDashboard:3.2.0" -SessionTimeout 0 -AutoDeploy 
New-PSUDashboard -Name "_JeaTask" -FilePath "_JeaTask.ps1" -BaseUrl "/_JeaTask" -Framework "UniversalDashboard:3.3.2" -SessionTimeout 0 -AutoDeploy 
New-PSUDashboard -Name "_JeaMenu" -FilePath "_JeaMenu.ps1" -BaseUrl "/_JeaMenu" -Framework "UniversalDashboard:3.2.0" -SessionTimeout 0 -AutoDeploy