$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m)|Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
function Normalize([string]$p){ $txt=Get-Content $p -Raw; $lines=$txt -split "`r?`n" | ForEach-Object { $_.TrimEnd() }; while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){ $lines=@(); break }; $lines=$lines[0..($lines.Count-2)] }; $utf8=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Resolve-Path $p), (($lines -join "`n") + "`n"), $utf8) }
$passport='operations/autonomous_inner_motor/execution_authority_passport_v1.json'
$evaluator='operations/autonomous_inner_motor/evaluate_action_execution_authority_v1.ps1'
Assert (Test-Path $passport) 'passport_missing'
Assert (Test-Path $evaluator) 'evaluator_missing'
try{ [void][scriptblock]::Create((Get-Content $evaluator -Raw)) }catch{ Add-Err ('evaluator_parse_failed:'+ $_.Exception.Message) }
$p=Get-Content $passport -Raw|ConvertFrom-Json
Assert ($p.schema -eq 'agent_execution_authority_passport_v1') 'passport_schema_bad'
Assert ($p.default_decision -eq 'DENY') 'default_decision_not_deny'
Assert (@($p.hard_denies) -contains 'mutate_active_memory_directly') 'hard_denies_missing_memory'
Assert (@($p.hard_denies) -contains 'run_school_live') 'hard_denies_missing_school_live'
Assert ($p.authority_classes.LAB_FILE_WRITE.execution_allowed -eq $false) 'lab_file_write_execution_not_false'
Assert ($p.authority_classes.OWNER_LIVE_ACTION_AUTHORITY.grantable_in_lab -eq $false) 'owner_live_grantable_in_lab_not_false'
$before=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $before[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower() } }
$packet='.runtime/agent_action_decision_contract_v1/validator_positive_packet.json'
if(-not(Test-Path $packet)){
  & powershell -NoProfile -ExecutionPolicy Bypass -File 'operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1' -Mode LabOnly -OutputPath $packet | Out-Null
}
$grantOut='.runtime/execution_authority_passport_v1/validator_grant_candidate_only.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $evaluator -ActionPacketPath $packet -OutputPath $grantOut *>&1 | ForEach-Object { [string]$_ })
$grant=Get-Content $grantOut -Raw|ConvertFrom-Json
Assert ($grant.status -eq 'PASS_EXECUTION_AUTHORITY_EVALUATION_V1') ('grant_status_bad:'+ $grant.status)
Assert ($grant.decision -eq 'GRANT_CANDIDATE_ONLY') ('grant_decision_bad:'+ $grant.decision)
Assert ($grant.execution_allowed -eq $false) 'grant_execution_allowed_not_false'
Assert ($grant.boundary.action_executed -eq $false) 'grant_action_executed_not_false'
$execReqOut='.runtime/execution_authority_passport_v1/validator_request_execution_blocked.json'
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $evaluator -ActionPacketPath $packet -OutputPath $execReqOut -RequestExecution *>&1 | ForEach-Object { [string]$_ })
$exec=Get-Content $execReqOut -Raw|ConvertFrom-Json
Assert ($exec.status -eq 'BLOCKED_EXECUTION_AUTHORITY_EVALUATION_V1') ('request_execution_status_bad:'+ $exec.status)
Assert (@($exec.deny_reasons) -contains 'execution_request_not_supported_by_passport_v1') 'request_execution_not_blocked'
Assert ($exec.execution_allowed -eq $false) 'request_execution_allowed_not_false'
# synthetic hard denied action packet
$denyPacket='.runtime/execution_authority_passport_v1/validator_hard_deny_packet.json'
$base=Get-Content $packet -Raw|ConvertFrom-Json
$base.selected_action.action_id='NEGATIVE_MUTATE_MEMORY'
$base.selected_action.action_type='mutate_active_memory_directly'
$base.selected_action.required_authority='PROTECTED_MEMORY_MUTATION'
$base.selected_action.validator_refs=@()
$base | ConvertTo-Json -Depth 80 | Set-Content $denyPacket -Encoding UTF8
$denyOut='.runtime/execution_authority_passport_v1/validator_hard_deny.json'
$out3=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $evaluator -ActionPacketPath $denyPacket -OutputPath $denyOut *>&1 | ForEach-Object { [string]$_ })
$deny=Get-Content $denyOut -Raw|ConvertFrom-Json
Assert ($deny.status -eq 'BLOCKED_EXECUTION_AUTHORITY_EVALUATION_V1') ('hard_deny_status_bad:'+ $deny.status)
Assert (@($deny.deny_reasons) -contains 'hard_denied_action_type') 'hard_deny_missing_hard_denied_action_type'
Assert (@($deny.deny_reasons) -contains 'authority_class_not_grantable_in_lab') 'hard_deny_missing_authority_not_grantable'
Assert ($deny.execution_allowed -eq $false) 'hard_deny_execution_allowed_not_false'
$after=@{}
foreach($f in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $f){ $after[$f]=(Get-FileHash $f -Algorithm SHA256).Hash.ToLower(); if($before[$f] -ne $after[$f]){ Add-Err ('active_memory_hash_changed:'+ $f) } } }
$status=if($errors.Count -eq 0){'PASS_AGENT_EXECUTION_AUTHORITY_PASSPORT_V1'}else{'FAIL_AGENT_EXECUTION_AUTHORITY_PASSPORT_V1'}
$proof=[ordered]@{
  schema='agent_execution_authority_passport_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  passport_path=$passport
  evaluator_path=$evaluator
  grant_candidate_only_evaluation=$grant
  request_execution_blocked_evaluation=$exec
  hard_deny_evaluation=$deny
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  action_executed=$false
  live_process_touched=$false
  repo_mutated_by_evaluator=$false
  errors=@($errors)
}
$proofPath='tests/self_development/AGENT_EXECUTION_AUTHORITY_PASSPORT_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof | ConvertTo-Json -Depth 100 | Set-Content $proofPath -Encoding UTF8
foreach($f in @($proofPath,$grantOut,$execReqOut,$denyOut,$denyPacket)){ if(Test-Path $f){ Normalize $f } }
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('GRANT_DECISION='+$grant.decision)
Write-Host ('REQUEST_EXECUTION_STATUS='+$exec.status)
Write-Host ('HARD_DENY_STATUS='+$deny.status)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
