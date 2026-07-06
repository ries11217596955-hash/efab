param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ObjectValue {
    param(
        [object]$Object,
        [string]$Name
    )

    if ($null -eq $Object) { return $null }
    $Property = $Object.PSObject.Properties[$Name]
    if ($null -eq $Property) { return $null }
    return $Property.Value
}

function Assert-RequiredString {
    param(
        [object]$Object,
        [string]$Name
    )

    $Value = Get-ObjectValue -Object $Object -Name $Name
    if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
        throw "Required field missing or empty: $Name"
    }

    return ([string]$Value).Trim()
}

function Get-ObservedEvidence {
    param([object]$Object)

    $RawEvidence = Get-ObjectValue -Object $Object -Name "observed_evidence"
    if ($null -eq $RawEvidence) {
        throw "Required field missing or empty: observed_evidence"
    }

    $Evidence = @()
    foreach ($Item in @($RawEvidence)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Item)) {
            $Evidence += ([string]$Item).Trim()
        }
    }

    if ($Evidence.Count -eq 0) {
        throw "Required field missing or empty: observed_evidence"
    }

    return $Evidence
}

function Normalize-Urgency {
    param([string]$Urgency)

    $Normalized = $Urgency.Trim().ToLowerInvariant()
    $Allowed = @("low", "medium", "high", "critical")
    if ($Allowed -notcontains $Normalized) {
        throw "urgency must be one of: low, medium, high, critical"
    }

    return $Normalized
}

function Get-Severity {
    param(
        [string]$Urgency,
        [string]$Text
    )

    $LowerText = $Text.ToLowerInvariant()

    if ($Urgency -eq "critical") { return "SEV-1" }
    if ($Urgency -eq "high" -and $LowerText -match "outage|data loss|security breach|production down|customer impact") {
        return "SEV-1"
    }
    if ($Urgency -eq "high") { return "SEV-2" }
    if ($Urgency -eq "medium" -and $LowerText -match "production|payment|release failed|blocked") {
        return "SEV-2"
    }
    if ($Urgency -eq "medium") { return "SEV-3" }

    return "SEV-4"
}

function Get-LikelyArea {
    param(
        [string]$AffectedSystem,
        [string]$Text
    )

    $Combined = "$AffectedSystem $Text".ToLowerInvariant()

    if ($Combined -match "deploy|release|build|pipeline|patch") { return "deployment_or_release" }
    if ($Combined -match "queue|worker|message|timeout") { return "queue_processing" }
    if ($Combined -match "database|sql|schema|migration") { return "data_store" }
    if ($Combined -match "auth|login|token|permission|identity") { return "identity_access" }
    if ($Combined -match "api|endpoint|http|service") { return "service_api" }

    return "operational_triage"
}

function Test-MeaningfulValue {
    param([object]$Value)

    if ($null -eq $Value) { return $false }
    $Items = @($Value)
    foreach ($Item in $Items) {
        if (-not [string]::IsNullOrWhiteSpace([string]$Item)) {
            return $true
        }
    }

    return $false
}

function Get-MissingInformation {
    param([object]$Object)

    $ExpectedOptionalFields = @(
        "impact",
        "first_observed_at",
        "reproduction_steps",
        "owner_or_contact",
        "recent_change_reference"
    )

    $Missing = @()
    foreach ($Field in $ExpectedOptionalFields) {
        if (-not (Test-MeaningfulValue -Value (Get-ObjectValue -Object $Object -Name $Field))) {
            $Missing += $Field
        }
    }

    return $Missing
}

function Get-RecommendedNextStep {
    param(
        [string]$Severity,
        [string]$LikelyArea,
        [string[]]$MissingInformation
    )

    if ($MissingInformation.Count -gt 0) {
        $MissingText = $MissingInformation -join ", "
    }
    else {
        $MissingText = "none"
    }

    if ($Severity -in @("SEV-1", "SEV-2")) {
        return "Open a remediation incident for $LikelyArea, attach the supplied evidence, and request missing information: $MissingText."
    }

    return "Create a tracked remediation ticket for $LikelyArea, attach the supplied evidence, and request missing information: $MissingText."
}

if (-not (Test-Path -LiteralPath $InputPath)) {
    throw "InputPath not found: $InputPath"
}

$Request = Get-Content -LiteralPath $InputPath -Raw | ConvertFrom-Json

$ProblemTitle = Assert-RequiredString -Object $Request -Name "problem_title"
$ProblemDescription = Assert-RequiredString -Object $Request -Name "problem_description"
$AffectedSystem = Assert-RequiredString -Object $Request -Name "affected_system"
$Urgency = Normalize-Urgency -Urgency (Assert-RequiredString -Object $Request -Name "urgency")
$Evidence = Get-ObservedEvidence -Object $Request

$CombinedText = "$ProblemTitle $ProblemDescription $AffectedSystem $($Evidence -join ' ')"
$Severity = Get-Severity -Urgency $Urgency -Text $CombinedText
$LikelyArea = Get-LikelyArea -AffectedSystem $AffectedSystem -Text $CombinedText
$MissingInformation = Get-MissingInformation -Object $Request

$Output = [ordered]@{
    normalized_problem = [ordered]@{
        title = $ProblemTitle
        description = $ProblemDescription
        affected_system = $AffectedSystem
        urgency = $Urgency
        evidence_count = $Evidence.Count
        evidence_summary = @($Evidence | Select-Object -First 3)
    }
    severity = $Severity
    likely_area = $LikelyArea
    missing_information = $MissingInformation
    recommended_next_step = Get-RecommendedNextStep -Severity $Severity -LikelyArea $LikelyArea -MissingInformation $MissingInformation
    operator_note = "Structured locally by remediation_intake_operator_agent_v1; no external APIs were called."
    validation_status = "PASS"
}

$OutputDirectory = Split-Path -Parent $OutputPath
if (-not [string]::IsNullOrWhiteSpace($OutputDirectory) -and -not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
}

$Output | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

Write-Output "REMEDIATION_INTAKE_OPERATOR_STATUS=PASS"
Write-Output "REMEDIATION_INTAKE_OPERATOR_OUTPUT=$OutputPath"

