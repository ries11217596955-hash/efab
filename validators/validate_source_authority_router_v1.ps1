$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err($m){$errors.Add($m)}
function WJson($obj,$path){$dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir | Out-Null}; $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8}
function Assert($cond,$msg){ if(-not $cond){ Add-Err $msg } }
$script='operations/reasoning/route_source_authority_v1.ps1'
Assert (Test-Path $script) 'source_router_script_missing'
$runtimeDir='.runtime/source_authority_router_v1'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
function Make-Decision($path,$decision,$evidence,$unknown,$risk){
  WJson ([ordered]@{
    schema='mind_delta_acceptance_gate_v1'
    status='PASS_MIND_DELTA_ACCEPTANCE_DECISION_V1'
    decision=$decision
    reason='fixture'
    evidence_count=$evidence
    unknown_count=$unknown
    risk_count=$risk
    accepted_memory_update=$false
    accepted_atom=$false
    boundary=[ordered]@{active_memory_mutated=$false; accepted_core_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; external_tool_launched=$false}
  }) $path
}
$acceptFixture=Join-Path $runtimeDir 'accept_decision_fixture.json'
$assumptionFixture=Join-Path $runtimeDir 'assumption_decision_fixture.json'
$requestFixture=Join-Path $runtimeDir 'request_decision_fixture.json'
Make-Decision $acceptFixture 'ACCEPT_AS_KNOWN_CANDIDATE' 2 0 0
Make-Decision $assumptionFixture 'KEEP_AS_ASSUMPTION' 2 1 0
Make-Decision $requestFixture 'REQUEST_MORE_PROOF' 0 0 0
$acceptOut=Join-Path $runtimeDir 'accept_route.json'
$assumptionOut=Join-Path $runtimeDir 'assumption_route.json'
$requestOut=Join-Path $runtimeDir 'request_route.json'
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AcceptanceDecisionPath $acceptFixture -OutputPath $acceptOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'accept_route_nonzero' }
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AcceptanceDecisionPath $assumptionFixture -OutputPath $assumptionOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'assumption_route_nonzero' }
& powershell -NoProfile -ExecutionPolicy Bypass -File $script -AcceptanceDecisionPath $requestFixture -OutputPath $requestOut | Out-Host
if($LASTEXITCODE -ne 0){ Add-Err 'request_route_nonzero' }
$a=Get-Content $acceptOut -Raw | ConvertFrom-Json
$s=Get-Content $assumptionOut -Raw | ConvertFrom-Json
$r=Get-Content $requestOut -Raw | ConvertFrom-Json
Assert ($a.status -eq 'PASS_SOURCE_AUTHORITY_ROUTE_DECISION_V1') ('accept_status_bad:'+ $a.status)
Assert ($a.route -eq 'LOCAL_ACCEPTANCE_PIPELINE_REQUIRED') ('accept_route_bad:'+ $a.route)
Assert ($s.route -eq 'LOCAL_MEMORY_THEN_REPO_PROOF') ('assumption_route_bad:'+ $s.route)
Assert ($r.route -eq 'SOURCE_LADDER_START_LOCAL') ('request_route_bad:'+ $r.route)
foreach($x in @($a,$s,$r)){
  Assert ($x.boundary.active_memory_mutated -eq $false) 'active_memory_mutated'
  Assert ($x.boundary.accepted_core_mutated -eq $false) 'accepted_core_mutated'
  Assert ($x.boundary.codex_launched -eq $false) 'codex_launched'
  Assert ($x.boundary.web_launched -eq $false) 'web_launched'
  Assert ($x.boundary.action_executed -eq $false) 'action_executed'
  Assert ($x.blocked_now -contains 'codex') 'codex_not_blocked_now'
  Assert ($x.blocked_now -contains 'web_external') 'web_not_blocked_now'
}
$status=if($errors.Count -eq 0){'PASS_SOURCE_AUTHORITY_ROUTER_V1'}else{'FAIL_SOURCE_AUTHORITY_ROUTER_V1'}
$proof=[ordered]@{
  schema='source_authority_router_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  script_path=$script
  accept_route=$a.route
  assumption_route=$s.route
  request_route=$r.route
  codex_launched=$false
  web_launched=$false
  accepted_memory_mutated=$false
  accepted_core_mutated=$false
  errors=@($errors)
}
$proofPath='tests/self_development/SOURCE_AUTHORITY_ROUTER_V1_PROOF.json'
WJson $proof $proofPath
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
if($errors.Count -gt 0){ $errors|ForEach-Object{Write-Host ('ERROR='+$_)}; exit 1 }
