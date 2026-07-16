$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){ $errors.Add($m) | Out-Null }
function Assert($cond,[string]$msg){ if(-not $cond){ Add-Err $msg } }
$contract='operations/autonomous_inner_motor/action_decision_contract_v1.json'
$script='operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'
Assert (Test-Path $contract) 'contract_missing'
Assert (Test-Path $script) 'selector_script_missing'
try{ [void][scriptblock]::Create((Get-Content $script -Raw)) }catch{ Add-Err ('selector_parse_failed:'+ $_.Exception.Message) }
$c=Get-Content $contract -Raw|ConvertFrom-Json
Assert ($c.schema -eq 'agent_action_decision_contract_v1') 'contract_schema_bad'
Assert (@($c.selected_action_required_fields).Count -ge 9) 'selected_required_fields_too_few'
Assert (($c.hard_rules -join ' ') -match 'validator') 'hard_rules_missing_validator'
Assert (($c.hard_rules -join ' ') -match 'rollback') 'hard_rules_missing_rollback'
$before=@{}
foreach($p in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $p){ $before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower() } }
$outPath='.runtime/agent_action_decision_contract_v1/validator_positive_packet.json'
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Mode LabOnly -OutputPath $outPath *>&1 | ForEach-Object { [string]$_ })
$status=($out|Where-Object{$_ -match '^ACTION_DECISION_PACKET_STATUS='}|Select-Object -Last 1) -replace '^ACTION_DECISION_PACKET_STATUS=',''
Assert ($status -eq 'PASS_AGENT_ACTION_DECISION_PACKET_V1') ('positive_status_bad:'+ $status)
Assert (Test-Path $outPath) 'positive_packet_missing'
$p=Get-Content $outPath -Raw|ConvertFrom-Json
Assert ($p.selected_action.action_id -eq 'ACTION_CONTRACT_V1') 'selected_action_bad'
Assert ($p.selected_action.execution_allowed -eq $false) 'selected_execution_allowed_not_false'
Assert (@($p.selected_action.validator_refs).Count -ge 1) 'selected_validator_refs_missing'
Assert ([string]$p.selected_action.rollback_plan -match 'git restore|rollback|restore') 'selected_rollback_missing'
Assert ($p.safety_boundary.action_execution_allowed -eq $false) 'safety_boundary_allows_execution'
Assert ($p.safety_boundary.active_memory_mutated -eq $false) 'safety_boundary_active_memory_mutated'
Assert (@($p.evidence_refs).Count -ge 5) 'evidence_refs_too_few'
$negPath='.runtime/agent_action_decision_contract_v1/validator_negative_packet.json'
$negOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -Mode LabOnly -OutputPath $negPath -NegativeMissingValidator *>&1 | ForEach-Object { [string]$_ })
$negStatus=($negOut|Where-Object{$_ -match '^ACTION_DECISION_PACKET_STATUS='}|Select-Object -Last 1) -replace '^ACTION_DECISION_PACKET_STATUS=',''
Assert ($negStatus -eq 'BLOCKED_AGENT_ACTION_DECISION_PACKET_V1') ('negative_status_bad:'+ $negStatus)
$n=Get-Content $negPath -Raw|ConvertFrom-Json
Assert (@($n.rejected_actions).Count -eq 1) 'negative_reject_count_bad'
Assert ((@($n.rejected_actions[0].reject_reasons) -contains 'missing_validator_refs')) 'negative_missing_validator_not_detected'
Assert ((@($n.rejected_actions[0].reject_reasons) -contains 'lab_mode_execution_forbidden')) 'negative_lab_execution_not_detected'
$after=@{}
foreach($p0 in @('.runtime/active_compact_semantic_memory_v1/manifest.json','.runtime/active_compact_semantic_memory_v1/index.json','.runtime/active_compact_semantic_memory_v1/cells.jsonl')){ if(Test-Path $p0){ $after[$p0]=(Get-FileHash $p0 -Algorithm SHA256).Hash.ToLower(); if($before[$p0] -ne $after[$p0]){ Add-Err ('active_memory_hash_changed:'+ $p0) } } }
$statusFinal=if($errors.Count -eq 0){'PASS_AGENT_ACTION_DECISION_CONTRACT_V1'}else{'FAIL_AGENT_ACTION_DECISION_CONTRACT_V1'}
$proof=[ordered]@{
  schema='agent_action_decision_contract_validation_v1'
  status=$statusFinal
  checked_at=(Get-Date).ToString('o')
  contract_path=$contract
  selector_script=$script
  positive_packet=$outPath
  negative_packet=$negPath
  selected_action=$p.selected_action
  rejected_negative=$n.rejected_actions
  active_memory_hash_unchanged=($errors|Where-Object{$_ -match 'active_memory_hash_changed'}).Count -eq 0
  live_process_touched=$false
  action_execution_performed=$false
  errors=@($errors)
}
$proofPath='tests/self_development/AGENT_ACTION_DECISION_CONTRACT_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host ('VALIDATION_STATUS='+$statusFinal)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('ACTIVE_MEMORY_HASH_UNCHANGED='+$proof.active_memory_hash_unchanged)
Write-Host ('ACTION_EXECUTION_PERFORMED=false')
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
