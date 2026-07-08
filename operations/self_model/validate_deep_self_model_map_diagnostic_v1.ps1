$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$diagJson='reports/self_development/DEEP_SELF_MODEL_MAP_DIAGNOSTIC_V1.json'
$diagMd='docs/operations/DEEP_SELF_MODEL_MAP_DIAGNOSTIC_V1.md'
Assert (Test-Path $diagJson) 'DIAGNOSTIC_JSON_MISSING'
Assert (Test-Path $diagMd) 'DIAGNOSTIC_MD_MISSING'
$r=Get-Content $diagJson -Raw|ConvertFrom-Json
Assert ($r.status -eq 'DIAGNOSTIC_COMPLETE_RECOMMEND_TWO_MAP_ORGANS_WITH_THIN_SELF_MODEL_LINK') 'STATUS_BAD'
Assert ($r.inventory_map_findings.status -eq 'EXISTS_AND_VALIDATED') 'INVENTORY_MAP_STATUS_BAD'
Assert ($r.capability_map_findings.status -eq 'EXISTS_AS_MATERIAL_STORE_NOT_MATURE_ORGAN') 'CAPABILITY_MAP_STATUS_BAD'
Assert ($r.capability_map_findings.task_json_count -gt 50) 'TASK_COUNT_TOO_LOW'
Assert ($r.capability_map_findings.has_inputs_count -eq 0) 'EXPECTED_INPUTS_GAP_NOT_PRESENT'
Assert ($r.capability_map_findings.has_outputs_count -eq 0) 'EXPECTED_OUTPUTS_GAP_NOT_PRESENT'
Assert ($r.design_decision.recommendation -eq 'DO_NOT_MERGE_INTO_ONE_BIG_ORGAN') 'DESIGN_DECISION_BAD'
Assert ($r.design_decision.preferred_architecture -eq 'TWO_MAP_ORGANS_PLUS_THIN_SELF_MODEL_LINK') 'ARCHITECTURE_DECISION_BAD'
Assert (@($r.gaps_to_fix_before_new_organs).gap -contains 'CAPABILITY_INVOCATION_MAP_NOT_CANONICAL') 'CAPABILITY_MAP_GAP_MISSING'
Assert (@($r.gaps_to_fix_before_new_organs).gap -contains 'ORGAN_TO_CAPABILITY_LINK_MISSING') 'ORGAN_LINK_GAP_MISSING'
Assert ($r.no_delete_policy -like 'No silent deletion*') 'NO_DELETE_POLICY_BAD'
Assert ($r.current_live.live_aimo_count -eq 1) 'LIVE_COUNT_BAD'
Assert ($r.current_live.has_gate -eq $false) 'LIVE_GATE_BAD'
Assert ($r.current_live.runtime_size_mb -lt 80) 'RUNTIME_SIZE_BAD'
foreach($p in @('reports/self_development/SELF_MODEL_ACTIVE_MAP.json','reports/self_development/agent_body_map.json','CAPABILITY_ROADMAP.json','tasks')){ Assert (Test-Path $p) ("EXPECTED_SURFACE_MISSING:{0}" -f $p) }
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_NOW_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_NOW_GATE_BAD'
$proof=[ordered]@{
  schema='deep_self_model_map_diagnostic_validation_v1'
  status='PASS_DEEP_SELF_MODEL_MAP_DIAGNOSTIC_V1'
  diagnostic_json=$diagJson
  diagnostic_md=$diagMd
  recommendation='TWO_MAP_ORGANS_PLUS_THIN_SELF_MODEL_LINK'
  best_next_move='CAPABILITY_INVOCATION_MAP_V1_CONTRACT'
  deletion_allowed=$false
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/DEEP_SELF_MODEL_MAP_DIAGNOSTIC_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_DEEP_SELF_MODEL_MAP_DIAGNOSTIC_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
