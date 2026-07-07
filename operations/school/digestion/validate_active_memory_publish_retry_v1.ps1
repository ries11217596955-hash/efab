$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/school/digestion/absorb_atom_file_via_digest_pipeline_v1.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'ABSORB_SCRIPT_PARSE_ERRORS'
foreach($name in @('EnsureDir','Invoke-FileSystemActionWithRetry','Publish-ActiveMemoryRootWithRetry')){
  $func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq $name }, $true))[0]
  Assert ($null -ne $func) "FUNCTION_MISSING:$name"
  Invoke-Expression $func.Extent.Text
}
$runId='active_memory_publish_retry_validation_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$sandbox=Join-Path '.runtime/validation' $runId
$target=Join-Path $sandbox 'active_memory'
$candidate=Join-Path $sandbox 'candidate_memory'
New-Item -ItemType Directory -Force -Path $target,$candidate | Out-Null
Set-Content -Path (Join-Path $target 'cells.jsonl') -Value '{"old":true}' -Encoding UTF8
Set-Content -Path (Join-Path $target 'manifest.json') -Value '{"status":"OLD","cell_count":1}' -Encoding UTF8
Set-Content -Path (Join-Path $candidate 'cells.jsonl') -Value '{"new":true}' -Encoding UTF8
Set-Content -Path (Join-Path $candidate 'manifest.json') -Value '{"status":"NEW","cell_count":1}' -Encoding UTF8
$lockFile=Join-Path $sandbox 'LOCK_READY.txt'
$lockScript=Join-Path $sandbox 'hold_lock.ps1'
$targetCells=(Resolve-Path (Join-Path $target 'cells.jsonl')).Path
@"
`$fs=[System.IO.File]::Open('$targetCells',[System.IO.FileMode]::Open,[System.IO.FileAccess]::Read,[System.IO.FileShare]::None)
try { Set-Content -Path '$lockFile' -Value 'ready' -Encoding UTF8; Start-Sleep -Seconds 2 } finally { `$fs.Dispose() }
"@ | Set-Content -Path $lockScript -Encoding UTF8
$lockProc=Start-Process -FilePath 'powershell' -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$lockScript) -PassThru -WindowStyle Hidden
$deadline=(Get-Date).AddSeconds(10)
while(-not(Test-Path $lockFile)){
  if((Get-Date) -gt $deadline){ throw 'LOCK_READY_TIMEOUT' }
  Start-Sleep -Milliseconds 100
}
$result=Publish-ActiveMemoryRootWithRetry -CandidateMemoryRoot $candidate -TargetMemoryRoot $target -MaxAttempts 20 -DelayMs 250
$lockProc.WaitForExit(10000) | Out-Null
Assert ($result.status -eq 'PASS_ACTIVE_MEMORY_ROOT_PUBLISHED_WITH_RETRY') "PUBLISH_STATUS_BAD:$($result.status)"
Assert ($result.remove_result.attempts -gt 1) 'REMOVE_DID_NOT_RETRY_UNDER_LOCK'
Assert (Test-Path (Join-Path $target 'manifest.json')) 'TARGET_MANIFEST_MISSING_AFTER_PUBLISH'
$newManifest=Get-Content (Join-Path $target 'manifest.json') -Raw | ConvertFrom-Json
Assert ($newManifest.status -eq 'NEW') 'TARGET_NOT_REPLACED_WITH_CANDIDATE'
Assert ((Get-Content (Join-Path $target 'cells.jsonl') -Raw) -match 'new') 'TARGET_CELLS_NOT_REPLACED'
$out=[ordered]@{
  schema='active_memory_publish_retry_validation_v1'
  status='PASS_ACTIVE_MEMORY_PUBLISH_RETRY_V1'
  script=$script
  remove_attempts=$result.remove_result.attempts
  copy_attempts=$result.copy_result.attempts
  lock_tolerant=$result.lock_tolerant
  target_replaced=$true
  school_live_touched=$false
  aimo_live_touched=$false
  created_at=(Get-Date).ToString('o')
}
$proof='tests/school/digestion/ACTIVE_MEMORY_PUBLISH_RETRY_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proof -Parent) | Out-Null
$out | ConvertTo-Json -Depth 30 | Set-Content -Path $proof -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_ACTIVE_MEMORY_PUBLISH_RETRY_V1'
Write-Host "PROOF_PATH=$proof"
Write-Host "REMOVE_ATTEMPTS=$($result.remove_result.attempts)"
Write-Host 'LIVE_PROCESS_TOUCHED=false'