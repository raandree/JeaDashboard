if (-not (Get-Lab)) {
    Write-Error 'Please importe the lab first' -ErrorAction Stop
}

$here = $PSScriptRoot
$webServers = Get-LabVM -Role WebServer

$vsCodeDownloadUrl = 'https://go.microsoft.com/fwlink/?Linkid=852157'
$vscodeInstaller = Get-LabInternetFile -Uri $vscodeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $vscodeInstaller.FullName -CommandLine /SILENT -ComputerName $webServers

$powershellUniversalInstallerDownloadUrl = 'https://imsreleases.blob.core.windows.net/universal/production/1.5.19/PowerShellUniversal.1.5.19.msi'
$powershellUniversalInstaller = Get-LabInternetFile -Uri $powershellUniversalInstallerDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $powershellUniversalInstaller.FullName -CommandLine /q -ComputerName $webServers

$powershellUniversalZipUrl = 'https://imsreleases.blob.core.windows.net/universal/production/1.5.14/Universal.win7-x64.1.5.19.zip'
$powershellUniversalZip = Get-LabInternetFile -Uri $powershellUniversalZipUrl -Path $labSources\SoftwarePackages -PassThru
Copy-LabFileItem -Path $powershellUniversalZip.FullName -ComputerName $webServers

$dotnetHostingUrl = 'https://download.visualstudio.microsoft.com/download/pr/854cbd11-4b96-4a44-9664-b95991c0c4f7/8ec4944a5bd770faba2f769e647b1e6e/dotnet-hosting-3.1.8-win.exe'
$dotnetHostingInstaller = Get-LabInternetFile -Uri $dotnetHostingUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $dotnetHostingInstaller.FullName -CommandLine /q -ComputerName $webServers

$gitDownloadUrl = 'https://github.com/git-for-windows/git/releases/download/v2.31.1.windows.1/Git-2.31.1-64-bit.exe'
$gitInstaller = Get-LabInternetFile -Uri $gitDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $gitInstaller.FullName -CommandLine /SILENT -ComputerName $webServers

$edgeDownloadUrl = 'http://dl.delivery.mp.microsoft.com/filestreamingservice/files/0af31313-0430-454d-908a-d55ce3df7b69/MicrosoftEdgeEnterpriseX64.msi'
$edgeInstaller = Get-LabInternetFile -Uri $edgeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $edgeInstaller.FullName -ComputerName $webServers

$chromeDownloadUrl = 'https://dl.google.com/tag/s/appguid%3D%7B8A69D345-D564-463C-AFF1-A69D9E530F96%7D%26iid%3D%7BC9D94BD4-6037-E88E-2D5A-F6B7D7F8F4CF%7D%26lang%3Den%26browser%3D5%26usagestats%3D0%26appname%3DGoogle%2520Chrome%26needsadmin%3Dprefers%26ap%3Dx64-stable-statsdef_1%26installdataindex%3Dempty/chrome/install/ChromeStandaloneSetup64.exe'
$chromeInstaller = Get-LabInternetFile -Uri $chromeDownloadUrl -Path $labSources\SoftwarePackages -PassThru
Install-LabSoftwarePackage -Path $chromeInstaller.FullName -ComputerName $webServers -CommandLine '/silent /install'

Remove-LabPSSession -All
Restart-LabVM -ComputerName $webServers -Wait

Copy-LabFileItem -Path $labSources\SoftwarePackages\VSCodeExtensions -ComputerName $webServers
Invoke-LabCommand -ActivityName 'Install VSCode Extensions' -ComputerName $webServers -ScriptBlock {
    dir -Path C:\VSCodeExtensions | ForEach-Object {
        code --install-extension $_.FullName 2>$null #suppressing errors
    }
} -NoDisplay

$requiredModules = @{
    'powershell-yaml'            = 'latest'
    datum                        = '0.39.0'
    InvokeBuild                  = 'latest'
    Pester                       = 'latest'
    PSDeploy                     = 'latest'
    PSScriptAnalyzer             = 'latest'
    PowerShellGet                = 'latest'
    PackageManagement            = 'latest'
    dbatools                     = 'latest'
    ISESteroids                  = 'latest'
    NTFSSecurity                 = 'latest'
    Universal                    = 'latest'
    JeaDsc                       = 'latest'
    xPSDesiredStateConfiguration = 'latest'
}

Invoke-LabCommand -ActivityName 'Get tested nuget.exe and register Azure DevOps Artifact Feed' -ScriptBlock {

    [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.SecurityProtocolType]::Tls12
    Install-PackageProvider -Name NuGet -Force
    mkdir -Path C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet -Force
    Invoke-WebRequest -Uri 'https://nuget.org/nuget.exe' -OutFile C:\ProgramData\Microsoft\Windows\PowerShell\PowerShellGet\nuget.exe -ErrorAction Stop

} -ComputerName $webServers

Remove-LabPSSession -All

mkdir -Path "$here\Temp" -ErrorAction SilentlyContinue | Out-Null
Write-Host "Saving $($requiredModules.Count) modules to '$here\Temp'"
foreach ($requiredModule in $requiredModules.GetEnumerator()) {
    $saveModuleParams = @{
        Name          = $requiredModule.Key
        Repository    = 'PSGallery'
        WarningAction = 'SilentlyContinue'
        Path          = "$here\Temp"
    }
    if ($requiredModule.Value -ne 'latest') {
        $saveModuleParams.Add('RequiredVersion', $requiredModule.Value)
    }
    if ($requiredModule.Value -like '*-*') {
  	      #if pre-release version
        $saveModuleParams.Add('AllowPrerelease', $true)
    }
    Write-Host "Saving module '$($requiredModule.Key)' with version '$($requiredModule.Value)'"
    Save-Module @saveModuleParams
}

Copy-LabFileItem -Path $here\Temp\* -ComputerName $webServers -DestinationFolderPath 'C:\Program Files\WindowsPowerShell\Modules'
Remove-Item -Path $here\Temp -Recurse -Force

Write-Host "1. - Creating Snapshot 'AfterSoftwareInstall'" -ForegroundColor Magenta
Checkpoint-LabVM -All -SnapshotName AfterSoftwareInstall
