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
  $clean=($lines -join "`n") + "`n"
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $full=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($full,$clean,$utf8NoBom)
}
if([string]::IsNullOrWhiteSpace($ProofPath)){
  $latest=Get-ChildItem '.runtime/autonomous_inner_motor' -Filter 'SANDBOX_EXPLORATION_PROOF.json' -Recurse -File | Sort-Object LastWriteTime -Descending | Select-Object -First 1
  if($latest){ $ProofPath=$latest.FullName.Substring((Resolve-Path '.').Path.Length+1).Replace('\','/') }
}
$proof=Read-Json $ProofPath
$runnerText=if(Test-Path 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'){ Get-Content 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1' -Raw } else { Add-Err 'missing_runner'; '' }
$policy=Read-Json 'operations/autonomous_inner_motor/deep_thinking_policy.json'
$schema=Read-Json 'operations/autonomous_inner_motor/thought_frame_schema.json'
foreach($needle in @('Build-DeepThinkingTree','New-ThoughtFrame','New-DeepThinkingLearningAtom','Invoke-LearningAtomAbsorption','Invoke-MemoryAtomAcceptanceGate','Invoke-AcceptedLearningAtomAbsorption','Invoke-AgentLifeMemoryQueueIntake','EnableMemoryLearning','EnableDeepThinking')){
  if($runnerText -notlike "*$needle*"){ Add-Err "runner_missing:$needle" }
}
if($null -ne $policy){
  if($policy.memory_learning.requires_governed_absorption -ne $true){ Add-Err 'policy_does_not_require_governed_absorption' }
  if($policy.memory_learning.direct_active_memory_write -ne $false){ Add-Err 'policy_allows_direct_active_memory_write' }
  if([int]$policy.memory_learning.max_atoms_per_cycle -ne 1){ Add-Err 'policy_max_atoms_not_one' }
}
if($null -ne $schema){
  foreach($field in @('return_to_parent','evidence','answer_status','priority_score')){ if(-not(@($schema.required_fields) -contains $field)){ Add-Err "thought_frame_schema_missing:$field" } }
}
if($null -ne $proof){
  if($proof.deep_thinking.status -ne 'PASS_DEEP_THINKING_WITH_MEMORY_LEARNING'){ Add-Err "deep_status_bad:$($proof.deep_thinking.status)" }
  if(@($proof.deep_thinking.frames).Count -lt 4){ Add-Err 'too_few_thought_frames' }
  $badReturn=@($proof.deep_thinking.frames | Where-Object { $_.id -ne 'root' -and [string]::IsNullOrWhiteSpace($_.return_to_parent) })
  if($badReturn.Count -gt 0){ Add-Err 'missing_return_to_parent_in_frames' }
  if(@($proof.deep_thinking.memory_recalls).Count -lt 3){ Add-Err 'memory_recall_less_than_three' }
  if($proof.deep_thinking.learning_atom.concept_key -ne 'aimo.deep_thinking.recursive_thought_frame.memory_learning'){ Add-Err 'learning_atom_concept_key_bad' }
  if(-not $proof.deep_thinking.acceptance_gate){ Add-Err 'acceptance_gate_missing' }
  else {
    if($proof.deep_thinking.acceptance_gate.decision.absorption_allowed -ne $true){ Add-Err 'acceptance_gate_absorption_not_allowed' }
    if([string]::IsNullOrWhiteSpace($proof.deep_thinking.acceptance_gate.decision.explanation)){ Add-Err 'acceptance_gate_explanation_missing' }
    if($proof.deep_thinking.absorption.mode -eq 'QueueAndMerge'){
      if($proof.deep_thinking.absorption.queue_packet.packet.source_kind -ne 'AgentLife'){ Add-Err 'queue_packet_not_agentlife' }
      if($proof.deep_thinking.absorption.queue_packet.packet.atoms[0].source_ref -ne $proof.deep_thinking.acceptance_gate.final_atom_path){ Add-Err 'queue_packet_source_ref_not_gate_final_atom' }
      if($proof.deep_thinking.absorption.merge.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ Add-Err 'queue_merge_not_pass' }
    } elseif($proof.deep_thinking.absorption.atom_path -ne $proof.deep_thinking.acceptance_gate.final_atom_path){
      Add-Err 'absorption_not_using_gate_final_atom'
    }
  }
  if($proof.boundary.governed_memory_learning -ne $true){ Add-Err 'boundary_governed_memory_learning_not_true' }
  if($proof.boundary.direct_active_memory_write -ne $false){ Add-Err 'direct_active_memory_write_not_false' }
  if($proof.deep_thinking.absorption.memory_changed -ne $true){ Add-Err 'absorption_memory_changed_not_true' }
  if([int]$proof.deep_thinking.absorption.exit_code -ne 0){ Add-Err 'absorption_exit_not_zero' }
  if($proof.deep_thinking.absorption.mode -eq 'QueueAndMerge'){
    if($proof.deep_thinking.absorption.merge.status -ne 'PASS_MULTI_SOURCE_COMPACT_MEMORY_MERGE_QUEUE_V1'){ Add-Err 'queue_merge_not_pass_for_candidate_cleanup_boundary' }
  } elseif(($proof.deep_thinking.absorption.candidate_memory_root_removed -ne 'True') -and ($proof.deep_thinking.absorption.candidate_memory_root_removed -ne $true)){
    Add-Err 'candidate_memory_root_not_removed'
  }
  if($proof.stop_reason -ne 'PROTECTIVE_CHECKPOINT_THINKING_ONLY'){ Add-Err 'stop_reason_bad' }
  if($proof.mutation_audit.direct_active_memory_write -ne $false){ Add-Err 'mutation_audit_direct_write_not_false' }
  if($proof.mutation_audit.governed_absorption_used -ne $true){ Add-Err 'governed_absorption_not_used' }
}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_INNER_MOTOR_DEEP_THINKING_MEMORY_LEARNING_V1'}else{'FAIL_AUTONOMOUS_INNER_MOTOR_DEEP_THINKING_MEMORY_LEARNING_V1'}
$out=[ordered]@{
  schema='autonomous_inner_motor_deep_thinking_memory_learning_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  proof_path=$ProofPath
  boundary=[ordered]@{ validates_recursive_thinking=$true; validates_governed_memory_atom_absorption=$true; validates_direct_active_memory_write_false=$true; validates_one_atom_growth=$true }
  errors=@($errors)
}
$proofOut='tests/self_development/AUTONOMOUS_INNER_MOTOR_DEEP_THINKING_MEMORY_LEARNING_V1_PROOF.json'
Write-CleanJson $proofOut $out 30
Write-Host "STATUS=$status"
Write-Host "PROOF_OUT=$proofOut"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
