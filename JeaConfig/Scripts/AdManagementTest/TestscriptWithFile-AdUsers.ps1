<#
.SYNOPSIS
    TestscriptWithFile.ps1
 
.DESCRIPTION

{
    "Department":  "WinSrv", 
    "JeaRole":  "AdManagementUsers",       
    "MenuLevel":  {
                      "Parent":  "Root",  
                      "Current":  "WinSrv"
                  },
    "GUID": "c6f346d9-86db-44f7-8d9c-11cb81638a3e",
	"ModulesToImport": ["ActiveDirectory"]
}
#>

[CmdletBinding(DefaultParameterSetName = 'ip')]
param (
	[Parameter(Mandatory)]
	[string]$HostName,
        
	[Parameter(Mandatory, ParameterSetName = 'ip')]
	[string]$IpAddress,
        
	[Parameter(Mandatory, ParameterSetName = 'ip')]
	[string]$Prefix,
        
	[Parameter(Mandatory, ParameterSetName = 'mac')]
	[string]$MacAddress,
        
	[Parameter(ParameterSetName = 'ip')]
	[Parameter(Mandatory, ParameterSetName = 'mac')]
	[string]$SwitchName
)

$PSBoundParameters
