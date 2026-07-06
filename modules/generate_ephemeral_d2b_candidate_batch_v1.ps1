param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [ValidateRange(1, 10000)]
  [int]$Count = 100,
  [string]$OutputRoot = '.runtime',
  [string]$BatchId = ''
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

function ConvertTo-GeneratorFullPath {
  param([string]$Root, [string]$Path)
  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }
  return [System.IO.Path]::GetFullPath((Join-Path $Root $Path))
}

function Get-GeneratorRelativePath {
  param([string]$Root, [string]$Path)
  $rootFull = [System.IO.Path]::GetFullPath($Root).TrimEnd('\','/')
  $pathFull = [System.IO.Path]::GetFullPath($Path)
  if (-not $pathFull.StartsWith($rootFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)) {
    return $Path
  }
  return ($pathFull.Substring($rootFull.Length + 1) -replace '\\', '/')
}

function New-EphemeralD2BCandidate {
  param(
    [string]$BatchId,
    [int]$Index
  )

  $ordinal = '{0:d4}' -f $Index
  $candidateId = "ephemeral_d2b_candidate_${BatchId}_$ordinal"
  $atomId = "ephemeral.d2b.atom.$BatchId.$ordinal"
  return [ordered]@{
    candidate_id = $candidateId
    concept_id = "ephemeral_d2b_concept_$ordinal"
    target_atom_id_suggestion = $atomId
    explanation = "Ephemeral direct D2B candidate $ordinal generated for a bounded candidate-to-atom absorption trial."
    atom_type_suggestion = "concept"
    guided_example = "When the direct ephemeral candidate circuit is used, this candidate is absorbed through the old D2B runner and then removed after successful retention."
    check_prompt = "Confirm that candidate $ordinal reaches accepted atom surfaces through the existing D2B policy, executor, and finalizer path."
    expected_check_result = "PASS"
    behavior_change = "The builder can consume generated ephemeral candidate fuel without preserving raw shard material."
    next_layer_questions = @(
      "Can the next trial keep the same direct path while adding stronger candidate usefulness checks?",
      "Can successful candidate fuel remain untracked after atom retention receipts are emitted?"
    )
    source = "EPHEMERAL_D2B_CANDIDATE_BATCH_GENERATOR_V1"
    provenance = "direct_candidate_to_atom_circuit"
    producer_id = "generate_ephemeral_d2b_candidate_batch_v1"
    source_kind = "ephemeral_candidate"
    source_run_id = $BatchId
    dedup_key = "ephemeral_d2b_candidate_$BatchId`_$ordinal"
    domain = "agent_builder_self_development"
    priority = "bounded_trial"
    dependencies = @()
    batch_id = $BatchId
    risk_level = "LOW"
    risk_flags = @("none_identified_at_material_stage")
    risk_flag = "none_identified_at_material_stage"
    validator_required = $true
    requires_school_acceptance = $true
    requires_c2b_guard = $true
    requires_phase162_acceptance = $true
    accepted = $false
    trusted = $false
  }
}

$root = (Resolve-Path $RepoRoot).Path
$outputFull = ConvertTo-GeneratorFullPath -Root $root -Path $OutputRoot
$runtimeFull = [System.IO.Path]::GetFullPath((Join-Path $root '.runtime')).TrimEnd('\','/')
$outputTrimmed = $outputFull.TrimEnd('\','/')
if (-not ($outputTrimmed.Equals($runtimeFull, [System.StringComparison]::OrdinalIgnoreCase) -or
    $outputTrimmed.StartsWith($runtimeFull + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase))) {
  throw "EPHEMERAL_OUTPUT_ROOT_MUST_BE_UNDER_RUNTIME=$outputFull"
}

if ([string]::IsNullOrWhiteSpace($BatchId)) {
  $BatchId = (Get-Date).ToUniversalTime().ToString('yyyyMMddHHmmss')
}
$safeBatchId = $BatchId -replace '[^A-Za-z0-9_]', '_'
$batchRoot = Join-Path $outputFull "ephemeral_candidate_batch_$safeBatchId"
New-Item -ItemType Directory -Force -Path $batchRoot | Out-Null

$batchPath = Join-Path $batchRoot 'candidate_batch.jsonl'
if (Test-Path -LiteralPath $batchPath) {
  Remove-Item -LiteralPath $batchPath -Force
}

for ($i = 1; $i -le $Count; $i += 1) {
  $candidate = New-EphemeralD2BCandidate -BatchId $safeBatchId -Index $i
  $line = $candidate | ConvertTo-Json -Depth 60 -Compress
  [System.IO.File]::AppendAllText($batchPath, $line + "`n", [System.Text.UTF8Encoding]::new($false))
}

$result = [ordered]@{
  schema = 'EPHEMERAL_D2B_CANDIDATE_BATCH_GENERATOR_RESULT_V1'
  status = 'PASS'
  created_utc = (Get-Date).ToUniversalTime().ToString('o')
  batch_id = $safeBatchId
  count = $Count
  candidate_batch_path = (Get-GeneratorRelativePath -Root $root -Path $batchPath)
  candidate_batch_full_path = $batchPath
  runtime_ready = $false
}

$result | ConvertTo-Json -Depth 20
