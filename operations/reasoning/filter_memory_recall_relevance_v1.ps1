param(
  [Parameter(Mandatory=$true)][string]$Query,
  [int]$Top=8,
  [int]$AcceptTop=3,
  [string]$OutputPath='.runtime/memory_recall_relevance_filter_v1/filter_result.json'
)
$ErrorActionPreference='Stop'
function WJson($o,$p){ New-Item -ItemType Directory -Force -Path (Split-Path $p -Parent) | Out-Null; $o|ConvertTo-Json -Depth 100|Set-Content -Path $p -Encoding UTF8 }
function Normalize-Key([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return '' }
  $x=$s.ToLowerInvariant()
  $x=$x -replace '\|directed_curriculum',''
  $x=$x -replace '\|experience_curriculum',''
  $x=$x -replace '\|separate',''
  $x=$x -replace '\|track',''
  $x=$x -replace '[^a-z0-9]+','_'
  $x=$x -replace '_+','_'
  return $x.Trim('_')
}
function Terms([string]$s){
  if([string]::IsNullOrWhiteSpace($s)){ return @() }
  return @($s.ToLowerInvariant() -split '[^a-z0-9]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique)
}
$qTerms=@(Terms $Query)
$queryScript='operations/school/memory/query_compact_semantic_memory_v1.ps1'
if(-not(Test-Path $queryScript)){ throw 'MEMORY_QUERY_SCRIPT_MISSING' }
$stdout=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $queryScript -Query $Query -Top $Top *>&1 | ForEach-Object { [string]$_ })
$recallStatus='UNKNOWN'
$line=($stdout|Where-Object{$_ -match '^MEMORY_RECALL_STATUS='}|Select-Object -Last 1)
if($line){ $recallStatus=$line -replace '^MEMORY_RECALL_STATUS=','' }
$rawMatches=@($stdout | Where-Object { $_ -match '^MATCH\|' })
$parsed=@()
foreach($raw in $rawMatches){
  $m=$null
  if($raw -match '^MATCH\|(?<rank>\d+)\|score=(?<score>\d+)\|label=(?<label>.*)\|hits=(?<hits>[^|]*)\|obs=(?<obs>\d+)\|summary=(?<summary>.*)$'){
    $label=$Matches.label
    $summary=$Matches.summary
    $hits=@($Matches.hits -split ',' | Where-Object { $_ -ne '' })
    $labelTerms=@(Terms $label)
    $summaryTerms=@(Terms $summary)
    $allTerms=@($labelTerms + $summaryTerms + $hits | Select-Object -Unique)
    $coverage=@($qTerms | Where-Object { $allTerms -contains $_ })
    $curriculumNoise=($summary -match '^Factory curriculum theme ' -or $label -match '^bskd_seed_')
    $duplicateKey=Normalize-Key $label
    $m=[ordered]@{
      raw=$raw
      rank=[int]$Matches.rank
      score=[int]$Matches.score
      label=$label
      hits=$hits
      observation_count=[int]$Matches.obs
      summary=$summary
      duplicate_key=$duplicateKey
      query_term_coverage=@($coverage)
      query_term_coverage_count=@($coverage).Count
      curriculum_noise=[bool]$curriculumNoise
      relevance_score=0
      relevance_class='UNSCORED'
      decision='UNDECIDED'
      reasons=@()
    }
    $rel=0
    $reasons=New-Object System.Collections.Generic.List[string]
    $rel += [Math]::Min([int]$m.score,12)
    $rel += (@($coverage).Count * 3)
    if(@($hits).Count -ge 2){ $rel += 2; $reasons.Add('multi_hit')|Out-Null }
    if($curriculumNoise){ $rel -= 8; $reasons.Add('curriculum_noise')|Out-Null }
    if([int]$m.observation_count -gt 1000 -and $curriculumNoise){ $rel -= 2; $reasons.Add('high_volume_curriculum_pattern')|Out-Null }
    if($summary -match 'AIMO|memory atom|gate|action candidate|mind|logic|recall'){ $rel += 4; $reasons.Add('agent_logic_semantic_signal')|Out-Null }
    if(@($coverage).Count -lt 2){ $rel -= 3; $reasons.Add('low_query_coverage')|Out-Null }
    $m.relevance_score=$rel
    $m.reasons=@($reasons)
    if($rel -ge 12 -and -not $curriculumNoise){ $m.relevance_class='STRONG' }
    elseif($rel -ge 8){ $m.relevance_class='WEAK' }
    else { $m.relevance_class='NOISE' }
    $parsed += [pscustomobject]$m
  }
}
# Duplicate handling: keep highest relevance per duplicate key; mark others.
$groups=@($parsed | Group-Object duplicate_key)
foreach($g in $groups){
  $ordered=@($g.Group | Sort-Object -Property @{Expression='relevance_score';Descending=$true},@{Expression='score';Descending=$true},@{Expression='rank';Descending=$false})
  for($i=0;$i -lt $ordered.Count;$i++){
    if($i -gt 0){
      $ordered[$i].relevance_class='DUPLICATE'
      $ordered[$i].decision='REJECT_DUPLICATE'
      $rs=@($ordered[$i].reasons); $rs += 'duplicate_of_higher_ranked_recall'; $ordered[$i].reasons=$rs
    }
  }
}
$accepted=@($parsed | Where-Object { $_.relevance_class -in @('STRONG','WEAK') -and $_.decision -ne 'REJECT_DUPLICATE' } | Sort-Object -Property @{Expression='relevance_score';Descending=$true},@{Expression='rank';Descending=$false} | Select-Object -First $AcceptTop)
foreach($a in $accepted){ $a.decision='ACCEPT_AS_MEMORY_EVIDENCE' }
foreach($p in $parsed){ if($p.decision -eq 'UNDECIDED'){ $p.decision=if($p.relevance_class -eq 'NOISE'){'REJECT_NOISE'}else{'REJECT_OVER_LIMIT'} } }
$result=[ordered]@{
  schema='memory_recall_relevance_filter_v1'
  status=if(@($accepted).Count -gt 0){'PASS_MEMORY_RECALL_RELEVANCE_FILTER_V1'}else{'BLOCKED_NO_RELEVANT_MEMORY_AFTER_FILTER_V1'}
  created_at=(Get-Date).ToString('o')
  query=$Query
  query_terms=@($qTerms)
  recall_status=$recallStatus
  raw_match_count=@($rawMatches).Count
  parsed_match_count=@($parsed).Count
  accepted_count=@($accepted).Count
  accepted_matches=@($accepted)
  rejected_matches=@($parsed | Where-Object { $_.decision -ne 'ACCEPT_AS_MEMORY_EVIDENCE' })
  all_matches=@($parsed | Sort-Object rank)
  filter_rules=@('parse labels with embedded pipes','score query-term coverage','penalize curriculum noise','deduplicate normalized labels','accept only top relevant evidence')
  boundary=[ordered]@{read_only=$true; active_memory_mutated=$false; action_executed=$false; external_launch=$false}
}
WJson $result $OutputPath
Write-Host ('RECALL_FILTER_STATUS='+$result.status)
Write-Host ('RECALL_FILTER_ACCEPTED_COUNT='+$result.accepted_count)
Write-Host ('RECALL_FILTER_PATH='+$OutputPath)
if($accepted.Count -gt 0){ Write-Host ('RECALL_FILTER_TOP_LABEL='+$accepted[0].label) }
