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
$InvokerPath = Join-Path $RepoRoot "operations\body_self_inspection\invoke_body_self_inspection_slice_e_v1.ps1"
$TrackedProofPath = Join-Path $RepoRoot "tests\self_development\BODY_SELF_INSPECTION_SLICE_E_V1_PROOF.json"

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

    $json = ($Data | ConvertTo-Json -Depth 80) -replace "`r`n", "`n"
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

function Test-FalseValue {
    param($Value)
    return ($Value -eq $false -or [string]$Value -eq "False")
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
        schema = "body_self_inspection_slice_e_validator_proof_v1"
        status = $Status
        generated_at = (Get-Date).ToUniversalTime().ToString("o")
        validator_ref = "validators/validate_body_self_inspection_slice_e_v1.ps1"
        circuit_ref = "BODY_SELF_INSPECTION_CIRCUIT_V1"
        slice = "E"
        output_refs = $script:OutputRefs
        validator_checks = $script:Checks
        negative_test_results = $script:NegativeResults
        git_status_before_invoker = @($script:GitStatusBeforeInvoker)
        git_status_after_invoker = @($script:GitStatusAfterInvoker)
        aggregate_counts = $script:AggregateCounts
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
$OutputRefs = [ordered]@{
    repo_inventory = Join-Path $RuntimeRoot "repo_inventory.json"
    body_map_read = Join-Path $RuntimeRoot "body_map_read.json"
    capability_map_read = Join-Path $RuntimeRoot "capability_map_read.json"
    organ_candidates = Join-Path $RuntimeRoot "organ_candidates.json"
    organ_similarity_index = Join-Path $RuntimeRoot "organ_similarity_index.json"
    passport_audit = Join-Path $RuntimeRoot "passport_audit.json"
    signal_readiness_audit = Join-Path $RuntimeRoot "signal_readiness_audit.json"
    body_reconciliation = Join-Path $RuntimeRoot "body_reconciliation.json"
    slice_d_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_D_PROOF.json"
    body_pain_register = Join-Path $RuntimeRoot "body_pain_register.json"
    repair_draft_board = Join-Path $RuntimeRoot "repair_draft_board.json"
    next_logic_queue = Join-Path $RuntimeRoot "next_logic_queue.json"
    slice_e_runtime_proof = Join-Path $RuntimeRoot "BODY_SELF_INSPECTION_SLICE_E_PROOF.json"
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
    Add-Failure -Message ("Invoker failed: " + $_.Exception.Message)
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

$reconciliation = $Parsed["body_reconciliation"]
$sliceDProof = $Parsed["slice_d_runtime_proof"]
$painRegister = $Parsed["body_pain_register"]
$draftBoard = $Parsed["repair_draft_board"]
$queue = $Parsed["next_logic_queue"]
$runtimeProof = $Parsed["slice_e_runtime_proof"]

if ($sliceDProof) {
    Add-Check -Name "slice_d_runtime_status_pass" -Passed ($sliceDProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_D_RUNTIME_V1") -Message "Slice D runtime proof status must be PASS"
}
if ($runtimeProof) {
    Add-Check -Name "slice_e_runtime_status_pass" -Passed ($runtimeProof.status -eq "PASS_BODY_SELF_INSPECTION_SLICE_E_RUNTIME_V1") -Message "Slice E runtime proof status must be PASS"
}

$discrepancyCount = 0
$painCount = 0
$draftCount = 0
$queueCount = 0
if ($reconciliation) {
    $discrepancyCount = @((Get-PropertyValue -Object $reconciliation -Name "discrepancy_records")).Count
}
if ($painRegister) {
    $painCount = @((Get-PropertyValue -Object $painRegister -Name "pain_records")).Count
}
if ($draftBoard) {
    $draftCount = @((Get-PropertyValue -Object $draftBoard -Name "repair_drafts")).Count
}
if ($queue) {
    $queueCount = @((Get-PropertyValue -Object $queue -Name "queue_items")).Count
}

Add-Check -Name "pain_records_exist_when_discrepancies_exist" -Passed (($discrepancyCount -eq 0) -or ($painCount -gt 0)) -Message "pain records exist when reconciliation discrepancies exist"
Add-Check -Name "repair_drafts_exist_when_pains_exist" -Passed (($painCount -eq 0) -or ($draftCount -gt 0)) -Message "repair drafts exist when pain records exist"
Add-Check -Name "queue_items_exist_when_drafts_exist" -Passed (($draftCount -eq 0) -or ($queueCount -gt 0)) -Message "next logic queue items exist when repair drafts exist"

$painFields = @("pain_id", "source_discrepancy_id", "subject_id", "pain_type", "severity", "evidence_refs", "source_refs", "why_it_matters", "blocked_capability", "recommended_repair_class", "next_cell", "acceptance_boundary", "forbidden_now")
$allowedPainTypes = @("MISSING_PASSPORT_PAIN", "MISSING_CONTRACT_PAIN", "MISSING_VALIDATOR_PAIN", "MISSING_PROOF_PAIN", "MISSING_SIGNAL_PAIN", "POSSIBLE_DUPLICATE_PAIN", "FUNCTIONAL_OVERLAP_PAIN", "BROKEN_REFERENCE_PAIN", "MAP_AMBIGUITY_PAIN", "UNKNOWN_BODY_PAIN")
$painFieldsOk = $true
$painTypesOk = $true
$painRefsOk = $true
if ($painRegister) {
    foreach ($record in @((Get-PropertyValue -Object $painRegister -Name "pain_records"))) {
        if (-not (Test-RecordFields -Record $record -Fields $painFields)) {
            $painFieldsOk = $false
        }
        if ($allowedPainTypes -notcontains [string](Get-PropertyValue -Object $record -Name "pain_type")) {
            $painTypesOk = $false
        }
        if (@(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $record -Name "evidence_refs")).Count -eq 0 -or @(ConvertTo-ItemArray -Value (Get-PropertyValue -Object $record -Name "source_refs")).Count -eq 0) {
            $painRefsOk = $false
        }
    }
}
Add-Check -Name "pain_record_required_fields" -Passed $painFieldsOk -Message "pain records include required fields"
Add-Check -Name "pain_type_values_allowed" -Passed $painTypesOk -Message "pain_type values are allowed"
Add-Check -Name "pain_records_have_refs" -Passed $painRefsOk -Message "pain records include evidence_refs and source_refs"

$draftFields = @("draft_id", "source_pain_id", "subject_id", "repair_class", "proposed_scope", "files_in_scope", "files_forbidden", "validators_required", "proof_required", "risk", "authority_required", "estimated_slice", "execution_allowed", "recommended_operator", "acceptance_boundary", "forbidden_now")
$allowedRepairClasses = @("CREATE_OR_REPAIR_PASSPORT_DRAFT", "CREATE_OR_REPAIR_CONTRACT_DRAFT", "ADD_OR_REPAIR_VALIDATOR_DRAFT", "ADD_OR_REPAIR_PROOF_DRAFT", "ADD_SIGNAL_CONTRACT_DRAFT", "REVIEW_DUPLICATE_DRAFT", "REVIEW_FUNCTIONAL_OVERLAP_DRAFT", "REPAIR_BROKEN_REFERENCE_DRAFT", "MAP_REFRESH_REVIEW_DRAFT", "HUMAN_REVIEW_DRAFT")
$draftFieldsOk = $true
$repairClassesOk = $true
$draftExecutionFalse = $true
if ($draftBoard) {
    foreach ($record in @((Get-PropertyValue -Object $draftBoard -Name "repair_drafts"))) {
        if (-not (Test-RecordFields -Record $record -Fields $draftFields)) {
            $draftFieldsOk = $false
        }
        if ($allowedRepairClasses -notcontains [string](Get-PropertyValue -Object $record -Name "repair_class")) {
            $repairClassesOk = $false
        }
        if (-not (Test-FalseValue -Value (Get-PropertyValue -Object $record -Name "execution_allowed"))) {
            $draftExecutionFalse = $false
        }
    }
}
Add-Check -Name "repair_draft_required_fields" -Passed $draftFieldsOk -Message "repair draft records include required fields"
Add-Check -Name "repair_class_values_allowed" -Passed $repairClassesOk -Message "repair_class values are allowed"
Add-Check -Name "repair_draft_execution_disallowed" -Passed $draftExecutionFalse -Message "execution_allowed is false on all repair drafts"

$queueFields = @("queue_id", "source_draft_id", "subject_id", "priority", "queue_type", "reason", "proposed_next_slice", "dependencies", "validators_required", "proof_required", "execution_allowed", "owner_decision_required", "recommended_operator", "forbidden_now")
$allowedQueueTypes = @("OPERATOR_REVIEW", "CODEX_TASK_CANDIDATE", "VALIDATOR_REPAIR_CANDIDATE", "PASSPORT_REPAIR_CANDIDATE", "SIGNAL_REPAIR_CANDIDATE", "MAP_REVIEW_CANDIDATE", "DUPLICATE_REVIEW_CANDIDATE", "HUMAN_DECISION_REQUIRED")
$queueFieldsOk = $true
$queueTypesOk = $true
$queueExecutionFalse = $true
if ($queue) {
    foreach ($record in @((Get-PropertyValue -Object $queue -Name "queue_items"))) {
        if (-not (Test-RecordFields -Record $record -Fields $queueFields)) {
            $queueFieldsOk = $false
        }
        if ($allowedQueueTypes -notcontains [string](Get-PropertyValue -Object $record -Name "queue_type")) {
            $queueTypesOk = $false
        }
        if (-not (Test-FalseValue -Value (Get-PropertyValue -Object $record -Name "execution_allowed"))) {
            $queueExecutionFalse = $false
        }
    }
}
Add-Check -Name "next_logic_queue_required_fields" -Passed $queueFieldsOk -Message "next logic queue items include required fields"
Add-Check -Name "queue_type_values_allowed" -Passed $queueTypesOk -Message "queue_type values are allowed"
Add-Check -Name "queue_execution_disallowed" -Passed $queueExecutionFalse -Message "execution_allowed is false on all queue items"

Add-Check -Name "no_tracked_map_passport_contract_mutation" -Passed (-not (Test-StatusHasForbiddenMutation -StatusLines $GitStatusAfterInvoker)) -Message "no tracked map/passport/contract/active-memory/accepted-core/live-script mutation observed"

$boundaryObjects = @(
    @{ name = "body_pain_register"; value = $painRegister },
    @{ name = "repair_draft_board"; value = $draftBoard },
    @{ name = "next_logic_queue"; value = $queue },
    @{ name = "slice_e_runtime_proof"; value = $runtimeProof }
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

$NegativeResults = @(
    [ordered]@{
        name = "repair_drafts_do_not_execute"
        passed = $draftExecutionFalse
        evidence = "execution_allowed on all repair drafts"
    },
    [ordered]@{
        name = "queue_items_do_not_execute"
        passed = $queueExecutionFalse
        evidence = "execution_allowed on all queue items"
    },
    [ordered]@{
        name = "no_repair_execution_boundary"
        passed = $(if ($runtimeProof) { Test-BoundaryFalse -Object $runtimeProof -Flag "repair_executed" } else { $false })
        evidence = "slice_e_runtime_proof.boundary.repair_executed"
    },
    [ordered]@{
        name = "codex_not_launched_boundary"
        passed = $(if ($runtimeProof) { Test-BoundaryFalse -Object $runtimeProof -Flag "codex_launched" } else { $false })
        evidence = "slice_e_runtime_proof.boundary.codex_launched"
    },
    [ordered]@{
        name = "web_not_launched_boundary"
        passed = $(if ($runtimeProof) { Test-BoundaryFalse -Object $runtimeProof -Flag "web_launched" } else { $false })
        evidence = "slice_e_runtime_proof.boundary.web_launched"
    }
)

$AggregateCounts = [ordered]@{
    source_discrepancy_records = $discrepancyCount
    pain_records = $painCount
    repair_drafts = $draftCount
    queue_items = $queueCount
}

$status = "PASS_BODY_SELF_INSPECTION_SLICE_E_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_E_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_E_V1"
}

Write-ValidatorProof -Status $status

try {
    [void](Read-JsonFile -Path $TrackedProofPath)
    Add-Check -Name "tracked_proof_parses" -Passed $true -Message "tracked Slice E proof exists and parses"
} catch {
    Add-Check -Name "tracked_proof_parses" -Passed $false -Message $_.Exception.Message
}

$status = "PASS_BODY_SELF_INSPECTION_SLICE_E_V1"
if ($Failures.Count -gt 0) {
    $status = "FAIL_BODY_SELF_INSPECTION_SLICE_E_V1"
}
if ($Blocked) {
    $status = "BLOCKED_BODY_SELF_INSPECTION_SLICE_E_V1"
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
