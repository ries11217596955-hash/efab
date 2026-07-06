param(
    [switch]$FinalizePhase,
    [string]$RunId
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Decode-B64 {
    param([string]$Value)
    return [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($Value))
}

function Normalize-Lf {
    param([string]$Text)
    return ($Text -replace "`r`n", "`n")
}

function Write-LfUtf8 {
    param([string]$Path, [string]$Text)
    $Parent = Split-Path -Parent $Path
    if (-not [string]::IsNullOrWhiteSpace($Parent)) {
        New-Item -ItemType Directory -Force -Path $Parent | Out-Null
    }
    $FullPath = if ([System.IO.Path]::IsPathRooted($Path)) { $Path } else { Join-Path (Get-Location).Path $Path }
    [System.IO.File]::WriteAllText($FullPath, $Text, [System.Text.UTF8Encoding]::new($false))
}

function Replace-B64 {
    param(
        [string]$Path,
        [string]$OldB64,
        [string]$NewB64,
        [string]$Marker
    )
    $Text = Normalize-Lf (Get-Content $Path -Raw)
    $Old = Normalize-Lf (Decode-B64 $OldB64)
    $New = Normalize-Lf (Decode-B64 $NewB64)
    if (-not $Text.Contains($Old)) {
        throw "TEXT_PATCH_ANCHOR_MISSING=$Marker"
    }
    Write-LfUtf8 $Path ($Text.Replace($Old, $New))
}

function Append-Array-B64 {
    param(
        [string]$Path,
        [string]$ElementsB64,
        [string]$Marker
    )
    $Text = Normalize-Lf (Get-Content $Path -Raw)
    $ElementsText = Normalize-Lf (Decode-B64 $ElementsB64)
    $Pattern = '(?s)\n  \]\n\}\s*$'
    if (-not [regex]::IsMatch($Text, $Pattern)) {
        throw "ARRAY_APPEND_ANCHOR_MISSING=$Marker"
    }
    $Replacement = ",`n$ElementsText`n  ]`n}`n"
    Write-LfUtf8 $Path ([regex]::Replace($Text, $Pattern, $Replacement, 1))
}

function Assert-JsonParse {
    param([string]$Path)
    $null = Get-Content $Path -Raw | ConvertFrom-Json
}

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

. ".\modules\invoke_external_agent_build.ps1"

$BuilderWorkflowPath = ".\.github\workflows\agent-builder-self-build.yml"
$ContractPath = ".\contracts\generated_agent_github_action_launch_surface.contract.json"
$SpecPath = ".\specs\github_action_surface_proof\ACTION_READY_AGENT_PROOF_SPEC.json"
$RunRoot = ".\runs\$RunId\PHASE53_ACTION_READY_GENERATED_AGENT_PROOF_V1"
$OutputRoot = ".\generated_agents"

foreach ($Path in @($BuilderWorkflowPath, $ContractPath, $SpecPath)) {
    if (-not (Test-Path $Path)) {
        throw "PHASE 53 required artifact missing: $Path"
    }
}

$Build = Invoke-ExternalAgentBuild `
    -SpecPath $SpecPath `
    -OutputRoot $OutputRoot `
    -RunRoot (Join-Path $RunRoot "target_build")

if ($Build.status -ne "PASS") {
    throw "Action-ready external agent build failed."
}

$PackageRoot = $Build.manifest.package_root
$WorkflowTemplatePath = Join-Path $PackageRoot "deployment\github_actions\run-generated-agent.workflow.yml"

if (-not (Test-Path $WorkflowTemplatePath)) {
    throw "Generated agent GitHub Action launch delivery artifact missing."
}

$WorkflowText = Get-Content $WorkflowTemplatePath -Raw
$WorkflowMarkers = @(
    "workflow_dispatch:",
    "input_path:",
    "output_path:",
    "orchestrator\run.ps1",
    "actions/checkout@v6",
    "actions/upload-artifact@v7"
)
foreach ($Marker in $WorkflowMarkers) {
    if ($WorkflowText -notmatch [regex]::Escape($Marker)) {
        throw "Generated workflow template missing marker: $Marker"
    }
}

if (-not (Test-Path $Build.validation.output_result_path)) {
    throw "Operational RUN validation output missing."
}

$Result = Get-Content $Build.validation.output_result_path -Raw | ConvertFrom-Json
if ($Result.status -ne "PASS") {
    throw "Operational RUN validation result must be PASS."
}
if ($Result.diagnostics.github_action_launch_surface -ne "delivery_artifact_present") {
    throw "Generated agent diagnostics must confirm Action launch delivery artifact."
}

Write-Host "ACTION_READY_BUILD_STATUS=$($Build.status)"
Write-Host "ACTION_READY_PACKAGE_ROOT=$PackageRoot"
Write-Host "ACTION_READY_WORKFLOW_TEMPLATE_EXISTS=True"
Write-Host "ACTION_READY_OPERATIONAL_RESULT_STATUS=$($Result.status)"
Write-Host "ACTION_READY_DIAGNOSTIC_SURFACE=$($Result.diagnostics.github_action_launch_surface)"

$Proof = [ordered]@{
    proof_id = "ACTION_READY_GENERATED_AGENT_PROOF_V1"
    run_id = $RunId
    status = "PASS"
    builder_workflow_path = $BuilderWorkflowPath
    action_launch_contract_path = $ContractPath
    generated_agent_spec_path = $SpecPath
    generated_package_root = $PackageRoot
    generated_workflow_template_path = $WorkflowTemplatePath
    operational_validation_output = $Build.validation.output_result_path
    operational_result_status = $Result.status
    diagnostic_surface = $Result.diagnostics.github_action_launch_surface
    conclusion = "The Builder now exposes its own manual GitHub Actions self-build workflow, and every newly generated external agent package carries a validator-enforced GitHub Actions launch delivery artifact."
}
$Proof | ConvertTo-Json -Depth 20 | Set-Content ".\proofs\ACTION_READY_GENERATED_AGENT_PROOF_V1.json" -Encoding UTF8

if ($FinalizePhase) {
    Replace-B64 ".\CAPABILITY_ROADMAP.json" 'ICAgICAgImlkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTMiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCg==' 'ICAgICAgImlkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTMiLAogICAgICAic3RhdHVzIjogIkNPTVBMRVRFRCIsCg==' "ROADMAP_PHASE53_COMPLETE"
    Replace-B64 ".\GENESIS_STATE.json" 'ICAgICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIKICBdLAo=' 'ICAgICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIsCiAgICAiYWN0aW9uX3JlYWR5X2dlbmVyYXRlZF9hZ2VudF9wcm9vZl92MSIKICBdLAo=' "STATE_APPEND_COMPLETED53"
    Replace-B64 ".\GENESIS_STATE.json" 'ImdpdGh1Yl9hY3Rpb25fZXhlY3V0aW9uX3N1cmZhY2VfcmVhZHkiOiBmYWxzZQ==' 'ImdpdGh1Yl9hY3Rpb25fZXhlY3V0aW9uX3N1cmZhY2VfcmVhZHkiOiB0cnVl' "STATE_SURFACE_READY_TRUE"
    Replace-B64 ".\TASK_QUEUE.json" 'ImFjdGl2ZV90YXNrX2lkIjogIlRBU0tfQUNUSU9OX1JFQURZX0dFTkVSQVRFRF9BR0VOVF9QUk9PRl9WMV8wMDEiLA==' 'ImFjdGl2ZV90YXNrX2lkIjogIk5PTkUiLA==' "QUEUE_NONE"
    Replace-B64 ".\TASK_QUEUE.json" 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19BQ1RJT05fUkVBRFlfR0VORVJBVEVEX0FHRU5UX1BST09GX1YxXzAwMSIsCiAgICAgICJjYXBhYmlsaXR5X2lkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCg==' 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19BQ1RJT05fUkVBRFlfR0VORVJBVEVEX0FHRU5UX1BST09GX1YxXzAwMSIsCiAgICAgICJjYXBhYmlsaXR5X2lkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAic3RhdHVzIjogIkNPTVBMRVRFRCIsCg==' "QUEUE_TASK53_COMPLETE"

    Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
    Assert-JsonParse ".\GENESIS_STATE.json"
    Assert-JsonParse ".\TASK_QUEUE.json"
}

Write-Host "PASS :: action_ready_generated_agent_proof_v1 checks passed. run_id=$RunId"

