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

function New-xPage {
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [scriptblock]$OnLoad,

        [Parameter(Mandatory)]
        [scriptblock]$Finished,

        [ValidateSet('Session', 'Cache')]
        [string]$Store = 'Session'
    )

    $onLoadText = $OnLoad.ToString()
    if (-not ($onLoadText -match 'Sync-UDElement -Id (?<Id>\w+)')) {
        Write-Error "No ID for 'New-UDDynamic' found."
        return
    }
    else {
        Write-Host "ID for 'New-UDDynamic' is $($Matches.Id)"
        $id = $Matches.Id
    }
    $isloaded = "`${$($Store):$($id)_loaded}"
    New-UDPage -Name $Name -Content {
        New-UDTypography -Text "Endpoint name: $jeaEndpointName | PID: $PID | Username = $user"

        [string]$passwordDynId = New-Guid
        New-UDDynamic -Id $passwordDynId -Content {
            Wait-Debugger
            if (-not $session:userPassword) {
                $header = New-UDCardHeader -Title 'Please provide your password'
                $body = New-UDCardBody -Content {
                    New-UDForm -Content {
                        New-UDTextbox -Id 'txtPassword' -Label Password
                    } -OnSubmit {
                        $session:userPassword = $EventData.txtTextfield
                        Wait-Debugger
                        Sync-UDElement -Id $passwordDynId
                    }
                }

                New-UDCard -Body $body -Header $header
            }
        } -AutoRefresh 1
        
        New-UDDynamic -Id $id -Content {
            Invoke-Ternary -Decider ([scriptblock]::Create($isloaded)) -IfTrue {
                New-xTable -JeaEndpointName $jeaEndpointName
            } -IfFalse {
                New-xWait -JeaEndpointName $jeaEndpointName
            }
        }
    }
}

function New-xTable {
    param(
        [Parameter(Mandatory)]
        [string]$JeaEndpointName
    )

    $columns = @(
        New-UDTableColumn -Property Name -Title Name
        New-UDTableColumn -Property Action -Render {
            #$item = $body | ConvertFrom-Json

            $parameters = ($session:tasks.$JeaEndpointName | Where-Object Name -eq $item.Name).Parameters
            $parameterDefaultValues =  Get-FunctionParameterWithDefaultValue -Scriptblock ([scriptblock]::Create($item.ScriptBlock))

            New-UDButton -Id "btn$JeaEndpointName_$($item.Name)" -Text $item.Name -OnClick {
                #$item = $body | ConvertFrom-Json
                Invoke-UDRedirect -Url "http://localhost:5000/_JeaTask/Home?JeaEndpointName=$jeaEndpointName&TaskName=$($item.Name)" -OpenInNewWindow
            }
        }
    )

    $data = if ((Get-Item -Path Session:"tasks.$JeaEndpointName").GetType().Name -eq 'PSCustomObject') {
        [pscustomobject]@{
            Name        = (Get-Item -Path Session:"tasks.$JeaEndpointName").Name
            Parameters  = (Get-Item -Path Session:"tasks.$JeaEndpointName").Parameters
            CommandType = (Get-Item -Path Session:"tasks.$JeaEndpointName").CommandType
            ScriptBlock = (Get-Item -Path Session:"tasks.$JeaEndpointName").ScriptBlock
        }
    }
    else {
        (Get-Item -Path Session:"tasks.$JeaEndpointName").ForEach( {
                [pscustomobject]@{
                    Name        = $_.Name
                    Parameters  = $_.Parameters
                    CommandType = $_.CommandType
                    ScriptBlock = $_.ScriptBlock
                }
            })
    }
    New-UdTable -Data $data -Columns $columns -Id "tbl$($jeaEndpoint.Name)" -Sort -Filter -Search
}

function New-xWait {
    param(
        [Parameter(Mandatory)]
        [string]$JeaEndpointName
    )

    New-Progress -Text "Loading JEA endpoint '$JeaEndpointName'"
    New-UDElement -Tag div -Endpoint {
        Set-Item -Path Session:"Dyn_$($JeaEndpointName)_loaded" -Value $true
        #Set-Item -Path Session:"SessionData$($jeaEndpointName)" = Get-Random

        $tasks = Get-JeaEndpointCapability -JeaEndpointName $jeaEndpointName -Username $user -ComputerName $cache:jeaServer
        Set-Item -Path Session:"tasks.$JeaEndpointName" -Value $tasks
        Sync-UDElement -Id "Dyn_$JeaEndpointName"
    }
}

Import-Module -Name Universal
Import-Module -Name JeaDiscovery

#$user = 'contoso\install'
#$cred = New-Object pscredential($user, ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
$cache:jeaServer = 'jWeb1'

$cache:jeaEndpoints = Get-JeaEndpoint -ComputerName $cache:jeaServer

#$session:tasks."$($jeaEndpoint.Name)" = Invoke-Command -Session $session:psSession -ScriptBlock {
#    Get-JeaPSSessionCapability -ConfigurationName $args[0] -Username $args[1]
#} -ArgumentList $jeaEndpoint.Name, $user #| Where-Object Name -like *-x*
# LOCAL DEV MODE
#$session:tasks."$($jeaEndpoint.Name)" = Get-Command -Name Set-Content, Start-Sleep -CommandType Cmdlet | Where-Object { $_.Parameters } | Select-Object -First 550 -Property Name, Parameters, CommandType
#Start-Sleep -Seconds 5 #Retrieving the capabilities from the JEA endpoints can take some seconds

$pages = foreach ($jeaEndpoint in $Cache:jeaEndpoints) {
    $jeaEndpointName = $jeaEndpoint.Name
    $onLoad = @"
#New-Progress -Text 'Loading Session data...'
#New-UDElement -Tag 'div' -Endpoint {
#    `$Session:Dyn_$($jeaEndpoint.Name)_loaded = `$true
#    `$Session:SessionData$jeaEndpointName = Get-Random
#    Sync-UDElement -Id Dyn_$($jeaEndpoint.Name)
#}
"@

    $finished = @"
#New-UDCard -Title "Page $jeaEndpointName" -Id "PageCard"
#`$data = `$Session:SessionData$jeaEndpointName
#New-UDTypography -Text "Some random text '`$data'"
"@

    $page = New-xPage -Name "$jeaEndpointName" -OnLoad ([scriptblock]::Create($onLoad)) -Finished ([scriptblock]::Create($finished)) -Store Session
    $page
}

New-UDDashboard -Pages $pages -Title New
