$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 80|Set-Content $Path -Encoding UTF8}
$passportPath='self_model/organ_passports/operations_live_start/ORGAN_PASSPORT_V1.json'
$reportPath='reports/self_development/OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1_PROOF.json'
Assert (Test-Path $passportPath) 'PASSPORT_MISSING'
$validators=@(
 'operations/live_start/validate_aimo_agent_only_restart_v1.ps1',
 'operations/live_start/validate_school_aimo_controlled_live_start_v1.ps1'
)
$proofs=@(
 'tests/live_start/AIMO_AGENT_ONLY_RESTART_V1_PROOF.json',
 'tests/live_start/SCHOOL_AIMO_CONTROLLED_LIVE_START_V1_PROOF.json'
)
$proofItems=@()
foreach($f in $proofs){
  Assert (Test-Path $f) "PROOF_FILE_MISSING:$f"
  $p=Get-Content $f -Raw|ConvertFrom-Json
  $proofItems += [pscustomobject]@{path=$f;schema=$p.schema;status=$p.status;proof_label=$p.proof_label;owner_authorized=$p.owner_authorized;live_started=$p.live_started;repo_head=$p.repo.head;active_processes_after=$p.repo.active_processes_after}
}
$liveLabels=@($proofItems|Where-Object{[string]$_.proof_label -match 'PROVEN_LIVE'})
$liveStartProofs=@($proofItems|Where-Object{$_.live_started -eq $true -or $_.active_processes_after -gt 0})
Assert ($liveLabels.Count -ge 1) 'EXPECTED_LIVE_LABEL_NOT_FOUND'
Assert ($liveStartProofs.Count -ge 1) 'EXPECTED_LIVE_START_PROOF_NOT_FOUND'
$pp=Get-Content $passportPath -Raw|ConvertFrom-Json
$pp.maturity='DRAFT'
$pp.live_or_lab_status='NOT_PROVEN'
$pp.last_validated_at=(Get-Date).ToString('o')
$pp.gaps=@('BLOCKED_LIVE_BOUNDARY: existing validators/proofs assert PROVEN_LIVE or live_started; cannot convert to PROVEN_LAB','requires dedicated lab-only validator/proof that does not require live start','PASSPORT_ACTIVE forbidden','PROVEN_LIVE forbidden without fresh live authorization and live proof')
$pp.safety_boundaries=@(($pp.safety_boundaries + 'lab-validation blocked by live-boundary proof labels' + 'no live start during lab-boundary gate')|Where-Object{$_}|Sort-Object -Unique)
$pp.proof_refs=@(($pp.proof_refs + $proofPath + $reportPath)|Where-Object{$_}|Sort-Object -Unique)
$pp|ConvertTo-Json -Depth 60|Set-Content $passportPath -Encoding UTF8
$report=[ordered]@{
 schema='operations_live_start_lab_boundary_gate_v1'
 status='BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1'
 organ_id='operations_live_start'
 passport_path=$passportPath
 validators=$validators
 inspected_proofs=$proofItems
 decision='DO_NOT_PROMOTE_TO_VALIDATED_LAB'
 root_cause='validators/proofs are live-start proofs, not lab-only organ validation proofs'
 required_next='create separate lab-only live-start contract validator that checks preconditions/control surfaces without starting live runtime'
 boundaries=[ordered]@{lab_boundary_gate_only=$true;no_validated_lab_claim_created=$true;no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false}
 created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
 schema='operations_live_start_lab_boundary_gate_v1_proof'
 status='BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1'
 organ_id='operations_live_start'
 decision='DO_NOT_PROMOTE_TO_VALIDATED_LAB'
 live_boundary_detected=$true
 live_proof_label_count=$liveLabels.Count
 live_start_proof_count=$liveStartProofs.Count
 maturity='DRAFT'
 live_or_lab_status='NOT_PROVEN'
 no_validated_lab_claim_created=$true
 no_active_passports_created=$true
 no_proven_live_claim=$true
 live_process_touched=$false
 report_path=$reportPath
 passport_path=$passportPath
 created_at=(Get-Date).ToString('o')
}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'BOUNDARY_GATE=BLOCKED_OPERATIONS_LIVE_START_LAB_BOUNDARY_GATE_V1'
Write-Host 'DECISION=DO_NOT_PROMOTE_TO_VALIDATED_LAB'
Write-Host 'ROOT_CAUSE=LIVE_PROOF_LABELS_NOT_LAB_ONLY'
Write-Host 'LIVE_PROCESS_TOUCHED=false'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
