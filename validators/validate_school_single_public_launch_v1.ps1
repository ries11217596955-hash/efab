param()
$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=30){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $json=$Obj | ConvertTo-Json -Depth $Depth
  $lines=@($json -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){ if($lines.Count -eq 1){$lines=@();break}; $lines=@($lines[0..($lines.Count-2)]) }
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),(($lines -join "`n") + "`n"),$utf8NoBom)
}
$public='operations/school/run_agent_school.ps1'
if(-not(Test-Path $public)){ Add-Err "missing_public_launcher:$public" }
$removed=@(
  'operations/school/warehouse/invoke_exact_count_warehouse_cycle_v1.ps1',
  'operations/school/warehouse/consume_codex_warehouse_micro_batches_v1.ps1',
  'operations/school/warehouse/invoke_codex_warehouse_producer_smoke_v1.ps1',
  'operations/school/warehouse/validate_codex_warehouse_pipeline_v1.ps1',
  'operations/school/warehouse/validate_codex_warehouse_producer_smoke_v1.ps1',
  'operations/school/warehouse/validate_generic_exact_count_cycle_v1.ps1'
)
foreach($p in $removed){ if(Test-Path $p){ Add-Err "extra_school_bicycle_exists:$p" } }
$tracked=@(git ls-files | Where-Object { Test-Path $_ })
$liveRefs=@()
foreach($needle in @('invoke_exact_count_warehouse_cycle_v1.ps1','consume_codex_warehouse_micro_batches_v1.ps1')){
  foreach($hit in @(Select-String -Path $tracked -Pattern $needle -SimpleMatch -ErrorAction SilentlyContinue)){
    if($hit.Path -match 'RUNTIME_BLOAT_ROOT_CAUSE_AUDIT|CODEX_WAREHOUSE_PIPELINE_INSTALLATION') { continue }
    $liveRefs += [ordered]@{ file=$hit.Path.Replace((Resolve-Path '.').Path+'\','').Replace('\','/'); line=$hit.LineNumber; text=$hit.Line.Trim() }
  }
}
if(@($liveRefs).Count -gt 0){ Add-Err ('live_refs_to_removed_bicycles:' + (@($liveRefs).Count)) }
$runText=''
if(Test-Path $public){ $runText=Get-Content $public -Raw }
if($runText -notmatch 'ONE BIKE LAW'){ Add-Err 'public_launcher_missing_one_bike_law_marker' }
if($runText -notmatch 'function Invoke-SchoolExactCountWarehouseCycle'){ Add-Err 'public_launcher_missing_embedded_exact_engine' }
if($runText -notmatch 'function Invoke-SchoolWarehouseConsumer'){ Add-Err 'public_launcher_missing_embedded_consumer_engine' }
$status=if($errors.Count -eq 0){'PASS_SCHOOL_SINGLE_PUBLIC_LAUNCH_V1'}else{'FAIL_SCHOOL_SINGLE_PUBLIC_LAUNCH_V1'}
$out=[ordered]@{
  schema='school_single_public_launch_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  public_launcher=$public
  removed_bicycles=$removed
  live_refs_to_removed_bicycles=@($liveRefs)
  errors=@($errors)
}
Write-CleanJson 'tests/self_development/SCHOOL_SINGLE_PUBLIC_LAUNCH_V1_PROOF.json' $out 50
Write-Host "STATUS=$status"
Write-Host 'PROOF_OUT=tests/self_development/SCHOOL_SINGLE_PUBLIC_LAUNCH_V1_PROOF.json'
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
