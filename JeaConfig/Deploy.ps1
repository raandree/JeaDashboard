$here = $PSScriptRoot
dir -Path $here\BuildOutput\MOF | Where-Object Name -NotLike 'jWeb1*' | Remove-Item
dir -Path $here\BuildOutput\MetaMof | Where-Object Name -NotLike 'jWeb1*' | Remove-Item

Set-DscLocalConfigurationManager -Path $here\BuildOutput\MetaMof -Verbose
Start-DscConfiguration -Path $here\BuildOutput\MOF -Force -Wait -Verbose
