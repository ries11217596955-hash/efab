$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$agents='AGENTS.md'
$task='codex_tasks/CODEX_TASK_REBUILD_BODY_MAP_PRIMARY_EVIDENCE_V1.md'
Assert (Test-Path $agents) 'AGENTS_MISSING'
Assert (Test-Path $task) 'CODEX_TASK_MISSING'
$a=Get-Content $agents -Raw
$t=Get-Content $task -Raw
Assert ($a -match 'Hard Codex context budget gate') 'AGENTS_HARD_BUDGET_GATE_MISSING'
Assert ($a -match 'READ_BUDGET_EXPANSION_REQUIRED') 'AGENTS_READ_BUDGET_BLOCKER_MISSING'
Assert ($a -match 'Codex must not read the whole repo') 'AGENTS_NO_WHOLE_REPO_RULE_MISSING'
Assert ($a -match 'ALLOW_BROAD_REPO_SCAN=true') 'AGENTS_BROAD_SCAN_EXCEPTION_MISSING'
Assert ($t -match 'READY_FOR_CODEX_PREFLIGHT') 'TASK_STATUS_BAD'
Assert ($t -match 'Do not read whole repo') 'TASK_NO_WHOLE_REPO_RULE_MISSING'
Assert ($t -match 'Do not read `self_knowledge/BUILDER_SELF_MODEL.json`') 'TASK_LEGACY_READ_FORBIDDEN_MISSING'
Assert ($t -match 'Do not read `reports/self_development/CURRENT_BODY_CAPABILITY_SNAPSHOT_V1.json` as authority') 'TASK_SNAPSHOT_AUTHORITY_FORBIDDEN_MISSING'
Assert ($t -match 'confirmed_components') 'TASK_CONFIRMED_COMPONENTS_MISSING'
Assert ($t -match 'primary_evidence_candidates') 'TASK_PRIMARY_CANDIDATES_MISSING'
Assert ($t -match 'legacy_unverified_hints') 'TASK_LEGACY_HINTS_MISSING'
Assert ($t -match 'Files changed before PREFLIGHT_PASS: YES/NO') 'TASK_PREFLIGHT_REPORT_MISSING'
Assert ($t -notmatch 'ALLOW_BROAD_REPO_SCAN=true') 'TASK_SHOULD_NOT_ALLOW_BROAD_SCAN'
$proof=[ordered]@{
  schema='codex_context_budget_and_body_map_task_validation_v1'
  status='PASS_CODEX_CONTEXT_BUDGET_AND_BODY_MAP_TASK_V1'
  agents_path=$agents
  codex_task_path=$task
  broad_repo_scan_allowed=$false
  legacy_maps_as_authority_allowed=$false
  codex_task_ready=$true
  next_actor='CODEX'
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/self_development/CODEX_CONTEXT_BUDGET_AND_BODY_MAP_TASK_V1_PROOF.json'
$proof|ConvertTo-Json -Depth 60|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_CODEX_CONTEXT_BUDGET_AND_BODY_MAP_TASK_V1'
Write-Host ('PROOF_PATH='+$proofPath)
