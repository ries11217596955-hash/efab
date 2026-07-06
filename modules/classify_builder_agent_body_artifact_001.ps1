param(
  [Parameter(Mandatory=$true)][string]$Path,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

$full = Join-Path (Resolve-Path $RepoRoot).Path $Path
if (-not (Test-Path -LiteralPath $full)) {
  throw "Artifact not found: $Path"
}

$text = Get-Content -LiteralPath $full -Raw -ErrorAction SilentlyContinue
$status = 'UNKNOWN_NEEDS_REVIEW'
$why = 'No stronger PHASE161C classification signal was detected.'
if ($Path -in @('CAPABILITY_ROADMAP.json','GENESIS_STATE.json','TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1')) {
  $status = 'RISK_LOCKED'
  $why = 'Protected source-of-truth or execution file; owner approval required for mutation.'
} elseif ([regex]::IsMatch($text, '(TODO|FIXME|STUB|placeholder|not implemented)', 'IgnoreCase')) {
  $status = 'STUB_OR_PLACEHOLDER'
  $why = 'Placeholder marker detected.'
} elseif ((Get-Item -LiteralPath $full).Length -lt 32) {
  $status = 'EMPTY_OR_NEAR_EMPTY'
  $why = 'File is too small to prove behavior.'
}

[pscustomobject]@{
  artifact_id = ($Path -replace '[^A-Za-z0-9]+','_').Trim('_')
  path = $Path
  primary_status = $status
  why_status = $why
  safe_to_modify = ($status -ne 'RISK_LOCKED')
  owner_approval_required = ($status -eq 'RISK_LOCKED')
}
