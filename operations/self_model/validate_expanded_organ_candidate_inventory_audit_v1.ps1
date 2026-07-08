$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1.json'
$docPath='docs/operations/EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1.md'
foreach($p in @($reportPath,$docPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
Assert ($r.schema -eq 'expanded_organ_candidate_inventory_audit_v1') 'SCHEMA_BAD'
Assert ($r.status -eq 'PASS_EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1_REFINED') 'STATUS_BAD'
Assert ($r.summary.registered_body_map_organs -eq 7) 'EXPECTED_7_REGISTERED_BODY_ORGANS_NOT_CONFIRMED'
Assert ($r.summary.selected_candidates -gt 7) 'NO_EXPANDED_CANDIDATES_FOUND'
Assert (($r.summary.unregistered_strong + $r.summary.unregistered_weak) -gt 0) 'NO_UNREGISTERED_CANDIDATES_FOUND'
Assert ($r.interpretation.body_map_is_incomplete_for_full_organ_inventory -eq $true) 'BODY_MAP_INCOMPLETE_FLAG_BAD'
Assert ($r.interpretation.raw_candidate_scan_is_noisy -eq $true) 'NOISY_SCAN_FLAG_MISSING'
Assert ($r.interpretation.passport_generator_blocked_until_expanded_inventory_triage -eq $true) 'GENERATOR_BLOCK_FLAG_BAD'
Assert ($r.recommended_next_step -eq 'ORGAN_INVENTORY_TRIAGE_V1_CLASSIFY_CANDIDATES_BEFORE_PASSPORT_DRAFT_GENERATOR') 'NEXT_STEP_BAD'
foreach($c in @($r.selected_candidates)){ Assert ($c.classification -ne 'REFERENCE_OR_MATERIAL_SURFACE') 'REFERENCE_SURFACE_SELECTED_BAD' }
# Candidate audit does not require all registered body-map organs to be selected; it uses the source passport coverage audit as authoritative registered count.
$sourceAudit=Get-Content $r.source_body_passport_audit -Raw|ConvertFrom-Json
Assert ($sourceAudit.summary.total_organs -eq 7) 'SOURCE_AUDIT_ORGAN_COUNT_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_GATE_BAD'
$proof=[ordered]@{
  schema='expanded_organ_candidate_inventory_audit_validation_v1'
  status='PASS_EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1_REFINED'
  report_path=$reportPath
  registered_body_map_organs=[int]$r.summary.registered_body_map_organs
  selected_candidates=[int]$r.summary.selected_candidates
  registered_entries=[int]$r.summary.registered_body_map_organ_entries
  inside_registered_entries=[int]$r.summary.inside_registered_organ_entries
  container_or_registry_entries=[int]$r.summary.container_or_registry_entries
  unregistered_strong=[int]$r.summary.unregistered_strong
  unregistered_weak=[int]$r.summary.unregistered_weak
  seven_is_suspicious_confirmed=$true
  refined_scan_still_needs_triage=$true
  passport_generator_blocked_until_triage=$true
  deletion_allowed=$false
  body_map_mutation_allowed=$false
  best_next_move=[string]$r.recommended_next_step
  live_pid_now=[int]$liveNow[0].ProcessId
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1_REFINED'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
