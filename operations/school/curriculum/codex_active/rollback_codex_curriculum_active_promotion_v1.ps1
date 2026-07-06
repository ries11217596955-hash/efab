$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$promotionId="codex_curriculum_digest_active_v1"
$rollbackDir="operations/school/curriculum/codex_active/rollback/$promotionId"
$manifestPath="$rollbackDir/promotion_manifest.json"
if(-not (Test-Path $manifestPath)){ throw "ROLLBACK_MANIFEST_MISSING" }
$m=Get-Content $manifestPath -Raw | ConvertFrom-Json
foreach($p in $m.protected_files){ $backup=Join-Path $rollbackDir (($p -replace "[\\/]","__") + ".before.json"); if(Test-Path $backup){ Copy-Item $backup $p -Force; Write-Host "RESTORED|$p" } else { throw "BACKUP_MISSING: $backup" } }
Write-Host "ROLLBACK_STATUS=RESTORED_CODEX_CURRICULUM_ACTIVE_PROMOTION"