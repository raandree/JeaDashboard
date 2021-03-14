if (-not (Get-Lab)) {
    Write-Error 'Please importe the lab first' -ErrorAction Stop
}

$dc = Get-LabVM -Role RootDC

$users = 'Q-UDService', 'Q-UDScript', 'Q-UDVMware'
$password = 'Somepass1'

Invoke-LabCommand -ActivityName 'Create accounts in AD' -ScriptBlock {

    if (-not ($ou = Get-ADOrganizationalUnit -Filter { Name -eq 'xxUD' })) {
        $ou = New-ADOrganizationalUnit -Name xxUD -ProtectedFromAccidentalDeletion $false -PassThru
    }

    foreach ($user in $users) {
        if (-not (Get-ADUser -Filter { Name -eq $user })) {
            $securePass = $password | ConvertTo-SecureString -AsPlainText -Force
            New-ADUser -Name $user -AccountPassword $securePass -Path $ou -Enabled $true
        }
    }

    Add-KdsRootKey -EffectiveTime ((Get-Date).AddHours(-10))
    $webServers = Get-ADComputer -Filter { Name -like '*web*' }
    New-ADServiceAccount -Name gmsa1 -DNSHostName gmsa1.contoso.com -ManagedPasswordIntervalInDays 90 -PrincipalsAllowedToRetrieveManagedPassword $webServers -Enabled $True -PassThru 
    New-ADServiceAccount -Name gmsa2 -DNSHostName gmsa1.contoso.com -ManagedPasswordIntervalInDays 90 -PrincipalsAllowedToRetrieveManagedPassword $webServers -Enabled $True -PassThru 

} -ComputerName $dc -Variable (Get-Variable -Name users, password) -PassThru

Invoke-LabCommand -ActivityName 'Create lab users' -ComputerName $dc -FileName 'New-ADLabAccounts 2.0.ps1' -DependencyFolderPath $labSources\PostInstallationActivities\PrepareFirstChildDomain
