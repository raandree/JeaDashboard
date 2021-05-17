$here = $PSScriptRoot
dir -Path $here\BuildOutput\MOF | Where-Object Name -NotLike "$($env:COMPUTERNAME)*" | Remove-Item
dir -Path $here\BuildOutput\MetaMof | Where-Object Name -NotLike "$($env:COMPUTERNAME)*" | Remove-Item

Set-DscLocalConfigurationManager -Path $here\BuildOutput\MetaMof -Verbose
Start-DscConfiguration -Path $here\BuildOutput\MOF -Force -Wait -Verbose
