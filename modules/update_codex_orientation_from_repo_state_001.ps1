param(
    [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path,
    [int]$RecentProofCount = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-GitValue {
    param(
        [string]$Root,
        [string[]]$Arguments,
        [switch]$Optional
    )

    $output = @(& git -C $Root @Arguments 2>$null)
    if ($LASTEXITCODE -ne 0) {
        if ($Optional) {
            return $null
        }
        throw "git $($Arguments -join ' ') failed."
    }

    return (($output -join "`n").Trim())
}

function Write-Utf8File {
    param(
        [string]$Path,
        [string]$Content
    )

    $parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $parent)) {
        New-Item -ItemType Directory -Force -Path $parent | Out-Null
    }
    Set-Content -LiteralPath $Path -Value $Content -Encoding UTF8
}

$root = (Resolve-Path $RepoRoot).Path
$requiredIdentityFiles = @(
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)

$missingIdentityFiles = @(
    $requiredIdentityFiles |
        Where-Object { -not (Test-Path -LiteralPath (Join-Path $root $_)) }
)
if ($missingIdentityFiles.Count -gt 0) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO missing: $($missingIdentityFiles -join ', ')"
}

$gitRoot = Get-GitValue -Root $root -Arguments @("rev-parse", "--show-toplevel")
if ([string]::IsNullOrWhiteSpace($gitRoot) -or
    -not [string]::Equals(
        (Resolve-Path $gitRoot).Path,
        $root,
        [System.StringComparison]::OrdinalIgnoreCase
    )) {
    throw "STOP=WRONG_AGENT_BUILDER_REPO"
}

$controlFiles = @(
    "AGENTS.md",
    "README.md",
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)
$controlContent = @{}
foreach ($relativePath in $controlFiles) {
    $fullPath = Join-Path $root $relativePath
    if (-not (Test-Path -LiteralPath $fullPath)) {
        throw "Required lightweight control file is missing: $relativePath"
    }

    $content = Get-Content -LiteralPath $fullPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        throw "Required lightweight control file is empty: $relativePath"
    }
    $controlContent[$relativePath] = $content

    if ($relativePath.EndsWith(".json", [System.StringComparison]::OrdinalIgnoreCase)) {
        $null = $content | ConvertFrom-Json
    }
}

$branch = Get-GitValue -Root $root -Arguments @("branch", "--show-current")
$head = Get-GitValue -Root $root -Arguments @("rev-parse", "HEAD")
$originRef = "origin/phase110-idempotent-autonomy-trial-runtime"
$origin = Get-GitValue -Root $root -Arguments @("rev-parse", "--verify", $originRef) -Optional
$gitStatus = Get-GitValue -Root $root -Arguments @("status", "--porcelain")
$gitStatusClean = [string]::IsNullOrWhiteSpace($gitStatus)
$generatorWorktreeStatus = if ($gitStatusClean) { "CLEAN" } else { "DIRTY" }
$headEqualsOrigin = (-not [string]::IsNullOrWhiteSpace($origin)) -and ($head -eq $origin)
$lastOrientationRefreshCommit = Get-GitValue -Root $root -Arguments @(
    "log",
    "-1",
    "--format=%H",
    "--",
    "docs/codex/CODEX_CURRENT_STATE_THIN.json",
    "docs/codex/CODEX_REPO_MAP.md",
    "docs/codex/CODEX_EVIDENCE_INDEX.md"
) -Optional
if ([string]::IsNullOrWhiteSpace($lastOrientationRefreshCommit)) {
    $lastOrientationRefreshCommit = $null
}

$activeRouteLock = "route_locks/AGENT_BUILDER_NEXT_15_STEPS_LOCK_V2.md"
$activeRouteLockFull = Join-Path $root $activeRouteLock
if (-not (Test-Path -LiteralPath $activeRouteLockFull)) {
    throw "Active route lock is missing: $activeRouteLock"
}
$null = Get-Content -LiteralPath $activeRouteLockFull -Raw

$phase165oPromotionProof = "proofs/self_development/PHASE165O_GUARDED_PROMOTION_APPLY_FOR_REUSABLE_SELF_BUILD_ORGAN_V1.json"
$phase165oCloseProof = "proofs/self_development/PHASE165O_POST_PROMOTION_STATE_VERIFY_AND_CLOSE_V1.json"
$phase165pBudgetProof = "proofs/self_development/PHASE165P_CODEX_CONTEXT_BUDGET_AGENTS_UPDATE_V1.json"
$phase165pFreshnessRepairProof = "proofs/self_development/PHASE165P_CODEX_ORIENTATION_FRESHNESS_MODEL_REPAIR_V1.json"
$namedProofPaths = @(
    $phase165oPromotionProof,
    $phase165oCloseProof,
    $phase165pBudgetProof,
    $phase165pFreshnessRepairProof
)

$namedProofs = @{}
foreach ($relativePath in $namedProofPaths) {
    $fullPath = Join-Path $root $relativePath
    if (Test-Path -LiteralPath $fullPath) {
        $namedProofs[$relativePath] = Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json
    }
}

$nextRequiredAction = $null
if ($namedProofs.ContainsKey($phase165oCloseProof) -and
    $namedProofs[$phase165oCloseProof].PSObject.Properties.Name -contains "next_required_action") {
    $nextRequiredAction = [string]$namedProofs[$phase165oCloseProof].next_required_action
}

$agentsNextActionMatch = [regex]::Match(
    $controlContent["AGENTS.md"],
    "(?m)^next_required_action\s*=\s*(?<value>\S+)\s*$"
)
if ($agentsNextActionMatch.Success) {
    $nextRequiredAction = $agentsNextActionMatch.Groups["value"].Value
}

$proofRoot = Join-Path $root "proofs/self_development"
$recentProofs = @()
if (Test-Path -LiteralPath $proofRoot) {
    $proofFiles = @(
        Get-ChildItem -LiteralPath $proofRoot -File -Filter "*.json" |
            Sort-Object -Property LastWriteTimeUtc -Descending |
            Select-Object -First $RecentProofCount
    )

    foreach ($file in $proofFiles) {
        $relativePath = "proofs/self_development/$($file.Name)"
        $proofData = $null
        $parseStatus = "PARSED"
        try {
            $proofData = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
        }
        catch {
            $parseStatus = "PARSE_FAILED"
        }

        $recentProofs += [pscustomobject][ordered]@{
            path = $relativePath
            file_last_write_utc = $file.LastWriteTimeUtc.ToString("o")
            created_utc = if ($null -ne $proofData -and $proofData.PSObject.Properties.Name -contains "created_utc") {
                if ($proofData.created_utc -is [DateTime]) {
                    $proofData.created_utc.ToUniversalTime().ToString("o")
                }
                else {
                    [string]$proofData.created_utc
                }
            }
            else {
                $null
            }
            phase = if ($null -ne $proofData -and $proofData.PSObject.Properties.Name -contains "phase") {
                [string]$proofData.phase
            }
            else {
                [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            }
            status = if ($null -ne $proofData -and $proofData.PSObject.Properties.Name -contains "status") {
                [string]$proofData.status
            }
            else {
                $null
            }
            parse_status = $parseStatus
        }
    }
}

$readFirst = @(
    "AGENTS.md",
    "docs/codex/CODEX_CURRENT_STATE_THIN.json",
    "docs/codex/CODEX_REPO_MAP.md",
    "docs/codex/CODEX_EVIDENCE_INDEX.md",
    "README.md",
    $activeRouteLock,
    "CAPABILITY_ROADMAP.json",
    "GENESIS_STATE.json",
    "TASK_QUEUE.json",
    "packs/registry.json",
    "orchestrator/run.ps1"
)
$skipRules = @(
    "reports/**",
    "proofs/**",
    "self_build_programs/**/canonical_trials/**",
    "self_build_programs/**/dry_runs/**",
    "self_build_programs/**/promotions/**",
    "runtime_sessions/**",
    "zz_MUSORKA_DO_NOT_READ_BY_CODEX/**"
)
$protectedFiles = @(
    "TASK_QUEUE.json",
    "GENESIS_STATE.json",
    "CAPABILITY_ROADMAP.json",
    "packs/registry.json",
    $activeRouteLock,
    "orchestrator/run.ps1"
)
$generatedFiles = @(
    "docs/codex/CODEX_REPO_MAP.md",
    "docs/codex/CODEX_EVIDENCE_INDEX.md",
    "docs/codex/CODEX_CURRENT_STATE_THIN.json"
)
$manualRefreshRequiredWhen = @(
    "active route changes",
    "protected state changes",
    "registry/roadmap/self-model changes",
    "proof index changes",
    "before starting a major Codex task"
)

$repoMapLines = @(
    "# Codex Repository Map",
    "",
    "Generated UTC: $([DateTime]::UtcNow.ToString('o'))",
    "",
    "## Current Git State",
    "",
    "- Branch: ``$branch``",
    "- Generated from HEAD: ``$head``",
    "- Origin ref: ``$originRef``",
    "- Generated from origin: ``$(if ($origin) { $origin } else { 'UNAVAILABLE' })``",
    "- Generated HEAD equals origin: ``$($headEqualsOrigin.ToString().ToLowerInvariant())``",
    "- Generator worktree status: ``$generatorWorktreeStatus``",
    "- Last orientation refresh commit: ``$(if ($lastOrientationRefreshCommit) { $lastOrientationRefreshCommit } else { 'NOT_DETECTED' })``",
    "- Active route lock: ``$activeRouteLock``",
    "",
    "## Freshness Semantics",
    "",
    "The orientation model is ``generated_from_repo_state_not_self_referential``. It is fresh when generated from current HEAD, or when generated from the parent of the latest commit and that latest commit is an accepted Codex orientation refresh or repair.",
    "",
    "Manual refresh is required when:"
)
$repoMapLines += $manualRefreshRequiredWhen | ForEach-Object { "- $_" }
$repoMapLines += @(
    "",
    "## Read First",
    ""
)
$repoMapLines += $readFirst | ForEach-Object { "- ``$_``" }
$repoMapLines += @(
    "",
    "## Do Not Read By Default",
    "",
    "These zones require an active task, Owner instruction, route requirement, or exact validator reference."
)
$repoMapLines += $skipRules | ForEach-Object { "- ``$_``" }
$repoMapLines += @(
    "",
    "## Protected Files",
    "",
    "Do not mutate these files for Codex orientation refresh work."
)
$repoMapLines += $protectedFiles | ForEach-Object { "- ``$_``" }
$repoMapLines += @(
    "",
    "## Typical Task Inspection",
    "",
    "- Orientation or planning: read the thin state, this map, the evidence index, AGENTS.md, and the active route lock.",
    "- Module implementation: inspect only the named module and its directly related contracts or callers.",
    "- Validation work: inspect only the named validator, generated outputs, and exact evidence paths.",
    "- State or queue work: inspect the protected state files only when the task explicitly authorizes mutation.",
    "- Runtime work: inspect ``orchestrator/run.ps1`` and only the modules reached by the requested mode or phase.",
    "",
    "## Exact-Path Evidence Rule",
    "",
    "Do not read ``reports/**`` or ``proofs/**`` recursively. Read only an exact proof or report path named by the route lock, proof chain, Owner, task, or validator.",
    ""
)

$evidenceLines = @(
    "# Codex Evidence Index",
    "",
    "Generated UTC: $([DateTime]::UtcNow.ToString('o'))",
    "",
    "> Warning: do not read ``reports/**`` or ``proofs/**`` recursively. Use exact paths only.",
    "",
    "## Current Post-PHASE165O Evidence",
    "",
    "- Promotion apply: ``$phase165oPromotionProof``",
    "- Post-promotion close: ``$phase165oCloseProof``",
    "- PHASE165P Codex context budget update: ``$phase165pBudgetProof``",
    "- PHASE165P orientation freshness repair: ``$phase165pFreshnessRepairProof``",
    "",
    "## Current Promoted Capability",
    "",
    "- Organ: ``reusable_owner_material_self_build_organ_v1``",
    "- Capability: ``owner_material_dynamic_self_build_loop``",
    "- Next required action: ``$(if ($nextRequiredAction) { $nextRequiredAction } else { 'NOT_FOUND' })``",
    "",
    "## Latest Proof Files",
    ""
)
if ($recentProofs.Count -eq 0) {
    $evidenceLines += "- No proof JSON files found."
}
else {
    foreach ($proof in $recentProofs) {
        $date = if ($proof.created_utc) { $proof.created_utc } else { $proof.file_last_write_utc }
        $status = if ($proof.status) { $proof.status } else { "UNKNOWN" }
        $evidenceLines += "- ``$($proof.path)`` | date ``$date`` | status ``$status`` | phase ``$($proof.phase)``"
    }
}
$evidenceLines += @(
    "",
    "## Exact-Path Evidence Rule",
    "",
    "Open only the exact evidence file required for the active task. Directory-wide proof or report reads are outside the default orientation policy.",
    ""
)

$state = [ordered]@{
    schema_version = "1.1"
    generated_utc = [DateTime]::UtcNow.ToString("o")
    branch = $branch
    generated_from_head = $head
    generated_from_origin = $origin
    generator_worktree_status_at_generation = $generatorWorktreeStatus
    orientation_freshness_model = "generated_from_repo_state_not_self_referential"
    orientation_self_commit_tolerance = $true
    manual_refresh_required_when = $manualRefreshRequiredWhen
    last_orientation_refresh_commit = $lastOrientationRefreshCommit
    head = $head
    origin = $origin
    head_equals_origin = [bool]$headEqualsOrigin
    git_status_clean = [bool]$gitStatusClean
    active_route_lock = $activeRouteLock
    next_required_action = $nextRequiredAction
    current_promoted_organ = "reusable_owner_material_self_build_organ_v1"
    current_capability = "owner_material_dynamic_self_build_loop"
    codex_skip_rules = $skipRules
    read_first = $readFirst
    generated_files = $generatedFiles
}

Write-Utf8File -Path (Join-Path $root "docs/codex/CODEX_REPO_MAP.md") -Content ($repoMapLines -join "`n")
Write-Utf8File -Path (Join-Path $root "docs/codex/CODEX_EVIDENCE_INDEX.md") -Content ($evidenceLines -join "`n")
Write-Utf8File -Path (Join-Path $root "docs/codex/CODEX_CURRENT_STATE_THIN.json") -Content ($state | ConvertTo-Json -Depth 20)

Write-Host "CODEX_ORIENTATION_GENERATOR=PASS"
Write-Host "BRANCH=$branch"
Write-Host "GENERATED_FROM_HEAD=$head"
Write-Host "GENERATED_FROM_ORIGIN=$(if ($origin) { $origin } else { 'UNAVAILABLE' })"
Write-Host "GENERATOR_WORKTREE_STATUS=$generatorWorktreeStatus"
Write-Host "LAST_ORIENTATION_REFRESH_COMMIT=$(if ($lastOrientationRefreshCommit) { $lastOrientationRefreshCommit } else { 'NOT_DETECTED' })"
Write-Host "ACTIVE_ROUTE_LOCK=$activeRouteLock"
Write-Host "RECENT_PROOF_COUNT=$($recentProofs.Count)"
Write-Host "GENERATED_FILES=$($generatedFiles -join ',')"

[pscustomobject]$state
