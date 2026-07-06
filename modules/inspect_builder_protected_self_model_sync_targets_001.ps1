param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$targets = @(
  [pscustomobject]@{ path = 'GENESIS_STATE.json'; kind = 'json'; proposed_role = 'derived_self_model_memory_reference' },
  [pscustomobject]@{ path = 'CAPABILITY_ROADMAP.json'; kind = 'json'; proposed_role = 'self_map_refresh_capability_evidence' },
  [pscustomobject]@{ path = 'TASK_QUEUE.json'; kind = 'json'; proposed_role = 'owner_review_task_candidate' },
  [pscustomobject]@{ path = 'packs/registry.json'; kind = 'json'; proposed_role = 'no_pack_change_recommended' },
  [pscustomobject]@{ path = 'orchestrator/run.ps1'; kind = 'powershell'; proposed_role = 'no_orchestrator_change_recommended' }
)

$items = foreach ($target in $targets) {
  $full = Join-Path $root $target.path
  if (-not (Test-Path -LiteralPath $full)) {
    throw "Protected target missing: $($target.path)"
  }
  $item = Get-Item -LiteralPath $full
  $hash = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
  $topKeys = @()
  $parseStatus = 'NOT_JSON'
  if ($target.kind -eq 'json') {
    $json = Get-Content -LiteralPath $full -Raw | ConvertFrom-Json
    $topKeys = @($json.PSObject.Properties.Name)
    $parseStatus = 'PASS'
  }
  [pscustomobject][ordered]@{
    target_file = $target.path
    target_kind = $target.kind
    current_size_bytes = $item.Length
    current_sha256 = $hash
    json_parse_status = $parseStatus
    top_level_keys = $topKeys
    proposed_role = $target.proposed_role
    read_only_in_phase161f = $true
  }
}

[pscustomobject][ordered]@{
  inspection_id = 'PHASE161F_PROTECTED_SELF_MODEL_SYNC_TARGETS_V1'
  protected_files_read = @($targets.path)
  protected_files_modified_directly = $false
  targets = @($items)
  inspected_at = (Get-Date).ToUniversalTime().ToString('o')
}
