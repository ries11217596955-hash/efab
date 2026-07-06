param(
    [Parameter(Mandatory=$true)][string]$TaskText,
    [int]$AtomsPerDomain = 3,
    [switch]$AsJson
)
$ErrorActionPreference = "Stop"
$repoRoot = (git rev-parse --show-toplevel).Trim()
Set-Location $repoRoot

$domainRules = @(
    @{ domain="owner_authority"; keywords=@("owner", "authorization", "authority", "permission", "apply", "real", "approve", "власть", "разреш", "реал") },
    @{ domain="codex_boundary"; keywords=@("codex", "preflight", "file write", "write files", "patch", "mutation", "PREFLIGHT") },
    @{ domain="bloat_control"; keywords=@("bloat", "bulk", "гигабайт", "repo", "archive", "candidate", "runtime", "жир", "мусор") },
    @{ domain="rollback_checkpoint"; keywords=@("rollback", "checkpoint", "restore", "откат", "чекпоинт") },
    @{ domain="input_x_restore"; keywords=@("unclear", "input", "screenshot", "file", "context", "X", "непонят", "скрин") },
    @{ domain="behavior_injection"; keywords=@("behavior", "decision", "use atoms", "inject", "future task", "поведение", "решение", "атом") },
    @{ domain="evidence_and_acceptance"; keywords=@("proof", "evidence", "acceptance", "validator", "доказ", "валидатор", "прием") },
    @{ domain="live_lab_boundary"; keywords=@("lab", "sandbox", "live", "test", "copy", "twin", "лаборатор", "песоч", "копи") },
    @{ domain="retention_and_memory"; keywords=@("memory", "retention", "storage", "remember", "память", "хран") },
    @{ domain="validator_order"; keywords=@("order", "dirty", "git status", "validator order", "порядок", "гряз") }
)

$lower = $TaskText.ToLowerInvariant()
$matchedDomains = New-Object System.Collections.Generic.List[string]
foreach($rule in $domainRules){
    foreach($kw in $rule.keywords){
        if($lower.Contains($kw.ToLowerInvariant())){
            if(-not $matchedDomains.Contains($rule.domain)){ $matchedDomains.Add($rule.domain) | Out-Null }
            break
        }
    }
}
if($matchedDomains.Count -eq 0){ $matchedDomains.Add("behavior_injection") | Out-Null }

$retrieved = New-Object System.Collections.Generic.List[object]
foreach($d in $matchedDomains){
    $json = & operations/active_behavior/invoke_active_behavior_retrieval_v1.ps1 -Domain $d -Limit $AtomsPerDomain
    $res = $json | ConvertFrom-Json
    if($res.status -eq "PASS"){
        foreach($rec in @($res.records)){ $retrieved.Add($rec) | Out-Null }
    }
}
$unique = @{}
$atoms = @($retrieved | Where-Object { -not $unique.ContainsKey($_.atom_id) -and ($unique[$_.atom_id]=$true) })
$baselineDecision = "GENERIC_UNGUARDED_DECISION_NO_ACTIVE_ATOMS"
$activeDecision = if($atoms.Count -gt 0){ "ACTIVE_GUARDED_DECISION_USING_PROMOTED_ATOMS" } else { "GENERIC_UNGUARDED_DECISION_NO_MATCH" }
$status = if($atoms.Count -gt 0 -and $baselineDecision -ne $activeDecision){ "PASS" } else { "NO_ACTIVE_ATOM_MATCH" }
$result = [pscustomobject]@{
    schema="active_behavior_task_decision_v1"
    status=$status
    runtime_ready=$false
    task_text=$TaskText
    matched_domains=@($matchedDomains)
    atom_count=$atoms.Count
    atom_ids_used=@($atoms | ForEach-Object { $_.atom_id })
    baseline_decision=$baselineDecision
    active_decision=$activeDecision
    behavior_delta_status= if($status -eq "PASS") { "PASS" } else { "FAIL" }
    decision_context=@($atoms | ForEach-Object { [pscustomobject]@{atom_id=$_.atom_id; domain=$_.domain; compact_summary=$_.compact_summary; behavior_change=$_.behavior_change; use_proof=$_.use_proof} })
    guardrail="Decision must name promoted atom_ids and use compact active memory pointer; no bulk candidates are loaded into active surfaces."
}
if($AsJson){ $result | ConvertTo-Json -Depth 20 } else { $result }