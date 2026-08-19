param(
    [Parameter(Mandatory = $true, Position = 0)]
    [ValidateRange(1, 10080)]
    [int]$DurationMinutes,
    [ValidateRange(5,45)][int]$TickBudgetSeconds=35
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

function Invoke-AgentLifeOwnedRunSanitation {
    param([Parameter(Mandatory=$true)][string]$RunDir,[Parameter(Mandatory=$true)][string]$AimoRoot,[Parameter(Mandatory=$true)][string[]]$OwnedRunDirs,[switch]$DeleteWholeRun)
    if(-not(Test-Path -LiteralPath $RunDir -PathType Container)){ return [ordered]@{status='ABSENT';removed_count=0;removed_bytes=0;kept_count=0} }
    $resolvedRoot=(Resolve-Path -LiteralPath $AimoRoot).Path.TrimEnd('\')
    $resolvedRun=(Resolve-Path -LiteralPath $RunDir).Path.TrimEnd('\')
    if((Split-Path -Parent $resolvedRun) -ne $resolvedRoot -or (Split-Path -Leaf $resolvedRun) -notlike 'aimo_*'){ throw "SANITATION_REFUSED_NON_AIMO_CHILD:$resolvedRun" }
    $ownedResolved=@($OwnedRunDirs | ForEach-Object { if(Test-Path -LiteralPath $_){(Resolve-Path -LiteralPath $_).Path.TrimEnd('\')}else{[IO.Path]::GetFullPath($_).TrimEnd('\')} })
    if($resolvedRun -notin $ownedResolved){ throw "SANITATION_REFUSED_NOT_CURRENT_LIFE_OWNED:$resolvedRun" }
    $files=@(Get-ChildItem -LiteralPath $resolvedRun -Recurse -File -Force -ErrorAction SilentlyContinue); [int64]$bytes=(($files|Measure-Object Length -Sum).Sum)
    if($DeleteWholeRun){ Remove-Item -LiteralPath $resolvedRun -Recurse -Force -ErrorAction Stop; return [ordered]@{status='DELETED_SELF_OWNED_INCOMPLETE_RUN';removed_count=$files.Count;removed_bytes=$bytes;kept_count=0} }
    $keep=@('memory_to_next_path_reuse_gate.json','short_term_mind_state.json','short_term_state_to_next_task_router.json','refocus_seed_diversification.json','refocus_to_new_thought_seed.json','action_decision_packet.json')
    $removed=0;[int64]$removedBytes=0
    foreach($f in $files){ if($f.DirectoryName -eq $resolvedRun -and $f.Name -in $keep){continue};$removed++;$removedBytes += [int64]$f.Length;Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop }
    foreach($d in @(Get-ChildItem -LiteralPath $resolvedRun -Directory -Force -ErrorAction SilentlyContinue)){Remove-Item -LiteralPath $d.FullName -Recurse -Force -ErrorAction Stop}
    $kept=@(Get-ChildItem -LiteralPath $resolvedRun -File -Force -ErrorAction SilentlyContinue)
    if($kept.Count -gt 6){ throw "SANITATION_CONTINUITY_LIMIT_EXCEEDED:$($kept.Count)" }
    return [ordered]@{status='COMPACTED_SELF_OWNED_RUN_TO_CONTINUITY';removed_count=$removed;removed_bytes=$removedBytes;kept_count=$kept.Count;kept_files=@($kept.Name)}
}

$RepoRoot = Get-RepoRoot
Set-Location $RepoRoot

$durationSeconds = [int]($DurationMinutes * 60)
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$trialRoot = Join-Path $RepoRoot ".runtime/live_trials/agent_life_${DurationMinutes}min_$timestamp"
New-Item -ItemType Directory -Force -Path $trialRoot | Out-Null

$preflightPath = Join-Path $trialRoot "PREFLIGHT.json"
$summaryPath = Join-Path $trialRoot "LIVE_TRIAL_SUMMARY.json"
$lifeWorkingMemoryPath = Join-Path $trialRoot "life_working_memory_context.json"

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
        memory_ingestion_mode = "Auto"
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
        memory_ingestion_mode = "Auto"
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
        life_working_memory_path = $lifeWorkingMemoryPath
        boundary = $preflight.boundary
    })
    throw "BLOCKED_AGENT_LIFE_PREFLIGHT: see $preflightPath"
}

$start = Get-Date
$end = $start.AddSeconds($durationSeconds)
$cycles = @()
$cycle = 0
$aimoRoot=Join-Path $RepoRoot '.runtime/autonomous_inner_motor'
if(-not(Test-Path -LiteralPath $aimoRoot)){New-Item -ItemType Directory -Force -Path $aimoRoot|Out-Null}
$ownedRunDirs=New-Object 'System.Collections.Generic.List[string]'
$sanitationEvents=New-Object 'System.Collections.Generic.List[object]'
$maxOwnedContinuityDirs=12

while ((Get-Date) -lt $end) {
    $cycle++
    $cycleStart=Get-Date
    $beforeDirs=@{};Get-ChildItem -LiteralPath $aimoRoot -Directory -ErrorAction SilentlyContinue|ForEach-Object{$beforeDirs[$_.FullName]=$true}
    $remainingMs=[Math]::Max(0,[int](($end-(Get-Date)).TotalMilliseconds))
    $tickBudgetMs=[Math]::Min($remainingMs,$TickBudgetSeconds*1000)
    if($tickBudgetMs -le 0){break}
    $runnerArgs=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1','-Mode','SandboxExploration','-EnableDeepThinking','-EnableMemoryLearning','-MemoryIngestionMode','Auto','-WakeContextPath',$lifeWorkingMemoryPath,'-LifeProfile','LifeLight')
    $runner=Start-Process -FilePath 'powershell.exe' -ArgumentList $runnerArgs -PassThru -NoNewWindow
    $boundedStop=$false
    if(-not $runner.WaitForExit($tickBudgetMs)){ $boundedStop=$true;& taskkill.exe /PID $runner.Id /T /F|Out-Null;try{$runner.WaitForExit(3000)}catch{} }
    $exit=if($boundedStop){124}else{$runner.ExitCode}
    $cycleFinish=Get-Date
    $newDirs=@(Get-ChildItem -LiteralPath $aimoRoot -Directory -ErrorAction SilentlyContinue|Where-Object{-not $beforeDirs.ContainsKey($_.FullName) -and $_.LastWriteTime -ge $cycleStart.AddSeconds(-2)}|Sort-Object LastWriteTime)
    $runBindingStatus=if($newDirs.Count -eq 1){'BOUND_CURRENT_TICK_RUN_DIR'}elseif($newDirs.Count -eq 0){'NO_CURRENT_TICK_RUN_DIR'}else{'AMBIGUOUS_CURRENT_TICK_RUN_DIRS'}
    $currentRun=if($newDirs.Count -eq 1){$newDirs[0]}else{$null}
    if($currentRun -and -not $ownedRunDirs.Contains($currentRun.FullName)){[void]$ownedRunDirs.Add($currentRun.FullName)}
    $proofPath=$null;$proof=$null
    if($currentRun){$candidateProof=Join-Path $currentRun.FullName 'SANDBOX_EXPLORATION_PROOF.json';if(Test-Path -LiteralPath $candidateProof){$proofPath=$candidateProof;try{$proof=Get-Content $candidateProof -Raw|ConvertFrom-Json}catch{$proof=$null}}}
    $selectedActionId=if($proof -and $proof.next_action_candidate -and $proof.next_action_candidate.packet -and $proof.next_action_candidate.packet.selected_action){$proof.next_action_candidate.packet.selected_action.action_id}elseif($proof -and $proof.next_action_candidate -and $proof.next_action_candidate.selected_action){$proof.next_action_candidate.selected_action.action_id}else{$null}
    $knowledgeCandidate=if($proof -and $proof.deep_thinking -and $proof.deep_thinking.absorption -and $proof.deep_thinking.absorption.atom_path){[string]$proof.deep_thinking.absorption.atom_path}else{$null}
    $usefulOutcome=if($knowledgeCandidate){'KNOWLEDGE_CANDIDATE_PRODUCED'}elseif($selectedActionId){'NEXT_ACTION_CANDIDATE_PRODUCED'}elseif($proof){'THOUGHT_PROOF_COMPLETED'}else{'NO_COMPLETED_THOUGHT_PROOF'}
    $sanitation=$null
    if($currentRun){
      if($exit -ne 0 -or -not $proof){$sanitation=Invoke-AgentLifeOwnedRunSanitation -RunDir $currentRun.FullName -AimoRoot $aimoRoot -OwnedRunDirs @($ownedRunDirs.ToArray()) -DeleteWholeRun;[void]$ownedRunDirs.Remove($currentRun.FullName)}
      else{$sanitation=Invoke-AgentLifeOwnedRunSanitation -RunDir $currentRun.FullName -AimoRoot $aimoRoot -OwnedRunDirs @($ownedRunDirs.ToArray())}
      [void]$sanitationEvents.Add([ordered]@{cycle=$cycle;run_dir=$currentRun.FullName;result=$sanitation})
    }
    $existingOwned=@($ownedRunDirs.ToArray()|Where-Object{Test-Path -LiteralPath $_})
    while($existingOwned.Count -gt $maxOwnedContinuityDirs){$oldest=$existingOwned|Sort-Object{(Get-Item -LiteralPath $_).LastWriteTime}|Select-Object -First 1;$ev=Invoke-AgentLifeOwnedRunSanitation -RunDir $oldest -AimoRoot $aimoRoot -OwnedRunDirs @($ownedRunDirs.ToArray()) -DeleteWholeRun;[void]$sanitationEvents.Add([ordered]@{cycle=$cycle;run_dir=$oldest;reason='owned_continuity_window_limit';result=$ev});[void]$ownedRunDirs.Remove($oldest);$existingOwned=@($ownedRunDirs.ToArray()|Where-Object{Test-Path -LiteralPath $_})}
    $cycles += [ordered]@{cycle=$cycle;started_at=$cycleStart.ToUniversalTime().ToString('o');finished_at=$cycleFinish.ToUniversalTime().ToString('o');duration_seconds=[Math]::Round(($cycleFinish-$cycleStart).TotalSeconds,3);tick_budget_seconds=$TickBudgetSeconds;exit_code=$exit;bounded_stop=$boundedStop;run_binding_status=$runBindingStatus;run_dir=if($currentRun){$currentRun.FullName}else{$null};proof_path=$proofPath;proof_status=if($proof){$proof.deep_thinking.status}else{$null};useful_outcome=$usefulOutcome;knowledge_candidate=$knowledgeCandidate;knowledge_candidate_reason_absent=if($knowledgeCandidate){$null}elseif($proof){'governed absorption produced no atom path this tick'}else{'tick produced no completed proof'};memory_ingestion_mode=if($proof){$proof.mutation_audit.memory_ingestion_mode}else{'Auto'};governed_absorption_used=if($proof){$proof.mutation_audit.governed_absorption_used}else{$false};selected_action_id=$selectedActionId;memory_is_command=if($proof -and $proof.memory_influence_contract){$proof.memory_influence_contract.memory_is_command}else{$false};memory_can_force_next_step=if($proof -and $proof.memory_influence_contract){$proof.memory_influence_contract.memory_can_force_next_step}else{$false};sanitation=$sanitation;action_execution_allowed=if($proof){$proof.boundary.action_execution_allowed}else{$false};active_memory_mutated=if($proof){$proof.mutation_audit.active_memory_mutated}else{$false};git_mutated=if($proof){$proof.mutation_audit.git_mutated}else{$false};codex_launched=if($proof){$proof.mutation_audit.codex_launched}else{$false};web_research_performed=if($proof){$proof.mutation_audit.web_research_performed}else{$false}}
    if($exit -ne 0 -and -not $boundedStop){break}
    if((Get-Date) -lt $end){Start-Sleep -Seconds 1}
}

$finish = Get-Date
$badCycles = @($cycles | Where-Object { $_.exit_code -ne 0 -and -not $_.bounded_stop })
$summary = [ordered]@{
    schema = "agent_life_trial_summary_v1"
    status = if (@($badCycles).Count -eq 0) { "PASS_AGENT_LIFE_CANONICAL_TRIAL" } else { "FAIL_AGENT_LIFE_CANONICAL_TRIAL" }
    started_at = $start.ToUniversalTime().ToString("o")
    finished_at = $finish.ToUniversalTime().ToString("o")
    duration_minutes_requested = $DurationMinutes
    tick_budget_seconds = $TickBudgetSeconds
    duration_seconds = [int]($finish - $start).TotalSeconds
    life_working_memory_path = $lifeWorkingMemoryPath
    life_working_memory_exists = (Test-Path $lifeWorkingMemoryPath)
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
        memory_ingestion_mode = "Auto"
        git_mutated = (@($cycles | Where-Object { $_.git_mutated -eq $true }).Count -gt 0)
        codex_launched = (@($cycles | Where-Object { $_.codex_launched -eq $true }).Count -gt 0)
        web_research_performed = (@($cycles | Where-Object { $_.web_research_performed -eq $true }).Count -gt 0)
        repair_executed = $false
    }
    sanitation = [ordered]@{policy='OWNED_RUN_COMPACTION_V1';continuity_files_per_run_max=6;owned_continuity_dirs_max=$maxOwnedContinuityDirs;events=@($sanitationEvents.ToArray());foreign_run_cleanup_allowed=$false;active_memory_cleanup_allowed=$false;tracked_repo_cleanup_allowed=$false}
    memory_influence_contract=[ordered]@{role='evidence_weight_context';memory_is_command=$false;memory_can_force_next_step=$false}
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
