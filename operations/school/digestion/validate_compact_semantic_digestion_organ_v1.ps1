param(
  [int]$TargetAtoms = 20,
  [int]$SizeBudgetBytes = 80000,
  [ValidateSet('Fast','Stable','Full')][string]$ValidationTier = 'Stable'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteText($Path,$Text){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),$Text,$utf8) }
$policyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/select_compact_semantic_digest_validation_budget_v1.ps1 -RequestedTier $ValidationTier -IncomingAtoms $TargetAtoms *>&1 | ForEach-Object {[string]$_})
$policyOut | ForEach-Object { Write-Host "POLICY|$_" }
$selectedTier=($policyOut|Where-Object{$_ -match '^SELECTED_TIER='}|Select-Object -Last 1) -replace '^SELECTED_TIER=',''
if([string]::IsNullOrWhiteSpace($selectedTier)){ throw 'VALIDATION_POLICY_TIER_MISSING' }
$routeBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
$runId="compact_semantic_digest_validation_$(Get-Date -Format yyyyMMdd_HHmmss)"
$root=".runtime/digestion_validation/$runId"
$input="$root/raw_candidates.jsonl"
$memory="$root/memory"
EnsureDir $root
$base=@(
  @{concept_key='vehicle.car';label='car';aliases=@('automobile','auto');definition='A car is a road vehicle used to transport people or goods.';properties=@('road vehicle','wheels','transport');relations=@('is_a:vehicle','used_for:transport');uses=@('travel','delivery')},
  @{concept_key='vehicle.car';label='automobile';aliases=@('car');definition='An automobile is a vehicle for road transport.';properties=@('engine or motor','passenger cabin');relations=@('is_a:vehicle');uses=@('commuting')},
  @{concept_key='vehicle.wheel';label='wheel';definition='A wheel is a round component that rotates to help a vehicle move.';properties=@('round','rotates');relations=@('part_of:vehicle');uses=@('movement')},
  @{concept_key='vehicle.engine';label='engine';definition='An engine converts energy into motion for a machine or vehicle.';properties=@('power source','motion');relations=@('can_power:car');uses=@('propulsion')},
  @{concept_key='road';label='road';definition='A road is a prepared path used by vehicles and people for travel.';properties=@('path','transport surface');relations=@('used_by:vehicle');uses=@('navigation')},
  @{concept_key='transport';label='transport';definition='Transport is the movement of people or goods from one place to another.';properties=@('movement','people','goods');relations=@('purpose_of:vehicle');uses=@('logistics')},
  @{concept_key='vehicle.bicycle';label='bicycle';definition='A bicycle is a human-powered vehicle with two wheels.';properties=@('two wheels','human powered');relations=@('is_a:vehicle');uses=@('travel')},
  @{concept_key='vehicle.electric_car';label='electric car';definition='An electric car is a car powered by one or more electric motors.';properties=@('electric motor','battery');relations=@('is_a:vehicle.car');uses=@('low-emission travel')},
  @{concept_key='battery';label='battery';definition='A battery stores electrical energy for later use.';properties=@('stores energy','electrical');relations=@('can_power:electric car');uses=@('energy storage')},
  @{concept_key='driver';label='driver';definition='A driver controls a vehicle.';properties=@('operator');relations=@('controls:vehicle');uses=@('safe operation')}
)
$rows=@()
for($i=0;$i -lt $TargetAtoms;$i++){
  $r=$base[$i % $base.Count].Clone()
  $r.observation_id="obs_$i"
  $rows += [pscustomobject]$r
}
$jsonl=($rows | ForEach-Object { $_|ConvertTo-Json -Depth 20 -Compress }) -join "`n"
WriteText $input ($jsonl + "`n")
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $input -MemoryRoot $memory -RunId $runId -CleanupRawSource -SizeBudgetBytes $SizeBudgetBytes *>&1 | ForEach-Object {[string]$_})
$out | ForEach-Object { Write-Host "DIGEST|$_" }
if(-not ($out | Where-Object { $_ -eq 'DIGEST_STATUS=PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1' })){ throw 'DIGEST_PASS_MISSING' }
if(Test-Path $input){ throw 'RAW_SOURCE_NOT_DELETED' }
$manifest=Get-Content (Join-Path $memory 'manifest.json') -Raw|ConvertFrom-Json
$index=Get-Content (Join-Path $memory 'index.json') -Raw|ConvertFrom-Json
$cells=@(Get-Content (Join-Path $memory 'cells.jsonl') | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_|ConvertFrom-Json })
if($manifest.status -ne 'PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1'){ throw 'MANIFEST_NOT_PASS' }
if($manifest.raw_source_dependency_removed -ne $true){ throw 'RAW_DEPENDENCY_NOT_REMOVED' }
if([int]$manifest.input_count -ne $TargetAtoms){ throw 'INPUT_COUNT_BAD' }
if([int]$manifest.cell_count -gt $TargetAtoms){ throw 'CELL_COUNT_EXCEEDS_INPUT' }
if($selectedTier -ne 'Fast' -and [int]$manifest.cell_count -ge $TargetAtoms){ throw 'DEDUP_MERGE_NOT_PROVEN' }
if([int]$manifest.total_memory_bytes -gt $SizeBudgetBytes){ throw 'SIZE_BUDGET_BAD' }
$terms=$index.terms
$lookupTerms=if($selectedTier -eq 'Fast'){@('vehicle-car','automobile')}else{@('vehicle-car','automobile','road-vehicle','transport','engine-or-motor')}
foreach($term in $lookupTerms){ if($null -eq $terms.$term){ throw "LOOKUP_TERM_MISSING:$term" } }
if($selectedTier -ne 'Fast'){
  foreach($c in $cells){
    $j=$c|ConvertTo-Json -Depth 50 -Compress
    foreach($bad in @('raw_text','source_text','ready_atoms','batch_trace','prompt_trace')){ if($j -match $bad){ throw "RAW_FIELD_SURVIVED:$bad" } }
  }
}
$routeAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
if([int]$routeBefore.routed_active_count -ne [int]$routeAfter.routed_active_count){ throw 'ROUTE_MUTATED_BY_DIGEST_VALIDATION' }
if([int]$ledgerBefore.replayed_active_count -ne [int]$ledgerAfter.replayed_active_count){ throw 'LEDGER_MUTATED_BY_DIGEST_VALIDATION' }
$statusLines=@(git status --short --untracked-files=all)
if($statusLines | Where-Object { $_ -match '^\?\? \.runtime' }){ throw 'RUNTIME_NOT_IGNORED' }
# Singleton latest/current property regression: successive observations must replace, not accumulate.
$singleton1="$root/singleton_property_1.jsonl"
$singleton2="$root/singleton_property_2.jsonl"
$row1=[ordered]@{concept_key='validator.singleton';label='singleton';definition='Validator singleton property concept.';properties=@('stable_property=keep','latest_observed_level=1');relations=@();uses=@()}
$row2=[ordered]@{concept_key='validator.singleton';label='singleton';definition='Validator singleton property concept.';properties=@('stable_property=keep','latest_observed_level=2');relations=@();uses=@()}
WriteText $singleton1 (($row1|ConvertTo-Json -Depth 20 -Compress)+"`n")
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $singleton1 -MemoryRoot $memory -RunId "${runId}_singleton_1" -SizeBudgetBytes $SizeBudgetBytes *> $null
if($LASTEXITCODE-ne0){ throw 'SINGLETON_DIGEST_1_FAILED' }
WriteText $singleton2 (($row2|ConvertTo-Json -Depth 20 -Compress)+"`n")
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $singleton2 -MemoryRoot $memory -RunId "${runId}_singleton_2" -SizeBudgetBytes $SizeBudgetBytes *> $null
if($LASTEXITCODE-ne0){ throw 'SINGLETON_DIGEST_2_FAILED' }
$singletonCell=@(Get-Content (Join-Path $memory 'cells.jsonl')|Where-Object{-not[string]::IsNullOrWhiteSpace($_)}|ForEach-Object{$_|ConvertFrom-Json}|Where-Object{$_.concept_key-eq'validator-singleton'}|Select-Object -First 1)
if(-not$singletonCell){ throw 'SINGLETON_CELL_MISSING' }
$latestProps=@($singletonCell.properties|Where-Object{([string]$_)-match '^latest_observed_level='})
if($latestProps.Count-ne1 -or [string]$latestProps[0]-ne'latest_observed_level=2'){ throw ('SINGLETON_PROPERTY_ACCUMULATED:'+(@($latestProps)-join',')) }
if(@($singletonCell.properties|Where-Object{[string]$_-eq'stable_property=keep'}).Count-ne1){ throw 'STABLE_PROPERTY_LOST' }
Write-Host 'SINGLETON_PROPERTY_REGRESSION=PASS'
# Index-clean fast-path regression: relations/fingerprints-only change must preserve index bytes.
$indexBeforeClean=(Get-FileHash -Algorithm SHA256 (Join-Path $memory 'index.json')).Hash
$cleanInput="$root/index_clean_relation_only.jsonl"
$cleanRow=[ordered]@{concept_key='vehicle.car';label='car';aliases=@('automobile','auto');definition='A car is a road vehicle used to transport people or goods.';properties=@('road vehicle','wheels','transport','engine or motor','passenger cabin');relations=@('proof_only:new_relation');uses=@('travel','delivery','commuting')}
WriteText $cleanInput (($cleanRow|ConvertTo-Json -Depth 20 -Compress)+"`n")
$cleanOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $cleanInput -MemoryRoot $memory -RunId "${runId}_index_clean" -SizeBudgetBytes $SizeBudgetBytes *>&1 | ForEach-Object {[string]$_})
$cleanAction=(($cleanOut|Where-Object{$_ -match '^INDEX_ACTION='}|Select-Object -Last 1) -replace '^INDEX_ACTION=','')
if($cleanAction -ne 'PRESERVED_CLEAN'){ throw "INDEX_CLEAN_NOT_PRESERVED:$cleanAction" }
$indexAfterClean=(Get-FileHash -Algorithm SHA256 (Join-Path $memory 'index.json')).Hash
if($indexAfterClean -ne $indexBeforeClean){ throw 'INDEX_CLEAN_SHA_CHANGED' }
# Index-dirty fallback: one new indexed property must rebuild and become queryable.
$dirtyInput="$root/index_dirty_property.jsonl"
$dirtyRow=[ordered]@{concept_key='vehicle.car';label='car';definition='A car is a road vehicle used to transport people or goods.';properties=@('validator-new-index-term');relations=@();uses=@()}
WriteText $dirtyInput (($dirtyRow|ConvertTo-Json -Depth 20 -Compress)+"`n")
$dirtyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $dirtyInput -MemoryRoot $memory -RunId "${runId}_index_dirty" -SizeBudgetBytes $SizeBudgetBytes *>&1 | ForEach-Object {[string]$_})
$dirtyAction=(($dirtyOut|Where-Object{$_ -match '^INDEX_ACTION='}|Select-Object -Last 1) -replace '^INDEX_ACTION=','')
if($dirtyAction -ne 'REBUILT'){ throw "INDEX_DIRTY_NOT_REBUILT:$dirtyAction" }
$dirtyIndex=Get-Content (Join-Path $memory 'index.json') -Raw|ConvertFrom-Json
if($null -eq $dirtyIndex.terms.'validator-new-index-term'){ throw 'INDEX_DIRTY_TERM_MISSING' }
Write-Host "INDEX_CLEAN_ACTION=$cleanAction"
Write-Host "INDEX_DIRTY_ACTION=$dirtyAction"
Write-Host 'VALIDATION_PASS=COMPACT_SEMANTIC_DIGESTION_ORGAN_V1_VALID'
Write-Host "VALIDATION_TIER=$selectedTier"
Write-Host "TARGET_ATOMS=$TargetAtoms"
Write-Host "DIGESTED_CELLS=$($manifest.cell_count)"
Write-Host "MERGED_COUNT=$($manifest.merged_count)"
Write-Host "RAW_SOURCE_DELETED=$($manifest.raw_source_deleted)"
Write-Host "RAW_SOURCE_DEPENDENCY_REMOVED=$($manifest.raw_source_dependency_removed)"
Write-Host "TOTAL_MEMORY_BYTES=$($manifest.total_memory_bytes)"
Write-Host "SIZE_BUDGET_BYTES=$SizeBudgetBytes"
Write-Host "ROUTE_AFTER=$($routeAfter.routed_active_count)"
Write-Host "LEDGER_AFTER=$($ledgerAfter.replayed_active_count)"
Write-Host 'RUNTIME_READY=false'