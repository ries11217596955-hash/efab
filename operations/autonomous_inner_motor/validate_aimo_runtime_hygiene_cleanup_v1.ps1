$ErrorActionPreference='Stop'
$RepoRoot=(Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
Set-Location $RepoRoot
function Assert($Cond,[string]$Msg){ if(-not $Cond){ throw $Msg } }
function SizeMb([string]$Path){ if(-not(Test-Path $Path)){ return 0 }; $sum=(Get-ChildItem $Path -Recurse -File -ErrorAction SilentlyContinue|Measure-Object Length -Sum).Sum; return [Math]::Round($sum/1MB,2) }
$script='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
Assert (Test-Path $script) 'AIMO_SCRIPT_MISSING'
$text=Get-Content $script -Raw
foreach($needle in @('function Remove-AimoTransientRuntimeTrash','runtime_hygiene_cleanup','runtime_hygiene_cleanup_on_stop','.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')){ Assert ($text -like ('*'+$needle+'*')) ("SCRIPT_MARKER_MISSING:{0}" -f $needle) }
$tokens=$null;$errors=$null
$ast=[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $script),[ref]$tokens,[ref]$errors)
Assert (@($errors).Count -eq 0) 'AIMO_SCRIPT_PARSE_ERRORS'
$func=@($ast.FindAll({param($n) $n -is [System.Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Remove-AimoTransientRuntimeTrash'},$true))[0]
Assert ($null -ne $func) 'CLEANUP_FUNCTION_MISSING'
Invoke-Expression $func.Extent.Text
$activeManifest='.runtime/active_compact_semantic_memory_v1/manifest.json'
$activeCells='.runtime/active_compact_semantic_memory_v1/cells.jsonl'
$liveProof='tests/live_start/AIMO_DEFAULT_NO_GATE_LIVE_HOTSWAP_V1_PROOF.json'
Assert (Test-Path $activeManifest) 'ACTIVE_MANIFEST_MISSING'
Assert (Test-Path $activeCells) 'ACTIVE_CELLS_MISSING'
Assert (Test-Path $liveProof) 'LIVE_PROOF_MISSING'
$activeManifestHashBefore=(Get-FileHash -Algorithm SHA256 -Path $activeManifest).Hash
$activeCellsHashBefore=(Get-FileHash -Algorithm SHA256 -Path $activeCells).Hash
$liveProofHashBefore=(Get-FileHash -Algorithm SHA256 -Path $liveProof).Hash
$fakeTargets=@('.runtime/compact_memory_intake_v1/checkpoints/validator_fake_cleanup_v1','.runtime/file_atom_absorption/validator_fake_cleanup_v1')
foreach($t in $fakeTargets){
  New-Item -ItemType Directory -Force -Path $t|Out-Null
  Set-Content -Path (Join-Path $t 'fake.txt') -Value ('fake transient '+(Get-Date).ToString('o')) -Encoding UTF8
}
$beforeSize=(SizeMb '.runtime')
$r=Remove-AimoTransientRuntimeTrash -Reason 'validator_fake_transient_cleanup' -RunId 'validator_runtime_hygiene_cleanup_v1'
Assert (@($r.items).Count -eq 2) 'CLEANUP_ITEM_COUNT_BAD'
foreach($it in @($r.items)){ Assert ($it.tracked_count -eq 0) ("TRACKED_TARGET_BAD:{0}" -f $it.path); Assert ($it.deleted -eq $true) ("TARGET_NOT_DELETED:{0}" -f $it.path) }
foreach($t in @('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')){ Assert (-not(Test-Path $t)) ("TRANSIENT_TARGET_STILL_EXISTS:{0}" -f $t) }
Assert ((Get-FileHash -Algorithm SHA256 -Path $activeManifest).Hash -eq $activeManifestHashBefore) 'ACTIVE_MANIFEST_MUTATED'
Assert ((Get-FileHash -Algorithm SHA256 -Path $activeCells).Hash -eq $activeCellsHashBefore) 'ACTIVE_CELLS_MUTATED'
Assert ((Get-FileHash -Algorithm SHA256 -Path $liveProof).Hash -eq $liveProofHashBefore) 'LIVE_PROOF_MUTATED'
$afterSize=(SizeMb '.runtime')
$liveNow=@(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -and $_.CommandLine -like '*run_autonomous_inner_motor.ps1*' -and $_.CommandLine -like '*-Mode SandboxTestLife*' -and $_.CommandLine -like '*-RunId live_aimo*' -and $_.CommandLine -notlike '* -Command *' })
Assert (@($liveNow).Count -eq 1) ("LIVE_AIMO_COUNT_BAD:{0}" -f @($liveNow).Count)
Assert ([string]$liveNow[0].CommandLine -notlike '*UseSourceAgnosticPathSelectionLabGate*') 'LIVE_AIMO_SHOULD_STILL_BE_NO_GATE'
$out=[ordered]@{
  schema='aimo_runtime_hygiene_cleanup_validation_v1'
  status='PASS_AIMO_RUNTIME_HYGIENE_CLEANUP_V1'
  cleanup_function='Remove-AimoTransientRuntimeTrash'
  cleaned_paths=@('.runtime/compact_memory_intake_v1/checkpoints','.runtime/file_atom_absorption')
  before_runtime_size_mb=$beforeSize
  after_runtime_size_mb=$afterSize
  cleanup_result=$r
  preserved=[ordered]@{active_manifest=$true;active_cells=$true;live_proof=$true}
  live_pid_now=[int]$liveNow[0].ProcessId
  live_process_touched_by_validator=$false
  active_memory_mutated=$false
  boundary='Code is fixed for future AIMO cycles. Current live process must be hotswapped/restarted to load this code.'
  created_at=(Get-Date).ToString('o')
}
$proofPath='tests/autonomous_inner_motor/AIMO_RUNTIME_HYGIENE_CLEANUP_V1_PROOF.json'
$out|ConvertTo-Json -Depth 100|Set-Content $proofPath -Encoding UTF8
Write-Host 'VALIDATION_PASS=PASS_AIMO_RUNTIME_HYGIENE_CLEANUP_V1'
Write-Host ('PROOF_PATH='+$proofPath)
Write-Host ('RUNTIME_MB_AFTER='+$afterSize)
Write-Host 'LIVE_PROCESS_TOUCHED_BY_VALIDATOR=false'
