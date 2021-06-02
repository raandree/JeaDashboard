<#
.SYNOPSIS
    New-xADGroup.ps1
 
.DESCRIPTION

{
    "Name": "New-xADGroup",
    "Department":  "WinSrv", 
    "JeaRole":  "AdManagementGroups",       
    "MenuLevel":  {
                      "Parent":  "Root",  
                      "Current":  "WinSrv"
                  },
    "GUID": "2891e18e-f290-4309-929e-1cfa5aedb7b5",
    "ModulesToImport": ["ActiveDirectory"]
}
#>

param (
    [Parameter(ParameterSetName = 'Default')]
    [string]$Path = 'CN=Users,DC=contoso,DC=com',
    
    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [string]$Name,
    
    [Parameter(ParameterSetName = 'Default')]
    [string]$Description,

    [Parameter(ParameterSetName = 'Default')]
    [ValidateSet('DomainLocal', 'Universal', 'Global')]
    [string]$GroupScope = 'Global',

    [Parameter(ParameterSetName = 'Default')]
    [ValidateSet('Distribution', 'Security')]
    [string]$GroupCategory = 'Security'
)

"New-ADGroup -Path $Path -Name $Name -GroupType $GroupType -Description $Description" | Out-File -FilePath C:\Commands.txt -Append
New-ADGroup -Path $Path -Name $Name -GroupScope $GroupScope -GroupCategory $GroupCategory -Description $Description