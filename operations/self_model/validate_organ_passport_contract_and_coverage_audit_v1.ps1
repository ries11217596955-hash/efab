$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$contractPath='self_model/ORGAN_PASSPORT_V1_CONTRACT.json'
$auditJson='reports/self_development/ORGAN_PASSPORT_COVERAGE_AUDIT_V1.json'
$contractDoc='docs/operations/ORGAN_PASSPORT_V1_CONTRACT.md'
$auditMd='docs/operations/ORGAN_PASSPORT_COVERAGE_AUDIT_V1.md'
foreach($p in @($contractPath,$auditJson,$contractDoc,$auditMd)){Assert (Test-Path $p) ("MISSING:{0}" -f $p)}
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
$a=Get-Content $auditJson -Raw|ConvertFrom-Json
Assert ($c.schema -eq 'organ_passport_v1_contract') 'CONTRACT_SCHEMA_BAD'
Assert ($c.status -eq 'ACTIVE_CONTRACT') 'CONTRACT_STATUS_BAD'
foreach($f in @('organ_id','purpose','responsibilities','owned_files','validators','proof_refs','exported_capabilities','safety_boundaries','gaps','source_evidence')){Assert (@($c.required_fields) -contains $f) ("REQUIRED_FIELD_MISSING:{0}" -f $f)}
Assert (@($c.allowed_passport_status) -contains 'PASSPORT_DRAFT_FROM_EVIDENCE') 'DRAFT_STATUS_MISSING'
Assert (@($c.allowed_passport_status) -contains 'PASSPORT_MISSING_BUT_EVIDENCE_EXISTS') 'MISSING_EVIDENCE_STATUS_MISSING'
Assert ($c.auto_draft_policy.allowed -eq $true) 'AUTO_DRAFT_NOT_ALLOWED'
Assert ($c.auto_draft_policy.draft_not_active -eq $true) 'DRAFT_ACTIVE_BOUNDARY_BAD'
Assert ($c.activation_policy.active_requires_validator -eq $true) 'ACTIVE_VALIDATOR_RULE_BAD'
Assert ($c.audit_policy.audit_does_not_delete -eq $true) 'AUDIT_DELETE_RULE_BAD'
Assert (($c.safety_rules -join ' ') -match 'No missing evidence may be filled by guesswork') 'NO_GUESS_RULE_MISSING'
Assert (($c.safety_rules -join ' ') -match 'No audit result may delete') 'NO_DELETE_RULE_MISSING'
Assert ($a.schema -eq 'organ_passport_coverage_audit_v1') 'AUDIT_SCHEMA_BAD'
Assert ($a.status -eq 'PASS_ORGAN_PASSPORT_COVERAGE_AUDIT_V1') 'AUDIT_STATUS_BAD'
Assert ($a.contract_ref -eq $contractPath) 'AUDIT_CONTRACT_REF_BAD'
Assert ($a.summary.total_organs -gt 0) 'NO_ORGANS_AUDITED'
Assert ($a.summary.passport_active -eq 0) 'FALSE_ACTIVE_PASSPORT_CLAIM'
Assert (($a.summary.passport_needs_repair + $a.summary.passport_missing_but_evidence_exists + $a.summary.passport_missing_no_evidence) -eq $a.summary.total_organs) 'SUMMARY_COUNTS_BAD'
foreach($o in @($a.organs)){
  Assert ($o.organ_id) 'ORGAN_ID_MISSING'
  Assert ($o.deletion_allowed -eq $false) ("DELETION_ALLOWED_FOR:{0}" -f $o.organ_id)
  Assert (@($c.allowed_passport_status) -contains $o.passport_status) ("UNKNOWN_PASSPORT_STATUS:{0}:{1}" -f $o.organ_id,$o.passport_status)
  Assert ($o.recommended_next_action) ("NEXT_ACTION_MISSING:{0}" -f $o.organ_id)
}
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_GATE_BAD'
$runtimeSize=(Get-ChildItem .runtime -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum
Assert ([Math]::Round($runtimeSize/1MB,2) -lt 80) 'RUNTIME_SIZE_BAD'
$proof=[ordered]@{
  schema='organ_passport_contract_and_coverage_audit_validation_v1'
  status='PASS_ORGAN_PASSPORT_CONTRACT_AND_COVERAGE_AUDIT_V1'
  contract_path=$contractPath
  audit_path=$auditJson
  audited_organs=[int]$a.summary.total_organs
  active_passports_claimed=[int]$a.summary.passport_active
  passports_needing_repair=[int]$a.summary.passport_needs_repair
  passports_missing_but_evidence_exists=[int]$a.summary.passport_missing_but_evidence_exists
  passports_missing_no_evidence=[int]$a.summary.passport_missing_no_evidence
  deletion_allowed=$false
  best_next_move='ORGAN_PASSPORT_DRAFT_GENERATOR_V1_FROM_EVIDENCE'
  live_pid_now=[int]$liveNow[0].ProcessId
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/ORGAN_PASSPORT_CONTRACT_AND_COVERAGE_AUDIT_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_CONTRACT_AND_COVERAGE_AUDIT_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
