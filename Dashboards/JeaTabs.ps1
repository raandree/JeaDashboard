function  Get-FunctionParameterWithDefaultValue {
    <#
    .SYNOPSIS
    This is a function that will find all of the default parameter names and values from a given function.
    
    .EXAMPLE
    PS>  Get-FunctionParameterWithDefaultValue -FunctionName Get-Something
    
    .PARAMETER FuntionName
    A mandatory string parameter representing the name of the function to find default parameters to.
    
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param
    (
        [Parameter(Mandatory, ParameterSetName = 'FunctionName')]
        [ValidateNotNullOrEmpty()]
        [string]$FunctionName,

        [Parameter(Mandatory, ParameterSetName = 'Scriptblock')]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Scriptblock
    )
    try {
        $ast = if ($FunctionName) {
            (Get-Command -Name $FunctionName).ScriptBlock.Ast
        }
        else {
            $Scriptblock.Ast
        }
        
        if (-not $ast) {
            return @{}
        }
        $select = @{ Name = 'Name'; Expression = { $_.Name.VariablePath.UserPath } },
        @{ Name = 'Value'; Expression = { $_.DefaultValue.Extent.Text -replace "`"|'" } }
        
        $ht = @{ }
        @($ast.FindAll( { $args[0] -is [System.Management.Automation.Language.ParameterAst] }, $true) | Where-Object { $_.DefaultValue } | Select-Object -Property $select).ForEach( {
                $ht[$_.Name] = $_.Value    
            })
        $ht
        
    }
    catch {
        Write-Error -Message $_.Exception.Message
    }
}

function New-Progress {
    param(
        [string]$Text
    )

    New-UDElement -tag 'div' -Attributes @{ style = @{ padding = "20px"; textAlign = 'center'} } -Content {
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

New-UDDashboard -Title "JeaTabs" -Content {
    $user = 'contoso\install'
    $cred = New-Object pscredential($user, ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
    $session:jeaServer = 'fiweb1'
    # JEA MODE
    #$session:psSession = New-PSSession -ComputerName $session:jeaServer -ConfigurationName JeaDiscovery
    #$session:endpoints = Invoke-Command -Session $session:psSession -ScriptBlock { Get-JeaEndpoint }
    # LOCAL DEV MODE
    $session:endpoints = @(
        [PSCustomObject]@{ Name = 'Local 1' },
        [PSCustomObject]@{ Name = 'Local 2' }
    )

    New-UDTypography -Text "Current process is $PID, current user is '$user'"
    
    $session:tasks = @{}
    New-UDTabs -Tabs {
        foreach ($jeaEndpoint in $session:endpoints) {
            New-UDTab -Text $jeaEndpoint.Name -Content {
                # JEA MODE
                #$session:tasks."$($jeaEndpoint.Name)" = Invoke-Command -Session $session:psSession -ScriptBlock {
                #    Get-JeaPSSessionCapability -ConfigurationName $args[0] -Username $args[1]
                #} -ArgumentList $jeaEndpoint.Name, $user #| Where-Object Name -like *-x*
                # LOCAL DEV MODE
                $session:tasks."$($jeaEndpoint.Name)" = Get-Command -Name Set-Content, Start-Sleep -CommandType Cmdlet | Where-Object { $_.Parameters } | Select-Object -First 550 -Property Name, Parameters, CommandType
                #Start-Sleep -Seconds 5 #Retrieving the capabilities from the JEA endpoints can take some seconds

                New-UDDynamic -Id "tab$($jeaEndpoint.Name)" -Content {
                    $columns = @(
                        New-UDTableColumn -Property Name -Title Name
                        New-UDTableColumn -Property Action -Render {
                            $item = $body | ConvertFrom-Json

                            $parameters = ($session:tasks."$($jeaEndpoint.Name)" | Where-Object Name -eq $item.Name).Parameters
                            $parameterDefaultValues =  Get-FunctionParameterWithDefaultValue -Scriptblock ([scriptblock]::Create($item.ScriptBlock))

                            New-UDButton -Id "btn$($item.Name)" -Text $item.Name -OnClick {

                                Show-UDModal -Content {
                                    New-UDDynamic -Id dynModal -Content {
                                        New-UDForm -Content {
                                            if ($Session:formProcessing) {
                                                New-Progress -Text 'Submitting form...'
                                            }
                                            else {
                                                $session:parameterElements = foreach ($p in $parameters.GetEnumerator()) {

                                                    if ($p.value.parameterType -eq 'System.Management.Automation.SwitchParameter') { 
                                                        New-UDCheckBox -Id $p.Key -Label $p.Key
                                                    }
                                                    else {
                                                        $udTextboxParam = @{
                                                            Id    = $p.Key
                                                            Label = "$($p.Key) ($($p.value.parameterType.Name))"
                                                            Type  = 'text'
                                                        }

                                                        if ($p.value.parameterType -eq 'System.Security.SecureString') {
                                                            $udTextboxParam.Type = 'password'
                                                        }

                                                        if ($parameterDefaultValues.ContainsKey($p.Key)) {
                                                            $udTextboxParam.Value = $parameterDefaultValues[$p.Key]
                                                        }
                                                    }

                                                    New-UDTextbox @udTextboxParam 
                                                }

                                                $session:parameterElements

                                                New-UDElement -Tag p -Attributes @{'class' = 'right-align' } -Content {
                                                    New-UDButton -Text "Close" -Icon (New-UDIcon -Icon stop) -OnClick { Hide-UDModal }
                                                }
                                            }
                                        
                                        } -OnSubmit {
                                            $Session:formProcessing = $true 
                                            Sync-UDElement -Id dynModal

                                            $param = @{}

                                            foreach ($parameterElement in $session:parameterElements) {
                                                $parameterElement = Get-UDElement -Id $parameterElement.id

                                                switch ($parameterElement) {

                                                    { $_.type -eq 'mu-textbox' } {
                                                        if ($_.value) { 
                                                            if ($_.textType -eq 'password') {
                                                                $param.Add($parameterElement.id, ($_.value | ConvertTo-SecureString -AsPlainText -Force))
                                                            }
                                                            else {
                                                                $param.Add($parameterElement.id, $_.value)
                                                            }
                                                        }
                                                    }
                                                    { $_.type -eq 'mu-checkbox' } {
                                                        if ($_.checked) {
                                                            $param.Add($parameterElement.id, $_.checked)
                                                        }
                                                    }
                                                }
                                            }

                                            $param | Export-Clixml -Path c:\param.xml
                                        
                                            $adminSession = New-PSSession -ComputerName $session:jeaServer -ConfigurationName $jeaEndpoint.Name

                                            Import-PSSession -Session $adminSession
                                        
                                            $result = try {
                                                & $item.Name @param -ErrorAction Stop
                                            }
                                            catch {
                                                $_.Exception.Message
                                            }

                                            $Session:formProcessing = $false 
                                            Sync-UDElement -Id dynModal

                                            #if ($result) {
                                            #    Show-UDModal -Content {
                                            #        New-UDTypography -Text 'An error occured' -Variant h5
                                            #        New-UDTypography -Text $result -Variant h5
                                            #    }
                                            #}
                                        }
                                    }
                                }
                            }
                        }
                    )
                    
                    New-UdTable -Data $session:tasks."$($jeaEndpoint.Name)" -Columns $columns -Id "tbl$($jeaEndpoint.Name)" -Sort -Filter -Search
                }
            }
        }
    } -RenderOnActive        
}
