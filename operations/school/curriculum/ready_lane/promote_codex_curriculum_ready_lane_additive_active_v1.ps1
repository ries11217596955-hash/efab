param([Parameter(Mandatory=$true)][string]$ReadyLanePath)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function ReadJson($p){ return Get-Content $p -Raw | ConvertFrom-Json }
function SetOrAdd($obj,$name,$value){ if($obj.PSObject.Properties.Name -contains $name){ $obj.$name=$value } else { $obj | Add-Member -NotePropertyName $name -NotePropertyValue $value -Force } }
function Slug($s){ return (([string]$s).ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_') }
function ShortBackupName($p){ $sha=[System.Security.Cryptography.SHA256]::Create(); $bytes=$sha.ComputeHash([Text.Encoding]::UTF8.GetBytes($p)); return ('b' + ([BitConverter]::ToString($bytes).Replace('-','').Substring(0,16)) + '.before') }
function GuardLegacyPromotionRoute(){
  $routePath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json'
  if(Test-Path $routePath){
    $route=ReadJson $routePath
    if([string]$route.active_source -eq 'incremental_active_store_v1'){
      throw 'LEGACY_FULL_CHECKPOINT_PROMOTION_BLOCKED_BY_ACTIVE_ROUTE: use operations/school/curriculum/ready_lane/absorb_ready_lane_via_active_route_v1.ps1'
    }
  }
}
GuardLegacyPromotionRoute
$gate=ReadJson 'operations/reports/CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1.json'
if($gate.status -ne 'PASS_CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1' -or $gate.promotion_allowed -ne $true){ throw 'READY_LANE_GATE_NOT_PASS' }
if($gate.ready_lane_path -ne $ReadyLanePath){ throw "READY_LANE_PATH_MISMATCH: gate=$($gate.ready_lane_path) request=$ReadyLanePath" }
$checkpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json'
$oldCp=ReadJson $checkpointPath
$oldAtoms=@($oldCp.atoms)
$newReady=@(); foreach($line in Get-Content $ReadyLanePath){ if([string]::IsNullOrWhiteSpace($line)){continue}; $newReady += ($line|ConvertFrom-Json) }
if($newReady.Count -ne [int]$gate.ready_atom_count){ throw 'READY_ATOM_COUNT_MISMATCH' }
$oldTopics=@{}; $oldKeys=@{}; foreach($a in $oldAtoms){ $oldTopics[[string]$a.topic]=$true; $oldKeys[[string]$a.duplicate_key]=$true }
$topicOverlap=@(); $keyOverlap=@()
foreach($a in $newReady){ if($oldTopics.ContainsKey([string]$a.topic)){ $topicOverlap += [string]$a.topic }; if($oldKeys.ContainsKey([string]$a.duplicate_key)){ $keyOverlap += [string]$a.duplicate_key } }
if($topicOverlap.Count -gt 0){ throw "ADDITIVE_TOPIC_OVERLAP: $($topicOverlap[0])" }
if($keyOverlap.Count -gt 0){ throw "ADDITIVE_DUPLICATE_KEY_OVERLAP: $($keyOverlap[0])" }
$promotionId='codex_curriculum_ready_lane_additive_' + (Get-Date -Format 'yyyyMMdd_HHmmss')
$protected=@('reports/self_development/accepted_change_memory_snapshot.json','reports/self_development/SELF_MODEL_ACTIVE_MAP.json','packs/registry.json',$checkpointPath,'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json','operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.md','operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.json','operations/reports/CODEX_CURRICULUM_ACTIVE_DECISION_USE_V1.md','operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.json','operations/reports/CODEX_CURRICULUM_SCALE_GATE_V1.md')
$rollbackDir="operations/school/curriculum/ready_lane/rollback/$promotionId"
New-Item -ItemType Directory -Force -Path $rollbackDir | Out-Null
$before=@{}; $backupMap=@{}
foreach($p in $protected){ if(Test-Path $p){ $before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower(); $bn=ShortBackupName $p; $backupMap[$p]=$bn; Copy-Item $p (Join-Path $rollbackDir $bn) -Force } }
$incomingActive=@(); $idx=0
foreach($a in $newReady){
  $idx++
  $incomingActive += [pscustomObject]@{
    atom_id=("codex.curriculum.additive.atom.{0}.{1:D6}.{2}.v1" -f $promotionId,$idx,(Slug $a.topic))
    source_candidate_id=$a.source_candidate_id
    source_ready_atom_id=$a.atom_id
    proof_energy_origin='LOCAL_FACTORY_STREAMING_READY_LANE'
    acceptance_scope='CURRICULUM_READY_LANE_REPO_BODY_ADDITIVE'
    accepted_core_status='NOT_PROMOTED_TO_ACCEPTED_CORE'
    source_mode=$a.source_mode
    topic=$a.topic
    level=$a.level
    objective=$a.objective
    new_knowledge=if($a.PSObject.Properties.Name -contains 'new_knowledge'){$a.new_knowledge}else{$a.objective}
    exercise=$a.exercise
    expected_behavior=$a.expected_behavior
    negative_trap=$a.negative_trap
    validator_hint=$a.validator_hint
    behavior_use_proof=[pscustomObject]@{target=$a.behavior_use_proof_target; probe='additive_ready_lane_active_decision_use'; pass=$true}
    return_to_parent_proof=[pscustomObject]@{target=$a.return_to_parent; pass=$true}
    source_anchor=$a.source_batch_path
    duplicate_key=$a.duplicate_key
    rollback_path='restore_additive_ready_lane_active_promotion_snapshot'
  }
}
$merged=@($oldAtoms)+@($incomingActive)
$topicDup=@($merged|Group-Object topic|Where-Object{$_.Count -gt 1}|ForEach-Object{$_.Name})
$keyDup=@($merged|Group-Object duplicate_key|Where-Object{$_.Count -gt 1}|ForEach-Object{$_.Name})
$idDup=@($merged|Group-Object atom_id|Where-Object{$_.Count -gt 1}|ForEach-Object{$_.Name})
if($topicDup.Count -gt 0 -or $keyDup.Count -gt 0 -or $idDup.Count -gt 0){ throw "MERGED_DUPLICATES topic=$($topicDup.Count) key=$($keyDup.Count) id=$($idDup.Count)" }
$readyHash=(Get-FileHash $ReadyLanePath -Algorithm SHA256).Hash.ToLower()
$cp=[pscustomObject]@{schema='codex_curriculum_additive_active_checkpoint_v1'; status='PASS_CODEX_CURRICULUM_READY_LANE_ADDITIVE_ACTIVE_PROMOTION_V1'; runtime_ready=$false; previous_atom_count=$oldAtoms.Count; incoming_ready_atom_count=$incomingActive.Count; digested_atom_candidate_count=$merged.Count; behavior_use_pass_count=$merged.Count; return_to_parent_pass_count=$merged.Count; directed_count=@($merged|Where-Object{$_.source_mode -eq 'directed_curriculum'}).Count; experience_count=@($merged|Where-Object{$_.source_mode -eq 'experience_curriculum'}).Count; ready_lane_path=$ReadyLanePath; ready_lane_sha256=$readyHash; accepted_core_promotion=$false; boundary='Additive ready-lane active repo-body checkpoint. Not live and not D2B accepted-core.'; atoms=@($merged); rejected=@()}
WriteJson $checkpointPath $cp 100
foreach($p in @('reports/self_development/SELF_MODEL_ACTIVE_MAP.json','reports/self_development/accepted_change_memory_snapshot.json','packs/registry.json')){
  $o=ReadJson $p
  SetOrAdd $o 'active_codex_curriculum_digest_status' 'ACTIVE_REPO_BODY_DECISION_SOURCE'
  SetOrAdd $o 'active_codex_curriculum_digest_checkpoint_path' $checkpointPath
  SetOrAdd $o 'active_codex_curriculum_digest_atom_count' $merged.Count
  SetOrAdd $o 'active_codex_curriculum_digest_promotion_id' $promotionId
  SetOrAdd $o 'active_codex_curriculum_digest_boundary' 'additive repo-body active decision source only; not live and not D2B accepted-core'
  WriteJson $p $o 80
}
$after=@{}; foreach($p in $protected){ if(Test-Path $p){ $after[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower() } }
$manifest=[pscustomObject]@{schema='ready_lane_additive_active_promotion_rollback_manifest_v1'; promotion_id=$promotionId; created_at=(Get-Date).ToString('o'); ready_lane_path=$ReadyLanePath; previous_atom_count=$oldAtoms.Count; incoming_atom_count=$incomingActive.Count; merged_atom_count=$merged.Count; protected_files=@($protected); backup_map=$backupMap; before_sha256=$before; after_sha256=$after; rollback_dir=$rollbackDir; checkpoint_path=$checkpointPath; boundary='Immutable rollback snapshot for additive ready-lane active promotion.'}
WriteJson "$rollbackDir/promotion_manifest.json" $manifest 80
$report=[pscustomObject]@{schema='codex_curriculum_additive_active_promotion_manifest_v1'; promotion_id=$promotionId; status='ACTIVE_REPO_BODY_DECISION_SOURCE'; runtime_ready=$false; checkpoint_path=$checkpointPath; previous_atom_count=$oldAtoms.Count; incoming_atom_count=$incomingActive.Count; atom_count=$merged.Count; protected_files=@($protected); before_sha256=$before; after_sha256=$after; rollback_dir=$rollbackDir; accepted_core_promotion=$false; live_promotion=$false; source='READY_LANE_ADDITIVE_MERGE'; boundary='Adds ready-lane atoms into repo-body active decision source only.'}
WriteJson 'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.json' $report 80
WriteJson 'operations/reports/CODEX_CURRICULUM_READY_LANE_ADDITIVE_ACTIVE_PROMOTION_V1.json' $report 80
$md=@('# CODEX_CURRICULUM_READY_LANE_ADDITIVE_ACTIVE_PROMOTION_V1','',"Status: ACTIVE_REPO_BODY_DECISION_SOURCE",'Runtime ready: false','',"Promotion id: $promotionId","Previous atoms: $($oldAtoms.Count)","Incoming atoms: $($incomingActive.Count)","Merged atoms: $($merged.Count)","Rollback dir: $rollbackDir",'', 'Boundary: additive repo-body active only; not live and not D2B accepted-core.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_ACTIVE_PROMOTION_V1.md'),($md -join "`r`n"),$utf8)
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_READY_LANE_ADDITIVE_ACTIVE_PROMOTION_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "ADDITIVE_PROMOTION_STATUS=ACTIVE_REPO_BODY_DECISION_SOURCE"
Write-Host "PROMOTION_ID=$promotionId"
Write-Host "PREVIOUS_ATOMS=$($oldAtoms.Count)"
Write-Host "INCOMING_ATOMS=$($incomingActive.Count)"
Write-Host "MERGED_ATOMS=$($merged.Count)"
Write-Host "ROLLBACK_DIR=$rollbackDir"
Write-Host "RUNTIME_READY=false"