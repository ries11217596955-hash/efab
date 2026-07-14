param(
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$Count,
  [Parameter(Mandatory=$true)][ValidateSet('Test','Live')][string]$Mode,
  [string]$Topics = 'AUTO',
  [ValidateSet('DryRun','MockCodex','RunCodex')][string]$ExecutorMode = 'DryRun',
  [switch]$Absorb,
  [ValidateRange(60,7200)][int]$CodexTimeoutSeconds = 900
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=100){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function Sha($p){ if(Test-Path $p){ (Get-FileHash $p -Algorithm SHA256).Hash } else { 'MISSING' } }
$mem='.runtime/active_compact_semantic_memory_v1'
$memoryBefore=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$runId="school_patch_executor_{0}_{1}_{2}" -f $Mode.ToLowerInvariant(),$Count,(Get-Date -Format 'yyyyMMdd_HHmmss')
$runRoot=".runtime/school_patch_executor/$runId"
EnsureDir $runRoot
$selectionPath="$runRoot/selection.json"
$planPath="$runRoot/topic_patch_plan.json"
$ledgerPath="$runRoot/patch_ledger.jsonl"
$eventsPath="$runRoot/executor_events.jsonl"
function AddEvent($state,$data){
  $row=[ordered]@{ts=(Get-Date).ToString('o'); state=$state; data=$data}
  ($row|ConvertTo-Json -Depth 60 -Compress) | Add-Content -LiteralPath $eventsPath -Encoding UTF8
}
AddEvent 'EXECUTOR_STARTED' @{mode=$Mode; count=$Count; topics=$Topics; executor_mode=$ExecutorMode; absorb=[bool]$Absorb}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/memory/select_dynamic_theme_cell_v1.ps1 -RequestedTopics $Topics -PatchSize 1000 -OutputPath $selectionPath | Out-Host
AddEvent 'TOPIC_SELECTED' @{selection_path=$selectionPath}
& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/plan_topic_patch_cycle_v1.ps1 -Count $Count -Mode $Mode -Topics $Topics -RunId $runId -PatchSize 1000 -DynamicSelectionPath $selectionPath -OutputPath $planPath -LedgerPath $ledgerPath | Out-Host
$plan=Get-Content $planPath -Raw | ConvertFrom-Json
AddEvent 'PATCH_PLANNED' @{plan_path=$planPath; next_patch=$plan.next_patch}
if($null -eq $plan.next_patch){ throw 'NO_NEXT_PATCH' }
$taskDir="$runRoot/codex_task_attempt_1"
$out=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/codex/build_codex_school_patch_task_v1.ps1 -SelectionPath $selectionPath -PatchPlanPath $planPath -OutputDir $taskDir -Attempt 1 *>&1 | ForEach-Object{[string]$_})
$out | Set-Content -LiteralPath "$taskDir/task_builder_stdout.txt" -Encoding UTF8
$taskJson="$taskDir/codex_school_patch_task.json"
$taskMd="$taskDir/CODEX_SCHOOL_PATCH_TASK.md"
$task=Get-Content $taskJson -Raw | ConvertFrom-Json
AddEvent 'CODEX_TASK_BUILT' @{task_json=$taskJson; task_md=$taskMd; candidate_limit=$task.candidate_limit; topic=$task.topic_key}
$candidatesPath=[string]$task.output_candidates_jsonl
$codexStatus='NOT_RUN'
$codexFailureClass=''
if($ExecutorMode -eq 'DryRun'){
  $finalStatus='PASS_PATCH_EXECUTOR_DRY_RUN_V1'
  AddEvent 'DRY_RUN_STOP_BEFORE_CODEX' @{reason='validator_safe_mode'}
}elseif($ExecutorMode -eq 'MockCodex'){
  EnsureDir (Split-Path -Parent $candidatesPath)
  $rows=New-Object System.Collections.ArrayList
  for($i=1;$i -le [int]$task.candidate_limit;$i++){
    $depth=[Math]::Min([int]$task.target_depth,[Math]::Max([int]$task.start_depth,1 + (($i-1) % [Math]::Max(1,[int]$task.target_depth))))
    $obj=[ordered]@{
      schema='codex_school_patch_candidate_v1'
      candidate_id=("mock.{0:D6}" -f $i)
      topic_key=$task.topic_key
      topic_label=$task.topic_label
      depth_level=$depth
      prerequisite_depth=[Math]::Max(0,$depth-1)
      target_depth=$task.target_depth
      source_basis=@('mock validator source')
      source_missing=$false
      claim="Mock candidate $i for $($task.topic_key) at depth $depth"
      expected_behavior="Builder can apply $($task.topic_key) rule $i with proof boundary."
      failure_contrast="Without this rule Builder drifts or accepts unvalidated material."
      validator="Check topic_key, depth range, proof_requirements, return_to_parent and source fields."
      proof_requirements="Runtime proof must show candidate accepted, normalized, and not memory-mutating before absorption."
      negative_case="Reject broad topic drift or missing validator/proof fields."
      return_to_parent="Improves school patch execution for selected development vector topic."
      digest_hint="Compact into topic cell $($task.topic_key) as depth-aware school patch material."
      quality_flags=@('mock','validator_safe')
    }
    [void]$rows.Add($obj)
  }
  ($rows|ForEach-Object{$_|ConvertTo-Json -Depth 50 -Compress}) -join "`n" | Set-Content -LiteralPath $candidatesPath -Encoding UTF8
  $codexStatus='MOCK_CODEX_DRAFT_CREATED'
  AddEvent 'MOCK_CODEX_DRAFT_CREATED' @{candidates=$candidatesPath; candidate_count=$rows.Count}
}else{
  $codexCmd=(Get-Command codex -ErrorAction Stop).Source
  $prompt=Get-Content $taskMd -Raw
  $stdoutPath="$taskDir/codex_stdout.txt"
  $stderrPath="$taskDir/codex_stderr.txt"
  $p=Start-Process -FilePath $codexCmd -ArgumentList @('exec','--cd',$repoRoot,'--sandbox','workspace-write','--ask-for-approval','never',$prompt) -NoNewWindow -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath
  if(-not $p.WaitForExit($CodexTimeoutSeconds*1000)){
    try{ $p.Kill() }catch{}
    $codexStatus='CODEX_FAILED'; $codexFailureClass='HANG_OR_TIMEOUT'
    AddEvent 'CODEX_FAILED' @{failure_class=$codexFailureClass; stdout=$stdoutPath; stderr=$stderrPath}
  } elseif($p.ExitCode -ne 0){
    $codexStatus='CODEX_FAILED'; $codexFailureClass='NONZERO_EXIT'
    AddEvent 'CODEX_FAILED' @{failure_class=$codexFailureClass; exit_code=$p.ExitCode; stdout=$stdoutPath; stderr=$stderrPath}
  } elseif(-not (Test-Path $candidatesPath)){
    $codexStatus='CODEX_FAILED'; $codexFailureClass='EMPTY_OUTPUT'
    AddEvent 'CODEX_FAILED' @{failure_class=$codexFailureClass; stdout=$stdoutPath; stderr=$stderrPath}
  } else {
    $codexStatus='CODEX_DRAFT_CREATED'
    AddEvent 'CODEX_DRAFT_CREATED' @{candidates=$candidatesPath; stdout=$stdoutPath; stderr=$stderrPath}
  }
}
$normalizedAtomsPath="$runRoot/normalized_patch_atoms.jsonl"
$normalizationReport="$runRoot/codex_candidate_normalization_report.json"
$absorbStatus='NOT_RUN'
$absorbProof=$null
$ledgerState='CODEX_TASK_BUILT'
if($codexStatus -in @('MOCK_CODEX_DRAFT_CREATED','CODEX_DRAFT_CREATED')){
  & powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/codex/validate_and_normalize_codex_school_patch_candidates_v1.ps1 -TaskJsonPath $taskJson -CandidatesJsonlPath $candidatesPath -OutputAtomsJsonlPath $normalizedAtomsPath -ReportPath $normalizationReport | Out-Host
  AddEvent 'CANDIDATES_NORMALIZED' @{atoms=$normalizedAtomsPath; report=$normalizationReport}
  $ledgerState='VALIDATED_NORMALIZED'
  if($Absorb){
    $absorbOut=@(& powershell -NoProfile -ExecutionPolicy Bypass -File operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1 -InputPath $normalizedAtomsPath -RunId $runId *>&1 | ForEach-Object{[string]$_})
    $absorbOut | Set-Content -LiteralPath "$runRoot/absorption_stdout.txt" -Encoding UTF8
    $absorbStatus=(($absorbOut|Where-Object{$_ -match '^FILE_ATOM_ABSORPTION_STATUS='}|Select-Object -Last 1) -replace '^FILE_ATOM_ABSORPTION_STATUS=','')
    $absorbProof=(($absorbOut|Where-Object{$_ -match '^PROOF_PATH='}|Select-Object -Last 1) -replace '^PROOF_PATH=','')
    if($absorbStatus -ne 'PASS_FILE_ATOM_ABSORPTION_PIPELINE_V1'){ throw "ABSORPTION_FAILED:$absorbStatus" }
    $ledgerState='ABSORBED'
    AddEvent 'PATCH_ABSORBED' @{status=$absorbStatus; proof=$absorbProof}
    $finalStatus='PASS_PATCH_EXECUTOR_ABSORBED_V1'
  } else {
    $finalStatus='PASS_PATCH_EXECUTOR_VALIDATED_NO_ABSORB_V1'
  }
}elseif($codexStatus -eq 'CODEX_FAILED'){
  $ledgerState='CODEX_FAILED'
  $finalStatus='PASS_PATCH_EXECUTOR_CODEX_FAILURE_RECORDED_V1'
}else{
  $finalStatus='PASS_PATCH_EXECUTOR_DRY_RUN_V1'
}
$ledgerRow=[ordered]@{
  ts=(Get-Date).ToString('o')
  run_id=$runId
  patch_id=$plan.next_patch.patch_id
  topic_key=$plan.next_patch.topic_key
  candidate_count=[int]$plan.next_patch.candidate_count
  state=$ledgerState
  executor_mode=$ExecutorMode
  codex_status=$codexStatus
  codex_failure_class=$codexFailureClass
  task_json=$taskJson
  candidates_jsonl=$candidatesPath
  normalized_atoms_jsonl=$normalizedAtomsPath
  normalization_report=$normalizationReport
  absorption_status=$absorbStatus
  absorption_proof=$absorbProof
}
($ledgerRow|ConvertTo-Json -Depth 80 -Compress) | Add-Content -LiteralPath $ledgerPath -Encoding UTF8
$memoryAfter=[ordered]@{manifest=Sha "$mem/manifest.json"; index=Sha "$mem/index.json"; cells=Sha "$mem/cells.jsonl"}
$report=[ordered]@{
  schema='school_patch_executor_v1'
  status=$finalStatus
  created_at=(Get-Date).ToString('o')
  run_id=$runId
  mode=$Mode
  count=$Count
  topics=$Topics
  executor_mode=$ExecutorMode
  absorb_requested=[bool]$Absorb
  selection_path=$selectionPath
  patch_plan_path=$planPath
  patch_ledger_path=$ledgerPath
  task_json=$taskJson
  task_md=$taskMd
  codex_status=$codexStatus
  codex_failure_class=$codexFailureClass
  normalized_atoms_jsonl=$normalizedAtomsPath
  normalization_report=$normalizationReport
  absorption_status=$absorbStatus
  absorption_proof=$absorbProof
  ledger_state=$ledgerState
  memory_before=$memoryBefore
  memory_after=$memoryAfter
  memory_changed=($memoryBefore.cells -ne $memoryAfter.cells -or $memoryBefore.index -ne $memoryAfter.index -or $memoryBefore.manifest -ne $memoryAfter.manifest)
  repo_tracked_patch_raw=$false
  boundary='One patch executor. DryRun/MockCodex validation does not mutate active memory. Real memory progress counts only when ledger_state=ABSORBED.'
}
$reportPath="$runRoot/school_patch_executor_report.json"
WriteJson $reportPath $report 100
Write-Host "SCHOOL_PATCH_EXECUTOR_STATUS=$($report.status)"
Write-Host "SCHOOL_PATCH_EXECUTOR_REPORT=$reportPath"
Write-Host "SCHOOL_PATCH_EXECUTOR_LEDGER_STATE=$ledgerState"
Write-Host "SCHOOL_PATCH_EXECUTOR_CODEX_STATUS=$codexStatus"
Write-Host "SCHOOL_PATCH_EXECUTOR_MEMORY_CHANGED=$($report.memory_changed)"
Write-Host "SCHOOL_PATCH_EXECUTOR_LEDGER=$ledgerPath"
