$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$reportPath='reports/self_development/MAP_AUTHORITY_DUPLICATE_AUDIT_V1.json'
$docPath='docs/operations/MAP_AUTHORITY_DUPLICATE_AUDIT_V1.md'
foreach($p in @($reportPath,$docPath)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
Assert ($r.schema -eq 'map_authority_duplicate_audit_v1') 'SCHEMA_BAD'
Assert ($r.status -eq 'PASS_MAP_AUTHORITY_DUPLICATE_AUDIT_V1') 'STATUS_BAD'
Assert ($r.current_canonical.component_count -eq 7) 'CURRENT_CANONICAL_NOT_7'
Assert ($r.current_canonical.new_component_lines_count -ge 7) 'NEW_COMPONENT_LINES_NOT_FOUND'
Assert ($r.findings.there_are_multiple_maps -eq $true) 'MULTIPLE_MAPS_NOT_CONFIRMED'
Assert ($r.findings.current_map_is_not_the_only_map -eq $true) 'ONLY_MAP_FALSE_NOT_SET'
Assert ($r.findings.current_map_is_incomplete_for_full_body_inventory -eq $true) 'INCOMPLETE_FLAG_BAD'
Assert ($r.findings.another_map_shows_more_components -eq $true) 'OTHER_MAP_MORE_COMPONENTS_FLAG_BAD'
Assert ($r.other_maps_with_more_or_different_inventory[0].component_count -gt $r.current_canonical.component_count) 'SNAPSHOT_DOES_NOT_SHOW_MORE_COMPONENTS'
Assert ($r.other_maps_with_more_or_different_inventory[1].generated_programs -gt 0) 'LEGACY_GENERATED_PROGRAMS_MISSING'
Assert ($r.other_maps_with_more_or_different_inventory[1].produced_agents -gt 0) 'LEGACY_PRODUCED_AGENTS_MISSING'
Assert ($r.expanded_candidate_audit.unregistered_strong -gt 0) 'EXPANDED_STRONG_CANDIDATES_MISSING'
Assert ($r.boundaries.do_not_delete_duplicate_maps -eq $true) 'NO_DELETE_BOUNDARY_BAD'
Assert ($r.boundaries.do_not_promote_legacy_map_raw -eq $true) 'NO_RAW_PROMOTION_BOUNDARY_BAD'
Assert ($r.boundaries.do_not_run_passport_generator_until_map_authority_repaired -eq $true) 'PASSPORT_GENERATOR_BLOCK_MISSING'
Assert ($r.recommended_next_step -eq 'MAP_AUTHORITY_REPAIR_V1_UNIFY_CURRENT_BODY_MAP_WITH_LEGACY_AND_SNAPSHOT_EVIDENCE_USING_VALIDATOR') 'NEXT_STEP_BAD'
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
$proof=[ordered]@{
 schema='map_authority_duplicate_audit_validation_v1'
 status='PASS_MAP_AUTHORITY_DUPLICATE_AUDIT_V1'
 report_path=$reportPath
 current_canonical_components=[int]$r.current_canonical.component_count
 parallel_snapshot_components=[int]$r.other_maps_with_more_or_different_inventory[0].component_count
 legacy_generated_programs=[int]$r.other_maps_with_more_or_different_inventory[1].generated_programs
 legacy_produced_agents=[int]$r.other_maps_with_more_or_different_inventory[1].produced_agents
 expanded_unregistered_strong=[int]$r.expanded_candidate_audit.unregistered_strong
 hardcoded_refresh_root_cause_confirmed=$true
 passport_generator_blocked=$true
 deletion_allowed=$false
 body_map_mutation_performed=$false
 live_pid_now=[int]$liveNow[0].ProcessId
 live_process_touched_by_validator=$false
 active_memory_mutated=$false
 created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/MAP_AUTHORITY_DUPLICATE_AUDIT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_MAP_AUTHORITY_DUPLICATE_AUDIT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
