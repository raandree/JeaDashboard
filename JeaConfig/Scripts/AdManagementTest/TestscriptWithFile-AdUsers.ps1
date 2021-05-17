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

.INPUTS
	Es wird eine Input Datei (Parametername: ScriptInputFile) im Format 'txt' verwendet

.OUTPUTS
	Änderungen ... auf dem Server ... und immer ein Log File.
	Das Log File liegt immer in C:\VRZ\Secure_Logs\TestscriptWithFile.ps1_<Ausführungs_Datum>.log>
 
.EXAMPLE

	Zum Starten des Skripts nutze folgendes Kommando:
    TestscriptWithFile.ps1
  
.NOTES
    {
    "Department":  "AD", 
    "JeaRole":  "AdManagementUser",       
    "MenuLevel":  {
                      "Parent":  "Root",  
                      "Current":  "AD"
                  }
}
#>

param (
    [Parameter(Mandatory=$false,HelpMessage='.txt-Datei mit Prozessliste öffnen...')]
	[ValidateNotNullOrEmpty()]
	[ValidateScript({
		if (-Not (Test-Path -Path $_)) {
			Throw "File does not exist"
		}
		return $true
	})]
	[System.IO.FileInfo]$ScriptInputFile,
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

		<#
		if ($ParameterSet = "Default") {
			$Parameter = @()
			foreach ($line in (Get-Content $ScriptInputFileContent)) {
				$Parameter += [PSCustomObject]@{
					Process = $line
				}
			}
		}
		elseif ($ParameterSet = "FileUpload") {
			$Parameter = $FileUpload
		}

		foreach ($process in $Parameter) {
		    Get-Process -Name ($Parameter.Process + "*")
		}
		#>
		
		$ScriptInputFileContent = Get-Content $HashConfiguration['Get_File']

		$Processes = foreach ($process in $ScriptInputFileContent) {
		    Get-Process -Name ($process + "*")
		}
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

# definieren des Skriptblockes, der Anpassungen der Skriptvariablen erlaubt
$ConfigAction =
{
	Log-write -Logpath $sLogFile -LineValue "Anpassung der Skriptvariablen"
	$HashConfiguration['GET_InputExtension'] = ".txt"
    Log-write -Logpath $sLogFile -LineValue "Anpassung der Skriptvariablen gelaufen"
}

# konvertieren der Sctiptblöcke in Strings damit Variablen sauber übergeben werden
#$ScriptBlockCheckString = $ScriptBlockCheck.ToString()
$ScriptBlockExecString = $ScriptBlockExec.ToString()
$ConfigActionString = $ConfigAction.ToString()

if ($ScriptInputFile) {
	$InputFileHash = @{
		myInputFile = $ScriptInputFile
	}
}

# Ausführen der Aktionen
Use-FIWindowsBasisModul -Name $Name -Beschreibung $Beschreibung <#-CheckAction $ScriptBlockCheckString#> -ExecuteAction $ScriptBlockExecString -ConfigAction $ConfigActionString -Manuell -needInputFile @InputFileHash
