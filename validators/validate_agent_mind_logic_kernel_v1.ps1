$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$kernel='operations/reasoning/agent_mind_logic_kernel_v1.json'
$builder='operations/reasoning/build_agent_mind_logic_frame_v1.ps1'
Assert (Test-Path $kernel) 'kernel_missing'
Assert (Test-Path $builder) 'builder_missing'
try{ [void][scriptblock]::Create((Get-Content $builder -Raw)) }catch{ Add-Err ('builder_parse_failed:'+ $_.Exception.Message) }
$k=Get-Content $kernel -Raw|ConvertFrom-Json
Assert ($k.schema -eq 'agent_mind_logic_kernel_v1') 'kernel_schema_bad'
Assert (($k.cognitive_cycle -join ' ') -match 'recall_relevant_memory') 'cycle_missing_memory_recall'
Assert (($k.cognitive_cycle -join ' ') -match 'separate_known_unknown_assumption') 'cycle_missing_known_unknown'
Assert (($k.cognitive_cycle -join ' ') -match 'detect_contradictions') 'cycle_missing_contradiction'
Assert (($k.logic_rules -join ' ') -match 'Memory recall is evidence') 'rules_missing_memory_recall_evidence'
$before=@{}
foreach($f0 in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f0){ $before[$f0]=(Get-FileHash $f0 -Algorithm SHA256).Hash.ToLower() } }
$correctionPath='.runtime/agent_mind_logic_kernel_v1/validator_owner_correction_frame.json'
$out=@(& $builder -OutputPath $correctionPath *>&1 | ForEach-Object { [string]$_ })
$f=Get-Content $correctionPath -Raw|ConvertFrom-Json
Assert ($f.status -eq 'PASS_AGENT_MIND_LOGIC_FRAME_V1') 'correction_frame_status_bad'
Assert ($f.classification -eq 'CONTEXT_MISMATCH_CORRECTION') ('classification_bad:'+ $f.classification)
Assert (@($f.contradictions).Count -ge 2) 'contradictions_too_few'
Assert ($f.selected_next_logical_step.step_id -eq 'BUILD_MIND_LOGIC_KERNEL') 'next_step_not_logic_kernel'
Assert ($f.boundary.action_executed -eq $false) 'action_executed_not_false'
Assert ($f.PSObject.Properties.Name -contains 'memory_recall') 'memory_recall_field_missing'
Assert ($f.PSObject.Properties.Name -contains 'memory_recall_filter') 'memory_recall_filter_field_missing'
Assert ($f.memory_recall.status -in @('PASS_COMPACT_MEMORY_RECALL_V1','BLOCKED_NO_RELEVANT_MEMORY_CELLS_V1')) ('memory_recall_status_bad:'+ $f.memory_recall.status)
Assert (@($f.known).Count -ge 3) 'known_too_few'
Assert (@($f.unknown).Count -ge 3) 'unknown_too_few'
Assert (@($f.hypotheses).Count -ge 3) 'hypotheses_too_few'
Assert (@($f.source_ladder).Count -ge 4) 'source_ladder_too_short'
$memoryPath='.runtime/agent_mind_logic_kernel_v1/validator_memory_recall_frame.json'
$outMem=@(& $builder -Problem 'agent mind logic memory recall action candidate' -OutputPath $memoryPath *>&1 | ForEach-Object { [string]$_ })
$mem=Get-Content $memoryPath -Raw|ConvertFrom-Json
Assert ($mem.memory_recall.status -eq 'PASS_COMPACT_MEMORY_RECALL_V1') ('memory_recall_expected_pass_but_was:'+ $mem.memory_recall.status)
Assert ($mem.memory_recall_filter.status -eq 'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1') ('memory_recall_filter_expected_pass_but_was:'+ $mem.memory_recall_filter.status)
Assert (@($mem.memory_recall.matches).Count -gt 0) 'memory_recall_matches_empty'
Assert ($mem.memory_recall.used_in_known -eq $true) 'memory_recall_not_used_in_known'
Assert ($mem.memory_recall_filter.used_in_known -eq $true) 'memory_recall_filter_not_used_in_known'
Assert ($mem.memory_recall_filter.accepted_count -gt 0) 'memory_recall_filter_accepted_count_zero'
Assert (($mem.known | ConvertTo-Json -Depth 10) -match 'FILTERED_MEMORY_RECALL_SUPPORTED') 'filtered_memory_supported_known_missing'
$gapPath='.runtime/agent_mind_logic_kernel_v1/validator_no_knowledge_frame.json'
$out2=@(& $builder -Problem no_evidence_no_knowledge -OutputPath $gapPath *>&1 | ForEach-Object { [string]$_ })
$g=Get-Content $gapPath -Raw|ConvertFrom-Json
Assert ($g.no_evidence_no_claim -eq $true) 'no_evidence_no_claim_false'
Assert ($g.selected_next_logical_step.step_id -eq 'ASK_OR_RECALL_SOURCE_BEFORE_ACTION') ('knowledge_next_step_bad:'+ $g.selected_next_logical_step.step_id)
$after=@{}
foreach($f1 in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f1){ $after[$f1]=(Get-FileHash $f1 -Algorithm SHA256).Hash.ToLower(); if($before[$f1] -ne $after[$f1]){ Add-Err ('active_memory_hash_changed:'+ $f1) } } }
$status=if($errors.Count -eq 0){'PASS_AGENT_MIND_LOGIC_KERNEL_V1'}else{'FAIL_AGENT_MIND_LOGIC_KERNEL_V1'}
$proof=[ordered]@{
  schema='agent_mind_logic_kernel_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  kernel_path=$kernel
  builder_path=$builder
  correction_frame=$correctionPath
  memory_recall_frame=$memoryPath
  no_knowledge_frame=$gapPath
  correction_classification=$f.classification
  correction_next_step=$f.selected_next_logical_step
  correction_memory_recall_status=$f.memory_recall.status
  memory_recall_status=$mem.memory_recall.status
  memory_recall_filter_status=$mem.memory_recall_filter.status
  memory_recall_match_count=@($mem.memory_recall.matches).Count
  memory_recall_filter_accepted_count=$mem.memory_recall_filter.accepted_count
  memory_recall_filter_used_in_known=$mem.memory_recall_filter.used_in_known
  memory_recall_used_in_known=$mem.memory_recall.used_in_known
  no_knowledge_next_step=$g.selected_next_logical_step
  tests=@(
    [ordered]@{name='kernel_has_cognitive_cycle';status=if(($k.cognitive_cycle -join ' ') -match 'detect_contradictions'){'PASS'}else{'FAIL'}},
    [ordered]@{name='memory_recall_cycle_present';status=if(($k.cognitive_cycle -join ' ') -match 'recall_relevant_memory'){'PASS'}else{'FAIL'}},
    [ordered]@{name='owner_correction_cuts_wrong_branch';status=if($f.classification -eq 'CONTEXT_MISMATCH_CORRECTION'){'PASS'}else{'FAIL'}},
    [ordered]@{name='known_unknown_hypothesis_present';status=if(@($f.known).Count -ge 3 -and @($f.unknown).Count -ge 3 -and @($f.hypotheses).Count -ge 3){'PASS'}else{'FAIL'}},
    [ordered]@{name='memory_recall_used_when_relevant';status=if($mem.memory_recall.status -eq 'PASS_COMPACT_MEMORY_RECALL_V1' -and $mem.memory_recall.used_in_known -eq $true){'PASS'}else{'FAIL'}},
    [ordered]@{name='memory_recall_filter_used_when_relevant';status=if($mem.memory_recall_filter.status -eq 'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1' -and $mem.memory_recall_filter.used_in_known -eq $true){'PASS'}else{'FAIL'}},
    [ordered]@{name='no_knowledge_selects_source_before_action';status=if($g.selected_next_logical_step.step_id -eq 'ASK_OR_RECALL_SOURCE_BEFORE_ACTION'){'PASS'}else{'FAIL'}},
    [ordered]@{name='active_memory_unchanged';status=if(($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0){'PASS'}else{'FAIL'}}
  )
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  action_executed=$false
  live_process_touched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/AGENT_MIND_LOGIC_KERNEL_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof|ConvertTo-Json -Depth 100|Set-Content $proofPath -Encoding UTF8
foreach($p in @($proofPath,$correctionPath,$memoryPath,$gapPath)){ if(Test-Path $p){ Normalize $p } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('CORRECTION_NEXT_STEP='+$f.selected_next_logical_step.step_id)
Write-Host ('MEMORY_RECALL_STATUS='+$mem.memory_recall.status)
Write-Host ('MEMORY_RECALL_MATCH_COUNT='+@($mem.memory_recall.matches).Count)
Write-Host ('NO_KNOWLEDGE_NEXT_STEP='+$g.selected_next_logical_step.step_id)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
