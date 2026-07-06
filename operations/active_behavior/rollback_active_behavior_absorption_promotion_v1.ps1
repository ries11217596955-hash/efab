param([string]$PromotionId="active_behavior_absorption_fresh_1000_v1")
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$manifestPath="operations/active_behavior/rollback/$PromotionId/rollback_manifest.json"
if(-not(Test-Path $manifestPath)){ throw "ROLLBACK_MANIFEST_MISSING" }
$m=Get-Content $manifestPath -Raw | ConvertFrom-Json
foreach($x in $m.protected_before){
  if(-not(Test-Path $x.backup_path)){ throw "BACKUP_MISSING=$($x.backup_path)" }
  Copy-Item -LiteralPath $x.backup_path -Destination $x.path -Force
}
Write-Host "ROLLBACK_APPLIED=$PromotionId"
Write-Host "RUNTIME_READY=false"