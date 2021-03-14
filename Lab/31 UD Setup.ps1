if (-not (Get-Lab)) {
    Write-Error 'Please importe the lab first' -ErrorAction Stop
}

$here = $PSScriptRoot
$webServers = Get-LabVM -Role WebServer | Select-Object -First 1
$udRepositoryPath = 'C:\ProgramData\UniversalAutomation\Repository'
$localUdRepositoryPath = "$here\..\Dashboards\*"

Copy-LabFileItem -Path $localUdRepositoryPath -ComputerName $webServers -DestinationFolderPath $udRepositoryPath

foreach ($webServer in $webServers) {

    $cert = Get-LabCertificate -SearchString "CN=$($webServer.FQDN)" -FindType FindBySubjectDistinguishedName -Location CERT_SYSTEM_STORE_LOCAL_MACHINE -Store My -ComputerName $webServer
    

    Invoke-LabCommand -ActivityName 'Setup Web Site' -ScriptBlock {

        Get-Website -Name 'Default Web Site' | Remove-Website

        Expand-Archive -Path (Resolve-Path -Path C:\Universal*x64*.zip).Path -DestinationPath $webPath

        $user = Get-ADUser -Identity $serviceUsername
        $appPool = New-WebAppPool -Name UD
        $appPool.processModel.userName = "$($env:USERDOMAIN)\$($user.Name)"
        $appPool.processModel.password = $serviceUserPassword
        $appPool.processModel.identityType = 'SpecificUser'
        $appPool | Set-Item

        $webSite = New-Website -Name UD -Port 80 -ApplicationPool $appPool.name -PhysicalPath $webPath
        New-WebBinding -Name $webSite.name -IP "*" -Port 443 -Protocol https
        Get-Item -Path "Cert:\LocalMachine\My\$($cert.Thumbprint)" | New-Item -Path IIS:\SslBindings\0.0.0.0!443

        Set-ItemProperty -Path C:\ProgramData -Name Attributes -Value Normal

        #Stop-Service -Name PowerShellUniversal
        #Copy-Item -Path C:\ProgramData\UniversalAutomation -Destination C:\ProgramData\UniversalAutomationIIS -Recurse

        Add-NTFSAccess -Path $webPath -Account $serviceUsername -AccessRights Modify
        Add-NTFSAccess -Path C:\ProgramData\UniversalAutomation -Account $serviceUsername -AccessRights Modify

        iisreset /stop
        Start-Service -Name PowerShellUniversal

        @'
New-UDDashboard -Title "Test Dashboard 1" -Content {
    New-UDTypography -Text "Hello, World!"

    New-UDButton -Text "Learn more about Universal Dashboard" -OnClick {
        Invoke-UDRedirect https://docs.ironmansoftware.com
    }
}
'@ | Out-File -FilePath C:\ProgramData\UniversalAutomation\Repository\Test1.ps1

        @'
New-UDDashboard -Title "Test Dashboard 2" -Content {
    New-UDTypography -Text "Hello, World!"

    New-UDButton -Text "Learn more about Universal Dashboard" -OnClick {
        Invoke-UDRedirect https://docs.ironmansoftware.com
    }
}
'@ | Out-File -FilePath C:\ProgramData\UniversalAutomation\Repository\Test2.ps1

        $latestUDDashboardFramework = dir C:\ProgramData\PowerShellUniversal\Dashboard\Frameworks\UniversalDashboard |
        Sort-Object -Descending |
        Select-Object -ExpandProperty Name -First 1

        @"
New-PSUDashboard -Name "Test1" -FilePath "Test1.ps1" -BaseUrl "/Test1" -Framework "UniversalDashboard:$latestUDDashboardFramework" 
New-PSUDashboard -Name "Test2" -FilePath "Test2.ps1" -BaseUrl "/Test2" -Framework "UniversalDashboard:$latestUDDashboardFramework"
"@ | Out-File -FilePath C:\ProgramData\UniversalAutomation\Repository\.universal\dashboards.ps1

    } -ComputerName $webServer -Variable (Get-Variable -Name cert, webPath, serviceUsername, serviceUserPassword)

}

Write-Host "2. - Creating Snapshot 'AfterPuSetup'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterPowerShellUniversalSetup
