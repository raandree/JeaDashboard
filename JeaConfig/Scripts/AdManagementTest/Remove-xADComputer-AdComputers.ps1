<#
.SYNOPSIS
    Remove-xADComputer.ps1
 
.DESCRIPTION

{
    "Name": "Remove-xADComputer",
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
    [Parameter(Mandatory, ParameterSetName = 'Default')]
    [string]$Identity
)

"Remove-ADComputer -Identity $Identity -Confirm:$false" | Out-File -FilePath C:\Commands.txt -Append
Remove-ADComputer -Identity $Identity -Confirm:$false