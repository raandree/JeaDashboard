configuration JeaEndpoints {
    param (
        [Parameter(Mandatory)]
        [hashtable[]]$Endpoints
    )

    Import-DscResource -ModuleName JeaDsc

    foreach ($endpoint in $Endpoints)
    {
        if (-not $endpoint.ContainsKey('Ensure'))
        {
            $endpoint.Ensure = 'Present'
        }

        #ConvertTo-Expression converts single-item arrays with a comma which JEA does not. To resolve this conflict,
        #the following values will be changed from a object[] to the array item type containing the first  element.
        foreach ($roleDefinition in $endpoint.RoleDefinitions.GetEnumerator()) {
            if ($roleDefinition.Value.RoleCapabilities -is [array] -and $roleDefinition.Value.RoleCapabilities.Count -eq 1){
                $roleDefinition.Value.RoleCapabilities = $roleDefinition.Value.RoleCapabilities[0]
            }
        }

        if ($endpoint.RoleDefinitions)
        {
            $endpoint.RoleDefinitions = ConvertTo-Expression -Object $endpoint.RoleDefinitions -Explore
        }
        
        (Get-DscSplattedResource -ResourceName JeaSessionConfiguration -ExecutionName "JeaSessionConfiguration_$($endpoint.Name)" -Properties $endpoint -NoInvoke).Invoke($endpoint)
        
    }

}
