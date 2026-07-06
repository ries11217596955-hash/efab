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

$ContractPath = ".\contracts\generated_agent_github_action_launch_surface.contract.json"
$GeneratorPath = ".\modules\new_external_agent_package.ps1"

foreach ($Path in @($ContractPath, $GeneratorPath)) {
    if (-not (Test-Path $Path)) {
        throw "PHASE 52 required artifact missing: $Path"
    }
}

$Contract = Get-Content $ContractPath -Raw | ConvertFrom-Json
if ($Contract.status -ne "ACTIVE") {
    throw "Action launch contract must be ACTIVE."
}
if ($Contract.delivery_artifact_path -ne "deployment/github_actions/run-generated-agent.workflow.yml") {
    throw "Action launch delivery path mismatch."
}

$GeneratorText = Get-Content $GeneratorPath -Raw
$RequiredGeneratorMarkers = @(
    "deployment\github_actions",
    "run-generated-agent.workflow.yml",
    "github_action_launch_delivery_artifact",
    "actions/checkout@v6",
    "actions/upload-artifact@v7"
)
foreach ($Marker in $RequiredGeneratorMarkers) {
    if ($GeneratorText -notmatch [regex]::Escape($Marker)) {
        throw "Generator missing action launch marker: $Marker"
    }
}

$Tokens = $null
$Errors = $null
[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $GeneratorPath), [ref]$Tokens, [ref]$Errors) | Out-Null
if ($Errors.Count -ne 0) {
    $Errors | Format-List *
    throw "Generator parser check failed."
}

Write-Host "ACTION_CONTRACT_STATUS=$($Contract.status)"
Write-Host "ACTION_CONTRACT_DELIVERY_PATH=$($Contract.delivery_artifact_path)"
Write-Host "ACTION_GENERATOR_PATCH_PRESENT=True"
Write-Host "ACTION_GENERATOR_PARSER=PASS"

$Proof = [ordered]@{
    proof_id = "GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1"
    run_id = $RunId
    status = "PASS"
    contract_path = $ContractPath
    generator_path = $GeneratorPath
    delivery_artifact_path = $Contract.delivery_artifact_path
    deployment_target_path = $Contract.deployment_target_path
}
$Proof | ConvertTo-Json -Depth 20 | Set-Content ".\proofs\GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1.json" -Encoding UTF8

if ($FinalizePhase) {
    Replace-B64 ".\CAPABILITY_ROADMAP.json" 'ICAgICAgImlkIjogImdlbmVyYXRlZF9hZ2VudF9hY3Rpb25fbGF1bmNoX2NvbnRyYWN0X3YxIiwKICAgICAgInBoYXNlIjogIlBIQVNFXzUyIiwKICAgICAgInN0YXR1cyI6ICJBQ1RJVkUiLAo=' 'ICAgICAgImlkIjogImdlbmVyYXRlZF9hZ2VudF9hY3Rpb25fbGF1bmNoX2NvbnRyYWN0X3YxIiwKICAgICAgInBoYXNlIjogIlBIQVNFXzUyIiwKICAgICAgInN0YXR1cyI6ICJDT01QTEVURUQiLAo=' "ROADMAP_PHASE52_COMPLETE"
    Replace-B64 ".\CAPABILITY_ROADMAP.json" 'ICAgICAgImlkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTMiLAogICAgICAic3RhdHVzIjogIlBFTkRJTkciLAo=' 'ICAgICAgImlkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAicGhhc2UiOiAiUEhBU0VfNTMiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCg==' "ROADMAP_PHASE53_ACTIVE"
    Replace-B64 ".\GENESIS_STATE.json" 'ImN1cnJlbnRfcGhhc2UiOiAiUEhBU0VfNTIiLA==' 'ImN1cnJlbnRfcGhhc2UiOiAiUEhBU0VfNTMiLA==' "STATE_TO_PHASE53"
    Replace-B64 ".\GENESIS_STATE.json" 'ImN1cnJlbnRfY2FwYWJpbGl0eSI6ICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIs' 'ImN1cnJlbnRfY2FwYWJpbGl0eSI6ICJhY3Rpb25fcmVhZHlfZ2VuZXJhdGVkX2FnZW50X3Byb29mX3YxIiw=' "STATE_TO_CAPABILITY53"
    Replace-B64 ".\GENESIS_STATE.json" 'ICAgICJidWlsZGVyX2dpdGh1Yl9hY3Rpb25fbWFudWFsX3J1bl9zdXJmYWNlX3YxIgogIF0sCg==' 'ICAgICJidWlsZGVyX2dpdGh1Yl9hY3Rpb25fbWFudWFsX3J1bl9zdXJmYWNlX3YxIiwKICAgICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIKICBdLAo=' "STATE_APPEND_COMPLETED52"
    Replace-B64 ".\TASK_QUEUE.json" 'ImFjdGl2ZV90YXNrX2lkIjogIlRBU0tfR0VORVJBVEVEX0FHRU5UX0FDVElPTl9MQVVOQ0hfQ09OVFJBQ1RfVjFfMDAxIiw=' 'ImFjdGl2ZV90YXNrX2lkIjogIlRBU0tfQUNUSU9OX1JFQURZX0dFTkVSQVRFRF9BR0VOVF9QUk9PRl9WMV8wMDEiLA==' "QUEUE_TO_TASK53"
    Replace-B64 ".\TASK_QUEUE.json" 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19HRU5FUkFURURfQUdFTlRfQUNUSU9OX0xBVU5DSF9DT05UUkFDVF9WMV8wMDEiLAogICAgICAiY2FwYWJpbGl0eV9pZCI6ICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIsCiAgICAgICJzdGF0dXMiOiAiQUNUSVZFIiwK' 'ICAgICAgInRhc2tfaWQiOiAiVEFTS19HRU5FUkFURURfQUdFTlRfQUNUSU9OX0xBVU5DSF9DT05UUkFDVF9WMV8wMDEiLAogICAgICAiY2FwYWJpbGl0eV9pZCI6ICJnZW5lcmF0ZWRfYWdlbnRfYWN0aW9uX2xhdW5jaF9jb250cmFjdF92MSIsCiAgICAgICJzdGF0dXMiOiAiQ09NUExFVEVEIiwK' "QUEUE_TASK52_COMPLETE"
    Append-Array-B64 ".\TASK_QUEUE.json" 'ICAgIHsKICAgICAgInRhc2tfaWQiOiAiVEFTS19BQ1RJT05fUkVBRFlfR0VORVJBVEVEX0FHRU5UX1BST09GX1YxXzAwMSIsCiAgICAgICJjYXBhYmlsaXR5X2lkIjogImFjdGlvbl9yZWFkeV9nZW5lcmF0ZWRfYWdlbnRfcHJvb2ZfdjEiLAogICAgICAic3RhdHVzIjogIkFDVElWRSIsCiAgICAgICJvYmplY3RpdmUiOiAiQnVpbGQgb25lIGdlbmVyYXRlZCBhZ2VudCB0aHJvdWdoIHRoZSBmYWN0b3J5IGFuZCBwcm92ZSB0aGUgR2l0SHViIEFjdGlvbnMgbGF1bmNoIGRlbGl2ZXJ5IGFydGlmYWN0IGlzIHByZXNlbnQgYW5kIHZhbGlkYXRvci1lbmZvcmNlZC4iLAogICAgICAiZXhwZWN0ZWRfZ2F0ZSI6ICJBQ1RJT05fUkVBRFlfR0VORVJBVEVEX0FHRU5UX1BST09GX1YxIiwKICAgICAgImJ1aWxkX3Rhc2tfcGF0aCI6ICJ0YXNrcy9UQVNLX0FDVElPTl9SRUFEWV9HRU5FUkFURURfQUdFTlRfUFJPT0ZfVjFfMDAxLmpzb24iCiAgICB9' "QUEUE_APPEND_TASK53"

    Copy-Item ".\packs\PHASE52_GENERATED_AGENT_ACTION_LAUNCH_CONTRACT_V1\payload\tasks\TASK_ACTION_READY_GENERATED_AGENT_PROOF_V1_001.json" ".\tasks\TASK_ACTION_READY_GENERATED_AGENT_PROOF_V1_001.json" -Force

    Assert-JsonParse ".\CAPABILITY_ROADMAP.json"
    Assert-JsonParse ".\GENESIS_STATE.json"
    Assert-JsonParse ".\TASK_QUEUE.json"
}

Write-Host "PASS :: generated_agent_action_launch_contract_v1 checks passed. run_id=$RunId"

