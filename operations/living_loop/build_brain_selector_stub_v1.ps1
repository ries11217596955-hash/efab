$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$envelopePath='reports/self_development/BRAIN_INPUT_CONSUMER_V1_ENVELOPE.json'
$consumerProofPath='tests/self_development/BRAIN_INPUT_CONSUMER_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$intentPath='reports/self_development/BRAIN_SELECTOR_STUB_V1_INTENT.json'
$reportPath='reports/self_development/BRAIN_SELECTOR_STUB_V1_REPORT.json'
$proofPath='tests/self_development/BRAIN_SELECTOR_STUB_V1_PROOF.json'
foreach($p in @($envelopePath,$consumerProofPath,$contractPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_brain_input_consumer_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BRAIN_INPUT_CONSUMER_VALIDATION_FAILED'
$env=Get-Content $envelopePath -Raw|ConvertFrom-Json
$cp=Get-Content $consumerProofPath -Raw|ConvertFrom-Json
Assert ($env.status -eq 'PASS_BRAIN_INPUT_CONSUMER_V1_ENVELOPE') 'ENVELOPE_STATUS_BAD'
Assert ($cp.status -eq 'PASS_BRAIN_INPUT_CONSUMER_V1') 'CONSUMER_PROOF_STATUS_BAD'
$intentClass='STOP_NO_LAWFUL_INTENT'
$allowed='Stop: no lawful intent selected.'
if($env.input_class -eq 'OWNER_DECISION_REQUIRED_REPAIR_OR_KEEP_BLOCKED' -and $env.route_class -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'){
  $intentClass='REQUEST_OWNER_AUTHORIZED_PREFLIGHT_REPAIR_OR_KEEP_BLOCKED'
  $allowed='Ask Owner to choose: authorize a separate PREFLIGHT repair task for operations_active_behavior source proof, or keep the organ BLOCKED. Do not repair yet.'
}elseif($env.owner_decision_required -eq $true){
  $intentClass='ASK_OWNER_DECISION_ONLY'
  $allowed='Ask Owner for decision. Do not execute.'
}
$evidence=@($env.evidence_refs|Where-Object{$_}|Sort-Object -Unique)
$forbidden=@($env.forbidden_actions|Where-Object{$_}|Sort-Object -Unique)
Assert ($evidence.Count -gt 0) 'NO_EVIDENCE_REFS_FROM_ENVELOPE'
Assert ($forbidden.Count -gt 0) 'NO_FORBIDDEN_ACTIONS_FROM_ENVELOPE'
$intent=[ordered]@{
  schema='brain_selector_stub_v1_intent'
  status='PASS_BRAIN_SELECTOR_STUB_V1_INTENT'
  source_envelope_ref=$envelopePath
  source_consumer_proof_ref=$consumerProofPath
  contract_ref=$contractPath
  intent_class=$intentClass
  target_organ_id=$env.target_organ_id
  source_route_class=$env.route_class
  dominant_root_cause=$env.dominant_root_cause
  owner_decision_required=$env.owner_decision_required
  selected_by_brain_stub=$true
  full_brain=$false
  execution_allowed=$false
  mutation_authorized=$false
  brain_can_execute=$false
  brain_can_mutate=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  passport_active_allowed=$false
  requires_preflight=$true
  requires_owner_authority=$true
  evidence_refs=$evidence
  forbidden_actions=$forbidden
  allowed_next_step_description=$allowed
  stop_conditions=@('Missing source proof remains absent','Owner authority not granted','PREFLIGHT not passed','Any mutation would be required','Any live/runtime claim appears')
  return_to_parent_summary=[ordered]@{
    current_chain='Evidence -> Signal -> Body State -> Reasoner -> Decision Gate -> Brain Input Consumer -> Brain Selector Stub'
    result='Candidate intent selected without execution authority.'
    next_safe_step='Return to Owner for authority decision or build an authority/passport gate; do not mutate.'
  }
  created_at=(Get-Date).ToString('o')
}
foreach($pair in @(
  @($intent.full_brain,$false,'FULL_BRAIN_OVERCLAIM'),@($intent.execution_allowed,$false,'EXECUTION_OVERCLAIM'),@($intent.mutation_authorized,$false,'MUTATION_OVERCLAIM'),@($intent.brain_can_execute,$false,'BRAIN_EXECUTE_OVERCLAIM'),@($intent.brain_can_mutate,$false,'BRAIN_MUTATE_OVERCLAIM'),@($intent.runtime_ready,$false,'RUNTIME_READY_OVERCLAIM'),@($intent.live_ready,$false,'LIVE_READY_OVERCLAIM'),@($intent.autonomous_runtime,$false,'AUTONOMOUS_OVERCLAIM'),@($intent.passport_active_allowed,$false,'PASSPORT_ACTIVE_OVERCLAIM')
)){Assert ($pair[0] -eq $pair[1]) $pair[2]}
Assert ($intent.requires_preflight -eq $true) 'PREFLIGHT_NOT_REQUIRED'
Assert ($intent.requires_owner_authority -eq $true) 'OWNER_AUTHORITY_NOT_REQUIRED'
$report=[ordered]@{
  schema='brain_selector_stub_v1_report'
  status='PASS_BRAIN_SELECTOR_STUB_V1'
  requirement='contracts/living_loop/BRAIN_SELECTOR_STUB_V1_REQUIREMENT.md'
  intent_ref=$intentPath
  source_envelope_ref=$envelopePath
  intent_class=$intentClass
  target_organ_id=$env.target_organ_id
  laws_enforced=@('Candidate intent is not execution','Brain stub is not full Brain','Owner decision requirement preserved','Missing source proof cannot be bypassed','Forbidden actions preserved','Evidence refs preserved','Preflight required before repair mutation')
  negative_guards=[ordered]@{full_brain=$false;execution_allowed=$false;mutation_authorized=$false;brain_can_execute=$false;brain_can_mutate=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='brain_selector_stub_v1_proof'
  status='PASS_BRAIN_SELECTOR_STUB_V1'
  consumer_validated=$true
  intent_class=$intentClass
  selected_intent_matches_route=($intentClass -eq 'REQUEST_OWNER_AUTHORIZED_PREFLIGHT_REPAIR_OR_KEEP_BLOCKED' -and $env.route_class -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED')
  target_preserved=($intent.target_organ_id -eq $env.target_organ_id)
  owner_decision_required_preserved=($intent.owner_decision_required -eq $true)
  requires_preflight=$true
  requires_owner_authority=$true
  evidence_refs_preserved=(@($intent.evidence_refs).Count -gt 0)
  forbidden_actions_preserved=(@($intent.forbidden_actions).Count -gt 0)
  selected_by_brain_stub=$true
  full_brain=$false
  execution_allowed=$false
  mutation_authorized=$false
  brain_can_execute=$false
  brain_can_mutate=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  intent_ref=$intentPath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $intentPath $intent 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_BRAIN_SELECTOR_STUB_V1'
Write-Host "INTENT_CLASS=$intentClass"
Write-Host "TARGET=$($intent.target_organ_id)"
Write-Host 'FULL_BRAIN=false'
Write-Host 'EXECUTION_ALLOWED=false'
Write-Host 'MUTATION_AUTHORIZED=false'
