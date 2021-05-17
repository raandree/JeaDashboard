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

.OUTPUTS
	Änderungen ... auf dem Server ... und immer ein Log File.
	Das Log File liegt immer in C:\VRZ\Secure_Logs\Testscript.ps1_<Ausführungs_Datum>.log>
 
.EXAMPLE

	Zum Starten des Skripts nutze folgendes Kommando:
    Testscript.ps1
  
.NOTES

#>

param (
	[Parameter(Mandatory=$true)]
	[String]$ProcessName,
	[Parameter(Mandatory=$true)]
	[String]$ServiceName
)

# Importieren des benötigten Moduls
Import-Module -name "D:\Skripte\Entwicklung\Modul_FIWindowsBasis\FIWindowsBasisModul.psd1"

# definieren des Namens des Scriptes / der Aktion
$Name = ($MyInvocation.MyCommand.Name).Substring(0,($MyInvocation.MyCommand.Name).Length - 4)

# Beschreibung des Scriptes / der Aktionen (wird benötigt für Logeinträge)
$Beschreibung = "6fce6534-053d-Description-4b64-a9cb-a6dd2f6b1185"

<#
# definieren des Scriptblockes der vor dem Ausführen der hauptsächlichen Aktion durchgeführt wird
$ScriptBlockCheck =
{
    Log-write -Logpath $sLogFile -LineValue "Vorabcheck gelaufen"
}
#>

# definieren des Skriptblockes der die hauptsächlichen Aktionen beinhaltet
$ScriptBlockExec =
{
    Try {
		
        $Processes = Get-Process -Name ($ProcessName + "*")
        if ($null -ine $Processes) {
            Log-write -Logpath $sLogFile -LineValue ($Processes | Out-String)
        }
        $Services = Get-Service -Name ($ServiceName + "*")
        if ($null -ine $Services) {
            Log-write -Logpath $sLogFile -LineValue ($Services | Out-String)
        }
    }
    Catch {

        Log-Error -LogPath $sLogFile -ErrorDesc $_.Exception -ExitGracefully $True

    }

    Log-write -Logpath $sLogFile -LineValue "Ausführung gelaufen"
}

<#
# definieren des Skriptblockes, der Anpassungen der Skriptvariablen erlaubt
$ConfigAction =
{
    Log-write -Logpath $sLogFile -LineValue "Anpassung der Skriptvariablen gelaufen"
}
#>

# konvertieren der Sctiptblöcke in Strings damit Variablen sauber übergeben werden
#$ScriptBlockCheckString = $ScriptBlockCheck.ToString()
$ScriptBlockExecString = $ScriptBlockExec.ToString()
#$ConfigActionString = $ConfigAction.ToString()

# Ausführen der Aktionen
Use-FIWindowsBasisModul -Name $Name -Beschreibung $Beschreibung <#-CheckAction $ScriptBlockCheckString#> -ExecuteAction $ScriptBlockExecString <#-ConfigAction $ConfigActionString#> -Manuell
