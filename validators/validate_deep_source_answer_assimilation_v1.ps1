$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err($m){$errors.Add($m)}
function WJson($obj,$path){$dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir | Out-Null}; $obj | ConvertTo-Json -Depth 100 | Set-Content $path -Encoding UTF8}
function Assert($cond,$msg){ if(-not $cond){ Add-Err $msg } }
$script='operations/reasoning/assimilate_deep_source_answer_v1.ps1'
Assert (Test-Path $script) 'assimilation_script_missing'
$runtimeDir='.runtime/deep_source_answer_assimilation_v1'
New-Item -ItemType Directory -Force -Path $runtimeDir | Out-Null
$readyFixture=Join-Path $runtimeDir 'validator_ready_answer_fixture.json'
$blockedFixture=Join-Path $runtimeDir 'validator_blocked_answer_fixture.json'
$ready=[ordered]@{
  schema='deep_source_answer_request_result_v1'
  status='PASS_DEEP_SOURCE_ANSWER_REQUEST_WITH_MEMORY_CANDIDATE_V1'
  answer_ready=$true
  answer_candidate=[ordered]@{
    direct_answer='A ready answer can be assimilated only as a bounded candidate.'
    evidence_items=@([ordered]@{source='validator_fixture'; claim='ready answer exists'})
    confidence='MEMORY_SUPPORTED_CANDIDATE'
    unknown=@('whether candidate is sufficient for accepted memory')
    assumptions=@('fixture represents request result')
    contradictions_or_risks=@('candidate can be stale')
    next_verification_step='run validator and require reuse proof before acceptance'
    reusable_rule='Assimilate ready answers into mind_delta candidates before memory acceptance.'
  }
}
$blocked=[ordered]@{schema='deep_source_answer_request_packet_v1'; status='PASS_DEEP_SOURCE_ANSWER_REQUEST_PACKET_V1'; answer_ready=$false; request_packet=[ordered]@{answer_contract=[ordered]@{required_format='json_object'}}}
WJson $ready $readyFixture
WJson $blocked $blockedFixture
$readyOut=Join-Path $runtimeDir 'validator_ready_assimilation.json'
$blockedOut=Join-Path $runtimeDir 'validator_blocked_assimilation.json'
$out1=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -DeepSourceAnswerPath $readyFixture -OutputPath $readyOut *>&1 | ForEach-Object { [string]$_ })
$r=Get-Content $readyOut -Raw | ConvertFrom-Json
Assert ($r.status -eq 'PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_CANDIDATE_V1') ('ready_status_bad:'+ $r.status)
Assert ($r.answer_ready -eq $true) 'ready_answer_not_true'
Assert ($r.evidence_count -ge 1) 'ready_evidence_missing'
Assert ($r.mind_delta_candidate.status -eq 'CANDIDATE_NOT_ACCEPTED') 'mind_delta_not_candidate'
Assert ($r.acceptance_boundary.accepted_memory_update -eq $false) 'accepted_memory_should_not_update'
Assert ($r.boundary.active_memory_mutated -eq $false -and $r.boundary.live_process_touched -eq $false -and $r.boundary.external_tool_launched -eq $false) 'boundary_broken_ready'
$out2=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $script -DeepSourceAnswerPath $blockedFixture -OutputPath $blockedOut *>&1 | ForEach-Object { [string]$_ })
$b=Get-Content $blockedOut -Raw | ConvertFrom-Json
Assert ($b.status -eq 'BLOCKED_NO_READY_DEEP_SOURCE_ANSWER_V1') ('blocked_status_bad:'+ $b.status)
Assert ($b.answer_ready -eq $false) 'blocked_answer_ready_true'
Assert ($b.boundary.active_memory_mutated -eq $false -and $b.boundary.external_tool_launched -eq $false) 'boundary_broken_blocked'
$status=if($errors.Count -eq 0){'PASS_DEEP_SOURCE_ANSWER_ASSIMILATION_V1'}else{'FAIL_DEEP_SOURCE_ANSWER_ASSIMILATION_V1'}
$proof=[ordered]@{
  schema='deep_source_answer_assimilation_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  script_path=$script
  ready_fixture=$readyFixture
  blocked_fixture=$blockedFixture
  ready_result=$readyOut
  blocked_result=$blockedOut
  ready_status=$r.status
  blocked_status=$b.status
  mind_delta_candidate_status=$r.mind_delta_candidate.status
  active_memory_mutated=$false
  live_process_touched=$false
  external_tool_launched=$false
  errors=@($errors)
}
$proofPath='tests/self_development/DEEP_SOURCE_ANSWER_ASSIMILATION_V1_PROOF.json'
WJson $proof $proofPath
Write-Host ('VALIDATION_STATUS='+$status)
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('READY_STATUS='+$r.status)
Write-Host ('BLOCKED_STATUS='+$b.status)
if($errors.Count -gt 0){ $errors|ForEach-Object{ Write-Host ('ERROR='+$_) }; exit 1 }
