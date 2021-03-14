if (-not (Get-Lab)) {
    Write-Error 'Please importe the lab first' -ErrorAction Stop
}

$webServers = Get-LabVM -Role WebServer

$users = 'Q-UDService', 'Q-UDScript', 'Q-UDVMware'
$password = 'Somepass1'

$cred = New-Object pscredential('contoso\Q-UDService', ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))

Invoke-LabCommand -ActivityName "Allow remote management for 'Q-UDService'" -ScriptBlock {
    Add-LocalGroupMember -Group 'Remote Management Users' -Member Q-UDService
} -ComputerName $webServers

Invoke-LabCommand -ActivityName "Store credentials for 'Q-UDService' in the context of 'Q-UDService'" -ScriptBlock {
    mkdir -Path C:\UDCredentials -Force

    foreach ($user in $users)
    {
        $cred = New-Object pscredential('contoso\Q-UDService', ('Somepass1' | ConvertTo-SecureString -AsPlainText -Force))
        $cred | Export-Clixml -Path C:\UDCredentials\$user.xml
    }
} -ComputerName $webServers -Variable (Get-Variable -Name users, password) -Credential $cred
