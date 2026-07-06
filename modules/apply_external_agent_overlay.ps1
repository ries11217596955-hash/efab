function Apply-ExternalAgentOverlay {
    param(
        [string]$GeneratedAgentRoot,
        [string]$OverlayRoot
    )

    if (-not (Test-Path $GeneratedAgentRoot)) {
        throw "Generated agent root missing: $GeneratedAgentRoot"
    }

    if (-not (Test-Path $OverlayRoot)) {
        throw "Overlay root missing: $OverlayRoot"
    }

    $ResolvedOverlayRoot = (Resolve-Path $OverlayRoot).Path
    $OverlayFiles = Get-ChildItem -Path $ResolvedOverlayRoot -Recurse -File

    foreach ($File in $OverlayFiles) {
        $Relative = $File.FullName.Substring($ResolvedOverlayRoot.Length).TrimStart('\')
        $Target = Join-Path $GeneratedAgentRoot $Relative
        $TargetDir = Split-Path $Target -Parent

        if (-not (Test-Path $TargetDir)) {
            New-Item -ItemType Directory -Force -Path $TargetDir | Out-Null
        }

        Copy-Item $File.FullName $Target -Force
    }

    return [pscustomobject]@{
        status = "PASS"
        applied_file_count = @($OverlayFiles).Count
        overlay_root = $ResolvedOverlayRoot
        generated_agent_root = $GeneratedAgentRoot
    }
}
