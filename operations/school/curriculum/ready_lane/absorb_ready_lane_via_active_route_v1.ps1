param(
  [Parameter(Mandatory=$true)][string]$ReadyLanePath,
  [string]$PromotionId = "manual_raw_route_absorb_blocked_$(Get-Date -Format yyyyMMdd_HHmmss)",
  [switch]$DryRun
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($Path,$Obj,$Depth=40){
  $dir=Split-Path $Path -Parent
  if($dir -and -not (Test-Path $dir)){ New-Item -ItemType Directory -Force $dir | Out-Null }
  [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),($Obj|ConvertTo-Json -Depth $Depth),$utf8)
}
$routePath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json'
$ledgerPath='operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json'
$route=$null; $ledger=$null
if(Test-Path $routePath){ $route=Get-Content $routePath -Raw|ConvertFrom-Json }
if(Test-Path $ledgerPath){ $ledger=Get-Content $ledgerPath -Raw|ConvertFrom-Json }
$readyExists=Test-Path $ReadyLanePath
$report=[ordered]@{
  schema='absorb_ready_lane_via_active_route_v2'
  status='BLOCKED_RAW_ROUTE_ABSORPTION_DEPRECATED_V1'
  promotion_id=$PromotionId
  ready_lane_path=$ReadyLanePath
  ready_lane_exists=$readyExists
  dry_run=[bool]$DryRun
  runtime_ready=$false
  active_route_mutated=$false
  digested_knowledge_mutated=$false
  raw_route_absorption_allowed=$false
  route_status=if($route){$route.status}else{'UNKNOWN'}
  route_count=if($route){[int]$route.routed_active_count}else{0}
  ledger_status=if($ledger){$ledger.status}else{'UNKNOWN'}
  ledger_count=if($ledger){[int]$ledger.replayed_active_count}else{0}
  blockers=@('RAW_READY_LANE_IS_STAGING_NOT_ABSORPTION','COMPACT_SEMANTIC_DIGESTION_ORGAN_REQUIRED')
  law='If raw source cannot be deleted after integration, the atom is not absorbed. Ready-lane route absorption is deprecated.'
  boundary='No mutation. Build digest organ first.'
}
WriteJson '.runtime/blocked_absorption/ABSORB_READY_LANE_VIA_ACTIVE_ROUTE_V2.json' $report 60
Write-Host "ROUTE_ABSORB_STATUS=$($report.status)"
Write-Host "READY_LANE=$ReadyLanePath"
Write-Host "ACTIVE_ROUTE_MUTATED=false"
Write-Host "DIGESTED_KNOWLEDGE_MUTATED=false"
Write-Host "RAW_ROUTE_ABSORPTION_ALLOWED=false"
Write-Host 'RUNTIME_READY=false'
exit 2