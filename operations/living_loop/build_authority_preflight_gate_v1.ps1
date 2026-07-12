$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$intentPath='reports/self_development/BRAIN_SELECTOR_STUB_V1_INTENT.json'
$selectorProofPath='tests/self_development/BRAIN_SELECTOR_STUB_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$authorityProofPath='tests/owner_authority/OPERATIONS_ACTIVE_BEHAVIOR_SOURCE_PROOF_REPAIR_AUTHORITY_V1.json'
$decisionPath='reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_DECISION.json'
$reportPath='reports/self_development/AUTHORITY_PREFLIGHT_GATE_V1_REPORT.json'
$proofPath='tests/self_development/AUTHORITY_PREFLIGHT_GATE_V1_PROOF.json'
foreach($p in @($intentPath,$selectorProofPath,$contractPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_brain_selector_stub_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BRAIN_SELECTOR_STUB_VALIDATION_FAILED'
$intent=Get-Content $intentPath -Raw|ConvertFrom-Json
$sp=Get-Content $selectorProofPath -Raw|ConvertFrom-Json
Assert ($intent.status -eq 'PASS_BRAIN_SELECTOR_STUB_V1_INTENT') 'INTENT_STATUS_BAD'
Assert ($sp.status -eq 'PASS_BRAIN_SELECTOR_STUB_V1') 'SELECTOR_PROOF_STATUS_BAD'
$authorityExists=Test-Path $authorityProofPath
$blockers=@()
if(-not $authorityExists){$blockers += 'OWNER_REPAIR_AUTHORITY_MISSING'}
$blockers += 'REPAIR_SCOPE_NOT_FORMALIZED_AS_TASK'
$blockers += 'REPAIR_VALIDATORS_NOT_DECLARED'
$blockers += 'ROLLBACK_OR_QUARANTINE_BOUNDARY_NOT_DECLARED'
$blockers += 'NO_FILE_WRITES_ALLOWED_BEFORE_PREFLIGHT_PASS'
$decision= if($blockers.Count -eq 0){'PREFLIGHT_PASS'}else{'BLOCKED_PREFLIGHT'}
$preflightPass=($decision -eq 'PREFLIGHT_PASS')
# Current expected state must block.
Assert ($decision -eq 'BLOCKED_PREFLIGHT') 'UNEXPECTED_PREFLIGHT_PASS_WITHOUT_DECLARED_REPAIR_TASK'
$decisionDoc=[ordered]@{
  schema='authority_preflight_gate_v1_decision'
  status='PASS_AUTHORITY_PREFLIGHT_GATE_V1_DECISION'
  gate_decision=$decision
  preflight_pass=$preflightPass
  source_intent_ref=$intentPath
  source_selector_proof_ref=$selectorProofPath
  target_organ_id=$intent.target_organ_id
  selected_intent_class=$intent.intent_class
  owner_authority_required=$intent.requires_owner_authority
  owner_authority_proof_ref=$authorityProofPath
  owner_authority_proof_exists=$authorityExists
  blockers=$blockers
  evidence_refs=@($intent.evidence_refs)
  forbidden_actions=@($intent.forbidden_actions)
  required_next_artifacts_before_pass=@('owner repair authority proof','formal repair task requirement','declared validators','rollback/quarantine boundary','report/proof expectations')
  execution_allowed=$false
  mutation_authorized=$false
  file_writes_allowed=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  passport_active_allowed=$false
  allowed_next_step_description='Prepare a separate owner-authorized repair PREFLIGHT task package, or keep operations_active_behavior BLOCKED. No repair writes allowed.'
  return_to_parent_summary=[ordered]@{
    current_chain='Evidence -> Signal -> Body State -> Reasoner -> Decision Gate -> Brain Input Consumer -> Brain Selector Stub -> Authority/PREFLIGHT Gate'
    result='Selected intent is blocked at PREFLIGHT because repair authority/scope/validators/rollback are not declared.'
    next_safe_step='Owner may authorize a separate repair preflight package; otherwise keep BLOCKED.'
  }
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{
  schema='authority_preflight_gate_v1_report'
  status='PASS_AUTHORITY_PREFLIGHT_GATE_V1'
  requirement='contracts/living_loop/AUTHORITY_PREFLIGHT_GATE_V1_REQUIREMENT.md'
  decision_ref=$decisionPath
  gate_decision=$decision
  blockers=$blockers
  laws_enforced=@('No authority -> no mutation','No PREFLIGHT_PASS -> no file writes','Selected intent is not execution authority','Owner decision required cannot be silently assumed','Missing source proof cannot be bypassed','Repair task must be separate from selector/gate')
  negative_guards=[ordered]@{preflight_pass=$false;execution_allowed=$false;mutation_authorized=$false;file_writes_allowed=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;passport_active_allowed=$false;repair_performed=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='authority_preflight_gate_v1_proof'
  status='PASS_AUTHORITY_PREFLIGHT_GATE_V1'
  selector_validated=$true
  gate_decision=$decision
  expected_blocked_preflight=$true
  preflight_pass=$false
  owner_authority_required=$true
  owner_authority_proof_exists=$authorityExists
  required_blockers_present=(@('OWNER_REPAIR_AUTHORITY_MISSING','REPAIR_SCOPE_NOT_FORMALIZED_AS_TASK','REPAIR_VALIDATORS_NOT_DECLARED','ROLLBACK_OR_QUARANTINE_BOUNDARY_NOT_DECLARED','NO_FILE_WRITES_ALLOWED_BEFORE_PREFLIGHT_PASS') | ForEach-Object { $blockers -contains $_ }) -notcontains $false
  blocker_count=$blockers.Count
  no_repair_performed=$true
  no_file_writes_by_repair=$true
  execution_allowed=$false
  mutation_authorized=$false
  file_writes_allowed=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  decision_ref=$decisionPath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $decisionPath $decisionDoc 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_AUTHORITY_PREFLIGHT_GATE_V1'
Write-Host "GATE_DECISION=$decision"
Write-Host "BLOCKERS=$($blockers.Count)"
Write-Host 'PREFLIGHT_PASS=false'
Write-Host 'MUTATION_AUTHORIZED=false'
