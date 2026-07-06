param(
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [string]$Task = 'Owner asks whether fresh compact school memory can guide a decision after a Real school run.'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$queryTerms='builder factory curriculum learning ladder guard classify validate route compress source ladder no external brain count not learning generated candidates factual knowledge proof active repo body batch checkpoint canonical scheduler'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/query_compact_semantic_memory_v1.ps1 -MemoryRoot $MemoryRoot -Query $queryTerms -Top 12 *>&1 | ForEach-Object {[string]$_})
$out | ForEach-Object { Write-Host "RECALL|$_" }
if(-not ($out -contains 'MEMORY_RECALL_STATUS=PASS_COMPACT_MEMORY_RECALL_V1')){ throw 'RECALL_FAILED' }
$labels=@()
foreach($line in $out){ if($line -match '^MATCH\|\d+\|.*\|label=([^|]+\|[^|]+\|[^|]+)\|'){ $labels += $Matches[1] } }
$hasSourceLadder=@($labels | Where-Object { $_ -match 'source_ladder' }).Count -gt 0
$hasNoExternal=@($labels | Where-Object { $_ -match 'no_external_brain' }).Count -gt 0
$hasCountNotLearning=@($labels | Where-Object { $_ -match 'count_not_learning' }).Count -gt 0
$baselineDecision='GENERIC_UNGUARDED_NO_COMPACT_MEMORY_USED'
if($hasSourceLadder -and ($hasNoExternal -or $hasCountNotLearning)){
  $decision='BLOCK_AS_WORLD_KNOWLEDGE_REQUIRE_SOURCE_ACQUISITION'
} elseif($labels.Count -gt 0) {
  $decision='GUARDED_BY_COMPACT_MEMORY_RECALL'
} else {
  $decision='INSUFFICIENT_MEMORY_FOR_DECISION'
}
$behaviorDelta=($labels.Count -gt 0 -and $decision -ne $baselineDecision -and $decision -ne 'INSUFFICIENT_MEMORY_FOR_DECISION')
if($behaviorDelta){ $status='VALIDATION_PASS=COMPACT_MEMORY_RECALL_USE_PROBE_V1_VALID' } else { $status='VALIDATION_FAIL=COMPACT_MEMORY_RECALL_USE_PROBE_V1' }
$report=[ordered]@{
  schema='compact_memory_recall_use_probe_v1'
  status=$status
  task=$Task
  query_terms=$queryTerms
  used_labels=@($labels)
  has_source_ladder=$hasSourceLadder
  has_no_external_brain=$hasNoExternal
  has_count_not_learning=$hasCountNotLearning
  baseline_decision=$baselineDecision
  active_decision=$decision
  decision=$decision
  behavior_delta=$behaviorDelta
  behavior_delta_definition='baseline generic/unguarded handling changes to a guarded decision only when compact memory cells are recalled and injected into decision context; source-boundary block is used when source/no-external/count-not-learning cells exist'
  boundary='This proves read-only recall/use from compact memory for a decision probe. It does not prove live autonomous behavior.'
  runtime_ready=$false
}
$proofDir='.runtime/memory_use_probes'
if(-not (Test-Path $proofDir)){ New-Item -ItemType Directory -Force $proofDir | Out-Null }
$proofPath=Join-Path $proofDir ('COMPACT_MEMORY_RECALL_USE_PROBE_V1_' + (Get-Date -Format yyyyMMdd_HHmmss) + '.json')
$report | ConvertTo-Json -Depth 60 | Set-Content -Path $proofPath -Encoding UTF8
Write-Host $status
Write-Host "PROOF_PATH=$proofPath"
Write-Host "TASK=$Task"
Write-Host "BASELINE_DECISION=$baselineDecision"
Write-Host "ACTIVE_DECISION=$decision"
Write-Host "DECISION=$decision"
Write-Host "BEHAVIOR_DELTA=$behaviorDelta"
Write-Host "HAS_SOURCE_LADDER=$hasSourceLadder"
Write-Host "HAS_NO_EXTERNAL_BRAIN=$hasNoExternal"
Write-Host "HAS_COUNT_NOT_LEARNING=$hasCountNotLearning"
Write-Host "USED_LABELS=$($labels -join ';')"
Write-Host 'RUNTIME_READY=false'
if(-not $behaviorDelta){ exit 2 }