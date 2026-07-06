param(
  [Parameter(Mandatory=$true)][ValidateSet('Start','Status','Stop')][string]$Action,
  [ValidateSet('Test','Live')][string]$Mode = '',
  [string]$TopicsPlan = 'operations/school/curriculum/topics/builder_night_school_topics_v1.json',
  [ValidateRange(0,1000000)][int]$Count = 0,
  [ValidateRange(0,1000)][int]$MaxCycles = 0,
  [Alias('MaxRuntimeMinutes')][ValidateRange(0,10080)][double]$MaxCycleRuntimeMinutes = 0,
  [ValidateRange(0,10080)][double]$MaxTotalRuntimeMinutes = 0,
  [string]$PolicyPath = 'operations/school/autonomous_school_cycle_policy.json'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if(-not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=60){ $d=Split-Path $Path -Parent; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function ActiveControllerProcesses(){ @(Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -match 'run_autonomous_school_cycle_v1.ps1' } | ForEach-Object{ [ordered]@{ pid=$_.ProcessId; command_line=$_.CommandLine } }) }
function LatestLaunch(){ $root='.runtime/autonomous_school_control/launches'; if(-not (Test-Path $root)){ return $null }; Get-ChildItem $root -Filter *.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
function LatestProof(){ $root='.runtime/autonomous_school_cycles'; if(-not (Test-Path $root)){ return $null }; Get-ChildItem $root -Recurse -Filter AUTONOMOUS_SCHOOL_CYCLE_RUN_V1.json | Sort-Object LastWriteTime -Descending | Select-Object -First 1 }
if(-not (Test-Path $PolicyPath)){ throw "AUTONOMOUS_SCHOOL_POLICY_MISSING:$PolicyPath" }
$policy=Get-Content $PolicyPath -Raw|ConvertFrom-Json
$stopFile=[string]$policy.stop_file
if([string]::IsNullOrWhiteSpace($stopFile)){ $stopFile='.runtime/school_control/STOP_AUTONOMOUS_SCHOOL' }
if($Action -eq 'Stop'){
  EnsureDir (Split-Path $stopFile -Parent)
  [ordered]@{ schema='autonomous_school_stop_request_v1'; status='STOP_REQUESTED'; created_at=(Get-Date).ToString('o'); stop_file=$stopFile; boundary='Soft stop only. Active school cycle is not hard-killed; controller stops before next cycle.' } | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $stopFile -Encoding UTF8
  $active=@(ActiveControllerProcesses)
  Write-Host 'SCHOOL_CONTROL_STATUS=STOP_REQUESTED'
  Write-Host "SCHOOL_CONTROL_STOP_FILE=$stopFile"
  Write-Host "SCHOOL_CONTROL_ACTIVE_CONTROLLER_COUNT=$($active.Count)"
  return
}
if($Action -eq 'Status'){
  $active=@(ActiveControllerProcesses)
  $launch=LatestLaunch
  $proof=LatestProof
  Write-Host 'SCHOOL_CONTROL_STATUS=STATUS_OK'
  Write-Host "SCHOOL_CONTROL_ACTIVE_CONTROLLER_COUNT=$($active.Count)"
  if($active.Count -gt 0){ $active|ForEach-Object{ Write-Host "SCHOOL_CONTROL_ACTIVE_PID=$($_.pid)" } }
  Write-Host "SCHOOL_CONTROL_STOP_FILE_EXISTS=$(Test-Path $stopFile)"
  if($launch){ Write-Host "SCHOOL_CONTROL_LATEST_LAUNCH=$($launch.FullName)" }
  if($proof){
    $p=Get-Content $proof.FullName -Raw|ConvertFrom-Json
    Write-Host "SCHOOL_CONTROL_LATEST_PROOF=$($proof.FullName)"
    Write-Host "SCHOOL_CONTROL_LATEST_PROOF_STATUS=$($p.status)"
    Write-Host "SCHOOL_CONTROL_LATEST_COMPLETED_CYCLES=$($p.completed_cycles)"
  }
  return
}
# Start
if(-not [string]::IsNullOrWhiteSpace($stopFile) -and (Test-Path $stopFile)){ Remove-Item -LiteralPath $stopFile -Force }
$active=@(ActiveControllerProcesses)
if($active.Count -gt 0){ throw 'AUTONOMOUS_SCHOOL_CONTROLLER_ALREADY_ACTIVE' }
if([string]::IsNullOrWhiteSpace($Mode)){ $Mode=[string]$policy.default_mode }
if([string]::IsNullOrWhiteSpace($Mode)){ $Mode='Live' }
if($Count -le 0){ $Count=[int]$policy.default_count }
if($MaxCycleRuntimeMinutes -le 0){ if($policy.PSObject.Properties['default_max_cycle_runtime_minutes']){ $MaxCycleRuntimeMinutes=[double]$policy.default_max_cycle_runtime_minutes } else { $MaxCycleRuntimeMinutes=[double]$policy.default_max_runtime_minutes } }
if($Count -lt 1){ throw 'COUNT_NOT_RESOLVED' }
if($MaxCycleRuntimeMinutes -le 0){ throw 'MAX_CYCLE_RUNTIME_NOT_RESOLVED' }
if(-not (Test-Path $TopicsPlan)){ throw "TOPICS_PLAN_MISSING:$TopicsPlan" }
$launchId="autonomous_school_launch_$(Get-Date -Format yyyyMMdd_HHmmss)"
$launchRoot='.runtime/autonomous_school_control/launches'
EnsureDir $launchRoot
$stdout=".runtime/autonomous_school_control/${launchId}.stdout.log"
$stderr=".runtime/autonomous_school_control/${launchId}.stderr.log"
EnsureDir (Split-Path $stdout -Parent)
$args=@('-NoProfile','-ExecutionPolicy','Bypass','-File','operations/school/run_autonomous_school_cycle_v1.ps1','-Count',([string]$Count),'-Mode',$Mode,'-TopicsPlan',$TopicsPlan,'-MaxCycleRuntimeMinutes',([string]$MaxCycleRuntimeMinutes),'-PolicyPath',$PolicyPath,'-RequireRepoClean')
if($MaxCycles -gt 0){ $args += @('-MaxCycles',([string]$MaxCycles)) }
if($MaxTotalRuntimeMinutes -gt 0){ $args += @('-MaxTotalRuntimeMinutes',([string]$MaxTotalRuntimeMinutes)) }
$p=Start-Process -FilePath 'powershell' -ArgumentList $args -WorkingDirectory $repoRoot -RedirectStandardOutput $stdout -RedirectStandardError $stderr -PassThru
$record=[ordered]@{
  schema='autonomous_school_launch_record_v1'
  status='LAUNCHED'
  launch_id=$launchId
  pid=$p.Id
  mode=$Mode
  count=$Count
  max_cycles=$MaxCycles
  max_cycle_runtime_minutes=$MaxCycleRuntimeMinutes
  max_total_runtime_minutes=$MaxTotalRuntimeMinutes
  topics_plan=$TopicsPlan
  policy_path=$PolicyPath
  stop_file=$stopFile
  stdout=$stdout
  stderr=$stderr
  started_at=(Get-Date).ToString('o')
  command=('powershell ' + ($args -join ' '))
  boundary='Detached start only. Stop is soft via stop file; no hard kill is performed by control v1.'
}
$recordPath=Join-Path $launchRoot "$launchId.json"
WriteJson $recordPath $record 60
Write-Host 'SCHOOL_CONTROL_STATUS=LAUNCHED'
Write-Host "SCHOOL_CONTROL_LAUNCH_ID=$launchId"
Write-Host "SCHOOL_CONTROL_PID=$($p.Id)"
Write-Host "SCHOOL_CONTROL_RECORD=$recordPath"
Write-Host "SCHOOL_CONTROL_STDOUT=$stdout"
Write-Host "SCHOOL_CONTROL_STDERR=$stderr"
Write-Host "SCHOOL_CONTROL_COUNT=$Count"
Write-Host "SCHOOL_CONTROL_MAX_CYCLE_RUNTIME_MINUTES=$MaxCycleRuntimeMinutes"
Write-Host "SCHOOL_CONTROL_MODE=$Mode"