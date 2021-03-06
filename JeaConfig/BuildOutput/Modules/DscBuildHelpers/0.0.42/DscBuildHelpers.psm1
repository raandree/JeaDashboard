function Assert-DscModuleResourceIsValid
{
    [cmdletbinding()]
    param (
        [parameter(ValueFromPipeline)]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo]
        $DscResources
    )

    begin
    {
        Write-Verbose "Testing for valid resources."
        $FailedDscResources = @()
    }

    process
    {
        foreach($DscResource in $DscResources) {
            $FailedDscResources += Get-FailedDscResource -DscResource $DscResource
        }
    }

    end
    {
        if ($FailedDscResources.Count -gt 0)
        {
            Write-Verbose "Found failed resources."
            foreach ($resource in $FailedDscResources)
            {

                Write-Warning "`t`tFailed Resource - $($resource.Name) ($($resource.Version))"
            }

            throw "One or more resources is invalid."
        }
    }
}

#author Iain Brighton, from here: https://gist.github.com/iainbrighton/9d3dd03630225ee44126769c5d9c50a9
# Not sure that takes all possibilities into account:
# i.e. when using Import-DscResource -Name ResourceName #even if it's bad practice
# Also need to return PSModuleInfo, instead of @{ModuleName='<version>'}
# Then probably worth promoting to public
function Get-RequiredModulesFromMOF {
    <#
    .SYNOPSIS
        Scans a Desired State Configuration .mof file and returns the declared/
        required modules.
#>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [System.String] $Path
    )
    process {

        $modules = @{ }
        $moduleName = $null
        $moduleVersion = $null

        Get-Content -Path $Path -Encoding Unicode | ForEach-Object {

            $line = $_;
            if ($line -match '^\s?Instance of') {
                ## We have a new instance so write the existing one
                if (($null -ne $moduleName) -and ($null -ne $moduleVersion)) {

                    $modules[$moduleName] = $moduleVersion;
                    $moduleName = $null
                    $moduleVersion = $null
                    Write-Verbose "Module Instance found: $moduleName $moduleVersion"
                }
            }
            elseif ($line -match '(?<=^\s?ModuleName\s?=\s?")\S+(?=";)') {

                ## Ignore the default PSDesiredStateConfiguration module
                if ($Matches[0] -notmatch 'PSDesiredStateConfiguration') {
                    $moduleName = $Matches[0]
                    Write-Verbose "Found Module Name $modulename"
                }
                else {
                    Write-Verbose 'Excluding PSDesiredStateConfiguration module'
                }
            }
            elseif ($line -match '(?<=^\s?ModuleVersion\s?=\s?")\S+(?=";)') {
                $moduleVersion = $Matches[0] -as [System.Version]
                Write-Verbose "Module version = $moduleVersion"
            }
        }

        Write-Output -InputObject $modules
    } #end process
} #end function Get-RequiredModulesFromMOF

function Resolve-ModuleMetadataFile {
    [cmdletbinding(DefaultParameterSetName = 'ByDirectoryInfo')]
    param (
        [parameter(
            ParameterSetName = 'ByPath',
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [string]
        $Path,
        [parameter(
            ParameterSetName = 'ByDirectoryInfo',
            Mandatory,
            ValueFromPipeline
        )]
        [System.IO.DirectoryInfo]
        $InputObject

    )

    process {
        $MetadataFileFound = $true
        $MetadataFilePath = ''
        Write-Verbose "Using Parameter set - $($PSCmdlet.ParameterSetName)"
        switch ($PSCmdlet.ParameterSetName) {
            'ByPath' {
                Write-Verbose "Testing Path - $path"
                if (Test-Path $Path) {
                    Write-Verbose "`tFound $path."
                    $item = (Get-Item $Path)
                    if ($item.psiscontainer) {
                        Write-Verbose "`t`tIt is a folder."
                        $ModuleName = Split-Path $Path -Leaf
                        $MetadataFilePath = Join-Path $Path "$ModuleName.psd1"
                        $MetadataFileFound = Test-Path $MetadataFilePath
                    }
                    else {
                        if ($item.Extension -like '.psd1') {
                            Write-Verbose "`t`tIt is a module metadata file."
                            $MetadataFilePath = $item.FullName
                            $MetadataFileFound = $true
                        }
                        else {
                            $ModulePath = Split-Path $Path
                            Write-Verbose "`t`tSearching for module metadata folder in $ModulePath"
                            $ModuleName = Split-Path $ModulePath -Leaf
                            Write-Verbose "`t`tModule name is $ModuleName."
                            $MetadataFilePath = Join-Path $ModulePath "$ModuleName.psd1"
                            Write-Verbose "`t`tChecking for $MetadataFilePath."
                            $MetadataFileFound = Test-Path $MetadataFilePath
                        }
                    }
                }
                else {
                    $MetadataFileFound = $false
                }
            }
            'ByDirectoryInfo' {
                $ModuleName = $InputObject.Name
                $MetadataFilePath = Join-Path $InputObject.FullName "$ModuleName.psd1"
                $MetadataFileFound = Test-Path $MetadataFilePath
            }

        }

        if ($MetadataFileFound -and (-not [string]::IsNullOrEmpty($MetadataFilePath))) {
            Write-Verbose "Found a module metadata file at $MetadataFilePath."
            Convert-path $MetadataFilePath
        }
        else {
            Write-Error "Failed to find a module metadata file at $MetadataFilePath."
        }
    }
}

function Clear-CachedDscResource {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param()

    if ($pscmdlet.ShouldProcess($env:computername)) {
        Write-Verbose 'Stopping any existing WMI processes to clear cached resources.'

        ### find the process that is hosting the DSC engine
        $dscProcessID = Get-WmiObject msft_providers |
          Where-Object {$_.provider -like 'dsccore'} |
            Select-Object -ExpandProperty HostProcessIdentifier

        ### Stop the process
        if ($dscProcessID -and $pscmdlet.ShouldProcess('DSC Process')) {
            Get-Process -Id $dscProcessID | Stop-Process
        }
        else {
            Write-Verbose 'Skipping killing the DSC Process'
        }

        Write-Verbose 'Clearing out any tmp WMI classes from tested resources.'
        Get-DscResourceWmiClass -class tmp* | remove-DscResourceWmiClass
    }
}

function Compress-DscResourceModule {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]
        $DscBuildOutputModules,

        [Parameter(Mandatory, ValueFromPipeline)]
        [AllowNull()]
        [psmoduleinfo[]]
        $Modules
    )

    begin {
        if (-not (Test-Path -Path $DscBuildOutputModules)) {
            mkdir -Path $DscBuildOutputModules -Force
        }
    }
    Process {
        Foreach ($module in $Modules) {
            if ($PSCmdlet.ShouldProcess("Compress $Module $($Module.Version) from $(Split-Path -parent $Module.Path) to $DscBuildOutputModules")) {
                Write-Verbose "Publishing Module $(Split-Path -parent $Module.Path) to $DscBuildOutputModules"
                $destinationPath = Join-Path -Path $DscBuildOutputModules -ChildPath "$($module.Name)_$($module.Version).zip"
                Compress-Archive -Path "$($module.ModuleBase)\*" -DestinationPath $destinationPath

                (Get-FileHash -Path $destinationPath).Hash | Set-Content -Path "$destinationPath.checksum" -NoNewline
            }
        }
    }
}

function Find-ModuleToPublish {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $DscBuildSourceResources,

        [ValidateNotNullOrEmpty()]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]
        $ExcludedModules = $null,

        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        $DscBuildOutputModules
    )

    $ModulesAvailable = Get-ModuleFromFolder -ModuleFolder $DscBuildSourceResources -ExcludedModules $ExcludedModules

    Foreach ($Module in $ModulesAvailable) {
        $publishTargetZip =  [System.IO.Path]::Combine(
                                            $DscBuildOutputModules,
                                            "$($module.Name)_$($module.version).zip"
                                            )
        $publishTargetZipCheckSum =  [System.IO.Path]::Combine(
                                            $DscBuildOutputModules,
                                            "$($module.Name)_$($module.version).zip.checksum"
                                            )

        $zipExists      = Test-Path -Path $publishTargetZip
        $checksumExists = Test-Path -Path $publishTargetZipCheckSum

        if (-not ($zipExists -and $checksumExists))
        {
            Write-Debug "ZipExists = $zipExists; CheckSum exists = $checksumExists"
            Write-Verbose -Message "Adding $($Module.Name)_$($Module.Version) to the Modules To Publish"
            Write-Output -inputObject $Module
        }
        else {
            Write-Verbose -Message "$($Module.Name) does not need to be published"
        }
    }
}

function Get-DscFailedResource {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline
        )]
        [Microsoft.PowerShell.DesiredStateConfiguration.DscResourceInfo[]]
        $DscResource
    )

    Process {
        foreach ($resource in $DscResource) {
            if ($resource.Path) {
                $resourceNameOrPath = Split-Path $resource.Path -Parent
            }
            else {
                $resourceNameOrPath = $resource.Name
            }

            if (-not (Test-xDscResource -Name $resourceNameOrPath)) {
                Write-Warning "`tResources $($_.name) is invalid."
                $resource
            }
            else {
                Write-Verbose ('DSC Resource Name {0} {1} is Valid' -f $resource.Name, $resource.Version)
            }
        }
    }
}

function Get-DscResourceFromModuleInFolder {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        $ModuleFolder,

        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSModuleInfo[]]
        $Modules

    )
    Begin {
        $oldPSModulePath = $Env:PSmodulePath
        $Env:PSmodulePath = $ModuleFolder
        Write-Verbose "Retrieving all resources for $ModuleFolder."
        $AllDscResource = Get-DscResource
        $Env:PSmodulePath = $oldPSModulePath
    }
    Process {

        Write-Verbose "Filtering the $($AllDscResource.Count) resources."
        Write-Debug ('Resources {0}' -f ($AllDscResource | Format-Table -AutoSize | out-string))
        $AllDscResource.Where{
            $isResourceInModulesToPublish = Foreach ($Module in $Modules) {
                if ( $null -eq $_.Module ) {
                    Write-Debug "Excluding resource $($_.Name) without Module"
                    Return $false
                }
                elseif ( !(compare-object $_.Module $Module -Property ModuleType, Version, Name) ) {
                    Write-Debug "Resource $($_.Name) matches one of the supplied Modules."
                    Return $true
                }
            }
            if (!$isResourceInModulesToPublish) {
                Write-Debug "`tExcluding $($_.Name) $($_.Version)"
                Return $false
            }
            else {
                Write-Debug "`tIncluding $($_.Name) $($_.Version)"
                Return $true
            }
        }
    }
}

function Get-DscResourceWmiClass {
    <#
        .Synopsis
            Retrieves WMI classes from the DSC namespace.
        .Description
            Retrieves WMI classes from the DSC namespace.
        .Example
            Get-DscResourceWmiClass -Class tmp*
        .Example
            Get-DscResourceWmiClass -Class 'MSFT_UserResource'
    #>
    param (
        #The WMI Class name search for.  Supports wildcards.
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('Name')]
        [string]
        $Class
    )
    begin {
        $DscNamespace = "root/Microsoft/Windows/DesiredStateConfiguration"
    }
    process {
        Get-wmiobject -Namespace $DscNamespace -list @psboundparameters
    }
}

function Global:Get-DscSplattedResource {
    [CmdletBinding()]
    Param(
        [String]
        $ResourceName,

        [String]
        $ExecutionName,

        [hashtable]
        $Properties,

        [switch]
        $NoInvoke
    )
    # Remove Case Sensitivity of ordered Dictionary or Hashtables
    $Properties = @{}+$Properties

    $stringBuilder = [System.Text.StringBuilder]::new()
    $null = $stringBuilder.AppendLine("Param([hashtable]`$Parameters)")
    $null = $stringBuilder.AppendLine()
    $null = $stringBuilder.AppendLine(' if ($Parameters) {')
    $null = $stringBuilder.AppendLine(' $($Parameters=@{}+$Parameters)')
    $null = $stringBuilder.AppendLine(' }')
    $null = $stringBuilder.AppendLine(" $ResourceName $ExecutionName { ")
    foreach($PropertyName in $Properties.keys) {
        $null = $stringBuilder.AppendLine("$PropertyName = `$(`$Parameters['$PropertyName'])")
    }
    $null = $stringBuilder.AppendLine("}")
    Write-Debug ("Generated Resource Block = {0}" -f $stringBuilder.ToString())

    if($NoInvoke.IsPresent) {
        [scriptblock]::Create($stringBuilder.ToString())
    }
    else {
        if ($Properties) {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke($Properties)
        } else {
            [scriptblock]::Create($stringBuilder.ToString()).Invoke()
        }
    }
}
Set-Alias -Name x -Value Get-DscSplattedResource -scope Global
#Export-ModuleMember -Alias x

function Get-ModuleFromFolder {
    [CmdletBinding()]
    [OutputType('System.Management.Automation.PSModuleInfo[]')]
    param (
        [Parameter(
            Mandatory,
            ValueFromPipeline,
            ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [io.DirectoryInfo[]]
        $ModuleFolder,

        [AllowNull()]
        [Microsoft.PowerShell.Commands.ModuleSpecification[]]
        $ExcludedModules = $null
    )

    Begin {
        $AllModulesInFolder = @()
    }

    Process {
        foreach ($Folder in $ModuleFolder) {
            Write-Debug -Message "Replacing Module path with $Folder"
            $OldPSModulePath = $env:PSModulePath
            $env:PSModulePath = $Folder
            Write-Debug -Message "Discovering modules from folder"
            $AllModulesInFolder += Get-Module -Refresh -ListAvailable
            Write-Debug -Message "Reverting PSModulePath"
            $env:PSModulePath = $OldPSModulePath
        }
    }

    End {

        $AllModulesInFolder | Where-Object {
            $source = $_
            Write-Debug -message "Checking if Module $source is Excluded."
            $isExcluded = foreach ($ExcludedModule in $ExcludedModules) {
                Write-Debug "`t Excluded Module $ExcludedModule"
                if ( ($ExcludedModule.Name -and $ExcludedModule.Name -eq $source.Name) -and
                    (
                        ( !$ExcludedModule.Version -and
                            !$ExcludedModule.Guid -and
                            !$ExcludedModule.MaximumVersion -and
                            !$ExcludedModule.RequiredVersion ) -or
                        ($ExcludedModule.Version -and $ExcludedModule.Version -eq $source.Version) -or
                        ($ExcludedModule.Guid -and $ExcludedModule.Guid -ne $source.Guid) -or
                        ($ExcludedModule.MaximumVersion -and $ExcludedModule.MaximumVersion -ge $source.Version) -or
                        ($ExcludedModule.RequiredVersion -and $ExcludedModule.RequiredVersion -eq $source.Version)
                    )
                ) {
                    Write-Debug ('Skipping {0} {1} {2}' -f $source.Name, $source.Version, $source.Guid)
                    return $false
                }
            }
            if (!$isExcluded) {
                return $true
            }
        }
    }

}

function Publish-DscConfiguration {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(
            Mandatory
        )]
        [string]
        $DscBuildOutputConfigurations,

        [string]
        $PullServerWebConfig = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"
    )
    Process {
        Write-Verbose "Publishing Configuration MOFs from $DscBuildOutputConfigurations"


        Get-ChildItem -Path (join-path -Path $DscBuildOutputConfigurations -ChildPath '*.mof') |
            foreach-object {
                if ( !(Test-Path -Path $PullServerWebConfig) ) {
                    Write-Warning "The Pull Server configg $PullServerWebConfig cannot be found."
                    Write-Warning "`t Skipping Publishing Configuration MOFs"
                }
                elseif ($pscmdlet.shouldprocess($_.BaseName)) {
                    Write-Verbose -Message "Publishing $($_.name)"
                    Publish-MOFToPullServer -FullName $_.FullName -PullServerWebConfig $PullServerWebConfig
                }
            }
    }
}

function Publish-DscResourceModule {
    [cmdletbinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(
            Mandatory
        )]
        [string]
        $DscBuildOutputModules,

        [io.FileInfo]
        $PullServerWebConfig = "$env:SystemDrive\inetpub\wwwroot\PSDSCPullServer\web.config"
    )
    Begin
    {
        if ( !(Test-Path $PullServerWebConfig) ) {
            if ($PSBoundParameters['ErrorAction'] -eq 'SilentlyContinue') {
                Write-Warning -Message "Could not find the Web.config of the pull Server at $PullServerWebConfig"
            }
            else {
                Throw "Could not find the Web.config of the pull Server at $PullServerWebConfig"
            }
            return
        }
        else {
            $webConfigXml = [xml](Get-Content -Raw -Path $PullServerWebConfig)
            $configXElement = $webConfigXml.SelectNodes("//appSettings/add[@key = 'ConfigurationPath']")
            $OutputFolderPath =  $configXElement.Value
        }
    }

    Process {
        if ($OutputFolderPath) {
            Write-Verbose 'Moving Processed Resource Modules from '
            Write-Verbose "`t$DscBuildOutputModules to"
            Write-Verbose "`t$OutputFolderPath"

            if ($pscmdlet.shouldprocess("copy $DscBuildOutputModules to $OutputFolderPath")) {
                Get-ChildItem -Path $DscBuildOutputModules -Include @('*.zip','*.checksum') |
                    Copy-Item -Destination $OutputFolderPath -Force
            }
        }
    }

}

function Push-DscConfiguration {
    [CmdletBinding(
        SupportsShouldProcess,
        ConfirmImpact='High'
    )]
    [Alias()]
    [OutputType([void])]
    Param (
        # Param1 help description
        [Parameter(Mandatory,
                    Position=0
                   ,ValueFromPipelineByPropertyName
        )]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        # Param2 help description
        [Parameter()]
        [Alias('MOF','Path')]
        [System.IO.FileInfo]
        $ConfigurationDocument,

        # Param3 help description
        [Parameter()]
        [psmoduleinfo[]]
        $WithModule,

        [Parameter(
            ,Position = 1
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias('DscBuildOutputModules')]
        $StagingFolderPath = "$Env:TMP\DSC\BuildOutput\modules\",

        [Parameter(
            ,Position = 3
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        $RemoteStagingPath = '$Env:TMP\DSC\modules\',

        [Parameter(
            ,Position = 4
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [switch]
        $Force
    )


    process {
        if ($pscmdlet.ShouldProcess($Session.ComputerName, "Applying MOF $ConfigurationDocument")) {
            if ($WithModule) {
                Push-DscModuleToNode -Module $WithModule -StagingFolderPath $StagingFolderPath -RemoteStagingPath $RemoteStagingPath -Session $Session
            }

            Write-Verbose "Removing previously pushed configuration documents"
            $ResolvedRemoteStagingPath = Invoke-Command -Session $Session -ScriptBlock {
                $ResolvedStagingPath = $ExecutionContext.InvokeCommand.ExpandString($Using:RemoteStagingPath)
                $null = Get-item "$ResolvedStagingPath\*.mof" | Remove-Item -force -ErrorAction SilentlyContinue
                if (!(Test-Path $ResolvedStagingPath)) {
                    mkdir -Force $ResolvedStagingPath -ErrorAction Stop
                }
                Write-Output $ResolvedStagingPath
            } -ErrorAction Stop

            $RemoteConfigDocumentPath = [io.path]::Combine(
                $ResolvedRemoteStagingPath,
                'localhost.mof'
            )

            Copy-Item -ToSession $Session -Path $ConfigurationDocument -Destination $RemoteConfigDocumentPath -Force -ErrorAction Stop

            Write-Verbose "Attempting to apply $RemoteConfigDocumentPath on $($session.ComputerName)"
            Invoke-Command -Session $Session -scriptblock {
                Start-DscConfiguration -Wait -Force -Path $Using:ResolvedRemoteStagingPath -Verbose -ErrorAction Stop
            }
        }
    }
}

<#
    .SYNOPSIS
    Injects Modules via PS Session.

    .DESCRIPTION
    Injects the missing modules on a remote node via a PSSession.
    The module list is checked again the available modules from the remote computer,
    Any missing version is then zipped up and sent over the PS session,
    before being extracted in the root PSModulePath folder of the remote node.

    .PARAMETER Module
    A list of Modules required on the remote node. Those missing will be packaged based
    on their Path.

    .PARAMETER StagingFolderPath
    Staging folder where the modules are being zipped up locally before being sent accross.

    .PARAMETER Session
    Session to use to gather the missing modules and to copy the modules to.

    .PARAMETER RemoteStagingPath
    Path on the remote Node where the modules will be copied before extraction.

    .PARAMETER Force
    Force all modules to be re-zipped, re-sent, and re-extracted to the target node.

    .EXAMPLE
    Push-DscModuleToNode -Module (Get-ModuleFromFolder C:\src\SampleKitchen\modules) -Session $RemoteSession -StagingFolderPath "C:\BuildOutput"

#>
function Push-DscModuleToNode {
    [CmdletBinding()]
    [OutputType([void])]
    Param (
        # Param1 help description
        [Parameter(
             Mandatory
            ,Position = 0
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias("ModuleInfo")]
        [System.Management.Automation.PSModuleInfo[]]
        $Module,

        [Parameter(
            ,Position = 1
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [Alias('DscBuildOutputModules')]
        $StagingFolderPath = "$Env:TMP\DSC\BuildOutput\modules\",


        [Parameter(
            ,Mandatory
            ,Position = 2
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [System.Management.Automation.Runspaces.PSSession]
        $Session,

        [Parameter(
            ,Position = 3
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        $RemoteStagingPath = '$Env:TMP\DSC\modules\',

        [Parameter(
            ,Position = 4
            ,ValueFromPipelineByPropertyName
            ,ValueFromRemainingArguments
        )]
        [switch]
        $Force
    )

    process
    {
        # Find the modules already available remotely
        if (!$Force) {
            $RemoteModuleAvailable = Invoke-command -Session $Session -ScriptBlock {Get-Module -ListAvailable}
        }
        $ResolvedRemoteStagingPath = Invoke-command -Session $Session -ScriptBlock {
            $ResolvedStagingPath = $ExecutionContext.InvokeCommand.ExpandString($Using:RemoteStagingPath)
            if (!(Test-Path $ResolvedStagingPath)) {
                mkdir -Force $ResolvedStagingPath
            }
            $ResolvedStagingPath
        }

        # Find the modules missing on remote node
        $MissingModules = $Module.Where{
            $MatchingModule = foreach ($remoteModule in $RemoteModuleAvailable) {
                if(
                    $remoteModule.Name -eq $_.Name -and
                    $remoteModule.Version -eq $_.Version -and
                    $remoteModule.guid -eq $_.guid
                ) {
                    Write-Verbose "Module match: $($remoteModule.Name)"
                    $remoteModule
                }
            }
            if(!$MatchingModule) {
                Write-Verbose "Module not found: $($_.Name)"
                $_
            }
        }
        Write-Verbose "The Missing modules are $($MissingModules.Name -join ', ')"

        # Find the missing modules from the staging folder
        #  and publish it there
        Write-Verbose "looking for missing zip modules in $($StagingFolderPath)"
        $MissingModules.where{ !(Test-Path "$StagingFolderPath\$($_.Name)_$($_.version).zip")} |
            Compress-DscResourceModule -DscBuildOutputModules $StagingFolderPath

        # Copy missing modules to remote node if not present already
        foreach ($module in $MissingModules) {
            $FileName = "$($StagingFolderPath)/$($module.Name)_$($module.Version).zip"
            if ($Force -or !(invoke-command -Session $Session -ScriptBlock {
                    Param($FileName)
                    Test-Path $FileName
                } -ArgumentList $FileName))
            {
                Write-Verbose "Copying $fileName* to $ResolvedRemoteStagingPath"
                Invoke-Command -Session $Session -ScriptBlock {
                    param($PathToZips)
                    if (!(Test-Path $PathToZips)) {
                        mkdir $PathToZips -Force
                    }
                } -ArgumentList $ResolvedRemoteStagingPath

                Copy-Item -ToSession $Session `
                    -Path "$($StagingFolderPath)/$($module.Name)_$($module.Version)*" `
                    -Destination $ResolvedRemoteStagingPath `
                    -Force | Out-Null
            }
            else {
                Write-Verbose "The File is already present remotely."
            }
        }

        # Extract missing modules on remote node to PSModulePath
        Write-Verbose "Expanding $ResolvedRemoteStagingPath/*.zip to $Env:CommonProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)"
        Invoke-Command -Session $Session -ScriptBlock {
            Param($MissingModules,$PathToZips)
            foreach ($module in $MissingModules) {
                $fileName = "$($module.Name)_$($module.version).zip"
                Write-Verbose "Expanding $PathToZips/$fileName to $Env:CommonProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)"
                Expand-Archive -Path "$PathToZips/$fileName" -DestinationPath "$Env:ProgramW6432\WindowsPowerShell\Modules\$($Module.Name)\$($module.version)" -Force
            }
        } -ArgumentList $MissingModules,$ResolvedRemoteStagingPath
    }
}

<#
    .Synopsis
        Removes a WMI class from the DSC namespace.
    .Description
        Removes a WMI class from the DSC namespace.
    .Example
        Get-DscResourceWmiClass -Class tmp* | Remove-DscResourceWmiClass
    .Example
        Remove-DscResourceWmiClass -Class 'tmpD460'
#>
function Remove-DscResourceWmiClass {
    param (
        #The WMI Class name to remove.  Supports wildcards.
        [parameter(ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('Name')]
        [string]
        $ResourceType
    )
    begin {
        $DscNamespace = "root/Microsoft/Windows/DesiredStateConfiguration"
    }
    process {
        #Have to use WMI here because I can't find how to delete a WMI instance via the CIM cmdlets.
        (Get-wmiobject -Namespace $DscNamespace -list -Class $ResourceType).psbase.delete()
    }
}

function Test-DscResourceFromModuleInFolderIsValid {
    [cmdletbinding()]
    param (
        [Parameter(
            Mandatory
        )]
        [ValidateNotNullOrEmpty()]
        [System.io.DirectoryInfo]
        $ModuleFolder,

        [Parameter(
            Mandatory,
            ValueFromPipelineByPropertyName,
            ValueFromPipeline
        )]
        [System.Management.Automation.PSModuleInfo[]]
        [AllowNull()]
        $Modules
    )

    Process {
        Foreach ($module in $Modules) {
            $Resources = Get-DscResourceFromModuleInFolder -ModuleFolder $ModuleFolder `
                                                          -Modules $module

            $Resources.Where{$_.ImplementedAs -eq 'PowerShell'} | Assert-DscModuleResourceIsValid
        }
    }
}


