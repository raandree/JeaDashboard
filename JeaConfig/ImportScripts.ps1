param(
    [Parameter()]
    [string]$Path = "$PSScriptRoot\Scripts",

    [Parameter()]
    [string]$ModuleName = 'Demos'
)

$here = $PSScriptRoot
$scripts = dir -Path $Path -Recurse -File -Filter *.ps1

$metaData = foreach ($script in $scripts) {
    $help = Get-Help $script.FullName -Full
    $md = $help.description[0].Text | ConvertFrom-Json
    $scriptName = if ($md.Name) {
        $md.Name
    }
    else {
        $script.BaseName
    }
    $md | Add-Member -Name ScriptName -MemberType NoteProperty -Value $scriptName
    $md | Add-Member -Name ScriptFullName -MemberType NoteProperty -Value $script.FullName
    $md
}

$roles = $metaData | Group-Object -Property JeaRole
foreach ($role in $roles) {
    $scripts = $role.Group
    $roleName = $role.Name
    $modulesToImport = $scripts.ModulesToImport | Select-Object -Unique
    $role = @{ 
        JeaRoles          = @{
            Roles = @(
                @{
                    Path                = "C:\Program Files\WindowsPowerShell\Modules\$ModuleName\RoleCapabilities\$roleName.psrc"
                    ModulesToImport     = $modulesToImport
                    VisibleFunctions    = @()
                    FunctionDefinitions = @()
                }
            )
        }
        Configurations = , 'JeaRoles'
    
    }

    foreach ($script in $scripts) {

        $scriptRole = $role.JeaRoles.Roles | Where-Object Path -like "*$($script.JeaRole)*"
        $scriptRole.VisibleFunctions += $script.ScriptName
        $scriptRole.FunctionDefinitions += @{
            Name        = $script.ScriptName
            ScriptBlock = Get-Content -Path $script.ScriptFullName -Raw
        }
    }

    $role | ConvertTo-Yaml | Out-File -FilePath "$here\DscConfigData\Roles\$roleName.yml"
}
