$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$requester='operations/reasoning/request_deep_source_answer_v1.ps1'
Assert (Test-Path $requester) 'requester_missing'
try{ [void][scriptblock]::Create((Get-Content $requester -Raw)) }catch{ Add-Err ('requester_parse_failed:'+ $_.Exception.Message) }
$before=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $before[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } }
$memoryOut='.runtime/deep_source_answer_request_v1/validator_memory_answer.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $requester -Problem 'agent mind logic memory recall hypothesis contradiction' -Need 'choose the next reasoning step from filtered memory evidence' -Mode Auto -OutputPath $memoryOut *>&1 | ForEach-Object { [string]$_ })
$m=Get-Content $memoryOut -Raw | ConvertFrom-Json
Assert ($m.status -eq 'PASS_DEEP_SOURCE_ANSWER_REQUEST_WITH_MEMORY_CANDIDATE_V1') ('memory_status_bad:'+ $m.status)
Assert ($m.answer_ready -eq $true) 'memory_answer_not_ready'
Assert (@($m.answer_candidate.evidence_items).Count -ge 1) 'memory_answer_evidence_missing'
Assert (($m.answer_contract.fields -contains 'direct_answer') -and ($m.answer_contract.fields -contains 'evidence_items') -and ($m.answer_contract.fields -contains 'unknown')) 'answer_contract_fields_missing'
Assert ($m.boundary.codex_launched -eq $false -and $m.boundary.web_launched -eq $false -and $m.boundary.active_memory_mutated -eq $false) 'boundary_broken_memory_case'
$requestOnlyOut='.runtime/deep_source_answer_request_v1/validator_request_only.json'
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $requester -Problem 'unknown external factual question' -Need 'get exact deep answer in required JSON shape' -Mode RequestOnly -OutputPath $requestOnlyOut *>&1 | ForEach-Object { [string]$_ })
$r=Get-Content $requestOnlyOut -Raw | ConvertFrom-Json
Assert ($r.status -eq 'PASS_DEEP_SOURCE_ANSWER_REQUEST_PACKET_V1') ('request_only_status_bad:'+ $r.status)
Assert ($r.answer_ready -eq $false) 'request_only_answer_should_not_be_ready'
Assert ($r.request_packet.answer_contract.required_format -eq 'json_object') 'request_packet_format_bad'
Assert (@($r.request_packet.preferred_source_ladder | Where-Object { $_.source -eq 'Codex' -and $_.allowed_now -eq $false }).Count -eq 1) 'codex_not_blocked_in_request_packet'
Assert (@($r.request_packet.preferred_source_ladder | Where-Object { $_.source -eq 'web_or_external_source' -and $_.allowed_now -eq $false }).Count -eq 1) 'web_not_blocked_in_request_packet'
$after=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $after[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); if($before[$f] -ne $after[$f]){ Add-Err ('active_memory_hash_changed:'+ $f) } } }
$status=if($errors.Count -eq 0){'PASS_DEEP_SOURCE_ANSWER_REQUEST_V1'}else{'FAIL_DEEP_SOURCE_ANSWER_REQUEST_V1'}
$proof=[ordered]@{
  schema='deep_source_answer_request_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  requester_path=$requester
  memory_answer_result=$memoryOut
  request_only_result=$requestOnlyOut
  memory_status=$m.status
  memory_answer_ready=$m.answer_ready
  memory_evidence_count=@($m.answer_candidate.evidence_items).Count
  request_only_status=$r.status
  request_packet_format=$r.request_packet.answer_contract.required_format
  blocked_external_sources=@($r.request_packet.preferred_source_ladder | Where-Object { $_.allowed_now -eq $false } | ForEach-Object { $_.source })
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  codex_launched=$false
  web_launched=$false
  action_executed=$false
  errors=@($errors)
}
$proofPath='tests/self_development/DEEP_SOURCE_ANSWER_REQUEST_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 100 | Set-Content $proofPath -Encoding UTF8
foreach($p in @($proofPath,$memoryOut,$requestOnlyOut)){ if(Test-Path $p){ Normalize $p } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('MEMORY_ANSWER_READY='+$m.answer_ready)
Write-Host ('MEMORY_EVIDENCE_COUNT='+@($m.answer_candidate.evidence_items).Count)
Write-Host ('REQUEST_ONLY_STATUS='+$r.status)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
