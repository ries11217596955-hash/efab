param(
  [Parameter(Mandatory=$true)][string]$PackRoot,
  [string]$BridgeRoot='C:\EFAB\bridge',
  [string]$RepoRoot='C:\EFAB\efab',
  [string]$PrimaryTokenPath='C:\ProgramData\EFAB\bridge_action_token.txt',
  [string]$RescueRoot='C:\ProgramData\EFAB-Rescue',
  [string]$NgrokRoot='C:\ProgramData\EFAB-Ngrok',
  [string]$PrimaryRoot='C:\ProgramData\EFAB-Primary',
  [string]$RebootProofRoot='C:\ProgramData\EFAB-Reboot-Proof',
  [string]$NgrokConfigPath,
  [string]$PythonExe,
  [string]$NgrokExe,
  [switch]$SkipDependencyInstall,
  [switch]$PreflightOnly,
  [switch]$StageOnly
)
$ErrorActionPreference='Stop'
function Resolve-Executable([string]$Explicit,[string[]]$Names){if($Explicit){if(Test-Path $Explicit){return (Resolve-Path $Explicit).Path};throw "EXECUTABLE_NOT_FOUND: $Explicit"};foreach($n in $Names){$c=Get-Command $n -ErrorAction SilentlyContinue;if($c){return $c.Source}};return $null}
function New-Token([string]$Path){$parent=Split-Path $Path -Parent;New-Item -ItemType Directory -Force -Path $parent|Out-Null;[byte[]]$b=New-Object byte[] 32;$rng=New-Object Security.Cryptography.RNGCryptoServiceProvider;$rng.GetBytes($b);$rng.Dispose();$v=($b|ForEach-Object{$_.ToString('x2')}) -join '';[IO.File]::WriteAllText($Path,$v)}
$required=@('primary','recovery','rescue','ngrok','boot','reboot_proof')
$blockers=@()
if(-not(Test-Path $PackRoot)){$blockers+='PACK_ROOT_MISSING'}
foreach($r in $required){if(-not(Test-Path (Join-Path $PackRoot $r))){$blockers+="PACK_COMPONENT_MISSING:$r"}}
$python=Resolve-Executable $PythonExe @('python.exe','py.exe');if(-not $python){$blockers+='PYTHON_NOT_FOUND'}
$ngrok=Resolve-Executable $NgrokExe @('ngrok.exe');if(-not $ngrok){$blockers+='NGROK_NOT_FOUND'}
if(-not $NgrokConfigPath -or -not(Test-Path $NgrokConfigPath)){$blockers+='NGROK_CONFIG_MISSING'}
$admin=([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if(-not $admin){$blockers+='ADMIN_REQUIRED'}
$pre=[ordered]@{status=if($blockers.Count){'BLOCKED_PREFLIGHT'}else{'PREFLIGHT_PASS'};pack_root=$PackRoot;bridge_root=$BridgeRoot;python=$python;ngrok=$ngrok;blockers=$blockers;files_changed_before_preflight_pass='NO'}
$pre|ConvertTo-Json -Depth 5
if($blockers.Count){exit 2}
if($PreflightOnly){exit 0}
$checkpoint='C:\ProgramData\EFAB-Migration-Checkpoint\'+(Get-Date -Format 'yyyyMMdd-HHmmss');New-Item -ItemType Directory -Force -Path $checkpoint|Out-Null
foreach($p in @($BridgeRoot,$RescueRoot,$NgrokRoot,$PrimaryRoot,$RebootProofRoot)){if(Test-Path $p){Copy-Item $p (Join-Path $checkpoint ((Split-Path $p -Leaf))) -Recurse -Force}}
New-Item -ItemType Directory -Force -Path $BridgeRoot,$RescueRoot,$NgrokRoot,$PrimaryRoot,$RebootProofRoot,(Split-Path $PrimaryTokenPath -Parent)|Out-Null
Copy-Item (Join-Path $PackRoot 'primary\*') $BridgeRoot -Recurse -Force
New-Item -ItemType Directory -Force -Path (Join-Path $BridgeRoot 'recovery_gateway_v1')|Out-Null
Copy-Item (Join-Path $PackRoot 'recovery\*') (Join-Path $BridgeRoot 'recovery_gateway_v1') -Recurse -Force
Copy-Item (Join-Path $PackRoot 'rescue\*') $RescueRoot -Recurse -Force
Copy-Item (Join-Path $PackRoot 'ngrok\*') $NgrokRoot -Recurse -Force
Copy-Item (Join-Path $PackRoot 'boot\*') $PrimaryRoot -Recurse -Force
Copy-Item (Join-Path $PackRoot 'reboot_proof\*') $RebootProofRoot -Recurse -Force
Copy-Item $NgrokConfigPath (Join-Path $NgrokRoot 'ngrok.yml') -Force
if(-not(Test-Path $PrimaryTokenPath)){New-Token $PrimaryTokenPath}
$rescueToken=Join-Path $RescueRoot 'rescue_token.txt';if(-not(Test-Path $rescueToken)){New-Token $rescueToken}
Copy-Item $PrimaryTokenPath (Join-Path $BridgeRoot 'recovery_gateway_v1\bridge_token.txt') -Force
foreach($f in @((Join-Path $BridgeRoot 'recovery_gateway_v1\recovery_supervisor.ps1'),(Join-Path $PrimaryRoot 'primary_boot.ps1'))){$text=[IO.File]::ReadAllText($f);$text=$text.Replace('H:\bridge',$BridgeRoot);[IO.File]::WriteAllText($f,$text,[Text.UTF8Encoding]::new($false))}
if($StageOnly){
  $stageProof=[ordered]@{status='STAGE_ONLY_PASS';bridge_root=$BridgeRoot;rescue_root=$RescueRoot;ngrok_root=$NgrokRoot;primary_root=$PrimaryRoot;reboot_proof_root=$RebootProofRoot;primary_token_exists=(Test-Path $PrimaryTokenPath);rescue_token_exists=(Test-Path $rescueToken);task_registration='SKIPPED';process_start='SKIPPED';dependency_install='SKIPPED'}
  $stageProof|ConvertTo-Json -Depth 5
  exit 0
}
if(-not $SkipDependencyInstall){& $python -m pip install -e $BridgeRoot;if($LASTEXITCODE -ne 0){throw 'PIP_INSTALL_FAILED'}}
$principal=New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
function Register-EfabTask($Name,$Script,$Working,$Triggers,$Arguments=''){$arg='-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "'+$Script+'" '+$Arguments;$a=New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $arg -WorkingDirectory $Working;$s=New-ScheduledTaskSettingsSet -StartWhenAvailable -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1) -ExecutionTimeLimit ([TimeSpan]::Zero);Register-ScheduledTask -TaskName $Name -Action $a -Trigger $Triggers -Settings $s -Principal $principal -Force|Out-Null}
$boot=New-ScheduledTaskTrigger -AtStartup
$minute=New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Minutes 1)
Register-EfabTask 'EFAB Bridge Boot SYSTEM' (Join-Path $PrimaryRoot 'primary_boot.ps1') $PrimaryRoot @($boot)
Register-EfabTask 'EFAB Recovery Gateway SYSTEM' (Join-Path $BridgeRoot 'recovery_gateway_v1\recovery_supervisor.ps1') (Join-Path $BridgeRoot 'recovery_gateway_v1') @($boot,$minute) '-Once'
Register-EfabTask 'EFAB Rescue Control SYSTEM' (Join-Path $RescueRoot 'rescue_gateway.ps1') $RescueRoot @($boot) '-Port 18789'
Register-EfabTask 'EFAB Rescue Watchdog SYSTEM' (Join-Path $RescueRoot 'rescue_watchdog.ps1') $RescueRoot @($minute)
Register-EfabTask 'EFAB Ngrok Primary SYSTEM' (Join-Path $NgrokRoot 'ngrok_launcher.ps1') $NgrokRoot @($boot)
Register-EfabTask 'EFAB Ngrok Watchdog SYSTEM' (Join-Path $NgrokRoot 'ngrok_watchdog.ps1') $NgrokRoot @($minute)
Register-EfabTask 'EFAB Post Reboot Validator SYSTEM' (Join-Path $RebootProofRoot 'post_reboot_validator.ps1') $RebootProofRoot @($boot)
foreach($n in @('EFAB Bridge Boot SYSTEM','EFAB Recovery Gateway SYSTEM','EFAB Rescue Control SYSTEM','EFAB Rescue Watchdog SYSTEM','EFAB Ngrok Primary SYSTEM','EFAB Ngrok Watchdog SYSTEM')){Start-ScheduledTask -TaskName $n -ErrorAction SilentlyContinue}
[ordered]@{status='INSTALLED_PENDING_VALIDATION';checkpoint=$checkpoint;bridge_root=$BridgeRoot;repo_root=$RepoRoot;primary_token=$PrimaryTokenPath;rescue_token=$rescueToken}|ConvertTo-Json -Depth 5
