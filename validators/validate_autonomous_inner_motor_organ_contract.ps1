param(
  [string]$SandboxProofPath = ''
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $RepoRoot
$OrganRoot = 'operations/autonomous_inner_motor'
$Errors = New-Object System.Collections.Generic.List[string]

function Read-Json($Path) {
  try { return (Get-Content $Path -Raw | ConvertFrom-Json) }
  catch { $Errors.Add("json_parse_failed:${Path}:$($_.Exception.Message)"); return $null }
}

$RequiredFiles = @('AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC.md','motor_policy.json','organ_contract.json','motor_state_schema.json','motor_proof_schema.json','run_autonomous_inner_motor.ps1')
foreach ($file in $RequiredFiles) {
  $path = Join-Path $OrganRoot $file
  if (-not (Test-Path $path)) { $Errors.Add("missing_required_file:$path") }
}
$Policy = Read-Json (Join-Path $OrganRoot 'motor_policy.json')
$Contract = Read-Json (Join-Path $OrganRoot 'organ_contract.json')
$StateSchema = Read-Json (Join-Path $OrganRoot 'motor_state_schema.json')
$ProofSchema = Read-Json (Join-Path $OrganRoot 'motor_proof_schema.json')

if ($Policy) {
  if ($Policy.organ_id -ne 'AUTONOMOUS_INNER_MOTOR_ORGAN') { $Errors.Add('policy_wrong_organ_id') }
  if ($Policy.runner_contract -ne 'single_runner_only_no_runner_per_level') { $Errors.Add('policy_missing_single_runner_rule') }
  if ($Policy.mutation_allowed -ne $false) { $Errors.Add('initial_policy_must_disable_mutation') }
  if ($Policy.active_memory_mutation_allowed -ne $false) { $Errors.Add('initial_policy_must_disable_active_memory_mutation') }
  if ($Policy.git_mutation_allowed -ne $false) { $Errors.Add('initial_policy_must_disable_git_mutation') }
  if ($Policy.school_priority.enabled -ne $true) { $Errors.Add('school_priority_not_enabled') }
  foreach ($mode in @('Diagnostic','ReadOnly','SandboxExploration','SandboxTestLife')) { if ($Policy.allowed_modes -notcontains $mode) { $Errors.Add("allowed_mode_missing:$mode") } }
  foreach ($mode in @('SandboxAction','GovernedRepoAction','Continuous','LiveAuthority')) { if ($Policy.disabled_modes -notcontains $mode) { $Errors.Add("disabled_mode_missing:$mode") } }
  foreach ($port in @('school_port','active_memory_port','internal_library_port','web_research_port','validator_port','rollback_port')) { if (-not $Policy.ports.PSObject.Properties.Name.Contains($port)) { $Errors.Add("missing_port:$port") } }
  if (-not $Policy.PSObject.Properties.Name.Contains('sandbox_exploration')) { $Errors.Add('sandbox_exploration_policy_missing') }
  else {
    if ($Policy.sandbox_exploration.no_extra_files -ne $true) { $Errors.Add('sandbox_one_file_rule_not_enabled') }
    if ([int]$Policy.sandbox_exploration.max_proof_bytes -gt 250000) { $Errors.Add('sandbox_proof_budget_too_large') }
  }
}
if ($Contract) {
  if ($Contract.role -notmatch 'not_whole_brain') { $Errors.Add('contract_must_state_motor_not_whole_brain') }
  if ($Contract.single_runner_rule -notmatch 'one_runner_only') { $Errors.Add('contract_missing_one_runner_rule') }
  if ($Contract.no_sprawl_law -notmatch 'No new runner') { $Errors.Add('contract_missing_no_sprawl_law') }
}
if ($StateSchema) { foreach ($field in @('organ_id','run_id','mode','maturity_level','repo_state','memory_state','school_state','policy_decision','selected_next_path','stop_reason','created_at')) { if ($StateSchema.required_fields -notcontains $field) { $Errors.Add("state_required_field_missing:$field") } } }
if ($ProofSchema) { foreach ($section in @('boundary','repo_state','memory_state','school_state','policy_snapshot','self_question_trace','decision_trace','heartbeat','stop_reason','mutation_audit','validator_result')) { if ($ProofSchema.required_sections -notcontains $section) { $Errors.Add("proof_required_section_missing:$section") } } }
$SpecText = Get-Content (Join-Path $OrganRoot 'AUTONOMOUS_INNER_MOTOR_ORGAN_SPEC.md') -Raw
foreach ($needle in @('No new autonomous runner','School teaches','INTERNAL_LIBRARY_PORT','WEB_RESEARCH_PORT','Maturity levels inside one organ')) { if ($SpecText -notmatch [regex]::Escape($needle)) { $Errors.Add("spec_missing:$needle") } }
$RunnerPath = Join-Path $OrganRoot 'run_autonomous_inner_motor.ps1'
if (Test-Path $RunnerPath) {
  $RunnerText = Get-Content $RunnerPath -Raw
  foreach ($needle in @('SandboxExploration','sandbox_exploration','SANDBOX_EXPLORATION_PROOF.json','SandboxTestLife','TEST_LIFE_PROOF.json','Get-ActiveMemoryState','schoolActive','PROTECTIVE_CHECKPOINT','No active memory mutation','next_action_candidate','ACTION_DECISION_STATUS','mind_logic_frame','MIND_LOGIC_STATUS')) { if ($RunnerText -notmatch [regex]::Escape($needle)) { $Errors.Add("runner_missing:$needle") } }
}
$RunnerFiles = @(Get-ChildItem -Path $OrganRoot -Filter 'run_*motor*.ps1' -File | ForEach-Object { $_.FullName })
if ($RunnerFiles.Count -ne 1) { $Errors.Add("runner_sprawl_detected_count:$($RunnerFiles.Count)") }

if ($SandboxProofPath -ne '') {
  if (-not (Test-Path $SandboxProofPath)) { $Errors.Add("sandbox_proof_missing:$SandboxProofPath") }
  else {
    $Proof = Read-Json $SandboxProofPath
    $ProofFile = Get-Item $SandboxProofPath
    $RunRoot = Split-Path $ProofFile.FullName -Parent
    $files = @(Get-ChildItem -Path $RunRoot -File)
    $allowedSandboxFiles=@('SANDBOX_EXPLORATION_PROOF.json','action_decision_packet.json','mind_logic_frame.json')
    $extraFiles=@($files | Where-Object { $allowedSandboxFiles -notcontains $_.Name })
    if ($extraFiles.Count -gt 0) { $Errors.Add("sandbox_extra_files_detected:$($extraFiles.Count)") }
    if (-not ($files | Where-Object { $_.Name -eq 'SANDBOX_EXPLORATION_PROOF.json' })) { $Errors.Add('sandbox_proof_file_missing_in_runroot') }
    if ($ProofFile.Length -gt [int]$Policy.sandbox_exploration.max_proof_bytes) { $Errors.Add("sandbox_proof_too_large:$($ProofFile.Length)") }
    if ($Proof) {
      if ($Proof.schema -ne 'AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF') { $Errors.Add('sandbox_wrong_schema') }
      if ($Proof.mode -ne 'SandboxExploration') { $Errors.Add('sandbox_wrong_mode') }
      if ($Proof.memory_state.unchanged -ne $true) { $Errors.Add('sandbox_memory_not_unchanged') }
      if ($Proof.mutation_audit.active_memory_mutated -ne $false) { $Errors.Add('sandbox_active_memory_mutation_claimed') }
      if ($Proof.mutation_audit.codex_launched -ne $false) { $Errors.Add('sandbox_codex_launched') }
      if ($Proof.mutation_audit.web_research_performed -ne $false) { $Errors.Add('sandbox_web_used') }
      if ($Proof.mutation_audit.school_started -ne $false) { $Errors.Add('sandbox_school_started') }
      if ($Proof.mutation_audit.background_process_started -ne $false) { $Errors.Add('sandbox_background_process_started') }
      if (@($Proof.cycles).Count -gt [int]$Policy.sandbox_exploration.max_cycles) { $Errors.Add('sandbox_cycle_limit_exceeded') }
      if (@($Proof.cycles).Count -lt 5) { $Errors.Add('sandbox_too_few_cycles_for_exploration') }
      if (-not $Proof.final_self_diagnosis) { $Errors.Add('sandbox_missing_final_self_diagnosis') }
      if ($Proof.stop_reason -notmatch 'PROTECTIVE_CHECKPOINT') { $Errors.Add('sandbox_stop_reason_not_protective') }
    }
  }
}

$Status = if ($Errors.Count -eq 0) { 'PASS_AUTONOMOUS_INNER_MOTOR_ORGAN_CONTRACT' } else { 'FAIL_AUTONOMOUS_INNER_MOTOR_ORGAN_CONTRACT' }
if ($SandboxProofPath -ne '') { $Status = if ($Errors.Count -eq 0) { 'PASS_AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF' } else { 'FAIL_AUTONOMOUS_INNER_MOTOR_SANDBOX_EXPLORATION_PROOF' } }
$Result = [ordered]@{ schema='AUTONOMOUS_INNER_MOTOR_ORGAN_VALIDATION'; status=$Status; checked_at=(Get-Date).ToString('o'); repo_head=(git rev-parse HEAD).Trim(); sandbox_proof_path=$SandboxProofPath; errors=@($Errors); boundary='Validation only. No motor launch by validator, no active memory mutation, no school run, no web research.' }
$OutPath = Join-Path $OrganRoot 'validation/AUTONOMOUS_INNER_MOTOR_ORGAN_CONTRACT_VALIDATION.json'
$Result | ConvertTo-Json -Depth 12 | Set-Content -Path $OutPath -Encoding UTF8
Write-Host "VALIDATION_STATUS=$Status"
Write-Host "VALIDATION_OUT=$OutPath"
foreach ($err in $Errors) { Write-Host "ERROR=$err" }
if ($Errors.Count -gt 0) { exit 1 }
exit 0
