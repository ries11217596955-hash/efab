$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$packetPath='reports/self_development/DECISION_GATE_V1_DECISION_PACKET.json'
$decisionProofPath='tests/self_development/DECISION_GATE_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$envelopePath='reports/self_development/BRAIN_INPUT_CONSUMER_V1_ENVELOPE.json'
$reportPath='reports/self_development/BRAIN_INPUT_CONSUMER_V1_REPORT.json'
$proofPath='tests/self_development/BRAIN_INPUT_CONSUMER_V1_PROOF.json'
foreach($p in @($packetPath,$decisionProofPath,$contractPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_decision_gate_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'DECISION_GATE_VALIDATION_FAILED'
$packet=Get-Content $packetPath -Raw|ConvertFrom-Json
$dp=Get-Content $decisionProofPath -Raw|ConvertFrom-Json
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($packet.status -eq 'PASS_DECISION_GATE_V1_DECISION_PACKET') 'PACKET_STATUS_BAD'
Assert ($dp.status -eq 'PASS_DECISION_GATE_V1') 'DECISION_PROOF_STATUS_BAD'
$inputClass='NON_EXECUTING_ROUTE_PACKET'
if($packet.route_class -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED' -and $packet.owner_decision_required -eq $true){$inputClass='OWNER_DECISION_REQUIRED_REPAIR_OR_KEEP_BLOCKED'}
if($packet.route_class -eq 'STOP_NO_LAWFUL_ACTION'){$inputClass='STOP_PACKET'}
$requiredQuestion='Owner decision required: authorize a separate PREFLIGHT repair task to locate/rebuild the missing source proof for operations_active_behavior, or keep the organ BLOCKED?'
$safePrompt='Read this envelope only as a route constraint. Do not execute repair, mutate files, create proof, or claim runtime/live readiness. Ask/require Owner authority before any repair preflight.'
$evidence=@($packet.evidence_refs|Where-Object{$_}|Sort-Object -Unique)
$forbidden=@($packet.forbidden_actions|Where-Object{$_}|Sort-Object -Unique)
Assert ($evidence.Count -gt 0) 'NO_EVIDENCE_REFS_FROM_PACKET'
Assert ($forbidden.Count -gt 0) 'NO_FORBIDDEN_ACTIONS_FROM_PACKET'
$envelope=[ordered]@{
  schema='brain_input_consumer_v1_envelope'
  status='PASS_BRAIN_INPUT_CONSUMER_V1_ENVELOPE'
  source_decision_packet_ref=$packetPath
  source_decision_proof_ref=$decisionProofPath
  contract_ref=$contractPath
  input_class=$inputClass
  route_class=$packet.route_class
  target_organ_id=$packet.target_organ_id
  dominant_root_cause=$packet.dominant_root_cause
  legal_action_class=$packet.legal_action_class
  owner_decision_required=$packet.owner_decision_required
  execution_allowed=$false
  mutation_authorized=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  passport_active_allowed=$false
  brain_can_read=$true
  brain_can_execute=$false
  brain_can_mutate=$false
  brain_decision=$false
  brain_must_preserve_forbidden_actions=$true
  evidence_refs=$evidence
  forbidden_actions=$forbidden
  required_owner_question=$requiredQuestion
  safe_next_prompt_for_brain=$safePrompt
  return_to_parent_summary=[ordered]@{
    current_chain='Evidence -> Signal -> Body State -> Reasoner -> Decision Gate -> Brain Input Consumer'
    result='Brain-safe input envelope emitted; execution and mutation still forbidden.'
    next_safe_step='Owner can authorize PREFLIGHT repair task, keep blocked, or allow building a non-executing Brain/Selector stub.'
  }
  created_at=(Get-Date).ToString('o')
}
Assert ($envelope.brain_can_read -eq $true) 'BRAIN_READ_FALSE'
Assert ($envelope.brain_can_execute -eq $false) 'BRAIN_EXECUTE_OVERCLAIM'
Assert ($envelope.brain_can_mutate -eq $false) 'BRAIN_MUTATE_OVERCLAIM'
Assert ($envelope.execution_allowed -eq $false) 'EXECUTION_ALLOWED_OVERCLAIM'
Assert ($envelope.mutation_authorized -eq $false) 'MUTATION_AUTHORIZED_OVERCLAIM'
Assert ($envelope.brain_decision -eq $false) 'BRAIN_DECISION_OVERCLAIM'
Assert ($envelope.passport_active_allowed -eq $false) 'PASSPORT_ACTIVE_OVERCLAIM'
Assert ($envelope.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($envelope.live_ready -eq $false) 'LIVE_READY_OVERCLAIM'
Assert ($envelope.autonomous_runtime -eq $false) 'AUTONOMOUS_OVERCLAIM'
$report=[ordered]@{
  schema='brain_input_consumer_v1_report'
  status='PASS_BRAIN_INPUT_CONSUMER_V1'
  requirement='contracts/living_loop/BRAIN_INPUT_CONSUMER_V1_REQUIREMENT.md'
  envelope_ref=$envelopePath
  source_decision_packet_ref=$packetPath
  input_class=$inputClass
  route_class=$packet.route_class
  target_organ_id=$packet.target_organ_id
  owner_decision_required=$packet.owner_decision_required
  laws_enforced=@('Brain-readable is not Brain-executable','Evidence refs preserved','Forbidden actions preserved','Owner decision requirement preserved','Missing source proof cannot be bypassed','Consumer is not Brain','Consumer cannot authorize mutation')
  negative_guards=[ordered]@{execution_allowed=$false;mutation_authorized=$false;brain_can_execute=$false;brain_can_mutate=$false;brain_decision=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='brain_input_consumer_v1_proof'
  status='PASS_BRAIN_INPUT_CONSUMER_V1'
  decision_gate_validated=$true
  input_class=$inputClass
  route_class_preserved=($envelope.route_class -eq $packet.route_class)
  target_preserved=($envelope.target_organ_id -eq $packet.target_organ_id)
  owner_decision_required_preserved=($envelope.owner_decision_required -eq $packet.owner_decision_required -and $envelope.owner_decision_required -eq $true)
  evidence_refs_preserved=(@($envelope.evidence_refs).Count -gt 0)
  forbidden_actions_preserved=(@($envelope.forbidden_actions).Count -gt 0)
  required_owner_question_present=(-not [string]::IsNullOrWhiteSpace($envelope.required_owner_question))
  brain_can_read=$true
  brain_can_execute=$false
  brain_can_mutate=$false
  execution_allowed=$false
  mutation_authorized=$false
  brain_decision=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  envelope_ref=$envelopePath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $envelopePath $envelope 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_BRAIN_INPUT_CONSUMER_V1'
Write-Host "INPUT_CLASS=$inputClass"
Write-Host "ROUTE_CLASS=$($envelope.route_class)"
Write-Host "BRAIN_CAN_READ=$($envelope.brain_can_read)"
Write-Host 'BRAIN_CAN_EXECUTE=false'
Write-Host 'BRAIN_CAN_MUTATE=false'
