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

$WorkflowPath = ".\.github\workflows\agent-builder-self-build.yml"
if (-not (Test-Path $WorkflowPath)) { throw "Builder GitHub Actions workflow missing." }

$WorkflowText = Get-Content $WorkflowPath -Raw
$RequiredMarkers = @(
    "workflow_dispatch:",
    "run_id:",
    "max_packs:",
    "actions/checkout@v6",
    "actions/upload-artifact@v7",
    "orchestrator\run.ps1",
    "-Mode SELF_BUILD"
)
foreach ($Marker in $RequiredMarkers) {
    if ($WorkflowText -notmatch [regex]::Escape($Marker)) {
        throw "Builder workflow missing marker: $Marker"
    }
}

Write-Host "BUILDER_ACTION_WORKFLOW_EXISTS=True"
Write-Host "BUILDER_ACTION_WORKFLOW_DISPATCH=True"
Write-Host "BUILDER_ACTION_SELF_BUILD_ENTRY=True"
Write-Host "BUILDER_ACTION_ARTIFACT_UPLOAD=True"

$Proof = [ordered]@{
    proof_id = "BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1"
    run_id = $RunId
    status = "PASS"
    workflow_path = $WorkflowPath
    trigger = "workflow_dispatch"
    workflow_name = "Agent Builder Self-Build"
    self_build_entrypoint = "orchestrator/run.ps1"
    checkout_action = "actions/checkout@v6"
    artifact_upload = "actions/upload-artifact@v7"
}
$Proof | ConvertTo-Json -Depth 20 | Set-Content ".\proofs\BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1.json" -Encoding UTF8

if ($FinalizePhase) {
    Replace-B64 ".\CAPABILITY_ROADMAP.json" 'ICAgICAgImlkIjogImJ1aWxkZXJfZ2l0aHViX2FjdGlvbl9tYW51YWxfcnVuX3N1cmZhY2VfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTEiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCg==' 'ICAgICAgImlkIjogImJ1aWxkZXJfZ2l0aHViX2FjdGlvbl9tYW51YWxfcnVuX3N1cmZhY2VfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTEiLAogICAgICAic3RhdHVzIjogIkNPTVBMRVRFRCIsCg==' "ROADMAP_PHASE51_COMPLETE"
    Replace-B64 ".\CAPABILITY_ROADMAP.json" 'ICAgICAgImlkIjogImdlbmVyYXRlZF9hZ2VudF9hY3Rpb25fbGF1bmNoX2NvbnRyYWN0X3YxIiwKICAgICAgInBoYXNlIjogIlBIQVNFXzUyIiwKICAgICAgInN0YXR1cyI6ICJQRU5ESU5HIiwK' 'ICAgICAgImlkIjogImdlbmVyYXRlZF9hZ2VudF9hY3Rpb25fbGF1bmNoX2NvbnRyYWN0X3YxIiwKICAgICAgInBoYXNlIjogIlBIQVNFXzUyIiwKICAgICAgInN0YXR1cyI6ICJBQ1RJVkUiLAo=' "ROADMAP_PHASE52_ACTIVE"
    Replace-B64 ".\GENESIS_STATE.json" 'ImN1cnJlbnRfcGhhc2UiOiAiUEhBU0VfNTEiLA==' 'ImN1cnJlbnRfcGhhc2UiOiAiUEhBU0VfNTIiLA==' "STATE_TO_PHASE52"
    Replace-B64 ".\GENESIS_STATE.json" 'ImN1cnJlbnRfY2FwYWJpbGl0eSI6ICJidWlsZGVyX2dpdGh1Yl9hY3Rpb25fbWFudWFsX3J1bl9zdXJmYWNlX3YxIiw=' 'ImN1cnJlbnRfY2FwYWJpbGl0eSI6ICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIs' "STATE_TO_CAPABILITY52"
    Replace-B64 ".\GENESIS_STATE.json" 'ICAgICJvbmVfcnVuX3JlbWVkaWF0aW9uX3NlZWRfcHJvZ3JhbV9zeW50aGVzaXNfcHJvb2ZfdjEiCiAgXSwK' 'ICAgICJvbmVfcnVuX3JlbWVkaWF0aW9uX3NlZWRfcHJvZ3JhbV9zeW50aGVzaXNfcHJvb2ZfdjEiLAogICAgImJ1aWxkZXJfZ2l0aHViX2FjdGlvbl9tYW51YWxfcnVuX3N1cmZhY2VfdjEiCiAgXSwK' "STATE_APPEND_COMPLETED51"
    Replace-B64 ".\TASK_QUEUE.json" 'ImFjdGl2ZV90YXNrX2lkIjogIlRBU0tfQlVJTERFUl9HSVRIVUJfQUNUSU9OX01BTlVBTF9SVU5fU1VSRkFDRV9WMV8wMDEiLA==' 'ImFjdGl2ZV90YXNrX2lkIjogIlRBU0tfR0VORVJBVEVEX0FHRU5UX0FDVElPTl9MQVVOQ0hfQ09OVFJBQ1RfVjFfMDAxIiw=' "QUEUE_TO_TASK52"
    Replace-B64 ".\TASK_QUEUE.json" 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19CVUlMREVSX0dJVEhVQl9BQ1RJT05fTUFOVUFMX1JVTl9TVVJGQUNFX1YxXzAwMSIsCiAgICAgICJjYXBhYmlsaXR5X2lkIjogImJ1aWxkZXJfZ2l0aHViX2FjdGlvbl9tYW51YWxfcnVuX3N1cmZhY2VfdjEiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCg==' 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19CVUlMREVSX0dJVEhVQl9BQ1RJT05fTUFOVUFMX1JVTl9TVVJGQUNFX1YxXzAwMSIsCiAgICAgICJjYXBhYmlsaXR5X2lkIjogImJ1aWxkZXJfZ2l0aHViX2FjdGlvbl9tYW51YWxfcnVuX3N1cmZhY2VfdjEiLAogICAgICAic3RhdHVzIjogIkNPTVBMRVRFRCIsCg==' "QUEUE_TASK51_COMPLETE"
    Append-Array-B64 ".\TASK_QUEUE.json" 'ICAgIHsKICAgICAgInRhc2tfaWQiOiAiVEFTS19HRU5FUkFURURfQUdFTlRfQUNUSU9OX0xBVU5DSF9DT05UUkFDVF9WMV8wMDEiLAogICAgICAiY2FwYWJpbGl0eV9pZCI6ICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIsCiAgICAgICJzdGF0dXMiOiAiQUNUSVZFIiwKICAgICAgIm9iamVjdGl2ZSI6ICJVcGdyYWRlIGdlbmVyYXRlZCBleHRlcm5hbCBhZ2VudCBwYWNrYWdlcyBzbyB0aGV5IGluY2x1ZGUgYSBHaXRIdWIgQWN0aW9ucyBsYXVuY2ggZGVsaXZlcnkgYXJ0aWZhY3QgYW5kIHZhbGlkYXRvciBjb3ZlcmFnZS4iLAogICAgICAiZXhwZWN0ZWRfZ2F0ZSI6ICJHRU5FUkFURURfQUdFTlRfQUNUSU9OX0xBVU5DSF9DT05UUkFDVF9WMV9SRUFEWSIsCiAgICAgICJidWlsZF90YXNrX3BhdGgiOiAidGFza3MvVEFTS19HRU5FUkFURURfQUdFTlRfQUNUSU9OX0xBVU5DSF9DT05UUkFDVF9WMV8wMDEuanNvbiIKICAgIH0=' "QUEUE_APPEND_TASK52"

    Copy-Item ".\packs\PHASE51_BUILDER_GITHUB_ACTION_MANUAL_RUN_SURFACE_V1\payload\tasks\TASK_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1_001.json" ".\tasks\TASK_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1_001.json" -Force

    Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
    Assert-JsonParse ".\GENESIS_STATE.json"
    Assert-JsonParse ".\TASK_QUEUE.json"
}

Write-Host "PASS :: builder_github_action_manual_run_surface_v1 checks passed. run_id=$RunId"

