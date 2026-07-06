$ErrorActionPreference = "Stop"

$Repo = Split-Path $PSScriptRoot -Parent
Set-Location $Repo

$ProofPath = "tests/accepted_atom_retention/CONTROLLED_RUNTIME_MEMORY_DELTA_ISOLATION_TRIAL_V1.json"
$CoreFiles = @(
  "packs/registry.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "reports/self_development/accepted_change_memory_snapshot.json"
)

function Fail {
  param([string]$Reason)
  Write-Host "FAIL=$Reason"
  exit 1
}

if (-not (Test-Path -LiteralPath $ProofPath)) { Fail "PROOF_MISSING" }

try {
  $p = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
} catch {
  Fail "PROOF_JSON_PARSE_FAILED"
}

if ([string]$p.status -ne "PASS") { Fail "PROOF_STATUS_NOT_PASS" }
if ([string]$p.design_mode -notin @("RuntimeDeltaOnly","CompactCore")) { Fail "DESIGN_MODE_UNEXPECTED" }
if ([int]$p.completed_cycles -ne 12) { Fail "COMPLETED_CYCLES_NOT_12" }
if ([int]$p.total_accepted -ne 1200) { Fail "TOTAL_ACCEPTED_NOT_1200" }
if ([int]$p.total_receipts -ne 1200) { Fail "TOTAL_RECEIPTS_NOT_1200" }
if ([int]$p.failed_cycles -ne 0) { Fail "FAILED_CYCLES_NOT_ZERO" }
if ([bool]$p.runtime_ready -ne $false) { Fail "RUNTIME_READY_TRUE" }
if ([bool]$p.heartbeat_written -ne $true) { Fail "HEARTBEAT_MISSING" }
if ([bool]$p.summary_written -ne $true) { Fail "SUMMARY_MISSING" }
if ([bool]$p.material_pruned_all_successful_cycles -ne $true) { Fail "MATERIAL_PRUNING_FALSE" }
if ([bool]$p.work_current_pruned_all_successful_cycles -ne $true) { Fail "WORK_CURRENT_PRUNING_FALSE" }
if ([bool]$p.runtime_delta_written -ne $true) { Fail "RUNTIME_DELTA_WRITTEN_FALSE" }
if (@($p.tracked_core_dirty_files).Count -ne 0) { Fail "PROOF_TRACKED_CORE_DIRTY" }
if ([string]$p.design_mode -eq "CompactCore" -and [int64]$p.core_file_growth_bytes -gt 204800) { Fail "COMPACT_CORE_GROWTH_EXCEEDS_LIMIT" }
if ([string]$p.design_mode -eq "RuntimeDeltaOnly" -and [int64]$p.core_file_growth_bytes -ne 0) { Fail "RUNTIME_DELTA_CORE_GROWTH_NONZERO" }
if ([bool]$p.core_growth_within_limit -ne $true) { Fail "CORE_GROWTH_LIMIT_FALSE" }

$coreStatus = @(git status --short -- $CoreFiles)
if ($coreStatus.Count -ne 0) {
  Write-Host "DIRTY_ACCEPTED_CORE:"
  $coreStatus | ForEach-Object { Write-Host $_ }
  Fail "TRACKED_CORE_FILES_DIRTY_AFTER_TRIAL"
}

foreach ($cycle in @($p.cycle_results)) {
  if ([string]$cycle.accepted_core_mode -ne "RuntimeDeltaOnly") { Fail "CYCLE_ACCEPTED_CORE_MODE_NOT_RUNTIME_DELTA" }
  if ([bool]$cycle.runtime_delta_written -ne $true) { Fail "CYCLE_RUNTIME_DELTA_FALSE" }
  if ([string]::IsNullOrWhiteSpace([string]$cycle.accepted_core_delta_root)) { Fail "CYCLE_DELTA_ROOT_MISSING" }
}

Write-Host "VALIDATION_PASS=CONTROLLED_RUNTIME_MEMORY_DELTA_ISOLATION_V1"
Write-Host "PROOF_PATH=$ProofPath"
Write-Host "DESIGN_MODE=$($p.design_mode)"
Write-Host "TOTAL_ACCEPTED=$($p.total_accepted)"
Write-Host "TOTAL_RECEIPTS=$($p.total_receipts)"
Write-Host "CORE_FILE_GROWTH_BYTES=$($p.core_file_growth_bytes)"
Write-Host "RUNTIME_READY=false"
exit 0
