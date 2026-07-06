$ErrorActionPreference = "Stop"
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

$protected = @(
  "reports/self_development/accepted_change_memory_snapshot.json",
  "reports/self_development/SELF_MODEL_ACTIVE_MAP.json",
  "packs/registry.json"
)
$before=@{}
foreach($p in $protected){ $before[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower() }

$tasks=@(
  [pscustomobject]@{id="owner_authority_real_apply"; text="Owner asks to apply a safe-run result into real active memory; require owner authority and rollback before Real."; expected_domain="owner_authority"},
  [pscustomobject]@{id="codex_preflight_file_write"; text="Codex wants to write files before PREFLIGHT_PASS during a patch task; guard mutation until preflight passes."; expected_domain="codex_boundary"},
  [pscustomobject]@{id="bloat_bulk_candidates"; text="A school run may create bulk candidates and make the repo жирным by committing archives; enforce bloat control."; expected_domain="bloat_control"},
  [pscustomobject]@{id="rollback_checkpoint_required"; text="Before promotion to active memory, require rollback checkpoint and restore command."; expected_domain="rollback_checkpoint"},
  [pscustomobject]@{id="input_x_unclear_file"; text="Unclear X arrives as file or screenshot; restore context before choosing lens."; expected_domain="input_x_restore"},
  [pscustomobject]@{id="behavior_injection_future_task"; text="Promoted atoms should change behavior through active decision injection."; expected_domain="behavior_injection"}
)
$results=@()
foreach($t in $tasks){
    $res = & operations/active_behavior/invoke_active_behavior_task_decision_v1.ps1 -TaskText $t.text -AtomsPerDomain 3 -AsJson | ConvertFrom-Json
    $domainOk = @($res.matched_domains) -contains $t.expected_domain
    $statusOk = ($res.status -eq "PASS" -and $res.behavior_delta_status -eq "PASS")
    $expectedAtoms=@($res.decision_context | Where-Object { $_.domain -eq $t.expected_domain })
    $atomOk = ([int]$res.atom_count -ge 1 -and @($res.atom_ids_used).Count -ge 1 -and $expectedAtoms.Count -ge 1)
    $changedOk = ($res.baseline_decision -ne $res.active_decision)
    $results += [pscustomobject]@{
        id=$t.id
        status= if($domainOk -and $statusOk -and $atomOk -and $changedOk){"PASS"}else{"FAIL"}
        expected_domain=$t.expected_domain
        matched_domains=@($res.matched_domains)
        atom_count=$res.atom_count
        first_atom_id=@($res.atom_ids_used | Select-Object -First 1)
        expected_domain_atom_id=@($expectedAtoms | Select-Object -First 1).atom_id
        behavior_delta_status=$res.behavior_delta_status
        baseline_decision=$res.baseline_decision
        active_decision=$res.active_decision
    }
}
$after=@{}
$protectedChanged=$false
foreach($p in $protected){
  $after[$p]=(Get-FileHash $p -Algorithm SHA256).Hash.ToLower()
  if($after[$p] -ne $before[$p]){ $protectedChanged=$true }
}
$failCount=@($results | Where-Object { $_.status -ne "PASS" }).Count
$status=if($failCount -eq 0 -and -not $protectedChanged){"PASS_ACTIVE_BEHAVIOR_TASK_DECISION_FLOW"}else{"FAIL_ACTIVE_BEHAVIOR_TASK_DECISION_FLOW"}
$report=[pscustomobject]@{
    schema="active_behavior_task_decision_flow_v1"
    status=$status
    runtime_ready=$false
    task_count=$tasks.Count
    pass_count=@($results | Where-Object { $_.status -eq "PASS" }).Count
    fail_count=$failCount
    protected_surfaces_unchanged=(-not $protectedChanged)
    results=@($results)
    boundary="Uses active promoted atoms from active memory pointer in normal task decision flow. Does not mutate active surfaces and does not set runtime_ready true."
}
$jsonPath="operations/reports/ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1.json"
$mdPath="operations/reports/ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1.md"
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $jsonPath), ($report | ConvertTo-Json -Depth 20), $utf8NoBom)
$lines=($results | ForEach-Object { "- $($_.id): $($_.status), domain=$($_.expected_domain), atoms=$($_.atom_count), first=$($_.first_atom_id)" }) -join "`r`n"
$md=@"
# ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1

Статус: $status  
Runtime ready: false

## Смысл

Проверяет не harness-only retrieval, а обычный task decision flow: task text -> matched domain -> active atom retrieval -> decision context injection -> guarded decision.

## Results

$lines

## Boundary

Active promoted atoms used from active memory pointer. Active surfaces are not mutated by decision flow.
"@
[System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $mdPath), $md, $utf8NoBom)
if($status -ne "PASS_ACTIVE_BEHAVIOR_TASK_DECISION_FLOW") { throw $status }
Write-Host "VALIDATION_PASS=ACTIVE_BEHAVIOR_TASK_DECISION_FLOW_V1"
Write-Host "TASK_COUNT=$($tasks.Count)"
Write-Host "PASS_COUNT=$($report.pass_count)"
Write-Host "FAIL_COUNT=$($report.fail_count)"
Write-Host "PROTECTED_SURFACES_UNCHANGED=$($report.protected_surfaces_unchanged)"
Write-Host "RUNTIME_READY=false"