$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 50) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$task='operations/autonomous_inner_motor/CODEX_TASK_INNATE_REFLEX_BOOTLOAD_V1.md'
if(-not(Test-Path $task)){ Add-Err 'missing_bootload_codex_task' }
$text=if(Test-Path $task){Get-Content $task -Raw}else{''}
$required=@(
 'READY_FOR_CODEX / NOT_RUN',
 'INNATE_REFLEX_BOOTLOAD_V1',
 'permanent kernel is stored once',
 'canonical life boot-loads it once per run',
 'PREFLIGHT_PASS',
 'Files changed before PREFLIGHT_PASS: YES/NO',
 'Allowed modifications',
 'Allowed new files',
 'Forbidden scope',
 'Do not modify:',
 'innate_reflex_bootload.json',
 'Do not write the full kernel every cycle.',
 'validators/validate_innate_reflex_bootload_v1.ps1',
 'PASS_INNATE_REFLEX_BOOTLOAD_V1',
 'Bootload writes full matrix every cycle: YES/NO'
)
foreach($needle in $required){ if($text -notlike "*$needle*"){ Add-Err "task_missing:$needle" } }
$forbiddenMust=@('operations/autonomous_inner_motor/start_agent_life_v1.ps1','operations/autonomous_inner_motor/innate_reflex_kernel_v1.json','operations/body_self_inspection/*','.runtime/active_compact_semantic_memory_v1')
foreach($needle in $forbiddenMust){ if($text -notlike "*$needle*"){ Add-Err "forbidden_missing:$needle" } }
$status=if($errors.Count -eq 0){'PASS_INNATE_REFLEX_BOOTLOAD_CODEX_TASK_V1'}else{'FAIL_INNATE_REFLEX_BOOTLOAD_CODEX_TASK_V1'}
$proof=[ordered]@{
 schema='innate_reflex_bootload_codex_task_v1_validation'
 status=$status
 checked_at=(Get-Date).ToUniversalTime().ToString('o')
 task=$task
 errors=@($errors)
 boundary=[ordered]@{ task_only=$true; codex_not_launched_by_validator=$true; implementation_not_done=$true; body_inspection_invoked=$false; active_memory_mutated=$false; permanent_kernel_not_mutated=$true }
}
WJson 'tests/self_development/INNATE_REFLEX_BOOTLOAD_CODEX_TASK_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
