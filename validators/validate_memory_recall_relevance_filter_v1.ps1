$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$filter='operations/reasoning/filter_memory_recall_relevance_v1.ps1'
Assert (Test-Path $filter) 'filter_missing'
try{ [void][scriptblock]::Create((Get-Content $filter -Raw)) }catch{ Add-Err ('filter_parse_failed:'+ $_.Exception.Message) }
$before=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $before[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } }
$outPath='.runtime/memory_recall_relevance_filter_v1/validator_filter_result.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $filter -Query 'agent mind logic memory recall action candidate' -Top 8 -AcceptTop 3 -OutputPath $outPath *>&1 | ForEach-Object { [string]$_ })
$r=Get-Content $outPath -Raw | ConvertFrom-Json
Assert ($r.status -eq 'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1') ('filter_status_bad:'+ $r.status)
Assert ($r.accepted_count -ge 1) 'accepted_count_lt_1'
Assert ($r.accepted_count -le 3) 'accepted_count_gt_3'
Assert (@($r.accepted_matches | Where-Object { $_.decision -ne 'ACCEPT_AS_MEMORY_EVIDENCE' }).Count -eq 0) 'accepted_decision_bad'
Assert (@($r.rejected_matches | Where-Object { $_.relevance_class -eq 'DUPLICATE' }).Count -ge 1) 'duplicate_not_detected'
Assert (@($r.rejected_matches | Where-Object { $_.curriculum_noise -eq $true }).Count -ge 1) 'curriculum_noise_not_detected'
Assert (($r.accepted_matches | ConvertTo-Json -Depth 20) -match 'AIMO|memory atom|gate|agent|logic|action') 'accepted_not_agent_relevant'
$after=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $after[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); if($before[$f] -ne $after[$f]){ Add-Err ('active_memory_hash_changed:'+ $f) } } }
$status=if($errors.Count -eq 0){'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1'}else{'FAIL_MEMORY_RECALL_RELEVANCE_FILTER_V1'}
$proof=[ordered]@{
  schema='memory_recall_relevance_filter_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  filter_path=$filter
  filter_result_path=$outPath
  filter_status=$r.status
  raw_match_count=$r.raw_match_count
  accepted_count=$r.accepted_count
  accepted_labels=@($r.accepted_matches | ForEach-Object { $_.label })
  duplicate_reject_count=@($r.rejected_matches | Where-Object { $_.relevance_class -eq 'DUPLICATE' }).Count
  curriculum_noise_reject_count=@($r.rejected_matches | Where-Object { $_.curriculum_noise -eq $true }).Count
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  action_executed=$false
  live_process_touched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/MEMORY_RECALL_RELEVANCE_FILTER_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 80 | Set-Content $proofPath -Encoding UTF8
foreach($p in @($proofPath,$outPath)){ if(Test-Path $p){ Normalize $p } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('ACCEPTED_COUNT='+$proof.accepted_count)
Write-Host ('DUPLICATE_REJECT_COUNT='+$proof.duplicate_reject_count)
Write-Host ('CURRICULUM_NOISE_REJECT_COUNT='+$proof.curriculum_noise_reject_count)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
