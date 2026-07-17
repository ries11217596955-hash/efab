param(
    [string]$OutputPath = 'operations/autonomous_inner_motor/reports/AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1.json'
)

$ErrorActionPreference = 'Stop'

function Write-JsonFile {
    param([string]$Path, $Data)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $json = ($Data | ConvertTo-Json -Depth 60) -replace "`r`n", "`n"
    [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path), $json.TrimEnd() + "`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Test-TextContains {
    param([string]$Path,[string[]]$Needles)
    $text = if(Test-Path $Path){ Get-Content $Path -Raw } else { '' }
    $results = @()
    foreach($needle in $Needles){
        $results += [ordered]@{ needle=$needle; present=($text -like "*$needle*") }
    }
    return @($results)
}

function Get-ContainsAll {
    param($Checks)
    return (@($Checks | Where-Object { -not $_.present }).Count -eq 0)
}

$canonicalLauncher = 'operations/autonomous_inner_motor/start_agent_life_v1.ps1'
$runner = 'operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$selector = 'operations/autonomous_inner_motor/select_agent_next_action_candidate_v1.ps1'

$launcherText = if(Test-Path $canonicalLauncher){Get-Content $canonicalLauncher -Raw}else{''}
$runnerText = if(Test-Path $runner){Get-Content $runner -Raw}else{''}
$selectorText = if(Test-Path $selector){Get-Content $selector -Raw}else{''}

$launcherParamCheck = [ordered]@{ exactly_one_owner_parameter = $false; parameter_name = $null; parse_errors = @() }
if(Test-Path $canonicalLauncher){
    $tokens=$null; $errors=$null
    $ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $canonicalLauncher),[ref]$tokens,[ref]$errors)
    $launcherParamCheck.parse_errors=@($errors | ForEach-Object { $_.Message })
    if($ast.ParamBlock -and @($ast.ParamBlock.Parameters).Count -eq 1){
        $launcherParamCheck.parameter_name=$ast.ParamBlock.Parameters[0].Name.VariablePath.UserPath
        $launcherParamCheck.exactly_one_owner_parameter=($launcherParamCheck.parameter_name -eq 'DurationMinutes')
    }
}

$canonicalContractChecks = Test-TextContains $canonicalLauncher @(
    'DurationMinutes',
    'SandboxExploration',
    'EnableDeepThinking',
    'EnableMemoryLearning',
    'MemoryIngestionMode',
    'QueueOnly',
    'action_execution_allowed = $false',
    'codex_allowed = $false',
    'web_allowed = $false',
    'git_mutation_allowed = $false',
    'repair_execution_allowed = $false'
)

$runnerWiringChecks = Test-TextContains $runner @(
    'select_agent_next_action_candidate_v1.ps1',
    'memory_to_next_path_reuse_gate.json',
    'mental_frontier_expansion_gate.json',
    'mental_frontier_router.json',
    'sandbox_proof_pack_manifest.json',
    'PASS_COMPACT_MEMORY_KNOWLEDGE_PACKET_V1',
    'Get-MentalFrontierExpansionGate',
    'Get-MentalFrontierRouter'
)

$selectorActionChecks = Test-TextContains $selector @(
    'ACTION_CONTRACT_V1',
    'MEMORY_TO_NEXT_PATH_REUSE_GATE_V1',
    'MENTAL_FRONTIER_EXPANSION_GATE_V1',
    'MENTAL_FRONTIER_ROUTER_V1',
    'WIRE_AIMO_TO_EXECUTION',
    'RUN_BIG_LIVE_AGENT',
    'already_absorbed_repeat_candidate'
)

$trackedScriptFiles = @(Get-ChildItem operations,validators,tests -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '\\.runtime\\' })
$runnerInvocations = @()
foreach($file in $trackedScriptFiles){
    $text = Get-Content $file.FullName -Raw
    if($text -match 'run_autonomous_inner_motor\.ps1'){
        $rel = $file.FullName.Replace((Get-Location).Path + '\','').Replace('\','/')
        $classification = 'UNKNOWN_RUNNER_REFERENCE'
        if($rel -eq $canonicalLauncher){ $classification='CANONICAL_LAUNCHER_TO_INTERNAL_RUNNER' }
        elseif($rel -eq $selector){ $classification='ACTION_CANDIDATE_TEXT_REFERENCE_NOT_LAUNCH' }
        elseif($rel -like 'operations/live_like/*' -or $rel -like 'operations/live_readiness/*' -or $rel -like 'operations/live_start/*' -or $rel -like 'operations/parallel_life/*'){ $classification='LEGACY_NON_CANONICAL_LAUNCH_SURFACE' }
        elseif($rel -like 'operations/reasoning/*'){ $classification='MIND_LOGIC_REFERENCE_NOT_LAUNCH' }
        elseif($rel -like 'operations/self_model/*'){ $classification='SELF_MODEL_REFERENCE_NOT_CURRENT_LAUNCH' }
        elseif($rel -like 'validators/*' -or (Split-Path $rel -Leaf) -like 'validate_*.ps1'){ $classification='VALIDATOR_OR_STATIC_CHECK_REFERENCE' }
        elseif((Split-Path $rel -Leaf) -like 'audit_*.ps1'){ $classification='AUDIT_REFERENCE' }
        elseif($rel -like 'tests/*'){ $classification='TEST_REFERENCE' }
        elseif($rel -eq $runner){ $classification='SELF_REFERENCE_OR_TEXT' }
        $runnerInvocations += [ordered]@{ path=$rel; classification=$classification; contains_enable_memory_learning=($text -like '*-EnableMemoryLearning*'); contains_queueonly=($text -like '*QueueOnly*'); contains_duration_minutes=($text -like '*DurationMinutes*') }
    }
}

$runtimeWrappers = @()
if(Test-Path '.runtime/live_trials'){
    $runtimeWrappers = @(Get-ChildItem '.runtime/live_trials' -Recurse -File -Include '*.ps1' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 80 | ForEach-Object {
        [ordered]@{ path=$_.FullName.Replace((Get-Location).Path + '\','').Replace('\','/'); classification='HISTORICAL_RUNTIME_WRAPPER_NOT_CANONICAL'; last_write=$_.LastWriteTime.ToUniversalTime().ToString('o'); bytes=$_.Length }
    })
}

$organs = @(
    [ordered]@{ name='AGENT_LIFE_LAUNCHER_V1'; expected_entry=$canonicalLauncher; validator='validators/validate_agent_life_launcher_v1.ps1'; proof='tests/self_development/AGENT_LIFE_LAUNCHER_V1_PROOF.json'; wired_to_canonical=(Test-Path $canonicalLauncher); notes='Owner-facing canonical launch; only DurationMinutes should be required.' },
    [ordered]@{ name='AUTONOMOUS_INNER_MOTOR_RUNNER'; expected_entry=$runner; validator='validators/validate_autonomous_inner_motor_organ_contract.ps1'; proof='operations/autonomous_inner_motor/validation/AUTONOMOUS_INNER_MOTOR_ORGAN_CONTRACT_VALIDATION.json'; wired_to_canonical=($launcherText -like "*$runner*"); notes='Internal runner only; should be invoked by canonical launcher, not by Owner directly.' },
    [ordered]@{ name='ACTION_DECISION_SELECTOR'; expected_entry=$selector; validator='validators/validate_autonomous_inner_motor_action_decision_wiring_v1.ps1'; proof='tests/self_development/AUTONOMOUS_INNER_MOTOR_ACTION_DECISION_WIRING_V1_PROOF.json'; wired_to_canonical=($runnerText -like "*$selector*"); notes='Selector is called by runner and controls candidate path selection.' },
    [ordered]@{ name='MEMORY_TO_NEXT_PATH_REUSE_GATE_V1'; expected_entry='memory_to_next_path_reuse_gate.json'; validator='validators/validate_memory_to_next_path_reuse_gate_v1.ps1'; proof='tests/self_development/MEMORY_TO_NEXT_PATH_REUSE_GATE_V1_PROOF.json'; wired_to_canonical=($runnerText -like '*memory_to_next_path_reuse_gate.json*' -and $selectorText -like '*MEMORY_TO_NEXT_PATH_REUSE_GATE_V1*'); notes='Wired through runner proof pack and selector action candidate.' },
    [ordered]@{ name='MENTAL_FRONTIER_EXPANSION_GATE_V1'; expected_entry='mental_frontier_expansion_gate.json'; validator='validators/validate_mental_frontier_expansion_gate_v1.ps1'; proof='tests/self_development/MENTAL_FRONTIER_EXPANSION_GATE_V1_PROOF.json'; wired_to_canonical=($runnerText -like '*mental_frontier_expansion_gate.json*' -and $selectorText -like '*MENTAL_FRONTIER_EXPANSION_GATE_V1*'); notes='Wired through runner proof pack and selector action candidate.' },
    [ordered]@{ name='MENTAL_FRONTIER_ROUTER_V1'; expected_entry='mental_frontier_router.json'; validator='validators/validate_mental_frontier_router_v1.ps1'; proof='tests/self_development/MENTAL_FRONTIER_ROUTER_V1_PROOF.json'; wired_to_canonical=($runnerText -like '*mental_frontier_router.json*' -and $selectorText -like '*MENTAL_FRONTIER_ROUTER_V1*'); notes='Wired through runner proof pack and selector action candidate.' },
    [ordered]@{ name='BODY_SELF_INSPECTION_CIRCUIT_V1'; expected_entry='operations/body_self_inspection/invoke_body_self_inspection_circuit_v1.ps1'; validator='validators/validate_body_self_inspection_circuit_v1.ps1'; proof='tests/self_development/BODY_SELF_INSPECTION_CIRCUIT_V1_PROOF.json'; wired_to_canonical=($runnerText -like '*invoke_body_self_inspection_circuit_v1.ps1*'); connection_status=if($runnerText -like '*body_self_inspection_signal*' -or $selectorText -like '*body_self_inspection_signal*'){'FRONTIER_REFERENCED_NOT_INVOKED'}else{'NOT_REFERENCED'}; current_life_required=$false; notes='Built/proven separately; router may reference body_self_inspection_signal, but circuit is not invoked by canonical agent life yet.' }
)

foreach($organ in $organs){
    if($null -eq $organ.current_life_required){ $organ.current_life_required = $true }
    if($null -eq $organ.connection_status){ $organ.connection_status = if($organ.wired_to_canonical){'WIRED_TO_CANONICAL_LIFE'}else{'NOT_WIRED_TO_CANONICAL_LIFE'} }
    $organ.validator_exists = (Test-Path $organ.validator)
    $organ.proof_exists = (Test-Path $organ.proof)
}

$nonCanonicalRunnerReferences = @($runnerInvocations | Where-Object { $_.classification -eq 'UNKNOWN_RUNNER_REFERENCE' })
$legacyNonCanonicalLaunchSurfaces = @($runnerInvocations | Where-Object { $_.classification -eq 'LEGACY_NON_CANONICAL_LAUNCH_SURFACE' })
$unwiredBuiltOrgans = @($organs | Where-Object { $_.proof_exists -and $_.current_life_required -and -not $_.wired_to_canonical })
$frontierReferencedNotInvoked = @($organs | Where-Object { $_.connection_status -eq 'FRONTIER_REFERENCED_NOT_INVOKED' })
$canonicalReady = (Test-Path $canonicalLauncher) -and $launcherParamCheck.exactly_one_owner_parameter -and (Get-ContainsAll $canonicalContractChecks) -and (Get-ContainsAll $runnerWiringChecks) -and (Get-ContainsAll $selectorActionChecks) -and (@($nonCanonicalRunnerReferences).Count -eq 0)

$report = [ordered]@{
    schema='agent_life_single_launch_wiring_audit_v1'
    status=if($canonicalReady){'PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'}else{'FAIL_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'}
    generated_at=(Get-Date).ToUniversalTime().ToString('o')
    repo=[ordered]@{ branch=(git rev-parse --abbrev-ref HEAD).Trim(); head=(git rev-parse --short HEAD).Trim(); delta=(git rev-list --left-right --count HEAD...origin/main 2>$null).Trim(); dirty=@(git status --short --untracked-files=all | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
    canonical_launcher=[ordered]@{ path=$canonicalLauncher; exists=(Test-Path $canonicalLauncher); owner_parameters=$launcherParamCheck; contract_checks=$canonicalContractChecks; contract_pass=(Get-ContainsAll $canonicalContractChecks) }
    internal_runner=[ordered]@{ path=$runner; exists=(Test-Path $runner); wiring_checks=$runnerWiringChecks; wiring_pass=(Get-ContainsAll $runnerWiringChecks) }
    selector=[ordered]@{ path=$selector; exists=(Test-Path $selector); action_checks=$selectorActionChecks; action_checks_pass=(Get-ContainsAll $selectorActionChecks) }
    launch_reference_audit=[ordered]@{ tracked_runner_reference_count=@($runnerInvocations).Count; tracked_runner_references=$runnerInvocations; unknown_runner_reference_count=@($nonCanonicalRunnerReferences).Count; runtime_wrapper_count=@($runtimeWrappers).Count; runtime_wrappers=$runtimeWrappers; legacy_noncanonical_launch_surface_count=@($legacyNonCanonicalLaunchSurfaces).Count; legacy_noncanonical_launch_surfaces=$legacyNonCanonicalLaunchSurfaces }
    organ_wiring=$organs
    findings=[ordered]@{
        canonical_owner_launch_is_single=$launcherParamCheck.exactly_one_owner_parameter
        canonical_launcher_controls_modes=(Get-ContainsAll $canonicalContractChecks)
        runner_contains_current_mental_organs=(Get-ContainsAll $runnerWiringChecks)
        selector_contains_current_action_candidates=(Get-ContainsAll $selectorActionChecks)
        historical_runtime_wrappers_exist=(@($runtimeWrappers).Count -gt 0)
        historical_wrappers_are_not_canonical=$true
        unwired_current_life_organ_count=@($unwiredBuiltOrgans).Count
        unwired_current_life_organs=@($unwiredBuiltOrgans | ForEach-Object { $_.name })
        frontier_referenced_not_invoked_count=@($frontierReferencedNotInvoked).Count
        frontier_referenced_not_invoked=@($frontierReferencedNotInvoked | ForEach-Object { $_.name })
        unknown_tracked_runner_references=@($nonCanonicalRunnerReferences)
        legacy_noncanonical_launch_surface_count=@($legacyNonCanonicalLaunchSurfaces).Count
        legacy_noncanonical_launch_surfaces=@($legacyNonCanonicalLaunchSurfaces | ForEach-Object { $_.path })
    }
    conclusion=[ordered]@{
        current_owner_launch='operations/autonomous_inner_motor/start_agent_life_v1.ps1 -DurationMinutes <minutes>'
        current_owner_launch_status=if($canonicalReady){'CANONICAL_SINGLE_LAUNCH_PATH_OK'}else{'CANONICAL_SINGLE_LAUNCH_PATH_HAS_AUDIT_GAPS'}
        strongest_risk='Historical runtime wrappers exist and can confuse humans, but tracked code has a canonical launcher path. BODY_SELF_INSPECTION_CIRCUIT_V1 is proven separately and currently frontier-referenced, not invoked by canonical AIMO life.'
        do_not_use='Do not manually launch old .runtime/live_trials wrappers or raw run_autonomous_inner_motor variants as Owner-facing life runs.'
    }
    boundary=[ordered]@{ audit_only=$true; no_runtime_started=$true; active_memory_mutated=$false; live_process_touched=$false; codex_launched=$false; web_launched=$false; repair_executed=$false }
}

Write-JsonFile -Path $OutputPath -Data $report
Write-Host $report.status
Write-Host $OutputPath
if($report.status -ne 'PASS_AGENT_LIFE_SINGLE_LAUNCH_WIRING_AUDIT_V1'){ exit 1 }
