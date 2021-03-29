#Region '.\Enum\Ensure.ps1' 0
enum Ensure
{
    Present
    Absent
}
#EndRegion '.\Enum\Ensure.ps1' 6
#Region '.\Classes\1.Reason.ps1' 0
class Reason
{
    [DscProperty()]
    [string] $Phrase

    [DscProperty()]
    [string] $Code
}
#EndRegion '.\Classes\1.Reason.ps1' 9
#Region '.\Classes\1.RoleCapabilitiesUtility.ps1' 0
$modulePath = Join-Path -Path $PSScriptRoot -ChildPath Modules

Import-Module -Name (Join-Path -Path $modulePath -ChildPath DscResource.Common)
Import-Module -Name (Join-Path -Path $modulePath -ChildPath (Join-Path -Path JeaDsc.Common -ChildPath JeaDsc.Common.psm1))

$script:localizedDataRole = Get-LocalizedData -DefaultUICulture en-US -FileName 'JeaRoleCapabilities.strings.psd1'

class RoleCapabilitiesUtility
{
    hidden [boolean] ValidatePath()
    {
        $fileObject = [System.IO.FileInfo]::new($this.Path)
        Write-Verbose -Message ($script:localizedDataRole.ValidatingPath -f $fileObject.Fullname)
        Write-Verbose -Message ($script:localizedDataRole.CheckPsrcExtension -f $fileObject.Fullname)
        if ($fileObject.Extension -ne '.psrc')
        {
            Write-Verbose -Message ($script:localizedDataRole.NotPsrcExtension -f $fileObject.Fullname)
            return $false
        }

        Write-Verbose -Message ($script:localizedDataRole.CheckParentFolder -f $fileObject.Fullname)
        if ($fileObject.Directory.Name -ne 'RoleCapabilities')
        {
            Write-Verbose -Message ($script:localizedDataRole.NotRoleCapabilitiesParent -f $fileObject.Fullname)
            return $false
        }


        Write-Verbose -Message $script:localizedDataRole.ValidePsrcPath
        return $true
    }
}
#EndRegion '.\Classes\1.RoleCapabilitiesUtility.ps1' 33
#Region '.\Classes\1.SessionConfigurationUtility.ps1' 0
$script:localizedDataSession = Get-LocalizedData -DefaultUICulture en-US -FileName 'JeaSessionConfiguration.strings.psd1'

class SessionConfigurationUtility
{
    hidden [bool] TestParameters()
    {
        if (-not $this.SessionType)
        {
            $this.SessionType = 'RestrictedRemoteServer'
        }

        if ($this.RunAsVirtualAccountGroups -and $this.GroupManagedServiceAccount)
        {
            throw $script:localizedDataSession.ConflictRunAsVirtualAccountGroupsAndGroupManagedServiceAccount
        }

        if ($this.GroupManagedServiceAccount -and $this.RunAsVirtualAccount)
        {
            throw $script:localizedDataSession.ConflictRunAsVirtualAccountAndGroupManagedServiceAccount
        }

        if (-not $this.GroupManagedServiceAccount)
        {
            $this.RunAsVirtualAccount = $true
            Write-Warning -Message $script:localizedDataSession.NotDefinedGMSaAndVirtualAccount
        }

        return $true
    }

    ## Get a PS Session Configuration based on its name
    hidden [object] GetPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name 'WinRM'
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $psSessionConfiguration = Get-PSSessionConfiguration -Name $Name -ErrorAction SilentlyContinue
            $Global:VerbosePreference = $verbosePreferenceBackup

            if ($psSessionConfiguration)
            {
                return $psSessionConfiguration
            }
            else
            {
                return $null
            }
        }
        else
        {
            Write-Verbose -Message $script:localizedDataSession.WinRMNotRunningGetPsSession
            return $null
        }
    }

    ## Unregister a PS Session Configuration based on its name
    hidden [void] UnregisterPSSessionConfiguration($Name)
    {
        $winRMService = Get-Service -Name WinRM
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            # Temporary disabling Verbose as xxx-PSSessionConfiguration methods verbose messages are useless for DSC debugging
            $verbosePreferenceBackup = $Global:VerbosePreference
            $Global:VerbosePreference = 'SilentlyContinue'
            $null = Unregister-PSSessionConfiguration -Name $Name -Force -WarningAction SilentlyContinue
            $Global:VerbosePreference = $verbosePreferenceBackup
        }
        else
        {
            throw ($script:localizedDataSession.WinRMNotRunningUnRegisterPsSession -f $Name)
        }
    }

    ## Register a PS Session Configuration and handle a WinRM hanging situation
    hidden [Void] RegisterPSSessionConfiguration($Name, $Path, $Timeout)
    {
        $winRMService = Get-Service -Name WinRM
        if ($winRMService -and $winRMService.Status -eq 'Running')
        {
            Write-Verbose -Message ($script:localizedDataSession.RegisterPSSessionConfiguration -f $Name,$Path,$Timeout)
            # Register-PSSessionConfiguration has been hanging because the WinRM service is stuck in Stopping state
            # therefore we need to run Register-PSSessionConfiguration within a job to allow us to handle a hanging WinRM service

            # Save the list of services sharing the same process as WinRM in case we have to restart them
            $processId = Get-CimInstance -ClassName Win32_Service -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
            $serviceList = Get-CimInstance -ClassName Win32_Service -Filter "ProcessId=$processId" | Select-Object -ExpandProperty Name
            foreach ($service in $serviceList.Clone())
            {
                $dependentServiceList = Get-Service -Name $service | ForEach-Object { $_.DependentServices }
                foreach ($dependentService in $dependentServiceList)
                {
                    if ($dependentService.Status -eq 'Running' -and $serviceList -notcontains $dependentService.Name)
                    {
                        $serviceList += $dependentService.Name
                    }
                }
            }

            $registerString = if ($Path)
            {
                @"
if (Get-PSSessionConfiguration -Name '$Name' -ErrorAction SilentlyContinue)
{
    Unregister-PSSessionConfiguration -Name '$Name' -NoServiceRestart -ErrorAction Stop -WarningAction SilentlyContinue
}
`$null = Register-PSSessionConfiguration -Name '$Name' -Path '$Path' -NoServiceRestart -ErrorAction Stop -WarningAction SilentlyContinue
"@
            }
            else
            {
                @"
if (Get-PSSessionConfiguration -Name '$Name' -ErrorAction SilentlyContinue)
{
    Unregister-PSSessionConfiguration -Name '$Name' -NoServiceRestart -ErrorAction Stop -WarningAction SilentlyContinue
}
`$null = Register-PSSessionConfiguration -Name '$Name' -NoServiceRestart -ErrorAction Stop -WarningAction SilentlyContinue
"@
            }

            $registerScriptBlock = [scriptblock]::Create($registerString)

            if ($Timeout -gt 0)
            {
                Start-Job -ScriptBlock $registerScriptBlock | Receive-Job -Wait -AutoRemoveJob

                # If WinRM is still Stopping after the job has completed / exceeded $Timeout, force kill the underlying WinRM process
                $winRMService = Get-Service -Name WinRM
                if ($winRMService -and $winRMService.Status -eq 'StopPending')
                {
                    $processId = Get-CimInstance -ClassName Win32_Service -Filter "Name LIKE 'WinRM'" | Select-Object -ExpandProperty ProcessId
                    Write-Verbose -Message ($script:localizedDataSession.ForcingProcessToStop -f $processId)
                    $failureList = @()
                    try
                    {
                        # Kill the process hosting WinRM service
                        Stop-Process -Id $processId -Force
                        Start-Sleep -Seconds 5
                        Write-Verbose -Message ($script:localizedDataSession.RegisterPSSessionConfiguration -f $($serviceList -join ', '))
                        # Then restart all services previously identified
                        foreach ($service in $serviceList)
                        {
                            try
                            {
                                Start-Service -Name $service
                            }
                            catch
                            {
                                $failureList += $script:localizedDataSession.FailureListStartService -f $service
                            }
                        }
                    }
                    catch
                    {
                        $failureList += $script:localizedDataSession.FailureListKillWinRMProcess
                    }

                    if ($failureList)
                    {
                        Write-Verbose -Message ($script:localizedDataSession.FailureListKillWinRMProcess -f $($failureList -join ', '))
                    }
                }
                elseif ($winRMService -and $winRMService.Status -eq 'Stopped')
                {
                    Write-Verbose -Message $script:localizedDataSession.RestartWinRM
                    Start-Service -Name WinRM

                }
            }
            else
            {
                Invoke-Command -ScriptBlock $registerScriptBlock
            }
        }
        else
        {
            throw ($script:localizedDataSession.WinRMNotRunningRegisterPsSession -f $Name)
        }
    }

}
#EndRegion '.\Classes\1.SessionConfigurationUtility.ps1' 184
#Region '.\Classes\JeaRoleCapabilities.ps1' 0
[DscResource()]
class JeaRoleCapabilities:RoleCapabilitiesUtility
{

    [DscProperty()]
    [Ensure]$Ensure = [Ensure]::Present

    # Where to store the file.
    [DscProperty(Key)]
    [string]$Path

    # Specifies the modules that are automatically imported into sessions that use the role capability file.
    # By default, all of the commands in listed modules are visible. When used with VisibleCmdlets or VisibleFunctions,
    # the commands visible from the specified modules can be restricted. Hashtable with keys ModuleName, ModuleVersion and GUID.
    [DscProperty()]
    [string[]]$ModulesToImport

    # Limits the aliases in the session to those aliases specified in the value of this parameter,
    # plus any aliases that you define in the AliasDefinition parameter. Wildcard characters are supported.
    # By default, all aliases that are defined by the Windows PowerShell engine and all aliases that modules export are
    # visible in the session.
    [DscProperty()]
    [string[]]$VisibleAliases

    # Limits the cmdlets in the session to those specified in the value of this parameter.
    # Wildcard characters and Module Qualified Names are supported.
    [DscProperty()]
    [string[]]$VisibleCmdlets

    #  Limits the functions in the session to those specified in the value of this parameter,
    # plus any functions that you define in the FunctionDefinitions parameter. Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleFunctions

    # Limits the external binaries, scripts and commands that can be executed in the session to those specified in
    # the value of this parameter. Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleExternalCommands

    # Limits the Windows PowerShell providers in the session to those specified in the value of this parameter.
    # Wildcard characters are supported.
    [DscProperty()]
    [string[]]$VisibleProviders

    # Specifies scripts to add to sessions that use the role capability file.
    [DscProperty()]
    [string[]]$ScriptsToProcess

    # Adds the specified aliases to sessions that use the role capability file.
    # Hashtable with keys Name, Value, Description and Options.
    [DscProperty()]
    [string[]]$AliasDefinitions

    # Adds the specified functions to sessions that expose the role capability.
    # Hashtable with keys Name, Scriptblock and Options.
    [DscProperty()]
    [string[]]$FunctionDefinitions

    # Specifies variables to add to sessions that use the role capability file.
    # Hashtable with keys Name, Value, Options.
    [DscProperty()]
    [string[]]$VariableDefinitions

    # Specifies the environment variables for sessions that expose this role capability file.
    # Hashtable of environment variables.
    [DscProperty()]
    [string[]]$EnvironmentVariables

    # Specifies type files (.ps1xml) to add to sessions that use the role capability file.
    # The value of this parameter must be a full or absolute path of the type file names.
    [DscProperty()]
    [string[]]$TypesToProcess

    # Specifies the formatting files (.ps1xml) that run in sessions that use the role capability file.
    # The value of this parameter must be a full or absolute path of the formatting files.
    [DscProperty()]
    [string[]]$FormatsToProcess

    # Specifies the assemblies to load into the sessions that use the role capability file.
    [DscProperty()]
    [string]$Description

    # Description of the role
    [DscProperty()]
    [string[]]$AssembliesToLoad

    # Reasons of why the resource isn't in desired state
    [DscProperty(NotConfigurable)]
    [Reason[]]$Reasons

    [JeaRoleCapabilities] Get()
    {
        $currentState = [JeaRoleCapabilities]::new()
        $currentState.Path = $this.Path
        if (Test-Path -Path $this.Path)
        {
            $currentStateFile = Import-PowerShellDataFile -Path $this.Path

            'Copyright', 'GUID', 'Author', 'CompanyName' | Foreach-Object {
                $currentStateFile.Remove($_)
            }

            foreach ($property in $currentStateFile.Keys)
            {
                $propertyType = ($this | Get-Member -Name $property -MemberType Property).Definition.Split(' ')[0]
                $currentState.$property = foreach ($propertyValue in $currentStateFile[$property])
                {
                    if ($propertyValue -is [hashtable] -and $propertyType -ne 'hashtable')
                    {
                        if ($propertyValue.ScriptBlock -is [scriptblock])
                        {
                            $code = $propertyValue.ScriptBlock.Ast.Extent.Text
                            $code -match '(?<=\{)(?<Code>((.|\s)*))(?=\})' | Out-Null
                            $propertyValue.ScriptBlock = [scriptblock]::Create($Matches.Code)
                        }

                        ConvertTo-Expression -Object $propertyValue -NewLine "`n"
                    }
                    elseif ($propertyValue -is [hashtable] -and $propertyType -eq 'hashtable')
                    {
                        $propertyValue
                    }
                    else
                    {
                        $propertyValue
                    }
                }
            }
            $currentState.Ensure = [Ensure]::Present

            # Compare current and desired state to add reasons
            $valuesToCheck = $this.psobject.Properties.Name.Where({$_ -notin 'Path','Reasons'})

            $compareState = Compare-DscParameterState `
                -CurrentValues ($currentState | Convert-ObjectToHashtable) `
                -DesiredValues ($this | Convert-ObjectToHashtable) `
                -ValuesToCheck $valuesToCheck | Where-Object {$_.InDesiredState -eq $false }

            $currentState.Reasons = switch ($compareState)
            {
                {$_.Property -eq 'Ensure'}{
                    [Reason]@{
                        Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                        Phrase = $script:localizedDataRole.ReasonEnsure -f $this.Path
                    }
                    continue
                }
                {$_.Property -eq 'Description'}{
                    [Reason]@{
                        Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                        Phrase = $script:localizedDataRole.ReasonDescription -f $this.Description
                    }
                    continue
                }
                default {
                    [Reason]@{
                        Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                        Phrase = $script:localizedDataRole."Reason$($_.Property)"
                    }
                }
            }
        }
        else
        {
            $currentState.Ensure = [Ensure]::Absent
            if ($this.Ensure -eq [Ensure]::Present)
            {
                $currentState.Reasons = [Reason]@{
                    Code = '{0}:{0}:Ensure' -f $this.GetType()
                    Phrase = $script:localizedDataRole.ReasonFileNotFound -f $this.Path
                }
            }
        }

        return $currentState
    }

    [void] Set()
    {
        $invalidConfiguration = $false

        if ($this.Ensure -eq [Ensure]::Present)
        {
            $desiredState = Convert-ObjectToHashtable -Object $this

            foreach ($parameter in $desiredState.Keys.Where( { $desiredState[$_] -match '@{' }))
            {
                $desiredState[$parameter] = Convert-StringToObject -InputString $desiredState[$parameter]
            }

            $desiredState = Sync-Parameter -Command (Get-Command -Name New-PSRoleCapabilityFile) -Parameters $desiredState

            if ($desiredState.ContainsKey('FunctionDefinitions'))
            {
                foreach ($functionDefinitionName in $desiredState['FunctionDefinitions'].Name)
                {
                    if ($functionDefinitionName -notin $desiredState['VisibleFunctions'])
                    {
                        Write-Verbose ($script:localizedDataRole.FunctionDefinedNotVisible -f $functionDefinitionName)
                        Write-Error ($script:localizedDataRole.FunctionDefinedNotVisible -f $functionDefinitionName)
                        $invalidConfiguration = $true
                    }
                }
            }

            if (-not $invalidConfiguration)
            {
                $parentPath = Split-Path -Path $desiredState.Path -Parent
                mkdir -Path $parentPath -Force

                $fPath = $desiredState.Path
                $desiredState.Remove('Path')
                $content = $desiredState | ConvertTo-Expression -NewLine "`n"
                $content | Set-Content -Path $fPath -Force
            }
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and (Test-Path -Path $this.Path))
        {
            Remove-Item -Path $this.Path -Confirm:$false -Force
        }

    }

    [bool] Test()
    {
        if (-not ($this.ValidatePath()))
        {
            Write-Error -Message $script:localizedDataRole.InvalidPath
            return $false
        }
        if ($this.Ensure -eq [Ensure]::Present -and -not (Test-Path -Path $this.Path))
        {
            return $false
        }
        elseif ($this.Ensure -eq [Ensure]::Present -and (Test-Path -Path $this.Path))
        {

            $currentState = Convert-ObjectToHashtable -Object $this.Get()
            $desiredState = Convert-ObjectToHashtable -Object $this

            $cmdlet = Get-Command -Name New-PSRoleCapabilityFile
            $desiredState = Sync-Parameter -Command $cmdlet -Parameters $desiredState
            $currentState = Sync-Parameter -Command $cmdlet -Parameters $currentState
            $propertiesAsObject = $cmdlet.Parameters.Keys |
                Where-Object { $_ -in $desiredState.Keys } |
                    Where-Object { $cmdlet.Parameters.$_.ParameterType.FullName -in 'System.Collections.IDictionary', 'System.Collections.Hashtable', 'System.Collections.IDictionary[]', 'System.Object[]' }
            foreach ($key in $propertiesAsObject)
            {
                if ($cmdlet.Parameters.$key.ParameterType.FullName -in 'System.Collections.Hashtable', 'System.Collections.IDictionary', 'System.Collections.IDictionary[]', 'System.Object[]')
                {
                    $desiredState."$($key)" = $desiredState."$($key)" | Convert-StringToObject
                    $currentState."$($key)" = $currentState."$($key)" | Convert-StringToObject
                }
            }

            $compare = Test-DscParameterState -CurrentValues $currentState -DesiredValues $desiredState -SortArrayValues -TurnOffTypeChecking -ReverseCheck

            return $compare
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and (Test-Path -Path $this.Path))
        {
            return $false
        }
        elseif ($this.Ensure -eq [Ensure]::Absent -and -not (Test-Path -Path $this.Path))
        {
            return $true
        }

        return $false
    }
}
#EndRegion '.\Classes\JeaRoleCapabilities.ps1' 272
#Region '.\Classes\JeaSessionConfiguration.ps1' 0
[DscResource()]
class JeaSessionConfiguration:SessionConfigurationUtility
{
    ## The optional state that ensures the endpoint is present or absent. The defualt value is [Ensure]::Present.
    [DscProperty()]
    [Ensure] $Ensure = [Ensure]::Present

    ## The mandatory endpoint name. Use 'Microsoft.PowerShell' by default.
    [DscProperty(Key)]
    [string] $Name = 'Microsoft.PowerShell'

    ## The role definition map to be used for the endpoint. This
    ## should be a string that represents the Hashtable used for the RoleDefinitions
    ## property in New-PSSessionConfigurationFile, such as:
    ## RoleDefinitions = '@{ Everyone = @{ RoleCapabilities = "BaseJeaCapabilities" } }'
    [Dscproperty()]
    [string] $RoleDefinitions

    ## run the endpoint under a Virtual Account
    [DscProperty()]
    [bool] $RunAsVirtualAccount

    ## The optional groups to be used when the endpoint is configured to
    ## run as a Virtual Account
    [DscProperty()]
    [string[]] $RunAsVirtualAccountGroups

    ## The optional Group Managed Service Account (GMSA) to use for this
    ## endpoint. If configured, will disable the default behaviour of
    ## running as a Virtual Account
    [DscProperty()]
    [string] $GroupManagedServiceAccount

    ## The optional directory for transcripts to be saved to
    [DscProperty()]
    [string] $TranscriptDirectory

    ## The optional startup script for the endpoint
    [DscProperty()]
    [string[]] $ScriptsToProcess

    ## The optional session type for the endpoint
    [DscProperty()]
    [string] $SessionType

    ## The optional switch to enable mounting of a restricted user drive
    [Dscproperty()]
    [bool] $MountUserDrive

    ## The optional size of the user drive. The default is 50MB.
    [Dscproperty()]
    [long] $UserDriveMaximumSize

    ## The optional expression declaring which domain groups (for example,
    ## two-factor authenticated users) connected users must be members of. This
    ## should be a string that represents the Hashtable used for the RequiredGroups
    ## property in New-PSSessionConfigurationFile, such as:
    ## RequiredGroups = '@{ And = "RequiredGroup1", @{ Or = "OptionalGroup1", "OptionalGroup2" } }'
    [Dscproperty()]
    [string[]] $RequiredGroups

    ## The optional modules to import when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## ModulesToImport = "'MyCustomModule', @{ ModuleName = 'MyCustomModule'; ModuleVersion = '1.0.0.0'; GUID = '4d30d5f0-cb16-4898-812d-f20a6c596bdf' }"
    [Dscproperty()]
    [string[]] $ModulesToImport

    ## The optional aliases to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleAliases

    ## The optional cmdlets to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleCmdlets = "'Invoke-Cmdlet1', @{ Name = 'Invoke-Cmdlet2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleCmdlets

    ## The optional functions to make visible when applied to a session
    ## This should be a string that represents a string, a Hashtable, or array of strings and/or Hashtables
    ## VisibleFunctions = "'Invoke-Function1', @{ Name = 'Invoke-Function2'; Parameters = @{ Name = 'Parameter1'; ValidateSet = 'Item1', 'Item2' }, @{ Name = 'Parameter2'; ValidatePattern = 'L*' } }"
    [Dscproperty()]
    [string[]] $VisibleFunctions

    ## The optional external commands (scripts and applications) to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleExternalCommands

    ## The optional providers to make visible when applied to a session
    [Dscproperty()]
    [string[]] $VisibleProviders

    ## The optional aliases to be defined when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## AliasDefinitions = "@{ Name = 'Alias1'; Value = 'Invoke-Alias1'}, @{ Name = 'Alias2'; Value = 'Invoke-Alias2'}"
    [Dscproperty()]
    [string[]] $AliasDefinitions

    ## The optional functions to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## FunctionDefinitions = "@{ Name = 'MyFunction'; ScriptBlock = { param($MyInput) $MyInput } }"
    [Dscproperty()]
    [string[]] $FunctionDefinitions

    ## The optional variables to define when applied to a session
    ## This should be a string that represents a Hashtable or array of Hashtable
    ## VariableDefinitions = "@{ Name = 'Variable1'; Value = { 'Dynamic' + 'InitialValue' } }, @{ Name = 'Variable2'; Value = 'StaticInitialValue' }"
    [Dscproperty()]
    [string] $VariableDefinitions

    ## The optional environment variables to define when applied to a session
    ## This should be a string that represents a Hashtable
    ## EnvironmentVariables = "@{ Variable1 = 'Value1'; Variable2 = 'Value2' }"
    [Dscproperty()]
    [string] $EnvironmentVariables

    ## The optional type files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $TypesToProcess

    ## The optional format files (.ps1xml) to load when applied to a session
    [Dscproperty()]
    [string[]] $FormatsToProcess

    ## The optional assemblies to load when applied to a session
    [Dscproperty()]
    [string[]] $AssembliesToLoad

    ## The optional number of seconds to wait for registering the endpoint to complete.
    ## 0 for no timeout
    [Dscproperty(NotConfigurable)]
    [int] $HungRegistrationTimeout = 10

    # Contains the not compliant properties detected in Get() method.
    [DscProperty(NotConfigurable)]
    [Reason[]]$Reasons
    
    $properties
    
    JeaSessionConfiguration () {
        $this.properties = [JeaSessionConfiguration].GetProperties() |
        Where-Object { $_.CustomAttributes.Where(
            {$_.AttributeType.Name -eq 'DscPropertyAttribute' -and $_.NamedArguments.MemberName -ne 'NotConfigurable'})}
    }

    [void] Set()
    {
        $ErrorActionPreference = 'Stop'

        $this.TestParameters()

        $psscPath = Join-Path ([IO.Path]::GetTempPath()) ([IO.Path]::GetRandomFileName() + '.pssc')
        Write-Verbose -Message ($script:localizedDataSession.StoringPSSessionConfigurationFile -f $psscPath)
        $desiredState = Convert-ObjectToHashtable -Object $this
        $desiredState.Add('Path', $psscPath)

        if ($this.Ensure -eq [Ensure]::Present)
        {
            foreach ($parameter in $desiredState.Keys.Where( { $desiredState[$_] -match '@{' }))
            {
                $desiredState[$parameter] = Convert-StringToObject -InputString $desiredState[$parameter]
            }
        }

        ## Register the endpoint
        try
        {
            ## If we are replacing Microsoft.PowerShell, create a 'break the glass' endpoint
            if ($this.Name -eq 'Microsoft.PowerShell')
            {
                $breakTheGlassName = 'Microsoft.PowerShell.Restricted'
                if (-not ($this.GetPSSessionConfiguration($breakTheGlassName)))
                {
                    $this.RegisterPSSessionConfiguration($breakTheGlassName, $null, $this.HungRegistrationTimeout)
                }
            }

            ## Remove the previous one, if any.
            if ($this.GetPSSessionConfiguration($this.Name))
            {
                $this.UnregisterPSSessionConfiguration($this.Name)
            }

            if ($this.Ensure -eq [Ensure]::Present)
            {
                ## Create the configuration file
                #New-PSSessionConfigurationFile @configurationFileArguments
                $desiredState = Sync-Parameter -Command (Get-Command -Name New-PSSessionConfigurationFile) -Parameters $desiredState
                New-PSSessionConfigurationFile @desiredState

                ## Register the configuration file
                $this.RegisterPSSessionConfiguration($this.Name, $psscPath, $this.HungRegistrationTimeout)
            }
        }
        catch
        {
            Write-Error -ErrorRecord $_
        }
        finally
        {
            if (Test-Path $psscPath)
            {
                Remove-Item $psscPath
            }
        }
    }

    # Tests if the resource is in the desired state.
    [bool] Test()
    {
        $this.TestParameters()

        $currentState = Convert-ObjectToHashtable -Object $this.Get()
        $desiredState = Convert-ObjectToHashtable -Object $this

        # short-circuit if the resource is not present and is not supposed to be present
        if ($currentState.Ensure -ne $desiredState.Ensure)
        {
            Write-Verbose -Message ($script:localizedDataSession.FailureListKillWinRMProcess -f $currentState.Name,$desiredState.Ensure,$currentState.Ensure )
            return $false
        }
        if ($this.Ensure -eq [Ensure]::Absent)
        {
            if ($currentState.Ensure -eq [Ensure]::Absent)
            {
                return $true
            }

            Write-Verbose ($script:localizedDataSession.PSSessionConfigurationNamePresent -f $currentState.Name)
            return $false
        }

        
        $currentState.Clone().Keys | Where-Object { $_ -notin $this.properties.Name } | ForEach-Object { $currentState.Remove($_) }
        $desiredState.Clone().Keys | Where-Object { $_ -notin $this.properties.Name } | ForEach-Object { $desiredState.Remove($_) }
        $keys = $this.properties.Name
        
        foreach ($key in $keys)
        {
            if ($key.PropertyType.FullName -in 'System.Collections.Hashtable', 'System.Collections.IDictionary', 'System.Collections.IDictionary[]', 'System.Object[]')
            {
                $desiredState."$($key)" = $desiredState."$($key)" | Convert-StringToObject
                $currentState."$($key)" = $currentState."$($key)" | Convert-StringToObject
            }
        }
        #Wait-Debugger
        $compare = Test-DscParameterState -CurrentValues $currentState -DesiredValues $desiredState -TurnOffTypeChecking -SortArrayValues -ReverseCheck

        return $compare
    }

    # Gets the resource's current state.
    [JeaSessionConfiguration] Get()
    {
        $currentState = New-Object JeaSessionConfiguration
        $CurrentState.Name = $this.Name
        $CurrentState.Ensure = [Ensure]::Present

        $sessionConfiguration = $this.GetPSSessionConfiguration($this.Name)
        if (-not $sessionConfiguration -or -not $sessionConfiguration.ConfigFilePath)
        {
            $currentState.Ensure = [Ensure]::Absent
            if ($this.Ensure -eq [Ensure]::Present)
            {
                $currentState.Reasons = [Reason]@{
                    Code = '{0}:{0}:Ensure' -f $this.GetType()
                    Phrase = $script:localizedDataSession.ReasonEpSessionNotFound -f $this.Name
                }
            }

            return $currentState
        }

        $configFile = Import-PowerShellDataFile $sessionConfiguration.ConfigFilePath

        'Copyright', 'GUID', 'Author', 'CompanyName', 'SchemaVersion' | Foreach-Object {
            $configFile.Remove($_)
        }

        foreach ($property in $configFile.Keys)
        {
            $propertyType = ($this | Get-Member -Name $property -MemberType Property).Definition.Split(' ')[0]
            $currentState.$property = foreach ($propertyValue in $configFile[$property])
            {
                if ($propertyValue -is [hashtable] -and $propertyType -ne 'hashtable')
                {
                    if ($propertyValue.ScriptBlock -is [scriptblock])
                    {
                        $code = $propertyValue.ScriptBlock.Ast.Extent.Text
                        $code -match '(?<=\{\{)(?<Code>((.|\s)*))(?=\}\})' | Out-Null
                        $propertyValue.ScriptBlock = [scriptblock]::Create($Matches.Code)
                    }

                    ConvertTo-Expression -Object $propertyValue -NewLine "`n"
                }
                elseif ($propertyValue -is [hashtable] -and $propertyType -eq 'hashtable')
                {
                    $propertyValue
                }
                else
                {
                    $propertyValue
                }
            }
        }

        # Compare current and desired state to add reasons
        $valuesToCheck = $this.psobject.Properties.Name.Where({$_ -notin 'Name','Reasons'})

        $compareState = Compare-DscParameterState `
            -CurrentValues ($currentState | Convert-ObjectToHashtable) `
            -DesiredValues ($this | Convert-ObjectToHashtable) `
            -ValuesToCheck $valuesToCheck | Where-Object {$_.InDesiredState -eq $false }

        $currentState.Reasons = switch ($compareState)
        {
            {$_.Property -eq 'Ensure'}{
                [Reason]@{
                    Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                    Phrase = $script:localizedDataSession.ReasonEnsure -f $this.Path
                }
                continue
            }
            {$_.Property -eq 'Description'}{
                [Reason]@{
                    Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                    Phrase = $script:localizedDataSession.ReasonDescription -f $this.Description
                }
                continue
            }
            default {
                [Reason]@{
                    Code = '{0}:{0}:{1}' -f $this.GetType(),$_.Property
                    Phrase = $script:localizedDataSession."Reason$($_.Property)"
                }
            }
        }

        return $currentState
    }
}
#EndRegion '.\Classes\JeaSessionConfiguration.ps1' 335
