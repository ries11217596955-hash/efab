param(
  [string]$RepoRoot,
  [string]$RunId,
  [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Read-JsonFile {
  param([string]$Path)
  return Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json
}

function Write-JsonFile {
  param([string]$Path, [object]$Value)
  $dir = Split-Path -Parent $Path
  if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Force -Path $dir | Out-Null
  }
  $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding UTF8
}

function Assert-RequiredPath {
  param([string]$Path, [string]$Label)
  if (-not (Test-Path -LiteralPath $Path)) {
    throw "$Label missing: $Path"
  }
}

function Get-OneByProperty {
  param(
    [object[]]$Items,
    [string]$PropertyName,
    [string]$ExpectedValue,
    [string]$Label
  )

  $matches = @($Items | Where-Object { $_.$PropertyName -eq $ExpectedValue })
  if ($matches.Count -ne 1) {
    throw "$Label expected one item where $PropertyName = $ExpectedValue, found $($matches.Count)."
  }

  return $matches[0]
}

function Add-UniqueString {
  param(
    [object]$Object,
    [string]$PropertyName,
    [string]$Value
  )

  if (-not $Object.PSObject.Properties.Name.Contains($PropertyName)) {
    Add-Member -InputObject $Object -MemberType NoteProperty -Name $PropertyName -Value @()
  }

  $items = @($Object.$PropertyName)
  if ($items -notcontains $Value) {
    $items += $Value
  }

  $Object.$PropertyName = $items
}

function Convert-GhCreatedAtUtc {
  param(
    [Parameter(Mandatory = $true)]
    [object]$Value
  )

  if ($Value -is [datetime]) {
    return $Value.ToUniversalTime()
  }

  if ($Value -is [datetimeoffset]) {
    return $Value.UtcDateTime
  }

  $parsed = [System.DateTimeOffset]::Parse(
    [string]$Value,
    [System.Globalization.CultureInfo]::InvariantCulture,
    [System.Globalization.DateTimeStyles]::AssumeUniversal -bor [System.Globalization.DateTimeStyles]::AdjustToUniversal
  )

  return $parsed.UtcDateTime
}

function Copy-IfDifferentPath {
  param(
    [Parameter(Mandatory = $true)]
    [string]$SourcePath,

    [Parameter(Mandatory = $true)]
    [string]$DestinationPath
  )

  $resolvedSourcePath = (Resolve-Path -LiteralPath $SourcePath).Path

  if (Test-Path -LiteralPath $DestinationPath) {
    $resolvedDestinationPath = (Resolve-Path -LiteralPath $DestinationPath).Path
    if ([string]::Equals($resolvedSourcePath, $resolvedDestinationPath, [System.StringComparison]::OrdinalIgnoreCase)) {
      Write-Output "SKIP_COPY_SAME_PATH=$resolvedSourcePath"
      return
    }
  }

  Copy-Item -LiteralPath $resolvedSourcePath -Destination $DestinationPath -Force
}

function Invoke-NativeGitCommand {
  param(
    [string]$Label,
    [string[]]$Arguments
  )

  $previousPreference = $ErrorActionPreference
  $output = @()
  $exitCode = $null

  try {
    $ErrorActionPreference = "Continue"
    $output = @(& git @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  foreach ($line in $output) {
    Write-Output ($line.ToString())
  }

  if ($exitCode -ne 0) {
    throw "GIT_${Label}_FAILED_EXIT_CODE=$exitCode"
  }

  Write-Output "GIT_${Label}=PASS"
}

function Invoke-Gh {
  param(
    [string]$Label,
    [string[]]$Arguments,
    [switch]$EchoOutput
  )

  $previousPreference = $ErrorActionPreference
  $output = @()
  $exitCode = $null

  try {
    $ErrorActionPreference = "Continue"
    $output = @(& gh @Arguments 2>&1)
    $exitCode = $LASTEXITCODE
  }
  finally {
    $ErrorActionPreference = $previousPreference
  }

  if ($exitCode -ne 0) {
    throw "GH_${Label}_FAILED_EXIT_CODE=$exitCode`n$($output -join "`n")"
  }

  if ($EchoOutput) {
    foreach ($line in $output) {
      Write-Output ($line.ToString())
    }
  }

  return $output
}

function Set-AgentCatalogEntry {
  param(
    [string]$Status,
    [string]$GithubActionValidation
  )

  $catalogPath = "agent_catalog/AGENT_CATALOG.json"
  if (Test-Path -LiteralPath $catalogPath) {
    $catalog = Read-JsonFile $catalogPath
  }
  else {
    $catalog = [pscustomobject]@{
      catalog_version = "1.0"
      agents = @()
    }
  }

  if (-not $catalog.PSObject.Properties.Name.Contains("agents")) {
    Add-Member -InputObject $catalog -MemberType NoteProperty -Name "agents" -Value @()
  }

  $existing = @($catalog.agents | Where-Object { [string]$_.agent_id -eq $AgentId })
  if ($existing.Count -gt 1) {
    throw "Agent catalog contains duplicate entries for $AgentId."
  }

  $entry = [ordered]@{
    agent_id = $AgentId
    name = $AgentName
    status = $Status
    package_path = $AgentRoot
    local_run_command = "pwsh -NoLogo -NoProfile -File generated_agents/evidence_packager_agent_v1/run.ps1 -InputPath generated_agents/evidence_packager_agent_v1/INPUT_EXAMPLE.json -OutputPath generated_agents/evidence_packager_agent_v1/OUTPUT_EXAMPLE_RUNTIME.json"
    github_workflow = $WorkflowPath
    github_workflow_name = $WorkflowName
    artifact_name = $ArtifactName
    github_action_validation = $GithubActionValidation
    proof_paths = @($ProofPath)
    report_paths = @($ReportPath)
  }

  $catalog.agents = @($catalog.agents | Where-Object { [string]$_.agent_id -ne $AgentId })
  $catalog.agents += [pscustomobject]$entry
  Write-JsonFile -Path $catalogPath -Value $catalog
}

function Write-AgentCatalogMarkdown {
  param([string]$Status)

  $catalogMd = @"
# Evidence Packager Agent v1

## Status

$Status

## Purpose

Evidence Packager Agent v1 accepts a task or incident and a list of evidence items, then creates an evidence package showing available evidence, missing evidence, risk flags, and the next operator action.

## Package

generated_agents/evidence_packager_agent_v1

## Workflow

$WorkflowPath

## Artifact

$ArtifactName
"@

  Set-Content -LiteralPath "agent_catalog/evidence_packager_agent_v1.md" -Value $catalogMd -Encoding UTF8
}

if (-not $InvokedByOrchestrator) {
  throw "Pack must be invoked by orchestrator."
}

if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
  throw "RepoRoot is required."
}

$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
Set-Location $RepoRoot

$CapId = "evidence_packager_agent_closed_loop_trial_v1"
$TaskId = "TASK_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_001"
$AgentId = "evidence_packager_agent_v1"
$AgentName = "Evidence Packager Agent v1"
$WorkflowFile = "run-evidence-packager-agent-v1.yml"
$WorkflowName = "Run Evidence Packager Agent v1"
$WorkflowPath = ".github/workflows/$WorkflowFile"
$ArtifactName = "evidence-packager-agent-v1-output"
$AgentRoot = "generated_agents/evidence_packager_agent_v1"
$RunRoot = "runs/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
$ProofPath = "proofs/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1.json"
$ReportPath = "reports/external_agent_production/EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_REPORT.json"
$ClosedLoopStandardProofPath = "proofs/AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1.json"
$ClosedLoopStandardId = "AGENT_PRODUCTION_CLOSED_LOOP_STANDARD_V1"
$NextRecommendedStep = "generalize_program_to_closed_loop_executor_v1"

$PackRoot = Join-Path $RepoRoot "packs/PHASE77_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
$AgentPayloadRoot = Join-Path $PackRoot "payload/generated_agents/evidence_packager_agent_v1"
$WorkflowPayloadPath = Join-Path $PackRoot "payload/.github/workflows/$WorkflowFile"
$ValidatorPayloadPath = Join-Path $PackRoot "payload/validators/validate_evidence_packager_agent_closed_loop_trial_v1.ps1"
$ValidatorTargetPath = "validators/validate_evidence_packager_agent_closed_loop_trial_v1.ps1"

Write-Output "PHASE77_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL=START"

Assert-RequiredPath $AgentPayloadRoot "agent payload"
Assert-RequiredPath $WorkflowPayloadPath "workflow payload"
Assert-RequiredPath $ValidatorPayloadPath "validator payload"
Assert-RequiredPath $ClosedLoopStandardProofPath "closed loop standard proof"

$standardProof = Read-JsonFile $ClosedLoopStandardProofPath
if ([string]$standardProof.status -ne "PASS") {
  throw "Closed-loop standard proof status must be PASS."
}
if ([string]$standardProof.proof_id -ne $ClosedLoopStandardId) {
  throw "Closed-loop standard proof_id must be $ClosedLoopStandardId."
}

New-Item -ItemType Directory -Force -Path "generated_agents" | Out-Null
New-Item -ItemType Directory -Force -Path ".github/workflows" | Out-Null
New-Item -ItemType Directory -Force -Path "agent_catalog" | Out-Null
New-Item -ItemType Directory -Force -Path "validators" | Out-Null
New-Item -ItemType Directory -Force -Path "proofs" | Out-Null
New-Item -ItemType Directory -Force -Path "reports/external_agent_production" | Out-Null

if (Test-Path -LiteralPath $AgentRoot) {
  Remove-Item -LiteralPath $AgentRoot -Recurse -Force
}
New-Item -ItemType Directory -Force -Path $AgentRoot | Out-Null
Copy-Item -Path (Join-Path $AgentPayloadRoot "*") -Destination $AgentRoot -Recurse -Force
Copy-Item -LiteralPath $WorkflowPayloadPath -Destination $WorkflowPath -Force
Copy-Item -LiteralPath $ValidatorPayloadPath -Destination $ValidatorTargetPath -Force

$agentSpec = Read-JsonFile "$AgentRoot/AGENT_SPEC.json"
if ([string]$agentSpec.agent_id -ne $AgentId) {
  throw "Generated AGENT_SPEC agent_id must be $AgentId."
}

$localOutputPath = "$AgentRoot/OUTPUT_EXAMPLE_RUNTIME.json"
& "$AgentRoot/run.ps1" -InputPath "$AgentRoot/INPUT_EXAMPLE.json" -OutputPath $localOutputPath
$localOutput = Read-JsonFile $localOutputPath
if ([string]$localOutput.validation_status -ne "PASS") {
  throw "Local runtime validation_status must be PASS."
}

Set-AgentCatalogEntry -Status "PENDING_GITHUB_ACCEPTANCE" -GithubActionValidation "PENDING"
Write-AgentCatalogMarkdown -Status "PENDING_GITHUB_ACCEPTANCE"

Invoke-NativeGitCommand -Label "ADD_INTERMEDIATE_GENERATED_AGENT" -Arguments @(
  "add",
  "-f",
  ".\generated_agents\evidence_packager_agent_v1"
)

Invoke-NativeGitCommand -Label "ADD_INTERMEDIATE" -Arguments @(
  "add",
  ".\.github\workflows\run-evidence-packager-agent-v1.yml",
  ".\agent_catalog\AGENT_CATALOG.json",
  ".\agent_catalog\evidence_packager_agent_v1.md",
  ".\validators\validate_evidence_packager_agent_closed_loop_trial_v1.ps1"
)

Invoke-NativeGitCommand -Label "COMMIT_INTERMEDIATE" -Arguments @(
  "commit",
  "-m",
  "Add evidence packager agent workflow v1"
)

Invoke-NativeGitCommand -Label "PUSH_INTERMEDIATE" -Arguments @(
  "push",
  "origin",
  "main"
)

$dispatchStartUtc = (Get-Date).ToUniversalTime().AddSeconds(-10)

Invoke-Gh -Label "WORKFLOW_RUN" -Arguments @(
  "workflow",
  "run",
  $WorkflowFile,
  "--ref",
  "main"
) | Out-Null

$runId = $null
$runUrl = $null
$runConclusion = $null

Write-Output "PHASE77_WAIT_FOR_GITHUB_RUN=START"

for ($i = 0; $i -lt 60; $i++) {
  Start-Sleep -Seconds 10

  $runsJson = Invoke-Gh -Label "RUN_LIST" -Arguments @(
    "run",
    "list",
    "--workflow",
    $WorkflowFile,
    "--branch",
    "main",
    "--json",
    "databaseId,status,conclusion,createdAt,event,url",
    "--limit",
    "10"
  )

  $runs = $runsJson -join "`n" | ConvertFrom-Json
  $candidates = @(
    @($runs) | Where-Object {
      $_.event -eq "workflow_dispatch" -and
      ((Convert-GhCreatedAtUtc $_.createdAt) -ge $dispatchStartUtc)
    } | Sort-Object { Convert-GhCreatedAtUtc $_.createdAt } -Descending
  )

  if ($candidates.Count -eq 0) {
    Write-Output "PHASE77_WAITING_FOR_RUN_RECORD=$i"
    continue
  }

  $run = $candidates[0]
  $runId = [string]$run.databaseId
  $runUrl = [string]$run.url

  Write-Output "PHASE77_RUN_ID=$runId"
  Write-Output "PHASE77_RUN_STATUS=$($run.status)"

  if ([string]$run.status -eq "completed") {
    $runConclusion = [string]$run.conclusion
    break
  }
}

if ([string]::IsNullOrWhiteSpace($runId)) {
  throw "No new GitHub workflow_dispatch run found for $WorkflowFile."
}

if ([string]$runConclusion -ne "success") {
  throw "GitHub run did not finish with success. run_id=$runId conclusion=$runConclusion url=$runUrl"
}

Remove-Item -LiteralPath $RunRoot -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $RunRoot | Out-Null

Invoke-Gh -Label "RUN_DOWNLOAD" -Arguments @(
  "run",
  "download",
  $runId,
  "--name",
  $ArtifactName,
  "--dir",
  $RunRoot
) | Out-Null

$artifactOutputPath = Get-ChildItem -LiteralPath $RunRoot -Recurse -File -Filter "GITHUB_ACTION_OUTPUT.json" | Select-Object -First 1
$artifactSpecPath = Get-ChildItem -LiteralPath $RunRoot -Recurse -File -Filter "AGENT_SPEC.json" | Select-Object -First 1

if ($null -eq $artifactOutputPath) {
  throw "Downloaded artifact missing GITHUB_ACTION_OUTPUT.json"
}

if ($null -eq $artifactSpecPath) {
  throw "Downloaded artifact missing AGENT_SPEC.json"
}

Copy-IfDifferentPath -SourcePath $artifactOutputPath.FullName -DestinationPath (Join-Path $RunRoot "GITHUB_ACTION_OUTPUT.json")
Copy-IfDifferentPath -SourcePath $artifactSpecPath.FullName -DestinationPath (Join-Path $RunRoot "AGENT_SPEC.json")

$artifactOutput = Read-JsonFile "$RunRoot/GITHUB_ACTION_OUTPUT.json"
if ([string]$artifactOutput.validation_status -ne "PASS") {
  throw "Artifact output validation_status must be PASS."
}

$artifactSpec = Read-JsonFile "$RunRoot/AGENT_SPEC.json"
if ([string]$artifactSpec.agent_id -ne $AgentId) {
  throw "Artifact AGENT_SPEC agent_id must be $AgentId."
}

Set-AgentCatalogEntry -Status "ACCEPTED" -GithubActionValidation "PASS"
Write-AgentCatalogMarkdown -Status "ACCEPTED"

$proof = [ordered]@{
  proof_id = "EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
  status = "PASS"
  produced_agent_id = $AgentId
  local_runtime_validation = "PASS"
  github_workflow_file = $WorkflowPath
  github_workflow_name = $WorkflowName
  github_run_id = $runId
  github_run_url = $runUrl
  github_run_conclusion = "success"
  artifact_name = $ArtifactName
  artifact_validation_status = "PASS"
  catalog_status_after = "ACCEPTED"
  active_task_after = "NONE"
  closed_loop_standard_used = $ClosedLoopStandardId
  next_recommended_step = $NextRecommendedStep
}

$report = [ordered]@{
  report_id = "EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_REPORT"
  proof_id = "EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
  status = "PASS"
  produced_agent_id = $AgentId
  produced_agent_name = $AgentName
  purpose = "Create and accept Evidence Packager Agent v1 as the third external agent trial for the closed-loop production standard."
  closed_loop_stages_completed = @(
    "PROGRAM_ADMISSION",
    "AGENT_PACKAGE_BUILD",
    "LOCAL_RUNTIME_VALIDATION",
    "AGENT_CATALOG_REGISTRATION",
    "GITHUB_WORKFLOW_LAUNCH",
    "GITHUB_RUN_DISPATCH",
    "ARTIFACT_DOWNLOAD",
    "ARTIFACT_VALIDATION",
    "ACCEPTANCE_PROOF_REPORT",
    "CLEAN_QUEUE_RETURN"
  )
  github_workflow_file = $WorkflowPath
  github_workflow_name = $WorkflowName
  github_run_id = $runId
  github_run_url = $runUrl
  artifact_name = $ArtifactName
  artifact_checked = "$RunRoot/GITHUB_ACTION_OUTPUT.json"
  acceptance_reason = "Local runtime validation passed, GitHub workflow concluded success, artifact output validation_status was PASS, and catalog status was updated to ACCEPTED."
  next_recommended_step = $NextRecommendedStep
  next_step_reason = "Generalize this closed-loop sequence into a reusable executor."
}

Write-JsonFile -Path $ProofPath -Value $proof
Write-JsonFile -Path $ReportPath -Value $report

$state = Read-JsonFile "GENESIS_STATE.json"
$roadmap = Read-JsonFile "CAPABILITY_ROADMAP.json"
$queue = Read-JsonFile "TASK_QUEUE.json"

$capability = Get-OneByProperty -Items @($roadmap.capabilities) -PropertyName "id" -ExpectedValue $CapId -Label "PHASE77 capability"
$task = Get-OneByProperty -Items @($queue.tasks) -PropertyName "task_id" -ExpectedValue $TaskId -Label "PHASE77 task"

$capability.status = "COMPLETED"
$task.status = "COMPLETED"
$queue.active_task_id = "NONE"
$state.current_phase = "PHASE_77"
$state.current_capability = $CapId
$state.last_run_status = "PASS"
Add-UniqueString -Object $state -PropertyName "completed_capabilities" -Value $CapId

Write-JsonFile -Path "CAPABILITY_ROADMAP.json" -Value $roadmap
Write-JsonFile -Path "TASK_QUEUE.json" -Value $queue
Write-JsonFile -Path "GENESIS_STATE.json" -Value $state

& $ValidatorTargetPath -FinalizePhase -RunId $RunId -RepoRoot $RepoRoot

Invoke-NativeGitCommand -Label "ADD_FINAL" -Arguments @(
  "add",
  ".\CAPABILITY_ROADMAP.json",
  ".\GENESIS_STATE.json",
  ".\TASK_QUEUE.json",
  ".\packs\registry.json",
  ".\tasks\TASK_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_001.json",
  ".\packs\PHASE77_EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1",
  ".\generated_agents\evidence_packager_agent_v1",
  ".\.github\workflows\run-evidence-packager-agent-v1.yml",
  ".\agent_catalog\AGENT_CATALOG.json",
  ".\agent_catalog\evidence_packager_agent_v1.md",
  ".\validators\validate_evidence_packager_agent_closed_loop_trial_v1.ps1",
  ".\proofs\EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1.json",
  ".\reports\external_agent_production\EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_REPORT.json",
  ".\runs\EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1"
)

Invoke-NativeGitCommand -Label "COMMIT_FINAL" -Arguments @(
  "commit",
  "-m",
  "Accept evidence packager agent closed loop trial v1"
)

Invoke-NativeGitCommand -Label "PUSH_FINAL" -Arguments @(
  "push",
  "origin",
  "main"
)

Write-Output "EVIDENCE_PACKAGER_AGENT_CLOSED_LOOP_TRIAL_V1_STATUS=PASS"
Write-Output "EVIDENCE_PACKAGER_AGENT_ACCEPTED=PASS"
Write-Output "PACK_COMMIT_PUSH=PASS"
