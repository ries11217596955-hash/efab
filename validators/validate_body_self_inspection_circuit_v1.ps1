param(
    [string]$RepoRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

$RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_circuit_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_CIRCUIT_V1_PROOF.json"

function New-BodyInspectionBoundary {
    return [ordered]@{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
        passports_mutated = $false
        contracts_mutated = $false
        repair_executed = $false
        parent_action_executed = $false
        mind_logic_mutated = $false
        nervous_system_connected = $false
        live_process_touched = $false
        codex_launched = $false
        web_launched = $false
        cleanup_performed = $false
    }
}

function Write-JsonFile {
    param(
        [string]$Path,
        $Data
    )

    $parent = Split-Path -Parent $Path
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }

    $json = ($Data | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
    $json = $json.TrimEnd() + "`n"
    [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

function Read-JsonFile {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing JSON file: $Path"
    }
    return (Get-Content -Raw -LiteralPath $Path | ConvertFrom-Json)
}

function Get-PropertyValue {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $null
    }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $null
    }
    $property = $Object.PSObject.Properties[$Name]
    if ($null -eq $property) {
        return $null
    }
    return $property.Value
}

function Test-HasProperty {
    param(
        $Object,
        [string]$Name
    )

    if ($null -eq $Object) {
        return $false
    }
    if ($Object -is [System.Collections.IDictionary]) {
        return $Object.Contains($Name)
    }
    return (@($Object.PSObject.Properties.Name) -contains $Name)
}

function ConvertTo-ItemArray {
    param($Value)

    if ($null -eq $Value) {
        return @()
    }
    if ($Value -is [string]) {
        if ($Value.Trim() -eq "") {
            return @()
        }
        return @($Value)
    }
    if ($Value -is [System.Collections.IEnumerable]) {
        return @($Value)
    }
    return @($Value)
}

function Test-FalseValue {
    param($Value)

    return ($Value -eq $false -or [string]$Value -eq "False")
}

function Test-TrueValue {
    param($Value)

    return ($Value -eq $true -or [string]$Value -eq "True")
}

function Test-BoundaryFalse {
    param(
        $Object,
        [string]$Flag
    )

    $boundary = Get-PropertyValue -Object $Object -Name "boundary"
    if ($null -eq $boundary) {
        return $false
    }
    if (-not (Test-HasProperty -Object $boundary -Name $Flag)) {
        return $false
    }
    return (Test-FalseValue -Value (Get-PropertyValue -Object $boundary -Name $Flag))
}

function Add-Failure {
    param([string]$Message)

    $script:Failures += $Message
}

function Add-Check {
    param(
        [string]$Name,
        [bool]$Passed,
        [string]$Message
    )

    $script:Checks += [ordered]@{
        name = $Name
        passed = $Passed
        message = $Message
    }
    if (-not $Passed) {
        Add-Failure -Message $Message
    }
}

function Test-RecordFields {
    param(
        $Record,
        [string[]]$Fields
    )

    foreach ($field in @($Fields)) {
        if (-not (Test-HasProperty -Object $Record -Name $field)) {
            return $false
        }
    }
    return $true
}

function Get-GitStatusLines {
    param([string]$Root)

    $output = & git -C $Root status --short --untracked-files=all
    if ($LASTEXITCODE -ne 0) {
        return @("GIT_STATUS_FAILED")
    }
    return @($output)
}

function Get-StatusPath {
    param([string]$Line)

    if (-not $Line -or $Line.Length -lt 4) {
        return ""
    }
    return ($Line.Substring(3) -replace "\\", "/")
}

function Test-StatusHasForbiddenMutation {
    param([array]$StatusLines)

    foreach ($line in @($StatusLines)) {
        $path = Get-StatusPath -Line ([string]$line)
        if (-not $path) {
            continue
        }
        if ($path -in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "reports/self_development/SELF_MODEL_ACTIVE_MAP.json")) {
            return $true
        }
        if ($path -like "contracts/*") {
            return $true
        }
        if ($path -like "accepted-core/*" -or $path -like "accepted_core/*") {
            return $true
        }
        if ($path -like ".runtime/active_compact_semantic_memory_v1*") {
            return $true
        }
        if ($path -like "operations/autonomous_inner_motor/*" -or $path -like "operations/reasoning/*" -or $path -like "operations/school/*") {
            return $true
        }
        if ($path -match "(?i)passport") {
            return $true
        }
        if ($path -match "(?i)(body_map|capability_map)") {
            return $true
        }
    }
    return $false
}

function Write-ValidatorProof {
    param([string]$Status)

    $proof = [ordered]@{
        schema = "body_self_inspection_circuit_validator_proof_v1"
        status = $Status
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        validator_ref = "validators/validate_body_self_inspection_circuit_v1.ps1"
        circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
        output_refs = $script:OutputRefs
        validator_checks = $script:Checks
        negative_test_results = $script:NegativeResults
        aggregate_counts = $script:AggregateCounts
        selected_next_logic_action = $script:SelectedNextLogicAction
        git_status_before_invoker = @($script:GitStatusBeforeInvoker)
        git_status_after_invoker = @($script:GitStatusAfterInvoker)
        boundary = New-BodyInspectionBoundary
        errors = $script:Failures
    }

    Write-JsonFile -Path $TrackedProofPath -Data $proof
}

$Failures = @()
$Checks = @()
$NegativeResults = @()
$Blocked = $false
$Parsed = @{}
$AggregateCounts = [ordered]@{}
$SelectedNextLogicAction = $null
$OutputRefs = [ordered]@{
    scan_policy_effective = Join-Path $RuntimeRoot "scan_policy_effective.json"
    scan_skipped_surfaces = Join-Path $RuntimeRoot "scan_skipped_surfaces.json"
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    passport_audit = Join-Path $RuntimeRoot "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRoot "signal_readiness_audit.json"
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
    body_pain_register = Join-Path $RuntimeRoot "body_pain_register.json"
    repair_draft_board = Join-Path $RuntimeRoot "repair_draft_board.json"
    next_logic_queue = Join-Path $RuntimeRoot "next_logic_queue.json"
    slice_a_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_A_PROOF.json"
    slice_b_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_B_PROOF.json"
    slice_c_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_C_PROOF.json"
    slice_d_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"
    slice_e_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_E_PROOF.json"
    body_self_inspection_signal = Join-Path $RuntimeRoot "body_self_inspection_signal.json"
    body_self_inspection_parent_packet = Join-Path $RuntimeRoot "body_self_inspection_parent_packet.json"
    circuit_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_CIRCUIT_PROOF.json"
    slice_a_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_A_V1_PROOF.json"
    slice_b_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_B_V1_PROOF.json"
    slice_c_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_C_V1_PROOF.json"
    slice_d_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_D_V1_PROOF.json"
    slice_e_tracked_proof = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json"
    tracked_proof = $TrackedProofPath
}

$GitStatusBeforeInvoker = Get-GitStatusLines -Root $RepoRoot

try {
    if (-not (Test-Path -LiteralPath $InvokerPath)) {
        $Blocked = $true
        throw "Missing invoker: $InvokerPath"
    }
    & $InvokerPath -RepoRoot $RepoRoot -RuntimeRoot $RuntimeRoot | Out-Null
} catch {
    $Blocked = $true
    Add-Failure -Message ("Circuit invoker failed: " + $_.Exception.Message)
}

$GitStatusAfterInvoker = Get-GitStatusLines -Root $RepoRoot

foreach ($name in @($OutputRefs.Keys)) {
    if ($name -eq "tracked_proof") {
        continue
    }
    $path = [string]$OutputRefs[$name]
    try {
        $Parsed[$name] = Read-JsonFile -Path $path
        Add-Check -Name ($name + "_parses") -Passed $true -Message ($name + " exists and parses")
    } catch {
        Add-Check -Name ($name + "_parses") -Passed $false -Message $_.Exception.Message
    }
}

$trackedStatuses = [ordered]@{
    A = "PASS_BODY_SELF_INSPECTION_SLICE_A_V1"
    B = "PASS_BODY_SELF_INSPECTION_SLICE_B_V1"
    C = "PASS_BODY_SELF_INSPECTION_SLICE_C_V1"
    D = "PASS_BODY_SELF_INSPECTION_SLICE_D_V1"
    E = "PASS_BODY_SELF_INSPECTION_SLICE_E_V1"
}
$runtimeStatuses = [ordered]@{
    A = "PASS_BODY_SELF_INSPECTION_SLICE_A_RUNTIME_V1"
    B = "PASS_BODY_SELF_INSPECTION_SLICE_B_RUNTIME_V1"
    C = "PASS_BODY_SELF_INSPECTION_SLICE_C_RUNTIME_V1"
    D = "PASS_BODY_SELF_INSPECTION_SLICE_D_RUNTIME_V1"
    E = "PASS_BODY_SELF_INSPECTION_SLICE_E_RUNTIME_V1"
}

foreach ($slice in @("A", "B", "C", "D", "E")) {
    $trackedName = "slice_" + $slice.ToLowerInvariant() + "_tracked_proof"
    $runtimeName = "slice_" + $slice.ToLowerInvariant() + "_runtime_proof"
    $tracked = $Parsed[$trackedName]
    $runtime = $Parsed[$runtimeName]
    if ($tracked) {
        Add-Check -Name ("slice_" + $slice + "_tracked_status_pass") -Passed ((Get-PropertyValue -Object $tracked -Name "status") -eq $trackedStatuses[$slice]) -Message ("Slice " + $slice + " tracked proof status must be PASS")
    }
    if ($runtime) {
        Add-Check -Name ("slice_" + $slice + "_runtime_status_pass") -Passed ((Get-PropertyValue -Object $runtime -Name "status") -eq $runtimeStatuses[$slice]) -Message ("Slice " + $slice + " runtime proof status must be PASS")
    }
}

$signal = $Parsed["body_self_inspection_signal"]
$parentPacket = $Parsed["body_self_inspection_parent_packet"]
$circuitProof = $Parsed["circuit_runtime_proof"]
$painRegister = $Parsed["body_pain_register"]
$repairDraftBoard = $Parsed["repair_draft_board"]
$nextLogicQueue = $Parsed["next_logic_queue"]

if ($signal) {
    Add-Check -Name "signal_status_pass" -Passed ((Get-PropertyValue -Object $signal -Name "status") -eq "PASS_BODY_SELF_INSPECTION_SIGNAL_V1") -Message "signal status is PASS"
    $signalFields = @("schema", "status", "version", "generated_at", "repo_root", "source_outputs", "proof_refs", "body_health_summary", "pain_summary", "repair_summary", "queue_summary", "top_priority_items", "parent_loop_signal", "integration_boundary", "boundary")
    Add-Check -Name "signal_required_fields" -Passed (Test-RecordFields -Record $signal -Fields $signalFields) -Message "signal includes required fields"

    $integrationBoundary = Get-PropertyValue -Object $signal -Name "integration_boundary"
    $signalNotConnected = $false
    if ($integrationBoundary) {
        $statement = [string](Get-PropertyValue -Object $integrationBoundary -Name "statement")
        $explicitFlag = Test-TrueValue -Value (Get-PropertyValue -Object $integrationBoundary -Name "signal_is_not_nervous_system_connection")
        $signalNotConnected = ($explicitFlag -and $statement -match "signal != nervous system connection")
    }
    Add-Check -Name "signal_not_nervous_system_connection" -Passed $signalNotConnected -Message "integration boundary explicitly says signal is not nervous system connection"
}

if ($parentPacket) {
    Add-Check -Name "parent_packet_status_pass" -Passed ((Get-PropertyValue -Object $parentPacket -Name "status") -eq "PASS_BODY_SELF_INSPECTION_PARENT_PACKET_V1") -Message "parent packet status is PASS"
    $packetFields = @("schema", "status", "version", "generated_at", "packet_type", "produced_by", "source_signal_ref", "recommended_parent_action", "next_safe_operator_action", "execution_allowed", "owner_decision_required", "proof_required_before_execution", "forbidden_now", "boundary")
    Add-Check -Name "parent_packet_required_fields" -Passed (Test-RecordFields -Record $parentPacket -Fields $packetFields) -Message "parent packet includes required fields"
    Add-Check -Name "parent_packet_execution_disallowed" -Passed (Test-FalseValue -Value (Get-PropertyValue -Object $parentPacket -Name "execution_allowed")) -Message "parent packet execution_allowed is false"
}

if ($circuitProof) {
    Add-Check -Name "circuit_runtime_status_pass" -Passed ((Get-PropertyValue -Object $circuitProof -Name "status") -eq "PASS_BODY_SELF_INSPECTION_CIRCUIT_RUNTIME_V1") -Message "circuit runtime proof status is PASS"
    Add-Check -Name "circuit_execution_disallowed" -Passed (Test-FalseValue -Value (Get-PropertyValue -Object $circuitProof -Name "execution_allowed")) -Message "circuit proof execution_allowed is false"
}

$draftExecutionFalse = $true
if ($repairDraftBoard) {
    foreach ($draft in @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $repairDraftBoard -Name "repair_drafts"))) {
        if (-not (Test-FalseValue -Value (Get-PropertyValue -Object $draft -Name "execution_allowed"))) {
            $draftExecutionFalse = $false
        }
    }
}
Add-Check -Name "repair_drafts_not_executed" -Passed $draftExecutionFalse -Message "repair drafts are not executed and execution_allowed is false"

$queueExecutionFalse = $true
if ($nextLogicQueue) {
    foreach ($item in @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $nextLogicQueue -Name "queue_items"))) {
        if (-not (Test-FalseValue -Value (Get-PropertyValue -Object $item -Name "execution_allowed"))) {
            $queueExecutionFalse = $false
        }
    }
    $selected = Get-PropertyValue -Object $nextLogicQueue -Name "selected_next_item"
    if ($selected) {
        $SelectedNextLogicAction = Get-PropertyValue -Object $selected -Name "queue_type"
    }
}
Add-Check -Name "queue_items_not_executed" -Passed $queueExecutionFalse -Message "queue items are not executed and execution_allowed is false"

Add-Check -Name "no_forbidden_tracked_mutation" -Passed (-not (Test-StatusHasForbiddenMutation -StatusLines $GitStatusAfterInvoker)) -Message "no tracked map/passport/contract/active-memory/accepted-core/live-script mutation observed"

$boundaryObjects = @(
    @{ name = "signal"; value = $signal },
    @{ name = "parent_packet"; value = $parentPacket },
    @{ name = "circuit_runtime_proof"; value = $circuitProof }
)
$boundaryFlags = @(
    "repo_mutated",
    "active_memory_mutated",
    "accepted_core_mutated",
    "body_map_mutated",
    "capability_map_mutated",
    "passports_mutated",
    "contracts_mutated",
    "repair_executed",
    "parent_action_executed",
    "mind_logic_mutated",
    "nervous_system_connected",
    "live_process_touched",
    "codex_launched",
    "web_launched",
    "cleanup_performed"
)

foreach ($entry in @($boundaryObjects)) {
    foreach ($flag in @($boundaryFlags)) {
        Add-Check -Name ("boundary_" + $entry["name"] + "_" + $flag) -Passed (Test-BoundaryFalse -Object $entry["value"] -Flag $flag) -Message ($entry["name"] + " boundary flag is false: " + $flag)
    }
}

$painCount = 0
$draftCount = 0
$queueCount = 0
if ($painRegister) {
    $painCount = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $painRegister -Name "pain_records")).Count
}
if ($repairDraftBoard) {
    $draftCount = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $repairDraftBoard -Name "repair_drafts")).Count
}
if ($nextLogicQueue) {
    $queueCount = @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $nextLogicQueue -Name "queue_items")).Count
}

$AggregateCounts = [ordered]@{
    total_pains = $painCount
    total_repair_drafts = $draftCount
    total_queue_items = $queueCount
}

$NegativeResults = @(
    [ordered]@{
        name = "repair_drafts_do_not_execute"
        passed = $draftExecutionFalse
        evidence = "execution_allowed is false on repair_drafts"
    },
    [ordered]@{
        name = "queue_items_do_not_execute"
        passed = $queueExecutionFalse
        evidence = "execution_allowed is false on queue_items"
    },
    [ordered]@{
        name = "parent_packet_does_not_execute_parent_action"
        passed = $(if ($parentPacket) { Test-BoundaryFalse -Object $parentPacket -Flag "parent_action_executed" } else { $false })
        evidence = "parent_packet.boundary.parent_action_executed"
    },
    [ordered]@{
        name = "signal_not_nervous_system_connection"
        passed = $(if ($signal) { Test-BoundaryFalse -Object $signal -Flag "nervous_system_connected" } else { $false })
        evidence = "signal.boundary.nervous_system_connected"
    },
    [ordered]@{
        name = "codex_and_web_not_launched"
        passed = $(if ($circuitProof) { (Test-BoundaryFalse -Object $circuitProof -Flag "codex_launched") -and (Test-BoundaryFalse -Object $circuitProof -Flag "web_launched") } else { $false })
        evidence = "circuit proof boundary"
    }
)

$status = "PASS_BODY_SELF_INSPECTION_CIRCUIT_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_CIRCUIT_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_CIRCUIT_V1"
}

Write-ValidatorProof -Status $status

try {
    [void](Read-JsonFile -Path $TrackedProofPath)
    Add-Check -Name "tracked_proof_parses" -Passed $true -Message "tracked circuit proof exists and parses"
} catch {
    Add-Check -Name "tracked_proof_parses" -Passed $false -Message $_.Exception.Message
}

$status = "PASS_BODY_SELF_INSPECTION_CIRCUIT_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_CIRCUIT_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_CIRCUIT_V1"
}

Write-ValidatorProof -Status $status

if ($Failures.Count -gt 0) {
    Write-Output ("STATUS=" + $status)
    foreach ($failure in @($Failures)) {
        Write-Output ("FAIL=" + $failure)
    }
    exit 1
}

Write-Output ("STATUS=" + $status)
Write-Output ("PROOF=" + $TrackedProofPath)
exit 0
