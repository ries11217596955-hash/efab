param(
  [string]$CandidatePath='reports/self_development/CANDIDATE_ACTION_SET_V1.json',
  [string]$OutputPath='reports/self_development/BUILDER_MISSION_SCORING_V1.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
if(-not(Test-Path $CandidatePath)){
  & powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_candidate_action_set_v1.ps1 -OutputPath $CandidatePath | Out-Host
}
$candidateSet=Get-Content $CandidatePath -Raw|ConvertFrom-Json
$gapMap=Get-Content 'reports/self_development/BUILDER_GAP_MAP_V1.json' -Raw|ConvertFrom-Json
$evidence=Get-Content $candidateSet.evidence_inventory_path -Raw|ConvertFrom-Json
$gaps=@($gapMap.gaps)
function GapById([string]$Id){ return @($gaps|Where-Object{$_.id -eq $Id}|Select-Object -First 1)[0] }
function SeverityPoints([string]$Severity){ switch($Severity){ 'CRITICAL'{35}; 'HIGH'{25}; 'MEDIUM'{12}; default{5} } }
function MissionPoints([string]$Mission){ switch($Mission){ 'primary_self_build'{30}; 'secondary_child_agent_future'{5}; default{10} } }
function KindPoints([string]$Kind){ switch($Kind){ 'self_build_selector'{20}; 'self_build_scoring'{18}; 'aimo_lab_wiring'{15}; 'trace'{13}; 'validator'{12}; 'defer_secondary'{2}; default{5} } }
function BoolPenalty([bool]$Value,[int]$Penalty){ if($Value){ return -1*$Penalty }; return 0 }
$scored=@()
foreach($cand in @($candidateSet.candidates)){
  $gap=GapById ([string]$cand.selected_gap)
  $severity=if($gap){[string]$gap.severity}else{'UNKNOWN'}
  $mission=[string]$cand.mission_relevance
  $kind=[string]$cand.candidate_kind
  $proofCount=@($cand.proof_needed).Count
  $validatorCount=@($cand.validator_needed).Count
  $rejectCount=@($cand.source_refs_rejected).Count
  $usedCount=@($cand.source_refs_used).Count
  $sourceRisk=if($gap -and $gap.source_dependency_risk -eq $true){$true}else{$false}
  $childJump=($mission -eq 'secondary_child_agent_future' -or $kind -eq 'defer_secondary')
  $schoolPenalty=BoolPenalty ([bool]$cand.depends_on_school) 50
  $latestOverfitPenalty=0
  if(@($cand.source_refs_used) -contains 'latest_runtime_packets_as_authority'){ $latestOverfitPenalty=-40 }
  $base=0
  $base += SeverityPoints $severity
  $base += MissionPoints $mission
  $base += KindPoints $kind
  $base += [Math]::Min($proofCount,3)*4
  $base += [Math]::Min($validatorCount,3)*5
  $base += [Math]::Min($rejectCount,4)*2
  $base += [Math]::Min($usedCount,4)*1
  if($sourceRisk){ $base += 8 }
  if($childJump){ $base -= 25 }
  $base += $schoolPenalty
  $base += $latestOverfitPenalty
  $score=[int]$base
  $rationale=@()
  $rationale += "severity:$severity"
  $rationale += "mission:$mission"
  $rationale += "kind:$kind"
  $rationale += "proof_count:$proofCount"
  $rationale += "validator_count:$validatorCount"
  if($sourceRisk){$rationale+='reduces_source_dependency'}
  if($childJump){$rationale+='secondary_child_agent_work_deferred_penalty'}
  if([bool]$cand.depends_on_school){$rationale+='school_dependency_penalty'}
  if($latestOverfitPenalty -lt 0){$rationale+='latest_signal_authority_penalty'}
  $row=New-Object PSObject
  $row|Add-Member -NotePropertyName id -NotePropertyValue ([string]$cand.id)
  $row|Add-Member -NotePropertyName selected_next_action -NotePropertyValue ([string]$cand.selected_next_action)
  $row|Add-Member -NotePropertyName selected_gap -NotePropertyValue ([string]$cand.selected_gap)
  $row|Add-Member -NotePropertyName candidate_kind -NotePropertyValue $kind
  $row|Add-Member -NotePropertyName mission_relevance -NotePropertyValue $mission
  $row|Add-Member -NotePropertyName severity -NotePropertyValue $severity
  $row|Add-Member -NotePropertyName score -NotePropertyValue $score
  $row|Add-Member -NotePropertyName score_rationale -NotePropertyValue ([string[]]@($rationale))
  $row|Add-Member -NotePropertyName proof_needed -NotePropertyValue ([string[]]@($cand.proof_needed))
  $row|Add-Member -NotePropertyName validator_needed -NotePropertyValue ([string[]]@($cand.validator_needed))
  $row|Add-Member -NotePropertyName source_refs_used -NotePropertyValue ([string[]]@($cand.source_refs_used))
  $row|Add-Member -NotePropertyName source_refs_rejected -NotePropertyValue ([string[]]@($cand.source_refs_rejected))
  $row|Add-Member -NotePropertyName why_not_latest_signal -NotePropertyValue ([string]$cand.why_not_latest_signal)
  $row|Add-Member -NotePropertyName fallback_if_source_missing -NotePropertyValue ([string]$cand.fallback_if_source_missing)
  $row|Add-Member -NotePropertyName depends_on_school -NotePropertyValue ([bool]$cand.depends_on_school)
  $scored=@($scored)+$row
}
$ranked=@($scored|Sort-Object -Property @{Expression='score';Descending=$true},@{Expression='id';Descending=$false})
$scoreReport=[ordered]@{
  schema='builder_mission_scoring_v1'
  status='BUILDER_MISSION_SCORING_EXPORTED'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  candidate_set_path=$CandidatePath
  evidence_inventory_path=$candidateSet.evidence_inventory_path
  scoring_rule='score_candidates_by_builder_identity_gap_severity_mission_value_proof_validator_path_dependency_reduction_and_overfit_penalties'
  score_components=[ordered]@{
    severity='CRITICAL=35,HIGH=25,MEDIUM=12,default=5'
    mission='primary_self_build=30,secondary_child_agent_future=5,default=10'
    kind='self_build_selector=20,self_build_scoring=18,aimo_lab_wiring=15,trace=13,validator=12,defer_secondary=2'
    proof='up_to_3_items_x4'
    validator='up_to_3_items_x5'
    rejection_trace='up_to_4_items_x2'
    used_sources='up_to_4_items_x1'
    source_dependency_risk='plus_8_when_gap_closes_dependency_risk'
    child_agent_jump='minus_25_until_self_build_selector_proven'
    school_dependency='minus_50'
    latest_signal_authority='minus_40'
  }
  ranked_candidates=@($ranked)
  candidate_count=@($ranked).Count
  scoring_performed=$true
  selection_not_performed=$true
  selected_candidate=$null
  top_candidate_id=if($ranked.Count -gt 0){[string]$ranked[0].id}else{$null}
  top_candidate_score=if($ranked.Count -gt 0){[int]$ranked[0].score}else{$null}
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$scoreReport|ConvertTo-Json -Depth 100|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=BUILDER_MISSION_SCORING_EXPORTED'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host ('CANDIDATE_COUNT='+@($ranked).Count)
Write-Host ('TOP_CANDIDATE_ID='+$scoreReport.top_candidate_id)
Write-Host ('TOP_CANDIDATE_SCORE='+$scoreReport.top_candidate_score)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
