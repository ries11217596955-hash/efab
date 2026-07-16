$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err($m){$errors.Add($m)}
function WJson($obj,$path){$dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir | Out-Null}; $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8}
function Assert($cond,$msg){ if(-not $cond){ Add-Err $msg } }
$script='operations/reasoning/build_route_request_packet_v1.ps1'
Assert (Test-Path $script) 'route_request_packet_script_missing'
$runtimeDir='.runtime/route_request_packet_v1'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
function Make-Route($path,$route,$acceptanceDecision){
  WJson ([ordered]@{
    schema='source_authority_router_v1'
    status='PASS_SOURCE_AUTHORITY_ROUTE_DECISION_V1'
    acceptance_decision=$acceptanceDecision
    route=$route
    reason='fixture'
    allowed_now=@('fixture_allowed')
    blocked_now=@('codex','web_external','accepted_memory_write','accepted_core_write','action_execution')
    boundary=[ordered]@{active_memory_mutated=$false; accepted_core_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; external_tool_launched=$false; action_executed=$false}
  }) $path
}
$cases=@(
  @{name='accept'; route='LOCAL_ACCEPTANCE_PIPELINE_REQUIRED'; decision='ACCEPT_AS_KNOWN_CANDIDATE'; expected='accepted_pipeline_request_packet'},
  @{name='assumption'; route='LOCAL_MEMORY_THEN_REPO_PROOF'; decision='KEEP_AS_ASSUMPTION'; expected='local_memory_then_repo_proof_packet'},
  @{name='repo'; route='REPO_PROOF_LOOKUP'; decision='KEEP_AS_ASSUMPTION'; expected='repo_proof_lookup_packet'},
  @{name='owner_repo'; route='OWNER_OR_REPO_PROOF_FIRST'; decision='KEEP_AS_ASSUMPTION'; expected='repo_or_owner_proof_request_packet'},
  @{name='start_local'; route='SOURCE_LADDER_START_LOCAL'; decision='REQUEST_MORE_PROOF'; expected='source_ladder_local_start_packet'},
  @{name='expand_local'; route='SOURCE_LADDER_EXPAND_LOCAL_FIRST'; decision='REQUEST_MORE_PROOF'; expected='source_ladder_expand_local_first_packet'}
)
$results=@()
foreach($c in $cases){
  $fixture=Join-Path $runtimeDir ($c.name+'_route_fixture.json')
  $out=Join-Path $runtimeDir ($c.name+'_packet.json')
  Make-Route $fixture $c.route $c.decision
  & powershell -NoProfile -ExecutionPolicy Bypass -File $script -SourceAuthorityRoutePath $fixture -OutputPath $out | Out-Host
  if($LASTEXITCODE -ne 0){ Add-Err ($c.name+'_packet_nonzero') }
  $r=Get-Content $out -Raw | ConvertFrom-Json
  $results += $r
  Assert ($r.status -eq 'PASS_ROUTE_REQUEST_PACKET_V1') ($c.name+'_status_bad:'+ $r.status)
  Assert ($r.request_type -eq $c.expected) ($c.name+'_request_type_bad:'+ $r.request_type)
  Assert ($r.boundary.active_memory_mutated -eq $false) ($c.name+'_active_memory_mutated')
  Assert ($r.boundary.accepted_core_mutated -eq $false) ($c.name+'_accepted_core_mutated')
  Assert ($r.boundary.codex_launched -eq $false) ($c.name+'_codex_launched')
  Assert ($r.boundary.web_launched -eq $false) ($c.name+'_web_launched')
  Assert ($r.boundary.action_executed -eq $false) ($c.name+'_action_executed')
  Assert ($r.codex_request_packet.allowed_now -eq $false) ($c.name+'_codex_allowed_now')
  Assert ($r.web_scout_request_packet.allowed_now -eq $false) ($c.name+'_web_allowed_now')
  Assert ($r.blocked_future -contains 'codex_request_packet') ($c.name+'_codex_future_not_blocked')
  Assert ($r.blocked_future -contains 'web_scout_request_packet') ($c.name+'_web_future_not_blocked')
}
$status=if($errors.Count -eq 0){'PASS_ROUTE_REQUEST_PACKET_V1'}else{'FAIL_ROUTE_REQUEST_PACKET_V1'}
$proof=[ordered]@{
  schema='route_request_packet_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  script_path=$script
  request_types=@($results | ForEach-Object { $_.request_type })
  codex_launched=$false
  web_launched=$false
  active_memory_mutated=$false
  accepted_core_mutated=$false
  action_executed=$false
  errors=@($errors)
}
$proofPath='tests/self_development/ROUTE_REQUEST_PACKET_V1_PROOF.json'
WJson $proof $proofPath
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
if($errors.Count -gt 0){ $errors|ForEach-Object{Write-Host ('ERROR='+$_)}; exit 1 }
