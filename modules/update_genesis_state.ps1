function New-UpdatedGenesisStateForNextCapability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$GenesisState,

        [Parameter(Mandatory = $true)]
        [string]$CompletedCapability,

        [Parameter(Mandatory = $true)]
        [string]$NextPhase,

        [Parameter(Mandatory = $true)]
        [string]$NextCapability
    )

    if (-not ($GenesisState.completed_capabilities -contains $CompletedCapability)) {
        $GenesisState.completed_capabilities += $CompletedCapability
    }

    $GenesisState.current_phase = $NextPhase
    $GenesisState.current_capability = $NextCapability
    $GenesisState.last_run_status = 'PASS'

    return $GenesisState
}
