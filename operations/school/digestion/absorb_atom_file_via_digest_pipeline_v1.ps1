param(
  [Parameter(Mandatory=$true)][string]$InputPath,
  [string]$MemoryRoot = '.runtime/active_compact_semantic_memory_v1',
  [ValidateSet('Auto','Fast','Stable','Full')][string]$ValidationTier = 'Auto',
  [int]$SizeBudgetBytes = 1048576,
  [switch]$DeleteOriginalRaw
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force $Path | Out-Null } }
function WriteText($Path,$Text){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $Path),$Text,$utf8) }
function WriteJson($Path,$Obj,$Depth=80){ WriteText $Path ($Obj|ConvertTo-Json -Depth $Depth) }
function FileSha256($Path){
  $sha=[System.Security.Cryptography.SHA256]::Create()
  $fs=[IO.File]::OpenRead((Resolve-Path $Path).Path)
  try { (($sha.ComputeHash($fs)|ForEach-Object{$_.ToString('x2')}) -join '') } finally { $fs.Dispose() }
}
function GetField($Obj,[string[]]$Names){
  foreach($n in $Names){ if($Obj.PSObject.Properties[$n]){ $v=[string]$Obj.PSObject.Properties[$n].Value; if(-not [string]::IsNullOrWhiteSpace($v)){ return $v } } }
  return ''
}
function Invoke-FileSystemActionWithRetry {
  param(
    [Parameter(Mandatory=$true)][scriptblock]$Action,
    [string]$ActionName = 'file_system_action',
    [int]$MaxAttempts = 30,
    [int]$DelayMs = 500
  )
  $lastError = $null
  for($attempt=1; $attempt -le [Math]::Max(1,$MaxAttempts); $attempt++){
    try {
      & $Action
      return [ordered]@{ status='PASS_FILE_SYSTEM_ACTION_WITH_RETRY'; action=$ActionName; attempts=$attempt; last_error=$null }
    } catch {
      $lastError = $_.Exception.Message
      if($attempt -lt [Math]::Max(1,$MaxAttempts)){ Start-Sleep -Milliseconds $DelayMs }
    }
  }
  throw ("FILE_SYSTEM_RETRY_EXHAUSTED:{0}:attempts={1}:last_error={2}" -f $ActionName,[Math]::Max(1,$MaxAttempts),$lastError)
}
function Publish-ActiveMemoryRootWithRetry {
  param(
    [Parameter(Mandatory=$true)][string]$CandidateMemoryRoot,
    [Parameter(Mandatory=$true)][string]$TargetMemoryRoot,
    [int]$MaxAttempts = 30,
    [int]$DelayMs = 500
  )
  if(-not(Test-Path $CandidateMemoryRoot)){ throw "CANDIDATE_MEMORY_ROOT_MISSING:$CandidateMemoryRoot" }
  $targetParent=Split-Path $TargetMemoryRoot -Parent
  if($targetParent){ EnsureDir $targetParent }
  $removeResult=[ordered]@{ status='SKIPPED_TARGET_NOT_PRESENT'; action='remove_existing_target_memory_root'; attempts=0; last_error=$null }
  if(Test-Path $TargetMemoryRoot){
    $removeResult = Invoke-FileSystemActionWithRetry -ActionName 'remove_existing_target_memory_root' -MaxAttempts $MaxAttempts -DelayMs $DelayMs -Action { Remove-Item -LiteralPath $TargetMemoryRoot -Recurse -Force -ErrorAction Stop }
  }
  $copyResult = Invoke-FileSystemActionWithRetry -ActionName 'copy_candidate_to_target_memory_root' -MaxAttempts $MaxAttempts -DelayMs $DelayMs -Action { Copy-Item -LiteralPath $CandidateMemoryRoot -Destination $TargetMemoryRoot -Recurse -Force -ErrorAction Stop }
  return [ordered]@{
    status='PASS_ACTIVE_MEMORY_ROOT_PUBLISHED_WITH_RETRY'
    remove_result=$removeResult
    copy_result=$copyResult
    target_memory_root=$TargetMemoryRoot
    candidate_memory_root=$CandidateMemoryRoot
    lock_tolerant=$true
  }
}
if(-not (Test-Path $InputPath)){ throw "INPUT_FILE_MISSING:$InputPath" }
$resolvedInput=(Resolve-Path $InputPath).Path
$repoRuntime=(Join-Path $repoRoot '.runtime')
$runId="file_atom_absorption_$(Get-Date -Format yyyyMMdd_HHmmss)"
$runRoot=".runtime/file_atom_absorption/$runId"
$stagingDir="$runRoot/staging"
EnsureDir $stagingDir
$stagedInput="$stagingDir/raw_atoms.jsonl"
$normalizedInput="$stagingDir/digestible_atoms.jsonl"
$targetMemoryRoot=$MemoryRoot
$candidateMemoryRoot="$runRoot/memory_candidate"
$cumulative_memory_merge=$true
$existing_memory_seeded=$false
$existing_memory_cells_before=0
if(Test-Path (Join-Path $targetMemoryRoot 'manifest.json')){
  $existingManifest=Get-Content (Join-Path $targetMemoryRoot 'manifest.json') -Raw|ConvertFrom-Json
  $existing_memory_cells_before=[int]$existingManifest.cell_count
  Copy-Item -Path $targetMemoryRoot -Destination $candidateMemoryRoot -Recurse -Force
  $existing_memory_seeded=$true
}
Copy-Item -Path $InputPath -Destination $stagedInput -Force
$rows=@()
$lineNo=0
Get-Content $stagedInput | ForEach-Object {
  $line=[string]$_
  if([string]::IsNullOrWhiteSpace($line)){ return }
  $lineNo++
  try { $rows += ($line | ConvertFrom-Json) } catch { throw "BAD_ATOM_JSONL_LINE:${lineNo}:$($_.Exception.Message)" }
}
if($rows.Count -lt 1){ throw 'NO_ATOMS_IN_FILE' }
$normalized=@()
foreach($r in $rows){
  $isFactoryCandidate=($r.PSObject.Properties['theme_key'] -and $r.PSObject.Properties['learning_key'] -and $r.PSObject.Properties['level'])
  if($isFactoryCandidate){
    $theme=GetField $r @('theme_key')
    $level=GetField $r @('level')
    $sourceMode=GetField $r @('source_mode')
    $verbRootMode=$theme
    $concept=$theme
    $label=$theme
    $definition="Factory curriculum theme $verbRootMode is a Builder learning ladder theme. Current observed step is level $level from source_mode $sourceMode."
    $props=@("source_mode=$sourceMode","latest_observed_level=$level")
    $relations=@()
    $prereq=GetField $r @('prerequisite_key')
    if($prereq){ $relations += "prerequisite_key:$prereq" }
    $learningKey=GetField $r @('learning_key')
    if($learningKey){ $relations += "learning_key:$learningKey" }
    $uses=@(
      "Use this theme only as Builder process curriculum material after factory contract, streaming, digest, and promotion gates pass.",
      "Do not treat factory cursor output as external factual world knowledge."
    )
  } else {
    $concept=GetField $r @('concept_key','concept','topic','learning_key','candidate_id','atom_id','label','title')
    if([string]::IsNullOrWhiteSpace($concept)){ throw 'ATOM_MISSING_CONCEPT_OR_TOPIC_FIELD' }
    $label=GetField $r @('label','topic','concept_key','concept','learning_key','candidate_id','atom_id')
    $definition=GetField $r @('definition','summary','new_knowledge','objective','expected_behavior','text','exercise')
    if([string]::IsNullOrWhiteSpace($definition)){ throw 'ATOM_MISSING_MEANING_FIELD' }
    $uses=@()
    foreach($name in @('behavior_use_proof_target','expected_behavior','return_to_parent','exercise')){ $v=GetField $r @($name); if($v){ $uses += $v } }
    $props=@()
    foreach($name in @('source_mode','theme_key','learning_key','level','ladder_step','batch_delta_target')){ if($r.PSObject.Properties[$name]){ $props += "$name=$($r.PSObject.Properties[$name].Value)" } }
    $relations=@()
    foreach($name in @('prerequisite_key','theme_key')){ if($r.PSObject.Properties[$name]){ $v=[string]$r.PSObject.Properties[$name].Value; if($v){ $relations += "${name}:$v" } } }
  }
  $normalized += [pscustomobject]@{
    concept_key=$concept
    label=$label
    kind=if($isFactoryCandidate){'factory_theme_ladder_memory'}else{'semantic_material'}
    definition=$definition
    properties=@($props)
    relations=@($relations)
    uses=@($uses)
  }
}
($normalized | ForEach-Object { $_|ConvertTo-Json -Depth 30 -Compress }) -join "`n" | Set-Content -Path $normalizedInput -Encoding UTF8
$policyOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/select_compact_semantic_digest_validation_budget_v1.ps1 -RequestedTier $ValidationTier -IncomingAtoms $rows.Count *>&1 | ForEach-Object {[string]$_})
$selectedTier=($policyOut|Where-Object{$_ -match '^SELECTED_TIER='}|Select-Object -Last 1) -replace '^SELECTED_TIER=',''
if([string]::IsNullOrWhiteSpace($selectedTier)){ throw 'VALIDATION_POLICY_TIER_MISSING' }
$routeBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerBefore=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
$inputSha=FileSha256 $stagedInput
$digestOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/invoke_compact_semantic_digestion_organ_v1.ps1 -InputPath $normalizedInput -MemoryRoot $candidateMemoryRoot -RunId $runId -CleanupRawSource -SizeBudgetBytes $SizeBudgetBytes *>&1 | ForEach-Object {[string]$_})
$digestStatus=($digestOut|Where-Object{$_ -match '^DIGEST_STATUS='}|Select-Object -Last 1) -replace '^DIGEST_STATUS=',''
if($digestStatus -ne 'PASS_COMPACT_SEMANTIC_DIGESTION_ORGAN_V1'){ throw "DIGEST_NOT_PASS:$digestStatus" }
if(Test-Path $normalizedInput){ throw 'NORMALIZED_DIGEST_INPUT_NOT_DELETED' }
if(Test-Path $stagedInput){ Remove-Item $stagedInput -Force }
$manifest=Get-Content (Join-Path $candidateMemoryRoot 'manifest.json') -Raw|ConvertFrom-Json
$index=Get-Content (Join-Path $candidateMemoryRoot 'index.json') -Raw|ConvertFrom-Json
$cellsPath=Join-Path $candidateMemoryRoot 'cells.jsonl'
if(Test-Path $stagedInput){ throw 'STAGED_RAW_SOURCE_NOT_DELETED' }
if($manifest.raw_source_dependency_removed -ne $true){ throw 'RAW_SOURCE_DEPENDENCY_NOT_REMOVED' }
if([int]$manifest.total_memory_bytes -gt $SizeBudgetBytes){ throw 'SIZE_BUDGET_EXCEEDED_AFTER_DIGEST' }
if([int]$index.term_count -lt 1){ throw 'LOOKUP_INDEX_EMPTY' }
if($selectedTier -ne 'Fast'){
  $cellsText=Get-Content $cellsPath -Raw
  foreach($bad in @('raw_text','source_text','ready_atoms','batch_trace','prompt_trace')){ if($cellsText -match $bad){ throw "RAW_FIELD_SURVIVED:$bad" } }
}
$originalDeleted=$false
if($DeleteOriginalRaw){
  if(-not ($resolvedInput.StartsWith($repoRuntime,[System.StringComparison]::OrdinalIgnoreCase))){ throw 'REFUSE_DELETE_ORIGINAL_OUTSIDE_RUNTIME' }
  if(Test-Path $resolvedInput){ Remove-Item $resolvedInput -Force }
  $originalDeleted=(-not (Test-Path $resolvedInput))
}
$routeAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_POINTER_V1.json -Raw|ConvertFrom-Json
$ledgerAfter=Get-Content operations/school/curriculum/incremental_active_store/ACTIVE_REPO_BODY_ROUTE_REPLAY_LEDGER_V1.json -Raw|ConvertFrom-Json
if([int]$routeBefore.routed_active_count -ne [int]$routeAfter.routed_active_count){ throw 'ROUTE_MUTATED_BY_FILE_ABSORPTION' }
if([int]$ledgerBefore.replayed_active_count -ne [int]$ledgerAfter.replayed_active_count){ throw 'LEDGER_MUTATED_BY_FILE_ABSORPTION' }
$publishResult=Publish-ActiveMemoryRootWithRetry -CandidateMemoryRoot $candidateMemoryRoot -TargetMemoryRoot $targetMemoryRoot
$report=[ordered]@{
  schema='file_atom_absorption_pipeline_v1'
  status='PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'
  run_id=$runId
  input_path=$resolvedInput
  input_sha256=$inputSha
  input_atoms=$rows.Count
  normalized_digest_atoms=$normalized.Count
  selected_validation_tier=$selectedTier
  memory_root=$targetMemoryRoot
  candidate_memory_root=$candidateMemoryRoot
  active_memory_publish=$publishResult
  digest_status=$digestStatus
  digested_cells=[int]$manifest.cell_count
  merged_count=[int]$manifest.merged_count
  cumulative_memory_merge=$cumulative_memory_merge
  existing_memory_seeded=$existing_memory_seeded
  existing_memory_cells_before=[int]$existing_memory_cells_before
  total_memory_bytes=[int]$manifest.total_memory_bytes
  size_budget_bytes=$SizeBudgetBytes
  staged_raw_deleted=(-not (Test-Path $stagedInput))
  normalized_digest_input_deleted=(-not (Test-Path $normalizedInput))
  original_raw_deleted=$originalDeleted
  raw_source_dependency_removed=$true
  lookup_term_count=[int]$index.term_count
  route_before=[int]$routeBefore.routed_active_count
  route_after=[int]$routeAfter.routed_active_count
  ledger_before=[int]$ledgerBefore.replayed_active_count
  ledger_after=[int]$ledgerAfter.replayed_active_count
  route_ledger_mutated=$false
  runtime_ready=$false
  boundary='Factory/atom file material is absorbed only through cumulative compact semantic memory. Existing active memory seeds candidate memory, new atoms merge through digest, staging and normalized raw are deleted; route/ledger are not intelligence stores.'
}
$proofPath="$runRoot/FILE_ATOM_ABSORPTION_PIPELINE_V1.json"
WriteJson $proofPath $report 80
Write-Host 'FILE_ATOM_ABSORPTION_STATUS=PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'
Write-Host "PROOF_PATH=$proofPath"
Write-Host "INPUT_ATOMS=$($rows.Count)"
Write-Host "NORMALIZED_DIGEST_ATOMS=$($normalized.Count)"
Write-Host "DIGESTED_CELLS=$($report.digested_cells)"
Write-Host "MERGED_COUNT=$($report.merged_count)"
Write-Host "VALIDATION_TIER=$selectedTier"
Write-Host "RAW_SOURCE_DEPENDENCY_REMOVED=$($report.raw_source_dependency_removed)"
Write-Host "STAGED_RAW_DELETED=$($report.staged_raw_deleted)"
Write-Host "NORMALIZED_DIGEST_INPUT_DELETED=$($report.normalized_digest_input_deleted)"
Write-Host "ORIGINAL_RAW_DELETED=$($report.original_raw_deleted)"
Write-Host "TOTAL_MEMORY_BYTES=$($report.total_memory_bytes)"
Write-Host "ROUTE_AFTER=$($report.route_after)"
Write-Host "LEDGER_AFTER=$($report.ledger_after)"
Write-Host 'RUNTIME_READY=false'