param(
    [string]$RepoRoot,
    [string]$RunId,
    [switch]$InvokedByOrchestrator
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not $InvokedByOrchestrator) { throw "Pack must be invoked by orchestrator." }
Set-Location $RepoRoot

Write-Host "PACK=PHASE20_IDEA_TO_AGENT_FACTORY_PROOF_V1"

Copy-Item ".\packs\PHASE20_IDEA_TO_AGENT_FACTORY_PROOF_V1\payload\specs\factory_proof\RAW_IDEA_FACTORY_PROOF.json" ".\specs\idea_to_agent_proof\RAW_IDEA_FACTORY_PROOF.json" -Force
Copy-Item ".\packs\PHASE20_IDEA_TO_AGENT_FACTORY_PROOF_V1\payload\validators\validate_idea_to_agent_factory_proof_v1.ps1" ".\validators\validate_idea_to_agent_factory_proof_v1.ps1" -Force

& ".\validators\validate_idea_to_agent_factory_proof_v1.ps1" -FinalizePhase -RunId $RunId

git add ".\specs\idea_to_agent_proof\RAW_IDEA_FACTORY_PROOF.json"
git add ".\validators\validate_idea_to_agent_factory_proof_v1.ps1"
git add ".\proofs\IDEA_TO_AGENT_FACTORY_PROOF_V1.json"
git add ".\CAPABILITY_ROADMAP.json"
git add ".\GENESIS_STATE.json"
git add ".\TASK_QUEUE.json"

git commit -m "Self-build PHASE 20 idea-to-agent factory proof v1"
git push origin main

Write-Host "PACK_COMMIT_PUSH=PASS"
