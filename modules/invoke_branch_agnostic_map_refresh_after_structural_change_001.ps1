param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$SubjectHead = 'HEAD',
  [string]$OutputRoot = 'reports/self_development',
  [string]$TriggerReason = 'local_post_structural_change_check',
  [switch]$Force,
  [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $RepoRoot).Path
Set-Location $root

function Get-GitLines([string[]]$GitArgs) {
  $out = & git @GitArgs
  if ($LASTEXITCODE -ne 0) { throw "git_failed:$($GitArgs -join ' ')" }
  return @($out | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ -replace '\\','/' })
}

function Test-StructuralPath([string]$Path) {
  $p = $Path -replace '\\','/'
  $excludePrefixes = @('operations/gpt_handoff/','operations/autonomy_diagnostics/','operations/autonomous_inner_motor/test_life_runs/','operations/archive/','runtime_sessions/','reports/')
  foreach ($prefix in $excludePrefixes) { if ($p.StartsWith($prefix)) { return $false } }
  if ($p -match '/proofs?/|/runs?/|/test_life_runs?/') { return $false }
  if ($p -match '^operations/map_control/.*validation.*\.json$') { return $false }
  if ($p -in @('AGENTS.md','README.md')) { return $true }
  if ($p.StartsWith('modules/') -and $p.EndsWith('.ps1')) { return $true }
  if ($p.StartsWith('validators/') -and $p.EndsWith('.ps1')) { return $true }
  if ($p.StartsWith('.github/workflows/')) { return $true }
  if ($p.StartsWith('operations/') -and ($p.EndsWith('.ps1') -or $p.EndsWith('.json') -or $p.EndsWith('.md'))) { return $true }
  return $false
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
  return [ordered]@{
    algorithm = 'sha256(sorted structural path plus file sha256; excludes reports/runtime/proofs/gpt_handoff archives)'
    structural_file_count = $entries.Count
    sha256 = $digest
  }
}

function Get-LatestGitCommitForPath([string]$Path) {
  $line = (& git log -1 --format='%H|%cI|%s' -- $Path) 2>$null
  if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($line)) { return $null }
  $parts = $line -split '\|',3
  return [ordered]@{ head = $parts[0]; committed_at = $parts[1]; subject = $parts[2] }
}

function Get-LatestFileUnder([string]$Path) {
  if (-not (Test-Path $Path)) { return $null }
  $item = Get-ChildItem $Path -Recurse -Force -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if ($null -eq $item) { return $null }
  return [ordered]@{
    path = (($item.FullName.Substring($root.Length)).TrimStart([char[]]@([char]92,[char]47)) -replace '\\','/')
    last_write = $item.LastWriteTime.ToString('o')
    bytes = $item.Length
  }
}

$trackedFiles = Get-GitLines @('ls-files')
function New-Component([string]$Id, [string]$RootPath, [string[]]$RequiredFiles = @(), [string[]]$RuntimeRoots = @(), [string]$Role = '') {
  $files = @($trackedFiles | Where-Object { $_ -eq $RootPath -or $_.StartsWith($RootPath.TrimEnd('/') + '/') })
  $scripts = @($files | Where-Object { $_.EndsWith('.ps1') })
  $policies = @($files | Where-Object { $_ -match 'policy\.json$' })
  $validators = @($files | Where-Object { $_ -match 'validate|validation' })
  $proofs = @($files | Where-Object { $_ -match '/proofs?/|_PROOF|PROOF_' })
  $docs = @($files | Where-Object { $_.EndsWith('.md') })
  $latestRuntime = $null
  foreach ($rt in $RuntimeRoots) {
    $candidate = Get-LatestFileUnder $rt
    if ($null -ne $candidate) {
      if ($null -eq $latestRuntime -or ([datetime]$candidate.last_write) -gt ([datetime]$latestRuntime.last_write)) { $latestRuntime = $candidate }
    }
  }
  $missing = @($RequiredFiles | Where-Object { -not (Test-Path $_) })
  return [ordered]@{
    id = $Id
    role = $Role
    root = $RootPath
    status = $(if ($files.Count -gt 0) { 'PRESENT_ON_CURRENT_BRANCH' } else { 'MISSING_ON_CURRENT_BRANCH' })
    file_count = $files.Count
    script_count = $scripts.Count
    policy_count = $policies.Count
    validator_count = $validators.Count
    proof_file_count = $proofs.Count
    doc_count = $docs.Count
    required_files = @($RequiredFiles)
    missing_required_files = @($missing)
    required_files_present = ($missing.Count -eq 0)
    entrypoint_scripts = @($scripts | Where-Object { $_ -match 'run_|control_|merge_|submit_|ask_|finalize_|validate_' } | Select-Object -First 40)
    notable_files = @($RequiredFiles | Where-Object { Test-Path $_ })
    latest_git_commit = Get-LatestGitCommitForPath $RootPath
    latest_runtime_artifact = $latestRuntime
  }
}

$branch = (git branch --show-current).Trim()
$observedHead = (git rev-parse HEAD).Trim()
$resolvedHead = (git rev-parse $SubjectHead).Trim()
$changedPaths = @()
try { $changedPaths = Get-GitLines @('diff-tree','--no-commit-id','--name-only','-r',$resolvedHead) } catch { $changedPaths = @() }
$structuralChangedPaths = @($changedPaths | Where-Object { Test-StructuralPath $_ })
$structuralFiles = @($trackedFiles | Where-Object { Test-StructuralPath $_ })
$sourceFingerprint = Get-CompositionSourceFingerprint -Paths $structuralFiles
$shouldRefresh = [bool]$Force -or ($structuralChangedPaths.Count -gt 0)
$outputFull = Join-Path $root $OutputRoot
New-Item -ItemType Directory -Force -Path $outputFull | Out-Null
$resultPath = Join-Path $outputFull 'branch_agnostic_map_refresh_result.json'

$result = [ordered]@{
  schema = 'BRANCH_AGNOSTIC_MAP_REFRESH_RESULT_V3'
  status = $(if ($shouldRefresh) { 'MAP_REFRESH_PENDING' } else { 'MAP_REFRESH_SKIPPED' })
  checked_at = (Get-Date).ToString('o')
  branch = $branch
  observed_head = $observedHead
  subject_head = $resolvedHead
  trigger_reason = $TriggerReason
  force = [bool]$Force
  dry_run = [bool]$DryRun
  changed_paths = @($changedPaths)
  structural_paths = @($structuralChangedPaths)
  output_root = $OutputRoot
  canonical_composition_map = (Join-Path $OutputRoot 'SELF_MODEL_ACTIVE_MAP.json') -replace '\\','/'
  human_composition_summary = (Join-Path $OutputRoot 'agent_body_map.md') -replace '\\','/'
  derived_compatibility_view = (Join-Path $OutputRoot 'agent_body_map.json') -replace '\\','/'
  protected_state_mutated = $false
  runtime_outputs_staged = $false
  live_process_touched = $false
  deletion_performed = $false
  body_source_fingerprint = $sourceFingerprint
  map_contains_required_components = $false
  required_components = @('school','school_source_router','compact_memory_intake','autonomous_inner_motor','map_control','gpt_handoff')
  skip_reason = $null
  freshness_rule = 'Currentness is body_source_fingerprint, not self-referential commit HEAD.'
}

if (-not $shouldRefresh) {
  $result.skip_reason = 'NO_STRUCTURAL_PATHS_CHANGED_AND_FORCE_NOT_SET'
  $result | ConvertTo-Json -Depth 28 | Set-Content -Path $resultPath -Encoding UTF8
  return [pscustomobject]$result
}
if ($DryRun) {
  $result.status = 'MAP_REFRESH_DRY_RUN_READY'
  $result.skip_reason = 'DRY_RUN_NO_BUILD_EXECUTED'
  $result | ConvertTo-Json -Depth 28 | Set-Content -Path $resultPath -Encoding UTF8
  return [pscustomobject]$result
}

$moduleFiles = @($trackedFiles | Where-Object { $_ -like 'modules/*.ps1' })
$validatorFiles = @($trackedFiles | Where-Object { $_ -like 'validators/*.ps1' })
$workflowFiles = @($trackedFiles | Where-Object { $_ -like '.github/workflows/*' })
$components = @(
  (New-Component 'school' 'operations/school' @('operations/school/run_agent_school.ps1','operations/school/finalize_agent_school_run_v1.ps1','operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md') @('.runtime/school_runs','.runtime/autonomous_school_cycles') 'candidate learning factory and school lifecycle'),
  (New-Component 'school_source_router' 'operations/school/curriculum/source_router' @('operations/school/curriculum/source_router/run_school_source_router_v1.ps1','operations/school/curriculum/source_router/run_school_codex_source_port_v1.ps1','operations/school/curriculum/source_router/run_school_external_world_source_port_v1.ps1','operations/school/curriculum/source_router/template_filter/run_school_source_template_filter_v1.ps1','operations/school/curriculum/source_router/template_filter/school_source_template_filter_policy.json') @('.runtime/school_source_router','.runtime/school_source_ports','.runtime/school_source_template_filter') 'governed source selection before school material intake'),
  (New-Component 'compact_memory_intake' 'operations/compact_memory_intake' @('operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1','operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1','operations/compact_memory_intake/run_compact_memory_queue_maintenance_v1.ps1') @('.runtime/compact_memory_intake_v1','.runtime/active_compact_semantic_memory_v1','.runtime/file_atom_absorption') 'only governed packet/intake/merge path into compact memory'),
  (New-Component 'autonomous_inner_motor' 'operations/autonomous_inner_motor' @('operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1') @('.runtime/autonomous_inner_motor') 'bounded inner motor / test life runtime surface'),
  (New-Component 'knowledge_acquisition_port' 'operations/knowledge_acquisition_port' @('operations/knowledge_acquisition_port/ask_codex_knowledge_source.ps1','operations/knowledge_acquisition_port/ask_codex_batch_knowledge_source.ps1') @('.runtime/knowledge_acquisition_port') 'bounded knowledge acquisition material port'),
  (New-Component 'map_control' 'operations/map_control' @('operations/map_control/BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT.md','operations/map_control/branch_agnostic_map_refresh_policy.json') @() 'map governance / freshness contract'),
  (New-Component 'gpt_handoff' 'operations/gpt_handoff' @('operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md') @() 'GPT/operator compact handoff surface')
)
function ConvertTo-BodyComponentId([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value)){ return $null }
  $v = $Value.Trim().ToLowerInvariant() -replace '[^a-z0-9]+','_'
  $v = $v.Trim('_')
  if([string]::IsNullOrWhiteSpace($v)){ return $null }
  return $v
}

function New-InventoryComponent([string]$Id, [string]$RootPath, [string]$Role, [string]$AuthorityClass, [string]$SourceRef, [string]$CandidateClassification = '', [int]$ObservedFileCount = -1, [int]$ObservedScriptCount = -1) {
  $files = @()
  $scripts = @()
  if(-not [string]::IsNullOrWhiteSpace($RootPath) -and (Test-Path $RootPath)) {
    $files = @($trackedFiles | Where-Object { $_ -eq $RootPath -or $_.StartsWith($RootPath.TrimEnd('/') + '/') })
    $scripts = @($files | Where-Object { $_.EndsWith('.ps1') })
  }
  $fileCount = if($ObservedFileCount -ge 0){ $ObservedFileCount } else { $files.Count }
  $scriptCount = if($ObservedScriptCount -ge 0){ $ObservedScriptCount } else { $scripts.Count }
  return [ordered]@{
    id = $Id
    role = $Role
    root = $RootPath
    status = $(if((Test-Path $RootPath) -or $AuthorityClass -match 'SNAPSHOT|LEGACY|CANDIDATE') { 'PRESENT_OR_EVIDENCE_INDEXED' } else { 'MISSING_ON_CURRENT_BRANCH' })
    file_count = $fileCount
    script_count = $scriptCount
    policy_count = 0
    validator_count = 0
    proof_file_count = 0
    doc_count = 0
    required_files = @()
    missing_required_files = @()
    required_files_present = $true
    entrypoint_scripts = @($scripts | Where-Object { $_ -match 'run_|control_|merge_|submit_|ask_|finalize_|validate_' } | Select-Object -First 40)
    notable_files = @()
    latest_git_commit = if(Test-Path $RootPath){ Get-LatestGitCommitForPath $RootPath } else { $null }
    latest_runtime_artifact = $null
    is_required_component = $false
    authority_class = $AuthorityClass
    source_ref = $SourceRef
    candidate_classification = $CandidateClassification
    needs_triage = $true
  }
}

$componentList = New-Object System.Collections.ArrayList
$componentIdSet = @{}
foreach($c in $components){
  $c['is_required_component'] = $true
  $c['authority_class'] = 'CURRENT_REQUIRED_COMPONENT'
  $c['source_ref'] = 'hardcoded_required_component_list_v1'
  $c['needs_triage'] = $false
  [void]$componentList.Add($c)
  $componentIdSet[[string]$c.id] = $true
}

$snapshotPath = 'reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'
$snapshotImported = 0
if(Test-Path $snapshotPath){
  try {
    $snapshot = Get-Content $snapshotPath -Raw | ConvertFrom-Json
    foreach($item in @($snapshot.components)){
      $rawName = if($item.PSObject.Properties.Name -contains 'name'){ [string]$item.name } elseif($item.PSObject.Properties.Name -contains 'id'){ [string]$item.id } else { $null }
      $id = ConvertTo-BodyComponentId $rawName
      if($id -and -not $componentIdSet.ContainsKey($id)){
        $kind = if($item.PSObject.Properties.Name -contains 'kind'){ [string]$item.kind } else { 'snapshot_component' }
        $built = if($item.PSObject.Properties.Name -contains 'built'){ [string]$item.built } else { 'unknown' }
        $wired = if($item.PSObject.Properties.Name -contains 'wired'){ [string]$item.wired } else { 'unknown' }
        $role = "snapshot component kind=$kind built=$built wired=$wired"
        [void]$componentList.Add((New-InventoryComponent $id "evidence://$snapshotPath#$id" $role 'PARALLEL_SNAPSHOT_COMPONENT_NEEDS_TRIAGE' $snapshotPath 'SNAPSHOT_COMPONENT'))
        $componentIdSet[$id] = $true
        $snapshotImported++
      }
    }
  } catch {}
}

$expandedAuditPath = 'reports/self_development/EXPANDED_ORGAN_CANDIDATE_INVENTORY_AUDIT_V1.json'
$expandedImported = 0
if(Test-Path $expandedAuditPath){
  try {
    $expandedAudit = Get-Content $expandedAuditPath -Raw | ConvertFrom-Json
    foreach($cand in @($expandedAudit.selected_candidates | Where-Object { $_.classification -like 'UNREGISTERED_ORGAN_CANDIDATE*' })){
      $id = ConvertTo-BodyComponentId ([string]$cand.path)
      if($id -and -not $componentIdSet.ContainsKey($id)){
        $role = "repo-discovered organ-like candidate; classification=$($cand.classification); score=$($cand.score)"
        [void]$componentList.Add((New-InventoryComponent $id ([string]$cand.path) $role 'REPO_DISCOVERED_CANDIDATE_NEEDS_TRIAGE' $expandedAuditPath ([string]$cand.classification) ([int]$cand.file_count) ([int]$cand.script_count)))
        $componentIdSet[$id] = $true
        $expandedImported++
      }
    }
  } catch {}
}

$legacySummary = [ordered]@{ path='self_knowledge/BUILDER_SELF_MODEL.json'; exists=(Test-Path 'self_knowledge/BUILDER_SELF_MODEL.json'); imported_as_raw_authority=$false }
if(Test-Path 'self_knowledge/BUILDER_SELF_MODEL.json'){
  try {
    $legacySelf = Get-Content 'self_knowledge/BUILDER_SELF_MODEL.json' -Raw | ConvertFrom-Json
    $legacySummary.module_inventory_modules = @($legacySelf.module_inventory.modules).Count
    $legacySummary.capabilities = @($legacySelf.capability_manifest.capabilities).Count
    $legacySummary.generated_programs = @($legacySelf.generated_programs).Count
    $legacySummary.produced_agents = @($legacySelf.produced_agents).Count
  } catch {}
}
$components = @($componentList)
$missingRequiredComponents = @($components | Where-Object { $_.is_required_component -eq $true -and ($_.status -ne 'PRESENT_ON_CURRENT_BRANCH' -or -not $_.required_files_present) } | ForEach-Object { $_.id })
$canonicalMapPath = Join-Path $outputFull 'SELF_MODEL_ACTIVE_MAP.json'
$bodyMapPath = Join-Path $outputFull 'agent_body_map.json'
$bodyMapMdPath = Join-Path $outputFull 'agent_body_map.md'
$legacySurfaces = @(
  [ordered]@{ path='self_knowledge/BUILDER_SELF_MODEL.json'; classification='LEGACY_SELF_MODEL_REFERENCE'; role='historical broad self model; not current composition map' },
  [ordered]@{ path='self_knowledge/ROADMAP_STATE.json'; classification='LEGACY_ROADMAP_REFERENCE'; role='historical roadmap state; not current composition map' },
  [ordered]@{ path='CAPABILITY_ROADMAP.json'; classification='CAPABILITY_ROADMAP_NOT_COMPOSITION_MAP'; role='capability/skill roadmap; keep separate from body composition map' },
  [ordered]@{ path='GENESIS_STATE.json'; classification='GENESIS_STATE_NOT_COMPOSITION_MAP'; role='genesis/static state registry; not current composition map' }
)

$activeMap = [ordered]@{
  schema = 'AGENT_BODY_COMPOSITION_MAP_V1'
  map_refresh_status = 'SELF_KNOWLEDGE_READY'
  map_kind = 'COMPOSITION_STATUS_MAP'
  not_capability_invocation_map = $true
  self_knowledge_ready = $true
  map_is_ready_for_next_decision = ($missingRequiredComponents.Count -eq 0)
  branch = $branch
  observed_head_at_generation = $observedHead
  subject_head = $resolvedHead
  generated_at = (Get-Date).ToString('o')
  generator = 'invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1'
  role = 'canonical local body composition/status map: what exists, where it is, freshness, last runtime/proof signal'
  trigger_reason = $TriggerReason
  canonical_map_path = ($canonicalMapPath.Substring($root.Length).TrimStart([char[]]@([char]92,[char]47)) -replace '\\','/')
  structural_path_count = $structuralFiles.Count
  body_source_fingerprint = $sourceFingerprint
  module_count = $moduleFiles.Count
  validator_count = $validatorFiles.Count
  workflow_count = $workflowFiles.Count
  components = @($components)
  component_authority_summary = [ordered]@{ required_components = @($components | Where-Object { $_.is_required_component -eq $true }).Count; snapshot_imported = $snapshotImported; expanded_candidates_imported = $expandedImported; total_components = @($components).Count; legacy_self_knowledge_summary = $legacySummary; legacy_maps_are_source_material_not_authority = $true; passport_generator_blocked_until_candidate_triage = $true }
  required_components_present = ($missingRequiredComponents.Count -eq 0)
  missing_required_components = @($missingRequiredComponents)
  legacy_or_noncanonical_map_surfaces = @($legacySurfaces)
  current_runtime_observation = [ordered]@{
    live_process_touched = $false
    latest_active_compact_memory_manifest = Get-LatestFileUnder '.runtime/active_compact_semantic_memory_v1'
    latest_school_runtime_artifact = Get-LatestFileUnder '.runtime/school_runs'
    latest_aimo_runtime_artifact = Get-LatestFileUnder '.runtime/autonomous_inner_motor'
  }
  freshness_rule = 'Trust currentness by body_source_fingerprint, not by self-referential commit HEAD.'
  boundary = 'This is the single canonical auto-refreshed composition/status map. It includes required components plus evidence-indexed candidates from approved source maps/audits. Candidate entries require triage before passport generation or organ acceptance. It does not describe how to invoke capabilities; capability invocation belongs to a separate capability map.'
}
$bodyMap = [ordered]@{
  schema = 'AGENT_BODY_MAP_COMPATIBILITY_VIEW_V1'
  source = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  branch = $branch
  observed_head_at_generation = $observedHead
  generated_at = $activeMap.generated_at
  body_source_fingerprint = $sourceFingerprint
  map_kind = 'DERIVED_HUMAN_COMPATIBILITY_VIEW'
  components = @($components | ForEach-Object { [ordered]@{ id=$_.id; status=$_.status; root=$_.root; file_count=$_.file_count; script_count=$_.script_count; latest_runtime_artifact=$_.latest_runtime_artifact; required_files_present=$_.required_files_present; is_required_component=$_.is_required_component; authority_class=$_.authority_class; source_ref=$_.source_ref; needs_triage=$_.needs_triage } })
}
$bodyMapMd = @('# Agent Body Composition Map','','Status: ACTIVE_DERIVED_VIEW',"Branch: $branch","Observed head at generation: $observedHead","Generated: $($activeMap.generated_at)","Body source fingerprint: $($sourceFingerprint.sha256)",'','Canonical JSON: `reports/self_development/SELF_MODEL_ACTIVE_MAP.json`','','## Boundary','','- This is the body composition/status map: what exists, where it is, and latest runtime/proof signal.','- This is not the capability invocation map: how to launch/use skills belongs elsewhere.','- Legacy self_knowledge/roadmap files are references, not the current composition map.','','## Components','')
foreach($c in $components){
  $lastRun = if($null -ne $c.latest_runtime_artifact){ $c.latest_runtime_artifact.path } else { 'none_observed' }
  $bodyMapMd += ("- ``{0}`` - {1}, root ``{2}``, files={3}, scripts={4}, required_present={5}, latest_runtime={6}" -f $c.id,$c.status,$c.root,$c.file_count,$c.script_count,$c.required_files_present,$lastRun)
}
$bodyMapMd += @('', '## Freshness', '', "- Currentness criterion: body source fingerprint", "- Required components present: $($missingRequiredComponents.Count -eq 0)")

$activeMap | ConvertTo-Json -Depth 28 | Set-Content -Path $canonicalMapPath -Encoding UTF8
$bodyMap | ConvertTo-Json -Depth 28 | Set-Content -Path $bodyMapPath -Encoding UTF8
$bodyMapMd -join "`n" | Set-Content -Path $bodyMapMdPath -Encoding UTF8
$result.status = 'MAP_REFRESHED'
$result.map_contains_required_components = ($missingRequiredComponents.Count -eq 0)
$result.missing_required_components = @($missingRequiredComponents)
$result.build_result = [ordered]@{ result = $(if ($missingRequiredComponents.Count -eq 0) { 'PASS' } else { 'PASS_WITH_MISSING_COMPONENTS' }); builder = 'AGENT_BODY_COMPOSITION_MAP_V1'; canonical_composition_map = $result.canonical_composition_map; component_count = $components.Count; required_component_count = @($components | Where-Object { $_.is_required_component -eq $true }).Count; snapshot_imported = $snapshotImported; expanded_candidates_imported = $expandedImported; structural_path_count = $structuralFiles.Count }
$result.refreshed_at = (Get-Date).ToString('o')
$result | ConvertTo-Json -Depth 28 | Set-Content -Path $resultPath -Encoding UTF8
[pscustomobject]$result
