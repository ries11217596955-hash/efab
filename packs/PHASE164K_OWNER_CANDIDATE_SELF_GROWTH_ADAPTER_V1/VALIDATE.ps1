param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path,
  [ValidateSet("Registered","Completed")]
  [string]$Stage = "Registered"
)

$ErrorActionPreference = "Stop"

$PackId = "PHASE164K_OWNER_CANDIDATE_SELF_GROWTH_ADAPTER_V1"
$TaskId = "PHASE164G_SELF_GROWTH_FROM_OWNER_CANDIDATE_CODEX_ARCHIVE_BOUNDARY_CHECKER_001"

Set-Location -LiteralPath $RepoRoot

$Required = @(
  "TASK_QUEUE.json",
  "packs/registry.json",
  "orchestrator/run.ps1",
  "packs/$PackId/APPLY.ps1",
  "packs/$PackId/VALIDATE.ps1",
  "owner_orders/candidate_inbox/OWNER_CANDIDATE_CODEX_ARCHIVE_BOUNDARY_CHECKER_001.candidate.json"
)

foreach ($Path in $Required) {
  if (-not (Test-Path -LiteralPath $Path)) { throw "MISSING_REQUIRED=$Path" }
}

$ParseErrors = $null
$Tokens = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path "packs/$PackId/APPLY.ps1"), [ref]$Tokens, [ref]$ParseErrors) | Out-Null
if ($ParseErrors.Count -gt 0) { throw "APPLY_PARSE_FAILED" }

$Registry = Get-Content -LiteralPath "packs/registry.json" -Raw | ConvertFrom-Json
$Binding = @($Registry.packs) | Where-Object { [string]$_.pack_id -eq $PackId -and [string]$_.task_id -eq $TaskId } | Select-Object -First 1
if ($null -eq $Binding) { throw "REGISTRY_BINDING_NOT_FOUND" }

if ([string]$Binding.shell -ne "PowerShell") { throw "REGISTRY_SHELL_NOT_POWERSHELL" }
if ([string]$Binding.entry_script -ne "packs/$PackId/APPLY.ps1") { throw "REGISTRY_ENTRY_SCRIPT_MISMATCH" }

if ($Stage -eq "Completed") {
  $ProofPath = "proofs/self_development/$PackId.json"
  if (-not (Test-Path -LiteralPath $ProofPath)) { throw "COMPLETED_PROOF_NOT_FOUND" }

  $Proof = Get-Content -LiteralPath $ProofPath -Raw | ConvertFrom-Json
  if ([string]$Proof.status -ne "PASS") { throw "COMPLETED_PROOF_NOT_PASS" }
  if ([bool]$Proof.atom_accepted) { throw "ATOM_ACCEPTED_TRUE" }
  if ([bool]$Proof.accepted_core_mutation) { throw "ACCEPTED_CORE_MUTATION_TRUE" }
  if ([bool]$Proof.route_lock_mutation) { throw "ROUTE_LOCK_MUTATION_TRUE" }
  if ([bool]$Proof.codex_execution) { throw "CODEX_EXECUTION_TRUE" }
}

Write-Host "PHASE164K_VALIDATE_STATUS=PASS"
Write-Host "PHASE164K_VALIDATE_STAGE=$Stage"
