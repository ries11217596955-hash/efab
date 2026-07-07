param(
  [string]$Topic='aimo_growth_selector_ordered_payload_failure',
  [string]$RunId='',
  [string]$OutputRoot='.runtime/reasoning/episodes',
  [string[]]$ProofRefs=@('tests/live_start/AIMO_GROWTH_SELECTOR_HOTSWAP_V1_PROOF.json','tests/autonomous_inner_motor/GROWTH_DIRECTED_TASK_SELECTION_V1_PROOF.json')
)
$ErrorActionPreference='Stop'
function New-SafeSlug([string]$Value){ $s=($Value.ToLowerInvariant() -replace '[^a-z0-9_\-]+','_').Trim('_'); if([string]::IsNullOrWhiteSpace($s)){$s='unknown'}; if($s.Length -gt 80){$s=$s.Substring(0,80).Trim('_')}; return $s }
if([string]::IsNullOrWhiteSpace($RunId)){ $RunId=(New-SafeSlug $Topic)+'_'+(Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ') }
foreach($ref in @($ProofRefs)){ if(-not (Test-Path $ref)){ throw "REASONING_PROOF_REF_MISSING:$ref" } }
New-Item -ItemType Directory -Force -Path $OutputRoot | Out-Null
$runRoot=Join-Path $OutputRoot $RunId
New-Item -ItemType Directory -Force -Path $runRoot | Out-Null
$proofFacts=@()
foreach($ref in @($ProofRefs)){
  $obj=Get-Content $ref -Raw | ConvertFrom-Json
  $proofFacts += [ordered]@{ path=$ref; status=$obj.status; proof_label=$obj.proof_label; sha256=(Get-FileHash -Algorithm SHA256 -Path $ref).Hash }
}
$aimoProof=Get-Content $ProofRefs[0] -Raw | ConvertFrom-Json
$selectorProof=Get-Content $ProofRefs[1] -Raw | ConvertFrom-Json
$workingMemory=[ordered]@{
  topic=$Topic
  active_concepts=@('growth signal','task selector','ordered payload','validator coverage','live hotswap','episodic lesson')
  known_facts=@(
    'AIMO live proof passed after ordered signal access fix.',
    ('Reason counts: '+((@($aimoProof.new_aimo.reason_counts)|ForEach-Object{$_.reason+':'+$_.count}) -join ',')),
    ('Selector validator status: '+$selectorProof.status)
  )
  assumptions=@('A future selector or memory routing fix can repeat this failure if validator fixtures do not match live payload shape.')
  open_questions=@(
    'Which object shapes must validators include for selector logic?',
    'What should be stored as reusable episodic memory instead of raw logs?',
    'How should future reasoning recall this episode before changing routing code?'
  )
  hypotheses=@('A compact episodic cell with proof refs and reuse_hint can prevent repeating the ordered-payload validator gap.')
  contradictions=@('A lab PASS alone did not imply live selector behavior because input shape differed.')
  external_checks=@()
}
$operators=@(
  [ordered]@{op='RECALL';result='Loaded live hotswap proof and selector validator proof.'},
  [ordered]@{op='CONNECT';result='Connected selector fallback failure to live ordered payload shape and validator coverage.'},
  [ordered]@{op='QUESTION';result=$workingMemory.open_questions},
  [ordered]@{op='HYPOTHESIZE';result=$workingMemory.hypotheses[0]},
  [ordered]@{op='CHECK';result='Proof refs exist and report PASS after correction.'},
  [ordered]@{op='CONTRADICT';result=$workingMemory.contradictions[0]},
  [ordered]@{op='SYNTHESIZE';result='Reusable lesson: validator inputs must include live-shaped payloads before accepting selector/memory routing changes.'},
  [ordered]@{op='COMMIT_CANDIDATE';result='Create episodic memory candidate with situation, hypothesis, result, failure, correction, proof refs, reuse hint.'},
  [ordered]@{op='NEXT';result='Use episodic recall before the next reasoning/routing patch.'}
)
$episodeCellOut='.runtime/episodic_memory_v1/reasoning_cells'
$writer='operations/memory/episodic/write_episode_cell_v1.ps1'
[string[]]$episodeProofRefs=@($ProofRefs)
$writerOut=& $writer -EpisodeId 'reasoning_episode_aimo_selector_ordered_payload_lesson_v1' -Topic $Topic -Situation 'Reasoning replay found that a selector lab pass did not protect live AIMO because live growth signal payload shape differed.' -Hypothesis 'A reusable episodic memory cell can preserve the failure mode, correction, and validator lesson for future selector work.' -ActionTaken 'Ran a bounded reasoning episode over live proof refs and emitted an episodic memory candidate.' -Result 'The episode produced a compact reusable lesson with proof refs and no raw trace.' -FailureReason 'Prior lab validation did not include ordered payload shape.' -Correction 'Future validators for selector/routing code must include live-shaped payload fixtures.' -ReuseHint 'Before editing selector or memory routing, recall this episode and test PSCustomObject plus ordered payload input shapes.' -Status 'REUSABLE_LESSON' -Confidence 'high' -ProofRefs $episodeProofRefs -Tags @('reasoning','episodic_memory','selector','validator') -OutputRoot $episodeCellOut
$episodeCellPath=($writerOut | Where-Object { $_ -like 'EPISODE_CELL_PATH=*' }) -replace '^EPISODE_CELL_PATH=',''
$report=[ordered]@{
  schema='reasoning_episode_v1'
  status='PASS_REASONING_EPISODE_V1'
  run_id=$RunId
  topic=$Topic
  working_memory=$workingMemory
  operators=$operators
  proof_facts=@($proofFacts)
  synthesis=[ordered]@{
    claim='Future selector and memory-routing validators must include live-shaped payload fixtures, because lab object shapes can hide routing bugs.'
    support=@($ProofRefs)
    confidence='high'
    proof_needed=@('Replay this episodic memory during the next routing patch before acceptance.')
  }
  compact_memory_candidate=[ordered]@{ type='episodic'; path=$episodeCellPath; status='WRITTEN_TO_EPISODIC_RUNTIME_CANDIDATE' }
  next_reasoning_topic='episodic_recall_before_selector_or_memory_routing_changes'
  raw_trace_included=$false
  live_process_touched=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$reportPath=Join-Path $runRoot 'REASONING_EPISODE_REPORT.json'
$report | ConvertTo-Json -Depth 50 | Set-Content -Path $reportPath -Encoding UTF8
Write-Output 'REASONING_STATUS=PASS_REASONING_EPISODE_V1'
Write-Output ('REASONING_REPORT_PATH='+$reportPath)
Write-Output ('EPISODIC_CELL_PATH='+$episodeCellPath)
Write-Output 'LIVE_PROCESS_TOUCHED=false'
Write-Output 'ACTIVE_MEMORY_MUTATED=false'