function Resolve-SpecializationOverlay {
    param(
        [string]$AgentKind,
        [string]$PackageProfile = ""
    )

    if ([string]::IsNullOrWhiteSpace($AgentKind)) {
        throw "AgentKind is required."
    }

    if ($AgentKind -eq "audit_agent") {
        $OverlayRoot = ".\applied_agents\specialization_profiles\audit_agent_v1\overlay"

        if (-not (Test-Path $OverlayRoot)) {
            throw "Specialization overlay root missing: $OverlayRoot"
        }

        return [pscustomobject]@{
            status = "PASS"
            profile_id = "audit_agent_v1"
            profile_kind = "audit_agent"
            overlay_root = (Resolve-Path $OverlayRoot).Path
            resolution_reason = "Derived spec agent_kind matched audit_agent."
        }
    }

    return [pscustomobject]@{
        status = "NO_MATCH"
        profile_id = "NONE"
        profile_kind = $AgentKind
        overlay_root = ""
        resolution_reason = "No bounded specialization profile registered for this agent_kind."
    }
}
