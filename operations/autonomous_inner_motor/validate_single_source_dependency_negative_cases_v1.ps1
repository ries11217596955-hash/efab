$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Clone-JsonObject($Obj){ return ($Obj | ConvertTo-Json -Depth 100 | ConvertFrom-Json) }
function Set-SourceHealth($Inventory,[string]$SourceId,[string]$Health){
  foreach($s in @($Inventory.sources)){
    if([string]$s.id -eq $SourceId){
      $s.health=$Health
      $s.can_suggest=($Health -notin @('MISSING','STALE','FAILED'))
      $s.required_for_selection=$false
    }
  }
}
function Add-AgentLifePacket($Inventory,[string]$CaseId,[string]$Topic,[string]$Health){
  foreach($s in @($Inventory.sources)){
    if([string]$s.id -eq 'latest_runtime_packets'){
      $s.health=$Health
      $s.can_suggest=($Health -notin @('MISSING','STALE','FAILED'))
      $s.authority='freshness_modifier_only'
      $s.required_for_selection=$false
    }
  }
  $packet=[ordered]@{
    path="synthetic://$CaseId/agentlife_residue.json"
    name="AgentLife_${CaseId}_residue.json"
    last_write_time=(Get-Date).ToString('o')
    source_kind='AgentLife'
    source_id=$CaseId
    topic=$Topic
    next_action_candidate=$Topic
    specific_gap='synthetic_agentlife_residue_should_not_command_selection'
  }
  $Inventory.latest_runtime_packets=@($packet)
}
function Invoke-Case([string]$CaseId,[scriptblock]$Mutator){
  $basePath='reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1.json'
  if(-not(Test-Path $basePath)){
    powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_source_evidence_inventory_v1.ps1 | Out-Host
  }
  $inv=Clone-JsonObject (Get-Content $basePath -Raw|ConvertFrom-Json)
  & $Mutator $inv
  $inv.simulation|Add-Member -NotePropertyName phase_j_case -NotePropertyValue $CaseId -Force
  $evidencePath="reports/self_development/SOURCE_EVIDENCE_INVENTORY_V1_PHASE_J_${CaseId}.json"
  $candidatePath="reports/self_development/CANDIDATE_ACTION_SET_V1_PHASE_J_${CaseId}.json"
  $scoringPath="reports/self_development/BUILDER_MISSION_SCORING_V1_PHASE_J_${CaseId}.json"
  $selectionPath="reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1_PHASE_J_${CaseId}.json"
  $inv|ConvertTo-Json -Depth 100|Set-Content $evidencePath -Encoding UTF8
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_candidate_action_set_v1.ps1 -EvidencePath $evidencePath -OutputPath $candidatePath | Out-Host
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_builder_mission_scoring_v1.ps1 -CandidatePath $candidatePath -OutputPath $scoringPath | Out-Host
  powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_source_agnostic_path_selection_v1.ps1 -ScoringPath $scoringPath -OutputPath $selectionPath | Out-Host
  $selection=Get-Content $selectionPath -Raw|ConvertFrom-Json
  Assert ($selection.selected_candidate_id -eq 'build_source_agnostic_path_selector_v1') ("CASE_SELECTED_BAD:{0}:{1}" -f $CaseId,$selection.selected_candidate_id)
  Assert ($selection.selected_gap -eq 'source_agnostic_path_selector_missing') ("CASE_GAP_BAD:{0}:{1}" -f $CaseId,$selection.selected_gap)
  Assert ($selection.selection_basis.school_is_required -eq $false) ("CASE_SCHOOL_REQUIRED_BAD:{0}" -f $CaseId)
  Assert ($selection.selection_basis.candidate_depends_on_school -eq $false) ("CASE_DEPENDS_ON_SCHOOL_BAD:{0}" -f $CaseId)
  Assert ($selection.selection_basis.latest_signal_is_authority -eq $false) ("CASE_LATEST_AUTHORITY_BAD:{0}" -f $CaseId)
  Assert (@($selection.source_refs_rejected) -contains 'school_as_required_brain') ("CASE_REJECTS_SCHOOL_MISSING:{0}" -f $CaseId)
  Assert (@($selection.source_refs_rejected) -contains 'latest_signal_as_authority') ("CASE_REJECTS_LATEST_MISSING:{0}" -f $CaseId)
  Assert (@($selection.source_refs_rejected) -contains 'agentlife_residue_as_direction') ("CASE_REJECTS_AGENTLIFE_MISSING:{0}" -f $CaseId)
  return [ordered]@{
    case_id=$CaseId
    status='PASS'
    evidence_path=$evidencePath
    candidate_path=$candidatePath
    scoring_path=$scoringPath
    selection_path=$selectionPath
    selected_candidate_id=[string]$selection.selected_candidate_id
    selected_next_action=[string]$selection.selected_next_action
    selected_gap=[string]$selection.selected_gap
    selected_score=[int]$selection.selected_score
    school_required=[bool]$selection.selection_basis.school_is_required
    latest_signal_is_authority=[bool]$selection.selection_basis.latest_signal_is_authority
    candidate_depends_on_school=[bool]$selection.selection_basis.candidate_depends_on_school
  }
}
# Load AIMO selector function and prove the lab gate can consume a variant selection file too.
$aimoScript='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $aimoScript),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) "FUNCTION_MISSING:$name"
  Invoke-Expression $func.Extent.Text
}
$cases=@()
$cases += Invoke-Case 'school_missing_runtime_missing' { param($i) Set-SourceHealth $i 'school_optional_source' 'MISSING'; Set-SourceHealth $i 'latest_runtime_packets' 'MISSING'; $i.latest_runtime_packets=@() }
$cases += Invoke-Case 'school_stale_runtime_missing' { param($i) Set-SourceHealth $i 'school_optional_source' 'STALE'; Set-SourceHealth $i 'latest_runtime_packets' 'MISSING'; $i.latest_runtime_packets=@() }
$cases += Invoke-Case 'school_failed_runtime_missing' { param($i) Set-SourceHealth $i 'school_optional_source' 'FAILED'; Set-SourceHealth $i 'latest_runtime_packets' 'MISSING'; $i.latest_runtime_packets=@() }
$cases += Invoke-Case 'fresh_agentlife_residue' { param($i) Set-SourceHealth $i 'school_optional_source' 'AVAILABLE'; Add-AgentLifePacket $i 'fresh_agentlife_residue' 'inspect_understand_own_policy_and_return_one_bounded_next_action_candidate' 'AVAILABLE' }
$cases += Invoke-Case 'stale_agentlife_residue' { param($i) Set-SourceHealth $i 'school_optional_source' 'AVAILABLE'; Add-AgentLifePacket $i 'stale_agentlife_residue' 'follow_growth_signal_follow_growth_signal_follow_gr' 'STALE' }
$cases += Invoke-Case 'all_optional_sources_missing' { param($i) foreach($id in @('school_optional_source','latest_runtime_packets','episodic_memory_proofs','reasoning_episode_proofs')){ Set-SourceHealth $i $id 'MISSING' }; $i.latest_runtime_packets=@() }
# Direct AIMO lab-gate variant test using all_optional_sources_missing selection.
$variantSelection=(@($cases)|Where-Object{$_.case_id -eq 'all_optional_sources_missing'}|Select-Object -First 1).selection_path
$tasks=@([ordered]@{name='choose_next_safe_growth_step';query='baseline';target='policy.json'})
$prev=[pscustomobject]@{available=$true;run_id='old';cells_sha256='OLD'}
$curr=[pscustomobject]@{available=$true;run_id='new';cells_sha256='NEW'}
$noGrowth=[pscustomobject]@{available=$false;topics=@();focus_boosts=@()}
$aimoSelection=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev -UseSourceAgnosticPathSelectionLabGate -SourceAgnosticPathSelectionPath $variantSelection
Assert ($aimoSelection.reason -eq 'SOURCE_AGNOSTIC_PATH_SELECTION_LAB_GATE') 'AIMO_VARIANT_GATE_REASON_BAD'
Assert ($aimoSelection.task.name -eq 'build_source_agnostic_path_selector_v1') 'AIMO_VARIANT_TASK_BAD'
Assert (@($aimoSelection.source_refs_rejected) -contains 'school_as_required_brain') 'AIMO_VARIANT_REJECTS_SCHOOL_MISSING'
Assert (@($aimoSelection.source_refs_rejected) -contains 'agentlife_residue_as_direction') 'AIMO_VARIANT_REJECTS_AGENTLIFE_MISSING'
$report=[ordered]@{
  schema='single_source_dependency_negative_cases_v1'
  status='PASS_SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  cases=@($cases)
  aimo_lab_gate_variant=[ordered]@{status='PASS';variant_selection_path=$variantSelection;reason=$aimoSelection.reason;selected_task=$aimoSelection.task.name;selected_gap=$aimoSelection.specific_gap}
  acceptance='School, AgentLife, latest runtime packets, and optional memories are not required for source-agnostic self-build selection.'
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$reportPath='reports/self_development/SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1.json'
$report|ConvertTo-Json -Depth 100|Set-Content $reportPath -Encoding UTF8
$proof=[ordered]@{
  schema='single_source_dependency_negative_cases_validation_v1'
  status='PASS_SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1'
  report_path=$reportPath
  case_count=@($cases).Count
  case_ids=@($cases|ForEach-Object{$_.case_id})
  live_process_touched=$false
  active_memory_mutated=$false
  tests=@(
    [ordered]@{name='school_missing_runtime_missing_non_blocking';status='PASS'},
    [ordered]@{name='school_stale_non_blocking';status='PASS'},
    [ordered]@{name='school_failed_non_blocking';status='PASS'},
    [ordered]@{name='fresh_agentlife_residue_not_authority';status='PASS'},
    [ordered]@{name='stale_agentlife_residue_not_authority';status='PASS'},
    [ordered]@{name='all_optional_sources_missing_still_self_builds';status='PASS'},
    [ordered]@{name='aimo_lab_gate_consumes_missing_optional_sources_variant';status='PASS'}
  )
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/autonomous_inner_motor/SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 100|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'

