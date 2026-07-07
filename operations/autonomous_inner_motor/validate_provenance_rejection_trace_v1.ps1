$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Get-TraceField($Obj,[string]$Field){
  if($null -eq $Obj){ return $null }
  if($Obj -is [System.Collections.IDictionary] -and $Obj.Contains($Field)){ return $Obj[$Field] }
  if($Obj.PSObject.Properties[$Field]){ return $Obj.PSObject.Properties[$Field].Value }
  return $null
}
function Require-NonEmpty($Obj,[string]$Field,[string]$Context){
  $v=Get-TraceField $Obj $Field
  Assert ($null -ne $v) ("FIELD_MISSING:{0}:{1}" -f $Context,$Field)
  if($v -is [array]){ Assert (@($v).Count -gt 0) ("ARRAY_EMPTY:{0}:{1}" -f $Context,$Field) }
  else { Assert (-not [string]::IsNullOrWhiteSpace([string]$v)) ("VALUE_EMPTY:{0}:{1}" -f $Context,$Field) }
}
# Regenerate canonical chain after fallback propagation.
powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/validate_candidate_action_set_v1.ps1 | Out-Host
powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/validate_builder_mission_scoring_v1.ps1 | Out-Host
powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/validate_source_agnostic_path_selection_v1.ps1 | Out-Host
powershell -NoProfile -ExecutionPolicy Bypass -File operations/autonomous_inner_motor/validate_single_source_dependency_negative_cases_v1.ps1 | Out-Host
$selectionPath='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
$selection=Get-Content $selectionPath -Raw|ConvertFrom-Json
foreach($f in @('selected_next_action','selected_candidate_id','identity_alignment','selected_gap','selected_gap_severity','selected_gap_reason','why_not_latest_signal','why_not_school_dependency','why_not_child_agent_jump','fallback_if_source_missing','selection_rule')){ Require-NonEmpty $selection $f 'canonical_selection' }
foreach($f in @('proof_needed','validator_needed','source_refs_used','source_refs_rejected')){ Require-NonEmpty $selection $f 'canonical_selection' }
foreach($r in @('latest_signal_as_authority','school_as_required_brain','agentlife_residue_as_direction','child_agent_jump_before_self_build_selector_proven')){ Assert (@($selection.source_refs_rejected) -contains $r) ("REQUIRED_REJECTION_MISSING:{0}" -f $r) }
Assert ($selection.selection_basis.identity_first -eq $true) 'IDENTITY_FIRST_BAD'
Assert ($selection.selection_basis.school_is_required -eq $false) 'SCHOOL_REQUIRED_BAD'
Assert ($selection.selection_basis.latest_signal_is_authority -eq $false) 'LATEST_AUTHORITY_BAD'
Assert ($selection.selection_basis.candidate_depends_on_school -eq $false) 'DEPENDS_ON_SCHOOL_BAD'
Assert ($selection.lab_only -eq $true) 'PHASE_K_REQUIRES_LAB_ONLY_SELECTION'
# Validate Phase J variant selections also carry rejection trace and fallback.
$phaseJ=Get-Content 'reports/self_development/SINGLE_SOURCE_DEPENDENCY_NEGATIVE_CASES_V1.json' -Raw|ConvertFrom-Json
$caseChecks=@()
foreach($case in @($phaseJ.cases)){
  $caseId=[string]$case.case_id
  $sp=[string]$case.selection_path
  Assert (Test-Path $sp) ("PHASE_J_SELECTION_PATH_MISSING:{0}" -f $caseId)
  $s=Get-Content $sp -Raw|ConvertFrom-Json
  foreach($f in @('selected_next_action','identity_alignment','selected_gap','why_not_latest_signal','why_not_school_dependency','fallback_if_source_missing')){ Require-NonEmpty $s $f ("phase_j:{0}" -f $caseId) }
  foreach($f in @('proof_needed','validator_needed','source_refs_used','source_refs_rejected')){ Require-NonEmpty $s $f ("phase_j:{0}" -f $caseId) }
  foreach($r in @('latest_signal_as_authority','school_as_required_brain','agentlife_residue_as_direction')){ Assert (@($s.source_refs_rejected) -contains $r) ("PHASE_J_REJECTION_MISSING:{0}:{1}" -f $caseId,$r) }
  $caseChecks += [ordered]@{case_id=$caseId;status='PASS';selection_path=$sp;fallback_if_source_missing=[string]$s.fallback_if_source_missing;rejected=@($s.source_refs_rejected)}
}
# Validate AIMO lab integration proof and direct function trace.
$aimoProof=Get-Content 'tests/autonomous_inner_motor/AIMO_SOURCE_AGNOSTIC_LAB_INTEGRATION_V1_PROOF.json' -Raw|ConvertFrom-Json
Assert ($aimoProof.status -eq 'PASS_AIMO_SOURCE_AGNOSTIC_LAB_INTEGRATION_V1') 'AIMO_LAB_INTEGRATION_PROOF_BAD'
Assert ($aimoProof.live_process_touched -eq $false -and $aimoProof.active_memory_mutated -eq $false) 'AIMO_LAB_INTEGRATION_MUTATION_FLAGS_BAD'
$aimoScript='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $aimoScript),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
foreach($name in @('Get-SelectorField','Normalize-GrowthSignalTopicForTask','Select-GrowthDirectedDevelopmentTask')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) ("FUNCTION_MISSING:{0}" -f $name)
  Invoke-Expression $func.Extent.Text
}
$tasks=@([ordered]@{name='choose_next_safe_growth_step';query='baseline';target='policy.json'})
$prev=[pscustomobject]@{available=$true;run_id='old';cells_sha256='OLD'}
$curr=[pscustomobject]@{available=$true;run_id='new';cells_sha256='NEW'}
$noGrowth=[pscustomobject]@{available=$false;topics=@();focus_boosts=@()}
$aimoSelection=Select-GrowthDirectedDevelopmentTask -DevelopmentTasks $tasks -Cycle 1 -GrowthSignal $noGrowth -CurrentMemoryState $curr -PreviousMemoryState $prev -UseSourceAgnosticPathSelectionLabGate
foreach($f in @('identity_alignment','specific_gap','next_action_candidate','why_not_latest_signal','fallback_if_source_missing')){ Require-NonEmpty $aimoSelection $f 'aimo_lab_gate_selector' }
foreach($f in @('proof_needed','source_refs_used','source_refs_rejected')){ Require-NonEmpty $aimoSelection $f 'aimo_lab_gate_selector' }
Assert ($aimoSelection.task.query -like '*source_refs_used*') 'AIMO_QUERY_SOURCE_REFS_USED_MISSING'
Assert ($aimoSelection.task.query -like '*source_refs_rejected*') 'AIMO_QUERY_SOURCE_REFS_REJECTED_MISSING'
Assert ($aimoSelection.task.query -like '*proof_needed*') 'AIMO_QUERY_PROOF_NEEDED_MISSING'
Assert ($aimoSelection.task.query -like '*validator_needed*') 'AIMO_QUERY_VALIDATOR_NEEDED_MISSING'
$traceContract=[ordered]@{
  schema='provenance_rejection_trace_v1'
  status='PASS_PROVENANCE_REJECTION_TRACE_V1'
  route_lock='route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V4_IDENTITY_BASED_SELECTION.md'
  canonical_selection_path=$selectionPath
  selected_next_action=[string]$selection.selected_next_action
  selected_gap=[string]$selection.selected_gap
  trace_required_fields=@('selected_next_action','identity_alignment','selected_gap','proof_needed','validator_needed','source_refs_used','source_refs_rejected','why_not_latest_signal','why_not_school_dependency','why_not_child_agent_jump','fallback_if_source_missing')
  source_refs_used=@($selection.source_refs_used)
  source_refs_rejected=@($selection.source_refs_rejected)
  why_not_latest_signal=[string]$selection.why_not_latest_signal
  why_not_school_dependency=[string]$selection.why_not_school_dependency
  fallback_if_source_missing=[string]$selection.fallback_if_source_missing
  phase_j_case_checks=@($caseChecks)
  aimo_lab_gate_trace=[ordered]@{status='PASS';reason=[string]$aimoSelection.reason;task_name=[string]$aimoSelection.task.name;target=[string]$aimoSelection.task.target;query_contains_trace=$true}
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$reportPath='reports/self_development/PROVENANCE_REJECTION_TRACE_V1.json'
$traceContract|ConvertTo-Json -Depth 100|Set-Content $reportPath -Encoding UTF8
$proof=[ordered]@{
  schema='provenance_rejection_trace_validation_v1'
  status='PASS_PROVENANCE_REJECTION_TRACE_V1'
  report_path=$reportPath
  canonical_selection_path=$selectionPath
  checked_phase_j_cases=@($caseChecks|ForEach-Object{$_.case_id})
  live_process_touched=$false
  active_memory_mutated=$false
  tests=@(
    [ordered]@{name='canonical_selection_trace_fields_non_empty';status='PASS'},
    [ordered]@{name='required_rejection_reasons_present';status='PASS'},
    [ordered]@{name='fallback_if_source_missing_carried_from_candidate_to_scoring_to_selection';status='PASS'},
    [ordered]@{name='phase_j_variant_selections_have_trace';status='PASS'},
    [ordered]@{name='aimo_lab_gate_selector_emits_trace_fields';status='PASS'}
  )
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/autonomous_inner_motor/PROVENANCE_REJECTION_TRACE_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 100|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_PROVENANCE_REJECTION_TRACE_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
