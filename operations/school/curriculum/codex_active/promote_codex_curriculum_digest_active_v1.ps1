$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
$promotionId="codex_curriculum_digest_active_v1"
$checkpointPath="operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json"
$validationPath="operations/reports/CODEX_CURRICULUM_DIGESTION_V1_VALIDATION.json"
if(-not (Test-Path $checkpointPath)){ throw "CHECKPOINT_MISSING" }
if(-not (Test-Path $validationPath)){ throw "VALIDATION_MISSING" }
$cp=Get-Content $checkpointPath -Raw | ConvertFrom-Json
$v=Get-Content $validationPath -Raw | ConvertFrom-Json
if($v.status -ne "PASS_CODEX_CURRICULUM_DIGESTION_VALIDATION_V1"){ throw "DIGESTION_NOT_PASS" }
$protected=@("reports/self_development/accepted_change_memory_snapshot.json","reports/self_development/SELF_MODEL_ACTIVE_MAP.json","packs/registry.json")
$rollbackDir="operations/school/curriculum/codex_active/rollback/$promotionId"
New-Item -ItemType Directory -Force -Path $rollbackDir | Out-Null
$before=@{}
foreach($p in $protected){ if(-not (Test-Path $p)){ throw "PROTECTED_MISSING: $p" }; $before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower(); Copy-Item $p (Join-Path $rollbackDir (($p -replace "[\\/]","__") + ".before.json")) -Force }
$snapshot=Get-Content $protected[0] -Raw | ConvertFrom-Json
$map=Get-Content $protected[1] -Raw | ConvertFrom-Json
$registry=Get-Content $protected[2] -Raw | ConvertFrom-Json
function AddOrSet($obj,$name,$value){ if($obj.PSObject.Properties.Name -contains $name){ $obj.$name=$value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value } }
foreach($obj in @($snapshot,$map,$registry)){
  AddOrSet $obj "active_codex_curriculum_digest_status" "ACTIVE_REPO_BODY_DECISION_SOURCE"
  AddOrSet $obj "active_codex_curriculum_digest_checkpoint_path" $checkpointPath
  AddOrSet $obj "active_codex_curriculum_digest_atom_count" ([int]$cp.digested_atom_candidate_count)
  AddOrSet $obj "active_codex_curriculum_digest_promotion_id" $promotionId
  AddOrSet $obj "active_codex_curriculum_digest_boundary" "repo-body active decision source only; not live and not D2B accepted-core"
}
AddOrSet $registry "codex_curriculum_digest_pack_id" $promotionId
AddOrSet $registry "codex_curriculum_digest_status" "ACTIVE"
[IO.File]::WriteAllText((Join-Path (Get-Location).Path $protected[0]),($snapshot|ConvertTo-Json -Depth 40),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path $protected[1]),($map|ConvertTo-Json -Depth 40),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path $protected[2]),($registry|ConvertTo-Json -Depth 40),$utf8)
$after=@{}; foreach($p in $protected){$after[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()}
$manifest=[pscustomObject]@{schema="codex_curriculum_active_promotion_manifest_v1"; promotion_id=$promotionId; status="ACTIVE_REPO_BODY_DECISION_SOURCE"; runtime_ready=$false; checkpoint_path=$checkpointPath; atom_count=[int]$cp.digested_atom_candidate_count; protected_files=$protected; before_sha256=$before; after_sha256=$after; rollback_dir=$rollbackDir; accepted_core_promotion=$false; live_promotion=$false; boundary="Promotes school-local Codex curriculum atoms into repo-body active decision source only."}
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "$rollbackDir/promotion_manifest.json"),($manifest|ConvertTo-Json -Depth 50),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json"),($manifest|ConvertTo-Json -Depth 50),$utf8)
$md=@("# CODEX_CURRICULUM_ACTIVE_PROMOTION_V1","","Status: ACTIVE_REPO_BODY_DECISION_SOURCE","Runtime ready: false","","Promotion id: $promotionId","Atom count: $($cp.digested_atom_candidate_count)","Accepted-core promotion: false","Live promotion: false","","Boundary: repo-body active decision source only; not live and not D2B accepted-core.")
[IO.File]::WriteAllText((Join-Path (Get-Location).Path "operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.md"),($md -join "`r`n"),$utf8)
Write-Host "PROMOTION_STATUS=ACTIVE_REPO_BODY_DECISION_SOURCE"
Write-Host "ATOM_COUNT=$($cp.digested_atom_candidate_count)"
Write-Host "ACCEPTED_CORE_PROMOTION=false"
Write-Host "LIVE_PROMOTION=false"
Write-Host "RUNTIME_READY=false"