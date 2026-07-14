param(
  [Parameter(Mandatory=$true)][string]$TaskJsonPath,
  [Parameter(Mandatory=$true)][string]$CandidatesJsonlPath,
  [Parameter(Mandatory=$true)][string]$OutputAtomsJsonlPath,
  [string]$ReportPath = ''
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
function EnsureDir($Path){ if($Path -and -not (Test-Path $Path)){ New-Item -ItemType Directory -Force -Path $Path | Out-Null } }
function WriteJson($Path,$Obj,$Depth=80){ $d=Split-Path -Parent $Path; if($d){ EnsureDir $d }; $Obj|ConvertTo-Json -Depth $Depth|Set-Content -LiteralPath $Path -Encoding UTF8 }
function GetProp($obj,$name){ if($obj.PSObject.Properties[$name]){ return $obj.PSObject.Properties[$name].Value }; return $null }
if(-not (Test-Path $TaskJsonPath)){ throw "TASK_JSON_MISSING:$TaskJsonPath" }
if(-not (Test-Path $CandidatesJsonlPath)){ throw "CANDIDATES_JSONL_MISSING:$CandidatesJsonlPath" }
$task=Get-Content $TaskJsonPath -Raw | ConvertFrom-Json
$required=@($task.required_candidate_fields)
if($required.Count -lt 10){ throw 'TASK_REQUIRED_FIELDS_TOO_THIN' }
$topic=[string]$task.topic_key
$targetDepth=[int]$task.target_depth
$startDepth=[int]$task.start_depth
$expectedCount=[int]$task.candidate_limit
$accepted=New-Object System.Collections.ArrayList
$rejected=New-Object System.Collections.ArrayList
$lineNo=0
$seen=@{}
foreach($line in Get-Content $CandidatesJsonlPath){
  if([string]::IsNullOrWhiteSpace($line)){ continue }
  $lineNo++
  $fail=New-Object System.Collections.ArrayList
  try{ $obj=$line | ConvertFrom-Json }catch{ [void]$rejected.Add([pscustomobject]@{line=$lineNo; reason='invalid_json'; error=$_.Exception.Message}); continue }
  foreach($f in $required){
    $v=GetProp $obj $f
    if($null -eq $v -or [string]::IsNullOrWhiteSpace([string]$v)){ [void]$fail.Add("missing_or_empty:$f") }
  }
  if([string](GetProp $obj 'topic_key') -ne $topic){ [void]$fail.Add('topic_key_mismatch') }
  $depth=0
  [void][int]::TryParse([string](GetProp $obj 'depth_level'),[ref]$depth)
  if($depth -lt $startDepth -or $depth -gt $targetDepth){ [void]$fail.Add('depth_out_of_range') }
  $cid=[string](GetProp $obj 'candidate_id')
  if([string]::IsNullOrWhiteSpace($cid)){ $cid="line_$lineNo" }
  if($seen.ContainsKey($cid)){ [void]$fail.Add('duplicate_candidate_id') } else { $seen[$cid]=$true }
  $sourceBasis=GetProp $obj 'source_basis'
  $sourceMissing=GetProp $obj 'source_missing'
  $hasSource=$false
  if($sourceBasis -is [array]){ $hasSource=($sourceBasis.Count -gt 0) } elseif(-not [string]::IsNullOrWhiteSpace([string]$sourceBasis)){ $hasSource=$true }
  $sourceMissingBool=(([string]$sourceMissing).ToLowerInvariant() -eq 'true')
  if(-not $hasSource -and -not $sourceMissingBool){ [void]$fail.Add('source_basis_or_source_missing_required') }
  foreach($f in @('expected_behavior','validator','proof_requirements','negative_case','return_to_parent','digest_hint')){
    if([string]::IsNullOrWhiteSpace([string](GetProp $obj $f))){ [void]$fail.Add("quality_field_empty:$f") }
  }
  if($fail.Count -gt 0){
    [void]$rejected.Add([pscustomobject]@{line=$lineNo; candidate_id=$cid; failures=@($fail)})
    continue
  }
  $summaryParts=@(
    "claim=$([string](GetProp $obj 'claim'))",
    "expected_behavior=$([string](GetProp $obj 'expected_behavior'))",
    "validator=$([string](GetProp $obj 'validator'))",
    "negative_case=$([string](GetProp $obj 'negative_case'))",
    "return_to_parent=$([string](GetProp $obj 'return_to_parent'))"
  )
  $atom=[pscustomobject]@{
    atom_id=("codex.school.patch.atom.{0}.{1:D6}.v1" -f (($topic -replace '[^A-Za-z0-9_\-]','_').ToLowerInvariant()),$lineNo)
    candidate_id=$cid
    topic=$topic
    concept_key=$topic
    label=[string](GetProp $obj 'topic_label')
    level=$depth
    source_mode='codex_school_patch'
    source_basis=$sourceBasis
    source_missing=$sourceMissingBool
    objective=[string](GetProp $obj 'claim')
    definition=($summaryParts -join '; ')
    summary=($summaryParts -join '; ')
    expected_behavior=[string](GetProp $obj 'expected_behavior')
    validator_hint=[string](GetProp $obj 'validator')
    proof_requirements=[string](GetProp $obj 'proof_requirements')
    negative_trap=[string](GetProp $obj 'negative_case')
    failure_contrast=[string](GetProp $obj 'failure_contrast')
    return_to_parent=[string](GetProp $obj 'return_to_parent')
    digest_hint=[string](GetProp $obj 'digest_hint')
    duplicate_key=("$topic|$cid")
    theme_key=$topic
    learning_key=("$topic.depth.$depth.$cid")
    prerequisite_key=("$topic.depth.$([Math]::Max(0,$depth-1))")
    behavior_use_proof_target=[string](GetProp $obj 'proof_requirements')
  }
  [void]$accepted.Add($atom)
}
if($accepted.Count -lt 1){ throw 'NO_ACCEPTED_CODEX_CANDIDATES' }
if($accepted.Count -ne $expectedCount){ throw "ACCEPTED_COUNT_MISMATCH:$($accepted.Count)/$expectedCount" }
EnsureDir (Split-Path -Parent $OutputAtomsJsonlPath)
($accepted | ForEach-Object { $_|ConvertTo-Json -Depth 50 -Compress }) -join "`n" | Set-Content -LiteralPath $OutputAtomsJsonlPath -Encoding UTF8
if([string]::IsNullOrWhiteSpace($ReportPath)){ $ReportPath=(Join-Path (Split-Path -Parent $OutputAtomsJsonlPath) 'codex_candidate_normalization_report.json') }
$report=[ordered]@{
  schema='codex_school_patch_candidate_normalization_v1'
  status='PASS_CODEX_SCHOOL_PATCH_CANDIDATE_NORMALIZATION_V1'
  created_at=(Get-Date).ToString('o')
  task_json=$TaskJsonPath
  candidates_jsonl=$CandidatesJsonlPath
  output_atoms_jsonl=$OutputAtomsJsonlPath
  topic_key=$topic
  expected_candidate_count=$expectedCount
  accepted_count=$accepted.Count
  rejected_count=$rejected.Count
  rejected=@($rejected | Select-Object -First 20)
  memory_mutated=$false
}
WriteJson $ReportPath $report 80
Write-Host "CODEX_CANDIDATE_NORMALIZATION_STATUS=$($report.status)"
Write-Host "CODEX_CANDIDATE_NORMALIZATION_REPORT=$ReportPath"
Write-Host "CODEX_CANDIDATE_NORMALIZED_ATOMS=$OutputAtomsJsonlPath"
Write-Host "CODEX_CANDIDATE_ACCEPTED_COUNT=$($accepted.Count)"
Write-Host "CODEX_CANDIDATE_REJECTED_COUNT=$($rejected.Count)"
