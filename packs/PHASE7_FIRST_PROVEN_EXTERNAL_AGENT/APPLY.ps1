param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) {
    throw "Pack must be invoked by orchestrator."
}

Set-Location $RepoRoot

Write-Host "PACK=PHASE7_FIRST_PROVEN_EXTERNAL_AGENT_V1"

Copy-Item `
    ".\packs\PHASE7_FIRST_PROVEN_EXTERNAL_AGENT\payload\validators\validate_first_proven_external_agent.ps1" `
    ".\validators\validate_first_proven_external_agent.ps1" `
    -Force

& ".\validators\validate_first_proven_external_agent.ps1" `
    -FinalizePhase `
    -RunId $RunId

git add ".\packs\registry.json"
git add ".\packs\PHASE7_FIRST_PROVEN_EXTERNAL_AGENT"
git add ".\validators\validate_first_proven_external_agent.ps1"
git add ".\proofs\FIRST_EXTERNAL_AGENT_PROOF_001.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 7 first proven external agent"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
