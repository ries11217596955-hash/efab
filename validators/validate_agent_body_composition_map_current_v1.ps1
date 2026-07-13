param(
  [string]$ResultPath = 'reports/self_development/branch_agnostic_map_refresh_result.json',
  [string]$ActiveMapPath = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  [switch]$RequireCurrentHead
)
$ErrorActionPreference = 'Stop'
$errors = New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $script:errors.Add($m) | Out-Null }
function Test-StructuralPath([string]$Path) {
  $p = $Path -replace '\\','/'
  $generatedOutputs = @(
    'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
    'reports/self_development/agent_body_map.json',
    'reports/self_development/agent_body_map.md',
    'reports/self_development/branch_agnostic_map_refresh_result.json',
    'reports/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1.json',
    'docs/operations/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1.md',
    'tests/self_development/BODY_MAP_PRIMARY_EVIDENCE_REBUILD_V1_PROOF.json'
  )
  if ($generatedOutputs -contains $p) { return $false }
  $allowedPrefixes = @(
    'operations/',
    'modules/',
    'validators/',
    'self_model/',
    'contracts/',
    'living_learning_environment/',
    'self_build_programs/',
    'packs/',
    'docs/operations/',
    'reports/self_development/',
    'tests/self_development/'
  )
  $isAllowed = $false
  foreach ($prefix in $allowedPrefixes) { if ($p.StartsWith($prefix)) { $isAllowed = $true; break } }
  if (-not $isAllowed) { return $false }
  $excludePrefixes = @('operations/archive/','runtime_sessions/')
  foreach ($prefix in $excludePrefixes) { if ($p.StartsWith($prefix)) { return $false } }
  if ($p -match '/runs?/|/test_life_runs?/') { return $false }
  return ($p.EndsWith('.ps1') -or $p.EndsWith('.json') -or $p.EndsWith('.md'))
}
function Get-CompositionSourceFingerprint([string[]]$Paths) {
  $entries = New-Object System.Collections.Generic.List[string]
  foreach($path in @($Paths | Sort-Object -Unique)){
    if(-not (Test-Path -LiteralPath $path -PathType Leaf)){ continue }
    $hash = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash
    $entries.Add("$path|$hash") | Out-Null
  }
  $joined = ($entries -join "`n")
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($joined)
  $sha = [System.Security.Cryptography.SHA256]::Create()
  try { $digest = [System.BitConverter]::ToString($sha.ComputeHash($bytes)).Replace('-','').ToLowerInvariant() }
  finally { $sha.Dispose() }
  return [ordered]@{ structural_file_count=$entries.Count; sha256=$digest }
}
$currentHead = (git rev-parse HEAD).Trim()
$branch = (git branch --show-current).Trim()
$BoundedEvidencePathspecs = @(
  'operations',
  'modules',
  'validators',
  'self_model',
  'contracts',
  'living_learning_environment',
  'self_build_programs',
  'packs',
  'docs/operations',
  'reports/self_development',
  'tests/self_development'
)
$trackedFiles = @((git ls-files -- @BoundedEvidencePathspecs) | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ -replace '\\','/' })
$currentStructuralFiles = @($trackedFiles | Where-Object { Test-StructuralPath $_ })
$currentFingerprint = Get-CompositionSourceFingerprint -Paths $currentStructuralFiles
foreach($f in @('operations/map_control/branch_agnostic_map_refresh_policy.json','operations/map_control/BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT.md','modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1',$ResultPath,$ActiveMapPath)) { if(-not (Test-Path $f)){ Add-Err "missing:$f" } }
$resultFingerprint = $null
if(Test-Path $ResultPath){
  $r=Get-Content $ResultPath -Raw|ConvertFrom-Json
  if(@('MAP_REFRESHED','MAP_REFRESH_SKIPPED','MAP_REFRESH_DRY_RUN_READY') -notcontains $r.status){ Add-Err "bad_status:$($r.status)" }
  if($r.protected_state_mutated -ne $false){ Add-Err 'protected_state_mutated_not_false' }
  if($r.runtime_outputs_staged -ne $false){ Add-Err 'runtime_outputs_staged_not_false' }
  if($r.live_process_touched -ne $false){ Add-Err 'live_process_touched_not_false' }
  if($r.deletion_performed -ne $false){ Add-Err 'deletion_performed_not_false' }
  if($r.status -eq 'MAP_REFRESHED' -and $r.map_contains_required_components -ne $true){ Add-Err 'required_components_missing_in_result' }
  $resultFingerprint = $r.body_source_fingerprint.sha256
  if([string]::IsNullOrWhiteSpace($resultFingerprint)){ Add-Err 'result_missing_body_source_fingerprint' }
  elseif($resultFingerprint -ne $currentFingerprint.sha256){ Add-Err "stale_result_fingerprint:$resultFingerprint:current:$($currentFingerprint.sha256)" }
}
$activeFingerprint = $null
$headMatches = $false
if(Test-Path $ActiveMapPath){
  $m=Get-Content $ActiveMapPath -Raw|ConvertFrom-Json
  if($m.schema -ne 'AGENT_BODY_COMPOSITION_MAP_V1'){ Add-Err "bad_active_map_schema:$($m.schema)" }
  if($m.map_kind -ne 'COMPOSITION_STATUS_MAP'){ Add-Err "bad_map_kind:$($m.map_kind)" }
  if($m.not_capability_invocation_map -ne $true){ Add-Err 'map_boundary_missing_not_capability_invocation_map' }
  foreach($section in @('confirmed_components','primary_evidence_candidates','legacy_unverified_hints','rejected_or_stale_hints','component_authority_summary')){
    if($m.PSObject.Properties.Name -notcontains $section){ Add-Err "missing_section:$section" }
  }
  $headMatches = ($m.observed_head_at_generation -eq $currentHead)
  $activeFingerprint = $m.body_source_fingerprint.sha256
  if([string]::IsNullOrWhiteSpace($activeFingerprint)){ Add-Err 'active_map_missing_body_source_fingerprint' }
  elseif($activeFingerprint -ne $currentFingerprint.sha256){ Add-Err "stale_active_map_fingerprint:$activeFingerprint:current:$($currentFingerprint.sha256)" }
  $confirmed = @($m.confirmed_components)
  $candidates = @($m.primary_evidence_candidates)
  if($confirmed.Count -lt 6){ Add-Err "confirmed_components_below_minimum:$($confirmed.Count)" }
  if($candidates.Count -le 0){ Add-Err 'primary_evidence_candidates_empty' }
  $summary = $m.component_authority_summary
  if($summary.legacy_maps_raw_authority -ne $false){ Add-Err 'legacy_maps_raw_authority_not_false' }
  if($summary.old_maps_read_as_authority -ne $false){ Add-Err 'old_maps_read_as_authority_not_false' }
  if($summary.passport_generator_blocked_until_candidate_triage -ne $true){ Add-Err 'passport_generator_not_blocked_until_candidate_triage' }
  if($summary.child_agent_factory_readiness -ne 'NOT_PROVEN'){ Add-Err "child_agent_factory_readiness_bad:$($summary.child_agent_factory_readiness)" }
  $componentIds=@($confirmed | ForEach-Object { $_.id })
  foreach($id in @('school','school_source_router','compact_memory_intake','knowledge_acquisition_port','map_control','gpt_handoff')){ if($componentIds -notcontains $id){ Add-Err "missing_component:$id" } }
  $router = @($confirmed | Where-Object { $_.id -eq 'school_source_router' } | Select-Object -First 1)
  if($router.Count -eq 0){ Add-Err 'school_source_router_component_absent' }
  else {
    foreach($rf in @('operations/school/curriculum/source_router/run_school_source_router_v1.ps1','operations/school/curriculum/source_router/template_filter/run_school_source_template_filter_v1.ps1')){
      if(@($router[0].required_files) -notcontains $rf){ Add-Err "router_required_file_not_declared:$rf" }
      if(@($router[0].missing_required_files) -contains $rf){ Add-Err "router_required_file_missing:$rf" }
    }
  }
}
$status=if($errors.Count -eq 0){'PASS_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1'}else{'FAIL_AGENT_BODY_COMPOSITION_MAP_CURRENT_V1'}
$out=[ordered]@{ schema='AGENT_BODY_COMPOSITION_MAP_CURRENT_VALIDATION_V2'; status=$status; checked_at=(Get-Date).ToString('o'); branch=$branch; head=$currentHead; head_matches_map_observed_head=$headMatches; current_body_source_fingerprint=$currentFingerprint; result_body_source_fingerprint=$resultFingerprint; active_body_source_fingerprint=$activeFingerprint; require_current_head_parameter_kept_for_compatibility=[bool]$RequireCurrentHead; errors=@($errors); boundary='Validation only. Currentness is body source fingerprint, not self-referential commit HEAD.' }
$outRoot='.runtime/map_control/validations'; New-Item -ItemType Directory -Force -Path $outRoot | Out-Null; $outPath=Join-Path $outRoot 'agent_body_composition_map_current_validation.json'
$out|ConvertTo-Json -Depth 18|Set-Content -Path $outPath -Encoding UTF8
Write-Host "STATUS=$status"
Write-Host "VALIDATION_PATH=$outPath"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }

