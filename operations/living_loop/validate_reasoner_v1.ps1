$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$req='contracts/living_loop/REASONER_V1_REQUIREMENT.md'
$explanationPath='reports/self_development/REASONER_V1_CAUSAL_EXPLANATION.json'
$reportPath='reports/self_development/REASONER_V1_REPORT.json'
$proofPath='tests/self_development/REASONER_V1_PROOF.json'
foreach($p in @($req,$explanationPath,$reportPath,$proofPath)){Assert (Test-Path $p) "MISSING:$p"}
powershell -ExecutionPolicy Bypass -File operations/living_loop/validate_body_state_aggregator_v1.ps1 | Out-Host
Assert ($LASTEXITCODE -eq 0) 'BODY_STATE_AGGREGATOR_VALIDATION_FAILED'
$e=Get-Content $explanationPath -Raw|ConvertFrom-Json
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
Assert ($e.status -eq 'PASS_REASONER_V1_CAUSAL_EXPLANATION') 'EXPLANATION_STATUS_BAD'
Assert ($r.status -eq 'PASS_REASONER_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_REASONER_V1') 'PROOF_STATUS_BAD'
$findings=@($e.findings)
Assert ($findings.Count -ge 7) 'FINDING_COUNT_TOO_LOW'
foreach($cls in @('BLOCKED_SOURCE_PROOF_ROOT_CAUSE','BOUNDARY_GUARD_ROOT_CAUSE','VALIDATED_LAB_NON_ACTIVE_CAUSE','RETURN_TO_PARENT_CAUSE')){Assert (@($findings|Where-Object{$_.finding_class -eq $cls}).Count -ge 1) "MISSING_CLASS:$cls"}
Assert (@($findings|Where-Object{$_.finding_class -eq 'BLOCKED_SOURCE_PROOF_ROOT_CAUSE' -and $_.root_cause -match 'source proof'}).Count -eq 1) 'BLOCKED_ROOT_CAUSE_BAD'
Assert (@($findings|Where-Object{$_.finding_class -eq 'BOUNDARY_GUARD_ROOT_CAUSE'}).Count -ge 2) 'BOUNDARY_FINDINGS_BAD'
Assert (@($findings|Where-Object{$_.finding_class -eq 'VALIDATED_LAB_NON_ACTIVE_CAUSE'}).Count -eq 3) 'VALIDATED_FINDINGS_BAD'
Assert (@($findings|Where-Object{$_.finding_class -eq 'RETURN_TO_PARENT_CAUSE'}).Count -eq 1) 'RETURN_FINDINGS_BAD'
foreach($f in $findings){
  foreach($field in @('finding_id','source_bucket','symptom','root_cause','confidence','evidence_refs','legal_action_class','forbidden_actions','recommended_next_question_or_action_class')){Assert ($f.PSObject.Properties.Name -contains $field) "FINDING_FIELD_MISSING:$field"}
  Assert (@($f.evidence_refs).Count -ge 1) "NO_EVIDENCE_REFS:$($f.finding_id)"
  Assert (@($f.forbidden_actions).Count -ge 1) "NO_FORBIDDEN_ACTIONS:$($f.finding_id)"
  Assert ($f.mutation_authorized -eq $false) "MUTATION_AUTHORIZED:$($f.finding_id)"
  Assert ($f.runtime_ready -eq $false) "RUNTIME_READY_OVERCLAIM:$($f.finding_id)"
  Assert ($f.live_ready -eq $false) "LIVE_READY_OVERCLAIM:$($f.finding_id)"
  Assert ($f.autonomous_runtime -eq $false) "AUTONOMOUS_OVERCLAIM:$($f.finding_id)"
  Assert ($f.brain_decision -eq $false) "BRAIN_DECISION_OVERCLAIM:$($f.finding_id)"
  Assert ($f.execution_performed -eq $false) "EXECUTION_OVERCLAIM:$($f.finding_id)"
}
Assert ($e.summary.dominant_root_cause -eq 'MISSING_SOURCE_PROOF') 'DOMINANT_ROOT_CAUSE_BAD'
Assert ($e.summary.recommended_next_action_class -eq 'REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED') 'NEXT_ACTION_CLASS_BAD'
Assert ($p.required_finding_classes_present -eq $true) 'REQUIRED_CLASSES_PROOF_BAD'
Assert ($p.blocked_root_cause_detected -eq $true) 'BLOCKED_PROOF_BAD'
Assert ($p.boundary_guard_preserved -eq $true) 'BOUNDARY_PROOF_BAD'
Assert ($p.validated_lab_non_active_preserved -eq $true) 'VALIDATED_PROOF_BAD'
Assert ($p.return_to_parent_preserved -eq $true) 'RETURN_PROOF_BAD'
Assert ($p.mutation_authorized -eq $false) 'MUTATION_OVERCLAIM'
Assert ($p.brain_decision -eq $false) 'BRAIN_OVERCLAIM'
Assert ($p.execution_performed -eq $false) 'EXECUTION_OVERCLAIM'
Write-Host 'VALIDATION_PASS=PASS_REASONER_V1'
Write-Host "FINDINGS=$($findings.Count)"
Write-Host 'DOMINANT_ROOT_CAUSE=MISSING_SOURCE_PROOF'
Write-Host 'RECOMMENDED_NEXT_ACTION_CLASS=REPAIR_SOURCE_PROOF_OR_KEEP_BLOCKED'
Write-Host 'BRAIN_DECISION=false'
Write-Host 'EXECUTION_PERFORMED=false'
