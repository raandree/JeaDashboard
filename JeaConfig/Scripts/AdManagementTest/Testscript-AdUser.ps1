<#
.SYNOPSIS
    Testscript.ps1
 
.DESCRIPTION

{
    "Department":  "WinSrv", 
    "JeaRole":  "AdManagementUsers",       
    "MenuLevel":  {
                      "Parent":  "Root",  
                      "Current":  "WinSrv"
                  },
    "GUID": "bf418a7b-3a9e-4967-b826-ddb9d517f487",
    "ModulesToImport": ["ActiveDirectory"]
}
#>

param (
	[Parameter(Mandatory=$true)]
	[String]$ProcessName,
	[Parameter(Mandatory=$true)]
	[String]$ServiceName
)

$PSBoundParameters
