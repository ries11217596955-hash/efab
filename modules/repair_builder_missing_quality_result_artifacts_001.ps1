param(
  [string]$RepoRoot = ".",
  [string]$SessionRoot = ""
)

$ErrorActionPreference = "Stop"

. (Join-Path $PSScriptRoot "inspect_builder_quality_decision_index_001.ps1")

$repoRootFull = Resolve-Phase160KQualityPath -Root (Get-Location).Path -Path $RepoRoot
if ([string]::IsNullOrWhiteSpace($SessionRoot)) {
  throw "PHASE160K_REPAIR_SESSION_ROOT_REQUIRED"
}
$sessionRootFull = Resolve-Phase160KQualityPath -Root $repoRootFull -Path $SessionRoot
Get-Phase160KQualityDecisionIndex -RepoRoot $repoRootFull -SessionRootFull $sessionRootFull -RepairMissingQualityResults | ConvertTo-Json -Depth 100
