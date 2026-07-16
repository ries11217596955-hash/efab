param(
  [Parameter(Mandatory=$true)][string]$ActionPacketPath,
  [string]$PassportPath='operations/autonomous_inner_motor/execution_authority_passport_v1.json',
  [string]$OutputPath='.runtime/execution_authority_passport_v1/evaluation.json',
  [switch]$RequestExecution
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 80|Set-Content -Path $p -Encoding UTF8 }
function FileProof($p){ if(Test-Path $p){ $i=Get-Item $p; return [ordered]@{path=$p; exists=$true; bytes=$i.Length; sha256=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()} } return [ordered]@{path=$p; exists=$false} }
if(-not(Test-Path $PassportPath)){ throw 'EXECUTION_AUTHORITY_PASSPORT_MISSING' }
if(-not(Test-Path $ActionPacketPath)){ throw 'ACTION_PACKET_MISSING' }
$passport=Get-Content $PassportPath -Raw|ConvertFrom-Json
$packet=Get-Content $ActionPacketPath -Raw|ConvertFrom-Json
$action=$packet.selected_action
if(-not $action){ throw 'ACTION_PACKET_SELECTED_ACTION_MISSING' }
$denyReasons=New-Object System.Collections.Generic.List[string]
$grantReasons=New-Object System.Collections.Generic.List[string]
$authority=[string]$action.required_authority
$actionType=[string]$action.action_type
$class=$passport.authority_classes.$authority
if(-not $class){ $denyReasons.Add('unknown_required_authority') | Out-Null }
if(@($passport.hard_denies) -contains $actionType){ $denyReasons.Add('hard_denied_action_type') | Out-Null }
if($class){
  if(-not (@($class.allowed_action_types) -contains $actionType)){ $denyReasons.Add('action_type_not_allowed_for_authority_class') | Out-Null }
  if($class.grantable_in_lab -ne $true){ $denyReasons.Add('authority_class_not_grantable_in_lab') | Out-Null }
  foreach($ref in @($class.required_validator_refs)){
    if($ref -eq 'OWNER_EXPLICIT_AUTHORITY'){ $denyReasons.Add('owner_explicit_authority_required') | Out-Null; continue }
    if(-not (@($action.validator_refs) -contains $ref)){ $denyReasons.Add("missing_required_validator_ref:$ref") | Out-Null }
  }
  if($class.rollback_required -eq $true -and [string]::IsNullOrWhiteSpace([string]$action.rollback_plan)){ $denyReasons.Add('rollback_plan_required') | Out-Null }
}
if($action.validator_required -eq $true -and @($action.validator_refs).Count -eq 0){ $denyReasons.Add('candidate_validator_refs_missing') | Out-Null }
if($action.proof_required -eq $true -and [string]::IsNullOrWhiteSpace([string]$packet.proof_expectation)){ $denyReasons.Add('packet_proof_expectation_missing') | Out-Null }
if($RequestExecution){ $denyReasons.Add('execution_request_not_supported_by_passport_v1') | Out-Null }
$decision='DENY'
$executionAllowed=$false
if($denyReasons.Count -eq 0){
  $decision='GRANT_CANDIDATE_ONLY'
  $grantReasons.Add('authority_class_grantable_for_candidate') | Out-Null
  $grantReasons.Add('validator_refs_present') | Out-Null
  $grantReasons.Add('rollback_plan_present') | Out-Null
}
$result=[ordered]@{
  schema='agent_execution_authority_evaluation_v1'
  status=if($decision -eq 'GRANT_CANDIDATE_ONLY'){'PASS_EXECUTION_AUTHORITY_EVALUATION_V1'}else{'BLOCKED_EXECUTION_AUTHORITY_EVALUATION_V1'}
  created_at=(Get-Date).ToString('o')
  passport_ref=$PassportPath
  action_packet_ref=$ActionPacketPath
  selected_action_id=$action.action_id
  action_type=$actionType
  required_authority=$authority
  decision=$decision
  execution_allowed=$executionAllowed
  request_execution=[bool]$RequestExecution
  deny_reasons=@($denyReasons)
  grant_reasons=@($grantReasons)
  passport_proof=FileProof $PassportPath
  packet_proof=FileProof $ActionPacketPath
  boundary=[ordered]@{
    evaluation_only=$true
    action_executed=$false
    live_process_touched=$false
    active_memory_mutated=$false
    repo_mutated=$false
    owner_authority_required_for_execution=$true
  }
}
WJson $result $OutputPath
Write-Host ('AUTHORITY_EVALUATION_STATUS='+$result.status)
Write-Host ('AUTHORITY_DECISION='+$decision)
Write-Host ('AUTHORITY_EXECUTION_ALLOWED='+$executionAllowed)
Write-Host ('AUTHORITY_EVALUATION_PATH='+$OutputPath)
if($decision -ne 'GRANT_CANDIDATE_ONLY'){ Write-Host ('AUTHORITY_DENY_REASONS=' + (@($denyReasons) -join ',')) }
