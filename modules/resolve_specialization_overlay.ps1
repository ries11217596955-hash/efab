function Resolve-SpecializationOverlay {
    param(
        [string]$AgentKind,
        [string]$PackageProfile = ""
    )

    if ([string]::IsNullOrWhiteSpace($AgentKind)) {
        throw "AgentKind is required."
    }

    $RegistryPath = ".\applied_agents\specialization_profiles\SPECIALIZATION_PROFILE_REGISTRY.json"

    if (-not (Test-Path $RegistryPath)) {
        throw "Specialization profile registry missing: $RegistryPath"
    }

    $Registry = Get-Content $RegistryPath -Raw | ConvertFrom-Json

    $Match = $Registry.profiles |
        Where-Object {
            $_.status -eq "ACTIVE" -and
            $_.agent_kind -eq $AgentKind -and
            (
                [string]::IsNullOrWhiteSpace($PackageProfile) -or
                $_.package_profile -eq $PackageProfile
            )
        } |
        Select-Object -First 1

    if ($null -eq $Match) {
        return [pscustomobject]@{
            status = "NO_MATCH"
            profile_id = "NONE"
            profile_kind = $AgentKind
            overlay_root = ""
            resolution_reason = "No active specialization profile matched derived agent_kind/package_profile."
        }
    }

    if (-not (Test-Path $Match.overlay_root)) {
        throw "Resolved specialization overlay root missing: $($Match.overlay_root)"
    }

    return [pscustomobject]@{
        status = "PASS"
        profile_id = $Match.profile_id
        profile_kind = $Match.agent_kind
        overlay_root = (Resolve-Path $Match.overlay_root).Path
        resolution_reason = "Registry matched active specialization profile."
    }
}
