$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$tester='operations/reasoning/test_mind_logic_hypotheses_v1.ps1'
Assert (Test-Path $tester) 'tester_missing'
try{ [void][scriptblock]::Create((Get-Content $tester -Raw)) }catch{ Add-Err ('tester_parse_failed:'+ $_.Exception.Message) }
$before=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $before[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } }
$mindOut='.runtime/hypothesis_tester_v1/validator_mind_hypothesis.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $tester -Problem 'Owner correction: continue agent mind logic reasoning, not safety passports or execution authority.' -OutputPath $mindOut *>&1 | ForEach-Object { [string]$_ })
$m=Get-Content $mindOut -Raw | ConvertFrom-Json
Assert ($m.status -eq 'PASS_HYPOTHESIS_TESTER_V1') 'mind_status_bad'
Assert ($m.strongest_hypothesis.kind -eq 'mind_logic') ('mind_winner_bad:'+ $m.strongest_hypothesis.kind)
Assert (@($m.evaluated_hypotheses).Count -ge 3) 'mind_evaluated_too_few'
Assert (@($m.rejected_hypotheses | Where-Object { $_.kind -eq 'action_authority' }).Count -eq 1) 'action_hypothesis_not_rejected_or_ranked_lower'
$memoryOut='.runtime/hypothesis_tester_v1/validator_memory_hypothesis.json'
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $tester -Problem 'memory recall evidence known unknown source filter relevance' -OutputPath $memoryOut *>&1 | ForEach-Object { [string]$_ })
$mem=Get-Content $memoryOut -Raw | ConvertFrom-Json
Assert ($mem.status -eq 'PASS_HYPOTHESIS_TESTER_V1') 'memory_status_bad'
Assert ($mem.strongest_hypothesis.kind -eq 'memory_evidence') ('memory_winner_bad:'+ $mem.strongest_hypothesis.kind)
$actionOut='.runtime/hypothesis_tester_v1/validator_action_penalty.json'
$out3=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $tester -Problem 'agent action execute authority hands but no evidence and no knowledge' -OutputPath $actionOut *>&1 | ForEach-Object { [string]$_ })
$a=Get-Content $actionOut -Raw | ConvertFrom-Json
Assert ($a.status -eq 'PASS_HYPOTHESIS_TESTER_V1') 'action_status_bad'
Assert ($a.strongest_hypothesis.kind -ne 'action_authority') 'premature_action_won_despite_penalty'
Assert (($a.evaluated_hypotheses | Where-Object { $_.kind -eq 'action_authority' }).reasons -contains 'penalized_as_premature_action_branch') 'action_penalty_missing'
$after=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $after[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); if($before[$f] -ne $after[$f]){ Add-Err ('active_memory_hash_changed:'+ $f) } } }
$status=if($errors.Count -eq 0){'PASS_HYPOTHESIS_TESTER_V1'}else{'FAIL_HYPOTHESIS_TESTER_V1'}
$proof=[ordered]@{
  schema='hypothesis_tester_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  tester_path=$tester
  mind_case=$mindOut
  memory_case=$memoryOut
  action_penalty_case=$actionOut
  mind_winner=$m.strongest_hypothesis
  memory_winner=$mem.strongest_hypothesis
  action_case_winner=$a.strongest_hypothesis
  action_case_action_hypothesis=($a.evaluated_hypotheses | Where-Object { $_.kind -eq 'action_authority' })
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  action_executed=$false
  live_process_touched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/HYPOTHESIS_TESTER_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 100 | Set-Content $proofPath -Encoding UTF8
foreach($p in @($proofPath,$mindOut,$memoryOut,$actionOut)){ if(Test-Path $p){ Normalize $p } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('MIND_WINNER='+$m.strongest_hypothesis.kind)
Write-Host ('MEMORY_WINNER='+$mem.strongest_hypothesis.kind)
Write-Host ('ACTION_CASE_WINNER='+$a.strongest_hypothesis.kind)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
