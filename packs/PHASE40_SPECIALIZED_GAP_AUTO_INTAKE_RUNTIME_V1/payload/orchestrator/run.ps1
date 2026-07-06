param(
    [ValidateSet(
        "SELF_BUILD",
        "BUILD_EXTERNAL_AGENT",
        "BUILD_FROM_RAW_IDEA",
        "BUILD_FROM_RAW_IDEA_SPECIALIZED",
        "GAP_TO_PROFILE_CANDIDATE",
        "VERIFY"
    )]
    [string]$Mode = "VERIFY",

    [string]$RunId = ("SELF_BUILD_" + (Get-Date -Format "yyyyMMdd_HHmmss")),

    [ValidateRange(1, 25)]
    [int]$MaxPacks = 1,

    [string]$SpecPath,

    [string]$OutputRoot,

    [string]$OverlayRoot = "",

    [string]$RawIdeaPath,

    [string]$DerivedSpecPath = "",

    [string]$GapReportPath,

    [string]$CandidateOutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
Set-Location $RepoRoot

Write-Host "AGENT_BUILDER_ORCHESTRATOR"
Write-Host "MODE=$Mode"
Write-Host "RUN_ID=$RunId"

if ($Mode -eq "VERIFY") {
    Write-Host "STATUS=PASS"
    return
}

if ($Mode -eq "GAP_TO_PROFILE_CANDIDATE") {
    if ([string]::IsNullOrWhiteSpace($GapReportPath)) {
        throw "GapReportPath is required."
    }

    . ".\modules\new_specialization_profile_candidate_brief.ps1"
    . ".\modules\new_gap_remediation_intake_report.ps1"

    $ModeRoot = ".\runs\$RunId\GAP_TO_PROFILE_CANDIDATE_MODE_V1"
    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null

    if ([string]::IsNullOrWhiteSpace($CandidateOutputPath)) {
        $CandidateOutputPath = Join-Path $ModeRoot "SPECIALIZATION_PROFILE_CANDIDATE.json"
    }

    $Candidate = New-SpecializationProfileCandidateBrief `
        -RunId $RunId `
        -GapReportPath $GapReportPath `
        -CandidateOutputPath $CandidateOutputPath

    $Intake = New-GapRemediationIntakeReport `
        -RunId $RunId `
        -ModeRoot $ModeRoot `
        -GapReportPath $GapReportPath `
        -CandidatePath $Candidate.candidate_path

    Write-Host "GAP_TO_PROFILE_CANDIDATE_STATUS=$($Candidate.status)"
    Write-Host "GAP_TO_PROFILE_CANDIDATE_PROFILE_ID=$($Candidate.candidate_profile_id)"
    Write-Host "GAP_TO_PROFILE_CANDIDATE_AGENT_KIND=$($Candidate.candidate_agent_kind)"
    Write-Host "GAP_TO_PROFILE_CANDIDATE_PATH=$($Candidate.candidate_path)"
    Write-Host "GAP_TO_PROFILE_CANDIDATE_INTAKE_REPORT_STATUS=$($Intake.status)"
    Write-Host "GAP_TO_PROFILE_CANDIDATE_INTAKE_REPORT_PATH=$($Intake.report_path)"
    return
}

if ($Mode -eq "BUILD_EXTERNAL_AGENT") {
    if ([string]::IsNullOrWhiteSpace($SpecPath)) { throw "SpecPath is required." }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "OutputRoot is required." }

    . ".\modules\invoke_external_agent_build.ps1"

    $RunRoot = ".\runs\$RunId\BUILD_EXTERNAL_AGENT_MODE_V2"

    $Build = Invoke-ExternalAgentBuild `
        -SpecPath $SpecPath `
        -OutputRoot $OutputRoot `
        -RunRoot $RunRoot `
        -OverlayRoot $OverlayRoot

    Write-Host "BUILD_EXTERNAL_AGENT_STATUS=$($Build.status)"
    Write-Host "BUILD_EXTERNAL_AGENT_PACKAGE_ROOT=$($Build.manifest.package_root)"
    Write-Host "BUILD_EXTERNAL_AGENT_OVERLAY_STATUS=$($Build.overlay.status)"
    Write-Host "BUILD_EXTERNAL_AGENT_OVERLAY_FILE_COUNT=$($Build.overlay.applied_file_count)"
    Write-Host "BUILD_EXTERNAL_AGENT_REPORT_PATH=$($Build.report_path)"
    return
}

if ($Mode -eq "BUILD_FROM_RAW_IDEA") {
    if ([string]::IsNullOrWhiteSpace($RawIdeaPath)) { throw "RawIdeaPath is required." }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "OutputRoot is required." }

    . ".\modules\invoke_agent_spec_architect_handoff.ps1"
    . ".\modules\invoke_external_agent_build.ps1"

    $ModeRoot = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_MODE_V1"
    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null

    if ([string]::IsNullOrWhiteSpace($DerivedSpecPath)) {
        $DerivedSpecPath = Join-Path $ModeRoot "DERIVED_AGENT_SPEC.json"
    }

    $Handoff = Invoke-AgentSpecArchitectHandoff `
        -ArchitectSpecPath ".\specs\applied_agents\agent_spec_architect\AGENT_SPEC_ARCHITECT_SPEC.json" `
        -ArchitectOverlayRoot ".\applied_agents\agent_spec_architect\overlay" `
        -RawIdeaRequestPath $RawIdeaPath `
        -GeneratedAgentsRoot ".\generated_agents" `
        -RunRoot (Join-Path $ModeRoot "architect_handoff") `
        -DerivedSpecOutputPath $DerivedSpecPath

    if ($Handoff.status -ne "PASS") {
        throw "Raw idea handoff failed."
    }

    $TargetBuild = Invoke-ExternalAgentBuild `
        -SpecPath $Handoff.derived_spec_path `
        -OutputRoot $OutputRoot `
        -RunRoot (Join-Path $ModeRoot "target_build")

    if ($TargetBuild.status -ne "PASS") {
        throw "Derived external agent build failed."
    }

    $Report = [ordered]@{
        report_id = "BUILD_FROM_RAW_IDEA_MODE_V1"
        run_id = $RunId
        status = "PASS"
        raw_idea_path = $RawIdeaPath
        derived_spec_path = $Handoff.derived_spec_path
        derived_agent_id = $Handoff.derived_agent_id
        architect_handoff = $Handoff
        target_build = [ordered]@{
            status = $TargetBuild.status
            package_root = $TargetBuild.manifest.package_root
            report_path = $TargetBuild.report_path
            validation_output = $TargetBuild.validation.output_result_path
        }
    }

    $ReportPath = Join-Path $ModeRoot "BUILD_FROM_RAW_IDEA_REPORT.json"
    $Report | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    Write-Host "BUILD_FROM_RAW_IDEA_STATUS=$($Report.status)"
    Write-Host "BUILD_FROM_RAW_IDEA_DERIVED_AGENT_ID=$($Report.derived_agent_id)"
    Write-Host "BUILD_FROM_RAW_IDEA_DERIVED_SPEC_PATH=$($Report.derived_spec_path)"
    Write-Host "BUILD_FROM_RAW_IDEA_PACKAGE_ROOT=$($Report.target_build.package_root)"
    Write-Host "BUILD_FROM_RAW_IDEA_REPORT_PATH=$ReportPath"
    return
}

if ($Mode -eq "BUILD_FROM_RAW_IDEA_SPECIALIZED") {
    if ([string]::IsNullOrWhiteSpace($RawIdeaPath)) { throw "RawIdeaPath is required." }
    if ([string]::IsNullOrWhiteSpace($OutputRoot)) { throw "OutputRoot is required." }

    . ".\modules\invoke_agent_spec_architect_handoff.ps1"
    . ".\modules\invoke_external_agent_build.ps1"
    . ".\modules\resolve_specialization_overlay.ps1"
    . ".\modules\new_specialization_gap_report.ps1"
    . ".\modules\new_specialization_profile_candidate_brief.ps1"
    . ".\modules\new_gap_remediation_intake_report.ps1"

    $ModeRoot = ".\runs\$RunId\BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1"
    New-Item -ItemType Directory -Force -Path $ModeRoot | Out-Null

    if ([string]::IsNullOrWhiteSpace($DerivedSpecPath)) {
        $DerivedSpecPath = Join-Path $ModeRoot "DERIVED_AGENT_SPEC.json"
    }

    $Handoff = Invoke-AgentSpecArchitectHandoff `
        -ArchitectSpecPath ".\specs\applied_agents\agent_spec_architect\AGENT_SPEC_ARCHITECT_SPEC.json" `
        -ArchitectOverlayRoot ".\applied_agents\agent_spec_architect\overlay" `
        -RawIdeaRequestPath $RawIdeaPath `
        -GeneratedAgentsRoot ".\generated_agents" `
        -RunRoot (Join-Path $ModeRoot "architect_handoff") `
        -DerivedSpecOutputPath $DerivedSpecPath

    if ($Handoff.status -ne "PASS") {
        throw "Raw idea handoff failed."
    }

    $DerivedSpec = Get-Content $Handoff.derived_spec_path -Raw | ConvertFrom-Json

    $Specialization = Resolve-SpecializationOverlay `
        -AgentKind $DerivedSpec.agent_kind `
        -PackageProfile $DerivedSpec.package_profile

    if ($Specialization.status -eq "NO_MATCH") {
        $Gap = New-SpecializationGapReport `
            -RunId $RunId `
            -ModeRoot $ModeRoot `
            -RawIdeaPath $RawIdeaPath `
            -DerivedSpecPath $Handoff.derived_spec_path `
            -DerivedSpec $DerivedSpec `
            -Specialization $Specialization

        $CandidatePath = Join-Path $ModeRoot "SPECIALIZATION_PROFILE_CANDIDATE.json"

        $Candidate = New-SpecializationProfileCandidateBrief `
            -RunId $RunId `
            -GapReportPath $Gap.report_path `
            -CandidateOutputPath $CandidatePath

        $Intake = New-GapRemediationIntakeReport `
            -RunId $RunId `
            -ModeRoot $ModeRoot `
            -GapReportPath $Gap.report_path `
            -CandidatePath $Candidate.candidate_path

        $Report = [ordered]@{
            report_id = "BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1"
            run_id = $RunId
            status = "SPECIALIZATION_GAP"
            raw_idea_path = $RawIdeaPath
            derived_spec_path = $Handoff.derived_spec_path
            derived_agent_id = $Handoff.derived_agent_id
            architect_handoff = $Handoff
            specialization = [ordered]@{
                status = $Specialization.status
                profile_id = $Specialization.profile_id
                profile_kind = $Specialization.profile_kind
                overlay_root = $Specialization.overlay_root
                resolution_reason = $Specialization.resolution_reason
            }
            gap_report = [ordered]@{
                status = $Gap.status
                report_path = $Gap.report_path
                diagnostic_status = $Gap.diagnostic_status
                missing_agent_kind = $Gap.missing_agent_kind
                requested_package_profile = $Gap.requested_package_profile
            }
            remediation_intake = [ordered]@{
                status = "PASS"
                candidate_status = $Candidate.status
                candidate_path = $Candidate.candidate_path
                candidate_profile_id = $Candidate.candidate_profile_id
                candidate_agent_kind = $Candidate.candidate_agent_kind
                intake_report_status = $Intake.status
                intake_report_path = $Intake.report_path
                required_build_move = $Intake.required_build_move
            }
            target_build = $null
        }

        $ReportPath = Join-Path $ModeRoot "BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
        $Report | ConvertTo-Json -Depth 100 |
            Set-Content $ReportPath -Encoding UTF8

        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_STATUS=$($Report.status)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_DERIVED_AGENT_ID=$($Report.derived_agent_id)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_PROFILE_ID=$($Report.specialization.profile_id)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_GAP_REPORT_PATH=$($Report.gap_report.report_path)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_REMEDIATION_CANDIDATE_PATH=$($Report.remediation_intake.candidate_path)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_REMEDIATION_INTAKE_REPORT_PATH=$($Report.remediation_intake.intake_report_path)"
        Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT_PATH=$ReportPath"
        return
    }
    if ($Specialization.status -ne "PASS") {
        throw "Unexpected specialization resolver status: $($Specialization.status)"
    }

    $TargetBuild = Invoke-ExternalAgentBuild `
        -SpecPath $Handoff.derived_spec_path `
        -OutputRoot $OutputRoot `
        -RunRoot (Join-Path $ModeRoot "target_build") `
        -OverlayRoot $Specialization.overlay_root

    if ($TargetBuild.status -ne "PASS") {
        throw "Specialized target external agent build failed."
    }

    $Report = [ordered]@{
        report_id = "BUILD_FROM_RAW_IDEA_SPECIALIZED_MODE_V1"
        run_id = $RunId
        status = "PASS"
        raw_idea_path = $RawIdeaPath
        derived_spec_path = $Handoff.derived_spec_path
        derived_agent_id = $Handoff.derived_agent_id
        architect_handoff = $Handoff
        specialization = [ordered]@{
            status = $Specialization.status
            profile_id = $Specialization.profile_id
            profile_kind = $Specialization.profile_kind
            overlay_root = $Specialization.overlay_root
            resolution_reason = $Specialization.resolution_reason
        }
        gap_report = $null
        target_build = [ordered]@{
            status = $TargetBuild.status
            package_root = $TargetBuild.manifest.package_root
            report_path = $TargetBuild.report_path
            validation_output = $TargetBuild.validation.output_result_path
            overlay_status = $TargetBuild.overlay.status
            overlay_file_count = $TargetBuild.overlay.applied_file_count
        }
    }

    $ReportPath = Join-Path $ModeRoot "BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT.json"
    $Report | ConvertTo-Json -Depth 100 |
        Set-Content $ReportPath -Encoding UTF8

    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_STATUS=$($Report.status)"
    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_DERIVED_AGENT_ID=$($Report.derived_agent_id)"
    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_PROFILE_ID=$($Report.specialization.profile_id)"
    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_OVERLAY_STATUS=$($Report.target_build.overlay_status)"
    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_PACKAGE_ROOT=$($Report.target_build.package_root)"
    Write-Host "BUILD_FROM_RAW_IDEA_SPECIALIZED_REPORT_PATH=$ReportPath"
    return
}

. ".\modules\read_pack_registry.ps1"
. ".\modules\select_self_build_pack.ps1"
. ".\modules\execute_self_build_pack.ps1"

Write-Host "MAX_PACKS=$MaxPacks"

$Executed = 0

for ($i = 1; $i -le $MaxPacks; $i++) {
    $Queue = Get-Content ".\TASK_QUEUE.json" -Raw | ConvertFrom-Json
    $Registry = Read-SelfBuildPackRegistry -RepoRoot $RepoRoot

    $Pack = $Registry.packs |
        Where-Object { $_.task_id -eq $Queue.active_task_id } |
        Select-Object -First 1

    if ($null -eq $Pack) {
        Write-Host "NO_REGISTERED_PACK_FOR_ACTIVE_TASK=$($Queue.active_task_id)"
        Write-Host "STATUS=PASS_STOPPED_NO_REGISTERED_PACK"
        return
    }

    Write-Host "SELECTED_PACK=$($Pack.pack_id)"
    Write-Host "SELECTED_TASK=$($Pack.task_id)"

    $Result = Invoke-SelfBuildPack `
        -RepoRoot $RepoRoot `
        -Pack $Pack `
        -RunId "$RunId`__PACK_$i"

    Write-Host "PACK_STATUS=$($Result.status)"

    if ($Result.status -ne "PASS") {
        if ($Result.error) {
            Write-Host "PACK_ERROR=$($Result.error)"
        }
        throw "Self-build pack failed."
    }

    $Executed++
}

Write-Host "PACKS_EXECUTED=$Executed"
Write-Host "STATUS=PASS_MAX_PACKS_REACHED"


