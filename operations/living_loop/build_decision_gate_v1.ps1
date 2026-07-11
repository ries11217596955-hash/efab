$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$reasonerPath='reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json'
$reasonerProofPath='tests/self_development/REASONER_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$packetPath='reports/self_development/DECISION_GATE_V1_DECISION_PACKET.json'
$reportPath='reports/self_development/DECISION_GATE_V1_REPORT.json'
$proofPath='tests/self_development/DECISION_GATE_V1_PROOF.json'
foreach($p in @($reasonerPath,$reasonerProofPath,$contractPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_reasoner_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'REASONER_VALIDATION_FAILED'
$r=Get-Content $reasonerPath -Raw|ConvertFrom-Json
$rp=Get-Content $reasonerProofPath -Raw|ConvertFrom-Json
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_REASONER_V1_CAUSAL_EXPLANATION') 'REASONER_STATUS_BAD'
Assert ($rp.status -eq 'PASS_REASONER_V1') 'REASONER_PROOF_STATUS_BAD'
$dominant=[string]$r.summary.dominant_root_cause
$recommended=[string]$r.summary.recommended_next_action_class
$routeClass='STOP_NO_LAWFUL_ACTION'
$target='NONE'
$ownerDecision=$false
$allowed='Stop because no lawful route was found.'
if($dominant -eq 'MISSING_SOURCE_PROOF' -and $recommended -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'){
  $routeClass='REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'
  $target='operations_active_behavior'
  $ownerDecision=$true
  $allowed='Prepare a separate owner-authorized repair/preflight task to locate or rebuild the missing source proof; otherwise keep organ BLOCKED.'
}elseif($recommended -match 'PRESERVE_BOUNDARIES'){
  $routeClass='PRESERVE_BOUNDARY_AND_CONTINUE_NON_EXECUTING_LAYER'
  $target='living_loop_boundary_state'
  $ownerDecision=$false
  $allowed='Continue non-executing reasoning or require separate live gate for live claims.'
}
$findings=@($r.findings)
$targetFindings=@($findings|Where-Object{$_.organ_id -eq $target -or $_.finding_class -eq 'BLOCKED_SOURCE_PROOF_ROOT_CAUSE'})
$evidence=@($targetFindings|ForEach-Object{@($_.evidence_refs)}|Where-Object{$_}|Sort-Object -Unique)
$forbidden=@($targetFindings|ForEach-Object{@($_.forbidden_actions)}|Where-Object{$_}|Sort-Object -Unique)
if($evidence.Count -eq 0){$evidence=@($reasonerPath,$reasonerProofPath)}
if($forbidden.Count -eq 0){$forbidden=@('EXECUTE_WITHOUT_AUTHORITY','MUTATE_WITHOUT_AUTHORITY','CLAIM_RUNTIME_READY','CREATE_PASSPORT_ACTIVE')}
$packet=[ordered]@{
  schema='decision_gate_v1_decision_packet'
  status='PASS_DECISION_GATE_V1_DECISION_PACKET'
  source_reasoner_ref=$reasonerPath
  source_reasoner_proof_ref=$reasonerProofPath
  contract_ref=$contractPath
  route_class=$routeClass
  target_organ_id=$target
  dominant_root_cause=$dominant
  legal_action_class=$recommended
  owner_decision_required=$ownerDecision
  execution_allowed=$false
  mutation_authorized=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  brain_decision=$false
  evidence_refs=$evidence
  forbidden_actions=$forbidden
  allowed_next_step_description=$allowed
  return_to_parent_summary=[ordered]@{
    current_chain='Evidence -> Signal -> Body State -> Reasoner -> Decision Gate'
    decision='Brain-safe route packet emitted; no execution authority granted.'
    next_safe_step='Owner-authorized repair preflight for source proof OR keep blocked; alternatively build Brain Input Consumer without execution.'
  }
  created_at=(Get-Date).ToString('o')
}
Assert ($packet.route_class -in @('REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED','KEEP_BLOCKED_NO_ACTION','ASK_OWNER_DECISION','STOP_NO_LAWFUL_ACTION','PRESERVE_BOUNDARY_AND_CONTINUE_NON_EXECUTING_LAYER')) 'ROUTE_CLASS_NOT_ALLOWED'
Assert ($packet.execution_allowed -eq $false) 'EXECUTION_ALLOWED_OVERCLAIM'
Assert ($packet.mutation_authorized -eq $false) 'MUTATION_AUTHORIZED_OVERCLAIM'
Assert ($packet.brain_decision -eq $false) 'BRAIN_DECISION_OVERCLAIM'
Assert ($packet.runtime_ready -eq $false) 'RUNTIME_READY_OVERCLAIM'
Assert ($packet.live_ready -eq $false) 'LIVE_READY_OVERCLAIM'
Assert ($packet.autonomous_runtime -eq $false) 'AUTONOMOUS_OVERCLAIM'
Assert (@($packet.evidence_refs).Count -gt 0) 'NO_EVIDENCE_REFS'
Assert (@($packet.forbidden_actions).Count -gt 0) 'NO_FORBIDDEN_ACTIONS'
$report=[ordered]@{
  schema='decision_gate_v1_report'
  status='PASS_DECISION_GATE_V1'
  requirement='contracts/living_loop/DECISION_GATE_V1_REQUIREMENT.md'
  decision_packet_ref=$packetPath
  source_reasoner_ref=$reasonerPath
  route_class=$routeClass
  target_organ_id=$target
  owner_decision_required=$ownerDecision
  laws_enforced=@('Legal route class is not execution authority','Blocked source proof cannot be bypassed','Brain input includes forbidden actions','Brain input includes evidence refs','Decision Gate is not Brain')
  negative_guards=[ordered]@{execution_allowed=$false;mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;brain_decision=$false;passport_active_created=$false;live_runtime_touched=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='decision_gate_v1_proof'
  status='PASS_DECISION_GATE_V1'
  route_class=$routeClass
  target_organ_id=$target
  route_matches_dominant_root_cause=($dominant -eq 'MISSING_SOURCE_PROOF' -and $routeClass -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED')
  reasoner_validated=$true
  evidence_refs_present=(@($packet.evidence_refs).Count -gt 0)
  forbidden_actions_present=(@($packet.forbidden_actions).Count -gt 0)
  owner_decision_required=$ownerDecision
  execution_allowed=$false
  mutation_authorized=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  brain_decision=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  decision_packet_ref=$packetPath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $packetPath $packet 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_DECISION_GATE_V1'
Write-Host "ROUTE_CLASS=$routeClass"
Write-Host "TARGET=$target"
Write-Host "OWNER_DECISION_REQUIRED=$ownerDecision"
Write-Host 'EXECUTION_ALLOWED=false'
Write-Host 'MUTATION_AUTHORIZED=false'
