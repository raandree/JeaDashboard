$labName = 'JeaUdLab1'

New-LabDefinition -Name $labName -DefaultVirtualizationEngine Azure

Set-PSFConfig -Module AutomatedLab -Name Timeout_WaitLabMachine_Online -Value 300

$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:ToolsPath'= "$labSources\Tools"
    'Add-LabMachineDefinition:OperatingSystem'= 'Windows Server 2019 Datacenter (Desktop Experience)'
    'Add-LabMachineDefinition:Memory'= 2GB
    'Add-LabMachineDefinition:DomainName'= 'contoso.com'
}

Add-LabVirtualNetworkDefinition -Name $labName

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

Add-LabMachineDefinition -Name jClient1 -OperatingSystem 'Windows 10 Pro'

Install-Lab

Install-LabSoftwarePackage -Path $labSources\SoftwarePackages\Notepad++.exe -CommandLine /S -ComputerName (Get-LabVM)

Install-LabWindowsFeature -ComputerName (Get-LabVM -Role WebServer) -FeatureName RSAT-AD-Tools

foreach ($webServer in (Get-LabVM -Role WebServer)) {
    Request-LabCertificate -Subject "CN=$($webServer.FQDN)" -TemplateName WebServer -ComputerName $webServer
}

Write-Host "1. - Creating Snapshot 'AfterInstall'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterInstall

Show-LabDeploymentSummary -Detailed
