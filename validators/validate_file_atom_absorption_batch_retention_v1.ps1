$ErrorActionPreference='Stop'
$scriptPath='operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1'
if(-not(Test-Path $scriptPath)){ throw "MISSING_SCRIPT:$scriptPath" }
$text=Get-Content $scriptPath -Raw
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$Message){ $script:errors.Add($Message) | Out-Null }
function Write-CleanText([string]$Path,[string]$Text){
  $dir=Split-Path $Path -Parent
  if($dir){ New-Item -ItemType Directory -Force -Path $dir | Out-Null }
  $lines=@($Text -split "`r?`n" | ForEach-Object { $_.TrimEnd() })
  while($lines.Count -gt 0 -and $lines[$lines.Count-1] -eq ''){
    if($lines.Count -eq 1){ $lines=@(); break }
    $lines=@($lines[0..($lines.Count-2)])
  }
  $clean=($lines -join "`n") + "`n"
  $utf8NoBom=New-Object System.Text.UTF8Encoding($false)
  $fullPath=if([System.IO.Path]::IsPathRooted($Path)){ $Path } else { Join-Path (Get-Location).Path $Path }
  [System.IO.File]::WriteAllText($fullPath,$clean,$utf8NoBom)
}
function Write-CleanJson([string]$Path,$Obj,[int]$Depth=10){ Write-CleanText $Path ($Obj | ConvertTo-Json -Depth $Depth) }
$checks=[ordered]@{
  keep_candidate_switch='KeepCandidateMemoryRoot'
  cleanup_function='function Remove-SuccessfulCandidateMemoryRoot'
  batch_policy='delete_per_micro_batch_after_successful_publish'
  active_equals_guard='REFUSE_DELETE_CANDIDATE_EQUALS_ACTIVE_MEMORY_ROOT'
  active_inside_guard='REFUSE_DELETE_CANDIDATE_INSIDE_ACTIVE_MEMORY_ROOT'
  publish_call='Publish-ActiveMemoryRootWithRetry -CandidateMemoryRoot $candidateMemoryRoot -TargetMemoryRoot $targetMemoryRoot'
  removed_report_field='candidate_memory_root_removed'
  active_cleanup_false='active_memory_cleanup_touched=$false'
  retention_report_policy="batch_retention_policy='per_micro_batch_cleanup_after_successful_publish'"
  host_output='CANDIDATE_MEMORY_ROOT_REMOVED=$($report.candidate_memory_root_removed)'
}
foreach($name in $checks.Keys){
  $needle=$checks[$name]
  if($text -notlike "*$needle*"){ Add-Err "missing:$($name):$needle" }
}
$publishIndex=$text.IndexOf('Publish-ActiveMemoryRootWithRetry -CandidateMemoryRoot $candidateMemoryRoot -TargetMemoryRoot $targetMemoryRoot')
$cleanupIndex=$text.IndexOf('Remove-SuccessfulCandidateMemoryRoot -CandidateMemoryRoot $candidateMemoryRoot -TargetMemoryRoot $targetMemoryRoot -RunRoot $runRoot')
$reportIndex=$text.IndexOf('$report=[ordered]@{')
$writeJsonIndex=$text.IndexOf('WriteJson $proofPath $report 80')
if($publishIndex -lt 0 -or $cleanupIndex -lt 0 -or $reportIndex -lt 0 -or $writeJsonIndex -lt 0){ Add-Err 'ordering_anchor_missing' }
else {
  if(-not($publishIndex -lt $cleanupIndex)){ Add-Err 'cleanup_not_after_publish' }
  if(-not($cleanupIndex -lt $reportIndex)){ Add-Err 'cleanup_not_before_report_build' }
  if(-not($reportIndex -lt $writeJsonIndex)){ Add-Err 'report_not_before_writejson' }
}
$status=if($errors.Count -eq 0){'PASS_FILE_ATOM_ABSORPTION_BATCH_RETENTION_V1'}else{'FAIL_FILE_ATOM_ABSORPTION_BATCH_RETENTION_V1'}
$out=[ordered]@{
  schema='file_atom_absorption_batch_retention_static_validation_v1'
  status=$status
  checked_at=(Get-Date).ToString('o')
  script=$scriptPath
  boundary=[ordered]@{
    validates_static_policy=$true
    runs_absorption=$false
    touches_active_memory=$false
    deletes_files=$false
  }
  expected_behavior='per micro-batch: publish candidate to active memory, remove only that successful run candidate root, keep reports/proofs and failed runs'
  errors=@($errors)
}
$proofPath='tests/self_development/FILE_ATOM_ABSORPTION_BATCH_RETENTION_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proofPath -Parent) | Out-Null
Write-CleanJson $proofPath $out 10
Write-Host "STATUS=$status"
Write-Host "PROOF_PATH=$proofPath"
foreach($e in $errors){ Write-Host "ERROR=$e" }
if($errors.Count -gt 0){ exit 1 }
