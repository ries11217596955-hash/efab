function Invoke-GeneratedFamilyAutonomousConveyor {
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$RunId,
        [int]$MaxPacks = 1,
        [Parameter(Mandatory)]
        [string]$ReportPath,
        [Parameter(Mandatory)]
        [string]$ProofPath,
        [bool]$DryRun = $true,
        [string[]]$ExcludedTaskIds = @()
    )

    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    . (Join-Path $RepoRoot "modules/read_task_queue.ps1")
    . (Join-Path $RepoRoot "modules/read_pack_registry.ps1")
    . (Join-Path $RepoRoot "modules/select_self_build_pack.ps1")
    . (Join-Path $RepoRoot "modules/execute_self_build_pack.ps1")

    $queue = Read-TaskQueue -RepoRoot $RepoRoot
    $registry = Read-SelfBuildPackRegistry -RepoRoot $RepoRoot
    $roadmap = Get-Content (Join-Path $RepoRoot "CAPABILITY_ROADMAP.json") -Raw | ConvertFrom-Json
    $genesis = Get-Content (Join-Path $RepoRoot "GENESIS_STATE.json") -Raw | ConvertFrom-Json

    $activeTaskIdObserved = [string]$queue.active_task_id
    $effectiveTaskId = $activeTaskIdObserved
    if ($ExcludedTaskIds -contains $activeTaskIdObserved) {
        $effectiveTaskId = "NONE"
    }

    $reportDir = Split-Path -Parent $ReportPath
    $proofDir = Split-Path -Parent $ProofPath
    if (-not [string]::IsNullOrWhiteSpace($reportDir)) { New-Item -ItemType Directory -Force -Path $reportDir | Out-Null }
    if (-not [string]::IsNullOrWhiteSpace($proofDir)) { New-Item -ItemType Directory -Force -Path $proofDir | Out-Null }

    $result = [ordered]@{
        proof_id = "GENERATED_FAMILY_AUTONOMOUS_CONVEYOR_CONTRACT_V1"
        run_id = $RunId
        status = "PASS"
        dry_run = [bool]$DryRun
        active_task_id_observed = $activeTaskIdObserved
        effective_conveyor_task_id = $effectiveTaskId
        excluded_task_ids = @($ExcludedTaskIds)
        conveyor_status = "UNKNOWN"
        packs_executed = 0
        generated_pack_execution_attempted = $false
        selected_pack = $null
        per_pack_results = @()
        next_required_capability = "generated_family_autonomous_conveyor_live_trial_v1"
        conclusion = ""
        roadmap_capability_count = @($roadmap.capabilities).Count
        registry_pack_count = @($registry.packs).Count
        queue_task_count = @($queue.tasks).Count
        genesis_phase = [string]$genesis.current_phase
        genesis_capability = [string]$genesis.current_capability
    }

    if ($effectiveTaskId -eq "NONE") {
        $result.conveyor_status = "READY_NO_ACTIVE_GENERATED_FAMILY_TASK"
        $result.conclusion = "The generated-family autonomous conveyor control surface is installed and can inspect live Builder queue state safely. No active generated-family task is currently available for live conveyor execution."
    }
    elseif ($DryRun) {
        $selected = Select-SelfBuildPack -Registry $registry -ActiveTaskId $effectiveTaskId
        $result.conveyor_status = "READY_ACTIVE_TASK_DETECTED"
        $result.selected_pack = $selected
        $result.conclusion = "Active task detected and pack resolved in dry-run mode."
    }
    else {
        $result.generated_pack_execution_attempted = $true
        $remaining = [Math]::Max(1, $MaxPacks)
        while ($remaining -gt 0) {
            $queue = Read-TaskQueue -RepoRoot $RepoRoot
            $effectiveTaskId = [string]$queue.active_task_id
            if ($ExcludedTaskIds -contains $effectiveTaskId) { $effectiveTaskId = "NONE" }
            if ($effectiveTaskId -eq "NONE") { break }

            $selected = Select-SelfBuildPack -Registry $registry -ActiveTaskId $effectiveTaskId
            $execution = Invoke-SelfBuildPack -RepoRoot $RepoRoot -Pack $selected -RunId $RunId
            $result.per_pack_results += $execution
            $result.packs_executed = @($result.per_pack_results).Count

            if ([string]$execution.status -ne "PASS") {
                $result.status = "FAIL"
                $result.conveyor_status = "HALTED_ON_PACK_FAILURE"
                break
            }

            $remaining--
        }

        if ($result.status -eq "PASS") {
            $result.conveyor_status = "EXECUTION_COMPLETE"
        }
        $result.conclusion = "Conveyor executed up to MaxPacks using existing self-build mechanics with visible per-pack outcomes."
    }

    $report = [ordered]@{
        run_id = $RunId
        conveyor_status = $result.conveyor_status
        active_task_id_observed = $result.active_task_id_observed
        effective_conveyor_task_id = $result.effective_conveyor_task_id
        excluded_task_ids = $result.excluded_task_ids
        packs_executed = $result.packs_executed
        dry_run = $result.dry_run
        generated_pack_execution_attempted = $result.generated_pack_execution_attempted
        selected_pack = $result.selected_pack
        per_pack_results = $result.per_pack_results
        conclusion = $result.conclusion
    }

    $report | ConvertTo-Json -Depth 20 | Set-Content -Path $ReportPath -Encoding UTF8
    $result | ConvertTo-Json -Depth 20 | Set-Content -Path $ProofPath -Encoding UTF8
    return [pscustomobject]$result
}

