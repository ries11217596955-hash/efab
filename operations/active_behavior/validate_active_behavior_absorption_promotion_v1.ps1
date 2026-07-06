$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$reportPath="operations/reports/ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1.json"
if(-not(Test-Path $reportPath)){ throw "PROMOTION_REPORT_MISSING" }
$r=Get-Content $reportPath -Raw | ConvertFrom-Json
if($r.schema -ne "active_behavior_absorption_promotion_v1"){ throw "BAD_SCHEMA" }
if($r.status -ne "PROMOTION_ACTIVE_BODY_VERIFIED"){ throw "BAD_STATUS=$($r.status)" }
if($r.runtime_ready -ne $false){ throw "RUNTIME_READY_OVERCLAIM" }
if([int]$r.active_atom_count -ne 1000){ throw "BAD_ACTIVE_ATOM_COUNT" }
if([int64]$r.active_store_bytes -gt 5000000){ throw "ACTIVE_STORE_TOO_LARGE" }
if(-not(Test-Path $r.active_manifest_path)){ throw "ACTIVE_MANIFEST_MISSING" }
if(-not(Test-Path $r.active_index_path)){ throw "ACTIVE_INDEX_MISSING" }
foreach($cp in @(10,100,500,700,1000)){
  $x=@($r.checkpoint_results | Where-Object { [int]$_.checkpoint -eq $cp })
  if($x.Count -ne 1){ throw "MISSING_CHECKPOINT_$cp" }
  if($x[0].status -ne "PASS"){ throw "CHECKPOINT_FAIL_$cp" }
  if([int]$x[0].unique_atom_id_used_count -ne $cp){ throw "BAD_UNIQUE_$cp" }
}
foreach($p in @("reports/self_development/accepted_change_memory_snapshot.json","reports/self_development/SELF_MODEL_ACTIVE_MAP.json","packs/registry.json")){
  if(-not(Test-Path $p)){ throw "ACTIVE_SURFACE_MISSING=$p" }
}
$pointer=Get-Content reports/self_development/accepted_change_memory_snapshot.json -Raw | ConvertFrom-Json
if($pointer.schema -ne "efab_active_memory_pointer_v1"){ throw "ACTIVE_MEMORY_POINTER_NOT_INSTALLED" }
if($pointer.active_atom_count -ne 1000){ throw "ACTIVE_MEMORY_POINTER_BAD_COUNT" }
if(-not(Test-Path $r.rollback_manifest_path)){ throw "ROLLBACK_MANIFEST_MISSING" }
# prove active retrieval works from installed pointer
$out = & operations/active_behavior/invoke_active_behavior_retrieval_v1.ps1 -Domain behavior_injection -Limit 10 | ConvertFrom-Json
if($out.status -ne "PASS" -or [int]$out.returned_count -ne 10){ throw "ACTIVE_RETRIEVAL_FAILED" }
Write-Host "VALIDATION_PASS=ACTIVE_BEHAVIOR_ABSORPTION_PROMOTION_V1"
Write-Host "ACTIVE_ATOM_COUNT=$($r.active_atom_count)"
Write-Host "ACTIVE_STORE_BYTES=$($r.active_store_bytes)"
Write-Host "ACTIVE_RETRIEVAL_STATUS=$($out.status)"
Write-Host "ROLLBACK_READY=$($r.rollback_ready)"
Write-Host "RUNTIME_READY=false"