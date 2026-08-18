param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][ValidateRange(1,1000000)][int]$SchoolCount,
  [ValidateSet('Test','Live')][string]$SchoolMode='Live',
  [string]$SchoolTopics='codex_school_task_template_strength',
  [Parameter(Mandatory=$true)][string]$AuthorityPassportBase64
)
$ErrorActionPreference='Stop'
Set-Location $RepoRoot
function Out-Result([hashtable]$Value){$Value|ConvertTo-Json -Depth 12 -Compress;exit 0}
function Block([string]$Reason,[hashtable]$Extra=@{}){$h=[ordered]@{status='PREP_BLOCKED';reason=$Reason;count=$SchoolCount;mode=$SchoolMode;topics=$SchoolTopics};foreach($k in $Extra.Keys){$h[$k]=$Extra[$k]};Out-Result $h}
try{$AuthorityPassportJson=[Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($AuthorityPassportBase64));$passport=$AuthorityPassportJson|ConvertFrom-Json}catch{Block 'AUTHORITY_PASSPORT_INVALID_JSON'}
$required=@('source','actor','action_class','target_surface','environment','scope','expiry','safety_boundary','checkpoint','rollback','validator')
$missing=@($required|Where-Object{$null-eq$passport.PSObject.Properties[$_] -or [string]::IsNullOrWhiteSpace([string]$passport.$_)})
if($missing.Count){Block 'AUTHORITY_PASSPORT_INCOMPLETE' @{missing=@($missing)}}
if([string]$passport.action_class -ne 'REMOTE_MUTATE'){Block 'AUTHORITY_ACTION_CLASS_NOT_REMOTE_MUTATE' @{action_class=[string]$passport.action_class}}
$school=@(Get-CimInstance Win32_Process|Where-Object{$_.ProcessId-ne$PID -and $_.CommandLine -and $_.CommandLine -notmatch 'invoke_builder_control_center_v1.ps1' -and $_.CommandLine -match '(?i)run_agent_school\.ps1|canonical_exact_count_cycle_real_|Invoke-SchoolWarehouseConsumer|codex_school_task_template_strength'})
if($school.Count){Block 'SCHOOL_ALREADY_RUNNING' @{process_count=$school.Count}}
$dirty=@(git status --porcelain=v1 -uall);if($dirty.Count){Block 'REPO_DIRTY' @{dirty=@($dirty)}}
$branch=(git branch --show-current).Trim();if([string]::IsNullOrWhiteSpace($branch)){Block 'DETACHED_HEAD'}
& git fetch --quiet origin; if($LASTEXITCODE-ne0){Block 'ORIGIN_FETCH_FAILED'}
$remoteRef='origin/'+$branch
& git rev-parse --verify $remoteRef 2>$null|Out-Null;if($LASTEXITCODE-ne0){Block 'REMOTE_BRANCH_MISSING' @{remote_ref=$remoteRef}}
$delta=((git rev-list --left-right --count ($remoteRef+'...HEAD')) -join '').Trim() -split '\s+'
if($delta.Count-lt2){Block 'REPO_DELTA_UNREADABLE'}
$behind=[int]$delta[0];$ahead=[int]$delta[1]
if($behind-gt0){Block 'REPO_BEHIND_OR_DIVERGED' @{behind=$behind;ahead=$ahead}}
$repairs=New-Object 'System.Collections.Generic.List[string]'
if($ahead-gt0){
  & git push --quiet origin ('HEAD:refs/heads/'+$branch);if($LASTEXITCODE-ne0){Block 'ORIGIN_PUSH_FAILED' @{ahead=$ahead}}
  & git fetch --quiet origin; if($LASTEXITCODE-ne0){Block 'ORIGIN_POST_PUSH_FETCH_FAILED'}
  $local=(git rev-parse HEAD).Trim();$remote=(git rev-parse $remoteRef).Trim();if($local-ne$remote){Block 'ORIGIN_POST_PUSH_MISMATCH' @{local=$local;remote=$remote}}
  [void]$repairs.Add('repo_synced')
}
$resumeRoot=Join-Path $RepoRoot '.runtime/school_resume_v1';$pending=Join-Path $resumeRoot 'pending_request.json';$stop=Join-Path $resumeRoot 'stop_request.json';$queue=Join-Path $resumeRoot 'queue'
$stale=New-Object 'System.Collections.Generic.List[string]';if(Test-Path $pending){[void]$stale.Add($pending)};if(Test-Path $stop){[void]$stale.Add($stop)};if(Test-Path $queue){Get-ChildItem $queue -File -Filter 'request_*.json' -ErrorAction SilentlyContinue|ForEach-Object{[void]$stale.Add($_.FullName)}}
$archive=$null
if($stale.Count){
  $archive=Join-Path $resumeRoot ('superseded/'+(Get-Date -Format 'yyyyMMdd_HHmmss_fff')+'_'+[guid]::NewGuid().ToString('N'));New-Item -ItemType Directory -Force -Path $archive|Out-Null
  foreach($src in $stale){$name=[IO.Path]::GetFileName($src);$dest=Join-Path $archive $name;if(Test-Path $dest){$dest=Join-Path $archive (([IO.Path]::GetFileNameWithoutExtension($name))+'_'+[guid]::NewGuid().ToString('N')+[IO.Path]::GetExtension($name))};Move-Item -LiteralPath $src -Destination $dest -Force}
  [void]$repairs.Add('recovery_state_archived')
}
$dirtyAfter=@(git status --porcelain=v1 -uall);if($dirtyAfter.Count){Block 'REPO_DIRTY_AFTER_PREP' @{dirty=@($dirtyAfter)}}
Out-Result ([ordered]@{status='PREPARED';count=$SchoolCount;mode=$SchoolMode;topics=$SchoolTopics;branch=$branch;head=(git rev-parse HEAD).Trim();remote_head=(git rev-parse $remoteRef).Trim();behind=0;ahead_after=0;repairs=@($repairs);recovery_archive=$archive;authority_source=[string]$passport.source})
