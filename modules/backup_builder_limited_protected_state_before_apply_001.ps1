param(
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
  [string]$CandidateRoot = 'reports/self_development/protected_state_update_candidates'
)

Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

$root = (Resolve-Path $RepoRoot).Path
$candidateFull = Join-Path $root $CandidateRoot
$snapshotRelative = "$CandidateRoot/rollback_snapshots/PHASE161G2"
$snapshotFull = Join-Path $root $snapshotRelative
if (-not (Test-Path -LiteralPath $snapshotFull)) {
  New-Item -ItemType Directory -Path $snapshotFull | Out-Null
}

$expected = [ordered]@{
  'GENESIS_STATE.json' = '2E42C007217F0B3ABAE6AB0817D1D6607175FBD3F30E3169884773EF17F6D20F'
  'CAPABILITY_ROADMAP.json' = 'CAF5552F5630E8D9783213CDCDAEFBF55491181DD41CB778965720DA5BDCA1CA'
  'TASK_QUEUE.json' = '27220D7E169EDA9E60341B4A7A2817D3515DE8C8BB11DFC7C841A941FC01C4EC'
  'packs/registry.json' = 'C3BBD8313FA46CA80298154964DC82431DB60525C485207C40D8059F8F88F760'
  'orchestrator/run.ps1' = '51AA1CBEB0339B2DF0CBA84606E414D9DFA7395DED7179CC5248B3C4BC5CC91D'
}

$hashRecords = @()
foreach ($path in $expected.Keys) {
  $full = Join-Path $root $path
  $actual = (Get-FileHash -LiteralPath $full -Algorithm SHA256).Hash
  if ($actual -ne $expected[$path]) {
    throw "Pre-apply hash mismatch for $path. Expected $($expected[$path]); actual $actual"
  }
  $hashRecords += [pscustomobject][ordered]@{
    path = $path
    expected_sha256 = $expected[$path]
    actual_sha256 = $actual
    match = $true
  }
}

Copy-Item -LiteralPath (Join-Path $root 'GENESIS_STATE.json') -Destination (Join-Path $snapshotFull 'GENESIS_STATE.json') -Force
Copy-Item -LiteralPath (Join-Path $root 'CAPABILITY_ROADMAP.json') -Destination (Join-Path $snapshotFull 'CAPABILITY_ROADMAP.json') -Force

$routeIndex = 'route_locks/ACTIVE_ROUTE_LOCK.json'
$route = Get-Content -LiteralPath (Join-Path $root $routeIndex) -Raw | ConvertFrom-Json
$activeRoute = $route.active_route_lock_file
$routeHashes = @(
  [pscustomobject]@{ path=$routeIndex; sha256=(Get-FileHash -LiteralPath (Join-Path $root $routeIndex) -Algorithm SHA256).Hash },
  [pscustomobject]@{ path=$activeRoute; sha256=(Get-FileHash -LiteralPath (Join-Path $root $activeRoute) -Algorithm SHA256).Hash }
)

$preHashes = [pscustomobject][ordered]@{
  phase = 'PHASE161G2_APPLY_LIMITED_PROTECTED_SELF_MODEL_REFERENCES'
  all_expected_hashes_matched = $true
  files = $hashRecords
  route_locks = $routeHashes
  checked_at = (Get-Date).ToUniversalTime().ToString('o')
}
$preHashes | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G2_PRE_APPLY_HASHES.json') -Encoding UTF8

$manifest = [pscustomobject][ordered]@{
  snapshot_id = 'PHASE161G2_ROLLBACK_SNAPSHOT_V1'
  snapshot_root = $snapshotRelative
  snapshots = @(
    [pscustomobject]@{ target='GENESIS_STATE.json'; snapshot="$snapshotRelative/GENESIS_STATE.json"; sha256=$expected['GENESIS_STATE.json'] },
    [pscustomobject]@{ target='CAPABILITY_ROADMAP.json'; snapshot="$snapshotRelative/CAPABILITY_ROADMAP.json"; sha256=$expected['CAPABILITY_ROADMAP.json'] }
  )
  blocked_file_hashes = @($hashRecords | Where-Object { $_.path -in @('TASK_QUEUE.json','packs/registry.json','orchestrator/run.ps1') })
  route_lock_hashes = $routeHashes
  rollback_instruction = 'Restore both snapshots byte-for-byte, verify original hashes, and stop on any apply or validation failure.'
  created_at = (Get-Date).ToUniversalTime().ToString('o')
}
$manifest | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath (Join-Path $candidateFull 'PHASE161G2_ROLLBACK_SNAPSHOT_MANIFEST.json') -Encoding UTF8
$manifest
