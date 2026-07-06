param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path,
  [string]$ReportRoot = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function Ensure-Dir {
  param([string]$Path)
  if ($Path -and -not (Test-Path -LiteralPath $Path)) {
    New-Item -ItemType Directory -Force -Path $Path | Out-Null
  }
}

function Write-J {
  param([string]$Path, [object]$Object)
  Ensure-Dir (Split-Path -Parent $Path)
  $Object | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Read-J {
  param([string]$Path)
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_FILE=$Path" }
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (-not $Condition) { throw $Message }
}

function Assert-ParserPass {
  param([string]$Path, [string]$Label)
  $tokens = $null
  $errors = $null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $Path).Path, [ref]$tokens, [ref]$errors) | Out-Null
  if ($errors.Count -gt 0) {
    throw "PARSER_FAIL_$Label=$((@($errors | ForEach-Object { $_.Message })) -join '; ')"
  }
}

function Get-ProtectedHashSnapshot {
  param([string]$Root, [string[]]$Paths)
  $snapshot = [ordered]@{}
  foreach ($rel in $Paths) {
    $full = Join-Path $Root $rel
    if (Test-Path -LiteralPath $full) {
      $snapshot[$rel] = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
    } else {
      $snapshot[$rel] = 'ABSENT'
    }
  }
  return $snapshot
}

function Assert-SnapshotUnchanged {
  param($Before, $After, [string[]]$Paths)
  foreach ($rel in $Paths) {
    Assert-True ($Before[$rel] -eq $After[$rel]) "PROTECTED_SURFACE_CHANGED=$rel"
  }
}

function Copy-FixtureFile {
  param([string]$SourceRoot, [string]$FixtureRoot, [string]$RelativePath)
  $source = Join-Path $SourceRoot $RelativePath
  $target = Join-Path $FixtureRoot $RelativePath
  Ensure-Dir (Split-Path -Parent $target)
  Copy-Item -LiteralPath $source -Destination $target -Force
}

$sourceRoot = (Resolve-Path $RepoRoot).Path
if ([string]::IsNullOrWhiteSpace($ReportRoot)) {
  $ReportRoot = Join-Path $sourceRoot ("reports/lab_r4_hygiene_04b_short_work_root_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
}
$reportFull = if ([System.IO.Path]::IsPathRooted($ReportRoot)) {
  [System.IO.Path]::GetFullPath($ReportRoot)
} else {
  [System.IO.Path]::GetFullPath((Join-Path $sourceRoot $ReportRoot))
}

$fixtureRoot = Join-Path $reportFull 'fixture_repo'
$inputRootRel = 'reports/self_development/phase165s_d2_big_curriculum_material_factory'
$outputRootRel = 'reports/self_development/phase165s_d2b_big_curriculum_autonomous_learning'
$shortWorkBase = Join-Path ([System.IO.Path]::GetTempPath()) ("efab_r4_hygiene_04b_short_work_root_{0}" -f (Get-Date -Format 'yyyyMMdd_HHmmss'))
$effectiveWorkRoot = Join-Path $shortWorkBase 'phase165s_d2b_work_current'
$runnerPath = Join-Path $sourceRoot 'modules/run_phase165s_d2b_big_curriculum_autonomous_learn_until_empty_001.ps1'
$smokePath = $PSCommandPath

$protectedAcceptedSurfaces = @(
  'packs/registry.json',
  'reports/self_development/accepted_change_memory_snapshot.json',
  'reports/self_development/SELF_MODEL_ACTIVE_MAP.json',
  'reports/self_development/agent_body_map.json'
)
$protectedBefore = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedAcceptedSurfaces

Ensure-Dir $fixtureRoot
Ensure-Dir (Join-Path $fixtureRoot 'modules')
Ensure-Dir (Join-Path $fixtureRoot 'packs')
Ensure-Dir (Join-Path $fixtureRoot 'reports/self_development')
Ensure-Dir (Join-Path $fixtureRoot "$inputRootRel/raw_shards")
Ensure-Dir $shortWorkBase

Copy-FixtureFile -SourceRoot $sourceRoot -FixtureRoot $fixtureRoot -RelativePath 'modules/evaluate_phase165s_c2_bounded_autonomous_atom_acceptance_policy_001.ps1'
Copy-FixtureFile -SourceRoot $sourceRoot -FixtureRoot $fixtureRoot -RelativePath 'modules/invoke_phase162_execute_controlled_accept_core_mutation_for_atom_batch_001.ps1'
Copy-FixtureFile -SourceRoot $sourceRoot -FixtureRoot $fixtureRoot -RelativePath 'modules/invoke_phase162_controller_consume_controlled_accept_core_mutation_execution_proof_001.ps1'

Write-J (Join-Path $fixtureRoot 'reports/self_development/accepted_change_memory_snapshot.json') ([ordered]@{
  phase162_accepted_atom_memory_records = @()
})
Write-J (Join-Path $fixtureRoot 'reports/self_development/SELF_MODEL_ACTIVE_MAP.json') ([ordered]@{
  phase162_absorbed_atom_capability_notes = @()
})
Write-J (Join-Path $fixtureRoot 'packs/registry.json') ([ordered]@{
  phase162_accepted_atom_references = @()
})

$shardRel = "$inputRootRel/raw_shards/curriculum_candidates_00001.jsonl"
Write-J (Join-Path $fixtureRoot "$inputRootRel/school_ready_manifest.json") ([ordered]@{
  schema = 'PHASE165S_D2A_BIG_CURRICULUM_SCHOOL_READY_MANIFEST_V1'
  total_candidate_count = 1
  safe_candidate_count = 1
  quarantine_candidate_count = 0
  shard_paths = @($shardRel)
})
Write-J (Join-Path $fixtureRoot "$inputRootRel/material_bank_index.json") ([ordered]@{
  schema = 'PHASE165S_D2A_BIG_CURRICULUM_MATERIAL_BANK_INDEX_V1'
  total_candidate_count = 1
  shard_count = 1
})

$candidate = [ordered]@{
  candidate_id = 'R4_HYGIENE_04B_SHORT_WORK_ROOT_SAFE_CANDIDATE_001'
  concept_id = 'r4_hygiene_04b.short_work_root.safe_candidate'
  target_atom_id_suggestion = 'r4.hygiene.04b.short_work_root.safe_candidate.v1'
  explanation = 'Fixture candidate proving D2B can keep transient package work under an explicit short work root.'
  atom_type_suggestion = 'proof_atom'
  guided_example = 'Use explicit WorkRoot for transient controller and execution packages while OutputRoot keeps logs and summaries.'
  check_prompt = 'Does D2B put candidate, controller, execution, and finalizer files under the explicit work root?'
  expected_check_result = 'TRANSIENT_WORK_ROOT_FIELDS_AND_FILES_PRESENT'
  behavior_change = 'D2B can avoid deep OutputRoot work/current paths without changing learning semantics.'
  next_layer_questions = @('Can resume enforce the same work root?', 'Can env EFAB_WORK_ROOT follow the same contract?')
  source = 'R4_HYGIENE_04B_FIXTURE'
  provenance = 'R4_HYGIENE_04B_SHORT_WORK_ROOT_SMOKE'
  accepted = $false
  trusted = $false
  risk_level = 'LOW'
  risk_flags = @('none_identified_at_material_stage')
  requires_school_acceptance = $true
  requires_c2b_guard = $true
  requires_phase162_acceptance = $true
}
($candidate | ConvertTo-Json -Depth 60 -Compress) | Set-Content -LiteralPath (Join-Path $fixtureRoot $shardRel) -Encoding UTF8

if (Get-Command git -ErrorAction SilentlyContinue) {
  & git -C $fixtureRoot init | Out-Null
  & git -C $fixtureRoot -c user.name='R4 Hygiene Smoke' -c user.email='r4-hygiene-smoke@example.invalid' add . | Out-Null
  & git -C $fixtureRoot -c user.name='R4 Hygiene Smoke' -c user.email='r4-hygiene-smoke@example.invalid' commit -m 'r4 hygiene 04b fixture baseline' | Out-Null
}

Assert-ParserPass -Path $runnerPath -Label 'RUNNER'
Assert-ParserPass -Path $smokePath -Label 'SMOKE'
$parserChecks = [ordered]@{
  runner = 'PASS'
  smoke = 'PASS'
}

$runnerOutput = @(& $runnerPath `
  -RepoRoot $fixtureRoot `
  -InputRoot $inputRootRel `
  -OutputRoot $outputRootRel `
  -WorkRoot $shortWorkBase `
  -CheckpointEvery 1 `
  -HeartbeatEvery 1 `
  -EmitJson)

$outputFull = Join-Path $fixtureRoot $outputRootRel
$summaryPath = Join-Path $outputFull 'final_summary.json'
$summary = Read-J $summaryPath

Assert-True ([string]$summary.status -eq 'PASS_QUEUE_EMPTY') "UNEXPECTED_FINAL_STATUS=$($summary.status)"
Assert-True ([string]$summary.work_root_mode -eq 'explicit') "WORK_ROOT_MODE_NOT_EXPLICIT=$($summary.work_root_mode)"
Assert-True ([bool]$summary.work_root_short_path_enabled -eq $true) 'SHORT_WORK_ROOT_NOT_ENABLED'
Assert-True ([System.IO.Path]::GetFullPath([string]$summary.work_root).Equals([System.IO.Path]::GetFullPath($effectiveWorkRoot), [System.StringComparison]::OrdinalIgnoreCase)) "WORK_ROOT_SUMMARY_MISMATCH=$($summary.work_root)"

$legacyWorkCurrent = Join-Path $outputFull 'work/current'
$transientChecks = [ordered]@{
  marker = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot '.efab_d2b_workroot')
  policy_candidate = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'policy_candidate.json')
  policy_result = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'policy_result.json')
  candidate_package = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'cand/controlled_accept_core_mutation_candidate_result.json')
  controller_package = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'ctrl/one_shot_controlled_accept_core_mutation_execution_authorization_for_atom_batch.json')
  execution_package = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'exec/execute_controlled_accept_core_mutation_result.json')
  finalizer_package = Test-Path -LiteralPath (Join-Path $effectiveWorkRoot 'fin/controller_consume_controlled_accept_core_mutation_execution_proof_result.json')
  legacy_output_work_current_absent = (-not (Test-Path -LiteralPath $legacyWorkCurrent))
}
foreach ($key in @($transientChecks.Keys)) {
  Assert-True ([bool]$transientChecks[$key]) "TRANSIENT_CHECK_FAILED=$key"
}

$outputChecks = [ordered]@{
  queue_state = Test-Path -LiteralPath (Join-Path $outputFull 'queue_state.json')
  resume_state = Test-Path -LiteralPath (Join-Path $outputFull 'resume_state.json')
  heartbeat = Test-Path -LiteralPath (Join-Path $outputFull 'heartbeat.json')
  final_summary = Test-Path -LiteralPath $summaryPath
  accepted_log = Test-Path -LiteralPath (Join-Path $outputFull 'accepted_log.jsonl')
  checkpoints = Test-Path -LiteralPath (Join-Path $outputFull 'checkpoints')
}
foreach ($key in @($outputChecks.Keys)) {
  Assert-True ([bool]$outputChecks[$key]) "OUTPUT_CHECK_FAILED=$key"
}

$protectedAfter = Get-ProtectedHashSnapshot -Root $sourceRoot -Paths $protectedAcceptedSurfaces
Assert-SnapshotUnchanged -Before $protectedBefore -After $protectedAfter -Paths $protectedAcceptedSurfaces

$proofPath = Join-Path $reportFull 'R4_HYGIENE_04B_SHORT_WORK_ROOT_PROOF.json'
$reportPath = Join-Path $reportFull 'R4_HYGIENE_04B_SHORT_WORK_ROOT_REPORT.md'
$proof = [ordered]@{
  status = 'PASS'
  task = 'R4-HYGIENE-04B'
  created_at = (Get-Date -Format o)
  fixture_root = $fixtureRoot
  report_root = $reportFull
  runner_path = $runnerPath
  runner_output = @($runnerOutput)
  output_root = $outputFull
  final_summary_path = $summaryPath
  work_root_base = $shortWorkBase
  effective_work_root = $effectiveWorkRoot
  summary_fields = [ordered]@{
    work_root = [string]$summary.work_root
    work_root_mode = [string]$summary.work_root_mode
    work_root_short_path_enabled = [bool]$summary.work_root_short_path_enabled
  }
  parser_checks = $parserChecks
  transient_checks = $transientChecks
  output_checks = $outputChecks
  protected_accepted_surfaces_checked = $protectedAcceptedSurfaces
  protected_hashes_before = $protectedBefore
  protected_hashes_after = $protectedAfter
  real_accepted_surfaces_unchanged = $true
}
Write-J $proofPath $proof

@"
# R4-HYGIENE-04B Short Work Root Smoke

Status: PASS

- fixture_root: $fixtureRoot
- output_root: $outputFull
- work_root_base: $shortWorkBase
- effective_work_root: $effectiveWorkRoot
- final_summary: $summaryPath
- proof: $proofPath

The smoke ran the real D2B runner with explicit -WorkRoot and verified transient package files were written under the D2B-specific short work root. OutputRoot retained state, logs, checkpoints, heartbeat, and final_summary. Real accepted core surfaces in the source repo were hash-checked before and after and were unchanged.
"@ | Set-Content -LiteralPath $reportPath -Encoding UTF8

Write-Host 'R4_HYGIENE_04B_SHORT_WORK_ROOT_SMOKE_RESULT=PASS'
Write-Host "REPORT_ROOT=$reportFull"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "REPORT_PATH=$reportPath"
Write-Host "EFFECTIVE_WORK_ROOT=$effectiveWorkRoot"
