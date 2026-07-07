$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/reasoning/run_reasoning_episode_v1.ps1'
Assert (Test-Path $script) 'REASONING_SCRIPT_MISSING'
# Positive run on real recent AIMO selector episode.
$out=& $script -RunId 'reasoning_episode_validator_real_replay_v1'
$reportPath=($out | Where-Object { $_ -like 'REASONING_REPORT_PATH=*' }) -replace '^REASONING_REPORT_PATH=',''
$cellPath=($out | Where-Object { $_ -like 'EPISODIC_CELL_PATH=*' }) -replace '^EPISODIC_CELL_PATH=',''
Assert (Test-Path $reportPath) 'REASONING_REPORT_NOT_WRITTEN'
Assert (Test-Path $cellPath) 'REASONING_EPISODIC_CELL_NOT_WRITTEN'
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_REASONING_EPISODE_V1') 'REASONING_STATUS_BAD'
Assert (@($r.working_memory.active_concepts).Count -ge 5) 'WORKING_MEMORY_CONCEPTS_TOO_FEW'
Assert (@($r.working_memory.open_questions).Count -ge 3) 'QUESTIONS_TOO_FEW'
Assert (@($r.working_memory.hypotheses).Count -ge 1) 'HYPOTHESIS_MISSING'
Assert (@($r.operators | Where-Object { $_.op -eq 'CONTRADICT' }).Count -eq 1) 'CONTRADICTION_OPERATOR_MISSING'
Assert ($r.raw_trace_included -eq $false) 'RAW_TRACE_INCLUDED_BAD'
Assert ($r.live_process_touched -eq $false) 'LIVE_PROCESS_TOUCHED_BAD'
Assert ($r.active_memory_mutated -eq $false) 'ACTIVE_MEMORY_MUTATED_BAD'
Assert ($r.synthesis.claim -like '*live-shaped payload*') 'SYNTHESIS_CLAIM_WEAK'
# Negative: missing proof ref must fail.
try { & $script -RunId 'reasoning_bad_missing_proof' -ProofRefs @('tests/nope/MISSING.json') | Out-Null; throw 'EXPECTED_MISSING_PROOF_FAILURE_NOT_RAISED' }
catch { if($_.Exception.Message -notlike '*REASONING_PROOF_REF_MISSING*'){ throw "WRONG_NEGATIVE_FAILURE:$($_.Exception.Message)" } }
# Replay retrieval: the produced cell should be findable by ordered payload / selector terms.
$cell=Get-Content $cellPath -Raw|ConvertFrom-Json
$searchText=($cell.topic+' '+$cell.situation+' '+$cell.failure_reason+' '+$cell.reuse_hint)
Assert ($searchText -match 'ordered payload|selector|live-shaped') 'REASONING_EPISODIC_RETRIEVAL_TERMS_MISSING'
$proof=[ordered]@{
  schema='reasoning_episode_validation_v1'
  status='PASS_REASONING_EPISODE_V1'
  reasoning_report_path=$reportPath
  episodic_cell_path=$cellPath
  tests=@(
    [ordered]@{name='real_recent_aimo_selector_replay';status='PASS'},
    [ordered]@{name='working_memory_has_concepts_questions_hypothesis';status='PASS'},
    [ordered]@{name='contradiction_and_synthesis_present';status='PASS'},
    [ordered]@{name='negative_missing_proof_rejected';status='PASS'},
    [ordered]@{name='replay_retrieval_terms_present';status='PASS'}
  )
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/reasoning/REASONING_EPISODE_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof|ConvertTo-Json -Depth 30|Set-Content -Path $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_REASONING_EPISODE_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('REASONING_REPORT_PATH='+$reportPath)
Write-Host ('EPISODIC_CELL_PATH='+$cellPath)
Write-Host 'LIVE_PROCESS_TOUCHED=false'

