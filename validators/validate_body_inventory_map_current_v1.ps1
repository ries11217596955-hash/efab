$ErrorActionPreference = 'Stop'
$errors = New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message) { $script:errors.Add($Message) | Out-Null }
function Read-Json([string]$Path, [string]$Label) {
  if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { Add-Err "missing_${Label}:$Path"; return $null }
  try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) }
  catch { Add-Err "bad_json_${Label}:$($Path):$($_.Exception.Message)"; return $null }
}
function Test-Unique([object[]]$Values) { return (@($Values | Sort-Object -Unique).Count -eq @($Values).Count) }

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
Set-Location $repoRoot
$bodyPath = 'reports/self_development/agent_body_map.json'
$canonicalPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
$refreshPath = 'reports/self_development/branch_agnostic_map_refresh_result.json'
$validationPath = '.runtime/map_control/validations/body_inventory_map_current_validation.json'

$branch = (git branch --show-current).Trim()
$head = (git rev-parse HEAD).Trim()
$body = Read-Json $bodyPath 'body_inventory_map'
$canonical = Read-Json $canonicalPath 'canonical_composition_map'
$refresh = Read-Json $refreshPath 'refresh_result'

$components = @()
$canonicalComponents = @()
if ($null -ne $body) {
  if ($body.schema -ne 'AGENT_BODY_MAP_COMPATIBILITY_VIEW_V2') { Add-Err "bad_body_schema:$($body.schema)" }
  if ($body.map_kind -ne 'DERIVED_HUMAN_COMPATIBILITY_VIEW') { Add-Err "bad_body_map_kind:$($body.map_kind)" }
  $components = @($body.components)
  if ($components.Count -le 0) { Add-Err 'body_components_empty' }
  if ($body.confirmed_component_count -lt 7) { Add-Err "confirmed_component_count_below_7:$($body.confirmed_component_count)" }
  if ($body.primary_evidence_candidate_count -le 0) { Add-Err 'primary_evidence_candidate_count_empty' }
  if ($components.Count -ne ($body.confirmed_component_count + $body.primary_evidence_candidate_count)) { Add-Err "body_component_count_mismatch:$($components.Count)" }
  $ids = @($components | ForEach-Object { [string]$_.id })
  if (-not (Test-Unique $ids)) { Add-Err 'duplicate_body_component_ids' }
  foreach ($c in $components) {
    if ([string]::IsNullOrWhiteSpace([string]$c.id)) { Add-Err 'component_missing_id' }
    if ([string]::IsNullOrWhiteSpace([string]$c.root)) { Add-Err "component_missing_root:$($c.id)" }
    elseif (-not (Test-Path -LiteralPath ([string]$c.root))) { Add-Err "component_root_missing:$($c.id):$($c.root)" }
    if ($c.PSObject.Properties.Name -contains 'capability') { Add-Err "body_view_contains_capability_field:$($c.id)" }
    if ($c.PSObject.Properties.Name -contains 'invocation') { Add-Err "body_view_contains_invocation_field:$($c.id)" }
  }
}
if ($null -ne $canonical) {
  if ($canonical.schema -ne 'AGENT_BODY_COMPOSITION_MAP_V1') { Add-Err "bad_canonical_schema:$($canonical.schema)" }
  if ($canonical.not_capability_invocation_map -ne $true) { Add-Err 'canonical_not_capability_invocation_flag_missing' }
  if ($canonical.generator -ne 'modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1') { Add-Err "bad_canonical_generator:$($canonical.generator)" }
  $canonicalComponents = @($canonical.components)
}
if ($null -ne $refresh) {
  if ($refresh.status -ne 'MAP_REFRESHED') { Add-Err "refresh_not_map_refreshed:$($refresh.status)" }
  if ($refresh.derived_compatibility_view -ne $bodyPath) { Add-Err "refresh_body_ref_bad:$($refresh.derived_compatibility_view)" }
  if ($refresh.canonical_composition_map -ne $canonicalPath) { Add-Err "refresh_canonical_ref_bad:$($refresh.canonical_composition_map)" }
  if ($refresh.protected_state_mutated -ne $false) { Add-Err 'protected_state_mutated_not_false' }
  if ($refresh.live_process_touched -ne $false) { Add-Err 'live_process_touched_not_false' }
  if ($refresh.deletion_performed -ne $false) { Add-Err 'deletion_performed_not_false' }
  if ($refresh.build_result.result -ne 'PASS') { Add-Err "refresh_build_result_not_pass:$($refresh.build_result.result)" }
}
if ($null -ne $body -and $null -ne $canonical) {
  if ($body.body_source_fingerprint.sha256 -ne $canonical.body_source_fingerprint.sha256) { Add-Err 'body_vs_canonical_fingerprint_mismatch' }
  if ($components.Count -ne $canonicalComponents.Count) { Add-Err "body_vs_canonical_component_count_mismatch:$($components.Count):$($canonicalComponents.Count)" }
  $bodyIds = @($components | ForEach-Object { [string]$_.id } | Sort-Object)
  $canonicalIds = @($canonicalComponents | ForEach-Object { [string]$_.id } | Sort-Object)
  if (($bodyIds -join "`n") -ne ($canonicalIds -join "`n")) { Add-Err 'body_vs_canonical_component_ids_mismatch' }
}
if ($null -ne $body -and $null -ne $refresh) {
  if ($body.body_source_fingerprint.sha256 -ne $refresh.body_source_fingerprint.sha256) { Add-Err 'body_vs_refresh_fingerprint_mismatch' }
}

$status = if ($errors.Count -eq 0) { 'PASS_BODY_INVENTORY_MAP_CURRENT_V1' } else { 'FAIL_BODY_INVENTORY_MAP_CURRENT_V1' }
$out = [ordered]@{
  schema = 'body_inventory_map_current_validation_v1'
  status = $status
  checked_at = (Get-Date).ToString('o')
  branch = $branch
  head = $head
  body_map_path = $bodyPath
  canonical_map_path = $canonicalPath
  refresh_result_path = $refreshPath
  component_count = $components.Count
  confirmed_component_count = $(if ($null -ne $body) { $body.confirmed_component_count } else { $null })
  primary_evidence_candidate_count = $(if ($null -ne $body) { $body.primary_evidence_candidate_count } else { $null })
  body_source_fingerprint = $(if ($null -ne $body) { $body.body_source_fingerprint } else { $null })
  boundary = [ordered]@{
    validates_body_inventory_view = $true
    validates_capability_invocation_map = $false
    validates_live_runtime = $false
    protected_state_mutated = $false
  }
  errors = @($errors)
}
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $validationPath) | Out-Null
$out | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $validationPath -Encoding UTF8
Write-Host "STATUS=$status"
Write-Host "VALIDATION_PATH=$validationPath"
Write-Host "COMPONENT_COUNT=$($components.Count)"
Write-Host "CONFIRMED_COMPONENT_COUNT=$($out.confirmed_component_count)"
Write-Host "PRIMARY_EVIDENCE_CANDIDATE_COUNT=$($out.primary_evidence_candidate_count)"
foreach ($e in $errors) { Write-Host "ERROR=$e" }
if ($errors.Count -gt 0) { exit 1 }

