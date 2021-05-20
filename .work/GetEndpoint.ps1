$endpoints = Get-JeaEndpoint -ComputerName $env:COMPUTERNAME
#$endpoints = $endpoints[1]
$modules = Get-ModuleWithRoleCapabilities
$roleCapabilities = $modules | ForEach-Object {
    Get-PSRoleCapability -ModuleBasePath $_.ModuleBase
}

$accessByGroup = @{}
$endpoints | ForEach-Object {
    $_.RoleDefinitions.GetEnumerator() | ForEach-Object {
        if ($accessByGroup.ContainsKey($_.Name)) {
            $accessByGroup."$($_.Name)" += $_.Value
        }
        else {
            $accessByGroup."$($_.Name)" = @($_.Value)
        }
    }
}

$roles = foreach ($endpoint in $endpoints) {
    foreach ($roleDefinition in ($endpoint.RoleDefinitions.Values | Select-Object -Unique)) {
        $role = $roleCapabilities | Where-Object RoleName -eq $roleDefinition
        if ($role.EndpointName) {
            $role.EndpointName += $endpoint.Name
        }
        else {
            $role | Add-Member -Name EndpointName -MemberType NoteProperty -Value @($endpoint.Name)
        }
        $role
    }
}

$accessByGroup.'contoso\Domain Users' | Select-Object -Unique

($roles | Where-Object RoleName -eq 'DhcpManagement').VisibleFunctions

$userRoles = [System.Security.Principal.WindowsIdentity]::GetCurrent().Groups |
    ForEach-Object { $_.Translate([System.Security.Principal.NTAccount]) } |
    ForEach-Object {
    $accessByGroup."$($_.Value)"
    
} | Select-Object -Unique | ForEach-Object { 
    $roles | Where-Object RoleName -eq $_
}

$userRoles.VisibleFunctions