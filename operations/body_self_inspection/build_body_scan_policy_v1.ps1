param(
    [string]$RepoRoot,
    [string]$RuntimeRoot
)

$ErrorActionPreference = "Stop"

if (-not $RepoRoot -or $RepoRoot.Trim() -eq "") {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot "..\..")).Path
} else {
    $RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
}

if (-not $RuntimeRoot -or $RuntimeRoot.Trim() -eq "") {
    $RuntimeRoot = Join-Path $RepoRoot ".runtime\body_self_inspection_v1"
}

function New-BodyScanBoundary {
    return @{
        repo_mutated = $false
        active_memory_mutated = $false
        accepted_core_mutated = $false
        body_map_mutated = $false
        capability_map_mutated = $false
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

    $json = ($Data | ConvertTo-Json -Depth 40) -replace "`r`n", "`n"; $json = $json.TrimEnd() + "`n"; [System.IO.File]::WriteAllText($Path, $json, (New-Object System.Text.UTF8Encoding($false)))
}

if (-not (Test-Path -LiteralPath $RuntimeRoot)) {
    New-Item -ItemType Directory -Path $RuntimeRoot -Force | Out-Null
}

$generatedAt = (Get-Date).ToUniversalTime().ToString("o")
$policyVersion = "body_scan_policy_v1_slice_a_2026-07-16"

$policy = @{
    schema = "body_scan_policy_v1"
    status = "PASS_BODY_SCAN_POLICY_V1"
    scan_policy_version = $policyVersion
    generated_at = $generatedAt
    repo_root = $RepoRoot
    denied_dirs = @(
        ".git",
        "node_modules",
        ".venv",
        "env",
        ".env",
        "__pycache__",
        ".pytest_cache",
        ".mypy_cache",
        "dist",
        "build",
        "cache",
        "tmp",
        "temp",
        "large archives",
        "large_archives",
        "generated streaming chunks",
        "generated_streaming_chunks",
        "old raw school run bodies",
        "old_raw_school_run_bodies",
        "stale raw runtime chunks",
        "stale_raw_runtime_chunks",
        "browser_cache_exports",
        ".runtime",
        "runtime_sessions",
        "raw_shards",
        "proofs",
        "reports",
        ".agents",
        ".codex",
        "zz_MUSORKA_DO_NOT_READ_BY_CODEX"
    )
    denied_file_patterns = @(
        "*.zip",
        "*.7z",
        "*.tar",
        "*.tar.gz",
        "*.tgz",
        "*.gz",
        "*.rar",
        "*.bin",
        "*.blob",
        "*.dll",
        "*.exe",
        "*.jsonl",
        "*streaming_chunk*",
        "*generated_streaming*",
        "*raw_school_run*",
        "*raw_runtime_chunk*",
        "*runtime_chunk*",
        "*stdout*dump*",
        "*stderr*dump*"
    )
    allowed_content_roles = @(
        "MAP_FILE",
        "CAPABILITY_MAP_FILE",
        "ORGAN_REGISTRY_FILE",
        "ORGAN_PASSPORT_FILE",
        "ORGAN_CONTRACT_FILE",
        "AUTHORITY_PASSPORT_FILE",
        "VALIDATOR_FILE_HEADER",
        "PROOF_JSON_SUMMARY",
        "RUNTIME_SUMMARY",
        "REPAIR_DRAFT_BOARD",
        "BODY_PAIN_REGISTER",
        "GPT_HANDOFF_POINTER",
        "PLAN_FILE"
    )
    max_content_read_bytes = 262144
    runtime_read_policy = @{
        mode = "SELECTED_SUMMARIES_ONLY"
        statement = "read manifests/latest summaries/selected proof refs only; do not bulk-read raw runtime chunks"
        allowed_reads = @(
            "latest summary json",
            "latest proof json selected by manifest",
            "compact run report",
            "current body_self_inspection_v1 outputs",
            "active draft board",
            "active pain register"
        )
        forbidden_reads = @(
            "full raw streaming chunks",
            "old run body dumps",
            "bulk logs",
            "temporary generated candidates",
            "large file blobs",
            "raw runtime chunks"
        )
    }
    protected_surfaces = @(
        ".runtime/active_compact_semantic_memory_v1",
        "accepted-core surfaces",
        "D2B/accepted-core pipeline surfaces",
        "body map tracked files",
        "capability map tracked files",
        "route locks",
        "registry files",
        "validators",
        "organ contracts",
        "passports",
        "runtime runners",
        "launch scripts",
        ".git",
        "credentials/secrets/env files"
    )
    git_command_allowlist = @(
        "git status",
        "git rev-parse",
        "git rev-list",
        "git log"
    )
    git_command_denylist = @(
        "git add",
        "git commit",
        "git push",
        "git clean",
        "git checkout",
        "git reset"
    )
    stale_after = @{
        policy = "24h"
        active_runtime_references = "1h"
        immediate_stale_if_git_head_changes = $true
    }
    boundary = New-BodyScanBoundary
}

$policyPath = Join-Path $RuntimeRoot "scan_policy_effective.json"
Write-JsonFile -Path $policyPath -Data $policy

Write-Output $policyPath
