$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
$contract=Get-Content 'self_model/ORGAN_PASSPORT_V1_CONTRACT.json' -Raw|ConvertFrom-Json
$reportPath='reports/self_development/ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1.json'
$proofPath='tests/self_development/ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1_PROOF.json'
$indexPath='self_model/organ_passports/_index/ORGAN_PASSPORT_DRAFT_INDEX_V1.json'
foreach($path in @($reportPath,$proofPath,$indexPath)){Assert (Test-Path $path) ("MISSING:{0}" -f $path)}
$r=Get-Content $reportPath -Raw|ConvertFrom-Json
$p=Get-Content $proofPath -Raw|ConvertFrom-Json
$idx=Get-Content $indexPath -Raw|ConvertFrom-Json
Assert ($r.status -eq 'PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1') 'REPORT_STATUS_BAD'
Assert ($p.status -eq 'PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1') 'PROOF_STATUS_BAD'
Assert ($idx.status -eq 'PASS_ORGAN_PASSPORT_DRAFT_INDEX_V1') 'INDEX_STATUS_BAD'
$items=@($r.items)
Assert ($items.Count -eq 2) 'REVIEWED_COUNT_BAD'
foreach($it in $items){
  Assert (Test-Path $it.passport_path) ("PASSPORT_MISSING:{0}" -f $it.organ_id)
  $pass=Get-Content $it.passport_path -Raw|ConvertFrom-Json
  foreach($field in @($contract.required_fields)){Assert ($pass.PSObject.Properties.Name -contains $field) ("FIELD_MISSING:{0}:{1}" -f $it.organ_id,$field)}
  Assert ($pass.status -eq 'PASSPORT_DRAFT_FROM_EVIDENCE') ("STATUS_NOT_DRAFT:{0}" -f $it.organ_id)
  Assert (@('DRAFT','VALIDATED_LAB') -contains $pass.maturity) ("MATURITY_NOT_ALLOWED:{0}:{1}" -f $it.organ_id,$pass.maturity)
  Assert (@('NOT_PROVEN','PROVEN_LAB') -contains $pass.live_or_lab_status) ("LIVE_STATUS_NOT_ALLOWED:{0}:{1}" -f $it.organ_id,$pass.live_or_lab_status)
  Assert ($it.active_claim_detected -eq $false) ("ACTIVE_CLAIM_DETECTED:{0}" -f $it.organ_id)
  Assert ($it.live_claim_detected -eq $false) ("PROVEN_LIVE_CLAIM_DETECTED:{0}" -f $it.organ_id)
}
Assert (@($items|Where-Object{$_.organ_id -eq 'operations_self_model' -and $_.review_decision -eq 'LAB_VALIDATED_NOT_ACTIVE'}).Count -eq 1) 'OPERATIONS_SELF_MODEL_NOT_LAB_VALIDATED_NOT_ACTIVE'
Assert (@($items|Where-Object{$_.organ_id -eq 'contracts_accepted_atom_retention_organ' -and $_.review_decision -eq 'BLOCKED_NO_VALIDATOR_EVIDENCE'}).Count -eq 1) 'ACCEPTED_ATOM_NOT_BLOCKED_NO_VALIDATOR'
Assert ($p.no_active_passports_created -eq $true) 'PROOF_ACTIVE_FALSE'
Assert ($p.no_proven_live_claims -eq $true) 'PROOF_PROVEN_LIVE_FALSE'
foreach($legacy in @('reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json','self_knowledge/BUILDER_SELF_MODEL.json')){Assert (-not(Test-Path $legacy)) ("LEGACY_MAP_PRESENT:{0}" -f $legacy)}
Write-Host 'VALIDATION_PASS=PASS_ORGAN_PASSPORT_DRAFT_REVIEW_AND_INDEX_GATE_V1'
Write-Host ('REPORT_PATH='+$reportPath)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('INDEX_PATH='+$indexPath)
