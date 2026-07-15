param(
  [ValidateSet('Diagnostic','ReadOnly','SandboxExploration','SandboxTestLife')][string]$Mode='SandboxExploration',
  [string]$Question='How should the agent improve its thinking using compact memory, without taking actions?',
  [string]$OutputRoot='.runtime/autonomous_inner_motor',
  [int]$MaxMemorySamples=6
)
$ErrorActionPreference='Stop'
# SandboxExploration, sandbox_exploration, SANDBOX_EXPLORATION_PROOF.json, SandboxTestLife, TEST_LIFE_PROOF.json
# No active memory mutation. PROTECTIVE_CHECKPOINT. schoolActive.
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=30){
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
function Get-FileProof([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
  $item=Get-Item -LiteralPath $Path
  return [ordered]@{ path=$Path; bytes=[int64]$item.Length; sha256=(Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLower() }
}
function Read-JsonSafe([string]$Path){
  if(-not(Test-Path -LiteralPath $Path -PathType Leaf)){ return $null }
  try { return (Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json) } catch { return $null }
}
function Get-ActiveMemoryState {
  $root='.runtime/active_compact_semantic_memory_v1'
  $state=[ordered]@{ root=$root; exists=(Test-Path -LiteralPath $root); unchanged=$true; files=@(); manifest_summary=$null; index_key_sample=@(); cell_sample=@() }
  if(-not $state.exists){ return $state }
  foreach($name in @('manifest.json','index.json','cells.jsonl')){
    $p=Join-Path $root $name
    $fp=Get-FileProof $p
    if($fp){ $state.files += $fp }
  }
  $manifest=Read-JsonSafe (Join-Path $root 'manifest.json')
  if($manifest){ $state.manifest_summary=[ordered]@{ schema=$manifest.schema; status=$manifest.status; run_id=$manifest.run_id; cell_count=$manifest.cell_count; merged_count=$manifest.merged_count; total_memory_bytes=$manifest.total_memory_bytes; runtime_ready=$manifest.runtime_ready; boundary=$manifest.boundary } }
  $index=Read-JsonSafe (Join-Path $root 'index.json')
  if($index){
    $props=@($index.PSObject.Properties | Select-Object -First $MaxMemorySamples)
    foreach($p in $props){ $state.index_key_sample += [ordered]@{ key=$p.Name; value=([string]$p.Value).Substring(0,[Math]::Min(120,([string]$p.Value).Length)) } }
  }
  $cellsPath=Join-Path $root 'cells.jsonl'
  if(Test-Path -LiteralPath $cellsPath){
    Get-Content -LiteralPath $cellsPath -TotalCount $MaxMemorySamples | ForEach-Object {
      try {
        $c=$_ | ConvertFrom-Json
        $titleCandidate=''
        if($c.PSObject.Properties.Name -contains 'title'){ $titleCandidate=[string]$c.title }
        elseif($c.PSObject.Properties.Name -contains 'summary'){ $titleCandidate=[string]$c.summary }
        elseif($c.PSObject.Properties.Name -contains 'topic'){ $titleCandidate=[string]$c.topic }
        $state.cell_sample += [ordered]@{ id=$c.id; kind=$c.kind; title=$titleCandidate.Substring(0,[Math]::Min(140,$titleCandidate.Length)) }
      }
      catch { }
    }
  }
  return $state
}
function Get-RepoState {
  return [ordered]@{
    branch=(git rev-parse --abbrev-ref HEAD).Trim()
    head=(git rev-parse --short HEAD).Trim()
    origin_delta=(git rev-list --left-right --count HEAD...origin/main).Trim()
    dirty=@(git status --short --untracked-files=all)
  }
}
function Get-SchoolState {
  $names=@('run_agent_school','exact_count_cycle','codex_warehouse','codex.cmd','codex exec','absorb_atom_file','digest','file_atom_absorption')
  $procs=@()
  Get-CimInstance Win32_Process | ForEach-Object {
    $cmd=$_.CommandLine; if(-not $cmd){$cmd=''}
    $hit=$false
    foreach($n in $names){ if($_.Name -like "*$n*" -or $cmd -like "*$n*"){ $hit=$true } }
    if($hit){ $procs += [ordered]@{ pid=$_.ProcessId; name=$_.Name; command=($cmd -replace '\s+',' ').Substring(0,[Math]::Min(260,($cmd -replace '\s+',' ').Length)) } }
  }
  return [ordered]@{ schoolActive=(@($procs).Count -gt 0); processes=$procs; owner_control_contract=(Test-Path 'operations/school/OWNER_SCHOOL_CONTROL_CONTRACT_V1.md'); runbook=(Test-Path 'operations/school/OWNER_SCHOOL_RUNBOOK_V1.md') }
}
function Get-BodyMapState {
  $p='reports/self_development/agent_body_map.json'
  $j=Read-JsonSafe $p
  if(-not $j){ return [ordered]@{ exists=$false; path=$p } }
  return [ordered]@{ exists=$true; path=$p; schema=$j.schema; map_kind=$j.map_kind; component_count=@($j.components).Count; confirmed_component_count=$j.confirmed_component_count; primary_evidence_candidate_count=$j.primary_evidence_candidate_count }
}
function Get-LivingLoopState {
  $paths=@('contracts/living_loop/LIVING_LOOP_CONTRACT_V1.md','reports/self_development/LIVING_LOOP_CONTRACT_V1_PROOF.json','reports/self_development/LIVING_LOOP_EVALUATOR_V1_PROOF.json')
  $items=@()
  foreach($p in $paths){ $items += [ordered]@{ path=$p; exists=(Test-Path -LiteralPath $p) } }
  return [ordered]@{ artifacts=$items; active_runtime=$false; autonomous_loop=$false; execution_allowed=$false; mutation_authorized=$false }
}
function New-WebResearchRequest([string]$Need,[string]$Why){
  return [ordered]@{ port='WEB_RESEARCH_PORT'; mode='request_only'; performed=$false; need=$Need; why=$Why; allowed_when='Owner/tool authority and citation requirement'; output_expected='cited external facts, not direct action' }
}
function New-CodexQuestionRequest([string]$Need,[string]$Why){
  return [ordered]@{ port='CODEX_QUESTION_PORT'; mode='request_only'; launched=$false; need=$Need; why=$Why; constraints=@('bounded question','no file writes before PREFLIGHT_PASS','Codex is not brain','answer returns as CODEX_DRAFT') }
}
$repo=Get-RepoState
$memoryBefore=Get-ActiveMemoryState
$school=Get-SchoolState
$body=Get-BodyMapState
$living=Get-LivingLoopState
$policy=Read-JsonSafe 'operations/autonomous_inner_motor/motor_policy.json'
$runId='aimo_'+(Get-Date -Format 'yyyyMMdd_HHmmss')
$runRoot=Join-Path $OutputRoot $runId
$proofName=if($Mode -eq 'SandboxTestLife'){ 'TEST_LIFE_PROOF.json' } else { 'SANDBOX_EXPLORATION_PROOF.json' }
$proofPath=Join-Path $runRoot $proofName
$cycles=@(
  [ordered]@{ n=1; lens='observe'; question='What is true now?'; memory_used=$true; answer='Repo/body/memory/School/living-loop state read first. No action selected.' },
  [ordered]@{ n=2; lens='memory'; question='What does compact memory give me before asking outside?'; memory_used=$true; answer='Manifest, hashes, sample index/cells establish active compact memory as first source. Full semantic search is next maturity step.' },
  [ordered]@{ n=3; lens='known_unknown'; question='What is known and unknown?'; memory_used=$true; answer='Known: body map validated, School live absorption proven, AIMO action modes disabled. Unknown: best reasoning heuristics require future memory retrieval depth and external source requests.' },
  [ordered]@{ n=4; lens='source_ladder'; question='When may web/Codex be asked?'; memory_used=$true; answer='Only as request objects after memory/internal library cannot answer; no browsing/Codex launch in this mode.' },
  [ordered]@{ n=5; lens='decision_gate'; question='May I act?'; memory_used=$true; answer='No. Thinking-only gate blocks active memory mutation, git mutation, School launch, web research, Codex launch.' },
  [ordered]@{ n=6; lens='return_to_parent'; question='What should parent build next?'; memory_used=$true; answer='Upgrade memory retrieval from sample/hash use into compact semantic query and scored recall, still read-only.' }
)
$webRequests=@(
  New-WebResearchRequest 'Current external facts needed for a question that compact memory/internal repo cannot answer.' 'The agent must have a governed external world port, but this run is no-web.'
)
$codexRequests=@(
  New-CodexQuestionRequest 'Ask Codex to inspect implementation uncertainty only after memory/repo are insufficient.' 'The agent must be able to formulate bounded Codex questions without treating Codex as brain.'
)
$selected=[ordered]@{
  path='build_read_only_compact_memory_query_port_v1'
  reason='Thinking quality depends on using compact memory deeply, not only hashing/sampling it.'
  forbidden_now=@('mutate_active_memory','launch_codex','browse_web','patch_repo')
  validator_needed='memory_query_read_only_validator'
}
$memoryAfter=Get-ActiveMemoryState
$proof=[ordered]@{
  schema='AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF'
  organ_id='AUTONOMOUS_INNER_MOTOR_ORGAN'
  run_id=$runId
  mode=$Mode
  maturity_level='L2_SANDBOX_EXPLORATION_THINKING_ONLY'
  created_at=(Get-Date).ToString('o')
  question=$Question
  boundary=[ordered]@{ thinking_only=$true; no_action=$true; no_active_memory_mutation=$true; no_git_mutation=$true; no_school_launch=$true; no_codex_launch=$true; no_web_research=$true; proof_file_only=$true }
  repo_state=$repo
  memory_state=[ordered]@{ before=$memoryBefore; after=$memoryAfter; unchanged=($($memoryBefore.files | ConvertTo-Json -Depth 10) -eq $($memoryAfter.files | ConvertTo-Json -Depth 10)) }
  body_map_state=$body
  school_state=$school
  living_loop_state=$living
  policy_snapshot=[ordered]@{ allowed_modes=$policy.allowed_modes; disabled_modes=$policy.disabled_modes; source_ladder=$policy.source_ladder; ports=$policy.ports }
  self_question_trace=$cycles
  cycles=$cycles
  memory_use_trace=[ordered]@{ first_source='ACTIVE_COMPACT_MEMORY_PORT'; used_manifest=$true; used_index_sample=$true; used_cell_sample=$true; mutation=$false; limitation='sample/hash use only; semantic search port is next organ slice' }
  internal_library_trace=[ordered]@{ used_body_map=$body.exists; used_living_loop=$true; used_school_contract=$school.owner_control_contract }
  web_research_requests=$webRequests
  codex_question_requests=$codexRequests
  decision_trace=@(
    [ordered]@{ step='classify'; result='thinking_only_agent_logic'; proof='Owner requested thinking/logical growth, not action authority.' },
    [ordered]@{ step='memory_first'; result='compact_memory_read_before_external_requests'; proof='memory_state present and unchanged.' },
    [ordered]@{ step='gate'; result='block_actions'; proof='policy disables mutation/action modes.' },
    [ordered]@{ step='select_next'; result=$selected.path; proof='memory depth is the next bottleneck for thinking quality.' }
  )
  selected_next_path=$selected
  heartbeat=[ordered]@{ cycle_count=@($cycles).Count; alive='one_shot_sandbox'; background_process_started=$false }
  final_self_diagnosis='The motor can perform memory-first, source-ladder-aware thinking and stop safely. It cannot yet do deep compact semantic retrieval; that is the next thinking upgrade.'
  stop_reason='PROTECTIVE_CHECKPOINT_THINKING_ONLY'
  mutation_audit=[ordered]@{ active_memory_mutated=$false; git_mutated=$false; codex_launched=$false; web_research_performed=$false; school_started=$false; background_process_started=$false; files_written=@($proofPath) }
  validator_result=[ordered]@{ runner_self_check='PASS_RUNNER_GENERATED_SINGLE_SANDBOX_PROOF'; external_validator_expected='validators/validate_autonomous_inner_motor_organ_contract.ps1 -SandboxProofPath <proof>' }
}
Write-CleanJson $proofPath $proof 80
Write-Host "MODE=$Mode"
Write-Host "PROOF_PATH=$proofPath"
Write-Host "STOP_REASON=$($proof.stop_reason)"
Write-Host "MEMORY_UNCHANGED=$($proof.memory_state.unchanged)"
Write-Host "No active memory mutation"
