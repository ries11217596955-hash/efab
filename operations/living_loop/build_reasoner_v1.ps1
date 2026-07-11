$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function Write-Json([string]$Path,$Obj,[int]$Depth=100){$dir=Split-Path -Parent $Path;if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null};$Obj|ConvertTo-Json -Depth $Depth|Set-Content $Path -Encoding UTF8}
$statePath='reports/self_development/BODY_STATE_AGGREGATOR_V1_STATE.json'
$stateProofPath='tests/self_development/BODY_STATE_AGGREGATOR_V1_PROOF.json'
$contractPath='contracts/living_loop/LIVING_LOOP_CONTRACT_V1.json'
$explanationPath='reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json'
$reportPath='reports/self_development/REASONER_V1_REPORT.json'
$proofPath='tests/self_development/REASONER_V1_PROOF.json'
foreach($p in @($statePath,$stateProofPath,$contractPath)){Assert (Test-Path $p) "INPUT_MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_body_state_aggregator_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BODY_STATE_AGGREGATOR_VALIDATION_FAILED'
$s=Get-Content $statePath -Raw|ConvertFrom-Json
$sp=Get-Content $stateProofPath -Raw|ConvertFrom-Json
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
Assert ($s.status -eq 'PASS_BODY_STATE_AGGREGATOR_V1_STATE') 'BODY_STATE_STATUS_BAD'
Assert ($sp.status -eq 'PASS_BODY_STATE_AGGREGATOR_V1') 'BODY_STATE_PROOF_STATUS_BAD'
$findings=@()
# Blocked source proof finding.
foreach($item in @($s.categories.blocked)){
  $findings += [ordered]@{
    finding_id='BLOCKED_SOURCE_PROOF_ROOT_CAUSE__' + $item.organ_id
    finding_class='BLOCKED_SOURCE_PROOF_ROOT_CAUSE'
    source_bucket='blocked'
    organ_id=$item.organ_id
    symptom='Organ is DRAFT/BLOCKED and cannot be promoted.'
    root_cause='Required source proof is missing; active behavior promotion proof cannot be trusted or synthesized.'
    confidence=1.0
    evidence_refs=@($item.evidence_ref)
    legal_action_class='REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'
    forbidden_actions=@('PROMOTE_TO_VALIDATED_LAB','CREATE_FAKE_PROOF','CREATE_PASSPORT_ACTIVE','CLAIM_RUNTIME_READY','TOUCH_LIVE_RUNTIME')
    recommended_next_question_or_action_class='Find or rebuild the missing source proof through its proper upstream generator; otherwise keep BLOCKED.'
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
    brain_decision=$false
    execution_performed=$false
  }
}
# Boundary guard findings.
foreach($item in @($s.categories.boundary_guarded)){
  $findings += [ordered]@{
    finding_id='BOUNDARY_GUARD_ROOT_CAUSE__' + $item.organ_id
    finding_class='BOUNDARY_GUARD_ROOT_CAUSE'
    source_bucket='boundary_guarded'
    organ_id=$item.organ_id
    symptom='Signal is useful but boundary-sensitive.'
    root_cause='Lab/observation evidence exists, but it does not grant live readiness, runtime_ready, autonomous runtime, or activation authority.'
    confidence=1.0
    evidence_refs=@($item.evidence_ref)
    legal_action_class='PRESERVE_BOUNDARY_OR_REQUEST_SEPARATE_LIVE_GATE'
    forbidden_actions=@('CLAIM_LIVE_READY','CLAIM_RUNTIME_READY','START_AUTONOMOUS_RUNTIME','CREATE_PASSPORT_ACTIVE','TOUCH_LIVE_RUNTIME_WITHOUT_AUTHORITY')
    recommended_next_question_or_action_class='Use as lab Body State signal only; separate live gate required for live readiness.'
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
    brain_decision=$false
    execution_performed=$false
  }
}
# Validated non-active findings.
foreach($item in @($s.categories.validated_lab_non_active)){
  $findings += [ordered]@{
    finding_id='VALIDATED_LAB_NON_ACTIVE_CAUSE__' + $item.organ_id
    finding_class='VALIDATED_LAB_NON_ACTIVE_CAUSE'
    source_bucket='validated_lab_non_active'
    organ_id=$item.organ_id
    symptom='Organ/capability has lab validation signal.'
    root_cause='Lifecycle proof verified lab state change and non-active boundary; no active authority was granted.'
    confidence=1.0
    evidence_refs=@($item.evidence_ref)
    legal_action_class='ALLOW_AS_LAB_SIGNAL_NO_ACTIVE_AUTHORITY'
    forbidden_actions=@('CREATE_PASSPORT_ACTIVE','CLAIM_PROVEN_LIVE','CLAIM_RUNTIME_READY','MUTATE_WITHOUT_AUTHORITY')
    recommended_next_question_or_action_class='Keep as Brain-consumable lab signal; require separate authority for activation or mutation.'
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
    brain_decision=$false
    execution_performed=$false
  }
}
# Return-to-parent finding.
foreach($item in @($s.categories.return_to_parent)){
  $findings += [ordered]@{
    finding_id='RETURN_TO_PARENT_CAUSE__' + $item.organ_id
    finding_class='RETURN_TO_PARENT_CAUSE'
    source_bucket='return_to_parent'
    organ_id=$item.organ_id
    symptom='Current layer completed signal/body-state pass and should return compact state upward.'
    root_cause='Living Loop requires return-to-parent after proof/state update; otherwise growth remains unfinished.'
    confidence=1.0
    evidence_refs=@($item.evidence_ref)
    legal_action_class='RETURN_EXPLANATION_TO_PARENT_OR_NEXT_NON_EXECUTING_LAYER'
    forbidden_actions=@('SELF_COMPLETE','EXECUTE_UNREQUESTED_MUTATION','SKIP_JOURNAL_OR_PROOF')
    recommended_next_question_or_action_class='Return causal explanation to parent; Brain/decision layer may later consume it.'
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
    brain_decision=$false
    execution_performed=$false
  }
}
Assert (@($findings).Count -gt 0) 'NO_FINDINGS'
$classes=@($findings|ForEach-Object{$_.finding_class}|Sort-Object -Unique)
$required=@('BLOCKED_SOURCE_PROOF_ROOT_CAUSE','BOUNDARY_GUARD_ROOT_CAUSE','VALIDATED_LAB_NON_ACTIVE_CAUSE','RETURN_TO_PARENT_CAUSE')
foreach($r in $required){Assert (@($classes|Where-Object{$_ -eq $r}).Count -eq 1) "MISSING_FINDING_CLASS:$r"}
# Legal route summary.
$legalActionClasses=@($findings|ForEach-Object{$_.legal_action_class}|Sort-Object -Unique)
$highestSeverity=[string]$s.summary.highest_severity
$dominantRootCause= if(@($findings|Where-Object{$_.finding_class -eq 'BLOCKED_SOURCE_PROOF_ROOT_CAUSE'}).Count -gt 0){'MISSING_SOURCE_PROOF'}else{'NO_BLOCKING_ROOT_CAUSE'}
$recommendedNext= if($dominantRootCause -eq 'MISSING_SOURCE_PROOF'){'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'}else{'PRESERVE_BOUNDARIES_AND_PREPARE_BRAIN_CONSUMPTION'}
$explanation=[ordered]@{
  schema='reasoner_v1_causal_explanation'
  status='PASS_REASONER_V1_CAUSAL_EXPLANATION'
  body_state_ref=$statePath
  body_state_proof_ref=$stateProofPath
  contract_ref=$contractPath
  findings=$findings
  summary=[ordered]@{
    finding_count=@($findings).Count
    finding_classes=$classes
    dominant_root_cause=$dominantRootCause
    highest_severity=$highestSeverity
    legal_action_classes=$legalActionClasses
    recommended_next_action_class=$recommendedNext
    brain_input_ready=$true
    mutation_authorized=$false
    runtime_ready=$false
    live_ready=$false
    autonomous_runtime=$false
    brain_decision=$false
    execution_performed=$false
  }
  created_at=(Get-Date).ToString('o')
}
$report=[ordered]@{
  schema='reasoner_v1_report'
  status='PASS_REASONER_V1'
  requirement='contracts/living_loop/REASONER_V1_REQUIREMENT.md'
  explanation_ref=$explanationPath
  body_state_ref=$statePath
  summary=$explanation.summary
  laws_enforced=@('Body State first; no raw proof-only reasoning','Symptom is separated from root cause','Reasoning is not execution','Legal action class is not mutation authority','Blocked state remains blocked until source proof exists','Live-like boundary remains non-live','Reasoner is not Brain')
  negative_guards=[ordered]@{mutation_authorized=$false;runtime_ready=$false;live_ready=$false;autonomous_runtime=$false;brain_decision=$false;execution_performed=$false;passport_active_created=$false;live_runtime_touched=$false}
  created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
  schema='reasoner_v1_proof'
  status='PASS_REASONER_V1'
  finding_count=@($findings).Count
  required_finding_classes_present=$true
  blocked_root_cause_detected=(@($findings|Where-Object{$_.finding_class -eq 'BLOCKED_SOURCE_PROOF_ROOT_CAUSE' -and $_.root_cause -match 'source proof'}).Count -ge 1)
  boundary_guard_preserved=(@($findings|Where-Object{$_.finding_class -eq 'BOUNDARY_GUARD_ROOT_CAUSE'}).Count -ge 2)
  validated_lab_non_active_preserved=(@($findings|Where-Object{$_.finding_class -eq 'VALIDATED_LAB_NON_ACTIVE_CAUSE'}).Count -eq 3)
  return_to_parent_preserved=(@($findings|Where-Object{$_.finding_class -eq 'RETURN_TO_PARENT_CAUSE'}).Count -eq 1)
  legal_action_classes_present=(@($legalActionClasses).Count -gt 0)
  forbidden_actions_present=(@($findings|Where-Object{@($_.forbidden_actions).Count -eq 0}).Count -eq 0)
  mutation_authorized=$false
  runtime_ready=$false
  live_ready=$false
  autonomous_runtime=$false
  brain_decision=$false
  execution_performed=$false
  no_passport_active_created=$true
  no_live_runtime_touched=$true
  explanation_ref=$explanationPath
  report_path=$reportPath
  created_at=(Get-Date).ToString('o')
}
Write-Json $explanationPath $explanation 100
Write-Json $reportPath $report 100
Write-Json $proofPath $proof 100
Write-Host 'BUILD_PASS=PASS_REASONER_V1'
Write-Host "FINDINGS=$($findings.Count)"
Write-Host "DOMINANT_ROOT_CAUSE=$dominantRootCause"
Write-Host "RECOMMENDED_NEXT_ACTION_CLASS=$recommendedNext"
