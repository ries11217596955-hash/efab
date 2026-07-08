$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/MAP_AUTHORITY_REPAIR_V1.json'
$docPath='docs/operations/MAP_AUTHORITY_REPAIR_V1.md'
$mapPath='reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
foreach($p in @($reportPath,$docPath,$mapPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$m=Get-Content $mapPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_MAP_AUTHORITY_REPAIR_V1_DYNAMIC_FULL_BODY_INVENTORY') 'REPORT_STATUS_BAD'
Assert (@($m.components).Count -gt 7) 'CANONICAL_MAP_STILL_ONLY_7'
Assert ([int]$m.component_authority_summary.required_components -eq 7) 'REQUIRED_COMPONENT_COUNT_BAD'
Assert ([int]$m.component_authority_summary.snapshot_imported -ge 3) 'SNAPSHOT_IMPORT_TOO_LOW'
Assert ([int]$m.component_authority_summary.expanded_candidates_imported -gt 0) 'EXPANDED_IMPORT_MISSING'
Assert ($m.component_authority_summary.legacy_maps_are_source_material_not_authority -eq $true) 'LEGACY_AUTHORITY_BAD'
Assert ($m.component_authority_summary.passport_generator_blocked_until_candidate_triage -eq $true) 'PASSPORT_BLOCK_MISSING'
$required=@($m.components|Where-Object{$_.is_required_component -eq $true})
Assert ($required.Count -eq 7) 'REQUIRED_MARKERS_BAD'
foreach($id in @('school','school_source_router','compact_memory_intake','autonomous_inner_motor','knowledge_acquisition_port','map_control','gpt_handoff')){Assert (@($required|ForEach-Object{$_.id}) -contains $id) ("REQUIRED_ID_MISSING:{0}" -f $id)}
$triage=@($m.components|Where-Object{$_.needs_triage -eq $true})
Assert ($triage.Count -gt 0) 'TRIAGE_CANDIDATES_MISSING'
Assert (@($triage|Where-Object{$_.authority_class -eq 'REPO_DISCOVERED_CANDIDATE_NEEDS_TRIAGE'}).Count -gt 0) 'REPO_CANDIDATES_MISSING'
Assert (@($triage|Where-Object{$_.authority_class -eq 'PARALLEL_SNAPSHOT_COMPONENT_NEEDS_TRIAGE'}).Count -gt 0) 'SNAPSHOT_CANDIDATES_MISSING'
Assert ($r.boundaries.candidates_require_triage -eq $true) 'CANDIDATE_TRIAGE_BOUNDARY_BAD'
Assert ($r.boundaries.legacy_maps_not_deleted_yet -eq $true) 'LEGACY_DELETION_BOUNDARY_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
$proof=[ordered]@{
 schema='map_authority_repair_v1_validation'
 status='PASS_MAP_AUTHORITY_REPAIR_V1'
 report_path=$reportPath
 canonical_map=$mapPath
 total_components=@($m.components).Count
 required_components=[int]$m.component_authority_summary.required_components
 snapshot_imported=[int]$m.component_authority_summary.snapshot_imported
 expanded_candidates_imported=[int]$m.component_authority_summary.expanded_candidates_imported
 legacy_maps_raw_authority=$false
 candidates_require_triage=$true
 passport_generator_blocked_until_triage=$true
 legacy_maps_deleted=$false
 deletion_allowed_next_with_rollback_proof=$true
 live_pid_now=[int]$liveNow[0].ProcessId
 live_process_touched_by_validator=$false
 active_memory_mutated=$false
 created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/MAP_AUTHORITY_REPAIR_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_MAP_AUTHORITY_REPAIR_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
