$ErrorActionPreference='Stop'
$errors=@()
function Add-Err([string]$e){ $script:errors += $e }
function WJson($path,$obj){ $dir=Split-Path $path -Parent; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; $json=($obj|ConvertTo-Json -Depth 40) -replace "`r`n","`n"; [System.IO.File]::WriteAllText((Join-Path (Get-Location).Path $path),$json.TrimEnd()+"`n",(New-Object System.Text.UTF8Encoding($false))) }
$plan='AGENT_BUILDER_INNATE_REFLEX_KERNEL_V1_PLAN.md'
if(-not(Test-Path $plan)){ Add-Err 'missing_plan' }
$text=if(Test-Path $plan){Get-Content $plan -Raw}else{''}
$required=@(
 'Bootload correction',
 'INNATE_REFLEX_BOOTLOAD_V1',
 'The permanent reflex kernel exists once in repo.',
 'It is not recreated on every agent launch.',
 'Do not write/recreate reflexes every run.',
 'canonical life startup reads permanent DNA',
 'innate_reflex_bootload.json',
 'reflex_kernel_loaded = true',
 'Do not write the full kernel every cycle.',
 'body_audit_reflex.callable = false',
 'CODEX_TASK_INNATE_REFLEX_BOOTLOAD_V1.md'
)
foreach($needle in $required){ if($text -notlike "*$needle*"){ Add-Err "plan_missing:$needle" } }
$status=if($errors.Count -eq 0){'PASS_INNATE_REFLEX_BOOTLOAD_PLAN_V1'}else{'FAIL_INNATE_REFLEX_BOOTLOAD_PLAN_V1'}
$proof=[ordered]@{
 schema='innate_reflex_bootload_plan_v1_validation'
 status=$status
 checked_at=(Get-Date).ToUniversalTime().ToString('o')
 plan=$plan
 errors=@($errors)
 boundary=[ordered]@{ plan_only=$true; codex_not_launched_by_validator=$true; implementation_not_done=$true; permanent_kernel_not_rewritten=$true; body_inspection_invoked=$false; active_memory_mutated=$false }
}
WJson 'tests/self_development/INNATE_REFLEX_BOOTLOAD_PLAN_V1_PROOF.json' $proof
Write-Host "STATUS=$status"
if($errors.Count -gt 0){ foreach($e in $errors){Write-Host "ERROR=$e"}; exit 1 }
