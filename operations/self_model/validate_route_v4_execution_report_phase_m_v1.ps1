$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$jsonPath='reports/self_development/AGENT_BUILDER_ROUTE_V4_EXECUTION_REPORT_PHASE_M.json'
$mdPath='docs/operations/AGENT_BUILDER_ROUTE_V4_EXECUTION_REPORT_PHASE_M.md'
Assert (Test-Path $jsonPath) 'ROUTE_EXECUTION_REPORT_JSON_MISSING'
Assert (Test-Path $mdPath) 'ROUTE_EXECUTION_REPORT_MD_MISSING'
$r=Get-Content $jsonPath -Raw|ConvertFrom-Json
Assert ($r.schema -eq 'agent_builder_route_v4_execution_report_phase_m_v1') 'SCHEMA_BAD'
Assert ($r.status -eq 'PASS_ROUTE_EXECUTION_REPORT_V1') 'STATUS_BAD'
foreach($ph in @('PHASE_A','PHASE_B','PHASE_C','PHASE_D','PHASE_E','PHASE_F','PHASE_G','PHASE_H','PHASE_I','PHASE_J','PHASE_K','PHASE_L','PHASE_M')){ Assert (@($r.phases_completed) -contains $ph) "PHASE_MISSING:$ph" }
Assert (@($r.phases_remaining_before_owner_review) -contains 'PHASE_N_OWNER_REVIEW_GATE') 'PHASE_N_GATE_MISSING'
Assert ($r.acceptance.does_not_claim_child_agent_readiness -eq $true) 'CHILD_AGENT_BOUNDARY_BAD'
Assert ($r.acceptance.owner_review_required_next -eq $true) 'OWNER_REVIEW_REQUIRED_BAD'
Assert ($r.live_state.live_aimo_count -eq 1) 'LIVE_AIMO_COUNT_BAD'
Assert ($r.live_state.live_gate_present -eq $true) 'LIVE_GATE_PRESENT_BAD'
Assert ($r.live_state.selected_task -eq 'build_source_agnostic_path_selector_v1') 'LIVE_SELECTED_TASK_BAD'
Assert ($r.live_state.selected_gap -eq 'source_agnostic_path_selector_missing') 'LIVE_SELECTED_GAP_BAD'
Assert ($r.live_state.stderr_size -eq 0) 'LIVE_STDERR_BAD'
Assert ($r.live_state.school_required -eq $false) 'SCHOOL_REQUIRED_BAD'
foreach($np in @('Ungated/default live AIMO path uses source-agnostic selector.','Child-agent factory readiness.','Child-agent production safety/maturity.')){ Assert (@($r.not_proven) -contains $np) "NOT_PROVEN_MISSING:$np" }
$expectedProofKeys=@('phase_a_route_lock','phase_b_identity','phase_c_snapshot','phase_d_gap_map','phase_e_source_inventory','phase_f_candidate_set','phase_g_scoring','phase_h_selection','phase_i_aimo_lab_gate','phase_j_dependency_negatives','phase_k_trace','phase_l_live_hotswap')
foreach($key in $expectedProofKeys){
  $prop=$r.proofs.PSObject.Properties[$key]
  Assert ($null -ne $prop) ("PROOF_KEY_MISSING:{0}" -f $key)
  Assert ([string]$prop.Value.status -notmatch 'MISSING|FAIL|BAD|UNREADABLE') ("PROOF_STATUS_BAD:{0}:{1}" -f $key,$prop.Value.status)
}
$md=Get-Content $mdPath -Raw
foreach($needle in @('PROVEN_LAB','PROVEN_LIVE','Remaining gaps / NOT_PROVEN','Do not claim child-agent readiness','PHASE_N_OWNER_REVIEW_GATE')){ Assert ($md -like "*$needle*") "MD_NEEDLE_MISSING:$needle" }
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_NOW_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -like '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_AIMO_NOW_GATE_MISSING'
$proof=[ordered]@{
  schema='route_v4_execution_report_phase_m_validation_v1'
  status='PASS_ROUTE_V4_EXECUTION_REPORT_PHASE_M_V1'
  report_json=$jsonPath
  report_md=$mdPath
  live_pid_now=[int]$liveNow[0].ProcessId
  owner_review_required_next=$true
  does_not_claim_child_agent_readiness=$true
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  tests=@(
    [ordered]@{name='all_completed_phases_listed';status='PASS'},
    [ordered]@{name='proof_refs_present_and_pass';status='PASS'},
    [ordered]@{name='live_state_matches_phase_l';status='PASS'},
    [ordered]@{name='not_proven_boundaries_present';status='PASS'},
    [ordered]@{name='owner_review_gate_next';status='PASS'}
  )
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/AGENT_BUILDER_ROUTE_V4_EXECUTION_REPORT_PHASE_M_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_ROUTE_V4_EXECUTION_REPORT_PHASE_M_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
