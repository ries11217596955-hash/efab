$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
$auditPath='reports/self_development/ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1.json'
Assert (Test-Path $auditPath) 'TAIL_AUDIT_MISSING'
$audit=Get-Content $auditPath -Raw|ConvertFrom-Json
Assert ($audit.status -eq 'PASS_ORGAN_PASSPORT_TAIL_DEDUP_AUDIT_V1') 'TAIL_AUDIT_NOT_PASS'
$queue=@()
foreach($d in @($audit.decisions)){
  $ownerDecision='NO_OWNER_DECISION_NEEDED_FOR_NOW'
  $safeAction='KEEP_CURRENT_FILES_AND_RECORD_CLASSIFICATION'
  $requiresOwner=$false
  $deleteRisk='NONE'
  $nextNoDeleteAction=''
  switch($d.organ_id){
    'operations_contracts' {
      $ownerDecision='OWNER_APPROVE_DOWNCLASSIFY_TO_REFERENCE_OR_KEEP_AS_DRAFT'
      $safeAction='mark as downclassify candidate in queue only'
      $requiresOwner=$true
      $deleteRisk='do not delete: may hold useful contract material and duplicate-map evidence'
      $nextNoDeleteAction='create follow-up patch to set passport_kind=GOVERNANCE_MATERIAL_REFERENCE or merge under existing contracts_* passports after Owner approval'
    }
    'operations_smoke_trials' {
      $ownerDecision='OWNER_APPROVE_DELETE_CANDIDATE_OR_KEEP_AS_TEST_REFERENCE'
      $safeAction='mark as delete/downclassify candidate in queue only'
      $requiresOwner=$true
      $deleteRisk='do not delete yet: fixtures may still support validators/tests'
      $nextNoDeleteAction='classify as TEST_FIXTURE_REFERENCE; deletion only after dependency scan and Owner approval'
    }
    'operations_active_behavior' {
      $ownerDecision='NO_DELETE_KEEP_DRAFT'
      $safeAction='run existing executable validators in later proof-run packet, or leave DRAFT'
      $requiresOwner=$false
      $deleteRisk='deleting would remove plausible organ surface'
      $nextNoDeleteAction='run validators and attach proof_refs if they pass; otherwise keep draft with blockers'
    }
    'operations_organ_promotion_lanes' {
      $ownerDecision='NO_DELETE_KEEP_GOVERNANCE_DRAFT'
      $safeAction='add second independent validator surface before promotion'
      $requiresOwner=$false
      $deleteRisk='deleting would break passport maturity/governance flow'
      $nextNoDeleteAction='build/read-only second-surface validator that cross-checks lanes against passport index and body map'
    }
    'operations_overnight_school' {
      $ownerDecision='NO_DELETE_KEEP_LONG_RUNTIME_DRAFT'
      $safeAction='keep corrected validator link; require long-runtime boundary before promotion'
      $requiresOwner=$false
      $deleteRisk='deleting could remove useful long-school process; promoting too early is also unsafe'
      $nextNoDeleteAction='run only bounded validator/proof or create long-runtime boundary gate; no overnight/live run by default'
    }
  }
  $queue += [ordered]@{
    organ_id=$d.organ_id
    current_audit_decision=$d.decision
    classification=$d.classification
    owner_decision_needed=$requiresOwner
    owner_decision_prompt=$ownerDecision
    safe_action_now=$safeAction
    next_no_delete_action=$nextNoDeleteAction
    delete_risk=$deleteRisk
    evidence_reason=$d.reason
    risk=$d.risk
  }
}
$reportPath='reports/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1.json'
$mdPath='reports/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1.md'
$proofPath='tests/self_development/OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1_PROOF.json'
$needsOwner=@($queue|Where-Object{$_.owner_decision_needed -eq $true})
$noDelete=@($queue|Where-Object{$_.owner_decision_needed -eq $false})
$report=[ordered]@{
 schema='owner_facing_organ_cleanup_queue_v1'
 status='PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1'
 source_audit=$auditPath
 queue=$queue
 summary=[ordered]@{
   total=$queue.Count
   owner_decision_required=$needsOwner.Count
   safe_keep_or_proof_actions=$noDelete.Count
   delete_candidates_without_deletion=(@($queue|Where-Object{$_.owner_decision_prompt -match 'DELETE_CANDIDATE'}).Count)
   downclassify_candidates_without_mutation=(@($queue|Where-Object{$_.current_audit_decision -eq 'DOWNCLASSIFY_CANDIDATE'}).Count)
 }
 boundaries=[ordered]@{queue_only=$true;no_files_deleted=$true;no_passport_promoted=$true;no_passport_downclassified=$true;no_pasport_active_created=$true;no_live_runtime_touched=$true;owner_must_approve_deletion=$true}
 created_at=(Get-Date).ToString('o')
}
$lines=@()
$lines += '# Owner-facing organ cleanup queue V1'
$lines += ''
$lines += 'STATUS: PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1'
$lines += ''
$lines += 'This queue does not delete files, promote passports, or downclassify passports. It only converts audit findings into Owner decisions and safe next actions.'
$lines += ''
$lines += '## Summary'
$lines += "- Total items: $($queue.Count)"
$lines += "- Owner decision required: $($needsOwner.Count)"
$lines += "- Safe keep/proof actions: $($noDelete.Count)"
$lines += "- Delete candidates without deletion: $(@($queue|Where-Object{$_.owner_decision_prompt -match 'DELETE_CANDIDATE'}).Count)"
$lines += ''
$lines += '## Queue'
foreach($q in $queue){
  $lines += "### $($q.organ_id)"
  $lines += "- Classification: $($q.classification)"
  $lines += "- Current audit decision: $($q.current_audit_decision)"
  $lines += "- Owner decision needed: $($q.owner_decision_needed)"
  $lines += "- Owner decision prompt: $($q.owner_decision_prompt)"
  $lines += "- Safe action now: $($q.safe_action_now)"
  $lines += "- Next no-delete action: $($q.next_no_delete_action)"
  $lines += "- Delete risk: $($q.delete_risk)"
  $lines += "- Evidence reason: $($q.evidence_reason)"
  $lines += ''
}
$lines += '## Boundaries'
$lines += '- No files deleted.'
$lines += '- No passport promoted.'
$lines += '- No passport downclassified.'
$lines += '- No PASSPORT_ACTIVE created.'
$lines += '- No live runtime touched.'
$lines|Set-Content $mdPath -Encoding UTF8
$proof=[ordered]@{
 schema='owner_facing_organ_cleanup_queue_v1_proof'
 status='PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1'
 total=$queue.Count
 owner_decision_required=$needsOwner.Count
 safe_keep_or_proof_actions=$noDelete.Count
 no_files_deleted=$true
 no_passport_promoted=$true
 no_passport_downclassified=$true
 no_passport_active_created=$true
 no_live_runtime_touched=$true
 report_path=$reportPath
 markdown_path=$mdPath
 created_at=(Get-Date).ToString('o')
}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'QUEUE_PASS=PASS_OWNER_FACING_ORGAN_CLEANUP_QUEUE_V1'
Write-Host ('TOTAL='+$queue.Count)
Write-Host ('OWNER_DECISION_REQUIRED='+$needsOwner.Count)
Write-Host ('SAFE_KEEP_OR_PROOF_ACTIONS='+$noDelete.Count)
Write-Host "REPORT_PATH=$reportPath"
Write-Host "MARKDOWN_PATH=$mdPath"
Write-Host "PROOF_PATH=$proofPath"
