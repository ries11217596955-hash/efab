param(
  [string]$ProofPath
)
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Read-Json([string]$Path){ if(-not(Test-Path $Path)){ Add-Err "missing:$Path"; return $null }; try { return (Get-Content $Path -Raw | ConvertFrom-Json) } catch { Add-Err "bad_json:$($Path):$($_.Exception.Message)"; return $null } }
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=20){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,(($lines -join "`n") + "`n"),$utf8NoBom)
}
if([string]::IsNullOrWhiteSpace($ProofPath)){
  $latest=Get-ChildItem '.runtime/autonomous_inner_motor' -Filter 'SANDBOX_EXPLORATION_PROOF.json' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){ $ProofPath=$latest.FullName.Substring((Resolve-Path '.').Path.Length+1).Replace('\','/') }
}
$proof=Read-Json $ProofPath
$runnerText=if(Test-Path 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'){ Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw } else { Add-Err 'missing_runner'; '' }
foreach($needle in @('MemoryIngestionMode','Invoke-AgentLifeMemoryQueueIntake','New-AgentLifeCompactMemoryPacket','Test-MemoryPublishBusy','QueueOnly','QueueAndMerge')){ if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" } }
$policy=Read-Json 'operations/autonomous_inner_motor/dual_pipe_memory_policy.json'
if($policy){
  if($policy.default_mode -ne 'Auto'){ Add-Err 'dual_policy_default_not_auto' }
  if($policy.pipes.AgentLife -notlike '*compact_memory_intake*'){ Add-Err 'dual_policy_agentlife_not_queue' }
}
if($proof){
  if($proof.boundary.direct_active_memory_write -ne $false){ Add-Err 'proof_direct_active_memory_write_not_false' }
  if($proof.boundary.agentlife_queue_first -ne $true){ Add-Err 'proof_agentlife_queue_first_not_true' }
  if($proof.deep_thinking.absorption.mode -ne 'QueueAndMerge'){ Add-Err "proof_ingestion_mode_not_queue_and_merge:$($proof.deep_thinking.absorption.mode)" }
  if($proof.deep_thinking.absorption.queue_packet.packet.source_kind -ne 'AgentLife'){ Add-Err 'packet_source_kind_not_agentlife' }
  if($proof.deep_thinking.absorption.packet_validation_status -ne 'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1'){ Add-Err 'packet_validation_not_pass' }
  if($proof.deep_thinking.absorption.merge.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ Add-Err "merge_status_not_pass:$($proof.deep_thinking.absorption.merge.status)" }
  if($proof.deep_thinking.absorption.memory_changed -ne $true){ Add-Err 'memory_changed_not_true_after_queue_merge' }
  if($proof.deep_thinking.acceptance_gate.decision.absorption_allowed -ne $true){ Add-Err 'acceptance_gate_not_allowed' }
}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_DUAL_PIPE_MEMORY_INGESTION_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_DUAL_PIPE_MEMORY_INGESTION_V1'}
$out=[ordered]@{ schema='autonomous_inner_motor_dual_pipe_memory_ingestion_validation_v1'; status=$status; checked_at=(Get-Date).ToString('o'); proof_path=$ProofPath; boundary=[ordered]@{ validates_agentlife_queue_first=$true; validates_locked_merge=$true; validates_no_direct_active_memory_write=$true; validates_one_memory_source_for_agent=$true }; errors=@($errors) }
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_DUAL_PIPE_MEMORY_INGESTION_V1_PROOF.json'
Write-CleanJson $proofOut $out 30
Write-Host "STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
