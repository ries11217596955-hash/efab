[CmdletBinding()]
param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..\..\..")).Path
,
  [string]$RunId = "BUILDER_GENERATED_CANDIDATE_RUNTIME_COMPAT",
  [switch]$InvokedByOrchestrator
)

$ErrorActionPreference = "Stop"
Write-Host "PHASE108_CANDIDATE_PRE_ADMISSION_VALIDATION_PLACEHOLDER"
Write-Host "EXECUTION_ALLOWED=FALSE"

