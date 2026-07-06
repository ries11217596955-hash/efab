param([Parameter(Mandatory=$true)][string]$PromotionId)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$rollbackDir="operations/school/curriculum/ready_lane/rollback/$PromotionId"
$manifestPath="$rollbackDir/promotion_manifest.json"
if(-not (Test-Path $manifestPath)){ throw "ROLLBACK_MANIFEST_MISSING: $manifestPath" }
$m=Get-Content $manifestPath -Raw | ConvertFrom-Json
foreach($p in $m.protected_files){
  $backupName=$m.backup_map.$p
  if(-not $backupName){ $backupName=(($p -replace '[\\/]','__') + '.before') }
  $backup=Join-Path $rollbackDir $backupName
  if(Test-Path $backup){ Copy-Item $backup $p -Force; Write-Host "RESTORED|$p" } else { Write-Host "SKIP_NO_BACKUP|$p" }
}
Write-Host "ROLLBACK_STATUS=RESTORED_READY_LANE_ACTIVE_PROMOTION"
Write-Host "PROMOTION_ID=$PromotionId"