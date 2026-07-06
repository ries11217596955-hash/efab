param([Parameter(Mandatory=$true)][string]$ReadyLanePath)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=80){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function IsExplicitPlaceholder($a){
  $joined=@($a.topic,$a.objective,$a.expected_behavior,$a.exercise,$a.negative_trap,$a.validator_hint,$a.behavior_use_proof_target,$a.return_to_parent) -join ' '
  if($joined -match '(?i)same-as-above|lorem|TODO'){ return $true }
  $topic=([string]$a.topic).Trim().ToLowerInvariant()
  if($topic -in @('placeholder','generic','filler','todo','same-as-above')){ return $true }
  if($topic -match '^(placeholder|generic|filler)[_\- ]?(text|candidate|lesson)?$'){ return $true }
  return $false
}
if(-not (Test-Path $ReadyLanePath)){ throw "READY_LANE_MISSING: $ReadyLanePath" }
$stream=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1.json -Raw | ConvertFrom-Json
$streamV=Get-Content operations/reports/STREAMING_SCHOOL_TO_ABSORPTION_VALIDATION_V1.json -Raw | ConvertFrom-Json
$consistency=Get-Content operations/reports/CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1.json -Raw | ConvertFrom-Json
$atoms=@(); $lineNo=0; $parseErrors=@()
foreach($line in Get-Content $ReadyLanePath){
  if([string]::IsNullOrWhiteSpace($line)){ continue }
  $lineNo++
  try{ $a=$line|ConvertFrom-Json; $a | Add-Member -NotePropertyName _ready_line -NotePropertyValue $lineNo -Force; $atoms += $a }catch{ $parseErrors += $lineNo }
}
$issues=@(); $weak=@(); $explicitPlaceholder=@()
if($parseErrors.Count -gt 0){ $issues += 'parse_errors' }
if($stream.status -ne 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_PIPELINE_V1'){ $issues += 'streaming_pipeline_not_pass' }
if($streamV.status -ne 'PASS_STREAMING_SCHOOL_TO_ABSORPTION_VALIDATION_V1'){ $issues += 'streaming_validation_not_pass' }
if($stream.active_memory_mutated -ne $false){ $issues += 'streaming_mutated_active_memory' }
if($consistency.status -ne 'PASS_CODEX_CURRICULUM_CONTRACT_CONSISTENCY_V1'){ $issues += 'contract_consistency_not_pass' }
if([int]$stream.ready_atoms_total -ne $atoms.Count){ $issues += 'ready_count_mismatch_stream_report' }
$topicDup=@($atoms | Group-Object topic | Where-Object {$_.Count -gt 1} | ForEach-Object {$_.Name})
$keyDup=@($atoms | Group-Object duplicate_key | Where-Object {$_.Count -gt 1} | ForEach-Object {$_.Name})
$idDup=@($atoms | Group-Object atom_id | Where-Object {$_.Count -gt 1} | ForEach-Object {$_.Name})
if($topicDup.Count -gt 0){ $issues += 'duplicate_topics' }
if($keyDup.Count -gt 0){ $issues += 'duplicate_keys' }
if($idDup.Count -gt 0){ $issues += 'duplicate_atom_ids' }
$required=@('atom_id','source_candidate_id','topic','level','source_mode','objective','expected_behavior','exercise','negative_trap','validator_hint','behavior_use_proof_target','return_to_parent','duplicate_key','source_batch_path')
foreach($a in $atoms){
  foreach($f in $required){ if(-not ($a.PSObject.Properties.Name -contains $f) -or $null -eq $a.$f -or ([string]$a.$f).Trim().Length -eq 0){ $weak += "$($a.atom_id):missing_or_empty_$f" } }
  try{ $lvl=[int]$a.level; if($lvl -lt 1){ $weak += "$($a.atom_id):bad_level" } } catch { $weak += "$($a.atom_id):bad_level" }
  if(([string]$a.exercise).Length -lt 20){ $weak += "$($a.atom_id):weak_exercise" }
  if(([string]$a.negative_trap).Length -lt 10){ $weak += "$($a.atom_id):weak_negative_trap" }
  if(([string]$a.behavior_use_proof_target).Length -lt 20){ $weak += "$($a.atom_id):weak_behavior_use_proof_target" }
  if(IsExplicitPlaceholder $a){ $explicitPlaceholder += $a.atom_id }
  if($a.source_batch_path -and -not (Test-Path ([string]$a.source_batch_path))){ $weak += "$($a.atom_id):source_batch_missing" }
}
if($weak.Count -gt 0){ $issues += 'weak_atoms' }
if($explicitPlaceholder.Count -gt 0){ $issues += 'explicit_placeholder_atoms' }
$directed=@($atoms|Where-Object {$_.source_mode -eq 'directed_curriculum'}).Count
$experience=@($atoms|Where-Object {$_.source_mode -eq 'experience_curriculum'}).Count
if($directed -lt 1){ $issues += 'no_directed_curriculum' }
if($experience -lt 1){ $issues += 'no_experience_curriculum' }
$status=if($issues.Count -eq 0){'PASS_CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1'}else{'FAIL_CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1'}
$report=[pscustomObject]@{
  schema='codex_curriculum_ready_lane_promotion_gate_v1'
  status=$status
  runtime_ready=$false
  ready_lane_path=$ReadyLanePath
  ready_atom_count=$atoms.Count
  unique_topic_count=@($atoms|Select-Object -ExpandProperty topic -Unique).Count
  directed_count=$directed
  experience_count=$experience
  duplicate_topics=@($topicDup)
  duplicate_keys=@($keyDup)
  duplicate_atom_ids=@($idDup)
  weak_atoms=@($weak)
  explicit_placeholder_atoms=@($explicitPlaceholder)
  streaming_status=$stream.status
  streaming_validation_status=$streamV.status
  contract_consistency_status=$consistency.status
  active_memory_mutated=$false
  promotion_allowed=($issues.Count -eq 0)
  issues=@($issues)
  boundary='Ready-lane promotion gate only. Does not mutate active memory. Passing this gate allows the next explicit active promotion step.'
}
WriteJson 'operations/reports/CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1.json' $report 100
$md=@('# CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1','',"Status: $status",'Runtime ready: false','',"Ready atoms: $($atoms.Count)","Unique topics: $($report.unique_topic_count)","Directed: $directed","Experience: $experience","Promotion allowed: $($report.promotion_allowed)","Issues: $($issues.Count)",'',"Ready lane: $ReadyLanePath",'', 'Boundary: gate only; no active memory mutation.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CURRICULUM_READY_LANE_PROMOTION_GATE_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "READY_LANE_GATE_STATUS=$status"
Write-Host "READY_ATOMS=$($atoms.Count)"
Write-Host "UNIQUE_TOPICS=$($report.unique_topic_count)"
Write-Host "DIRECTED=$directed"
Write-Host "EXPERIENCE=$experience"
Write-Host "PROMOTION_ALLOWED=$($report.promotion_allowed)"
Write-Host "ISSUES=$($issues.Count)"
Write-Host "RUNTIME_READY=false"
if($status -notlike 'PASS_*'){ exit 1 }