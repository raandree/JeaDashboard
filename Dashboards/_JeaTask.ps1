function New-Progress {
    param(
        [string]$Text
    )

    New-UDElement -tag 'div' -Attributes @{ style = @{ padding = "20px"; textAlign = 'center' } } -Content {
        New-UDRow -Columns {
            New-UDColumn -Content {
                New-UDTypography -Text $Text -Variant h4
            }
        }
        New-UDRow -Columns {
            New-UDColumn -Content {
                New-UDProgress -Circular 
            }
        }
    }
}

function New-xTaskForm {
    param(
        [Parameter(Mandatory)]
        [string]$ParameterSetName
    )

    $parameters = Get-FunctionParameter -ScriptBlock ([scriptblock]::Create($task.ScriptBlock)) -ParameterSetName $ParameterSetName
    $parameterDefaultValues = Get-FunctionParameterWithDefaultValue -Scriptblock ([scriptblock]::Create($task.ScriptBlock))
    $parameterValidateSetValues = Get-FunctionParameterValidateSetValues -Scriptblock ([scriptblock]::Create($task.ScriptBlock))
    $session:parameterSetName = $ParameterSetName
    $session:currentTask = $task

    New-UDDynamic -Id "dyn_$($session:parameterSetName)" -Content {
        New-UDForm -Content {
            if ($Session:formProcessing) {
                New-Progress -Text 'Submitting form...'
            }
            else {
                $alParameters = New-Object System.Collections.ArrayList
                $alParameters.AddRange(@($parameters))
                foreach ($p in $alParameters) {

                    $newElement = if ($p.Value.Name -eq 'FilePath' -and $ParameterSetName -eq 'FileUpload') {
                        New-UDUpload -Text 'File Upload' -OnUpload {
                            $Data = $Body | ConvertFrom-Json
                            $bytes = [System.Convert]::FromBase64String($Data.Data)
                            mkdir -Path "C:\Temp\$($session:currentTask.Name)" -Force
                            [System.IO.File]::WriteAllBytes("C:\Temp\$($session:currentTask.Name)\$($Data.Name)", $bytes)
                        } -Id "udElement_FilePath"
                    }
                    elseif ($p.Value.ParameterType.Name -eq 'SwitchParameter') { 
                        New-UDCheckBox -Id "udElement_$($p.Key)" -Label $p.Key
                    }
                    elseif ($p.Value.ParameterType.Name -eq 'PSCredential') {
                        $udTextboxParam = @{
                            Id    = "udElement_$($p.Key)_username"
                            Label = "$($p.Key) ($($p.Value.parameterType.Name)) Username"
                            Type  = 'text'
                        }

                        New-UDTextbox @udTextboxParam

                        #-------------------------------------------------------------

                        $udTextboxParam = @{
                            Id    = "udElement_$($p.Key)_password"
                            Label = "$($p.Key) ($($p.Value.parameterType.Name)) Password"
                            Type  = 'password'
                        }

                        New-UDTextbox @udTextboxParam
                    }
                    else {
                        if ($parameterValidateSetValues.ContainsKey($p.Key)) {
                            $values = $parameterValidateSetValues[$p.Key]
                            
                            $options = foreach ($value in $values) {
                                "New-UDSelectOption -Name $value -Value $value;"
                            }
                            $options = [scriptblock]::Create($options)

                            $udSelectParam = @{
                                Id     = "udElement_$($p.Key)"
                                Label  = "$($p.Key) ($($p.Value.parameterType.Name))"
                                Option = $options
                            }
                            
                            New-UDSelect @udSelectParam
                        }
                        else {
                            $udTextboxParam = @{
                                Id        = "udElement_$($p.Key)"
                                Label     = "$($p.Key) ($($p.Value.parameterType.Name))"
                                Type      = 'text'
                                FullWidth = $true
                            }

                            if (($p.Value.Attributes | Where-Object { $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory) {
                                $udTextboxParam.Icon = New-UDIcon -Icon exclamation_triangle
                            }
    
                            if ($p.Value.parameterType.Name -eq 'SecureString') {
                                $udTextboxParam.Type = 'password'
                            }
    
                            
                            if ($parameterDefaultValues.ContainsKey($p.Key)) {
                                $udTextboxParam.Value = $parameterDefaultValues[$p.Key]
                            }

                            New-UDTextbox @udTextboxParam
                        }
                    }

                    $newElement | Add-Member -Name ParameterSetName -Value $ParameterSetName -Type NoteProperty -PassThru
                    $session:parameterElements.Add($newElement)
                }
            }
        
        } -OnSubmit {
            $Session:formProcessing = $true
            $currentParameterSetName = ($EventId -split '_')[1]
            Sync-UDElement -Id "dyn_$currentParameterSetName"

            $alParameterElements = New-Object System.Collections.ArrayList
            $alParameterElements.AddRange(@($session:parameterElements))

            $param = @{}
            
            foreach ($parameterElement in ($session:parameterElements | Where-Object ParameterSetName -eq $currentParameterSetName)) {

                $getUDElementRetryCount = 3
                $parameterElementId = $parameterElement.id
                $parameterElement = $null
                while (-not $parameterElement -and $getUDElementRetryCount -gt 0) {
                    $parameterElement = Get-UDElement -Id $parameterElementId
                    $getUDElementRetryCount--
                    Start-Sleep -Milliseconds 100
                }
                $parameterName = $parameterElement.id -replace 'udElement_', ''
                
                switch ($parameterElement) {                    
                    { $_.type -eq 'mu-textbox' } {
                        if ($_.Value) { 
                            if ($_.textType -eq 'password') {
                                $param.Add($parameterName, ($_.Value | ConvertTo-SecureString -AsPlainText -Force))
                            }
                            else {
                                $param.Add($parameterName, $_.Value)
                            }
                        }
                    }
                    { $_.type -eq 'mu-checkbox' } {
                        if ($_.checked) {
                            $param.Add($parameterName, $_.checked)
                        }
                    }
                    { $_.type -eq 'mu-upload' } {
                        if ($_.Value) {
                            $param.Add($parameterName, "C:\Temp\$($session:currentTask.Name)\$($_.Value.name)")
                        }
                    }
                    { $_.type -eq 'mu-select' } {
                        if ($_.Value) { 
                            $param.Add($parameterName, $_.Value)
                        }
                    }
                }
            }


            $param | Export-Clixml -Path c:\param.xml
        

            if (-not $session:adminSession -or $session:adminSession.ConfigurationName -ne $session:jeaEndpointName -or $session:adminSession.State -eq 'Closed') {
                $xmlFileName = $user -replace '\\', '_'
                $cred = Import-Clixml -Path "C:\UDCredentials\$xmlFileName.xml"
                $session:adminSession = New-PSSession -ComputerName $cache:jeaServer -ConfigurationName $session:jeaEndpointName -Credential $cred
            }

            Import-PSSession -Session $session:adminSession -AllowClobber | Out-Null

            $result = try {
                & $session:taskName @param -ErrorAction Stop
            }
            catch {
                $errorOccured = $true
                $_.Exception.Message
            }

            $Session:formProcessing = $false 
            Sync-UDElement -Id "dyn_$($session:parameterSetName)"

            if ($result) {
                if ($errorOccured) {
                    Show-UDModal -Content {
                        New-UDTypography -Text 'An error occured:' -Variant h5
                        New-UDTypography -Text $result -Variant h5
                    }
                }
                else {
                    Show-UDModal -Content {
                        New-UDTypography -Text 'The result is:' -Variant h5
                        New-UDTypography -Text $result -Variant h5
                    } -FullWidth
                }
            }
        } -Id "form_$ParameterSetName"
    }
}

Import-Module -Name Universal
#$user = 'contoso\install'
#$cred = New-Object pscredential($user, ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
$cache:jeaServer = 'jWeb1'
$jeaServer = 'jWeb1'

New-UDDashboard -Title "JEA Task" -Content {
    
    if (-not $TaskName -or -not $JeaEndpointName) {
        New-UDCard -Content {
            "Either the parameter 'TaskName' or 'JeaEndpointName' is not defined."
        }
        return
    }

    #$user = 'contoso\install'
    $session:jeaEndpointName = $JeaEndpointName
    $session:taskName = $TaskName
    $session:parameterElements = New-Object System.Collections.ArrayList

    try {
        $task = Get-JeaEndpointCapability -ComputerName $jeaServer -JeaEndpointName $JeaEndpointName -Username $user -ErrorAction Stop | Where-Object Name -eq $TaskName

        New-UDDynamic -Id headerInfo -Content {
            New-UDCard -Content {
                @"
    TaskName        = '$TaskName'
    JeaEndpointName = '$JeaEndpointName'
    UserName = '$user'
    Password = '$session:userPassword'
"@
    
                $udButtonParams = @{
                    Icon    = New-UDIcon -Icon trash
                    Text    = 'Remove JEA Session'
                    OnClick = {
                        $session:adminSession | Remove-PSSession
                    }
                }
                if (-not $session:adminSession -or $session:adminSession.State -eq 'Closed') {
                    $udButtonParams.Disabled = $true
                }
                New-UDButton @udButtonParams
            }

        } -AutoRefresh -AutoRefreshInterval 2

        $parameterSets = Get-FunctionParameterSet -ScriptBlock ([scriptblock]::Create($task.ScriptBlock))
        New-UDTabs -Tabs {
            foreach ($parameterSet in $parameterSets) {
                New-UDTab -Id "tab_$parameterSet" -Text $parameterSet -Content {                
                    Invoke-Expression "New-xTaskForm -ParameterSetName $parameterSet"
                }
            }
        }
    }
    catch {
        New-UDCard -Content {
            "Task '$TaskName' not found in Jea Endpoint '$JeaEndpointName'. Error message: '$($_.Exception.Message)'"
        }
    }
}
