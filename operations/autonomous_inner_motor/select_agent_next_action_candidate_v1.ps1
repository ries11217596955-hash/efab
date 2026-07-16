param(
  [string]$Goal='Increase agent logic: choose the next safe self-build action from thinking evidence.',
  [ValidateSet('LabOnly')][string]$Mode='LabOnly',
  [string]$OutputPath='.runtime/agent_action_decision_contract_v1/decision_packet.json',
  [switch]$NegativeMissingValidator
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 80|Set-Content -Path $p -Encoding UTF8 }
function FileProof($p){ if(Test-Path $p){ $i=Get-Item $p; return [ordered]@{path=$p; exists=$true; bytes=$i.Length; sha256=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()} } return [ordered]@{path=$p; exists=$false} }
function GitValue($cmd){ try { return (& git $cmd 2>$null) -join ' ' } catch { return '' } }
$contractPath='operations/autonomous_inner_motor/action_decision_contract_v1.json'
if(-not(Test-Path $contractPath)){ throw 'ACTION_DECISION_CONTRACT_MISSING' }
$contract=Get-Content $contractPath -Raw|ConvertFrom-Json
$repoStatus=@(git status --short --untracked-files=all)
$head=(git rev-parse --short HEAD)
$branch=(git rev-parse --abbrev-ref HEAD)
$activeManifest=FileProof '.runtime/active_compact_semantic_memory_v1/manifest.json'
$activeIndex=FileProof '.runtime/active_compact_semantic_memory_v1/index.json'
$activeCells=FileProof '.runtime/active_compact_semantic_memory_v1/cells.jsonl'
$evidenceRefs=@(
  (FileProof 'tests/self_development/AUTONOMOUS_INNER_MOTOR_SELF_DIRECTED_THINKING_V1_PROOF.json'),
  (FileProof 'tests/self_development/AUTONOMOUS_INNER_MOTOR_DEEP_THINKING_MEMORY_LEARNING_V1_PROOF.json'),
  (FileProof 'tests/self_development/AUTONOMOUS_INNER_MOTOR_DUAL_PIPE_MEMORY_INGESTION_V1_PROOF.json'),
  (FileProof 'tests/self_development/SCHOOL_LIVE1000_DYNAMIC_PREFLIGHT_LIVE_V1_PROOF.json'),
  (FileProof 'tests/self_development/SCHOOL_CODEX_EXIT_ANOMALY_SCHEMA_REPAIR_V1_PROOF.json'),
  $activeManifest,
  $activeIndex,
  $activeCells
)
$known=@(
  'AIMO can self-seed thinking without Owner query.',
  'AIMO can run deep thinking and route learning atoms through AgentLife queue/merge.',
  'School is proven live and active memory changed after Live1000.',
  'Current AIMO boundary is protective thinking-only; it does not execute actions.'
)
$unknown=@(
  'AIMO has no proven live authority to execute repo/runtime actions independently.',
  'AIMO has no proven action selection gate requiring validator/proof/rollback before execution.',
  'AIMO fresh-memory per School batch remains partial proof, not full live proof.'
)
$gap='Agent has thinking and memory learning, but lacks a governed action-candidate contract between thought and execution.'
$candidateActions=@(
  [ordered]@{action_id='ACTION_CONTRACT_V1'; action_type='write_install_ready_artifact'; target_surface='operations/autonomous_inner_motor'; required_authority='LAB_FILE_WRITE'; validator_required=$true; validator_refs=@('validators/validate_agent_action_decision_contract_v1.ps1'); proof_required=$true; rollback_plan='git restore changed files before commit; no active memory mutation'; execution_allowed=($Mode -eq 'LabOnly'); why_candidate='Smallest safe bridge from thinking to action without granting hands.'},
  [ordered]@{action_id='WIRE_AIMO_TO_EXECUTION'; action_type='execute_repo_patch'; target_surface='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'; required_authority='OWNER_LIVE_ACTION_AUTHORITY'; validator_required=$true; validator_refs=@('validators/validate_autonomous_inner_motor_organ_contract.ps1'); proof_required=$true; rollback_plan='git restore runner and proof files'; execution_allowed=$false; why_candidate='Too early: execution wiring before action contract would mix thinking and hands.'},
  [ordered]@{action_id='RUN_BIG_LIVE_AGENT'; action_type='run_aimo_live'; target_surface='runtime'; required_authority='OWNER_EXPLICIT_LIVE_AUTHORITY'; validator_required=$true; validator_refs=@(); proof_required=$true; rollback_plan='stop process and preserve logs'; execution_allowed=$false; why_candidate='Rejected: missing validator refs and live authority.'}
)
if($NegativeMissingValidator){
  $candidateActions=@([ordered]@{action_id='NEGATIVE_NO_VALIDATOR'; action_type='execute_repo_patch'; target_surface='repo'; required_authority='LAB_FILE_WRITE'; validator_required=$true; validator_refs=@(); proof_required=$true; rollback_plan='none'; execution_allowed=$true; why_candidate='Synthetic unsafe candidate for negative test.'})
}
$rejected=@()
$valid=@()
foreach($a in $candidateActions){
  $reasons=@()
  if($a.action_type -ne 'observe_only' -and $a.validator_required -and @($a.validator_refs).Count -eq 0){ $reasons+='missing_validator_refs' }
  if([string]::IsNullOrWhiteSpace([string]$a.rollback_plan) -or $a.rollback_plan -eq 'none'){ $reasons+='missing_rollback_plan' }
  if($Mode -eq 'LabOnly' -and @('run_school_live','run_aimo_live','push_to_remote','delete_runtime','mutate_active_memory_directly','launch_child_agent','execute_repo_patch') -contains $a.action_type){ $reasons+='lab_mode_execution_forbidden' }
  if($reasons.Count -gt 0){ $rejected += [ordered]@{action=$a; reject_reasons=$reasons} } else { $valid += $a }
}
$selected=$null
if($valid.Count -gt 0){ $selected=$valid[0]; $selected.execution_allowed=$false; $selected.why_safe_now='Selected only as candidate/contract proof. Actual execution remains blocked by LabOnly boundary.' }
$status=if($selected){'PASS_AGENT_ACTION_DECISION_PACKET_V1'}else{'BLOCKED_AGENT_ACTION_DECISION_PACKET_V1'}
$packet=[ordered]@{
  schema='agent_action_decision_packet_v1'
  status=$status
  created_at=(Get-Date).ToString('o')
  mode=$Mode
  branch=$branch
  head=$head
  repo_dirty=($repoStatus.Count -gt 0)
  goal=$Goal
  evidence_refs=@($evidenceRefs)
  known=@($known)
  unknown=@($unknown)
  gap=$gap
  candidate_actions=@($candidateActions)
  selected_action=$selected
  rejected_actions=@($rejected)
  safety_boundary=[ordered]@{lab_only=$true; action_execution_allowed=$false; live_process_touched=$false; active_memory_mutated=$false; repo_mutation_allowed='proof/report write only'; requires_owner_for_execution=$true}
  proof_expectation='Decision packet must prove selected action has authority, validator refs, proof requirement, rollback plan, and execution_allowed=false in LabOnly mode.'
  return_to_parent='Return selected action candidate to AIMO/Owner; do not execute it until a separate authority passport and validator pass exist.'
  contract_ref=$contractPath
}
WJson $packet $OutputPath
Write-Host ('ACTION_DECISION_PACKET_STATUS='+$status)
Write-Host ('ACTION_DECISION_PACKET_PATH='+$OutputPath)
if($selected){ Write-Host ('SELECTED_ACTION_ID='+$selected.action_id); Write-Host ('SELECTED_EXECUTION_ALLOWED='+$selected.execution_allowed) }
Write-Host ('REJECTED_COUNT='+@($rejected).Count)
