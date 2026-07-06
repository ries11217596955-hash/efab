param(
  [ValidateSet('Auto','Fast','Stable','Full')][string]$RequestedTier = 'Auto',
  [int]$IncomingAtoms = 0,
  [int]$DigestsSinceStable = 0,
  [int]$DigestsSinceFull = 0,
  [switch]$BeforePromotion
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=40){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8) }
$tier=$RequestedTier
$reason='requested_explicit'
if($RequestedTier -eq 'Auto'){
  $tier='Fast'
  $reason='default_per_digest_fast_guard'
  if($BeforePromotion){ $tier='Full'; $reason='before_promotion_requires_full' }
  elseif($IncomingAtoms -ge 5000){ $tier='Full'; $reason='incoming_atoms_gte_5000' }
  elseif($DigestsSinceFull -ge 50){ $tier='Full'; $reason='digests_since_full_gte_50' }
  elseif($IncomingAtoms -ge 1000){ $tier='Stable'; $reason='incoming_atoms_gte_1000' }
  elseif($DigestsSinceStable -ge 10){ $tier='Stable'; $reason='digests_since_stable_gte_10' }
}
$checks=[ordered]@{}
switch($tier){
  'Fast' {
    $checks.schema_parse=$true; $checks.manifest_status=$true; $checks.raw_source_deleted=$true
    $checks.size_budget=$true; $checks.route_ledger_unchanged=$true; $checks.lookup_smoke=$true
    $checks.dedup_sample=$false; $checks.full_negative_tests=$false; $checks.full_memory_scan=$false
  }
  'Stable' {
    $checks.schema_parse=$true; $checks.manifest_status=$true; $checks.raw_source_deleted=$true
    $checks.size_budget=$true; $checks.route_ledger_unchanged=$true; $checks.lookup_smoke=$true
    $checks.dedup_sample=$true; $checks.full_negative_tests=$false; $checks.full_memory_scan=$false
  }
  'Full' {
    $checks.schema_parse=$true; $checks.manifest_status=$true; $checks.raw_source_deleted=$true
    $checks.size_budget=$true; $checks.route_ledger_unchanged=$true; $checks.lookup_smoke=$true
    $checks.dedup_sample=$true; $checks.full_negative_tests=$true; $checks.full_memory_scan=$true
  }
}
$policy=[ordered]@{
  schema='compact_semantic_digest_validation_budget_v1'
  status='PASS_DIGEST_VALIDATION_BUDGET_SELECTED_V1'
  requested_tier=$RequestedTier
  selected_tier=$tier
  reason=$reason
  incoming_atoms=$IncomingAtoms
  digests_since_stable=$DigestsSinceStable
  digests_since_full=$DigestsSinceFull
  before_promotion=[bool]$BeforePromotion
  checks=$checks
  law='Do cheap safety checks every digest; run expensive validation only by tier, threshold, or promotion boundary.'
  runtime_ready=$false
}
WriteJson '.runtime/digestion_policy/COMPACT_SEMANTIC_DIGEST_VALIDATION_BUDGET_V1.json' $policy 60
Write-Host "DIGEST_VALIDATION_POLICY_STATUS=$($policy.status)"
Write-Host "SELECTED_TIER=$tier"
Write-Host "REASON=$reason"
Write-Host 'RUNTIME_READY=false'