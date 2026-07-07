$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Invoke-ExpectFailure([scriptblock]$Block,[string]$Expected){
  try { & $Block; throw "EXPECTED_FAILURE_NOT_RAISED:$Expected" }
  catch { if($_.Exception.Message -notlike "*$Expected*"){ throw "WRONG_FAILURE:$($_.Exception.Message):EXPECTED:$Expected" } }
}
$writer='operations/memory/episodic/write_episode_cell_v1.ps1'
$proofAimo='tests/live_start/AIMO_GROWTH_SELECTOR_HOTSWAP_V1_PROOF.json'
$proofSelector='tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json'
Assert (Test-Path $writer) 'WRITER_MISSING'
Assert (Test-Path $proofAimo) 'AIMO_PROOF_MISSING'
Assert (Test-Path $proofSelector) 'SELECTOR_PROOF_MISSING'
$outRoot='.runtime/episodic_memory_v1/validator_cells'
Remove-Item $outRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$realArgs=@{
  EpisodeId='aimo_growth_selector_ordered_payload_failure_v1'
  Topic='aimo_growth_selector_ordered_payload_failure'
  Situation='AIMO selector lab validation initially passed, but live hotswap showed fallback selection while growth signal was available.'
  Hypothesis='The selector was reading signal fields in a shape that did not match the live ordered payload.'
  ActionTaken='Added robust selector field access, strengthened validator with ordered dictionary signal case, and repeated AIMO-only hotswap.'
  Result='Live AIMO selected growth-directed tasks with ACTIVE_GROWTH_SIGNAL_TOPIC and ACTIVE_MEMORY_DELTA_FROM_SCHOOL reasons.'
  FailureReason='Initial validator covered PSCustomObject path but not live-shaped ordered payload access.'
  Correction='Validator now extracts helper functions and checks ordered dictionary growth signal routing before acceptance.'
  ReuseHint='When validating selector or memory routing code, include the exact live object shape, not only synthetic PSCustomObject fixtures.'
  Status='REUSABLE_LESSON'
  Confidence='high'
  ProofRefs=@($proofAimo,$proofSelector)
  Tags=@('aimo','selector','validator','ordered_payload','live_hotswap')
  OutputRoot=$outRoot
}
$out=& $writer @realArgs
$cellPath=($out | Where-Object { $_ -like 'EPISODE_CELL_PATH=*' }) -replace '^EPISODE_CELL_PATH=',''
Assert (Test-Path $cellPath) 'REAL_CELL_NOT_WRITTEN'
$cell=Get-Content $cellPath -Raw | ConvertFrom-Json
Assert ($cell.memory_type -eq 'episodic') 'REAL_CELL_MEMORY_TYPE_BAD'
Assert ($cell.raw_trace_included -eq $false) 'REAL_CELL_RAW_TRACE_FLAG_BAD'
Assert (@($cell.proof_refs).Count -eq 2) 'REAL_CELL_PROOF_REF_COUNT_BAD'
Assert ($cell.reuse_hint -like '*live object shape*') 'REAL_CELL_REUSE_HINT_WEAK'
Invoke-ExpectFailure { & $writer -EpisodeId 'missing_proof' -Topic 'validator' -Situation 'x' -Hypothesis 'x' -ActionTaken 'x' -Result 'x' -ReuseHint 'x' -Status 'PROVEN_LIVE' -Confidence 'high' -ProofRefs @('tests/nope/MISSING.json') -OutputRoot $outRoot } 'PROOF_REF_MISSING'
Invoke-ExpectFailure { & $writer -EpisodeId 'raw_dump' -Topic 'validator' -Situation 'stdout_preview managed_run- raw text' -Hypothesis 'x' -ActionTaken 'x' -Result 'x' -ReuseHint 'x' -Status 'HYPOTHESIS_OPEN' -Confidence 'medium' -ProofRefs @($proofSelector) -OutputRoot $outRoot } 'RAW_DUMP_MARKER_IN_FIELD'
Invoke-ExpectFailure { & $writer -EpisodeId 'failed_without_reason' -Topic 'validator' -Situation 'x' -Hypothesis 'x' -ActionTaken 'x' -Result 'x' -ReuseHint 'x' -Status 'HYPOTHESIS_FAILED' -Confidence 'medium' -ProofRefs @($proofSelector) -OutputRoot $outRoot } 'FAILED_EPISODE_REQUIRES_FAILURE_REASON'
# Volume: 50 compact synthetic cells plus real cell, then simple retrieval by key terms must find real cell.
for($i=1;$i -le 50;$i++){
  & $writer -EpisodeId ("synthetic_episode_$i") -Topic "synthetic validator memory $i" -Situation "Synthetic compact episode $i for volume parser validation." -Hypothesis 'Compact episodic cells should remain parseable at volume.' -ActionTaken 'Wrote a bounded synthetic episode cell.' -Result 'Cell written for volume validation.' -ReuseHint 'Use bounded cells, not raw logs.' -Status 'HYPOTHESIS_SUPPORTED' -Confidence 'medium' -ProofRefs @($proofSelector) -Tags @('synthetic','volume') -OutputRoot $outRoot | Out-Null
}
$cells=@(Get-ChildItem $outRoot -File -Filter '*.json')
Assert ($cells.Count -ge 51) 'VOLUME_CELL_COUNT_BAD'
$parsed=@($cells | ForEach-Object { Get-Content $_.FullName -Raw | ConvertFrom-Json })
Assert (@($parsed | Where-Object { $_.raw_trace_included -ne $false }).Count -eq 0) 'VOLUME_RAW_TRACE_FLAG_BAD'
$retrieved=@($parsed | Where-Object { ($_.topic+' '+$_.situation+' '+$_.failure_reason+' '+$_.reuse_hint) -match 'ordered payload|live object shape|selector' })
Assert (@($retrieved | Where-Object { $_.episode_id -eq 'aimo_growth_selector_ordered_payload_failure_v1' }).Count -eq 1) 'REPLAY_RETRIEVAL_DID_NOT_FIND_REAL_EPISODE'
$proof=[ordered]@{
  schema='episodic_memory_cell_validation_v1'
  status='PASS_EPISODIC_MEMORY_CELL_V1'
  real_episode_cell_path=$cellPath
  tests=@(
    [ordered]@{name='real_episode_cell_from_aimo_selector_failure';status='PASS'},
    [ordered]@{name='reject_missing_proof_ref';status='PASS'},
    [ordered]@{name='reject_raw_dump_marker';status='PASS'},
    [ordered]@{name='reject_failed_hypothesis_without_failure_reason';status='PASS'},
    [ordered]@{name='volume_50_plus_real_cells_parse';status='PASS';cell_count=$cells.Count},
    [ordered]@{name='replay_retrieval_finds_real_episode';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/memory/episodic/EPISODIC_MEMORY_CELL_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 30 | Set-Content -Path $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_EPISODIC_MEMORY_CELL_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('REAL_EPISODE_CELL_PATH='+$cellPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'

