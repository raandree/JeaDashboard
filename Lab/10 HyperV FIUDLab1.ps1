$labName = 'JeaUdLab1'

New-LabDefinition -Name $labName -DefaultVirtualizationEngine HyperV

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem'= 'Windows Server 2019 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'= 2GB
    'Add-LabMachineDefinition:DomainName'= 'contoso.com'
}

Add-LabIsoImageDefinition -Name SQLServer2019 -Path $labSources\ISOs\en_sql_server_2019_standard_x64_dvd_814b57aa.iso

Add-LabVirtualNetworkDefinition -Name $labName #-AddressSpace 192.168.22.0/24

Add-LabDomainDefinition -Name contoso.com -AdminUser Install -AdminPassword Somepass1
Set-LabInstallationCredential -Username Install -Password Somepass1

Add-LabMachineDefinition -Name jDC1 -Roles RootDC

Add-LabMachineDefinition -Name jCA1 -Roles CaRoot

$disk = Add-LabDiskDefinition -Name jSQL1_D -DiskSizeInGb 100 -Label Data -DriveLetter D -PassThru
Add-LabMachineDefinition -Name jSQL1 -Roles SQLServer2019 -DiskName $disk
$disk = Add-LabDiskDefinition -Name jSQL2_D -DiskSizeInGb 100 -Label Data -DriveLetter D -PassThru
Add-LabMachineDefinition -Name jSQL2 -Roles SQLServer2019 -DiskName $disk

Add-LabMachineDefinition -Name jWeb1 -Roles WebServer
Add-LabMachineDefinition -Name jWeb2 -Roles WebServer

$disks = @()
$disks = Add-LabDiskDefinition -Name jFile1_D -DiskSizeInGb 100 -Label Data1 -DriveLetter D -PassThru
$disks = Add-LabDiskDefinition -Name jFile1_E -DiskSizeInGb 100 -Label Data2 -DriveLetter E -PassThru
Add-LabMachineDefinition -Name jFile1 -Roles FileServer -DiskName $disks

Add-LabMachineDefinition -Name jClient1 #-OperatingSystem 'Windows 10 Pro'

Install-Lab

Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\Notepad++.exe -CommandLine /S -ComputerName (Get-LabVM)

Install-LabWindowsFeature -ComputerName (Get-LabVM -Role WebServer) -FeatureName RSAT-AD-Tools

Invoke-LabCommand -ActivityName 'Disable Windows Update Service and DisableRealtimeMonitoring' -ComputerName (Get-LabVM) -ScriptBlock {
    Stop-Service -Name wuauserv
    Set-Service -Name wuauserv -StartupType Disabled
    Set-MpPreference -DisableRealtimeMonitoring $true
}

foreach ($webServer in (Get-LabVM -Role WebServer)) {
    Request-LabCertificate -Subject "CN=$($webServer.FQDN)" -TemplateName WebServer -ComputerName $webServer
}

Get-LabVM -Role WebServer | Get-VM | Add-VMNetworkAdapter -SwitchName 'Default Switch'

Write-Host "1. - Creating Snapshot 'AfterInstall'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterInstall

Show-LabDeploymentSummary -Detailed
