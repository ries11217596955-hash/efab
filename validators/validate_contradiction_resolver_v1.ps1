$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$resolver='operations/reasoning/resolve_mind_logic_contradiction_v1.ps1'
Assert (Test-Path $resolver) 'resolver_missing'
try{ [void][scriptblock]::Create((Get-Content $resolver -Raw)) }catch{ Add-Err ('resolver_parse_failed:'+ $_.Exception.Message) }
$before=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $before[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } }
$correctionOut='.runtime/contradiction_resolver_v1/validator_correction_resolution.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Problem 'Owner correction: build agent mind logic, not safety passports. Agent knows nothing and cannot act yet.' -OutputPath $correctionOut *>&1 | ForEach-Object { [string]$_ })
$c=Get-Content $correctionOut -Raw | ConvertFrom-Json
Assert ($c.status -eq 'PASS_CONTRADICTION_RESOLUTION_V1') 'correction_status_bad'
Assert ($c.decision -eq 'CUT_LOSING_BRANCH_AND_CONTINUE_WINNING_BRANCH') ('correction_decision_bad:'+ $c.decision)
Assert (@($c.cut_branches | Where-Object { $_.branch -match 'SAFETY|ACTION|AUTHORITY' }).Count -ge 1) 'correction_did_not_cut_wrong_branch'
Assert (@($c.preserve_branches | Where-Object { $_.branch -match 'MIND|KNOWLEDGE|LOGIC' }).Count -ge 1) 'correction_did_not_preserve_logic'
Assert (@($c.proof_needs).Count -ge 1) 'proof_needs_missing'
Assert ($c.boundary.action_executed -eq $false) 'correction_action_executed_not_false'
$noConflictOut='.runtime/contradiction_resolver_v1/validator_no_conflict_resolution.json'
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $resolver -Problem 'inventory update with known facts and one largest unknown' -OutputPath $noConflictOut *>&1 | ForEach-Object { [string]$_ })
$n=Get-Content $noConflictOut -Raw | ConvertFrom-Json
Assert ($n.status -eq 'PASS_CONTRADICTION_RESOLUTION_V1') 'no_conflict_status_bad'
Assert ($n.selected_resolution_step.step_id -eq 'RESOLVE_BY_LARGEST_UNKNOWN') ('no_conflict_next_bad:'+ $n.selected_resolution_step.step_id)
$after=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $after[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); if($before[$f] -ne $after[$f]){ Add-Err ('active_memory_hash_changed:'+ $f) } } }
$status=if($errors.Count -eq 0){'PASS_CONTRADICTION_RESOLVER_V1'}else{'FAIL_CONTRADICTION_RESOLVER_V1'}
$proof=[ordered]@{
  schema='contradiction_resolver_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  resolver_path=$resolver
  correction_resolution=$correctionOut
  no_conflict_resolution=$noConflictOut
  correction_decision=$c.decision
  correction_cut_branches=@($c.cut_branches)
  correction_preserve_branches=@($c.preserve_branches)
  correction_proof_needs=@($c.proof_needs)
  no_conflict_next_step=$n.selected_resolution_step
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  action_executed=$false
  live_process_touched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/CONTRADICTION_RESOLVER_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 100 | Set-Content $proofPath -Encoding UTF8
foreach($p in @($proofPath,$correctionOut,$noConflictOut)){ if(Test-Path $p){ Normalize $p } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('CORRECTION_DECISION='+$c.decision)
Write-Host ('NO_CONFLICT_NEXT='+$n.selected_resolution_step.step_id)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
