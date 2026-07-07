param(
  [string]$ScoringPath='reports/self_development/BUILDER_MISSION_SCORING_V1.json',
  [string]$OutputPath='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
)
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
if(-not(Test-Path $ScoringPath)){
  & powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_builder_mission_scoring_v1.ps1 -OutputPath $ScoringPath | Out-Host
}
$scoring=Get-Content $ScoringPath -Raw|ConvertFrom-Json
$identity=Get-Content 'self_model/BUILDER_IDENTITY_CONTRACT_V1.json' -Raw|ConvertFrom-Json
$gapMap=Get-Content 'reports/self_development/BUILDER_GAP_MAP_V1.json' -Raw|ConvertFrom-Json
$evidence=Get-Content $scoring.evidence_inventory_path -Raw|ConvertFrom-Json
$ranked=@($scoring.ranked_candidates)
if($ranked.Count -lt 1){ throw 'NO_RANKED_CANDIDATES' }
$selected=$ranked[0]
$gap=@($gapMap.gaps|Where-Object{$_.id -eq $selected.selected_gap}|Select-Object -First 1)[0]
$used=@($selected.source_refs_used)
$rejected=@($selected.source_refs_rejected)
# Add standard rejections from V4 doctrine if missing.
foreach($r in @('latest_signal_as_authority','school_as_required_brain','agentlife_residue_as_direction','child_agent_jump_before_self_build_selector_proven')){
  if($rejected -notcontains $r){ $rejected += $r }
}
$sourceHealth=@()
foreach($srcId in @($used)){
  $src=@($evidence.sources|Where-Object{$_.id -eq $srcId}|Select-Object -First 1)
  if($src.Count -gt 0){ $sourceHealth += [ordered]@{id=[string]$src[0].id;health=[string]$src[0].health;authority=[string]$src[0].authority;can_command=[bool]$src[0].can_command} }
}
$selection=[ordered]@{
  schema='source_agnostic_path_selection_v1'
  status='SOURCE_AGNOSTIC_PATH_SELECTED_LAB'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  scoring_report_path=$ScoringPath
  selected_next_action=[string]$selected.selected_next_action
  selected_candidate_id=[string]$selected.id
  selected_score=[int]$selected.score
  selected_rank=1
  identity_alignment='primary_mission:build_repair_verify_and_improve_self; secondary_mission:child_agents_after_self_build_selector_proven'
  selected_gap=[string]$selected.selected_gap
  selected_gap_severity=if($gap){[string]$gap.severity}else{'UNKNOWN'}
  selected_gap_reason=if($gap){[string]$gap.reason}else{'UNKNOWN'}
  proof_needed=@($selected.proof_needed)
  validator_needed=@($selected.validator_needed)
  source_refs_used=@($used)
  source_refs_used_health=@($sourceHealth)
  source_refs_rejected=@($rejected)
  why_not_latest_signal=[string]$selected.why_not_latest_signal
  why_not_school_dependency='School is optional evidence; selection is driven by identity, gap severity, proof path, and dependency reduction.'
  why_not_child_agent_jump='Child-agent factory is secondary until source-agnostic self-build selector is proven.'
  fallback_if_source_missing=[string]$selected.fallback_if_source_missing
  selection_rule='choose_highest_scored_candidate_from_builder_mission_scoring; require identity_alignment_gap_proof_validator_source_trace; no live/AIMO integration in PHASE_H'
  selection_basis=[ordered]@{
    identity_first=($identity.primary_mission -eq 'build_repair_verify_and_improve_self')
    scoring_top_candidate=[string]$scoring.top_candidate_id
    scoring_top_score=[int]$scoring.top_candidate_score
    candidate_depends_on_school=[bool]$selected.depends_on_school
    latest_signal_is_authority=$false
    school_is_required=$false
    child_agent_factory_selected=($selected.id -like '*child_agent*')
  }
  next_phase='PHASE_I_AIMO_INTEGRATION_BEHIND_LAB_GATE'
  lab_only=$true
  aimo_integration_performed=$false
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
New-Item -ItemType Directory -Force -Path (Split-Path $OutputPath -Parent)|Out-Null
$selection|ConvertTo-Json -Depth 100|Set-Content $OutputPath -Encoding UTF8
Write-Host 'EXPORT_STATUS=SOURCE_AGNOSTIC_PATH_SELECTED_LAB'
Write-Host ('OUTPUT_PATH='+$OutputPath)
Write-Host ('SELECTED='+$selection.selected_candidate_id)
Write-Host ('ACTION='+$selection.selected_next_action)
Write-Host ('SCORE='+$selection.selected_score)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
