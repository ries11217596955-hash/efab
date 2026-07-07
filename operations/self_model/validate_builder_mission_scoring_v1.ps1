$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$export='operations/self_model/export_builder_mission_scoring_v1.ps1'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export | Out-Host
$path='reports/self_development/BUILDER_MISSION_SCORING_V1.json'
Assert (Test-Path $path) 'SCORING_REPORT_MISSING'
$j=Get-Content $path -Raw|ConvertFrom-Json
Assert ($j.schema -eq 'builder_mission_scoring_v1') 'SCHEMA_BAD'
Assert ($j.scoring_performed -eq $true) 'SCORING_NOT_PERFORMED'
Assert ($j.selection_not_performed -eq $true) 'SELECTION_SCOPE_BAD'
Assert ($null -eq $j.selected_candidate) 'SELECTED_CANDIDATE_SHOULD_BE_NULL'
$c=@($j.ranked_candidates)
Assert ($c.Count -ge 7) 'TOO_FEW_SCORED_CANDIDATES'
foreach($row in $c){
  Assert ($row.PSObject.Properties['score']) "SCORE_MISSING:$($row.id)"
  Assert (@($row.score_rationale).Count -ge 3) "RATIONALE_TOO_SHORT:$($row.id)"
  Assert (@($row.proof_needed).Count -ge 1) "PROOF_NEEDED_MISSING:$($row.id)"
  Assert (@($row.validator_needed).Count -ge 1) "VALIDATOR_NEEDED_MISSING:$($row.id)"
  Assert ($row.depends_on_school -eq $false) "SCORED_CANDIDATE_DEPENDS_ON_SCHOOL:$($row.id)"
}
$top=$c|Select-Object -First 1
Assert ($top.id -eq 'build_source_agnostic_path_selector_v1') 'TOP_CANDIDATE_NOT_SOURCE_AGNOSTIC_SELECTOR'
Assert ($top.selected_gap -eq 'source_agnostic_path_selector_missing') 'TOP_GAP_BAD'
Assert (@($top.score_rationale) -contains 'reduces_source_dependency') 'TOP_RATIONALE_DEPENDENCY_REDUCTION_MISSING'
$child=$c|Where-Object{$_.id -eq 'defer_child_agent_factory_until_self_build_selector_proven'}|Select-Object -First 1
Assert ($child.score -lt $top.score) 'CHILD_AGENT_DEFER_SHOULD_NOT_OUTSCORE_SELF_BUILD'
Assert (@($child.score_rationale) -contains 'secondary_child_agent_work_deferred_penalty') 'CHILD_AGENT_PENALTY_MISSING'
$latestReject=$c|Where-Object{$_.id -eq 'add_latest_signal_overfit_negative_tests_v1'}|Select-Object -First 1
Assert ($latestReject.why_not_latest_signal -like '*Latest signal*' -or $latestReject.why_not_latest_signal -like '*Latest or single source*') 'LATEST_REJECTION_REASON_MISSING'
Assert ($j.live_process_touched -eq $false -and $j.active_memory_mutated -eq $false) 'MUTATION_FLAGS_BAD'
# Negative candidate set: a fake latest-signal-following candidate must lose due to latest_signal_authority and school dependency penalties.
$fakeCandidatePath='reports/self_development/CANDIDATE_ACTION_SET_V1_FAKE_LATEST_SIGNAL_TEST.json'
$base=Get-Content 'reports/self_development/CANDIDATE_ACTION_SET_V1.json' -Raw|ConvertFrom-Json
$fake=New-Object PSObject
$fake|Add-Member -NotePropertyName id -NotePropertyValue 'follow_latest_school_packet_without_gap_v1'
$fake|Add-Member -NotePropertyName selected_next_action -NotePropertyValue 'follow_latest_school_packet_without_gap_v1'
$fake|Add-Member -NotePropertyName candidate_kind -NotePropertyValue 'latest_signal_follow'
$fake|Add-Member -NotePropertyName identity_alignment -NotePropertyValue 'weak:latest_signal_over_identity'
$fake|Add-Member -NotePropertyName selected_gap -NotePropertyValue 'unknown_latest_signal_gap'
$fake|Add-Member -NotePropertyName mission_relevance -NotePropertyValue 'secondary_child_agent_future'
$fake|Add-Member -NotePropertyName reason -NotePropertyValue 'Fake negative candidate that follows latest School packet without known Builder gap.'
$fake|Add-Member -NotePropertyName proof_needed -NotePropertyValue ([string[]]@('fake proof'))
$fake|Add-Member -NotePropertyName validator_needed -NotePropertyValue ([string[]]@('fake validator'))
$fake|Add-Member -NotePropertyName source_refs_used -NotePropertyValue ([string[]]@('latest_runtime_packets_as_authority','school_optional_source'))
$fake|Add-Member -NotePropertyName source_refs_rejected -NotePropertyValue ([string[]]@())
$fake|Add-Member -NotePropertyName why_not_latest_signal -NotePropertyValue ''
$fake|Add-Member -NotePropertyName fallback_if_source_missing -NotePropertyValue ''
$fake|Add-Member -NotePropertyName depends_on_school -NotePropertyValue $true
$fake|Add-Member -NotePropertyName status -NotePropertyValue 'CANDIDATE_READY_FOR_SCORING'
$base.candidates=@($base.candidates)+$fake
$base.candidate_count=@($base.candidates).Count
$base|ConvertTo-Json -Depth 100|Set-Content $fakeCandidatePath -Encoding UTF8
$fakeScorePath='reports/self_development/BUILDER_MISSION_SCORING_V1_FAKE_LATEST_SIGNAL_TEST.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $export -CandidatePath $fakeCandidatePath -OutputPath $fakeScorePath | Out-Host
$f=Get-Content $fakeScorePath -Raw|ConvertFrom-Json
$fakeRow=@($f.ranked_candidates|Where-Object{$_.id -eq 'follow_latest_school_packet_without_gap_v1'}|Select-Object -First 1)[0]
$fTop=@($f.ranked_candidates|Select-Object -First 1)[0]
Assert ($fTop.id -eq 'build_source_agnostic_path_selector_v1') 'FAKE_LATEST_SIGNAL_BECAME_TOP_BAD'
Assert ($fakeRow.score -lt $fTop.score) 'FAKE_LATEST_SIGNAL_NOT_PENALIZED'
Assert (@($fakeRow.score_rationale) -contains 'school_dependency_penalty') 'FAKE_SCHOOL_PENALTY_MISSING'
Assert (@($fakeRow.score_rationale) -contains 'latest_signal_authority_penalty') 'FAKE_LATEST_PENALTY_MISSING'
$proof=[ordered]@{
  schema='builder_mission_scoring_validation_v1'
  status='PASS_BUILDER_MISSION_SCORING_V1'
  scoring_report_path=$path
  fake_latest_signal_test_path=$fakeScorePath
  live_process_touched=$false
  active_memory_mutated=$false
  tests=@(
    [ordered]@{name='scores_all_candidates_without_selection';status='PASS'},
    [ordered]@{name='source_agnostic_selector_scores_top';status='PASS'},
    [ordered]@{name='child_agent_jump_penalized_until_self_build_proven';status='PASS'},
    [ordered]@{name='school_dependency_and_latest_signal_authority_penalized';status='PASS'},
    [ordered]@{name='scoring_does_not_touch_live_or_active_memory';status='PASS'}
  )
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_model/BUILDER_MISSION_SCORING_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_BUILDER_MISSION_SCORING_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'
