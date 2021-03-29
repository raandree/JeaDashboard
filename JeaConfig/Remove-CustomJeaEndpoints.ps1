#1..10 | ForEach-Object { Register-PSSessionConfiguration -Name "t$_" -NoServiceRestart -Force -ErrorAction 'Stop' }

Get-PSSessionConfiguration | 
Where-Object { $_.Name -notlike 'microsoft*' } | 
ForEach-Object {
    Write-Host "Unregistering '$($_.Name)'"
    Unregister-PSSessionConfiguration -Name $_.Name -Force -NoServiceRestart
}
Restart-Service -Name WinRM