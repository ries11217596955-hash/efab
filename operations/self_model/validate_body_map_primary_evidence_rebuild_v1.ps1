param(
  [string]$ActiveMapPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  [string]$RefreshResultPath = 'reports/self_development/branch_agnostic_map_refresh_result.json',
  [string]$GeneratorPath = 'modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1',
  [string]$ReportPath = 'reports/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1.json',
  [string]$ProofPath = 'tests/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1_PROOF.json'
)

$ErrorActionPreference = 'Stop'
$errors = New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message) { $script:errors.Add($Message) | Out-Null }

function Read-JsonFile([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
    Add-Err "missing_${Label}:$Path"
    return $null
  }
  try {
    return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json)
  } catch {
    Add-Err "bad_json_${Label}:$($Path):$($_.Exception.Message)"
    return $null
  }
}

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
$map = Read-JsonFile $ActiveMapPath 'active_map'
$refresh = Read-JsonFile $RefreshResultPath 'refresh_result'

if (-not (Test-Path -LiteralPath $GeneratorPath -PathType Leaf)) {
  Add-Err "missing_generator:$GeneratorPath"
  $generatorText = ''
} else {
  $generatorText = Get-Content -LiteralPath $GeneratorPath -Raw
}

$forbiddenAuthorityReads = @(
  'Get-Content\s+[''"]?self_knowledge[\\/]+BUILDER_SELF_MODEL\.json',
  'Get-Content\s+[''"]?reports[\\/]+self_development[\\/]+CURRENT_BODY_CAPABILITY_SNAPSHOT_V1\.json'
)
foreach ($pattern in $forbiddenAuthorityReads) {
  if ($generatorText -match $pattern) { Add-Err "forbidden_legacy_raw_read_in_generator:$pattern" }
}

$requiredIds = @(
  'school',
  'school_source_router',
  'compact_memory_intake',
  'knowledge_acquisition_port',
  'map_control',
  'operations_self_model',
  'gpt_handoff'
)

$confirmed = @()
$candidates = @()
$legacyHints = @()
$rejectedHints = @()
$summary = $null
if ($null -ne $map) {
  if ($map.schema -ne 'AGENT_BODY_COMPOSITION_MAP_V1') { Add-Err "bad_schema:$($map.schema)" }
  if ($map.generated_by_auto_refresh -ne $true) { Add-Err 'map_not_marked_generated_by_auto_refresh' }
  if ($map.generator -ne $GeneratorPath) { Add-Err "unexpected_generator_ref:$($map.generator)" }
  foreach ($section in @('confirmed_components','primary_evidence_candidates','legacy_unverified_hints','rejected_or_stale_hints','component_authority_summary')) {
    if ($map.PSObject.Properties.Name -notcontains $section) { Add-Err "missing_section:$section" }
  }

  $confirmed = @($map.confirmed_components)
  $candidates = @($map.primary_evidence_candidates)
  $legacyHints = @($map.legacy_unverified_hints)
  $rejectedHints = @($map.rejected_or_stale_hints)
  $summary = $map.component_authority_summary

  if ($confirmed.Count -lt 7) { Add-Err "confirmed_components_below_7:$($confirmed.Count)" }
  if ($candidates.Count -le 0) { Add-Err 'primary_evidence_candidates_empty' }
  if ($legacyHints.Count -le 0) { Add-Err 'legacy_unverified_hints_empty' }

  $confirmedIds = @($confirmed | ForEach-Object { $_.id })
  foreach ($id in $requiredIds) {
    if ($confirmedIds -notcontains $id) { Add-Err "required_confirmed_component_missing:$id" }
  }

  foreach ($component in $confirmed) {
    if ($component.needs_triage -ne $false) { Add-Err "confirmed_component_needs_triage_not_false:$($component.id)" }
    if ([string]$component.source_ref -match 'self_knowledge/BUILDER_SELF_MODEL|CURRENT_BODY_CAPABILITY_SNAPSHOT') {
      Add-Err "confirmed_component_uses_legacy_source:$($component.id)"
    }
  }

  $badCandidates = @($candidates | Where-Object { $_.needs_triage -ne $true -or [string]::IsNullOrWhiteSpace([string]$_.path) })
  foreach ($candidate in $badCandidates) { Add-Err "candidate_missing_triage_or_path:$($candidate.id)" }

  $legacyHintPaths = @($legacyHints | ForEach-Object { $_.path })
  foreach ($legacyPath in @('self_knowledge/BUILDER_SELF_MODEL.json','reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json')) {
    if ($legacyHintPaths -notcontains $legacyPath) { Add-Err "legacy_hint_missing:$legacyPath" }
  }
  foreach ($hint in $legacyHints) {
    if ($hint.raw_authority -ne $false) { Add-Err "legacy_hint_raw_authority_not_false:$($hint.path)" }
    if ($hint.read_by_generator -ne $false) { Add-Err "legacy_hint_read_by_generator_not_false:$($hint.path)" }
  }

  if ($summary.legacy_maps_raw_authority -ne $false) { Add-Err 'summary_legacy_maps_raw_authority_not_false' }
  if ($summary.old_maps_read_as_authority -ne $false) { Add-Err 'summary_old_maps_read_as_authority_not_false' }
  if ($summary.passport_generator_blocked_until_candidate_triage -ne $true) { Add-Err 'summary_passport_generator_not_blocked' }
  if ($summary.child_agent_factory_readiness -ne 'NOT_PROVEN') { Add-Err "summary_child_agent_factory_readiness_bad:$($summary.child_agent_factory_readiness)" }
  if ($summary.files_changed_before_preflight_pass -ne $false) { Add-Err 'files_changed_before_preflight_pass_not_false' }
}

if ($null -ne $refresh) {
  if ($refresh.status -ne 'MAP_REFRESHED') { Add-Err "refresh_not_map_refreshed:$($refresh.status)" }
  if ($refresh.canonical_composition_map -ne $ActiveMapPath) { Add-Err "refresh_canonical_map_ref_bad:$($refresh.canonical_composition_map)" }
  if ($refresh.build_result.legacy_maps_raw_authority -ne $false) { Add-Err 'refresh_legacy_maps_raw_authority_not_false' }
  if ($refresh.build_result.old_maps_read_as_authority -ne $false) { Add-Err 'refresh_old_maps_read_as_authority_not_false' }
}

$status = if ($errors.Count -eq 0) { 'PASS_BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1' } else { 'FAIL_BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1' }
$counts = [ordered]@{
  confirmed_components = $confirmed.Count
  primary_evidence_candidates = $candidates.Count
  legacy_unverified_hints = $legacyHints.Count
  rejected_or_stale_hints = $rejectedHints.Count
}
$acceptance = [ordered]@{
  canonical_map_exists_and_parses = ($null -ne $map)
  produced_by_auto_refresh_generator = ($null -ne $map -and $map.generated_by_auto_refresh -eq $true -and $map.generator -eq $GeneratorPath)
  confirmed_components_count_ge_7 = ($confirmed.Count -ge 7)
  primary_evidence_candidates_count_gt_0 = ($candidates.Count -gt 0)
  legacy_unverified_hints_exists = ($legacyHints.Count -gt 0)
  legacy_maps_are_not_raw_authority = ($null -ne $summary -and $summary.legacy_maps_raw_authority -eq $false)
  old_maps_are_not_read_as_authority = ($null -ne $summary -and $summary.old_maps_read_as_authority -eq $false)
  passport_generator_blocked_until_candidate_triage = ($null -ne $summary -and $summary.passport_generator_blocked_until_candidate_triage -eq $true)
  child_agent_factory_readiness = if($null -ne $summary){ $summary.child_agent_factory_readiness } else { $null }
  required_components_present = @($requiredIds | Where-Object { @($confirmed | ForEach-Object { $_.id }) -notcontains $_ }).Count -eq 0
  live_process_inspected = $false
  live_process_count_remains_1_if_inspected = 'NOT_INSPECTED'
  files_changed_before_preflight_pass = $false
}
$report = [ordered]@{
  schema = 'body_map_primary_evidence_rebuild_v1'
  status = $status
  branch = $branch
  head = $head
  active_map_path = $ActiveMapPath
  refresh_result_path = $RefreshResultPath
  generator_path = $GeneratorPath
  counts = $counts
  acceptance = $acceptance
  legacy_map_authority_status = [ordered]@{
    legacy_maps_raw_authority = if($null -ne $summary){ $summary.legacy_maps_raw_authority } else { $null }
    old_maps_read_as_authority = if($null -ne $summary){ $summary.old_maps_read_as_authority } else { $null }
    generator_forbidden_raw_reads_found = @($errors | Where-Object { $_ -like 'forbidden_legacy_raw_read_in_generator:*' }).Count
  }
  errors = @($errors)
  live_process_touched = $false
  active_memory_mutated = $false
  created_at = (Get-Date).ToString('o')
}
$proof = [ordered]@{
  schema = 'body_map_primary_evidence_rebuild_v1_proof'
  status = $status
  report_path = $ReportPath
  canonical_map = $ActiveMapPath
  counts = $counts
  acceptance = $acceptance
  errors = @($errors)
  live_process_touched_by_validator = $false
  active_memory_mutated = $false
  created_at = $report.created_at
}

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ReportPath) | Out-Null
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $ProofPath) | Out-Null
$report | ConvertTo-Json -Depth 28 | Set-Content -LiteralPath $ReportPath -Encoding UTF8
$proof | ConvertTo-Json -Depth 28 | Set-Content -LiteralPath $ProofPath -Encoding UTF8

Write-Host "STATUS=$status"
Write-Host "REPORT_PATH=$ReportPath"
Write-Host "PROOF_PATH=$ProofPath"
foreach ($errorItem in $errors) { Write-Host "ERROR=$errorItem" }
if ($errors.Count -gt 0) { exit 1 }
