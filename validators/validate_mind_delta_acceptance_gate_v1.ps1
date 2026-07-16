$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err($m){$errors.Add($m)}
function WJson($obj,$path){$dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir | Out-Null}; $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8}
function Assert($cond,$msg){ if(-not $cond){ Add-Err $msg } }
$script='operations/reasoning/evaluate_mind_delta_acceptance_v1.ps1'
Assert (Test-Path $script) 'acceptance_gate_script_missing'
$runtimeDir='.runtime/mind_delta_acceptance_gate_v1'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
function Make-Assim($path,$evidenceCount,$unknowns,$risks){
  $items=@()
  for($i=1;$i -le $evidenceCount;$i++){ $items += [ordered]@{source='fixture'; claim=('claim_'+$i); evidence_status='ANSWER_EVIDENCE_CANDIDATE'} }
  WJson ([ordered]@{
    schema='deep_source_answer_assimilation_v1'
    status='PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1'
    evidence_count=$evidenceCount
    mind_delta_candidate=[ordered]@{
      type='reasoning_delta_candidate'
      status='CANDIDATE_NOT_ACCEPTED'
      known_additions=$items
      unknown_remaining=@($unknowns)
      risks=@($risks)
      next_verification_step='fixture verification'
    }
    boundary=[ordered]@{active_memory_mutated=$false; live_process_touched=$false; external_tool_launched=$false; repo_mutated=$false}
  }) $path
}
$acceptFixture=Join-Path $runtimeDir 'accept_fixture.json'
$assumptionFixture=Join-Path $runtimeDir 'assumption_fixture.json'
$requestFixture=Join-Path $runtimeDir 'request_more_proof_fixture.json'
Make-Assim $acceptFixture 2 @() @()
Make-Assim $assumptionFixture 2 @('unknown still open') @()
Make-Assim $requestFixture 0 @() @()
$acceptOut=Join-Path $runtimeDir 'accept_decision.json'
$assumptionOut=Join-Path $runtimeDir 'assumption_decision.json'
$requestOut=Join-Path $runtimeDir 'request_more_proof_decision.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AssimilationPath $acceptFixture -OutputPath $acceptOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'accept_case_nonzero' }
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AssimilationPath $assumptionFixture -OutputPath $assumptionOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'assumption_case_nonzero' }
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AssimilationPath $requestFixture -OutputPath $requestOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'request_case_nonzero' }
$a=Get-Content $acceptOut -Raw | ConvertFrom-Json
$s=Get-Content $assumptionOut -Raw | ConvertFrom-Json
$r=Get-Content $requestOut -Raw | ConvertFrom-Json
Assert ($a.status -eq 'PASS_MIND_DELTA_ACCEPTANCE_DECISION_V1') ('accept_status_bad:'+ $a.status)
Assert ($a.decision -eq 'ACCEPT_AS_KNOWN_CANDIDATE') ('accept_decision_bad:'+ $a.decision)
Assert ($s.decision -eq 'KEEP_AS_ASSUMPTION') ('assumption_decision_bad:'+ $s.decision)
Assert ($r.decision -eq 'REQUEST_MORE_PROOF') ('request_decision_bad:'+ $r.decision)
foreach($x in @($a,$s,$r)){
  Assert ($x.accepted_memory_update -eq $false) 'accepted_memory_update_should_be_false'
  Assert ($x.accepted_atom -eq $false) 'accepted_atom_should_be_false'
  Assert ($x.boundary.active_memory_mutated -eq $false) 'active_memory_mutated'
  Assert ($x.boundary.external_tool_launched -eq $false) 'external_tool_launched'
  Assert ($x.boundary.codex_launched -eq $false) 'codex_launched'
  Assert ($x.boundary.accepted_core_mutated -eq $false) 'accepted_core_mutated'
}
$status=if($errors.Count -eq 0){'PASS_MIND_DELTA_ACCEPTANCE_GATE_V1'}else{'FAIL_MIND_DELTA_ACCEPTANCE_GATE_V1'}
$proof=[ordered]@{
  schema='mind_delta_acceptance_gate_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  script_path=$script
  accept_decision=$a.decision
  assumption_decision=$s.decision
  request_more_proof_decision=$r.decision
  accepted_memory_mutated=$false
  accepted_core_mutated=$false
  codex_launched=$false
  external_tool_launched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/MIND_DELTA_ACCEPTANCE_GATE_V1_PROOF.json'
WJson $proof $proofPath
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
if($errors.Count -gt 0){ $errors|ForEach-Object{Write-Host ('ERROR='+$_)}; exit 1 }
