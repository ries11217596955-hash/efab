$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$BlockerJsonPath = "contracts/controlled_runtime/CONTROLLED_RUNTIME_MEMORY_BLOAT_BLOCKER_1100_V1.json"
$ExpectedAcceptedCoreFiles = @(
  "packs/registry.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "reports/self_development/accepted_change_memory_snapshot.json"
)

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $BlockerJsonPath)) { Fail "BLOCKER_JSON_MISSING" }

try {
  $blocker = Get-Content -LiteralPath $BlockerJsonPath -Raw | ConvertFrom-Json
} catch {
  Fail "BLOCKER_JSON_PARSE_FAILED"
}

if ([string]$blocker.status -ne "CONTROLLED_RUNTIME_MEMORY_BLOAT_BLOCKED") { Fail "STATUS_UNEXPECTED" }
if ([string]$blocker.source_trial -ne "DETACHED_30000_CONTROLLED_RUNTIME") { Fail "SOURCE_TRIAL_UNEXPECTED" }
if ([int]$blocker.completed_cycles -ne 11) { Fail "COMPLETED_CYCLES_NOT_11" }
if ([int]$blocker.batch_size -ne 100) { Fail "BATCH_SIZE_NOT_100" }
if ([int]$blocker.total_accepted -ne 1100) { Fail "TOTAL_ACCEPTED_NOT_1100" }
if ([int]$blocker.total_receipts -ne 1100) { Fail "TOTAL_RECEIPTS_NOT_1100" }
if ([int]$blocker.failed_cycles -ne 0) { Fail "FAILED_CYCLES_NOT_ZERO" }
if ([string]$blocker.stop_reason -ne "UNEXPECTED_TRACKED_CHANGE") { Fail "STOP_REASON_UNEXPECTED" }
if ([string]$blocker.dirty_json_parse -ne "PASS") { Fail "DIRTY_JSON_PARSE_NOT_PASS" }
if ([int]$blocker.diff_insertions -lt 187030) { Fail "DIFF_INSERTIONS_TOO_LOW" }
if ([int]$blocker.diff_deletions -ne 24) { Fail "DIFF_DELETIONS_UNEXPECTED" }
if ([string]$blocker.size_assessment -ne "LARGE") { Fail "SIZE_ASSESSMENT_NOT_LARGE" }
if ([string]$blocker.decision -ne "DO_NOT_ACCEPT_MEMORY_DELTA") { Fail "DECISION_UNEXPECTED" }
if ([bool]$blocker.rollback_required -ne $true) { Fail "ROLLBACK_REQUIRED_FALSE" }
if ([bool]$blocker.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([string]::IsNullOrWhiteSpace([string]$blocker.next_required)) { Fail "NEXT_REQUIRED_MISSING" }

$dirtyFiles = @($blocker.dirty_files | ForEach-Object { [string]$_ })
foreach ($file in $ExpectedAcceptedCoreFiles) {
  if ($file -notin $dirtyFiles) { Fail "DIRTY_FILE_MISSING=$file" }
  try {
    Get-Content -LiteralPath $file -Raw | ConvertFrom-Json | Out-Null
  } catch {
    Fail "ACCEPTED_CORE_JSON_PARSE_FAILED=$file"
  }
}

$acceptedCoreStatus = @(git status --short -- $ExpectedAcceptedCoreFiles)
if ($acceptedCoreStatus.Count -ne 0) {
  Write-Host "ACCEPTED_CORE_DIRTY:"
  $acceptedCoreStatus | ForEach-Object { Write-Host $_ }
  Fail "ACCEPTED_CORE_FILES_STILL_DIRTY"
}

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_MEMORY_BLOAT_BLOCKER_1100_V1"
Write-Host "BLOCKER_JSON=$BlockerJsonPath"
Write-Host "RUNTIME_READY=false"
exit 0
