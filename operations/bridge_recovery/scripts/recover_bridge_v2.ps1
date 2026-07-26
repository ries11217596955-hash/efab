param([string]$PrimaryPublicUrl,[string]$RescuePublicUrl)
$ErrorActionPreference='Stop'
foreach($n in @('EFAB Rescue Control SYSTEM','EFAB Ngrok Primary SYSTEM','EFAB Bridge Boot SYSTEM','EFAB Recovery Gateway SYSTEM','EFAB Rescue Watchdog SYSTEM','EFAB Ngrok Watchdog SYSTEM')){Start-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue}
Start-Sleep 15
& (Join-Path $PSScriptRoot 'validate_bridge_v2.ps1') -PrimaryPublicUrl $PrimaryPublicUrl -RescuePublicUrl $RescuePublicUrl
