$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 100) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$task='operations/autonomous_inner_motor/CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A.md'
if(-not(Test-Path $task)){ Add-Err "missing:$task" }
$text=if(Test-Path $task){Get-Content $task -Raw}else{''}
foreach($needle in @(
  'PREFLIGHT_PASS',
  'Files changed before PREFLIGHT_PASS: NO',
  'run_continuous_agent_runtime_v1_lab.ps1',
  'validate_continuous_agent_runtime_v1_lab.ps1',
  'CONTINUOUS_AGENT_RUNTIME_V1_LAB_PROOF.json',
  'same process + RAM state persistence across multiple cycles + safety boundary',
  'Do not edit existing runner/launcher',
  'DurationMinutes must be 1..5',
  'same_pid_across_cycles = true',
  'per_cycle_json_bridge_used_for_ram_state = false',
  'canonical_launcher_mutated = false',
  'cycle_runner_mutated = false',
  'status = CODEX_DRAFT_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A'
)){ if($text -notlike "*$needle*"){ Add-Err "task_missing:$needle" } }
foreach($forbidden in @('fix everything','full migration','replace canonical launcher')){ if($text -like "*$forbidden*"){ Add-Err "unsafe_broad_phrase:$forbidden" } }
$procs=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -notmatch '\s-Command\s' -and $_.CommandLine -match 'run_autonomous_inner_motor.ps1|start_agent_life_v1.ps1|invoke_body_self_inspection_circuit_v1.ps1|codex exec|node.*codex|school|run_continuous_agent_runtime_v1.ps1|continuous_agent_runtime_v1' })
if($procs.Count -ne 0){ Add-Err "process_count_not_zero:$($procs.Count)" }
$status=if($errors.Count -eq 0){'PASS_CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A'}else{'FAIL_CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A'}
$proof=[ordered]@{
  schema='codex_task_continuous_agent_runtime_lab_slice_a_v1_validation'
  status=$status
  checked_at=(Get-Date).ToUniversalTime().ToString('o')
  task=$task
  process_count=$procs.Count
  errors=@($errors)
  boundary=[ordered]@{ task_only=$true; continuous_runtime_launched=$false; codex_launched=$false; active_memory_mutated=$false; canonical_launcher_mutated=$false; cycle_runner_mutated=$false }
}
WJson 'tests/self_development/CODEX_TASK_CONTINUOUS_AGENT_RUNTIME_V1_LAB_SLICE_A_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
