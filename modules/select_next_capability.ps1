function Select-NextCapability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Roadmap,

        [Parameter(Mandatory = $true)]
        [object]$GenesisState
    )

    $activeCapabilities = @($Roadmap.capabilities | Where-Object { $_.status -eq 'ACTIVE' })
    if ($activeCapabilities.Count -ne 1) {
        throw "Expected exactly one ACTIVE capability, found $($activeCapabilities.Count)."
    }

    $selectedCapability = $activeCapabilities[0]

    if ($selectedCapability.id -ne $GenesisState.current_capability) {
        throw "ACTIVE roadmap capability '$($selectedCapability.id)' does not match state current_capability '$($GenesisState.current_capability)'."
    }

    if ($selectedCapability.phase -ne $GenesisState.current_phase) {
        throw "ACTIVE roadmap phase '$($selectedCapability.phase)' does not match state current_phase '$($GenesisState.current_phase)'."
    }

    return $selectedCapability
}
