$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$export='operations/self_model/export_source_agnostic_path_selection_v1.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export | Out-Host
$path='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1.json'
Assert (Test-Path $path) 'SELECTION_REPORT_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'source_agnostic_path_selection_v1') 'SCHEMA_BAD'
Assert ($j.status -eq 'SOURCE_AGNOSTIC_PATH_SELECTED_LAB') 'STATUS_BAD'
Assert ($j.selected_candidate_id -eq 'build_source_agnostic_path_selector_v1') 'SELECTED_CANDIDATE_BAD'
Assert ($j.selected_next_action -eq 'build_source_agnostic_path_selector_v1') 'SELECTED_ACTION_BAD'
Assert ($j.selected_gap -eq 'source_agnostic_path_selector_missing') 'SELECTED_GAP_BAD'
Assert ($j.selected_gap_severity -eq 'CRITICAL') 'SELECTED_GAP_SEVERITY_BAD'
Assert ($j.identity_alignment -like 'primary_mission:build_repair_verify_and_improve_self*') 'IDENTITY_ALIGNMENT_BAD'
foreach($field in @('proof_needed','validator_needed','source_refs_used','source_refs_rejected')){ Assert (@($j.$field).Count -ge 1) "FIELD_EMPTY:$field" }
foreach($r in @('latest_signal_as_authority','school_as_required_brain','agentlife_residue_as_direction','child_agent_jump_before_self_build_selector_proven')){ Assert (@($j.source_refs_rejected) -contains $r) "REJECTION_MISSING:$r" }
Assert ($j.why_not_latest_signal -like '*Latest runtime packet*' -or $j.why_not_latest_signal -like '*Latest signal*') 'WHY_NOT_LATEST_BAD'
Assert ($j.why_not_school_dependency -like 'School is optional evidence*') 'WHY_NOT_SCHOOL_BAD'
Assert ($j.why_not_child_agent_jump -like 'Child-agent factory is secondary*') 'WHY_NOT_CHILD_AGENT_BAD'
Assert ($j.selection_basis.identity_first -eq $true) 'IDENTITY_FIRST_BAD'
Assert ($j.selection_basis.candidate_depends_on_school -eq $false) 'SELECTED_DEPENDS_ON_SCHOOL_BAD'
Assert ($j.selection_basis.latest_signal_is_authority -eq $false) 'LATEST_AUTHORITY_BAD'
Assert ($j.selection_basis.school_is_required -eq $false) 'SCHOOL_REQUIRED_BAD'
Assert ($j.selection_basis.child_agent_factory_selected -eq $false) 'CHILD_AGENT_SELECTED_BAD'
Assert ($j.lab_only -eq $true -and $j.aimo_integration_performed -eq $false) 'PHASE_H_SCOPE_BAD'
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'MUTATION_FLAGS_BAD'
# Negative: fake latest/school scoring report must still select source-agnostic selector.
$fakeScore='reports/self_development/BUILDER_MISSION_SCORING_V1_FAKE_LATEST_SIGNAL_TEST.json'
Assert (Test-Path $fakeScore) 'FAKE_SCORING_INPUT_MISSING'
$fakeOut='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1_FAKE_LATEST_SIGNAL_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export -ScoringPath $fakeScore -OutputPath $fakeOut | Out-Host
$f=Get-Content $fakeOut -Raw|ConvertFrom-Json
Assert ($f.selected_candidate_id -eq 'build_source_agnostic_path_selector_v1') 'FAKE_LATEST_SELECTION_BAD'
Assert ($f.selection_basis.latest_signal_is_authority -eq $false) 'FAKE_LATEST_AUTHORITY_BAD'
Assert ($f.selection_basis.school_is_required -eq $false) 'FAKE_SCHOOL_REQUIRED_BAD'
Assert (@($f.source_refs_rejected) -contains 'school_as_required_brain') 'FAKE_REJECTS_SCHOOL_MISSING'
# Negative: missing source candidate set scoring still selects self-build, not School-dependent.
$missingScore='reports/self_development/BUILDER_MISSION_SCORING_V1_MISSING_SOURCES_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/self_model/export_builder_mission_scoring_v1.ps1 -CandidatePath reports/self_development/CANDIDATE_ACTION_SET_V1_MISSING_SOURCES_TEST.json -OutputPath $missingScore | Out-Host
$missingOut='reports/self_development/SOURCE_AGNOSTIC_PATH_SELECTION_V1_MISSING_SOURCES_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export -ScoringPath $missingScore -OutputPath $missingOut | Out-Host
$m=Get-Content $missingOut -Raw|ConvertFrom-Json
Assert ($m.selected_candidate_id -eq 'build_source_agnostic_path_selector_v1') 'MISSING_SOURCES_SELECTION_BAD'
Assert ($m.selection_basis.school_is_required -eq $false) 'MISSING_SOURCES_SCHOOL_REQUIRED_BAD'
Assert ($m.selection_basis.candidate_depends_on_school -eq $false) 'MISSING_SOURCES_DEPENDS_ON_SCHOOL_BAD'
$proof=[ordered]@{
  schema='source_agnostic_path_selection_validation_v1'
  status='PASS_SOURCE_AGNOSTIC_PATH_SELECTION_V1'
  selection_report_path=$path
  fake_latest_signal_selection_path=$fakeOut
  missing_sources_selection_path=$missingOut
  live_process_touched=$false
  active_memory_mutated=$false
  tests=@(
    [ordered]@{name='selects_top_builder_mission_candidate';status='PASS'},
    [ordered]@{name='selection_contract_fields_present';status='PASS'},
    [ordered]@{name='rejects_latest_school_agentlife_child_jump_authority';status='PASS'},
    [ordered]@{name='fake_latest_school_candidate_does_not_win';status='PASS'},
    [ordered]@{name='missing_sources_still_selects_self_build';status='PASS'},
    [ordered]@{name='lab_only_no_aimo_or_live_touch';status='PASS'}
  )
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_model/SOURCE_AGNOSTIC_PATH_SELECTION_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_SOURCE_AGNOSTIC_PATH_SELECTION_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
