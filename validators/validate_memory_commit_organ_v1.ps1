param(
  [string]$ProofPath,
  [switch]$RequireDrain
)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Read-Json([string]$Path){ if(-not(Test-Path $Path)){ Add-Err "missing:$Path"; return $null }; try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { Add-Err "bad_json:$($Path):$($_.Exception.Message)"; return $null } }
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=30){ $dir=Split-Path $Path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=$Obj|ConvertTo-Json -Depth $Depth; $utf8NoBom=New-Object System.Text.UTF8Encoding($false); [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),(($json -split "`r?`n"|%{$_.TrimEnd()}) -join "`n")+"`n",$utf8NoBom) }
$policy=Read-Json 'operations/memory_commit/memory_commit_policy_v1.json'
$retention=Read-Json 'operations/memory_commit/runtime_retention_policy_v1.json'
$scriptText=if(Test-Path 'operations/memory_commit/memory_commit_controller_v1.ps1'){ Get-Content 'operations/memory_commit/memory_commit_controller_v1.ps1' -Raw } else { Add-Err 'missing_controller'; '' }
foreach($needle in @('DrainAgentLife','PostSchoolComplete','BatchDrainAgentLife','SelfTestRejectDelete','DeleteRejected','Validate-Packet','merge_compact_memory_intake_queue_v1.ps1','AuditSchoolQuality','PruneProcessedAgentLife','LOW_VARIETY_VALID_SCAFFOLD')){ if($scriptText -notlike "*$needle*"){ Add-Err "controller_missing:$needle" } }
if($policy){
  if($policy.commit_throat -ne 'single_active_compact_memory_publish_path'){ Add-Err 'policy_commit_throat_bad' }
  if($policy.rejected_packet_rule.delete_packet_immediately -ne $true){ Add-Err 'policy_rejected_delete_not_true' }
  if($policy.source_lanes.AgentLife.max_delay_batches -gt 3){ Add-Err 'policy_agentlife_max_delay_too_high' }
}
if($retention){ if(-not(@($retention.rules).Count -ge 4)){ Add-Err 'retention_rules_too_few' } }
$proof=$null
if(-not [string]::IsNullOrWhiteSpace($ProofPath)){ $proof=Read-Json $ProofPath }
if($RequireDrain){
  if(-not $proof){ Add-Err 'drain_proof_required' }
  else {
    if(@('PASS_MEMORY_COMMIT_DRAIN_AGENTLIFE_V1','PASS_MEMORY_COMMIT_BATCH_DRAIN_AGENTLIFE_V1') -notcontains $proof.status){ Add-Err "drain_status_bad:$($proof.status)" }
    if($proof.queue_after -ne 0){ Add-Err "queue_after_not_zero:$($proof.queue_after)" }
    if($proof.accepted_count -lt 1 -and $proof.rejected_count -lt 1){ Add-Err 'accepted_or_rejected_count_lt_1' }
    if($proof.active_memory_changed -ne $true){ Add-Err 'active_memory_not_changed' }
  }
}
$status=if($errors.Count -eq 0){'PASS_MEMORY_COMMIT_ORGAN_V1'}else{'FAIL_MEMORY_COMMIT_ORGAN_V1'}
$out=[ordered]@{ schema='memory_commit_organ_validation_v1'; status=$status; checked_at=(Get-Date).ToString('o'); proof_path=$ProofPath; require_drain=$RequireDrain.IsPresent; errors=@($errors) }
Write-CleanJson 'tests/self_development/MEMORY_COMMIT_ORGAN_V1_PROOF.json' $out 30
Write-Host "STATUS=$status"
Write-Host 'PROOF_OUT=tests/self_development/MEMORY_COMMIT_ORGAN_V1_PROOF.json'
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
