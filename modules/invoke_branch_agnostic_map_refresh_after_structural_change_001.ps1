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
  return $null
}

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
$trackedFiles = Get-GitLines (@('ls-files','--') + $BoundedEvidencePathspecs)
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
  required_components = @('school','school_source_router','compact_memory_intake','autonomous_inner_motor','knowledge_acquisition_port','map_control','gpt_handoff')
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

function ConvertTo-BodyComponentId([string]$Value) {
  if([string]::IsNullOrWhiteSpace($Value)){ return $null }
  $v = $Value.Trim().ToLowerInvariant() -replace '[^a-z0-9]+','_'
  $v = $v.Trim('_')
  if([string]::IsNullOrWhiteSpace($v)){ return $null }
  return $v
}

function Test-PathUnderRoot([string]$Path, [string]$RootPath) {
  $p = $Path -replace '\\','/'
  $r = ($RootPath -replace '\\','/').TrimEnd('/')
  return ($p -eq $r -or $p.StartsWith($r + '/'))
}

function Get-TrackedFilesUnderRoot([string]$RootPath) {
  return @($trackedFiles | Where-Object { Test-PathUnderRoot $_ $RootPath })
}

function Get-EvidenceRefsForRoot([string]$RootPath, [string]$Pattern, [int]$Limit = 30) {
  return @($trackedFiles | Where-Object { (Test-PathUnderRoot $_ $RootPath) -and ($_ -match $Pattern) } | Sort-Object -Unique | Select-Object -First $Limit)
}

function New-ConfirmedComponent([string]$Id, [string]$RootPath, [string[]]$RequiredFiles, [string]$Role) {
  $files = Get-TrackedFilesUnderRoot $RootPath
  $scripts = @($files | Where-Object { $_.EndsWith('.ps1') })
  $validators = Get-EvidenceRefsForRoot $RootPath '(?i)(validate|validation)'
  $proofs = Get-EvidenceRefsForRoot $RootPath '(?i)(/proofs?/|_PROOF|PROOF_)'
  $contracts = Get-EvidenceRefsForRoot $RootPath '(?i)(contract|policy)'
  $docs = @($files | Where-Object { $_.EndsWith('.md') })
  $missing = @($RequiredFiles | Where-Object { -not (Test-Path -LiteralPath $_ -PathType Leaf) })
  $primaryRefs = @($RequiredFiles | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf })
  $primaryRefs += @($validators | Select-Object -First 10)
  $primaryRefs += @($proofs | Select-Object -First 10)
  $primaryRefs += @($contracts | Select-Object -First 10)
  return [ordered]@{
    id = $Id
    role = $Role
    root = $RootPath
    status = $(if($files.Count -gt 0 -and $missing.Count -eq 0){ 'CONFIRMED_PRIMARY_EVIDENCE_PRESENT' } else { 'CONFIRMED_REQUIRED_COMPONENT_WITH_GAPS' })
    confirmation_basis = 'explicit_required_component_with_primary_repo_evidence'
    file_count = $files.Count
    script_count = $scripts.Count
    validator_count = $validators.Count
    proof_file_count = $proofs.Count
    contract_or_policy_count = $contracts.Count
    doc_count = $docs.Count
    required_files = @($RequiredFiles)
    missing_required_files = @($missing)
    required_files_present = ($missing.Count -eq 0)
    validator_refs = @($validators)
    proof_refs = @($proofs)
    contract_or_policy_refs = @($contracts)
    primary_evidence_refs = @($primaryRefs | Sort-Object -Unique)
    entrypoint_scripts = @($scripts | Where-Object { $_ -match '(?i)(run_|control_|merge_|submit_|ask_|finalize_|validate_)' } | Select-Object -First 40)
    latest_git_commit = Get-LatestGitCommitForPath $RootPath
    latest_runtime_artifact = $null
    runtime_evidence_inspected = $false
    is_required_component = $true
    authority_class = 'CONFIRMED_REQUIRED_PRIMARY_EVIDENCE'
    source_ref = 'generator_required_component_registry_v2'
    needs_triage = $false
  }
}

function Get-CandidateRootFromPath([string]$Path) {
  $p = $Path -replace '\\','/'
  $parts = @($p -split '/')
  if($parts.Count -lt 2){ return $null }
  switch ($parts[0]) {
    'operations' {
      if($parts.Count -ge 2){ return "operations/$($parts[1])" }
    }
    'modules' {
      if($parts.Count -ge 3){ return "modules/$($parts[1])" }
    }
    'self_model' {
      if($parts.Count -ge 3){ return "self_model/$($parts[1])" }
    }
    'contracts' {
      if($parts.Count -ge 3){ return "contracts/$($parts[1])" }
    }
    'living_learning_environment' {
      if($parts.Count -ge 3){ return "living_learning_environment/$($parts[1])" }
    }
    'self_build_programs' {
      if($parts.Count -ge 3){ return "self_build_programs/$($parts[1])" }
    }
    'packs' {
      if($parts.Count -ge 3){ return "packs/$($parts[1])" }
    }
    default { return $null }
  }
  return $null
}

function Test-RootCoveredByConfirmed([string]$CandidateRoot, [object[]]$ConfirmedComponents) {
  foreach($component in $ConfirmedComponents) {
    if(Test-PathUnderRoot $CandidateRoot ([string]$component.root)) { return $true }
    if(Test-PathUnderRoot ([string]$component.root) $CandidateRoot) { return $true }
  }
  return $false
}

function New-PrimaryEvidenceCandidate([string]$RootPath) {
  $files = Get-TrackedFilesUnderRoot $RootPath
  $scripts = @($files | Where-Object { $_.EndsWith('.ps1') })
  $validators = @($files | Where-Object { $_ -match '(?i)(validate|validation)' } | Sort-Object -Unique | Select-Object -First 20)
  $proofs = @($files | Where-Object { $_ -match '(?i)(/proofs?/|_PROOF|PROOF_)' } | Sort-Object -Unique | Select-Object -First 20)
  $contracts = @($files | Where-Object { $_ -match '(?i)(contract|policy)' } | Sort-Object -Unique | Select-Object -First 20)
  $docs = @($files | Where-Object { $_.EndsWith('.md') })
  $id = ConvertTo-BodyComponentId $RootPath
  return [ordered]@{
    id = $id
    path = $RootPath
    root = $RootPath
    status = 'PRIMARY_EVIDENCE_CANDIDATE_NEEDS_TRIAGE'
    discovery_method = 'bounded_git_ls_files_path_discovery'
    evidence_counts = [ordered]@{
      files = $files.Count
      scripts = $scripts.Count
      validators = $validators.Count
      proofs = $proofs.Count
      contracts_or_policies = $contracts.Count
      docs = $docs.Count
    }
    file_count = $files.Count
    script_count = $scripts.Count
    validator_count = $validators.Count
    proof_file_count = $proofs.Count
    contract_or_policy_count = $contracts.Count
    doc_count = $docs.Count
    validator_refs = @($validators)
    proof_refs = @($proofs)
    contract_or_policy_refs = @($contracts)
    notable_files = @($files | Select-Object -First 25)
    primary_evidence_refs = @(@($validators) + @($proofs) + @($contracts) + @($scripts | Select-Object -First 10) | Sort-Object -Unique)
    needs_triage = $true
    authority_class = 'PRIMARY_EVIDENCE_CANDIDATE_REPO_DISCOVERED'
    source_ref = 'bounded_tracked_file_discovery_v1'
    is_required_component = $false
  }
}

$requiredComponentSpecs = @(
  [ordered]@{ id='school'; root='operations/school'; required=@('operations/school/run_agent_school.ps1','operations/school/finalize_agent_school_run_v1.ps1','operations/school/SCHOOL_CANONICAL_RUN_CONTRACT_V1.md'); role='candidate learning factory and school lifecycle' },
  [ordered]@{ id='school_source_router'; root='operations/school/curriculum/source_router'; required=@('operations/school/curriculum/source_router/run_school_source_router_v1.ps1','operations/school/curriculum/source_router/run_school_codex_source_port_v1.ps1','operations/school/curriculum/source_router/run_school_external_world_source_port_v1.ps1','operations/school/curriculum/source_router/template_filter/run_school_source_template_filter_v1.ps1','operations/school/curriculum/source_router/template_filter/school_source_template_filter_policy.json'); role='governed source selection before school material intake' },
  [ordered]@{ id='compact_memory_intake'; root='operations/compact_memory_intake'; required=@('operations/compact_memory_intake/submit_compact_memory_packet_v1.ps1','operations/compact_memory_intake/merge_compact_memory_intake_queue_v1.ps1','operations/compact_memory_intake/run_compact_memory_queue_maintenance_v1.ps1'); role='only governed packet/intake/merge path into compact memory' },
  [ordered]@{ id='autonomous_inner_motor'; root='operations/autonomous_inner_motor'; required=@('operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'); role='bounded inner motor / test life runtime surface' },
  [ordered]@{ id='knowledge_acquisition_port'; root='operations/knowledge_acquisition_port'; required=@('operations/knowledge_acquisition_port/ask_codex_knowledge_source.ps1','operations/knowledge_acquisition_port/ask_codex_batch_knowledge_source.ps1'); role='bounded knowledge acquisition material port' },
  [ordered]@{ id='map_control'; root='operations/map_control'; required=@('operations/map_control/BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT.md','operations/map_control/branch_agnostic_map_refresh_policy.json'); role='map governance / freshness contract' },
  [ordered]@{ id='operations_self_model'; root='operations/self_model'; required=@('operations/self_model/validate_operations_self_model_organ_lab_validation_v1.ps1','reports/self_development/OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1.json','tests/self_development/OPERATIONS_SELF_MODEL_ORGAN_LAB_VALIDATION_V1_PROOF.json','self_model/organ_passports/operations_self_model/ORGAN_PASSPORT_V1.json'); role='validated lab self-model/map/passport governance organ' },
  [ordered]@{ id='gpt_handoff'; root='operations/gpt_handoff'; required=@('operations/gpt_handoff/GPT_OPERATOR_JOURNAL.md'); role='GPT/operator compact handoff surface' }
)
$confirmedComponents = @($requiredComponentSpecs | ForEach-Object { New-ConfirmedComponent $_.id $_.root $_.required $_.role })
$candidateRootSet = @{}
foreach($path in $trackedFiles) {
  $candidateRoot = Get-CandidateRootFromPath $path
  if([string]::IsNullOrWhiteSpace($candidateRoot)){ continue }
  if(Test-RootCoveredByConfirmed $candidateRoot $confirmedComponents){ continue }
  $candidateRootSet[$candidateRoot] = $true
}
$primaryEvidenceCandidates = @(
  $candidateRootSet.Keys |
    Sort-Object |
    ForEach-Object { New-PrimaryEvidenceCandidate $_ } |
    Where-Object {
      $_.file_count -gt 0 -and
      ($_.script_count + $_.validator_count + $_.proof_file_count + $_.contract_or_policy_count + $_.doc_count) -gt 0
    }
)
$legacyHints = @(
  [ordered]@{ path='self_knowledge/BUILDER_SELF_MODEL.json'; classification='LEGACY_BROAD_SELF_MODEL_HINT_ONLY'; raw_authority=$false; read_by_generator=$false; allowed_use='bounded hint/reference only; never creates confirmed components' },
  [ordered]@{ path='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'; classification='LEGACY_PARALLEL_SNAPSHOT_HINT_ONLY'; raw_authority=$false; read_by_generator=$false; allowed_use='bounded hint/reference only; never creates confirmed components' },
  [ordered]@{ path='CAPABILITY_ROADMAP.json'; classification='CAPABILITY_ROADMAP_NOT_BODY_COMPOSITION_AUTHORITY'; raw_authority=$false; read_by_generator=$false; allowed_use='separate capability context only' },
  [ordered]@{ path='GENESIS_STATE.json'; classification='GENESIS_STATE_NOT_BODY_COMPOSITION_AUTHORITY'; raw_authority=$false; read_by_generator=$false; allowed_use='genesis/static context only' }
)
$rejectedHints = @(
  [ordered]@{ hint='child_agent_factory'; source_hint='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json#child_agent_factory'; rejection_reason='legacy snapshot hint cannot prove live child-agent factory readiness'; child_agent_factory_readiness='NOT_PROVEN'; raw_authority=$false },
  [ordered]@{ hint='legacy_self_knowledge_inventory_counts'; source_hint='self_knowledge/BUILDER_SELF_MODEL.json'; rejection_reason='legacy broad inventory is not primary body-map evidence'; raw_authority=$false },
  [ordered]@{ hint='current_body_capability_snapshot_components'; source_hint='reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json'; rejection_reason='older parallel snapshot is not canonical active behavior absorption evidence'; raw_authority=$false }
)

$missingRequiredComponents = @($confirmedComponents | Where-Object { -not $_.required_files_present } | ForEach-Object { $_.id })
$allComponents = @($confirmedComponents) + @($primaryEvidenceCandidates)
$canonicalMapPath = Join-Path $outputFull 'SELF_MODEL_ACTIVE_MAP.json'
$bodyMapPath = Join-Path $outputFull 'agent_body_map.json'
$bodyMapMdPath = Join-Path $outputFull 'agent_body_map.md'
$generatedAt = (Get-Date).ToString('o')
$authoritySummary = [ordered]@{
  confirmed_components = $confirmedComponents.Count
  primary_evidence_candidates = $primaryEvidenceCandidates.Count
  legacy_unverified_hints = $legacyHints.Count
  rejected_or_stale_hints = $rejectedHints.Count
  required_components = $requiredComponentSpecs.Count
  total_components_in_compatibility_view = $allComponents.Count
  bounded_discovery_pathspecs = @($BoundedEvidencePathspecs)
  discovery_command = 'git ls-files -- operations modules validators self_model contracts living_learning_environment self_build_programs packs docs/operations reports/self_development tests/self_development'
  legacy_maps_raw_authority = $false
  old_maps_read_as_authority = $false
  legacy_maps_are_hints_not_authority = $true
  passport_generator_blocked_until_candidate_triage = $true
  child_agent_factory_readiness = 'NOT_PROVEN'
  files_changed_before_preflight_pass = $false
  live_process_inspected = $false
  live_process_touched = $false
}

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
  generated_at = $generatedAt
  generator = 'modules/invoke_branch_agnostic_map_refresh_after_structural_change_001.ps1'
  generated_by_auto_refresh = $true
  role = 'canonical local body composition/status map built from primary repo evidence and bounded tracked-file discovery'
  trigger_reason = $TriggerReason
  canonical_map_path = ($canonicalMapPath.Substring($root.Length).TrimStart([char[]]@([char]92,[char]47)) -replace '\\','/')
  structural_path_count = $structuralFiles.Count
  body_source_fingerprint = $sourceFingerprint
  module_count = $moduleFiles.Count
  validator_count = $validatorFiles.Count
  confirmed_components = @($confirmedComponents)
  primary_evidence_candidates = @($primaryEvidenceCandidates)
  legacy_unverified_hints = @($legacyHints)
  rejected_or_stale_hints = @($rejectedHints)
  component_authority_summary = $authoritySummary
  components = @($allComponents)
  required_components_present = ($missingRequiredComponents.Count -eq 0)
  missing_required_components = @($missingRequiredComponents)
  current_runtime_observation = [ordered]@{
    runtime_evidence_inspected = $false
    live_process_inspected = $false
    live_process_touched = $false
  }
  freshness_rule = 'Trust currentness by body_source_fingerprint over bounded primary evidence files, excluding generated map outputs.'
  boundary = 'This is the single canonical auto-refreshed composition/status map. Confirmed components require explicit current repo evidence. Candidates come from bounded tracked-file discovery and require triage before passport generation, organ acceptance, or child-agent readiness claims.'
}
$bodyMap = [ordered]@{
  schema = 'AGENT_BODY_MAP_COMPATIBILITY_VIEW_V2'
  source = 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json'
  branch = $branch
  observed_head_at_generation = $observedHead
  generated_at = $generatedAt
  body_source_fingerprint = $sourceFingerprint
  map_kind = 'DERIVED_HUMAN_COMPATIBILITY_VIEW'
  confirmed_component_count = $confirmedComponents.Count
  primary_evidence_candidate_count = $primaryEvidenceCandidates.Count
  components = @($allComponents | ForEach-Object { [ordered]@{ id=$_.id; status=$_.status; root=$_.root; file_count=$_.file_count; script_count=$_.script_count; required_files_present=$_.required_files_present; is_required_component=$_.is_required_component; authority_class=$_.authority_class; source_ref=$_.source_ref; needs_triage=$_.needs_triage } })
}
$bodyMapMd = @(
  '# Agent Body Composition Map',
  '',
  'Status: ACTIVE_DERIVED_VIEW',
  "Branch: $branch",
  "Observed head at generation: $observedHead",
  "Generated: $generatedAt",
  "Body source fingerprint: $($sourceFingerprint.sha256)",
  '',
  'Canonical JSON: `reports/self_development/SELF_MODEL_ACTIVE_MAP.json`',
  '',
  '## Boundary',
  '',
  '- Confirmed components come from explicit current repo evidence and required-component declarations.',
  '- Primary evidence candidates come from bounded tracked-file discovery and require triage.',
  '- Legacy maps and prior snapshots are hints only; they do not create confirmed components.',
  '- This is not the capability invocation map.',
  '',
  '## Counts',
  '',
  "- Confirmed components: $($confirmedComponents.Count)",
  "- Primary evidence candidates: $($primaryEvidenceCandidates.Count)",
  "- Legacy unverified hints: $($legacyHints.Count)",
  "- Rejected or stale hints: $($rejectedHints.Count)",
  '',
  '## Confirmed Components',
  ''
)
foreach($c in $confirmedComponents){
  $bodyMapMd += ("- ``{0}`` - {1}, root ``{2}``, files={3}, scripts={4}, required_present={5}" -f $c.id,$c.status,$c.root,$c.file_count,$c.script_count,$c.required_files_present)
}
$bodyMapMd += @('', '## Candidate Triage Queue', '')
foreach($c in @($primaryEvidenceCandidates | Select-Object -First 80)){
  $bodyMapMd += ("- ``{0}`` - root ``{1}``, files={2}, scripts={3}, validators={4}, proofs={5}, needs_triage=True" -f $c.id,$c.root,$c.file_count,$c.script_count,$c.validator_count,$c.proof_file_count)
}
$bodyMapMd += @('', '## Freshness', '', '- Currentness criterion: body source fingerprint over bounded primary evidence files.', "- Required components present: $($missingRequiredComponents.Count -eq 0)")

$activeMap | ConvertTo-Json -Depth 32 | Set-Content -Path $canonicalMapPath -Encoding UTF8
$bodyMap | ConvertTo-Json -Depth 32 | Set-Content -Path $bodyMapPath -Encoding UTF8
$bodyMapMd -join "`n" | Set-Content -Path $bodyMapMdPath -Encoding UTF8
$result.status = 'MAP_REFRESHED'
$result.map_contains_required_components = ($missingRequiredComponents.Count -eq 0)
$result.required_components = @($requiredComponentSpecs.id)
$result.missing_required_components = @($missingRequiredComponents)
$result.build_result = [ordered]@{
  result = $(if ($missingRequiredComponents.Count -eq 0) { 'PASS' } else { 'PASS_WITH_MISSING_COMPONENTS' })
  builder = 'AGENT_BODY_COMPOSITION_MAP_PRIMARY_EVIDENCE_V1'
  canonical_composition_map = $result.canonical_composition_map
  confirmed_component_count = $confirmedComponents.Count
  primary_evidence_candidate_count = $primaryEvidenceCandidates.Count
  legacy_unverified_hint_count = $legacyHints.Count
  rejected_or_stale_hint_count = $rejectedHints.Count
  total_component_count = $allComponents.Count
  structural_path_count = $structuralFiles.Count
  legacy_maps_raw_authority = $false
  old_maps_read_as_authority = $false
  passport_generator_blocked_until_candidate_triage = $true
  child_agent_factory_readiness = 'NOT_PROVEN'
  files_changed_before_preflight_pass = $false
}
$result.refreshed_at = (Get-Date).ToString('o')
$result | ConvertTo-Json -Depth 32 | Set-Content -Path $resultPath -Encoding UTF8
[pscustomobject]$result

