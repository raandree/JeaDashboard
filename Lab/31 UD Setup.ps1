if (-not (Get-Lab)) {
    Write-Error 'Please importe the lab first' -ErrorAction Stop
}

$here = $PSScriptRoot
$webServers = Get-LabVM -Role WebServer | Select-Object -First 1

Copy-LabFileItem -Path "$here\..\Dashboards\*" -DestinationFolderPath 'C:\ProgramData\UniversalAutomation\Repository' -ComputerName $webServers
Copy-LabFileItem -Path "$here\..\JeaConfig\DscResources\*" -DestinationFolderPath 'C:\Program Files\WindowsPowerShell\Modules' -ComputerName $webServers
Copy-LabFileItem -Path "$here\..\JeaConfig" -DestinationFolderPath C:\Git -ComputerName $webServers

foreach ($webServer in $webServers) {

    $cert = Get-LabCertificate -SearchString "CN=$($webServer.FQDN)" -FindType FindBySubjectDistinguishedName -Location CERT_SYSTEM_STORE_LOCAL_MACHINE -Store My -ComputerName $webServer

    Invoke-LabCommand -ActivityName 'Setup Web Site' -ScriptBlock {

        $dashboardsFilePath = 'C:\ProgramData\UniversalAutomation\Repository\.universal\dashboards.ps1'
        Remove-Item -Path $dashboardsFilePath -Force -ErrorAction SilentlyContinue

        $files = dir -Path C:\ProgramData\UniversalAutomation\Repository\ -Filter *.ps1 -File

        foreach ($file in $files) {
            $fileName = $file.BaseName
            $entry = "New-PSUDashboard -Name '$fileName' -FilePath '$fileName.ps1' -BaseUrl '/$fileName' -Framework 'UniversalDashboard:Latest' -SessionTimeout 0 -AutoDeploy"

            $entry | Out-File -FilePath $dashboardsFilePath -Append
        }

        Set-ItemProperty -Path C:\ProgramData -Name Attributes -Value Normal

        Restart-Service -Name PowerShellUniversal

    } -ComputerName $webServer

}

Write-Host "2. - Creating Snapshot 'AfterPuSetup'" -ForegroundColor Magenta
#Checkpoint-LabVM -All -SnapshotName AfterPowerShellUniversalSetup
