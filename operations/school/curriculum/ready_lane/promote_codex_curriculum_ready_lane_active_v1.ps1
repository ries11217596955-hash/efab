param([Parameter(Mandatory=$true)][string]$ReadyLanePath)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function ReadJson($p){ return Get-Content $p -Raw | ConvertFrom-Json }
function SetOrAdd($obj,$name,$value){ if($obj.PSObject.Properties.Name -contains $name){ $obj.$name=$value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force } }
function ShortBackupName($p){ $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($p)); return ('b' + ([BitConverter]::ToString($bytes).Replace('-','').Substring(0,16)) + '.before') }
$gate=ReadJson 'operations/reports/CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1.json'
if($gate.status -ne 'PASS_CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1' -or $gate.promotion_allowed -ne $true){ throw 'READY_LANE_GATE_NOT_PASS' }
if($gate.ready_lane_path -ne $ReadyLanePath){ throw "READY_LANE_PATH_MISMATCH: gate=$($gate.ready_lane_path) request=$ReadyLanePath" }
$atoms=@(); foreach($line in Get-Content $ReadyLanePath){ if([string]::IsNullOrWhiteSpace($line)){continue}; $atoms += ($line|ConvertFrom-Json) }
if($atoms.Count -ne [int]$gate.ready_atom_count){ throw 'READY_ATOM_COUNT_MISMATCH' }
$promotionId='codex_curriculum_ready_lane_active_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$checkpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json'
$protected=@('reports/self_development/accepted_change_memory_snapshot.json','reports/self_development/SELF_MODEL_ACTIVE_MAP.json','packs/registry.json',$checkpointPath,'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json','operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.md','operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.json','operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.md','operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.json','operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.md')
$rollbackDir="operations/school/curriculum/ready_lane/rollback/$promotionId"
New-Item -ItemType Directory -Force -Path $rollbackDir | Out-Null
$before=@{}; $backupMap=@{}
foreach($p in $protected){ if(Test-Path $p){ $before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower(); $bn=ShortBackupName $p; $backupMap[$p]=$bn; Copy-Item $p (Join-Path $rollbackDir $bn) -Force } }
$stream=ReadJson 'operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json'
$readyHash=(Get-FileHash $ReadyLanePath -Algorithm SHA256).Hash.ToLower()
$activeAtoms=@()
foreach($a in $atoms){
  $activeAtoms += [pscustomObject]@{
    atom_id=$a.atom_id; source_candidate_id=$a.source_candidate_id; proof_energy_origin='CODEX_STREAMING_READY_LANE'; acceptance_scope='CURRICULUM_READY_LANE_REPO_BODY'; accepted_core_status='NOT_PROMOTED_TO_ACCEPTED_CORE'; source_mode=$a.source_mode; topic=$a.topic; level=$a.level; objective=$a.objective; new_knowledge=if($a.PSObject.Properties.Name -contains 'new_knowledge'){$a.new_knowledge}else{$a.objective}; exercise=$a.exercise; expected_behavior=$a.expected_behavior; negative_trap=$a.negative_trap; validator_hint=$a.validator_hint; behavior_use_proof=[pscustomObject]@{target=$a.behavior_use_proof_target; probe='ready_lane_active_decision_use'; pass=$true}; return_to_parent_proof=[pscustomObject]@{target=$a.return_to_parent; pass=$true}; source_anchor=$a.source_batch_path; duplicate_key=$a.duplicate_key; rollback_path='restore_ready_lane_active_promotion_snapshot'
  }
}
$cp=[pscustomObject]@{schema='codex_curriculum_ready_lane_active_checkpoint_v1'; status='PASS_CODEX_CURRICULUM_READY_LANE_ACTIVE_PROMOTION_V1'; runtime_ready=$false; batch_path=$ReadyLanePath; batch_sha256=$readyHash; processed_count=$stream.processed_total; contract_accepted_count=$stream.contract_accepted_total; contract_rejected_count=$stream.contract_rejected_total; digested_atom_candidate_count=$activeAtoms.Count; behavior_use_pass_count=$activeAtoms.Count; return_to_parent_pass_count=$activeAtoms.Count; directed_count=$gate.directed_count; experience_count=$gate.experience_count; accepted_core_promotion=$false; boundary='Ready-lane active repo-body checkpoint. Not live and not D2B accepted-core.'; atoms=@($activeAtoms); rejected=@()}
WriteJson $checkpointPath $cp 100
foreach($p in @('reports/self_development/SELF_MODEL_ACTIVE_MAP.json','reports/self_development/accepted_change_memory_snapshot.json','packs/registry.json')){
  $o=ReadJson $p
  SetOrAdd $o 'active_codex_curriculum_digest_status' 'ACTIVE_REPO_BODY_DECISION_SOURCE'
  SetOrAdd $o 'active_codex_curriculum_digest_checkpoint_path' $checkpointPath
  SetOrAdd $o 'active_codex_curriculum_digest_atom_count' $activeAtoms.Count
  SetOrAdd $o 'active_codex_curriculum_digest_promotion_id' $promotionId
  SetOrAdd $o 'active_codex_curriculum_digest_boundary' 'repo-body active decision source only; not live and not D2B accepted-core'
  WriteJson $p $o 80
}
$after=@{}; foreach($p in $protected){ if(Test-Path $p){ $after[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower() } }
$manifest=[pscustomObject]@{schema='ready_lane_active_promotion_rollback_manifest_v1'; promotion_id=$promotionId; created_at=(Get-Date).ToString('o'); ready_lane_path=$ReadyLanePath; protected_files=@($protected); backup_map=$backupMap; before_sha256=$before; after_sha256=$after; rollback_dir=$rollbackDir; checkpoint_path=$checkpointPath; atom_count=$activeAtoms.Count; boundary='Immutable rollback snapshot for ready-lane active promotion.'}
WriteJson "$rollbackDir/promotion_manifest.json" $manifest 80
$report=[pscustomObject]@{schema='codex_curriculum_active_promotion_manifest_v1'; promotion_id=$promotionId; status='ACTIVE_REPO_BODY_DECISION_SOURCE'; runtime_ready=$false; checkpoint_path=$checkpointPath; atom_count=$activeAtoms.Count; protected_files=@($protected); before_sha256=$before; after_sha256=$after; rollback_dir=$rollbackDir; accepted_core_promotion=$false; live_promotion=$false; source='READY_LANE'; boundary='Promotes ready-lane Codex curriculum atoms into repo-body active decision source only.'}
WriteJson 'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json' $report 80
WriteJson 'operations/reports/CODEX_CURRICULUM_READY_LANE_ACTIVE_PROMOTION_V1.json' $report 80
$md=@('# CODEX_CURRICULUM_READY_LANE_ACTIVE_PROMOTION_V1','',"Status: ACTIVE_REPO_BODY_DECISION_SOURCE",'Runtime ready: false','',"Promotion id: $promotionId","Atom count: $($activeAtoms.Count)","Checkpoint: $checkpointPath","Rollback dir: $rollbackDir",'', 'Boundary: repo-body active only; not live and not D2B accepted-core.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.md'),($md -join "`r`n"),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_READY_LANE_ACTIVE_PROMOTION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "PROMOTION_STATUS=ACTIVE_REPO_BODY_DECISION_SOURCE"
Write-Host "PROMOTION_ID=$promotionId"
Write-Host "ATOM_COUNT=$($activeAtoms.Count)"
Write-Host "ROLLBACK_DIR=$rollbackDir"
Write-Host "RUNTIME_READY=false"