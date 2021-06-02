<#
.SYNOPSIS
    New-xADComputer.ps1
 
.DESCRIPTION

{
    "Name": "New-xADComputer",
    "Department":  "WinSrv", 
    "JeaRole":  "AdManagementComputers",       
    "MenuLevel":  {
                      "Parent":  "Root",  
                      "Current":  "WinSrv"
                  },
    "GUID": "4046a234-2691-41be-a559-e4cdffb31489",
    "ModulesToImport": ["ActiveDirectory"]
}
#>

param (
    [Parameter(ParameterSetName = 'Default')]
    [string]$Path = 'CN=Users,DC=contoso,DC=com',
        
    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [string]$Name
)

"New-ADComputer -Path $Path -Name $Name" | Out-File -FilePath C:\Commands.txt -Append
New-ADComputer -Path $Path -Name $Name