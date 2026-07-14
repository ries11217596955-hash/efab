param(
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$Count,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$Topics,
  [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][string]$RunId,
  [ValidateRange(1,1000)][int]$PatchSize = 1000,
  [string]$DynamicSelectionPath = '',
  [string]$OutputPath = '',
  [string]$LedgerPath = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function NormalizeTopic($s){
  $x=([string]$s).Trim().ToLowerInvariant()
  $x=[regex]::Replace($x, '[^\p{L}\p{Nd}]+', '_')
  $x=$x.Trim('_')
  if([string]::IsNullOrWhiteSpace($x)){ $x='unknown_topic' }
  return $x
}
if($PatchSize -ne 1000){ throw "PATCH_SIZE_MUST_BE_1000_FOR_CODEX_STABILITY:$PatchSize" }
if([string]::IsNullOrWhiteSpace($OutputPath)){ $OutputPath=".runtime/school_patch_runs/$RunId/topic_patch_plan.json" }
if([string]::IsNullOrWhiteSpace($LedgerPath)){ $LedgerPath=".runtime/school_patch_runs/$RunId/patch_ledger.jsonl" }
$topicList=@()
if($Topics.Trim().ToUpperInvariant() -eq 'AUTO'){
  if([string]::IsNullOrWhiteSpace($DynamicSelectionPath) -or -not (Test-Path $DynamicSelectionPath)){ throw 'AUTO_TOPICS_REQUIRE_DYNAMIC_SELECTION_PATH' }
  $sel=Get-Content $DynamicSelectionPath -Raw | ConvertFrom-Json
  $topicList=@([string]$sel.selected_topic.topic_key)
}else{
  $topicList=@($Topics -split ',' | ForEach-Object { NormalizeTopic $_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}
if($topicList.Count -lt 1){ throw 'TOPICS_EMPTY_AFTER_NORMALIZATION' }
$absorbedCount=0; $plannedCount=0; $failedCount=0; $openCount=0; $patchRows=@()
if(Test-Path $LedgerPath){
  $patchRows=@(Get-Content $LedgerPath | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { $_ | ConvertFrom-Json })
  foreach($row in $patchRows){
    if($row.state -eq 'ABSORBED' -or $row.state -eq 'CLEANED_AFTER_ABSORPTION'){ $absorbedCount += [int]$row.candidate_count }
    elseif($row.state -in @('FAILED','QUARANTINED')){ $failedCount += [int]$row.candidate_count }
    else { $openCount += [int]$row.candidate_count }
    $plannedCount += [int]$row.candidate_count
  }
}
$remaining=[Math]::Max(0,$Count-$absorbedCount)
$nextPatchCount=[Math]::Min($PatchSize,$remaining)
$topicCursor=0
if($patchRows.Count -gt 0){
  $absorbedPatchRows=@($patchRows | Where-Object { $_.state -eq 'ABSORBED' -or $_.state -eq 'CLEANED_AFTER_ABSORPTION' })
  $topicCursor=$absorbedPatchRows.Count % $topicList.Count
}
$nextTopic=if($nextPatchCount -gt 0){ $topicList[$topicCursor] } else { $null }
$nextPatch=$null
if($nextPatchCount -gt 0){
  $nextPatch=[ordered]@{
    patch_id=("{0}_patch_{1:D6}" -f $RunId,($patchRows.Count+1))
    topic_key=$nextTopic
    candidate_count=$nextPatchCount
    state='PLANNED'
    patch_size=$PatchSize
    codex_task_boundary='single_topic_patch_only'
    memory_acceptance_boundary='Only ABSORBED or CLEANED_AFTER_ABSORPTION counts toward memory progress.'
  }
}
$plan=[ordered]@{
  schema='school_topic_patch_plan_v1'
  status=if($nextPatchCount -gt 0){'PASS_TOPIC_PATCH_PLAN_READY'}else{'PASS_TOPIC_PATCH_PLAN_ALREADY_ABSORBED'}
  created_at=(Get-Date).ToString('o')
  run_id=$RunId
  mode=$Mode
  total_count_ceiling=$Count
  topics_raw=$Topics
  normalized_topics=@($topicList)
  patch_size=$PatchSize
  dynamic_budget_policy='Count is a total ceiling. Budget is assigned patch-by-patch by topic pressure and completion state; it is not split evenly between topics.'
  retention_policy='Patch raw proof stays in runtime. Tracked repo gets compact run/topic summaries only. Keep latest 3-5 patch runtime proofs after absorption.'
  recovery_policy=[ordered]@{
    partial_absorption_allowed=$true
    counted_states=@('ABSORBED','CLEANED_AFTER_ABSORPTION')
    uncounted_states=@('PLANNED','CODEX_DRAFT_CREATED','VALIDATED','DIGESTED','FAILED','QUARANTINED')
    after_restart='read patch ledger; keep absorbed memory progress; quarantine or regenerate non-absorbed/open patches; never claim unabsorbed candidates as memory update'
  }
  ledger_path=$LedgerPath
  absorbed_candidate_count=$absorbedCount
  open_uncounted_candidate_count=$openCount
  failed_or_quarantined_candidate_count=$failedCount
  remaining_candidate_ceiling=$remaining
  next_patch=$nextPatch
  memory_mutated=$false
}
WriteJson $OutputPath $plan 80
EnsureDir (Split-Path -Parent $LedgerPath)
if(-not (Test-Path $LedgerPath)){ New-Item -ItemType File -Path $LedgerPath -Force | Out-Null }
Write-Host "TOPIC_PATCH_PLAN_STATUS=$($plan.status)"
Write-Host "TOPIC_PATCH_PLAN_PROOF=$OutputPath"
Write-Host "TOPIC_PATCH_LEDGER=$LedgerPath"
Write-Host "TOPIC_PATCH_SIZE=$PatchSize"
Write-Host "TOPIC_PATCH_NEXT_TOPIC=$nextTopic"
Write-Host "TOPIC_PATCH_NEXT_COUNT=$nextPatchCount"
Write-Host "TOPIC_PATCH_ABSORBED_COUNT=$absorbedCount"
Write-Host "TOPIC_PATCH_REMAINING_COUNT=$remaining"
