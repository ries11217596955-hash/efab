$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){if(-not $Cond){throw $Msg}}
function WJson($Obj,[string]$Path){$d=Split-Path $Path -Parent;if($d -and -not(Test-Path $d)){New-Item -ItemType Directory -Path $d -Force|Out-Null};$Obj|ConvertTo-Json -Depth 60|Set-Content $Path -Encoding UTF8}
$passportPath='self_model/organ_passports/operations_live_readiness/ORGAN_PASSPORT_V1.json'
$reportPath='reports/self_development/OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1.json'
$proofPath='tests/self_development/OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1_PROOF.json'
Assert (Test-Path $passportPath) 'PASSPORT_MISSING'
$validators=@(
 'operations/live_readiness/validate_detached_long_runtime_stopfile_contract_v1.ps1',
 'operations/live_readiness/validate_live_reject_and_forget_contract_v1.ps1',
 'operations/live_readiness/validate_live_rollback_contract_v1.ps1',
 'operations/live_readiness/validate_school_aimo_continuous_runtime_proof_v1.ps1',
 'operations/live_readiness/validate_school_aimo_live_readiness_gate_v1.ps1'
)
$checks=@()
foreach($v in $validators){
  Assert (Test-Path $v) "VALIDATOR_MISSING:$v"
  $out=& powershell -ExecutionPolicy Bypass -File $v 2>&1
  $exit=$LASTEXITCODE
  if($exit -ne 0){ throw "VALIDATOR_FAILED:$v`n$($out|Out-String)" }
  $statusLine=@($out|Where-Object{$_ -match 'VALIDATION_PASS='}|Select-Object -First 1)
  $proofLine=@($out|Where-Object{$_ -match 'PROOF_PATH='}|Select-Object -First 1)
  $checks += [ordered]@{validator=$v;exit_code=$exit;status=($statusLine -replace '^.*VALIDATION_PASS=','');proof_path=($proofLine -replace '^.*PROOF_PATH=','');output=@($out)}
}
$gateProof='tests/live_readiness/SCHOOL_AIMO_LIVE_READINESS_GATE_V1_PROOF.json'
$continuousProof='tests/live_readiness/SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1_PROOF.json'
Assert (Test-Path $gateProof) 'GATE_PROOF_MISSING'
Assert (Test-Path $continuousProof) 'CONTINUOUS_PROOF_MISSING'
$gate=Get-Content $gateProof -Raw|ConvertFrom-Json
$continuous=Get-Content $continuousProof -Raw|ConvertFrom-Json
Assert ($gate.status -eq 'PASS_SCHOOL_AIMO_LIVE_READINESS_GATE_NO_GO_V1') 'EXPECTED_NO_GO_GATE'
Assert ($gate.technical_runtime_ready -eq $true) 'GATE_TECHNICAL_READY_FALSE'
Assert ($gate.live_ready -eq $false) 'GATE_LIVE_READY_NOT_FALSE'
Assert ($gate.owner_live_authorized -eq $false) 'OWNER_AUTH_NOT_FALSE'
Assert (@($gate.checks.go_blockers) -contains 'OWNER_LIVE_AUTHORIZATION_MISSING') 'OWNER_AUTH_BLOCKER_MISSING'
Assert ($continuous.status -eq 'PASS_SCHOOL_AIMO_CONTINUOUS_RUNTIME_PROOF_V1') 'CONTINUOUS_STATUS_BAD'
Assert ($continuous.technical_runtime_ready -eq $true) 'CONTINUOUS_TECH_READY_FALSE'
Assert ($continuous.live_ready -eq $false) 'CONTINUOUS_LIVE_READY_NOT_FALSE'
$p=Get-Content $passportPath -Raw|ConvertFrom-Json
$p.maturity='VALIDATED_LAB'
$p.live_or_lab_status='PROVEN_LAB'
$p.last_validated_at=(Get-Date).ToString('o')
$p.proof_refs=@(($p.proof_refs + $proofPath + $reportPath + $gateProof + $continuousProof)|Where-Object{$_}|Sort-Object -Unique)
$p.gaps=@('PROVEN_LIVE forbidden until Owner live authorization and separate live proof','PASSPORT_ACTIVE forbidden until activation validator and owner acceptance')
if(@($p.safety_boundaries) -notcontains 'lab validated does not equal live authorization'){$p.safety_boundaries=@($p.safety_boundaries)+'lab validated does not equal live authorization'}
$p|ConvertTo-Json -Depth 50|Set-Content $passportPath -Encoding UTF8
$report=[ordered]@{
 schema='operations_live_readiness_lab_validation_v1'
 status='PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1'
 organ_id='operations_live_readiness'
 passport_path=$passportPath
 validators=$checks
 gate=[ordered]@{status=$gate.status;technical_runtime_ready=$gate.technical_runtime_ready;runtime_ready=$gate.runtime_ready;live_ready=$gate.live_ready;owner_live_authorized=$gate.owner_live_authorized;decision=$gate.decision;go_blockers=@($gate.checks.go_blockers)}
 continuous=[ordered]@{status=$continuous.status;technical_runtime_ready=$continuous.technical_runtime_ready;live_ready=$continuous.live_ready}
 passport_update=[ordered]@{maturity='VALIDATED_LAB';live_or_lab_status='PROVEN_LAB';status_preserved='PASSPORT_DRAFT_FROM_EVIDENCE'}
 boundaries=[ordered]@{lab_validation_only=$true;no_active_passports_created=$true;no_proven_live_claim=$true;live_process_touched=$false;live_authorization_missing=$true;live_ready=$false}
 created_at=(Get-Date).ToString('o')
}
$proof=[ordered]@{
 schema='operations_live_readiness_lab_validation_v1_proof'
 status='PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1'
 organ_id='operations_live_readiness'
 validators_passed=$validators.Count
 maturity='VALIDATED_LAB'
 live_or_lab_status='PROVEN_LAB'
 technical_runtime_ready=$true
 live_ready=$false
 owner_live_authorized=$false
 live_blocker='OWNER_LIVE_AUTHORIZATION_MISSING'
 no_active_passports_created=$true
 no_proven_live_claim=$true
 live_process_touched=$false
 report_path=$reportPath
 passport_path=$passportPath
 created_at=(Get-Date).ToString('o')
}
WJson $report $reportPath
WJson $proof $proofPath
Write-Host 'LAB_VALIDATION_PASS=PASS_OPERATIONS_LIVE_READINESS_LAB_VALIDATION_V1'
Write-Host 'PASSPORT_MATURITY=VALIDATED_LAB'
Write-Host 'LIVE_OR_LAB_STATUS=PROVEN_LAB'
Write-Host 'LIVE_READY=false'
Write-Host 'LIVE_BLOCKER=OWNER_LIVE_AUTHORIZATION_MISSING'
Write-Host "REPORT_PATH=$reportPath"
Write-Host "PROOF_PATH=$proofPath"
