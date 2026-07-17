param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 10080)]
    [int]$DurationMinutes
)

$ErrorActionPreference = "Stop"

function Convert-JsonCompatible {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [string] -or $Value -is [char] -or $Value -is [bool] -or $Value -is [int] -or $Value -is [long] -or $Value -is [double] -or $Value -is [decimal]) { return $Value }
    if ($Value -is [datetime]) { return $Value.ToUniversalTime().ToString("o") }
    if ($Value -is [System.Collections.IDictionary]) {
        $out = [ordered]@{}
        foreach ($key in $Value.Keys) { $out[[string]$key] = Convert-JsonCompatible $Value[$key] }
        return $out
    }
    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        return @($Value | ForEach-Object { Convert-JsonCompatible $_ })
    }
    if ($Value.PSObject -and $Value.PSObject.Properties) {
        $out = [ordered]@{}
        foreach ($prop in $Value.PSObject.Properties) { $out[[string]$prop.Name] = Convert-JsonCompatible $prop.Value }
        return $out
    }
    return [string]$Value
}
function Write-JsonFile {
    param([string]$Path, $Data)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = ((Convert-JsonCompatible $Data) | ConvertTo-Json -Depth 40) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText($Path, $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Get-RepoRoot {
    $root = (git rev-parse --show-toplevel 2>$null)
    if (-not $root) { throw "REPO_ROOT_NOT_FOUND" }
    return $root.Trim()
}

function Get-ProcessConflicts {
    $selfPid = $PID
    $patterns = @(
        "run_agent_school",
        "canonical_exact",
        "codex exec",
        "run_autonomous_inner_motor.ps1",
        "start_agent_life_v1.ps1"
    )
    $matches = @()
    $processes = Get-CimInstance Win32_Process | Where-Object { $_.CommandLine }
    foreach ($p in $processes) {
        if ([int]$p.ProcessId -eq [int]$selfPid) { continue }
        foreach ($pattern in $patterns) {
            $cmd = [string]$p.CommandLine
            if ($pattern -in @("run_autonomous_inner_motor.ps1", "start_agent_life_v1.ps1")) {
                if ($cmd -match "(?i)\s-Command\s") { continue }
                if ($cmd -notmatch "(?i)\s-File\s" -and $cmd -notmatch "(?i)^.*powershell.*-f\s") { continue }
            }
            if ($cmd -match [regex]::Escape($pattern)) {
                $matches += [ordered]@{
                    process_id = [int]$p.ProcessId
                    name = [string]$p.Name
                    matched_pattern = $pattern
                    command_line = $cmd
                }
                break
            }
        }
    }
    return @($matches)
}

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

$durationSeconds = [int]($DurationMinutes * 60)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$trialRoot = Join-Path $RepoRoot ".runtime/live_trials/agent_life_${DurationMinutes}min_$timestamp"
New-Item -ItemType Directory -Force -Path $trialRoot | Out-Null

$preflightPath = Join-Path $trialRoot "PREFLIGHT.json"
$summaryPath = Join-Path $trialRoot "LIVE_TRIAL_SUMMARY.json"

$head = (git rev-parse --short HEAD).Trim()
$delta = (git rev-list --left-right --count HEAD...origin/main 2>$null).Trim()
$dirty = @(git status --short --untracked-files=all | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$dirty = @($dirty | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$activeMemoryRoot = Join-Path $RepoRoot ".runtime/active_compact_semantic_memory_v1"
$activeMemoryReady = (Test-Path (Join-Path $activeMemoryRoot "manifest.json")) -and (Test-Path (Join-Path $activeMemoryRoot "index.json")) -and (Test-Path (Join-Path $activeMemoryRoot "cells.jsonl"))
$conflicts = @(Get-ProcessConflicts | Where-Object { $null -ne $_ -and $_.process_id })

$preflight = [ordered]@{
    schema = "agent_life_launcher_preflight_v1"
    status = if ($activeMemoryReady -and @($conflicts).Count -eq 0 -and @($dirty | Where-Object { $_ -notmatch '^\?\? \.runtime/' }).Count -eq 0) { "PREFLIGHT_PASS" } else { "BLOCKED_PREFLIGHT" }
    generated_at = (Get-Date).ToUniversalTime().ToString("o")
    repo_root = $RepoRoot
    head = $head
    delta = $delta
    dirty = $dirty
    duration_minutes = $DurationMinutes
    canonical_launch_contract = [ordered]@{
        required_user_parameter = "DurationMinutes"
        mode = "SandboxExploration"
        enable_deep_thinking = $true
        enable_memory_learning = $true
        memory_ingestion_mode = "QueueOnly"
        action_execution_allowed = $false
        codex_allowed = $false
        web_allowed = $false
        git_mutation_allowed = $false
        repair_execution_allowed = $false
    }
    active_memory = [ordered]@{
        root_exists = (Test-Path $activeMemoryRoot)
        manifest_exists = (Test-Path (Join-Path $activeMemoryRoot "manifest.json"))
        index_exists = (Test-Path (Join-Path $activeMemoryRoot "index.json"))
        cells_jsonl_exists = (Test-Path (Join-Path $activeMemoryRoot "cells.jsonl"))
        ready = $activeMemoryReady
    }
    process_conflicts = $conflicts
    boundary = [ordered]@{
        single_launcher = $true
        user_mode_choice_allowed = $false
        action_execution_allowed = $false
        direct_active_memory_write = $false
        governed_memory_learning = $true
        memory_ingestion_mode = "QueueOnly"
        live_action = $false
    }
}
Write-JsonFile -Path $preflightPath -Data $preflight
if ($preflight.status -ne "PREFLIGHT_PASS") {
    Write-JsonFile -Path $summaryPath -Data ([ordered]@{
        schema = "agent_life_trial_summary_v1"
        status = "BLOCKED_AGENT_LIFE_PREFLIGHT"
        preflight_ref = $preflightPath
        duration_minutes = $DurationMinutes
        cycles = 0
        boundary = $preflight.boundary
    })
    throw "BLOCKED_AGENT_LIFE_PREFLIGHT: see $preflightPath"
}

$start = Get-Date
$end = $start.AddSeconds($durationSeconds)
$cycles = @()
$cycle = 0

while ((Get-Date) -lt $end) {
    $cycle++
    $cycleStart = Get-Date
    powershell -NoProfile -ExecutionPolicy Bypass -File "operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1" -Mode SandboxExploration -EnableDeepThinking -EnableMemoryLearning -MemoryIngestionMode QueueOnly
    $exit = $LASTEXITCODE

    $latest = Get-ChildItem ".runtime/autonomous_inner_motor" -Directory -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    $proofPath = $null
    $proof = $null
    if ($latest) {
        $candidateProof = Join-Path $latest.FullName "SANDBOX_EXPLORATION_PROOF.json"
        if (Test-Path $candidateProof) {
            $proofPath = $candidateProof
            $proof = Get-Content $candidateProof -Raw | ConvertFrom-Json
        }
    }

    $cycles += [ordered]@{
        cycle = $cycle
        started_at = $cycleStart.ToUniversalTime().ToString("o")
        exit_code = $exit
        run_dir = if ($latest) { $latest.FullName } else { $null }
        proof_path = $proofPath
        proof_status = if ($proof) { $proof.deep_thinking.status } else { $null }
        action_execution_allowed = if ($proof) { $proof.boundary.action_execution_allowed } else { $null }
        active_memory_mutated = if ($proof) { $proof.mutation_audit.active_memory_mutated } else { $null }
        git_mutated = if ($proof) { $proof.mutation_audit.git_mutated } else { $null }
        codex_launched = if ($proof) { $proof.mutation_audit.codex_launched } else { $null }
        web_research_performed = if ($proof) { $proof.mutation_audit.web_research_performed } else { $null }
        memory_ingestion_mode = if ($proof) { $proof.mutation_audit.memory_ingestion_mode } else { "QueueOnly" }
        governed_absorption_used = if ($proof) { $proof.mutation_audit.governed_absorption_used } else { $null }
        anti_repeat_status = if ($proof) { $proof.memory_to_next_path_reuse_gate.status } else { $null }
        selected_action_id = if ($proof) { $proof.next_action_candidate.selected_action.action_id } else { $null }
        consecutive_repeat_count = if ($proof) { $proof.memory_to_next_path_reuse_gate.consecutive_repeat_count } else { $null }
        repeated_candidate_is_progress = if ($proof) { -not $proof.memory_to_next_path_reuse_gate.repeat_pressure_detected } else { $null }
        repeat_requires_new_learning_or_escalation = if ($proof) { $proof.memory_to_next_path_reuse_gate.repeat_pressure_detected } else { $null }
        manifest_status = if ($proof) { $proof.sandbox_proof_pack_manifest.status } else { $null }
        manifest_files = if ($proof) { @($proof.sandbox_proof_pack_manifest.files).Count } else { $null }
    }

    if ($exit -ne 0) { break }
    Start-Sleep -Seconds 5
}

$finish = Get-Date
$badCycles = @($cycles | Where-Object { $_.exit_code -ne 0 })
$summary = [ordered]@{
    schema = "agent_life_trial_summary_v1"
    status = if (@($badCycles).Count -eq 0) { "PASS_AGENT_LIFE_CANONICAL_TRIAL" } else { "FAIL_AGENT_LIFE_CANONICAL_TRIAL" }
    started_at = $start.ToUniversalTime().ToString("o")
    finished_at = $finish.ToUniversalTime().ToString("o")
    duration_minutes_requested = $DurationMinutes
    duration_seconds = [int]($finish - $start).TotalSeconds
    cycles = @($cycles).Count
    launcher = "operations/autonomous_inner_motor/start_agent_life_v1.ps1"
    launch_contract = $preflight.canonical_launch_contract
    preflight_ref = $preflightPath
    proof_status_counts = @($cycles | Group-Object proof_status | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })
    anti_repeat_status_counts = @($cycles | Group-Object anti_repeat_status | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })
    selected_action_counts = @($cycles | Group-Object selected_action_id | ForEach-Object { [ordered]@{ name = $_.Name; count = $_.Count } })
    governed_absorption_count = @($cycles | Where-Object { $_.governed_absorption_used -eq $true }).Count
    active_memory_mutated_count = @($cycles | Where-Object { $_.active_memory_mutated -eq $true }).Count
    boundary = [ordered]@{
        action_execution_allowed = $false
        direct_active_memory_write = $false
        governed_memory_learning = $true
        memory_ingestion_mode = "QueueOnly"
        git_mutated = (@($cycles | Where-Object { $_.git_mutated -eq $true }).Count -gt 0)
        codex_launched = (@($cycles | Where-Object { $_.codex_launched -eq $true }).Count -gt 0)
        web_research_performed = (@($cycles | Where-Object { $_.web_research_performed -eq $true }).Count -gt 0)
        repair_executed = $false
    }
    cycles_detail = $cycles
    repo_after = [ordered]@{
        head = (git rev-parse --short HEAD).Trim()
        delta = (git rev-list --left-right --count HEAD...origin/main 2>$null).Trim()
        dirty = @(git status --short --untracked-files=all | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    }
}
Write-JsonFile -Path $summaryPath -Data $summary
$summary.status | Set-Content (Join-Path $trialRoot "exit_status.txt") -Encoding UTF8
Write-Output $summaryPath
