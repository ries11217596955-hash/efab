$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$tokens=$null; $errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
$func=@($ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Get-ActiveMemoryState' }, $true))[0]
Assert ($null -ne $func) 'GET_ACTIVE_MEMORY_STATE_FUNCTION_MISSING'
Invoke-Expression $func.Extent.Text
$runId='aimo_memory_backoff_validation_' + (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssZ')
$sandbox=Join-Path '.runtime/validation' $runId
New-Item -ItemType Directory -Force -Path $sandbox | Out-Null
$missingRoot=Join-Path $sandbox 'missing_memory_root'
$missingResult=Get-ActiveMemoryState -MemoryRoot $missingRoot -MaxRetries 1 -RetryDelayMs 1
Assert ($missingResult.available -eq $false) 'MISSING_AVAILABLE_NOT_FALSE'
Assert ($missingResult.status -eq 'MEMORY_TEMPORARILY_UNAVAILABLE') "MISSING_STATUS_BAD:$($missingResult.status)"
Assert ($missingResult.runtime_ready -eq $false) 'MISSING_RUNTIME_READY_NOT_FALSE'
Assert ($missingResult.backoff_recommended -eq $true) 'MISSING_BACKOFF_NOT_TRUE'
Assert (@($missingResult.missing_paths).Count -ge 1) 'MISSING_PATHS_EMPTY'
$goodRoot=Join-Path $sandbox 'good_memory_root'
New-Item -ItemType Directory -Force -Path $goodRoot | Out-Null
$manifest=[ordered]@{ status='PASS_TEST_MEMORY'; run_id=$runId; runtime_ready=$false; cell_count=2; cells_sha256='TEST_CELLS_SHA256_FROM_MANIFEST' }
$manifest | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $goodRoot 'manifest.json') -Encoding UTF8
@('{"cell":"one"}','{"cell":"two"}') | Set-Content -Path (Join-Path $goodRoot 'cells.jsonl') -Encoding UTF8
$goodResult=Get-ActiveMemoryState -MemoryRoot $goodRoot -MaxRetries 1 -RetryDelayMs 1
Assert ($goodResult.available -eq $true) 'GOOD_AVAILABLE_NOT_TRUE'
Assert ($goodResult.status -eq 'ACTIVE_MEMORY_AVAILABLE') "GOOD_STATUS_BAD:$($goodResult.status)"
Assert ($goodResult.run_id -eq $runId) 'GOOD_RUN_ID_MISMATCH'
Assert ($goodResult.cell_count -eq 2) "GOOD_CELL_COUNT_BAD:$($goodResult.cell_count)"
Assert ($goodResult.cells_sha256 -eq 'TEST_CELLS_SHA256_FROM_MANIFEST') 'GOOD_HASH_NOT_FROM_MANIFEST'
$out=[ordered]@{
  schema='active_memory_state_backoff_validation_v1'
  status='PASS_ACTIVE_MEMORY_STATE_BACKOFF_V1'
  script=$script
  missing_result=$missingResult
  good_result=[ordered]@{ available=$goodResult.available; status=$goodResult.status; run_id=$goodResult.run_id; cell_count=$goodResult.cell_count; manifest_status=$goodResult.manifest_status }
  school_touched=$false
  live_process_touched=$false
  created_at=(Get-Date).ToString('o')
}
$proof='tests/autonomous_inner_motor/ACTIVE_MEMORY_STATE_BACKOFF_V1_PROOF.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proof -Parent) | Out-Null
$out | ConvertTo-Json -Depth 30 | Set-Content -Path $proof -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_ACTIVE_MEMORY_STATE_BACKOFF_V1'
Write-Host "PROOF_PATH=$proof"
Write-Host 'SCHOOL_TOUCHED=false'