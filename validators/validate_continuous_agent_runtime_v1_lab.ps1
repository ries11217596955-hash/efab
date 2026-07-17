param(
  [int]$DurationMinutes = 1
)

$ErrorActionPreference = 'Stop'
$errors = @()
function Add-Err([string]$e){ $script:errors += $e }
function Write-CleanJson {
  param([string]$Path, $Data, [int]$Depth = 100)
  $dir = Split-Path $Path -Parent
  if ($dir) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json = ($Data | ConvertTo-Json -Depth $Depth) -replace "`r`n", "`n"
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}
function Get-TreeStats([string]$Path){
  if (-not (Test-Path -LiteralPath $Path)) { return [ordered]@{exists=$false; files=0; bytes=0; mb=0} }
  $files = @(Get-ChildItem -LiteralPath $Path -Recurse -File -Force -ErrorAction SilentlyContinue)
  $bytes = [int64](($files | Measure-Object Length -Sum).Sum)
  return [ordered]@{exists=$true; files=$files.Count; bytes=$bytes; mb=[math]::Round($bytes/1MB,2)}
}

$repoRoot = (& git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot
$scriptPath = 'operations/autonomous_inner_motor/run_continuous_agent_runtime_v1_lab.ps1'
$canonicalProofPath = 'tests/self_development/CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json'
$acceptancePath = 'operations/autonomous_inner_motor/reports/CONTINUOUS_AGENT_RUNTIME_V1_LAB_ACCEPTANCE.json'
$runtimeBase = '.runtime/continuous_agent_runtime_v1_lab'
$activeRoot = '.runtime/active_compact_semantic_memory_v1'
$launcher = 'operations/autonomous_inner_motor/start_agent_life_v1.ps1'
$runner = 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'

if (-not (Test-Path -LiteralPath $scriptPath)) { Add-Err "missing_script:$scriptPath" }
if (-not (Test-Path -LiteralPath $activeRoot)) { Add-Err "active_memory_missing_before:$activeRoot" }

if (Test-Path -LiteralPath $scriptPath) {
  $tokens = $null; $parseErrors = $null
  [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $scriptPath), [ref]$tokens, [ref]$parseErrors) | Out-Null
  if ($parseErrors.Count -gt 0) { foreach($e in $parseErrors){ Add-Err "script_parse_error:$($e.Message)" } }
}

$launcherHashBefore = if (Test-Path $launcher) { (Get-FileHash $launcher -Algorithm SHA256).Hash } else { $null }
$runnerHashBefore = if (Test-Path $runner) { (Get-FileHash $runner -Algorithm SHA256).Hash } else { $null }
$activeStatsBefore = Get-TreeStats $activeRoot
$beforeRuntimeDirs = @()
if (Test-Path -LiteralPath $runtimeBase) { $beforeRuntimeDirs = @(Get-ChildItem -LiteralPath $runtimeBase -Directory -Force | Select-Object -ExpandProperty FullName) }

if ($errors.Count -eq 0) {
  powershell -NoProfile -ExecutionPolicy Bypass -File $scriptPath -DurationMinutes $DurationMinutes
  if ($LASTEXITCODE -ne 0) { Add-Err "lab_script_exit_code:$LASTEXITCODE" }
}

$afterRuntimeDirs = @()
if (Test-Path -LiteralPath $runtimeBase) { $afterRuntimeDirs = @(Get-ChildItem -LiteralPath $runtimeBase -Directory -Force | Sort-Object LastWriteTime -Descending) }
$newRuntime = $null
foreach ($dir in $afterRuntimeDirs) {
  if ($beforeRuntimeDirs -notcontains $dir.FullName) { $newRuntime = $dir; break }
}
if (-not $newRuntime -and $afterRuntimeDirs.Count -gt 0) { $newRuntime = $afterRuntimeDirs[0] }

$runtimeProof = $null
$runtimeProofPath = $null
if ($newRuntime) {
  $runtimeProofPath = Join-Path $newRuntime.FullName 'CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json'
  if (Test-Path -LiteralPath $runtimeProofPath) { $runtimeProof = Get-Content -LiteralPath $runtimeProofPath -Raw | ConvertFrom-Json }
}
if (-not $runtimeProof) { Add-Err 'runtime_proof_missing' }

if ($runtimeProof) {
  if ($runtimeProof.status -ne 'PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB') { Add-Err "status_mismatch:$($runtimeProof.status)" }
  if ($runtimeProof.same_pid_across_cycles -ne $true) { Add-Err 'same_pid_false' }
  if ([int]$runtimeProof.cycle_count -lt 2) { Add-Err "cycle_count_lt_2:$($runtimeProof.cycle_count)" }
  if ([int]$runtimeProof.ram_counter_final -lt 2) { Add-Err "ram_counter_lt_2:$($runtimeProof.ram_counter_final)" }
  if ($runtimeProof.ram_state_persisted -ne $true) { Add-Err 'ram_state_persisted_false' }
  if ($runtimeProof.per_cycle_json_bridge_used_for_ram_state -ne $false) { Add-Err 'per_cycle_json_bridge_not_false' }
  foreach($flag in @('lock_created','heartbeat_written','stop_signal_supported','checkpoint_written','final_proof_written','cycle_scratch_cleared')) {
    if ($runtimeProof.$flag -ne $true) { Add-Err "required_true_flag_false:$flag" }
  }
  foreach($flag in @('repo_mutated','active_memory_direct_mutated','codex_launched','web_launched','school_launched','raw_debug_retained','canonical_launcher_mutated','cycle_runner_mutated')) {
    if ($runtimeProof.$flag -ne $false) { Add-Err "required_false_flag_true:$flag" }
  }
  $pids = @($runtimeProof.cycle_records | ForEach-Object { [int]$_.pid } | Select-Object -Unique)
  if ($pids.Count -ne 1) { Add-Err "cycle_pid_unique_count:$($pids.Count)" }
  if ($pids.Count -eq 1 -and [int]$pids[0] -ne [int]$runtimeProof.pid) { Add-Err 'cycle_pid_does_not_match_runtime_pid' }
  $forbiddenFiles = @(
    'mind_logic_frame.json',
    'action_decision_packet.json',
    'wake_body_audit',
    'default_wake_reflexes.json'
  )
  foreach($ff in $forbiddenFiles){
    $found = @(Get-ChildItem -LiteralPath $newRuntime.FullName -Recurse -Force -ErrorAction SilentlyContinue | Where-Object { $_.Name -eq $ff -or $_.FullName -like "*$ff*" })
    if ($found.Count -gt 0) { Add-Err "forbidden_runtime_file_found:$ff" }
  }
}

$launcherHashAfter = if (Test-Path $launcher) { (Get-FileHash $launcher -Algorithm SHA256).Hash } else { $null }
$runnerHashAfter = if (Test-Path $runner) { (Get-FileHash $runner -Algorithm SHA256).Hash } else { $null }
if ($launcherHashBefore -ne $launcherHashAfter) { Add-Err 'canonical_launcher_hash_changed' }
if ($runnerHashBefore -ne $runnerHashAfter) { Add-Err 'cycle_runner_hash_changed' }
$activeStatsAfter = Get-TreeStats $activeRoot
if ($activeStatsBefore.bytes -ne $activeStatsAfter.bytes -or $activeStatsBefore.files -ne $activeStatsAfter.files) { Add-Err 'active_memory_stats_changed' }

$procPatterns = 'codex exec|node_modules.*@openai/codex|node.*codex.js|school'
$badProcs = @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch 'Get-CimInstance Win32_Process' -and $_.CommandLine -match $procPatterns })
if ($badProcs.Count -ne 0) { Add-Err "bad_process_count:$($badProcs.Count)" }

$status = if ($errors.Count -eq 0) { 'PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB' } else { 'FAIL_CONTINUOUS_AGENT_RUNTIME_V1_LAB' }
$canonical = [ordered]@{
  schema = 'continuous_agent_runtime_v1_lab_validation'
  status = $status
  checked_at = (Get-Date).ToUniversalTime().ToString('o')
  lab_script = $scriptPath
  runtime_proof_path = if ($runtimeProofPath) { $runtimeProofPath.Replace((Get-Location).Path + '\','') } else { $null }
  runtime_root = if ($newRuntime) { $newRuntime.FullName.Replace((Get-Location).Path + '\','') } else { $null }
  runtime_proof = $runtimeProof
  validation = [ordered]@{
    launcher_hash_before = $launcherHashBefore
    launcher_hash_after = $launcherHashAfter
    runner_hash_before = $runnerHashBefore
    runner_hash_after = $runnerHashAfter
    active_memory_before = $activeStatsBefore
    active_memory_after = $activeStatsAfter
    bad_process_count = $badProcs.Count
  }
  errors = @($errors)
  boundary = [ordered]@{
    operator_controlled = $true
    continuous_runtime_lab_launched = $true
    canonical_launcher_mutated = $false
    cycle_runner_mutated = $false
    active_memory_mutated = $false
    repo_runtime_mutated = $true
    codex_launched_by_lab = $false
    web_launched_by_lab = $false
    school_launched_by_lab = $false
    accepted_as_live = $false
  }
}
Write-CleanJson -Path $canonicalProofPath -Data $canonical 100

$acceptance = [ordered]@{
  schema = 'continuous_agent_runtime_v1_lab_acceptance'
  status = if ($status -eq 'PASS_CONTINUOUS_AGENT_RUNTIME_V1_LAB') { 'ACCEPTED_PROVEN_LAB_CONTINUOUS_AGENT_RUNTIME_V1_LAB' } else { 'REJECTED_CONTINUOUS_AGENT_RUNTIME_V1_LAB' }
  accepted_at = (Get-Date).ToUniversalTime().ToString('o')
  proof = $canonicalProofPath
  runtime_proof_path = $canonical.runtime_proof_path
  may_claim = 'PROVEN_LAB: one process can keep RAM state across multiple cycles under supervised safety gates'
  may_not_claim = @('canonical life replaced','agent became autonomous','mind quality improved','compact memory integration solved','live/unattended runtime ready')
  boundary = $canonical.boundary
}
Write-CleanJson -Path $acceptancePath -Data $acceptance 100

Write-Host "STATUS=$status"
if ($errors.Count -gt 0) { foreach($e in $errors){ Write-Host "ERROR=$e" }; exit 1 }
