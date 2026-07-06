param(
  [string]$ActiveCheckpointPath='operations/school/curriculum/codex_digest/store/active_codex_curriculum_digest_v1/active_codex_curriculum_digest_checkpoint.json',
  [string]$MemoryDir='operations/school/curriculum/candidate_factory/memory'
)
$ErrorActionPreference='Stop'
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$utf8=New-Object System.Text.UTF8Encoding($false)
function WriteJson($p,$o,$d=100){$dir=Split-Path -Parent $p; if($dir){New-Item -ItemType Directory -Force -Path $dir|Out-Null}; [IO.File]::WriteAllText((Join-Path (Get-Location).Path $p),($o|ConvertTo-Json -Depth $d),$utf8)}
function Slug($s){ return (([string]$s).ToLowerInvariant() -replace '[^a-z0-9]+','_').Trim('_') }
$topicRoots=@('proof_boundary','school_life_boundary','codex_preflight','validator_consistency','streaming_absorption','ready_lane_gate','rollback_snapshot','scale_gate','decision_use','return_to_parent','contract_schema','source_anchor','duplicate_key_hygiene','count_not_learning','runtime_boundary','active_repo_body','quarantine_lane','factory_generation','batch_checkpoint','owner_selected_n','canonical_scheduler','local_first','no_external_brain','negative_control','promotion_boundary','lab_not_live','child_agent_delay','memory_compaction','source_ladder','failure_report')
$verbs=@('separate','classify','validate','guard','stream','promote','rollback','prove','route','compress')
function ParseFactoryTopic([string]$topic){
  foreach($verb in $verbs){
    foreach($root in $topicRoots){
      $prefix="factory_${verb}_${root}_"
      if($topic.StartsWith($prefix)){
        $tail=$topic.Substring($prefix.Length)
        $ordinal=$null; $runSlug='legacy_no_run_slug'
        if($tail -match '^(?<run>.+)_(?<ord>\d{6})$'){
          $runSlug=$Matches.run; $ordinal=[int]$Matches.ord
        } elseif($tail -match '^(?<ord>\d{6})$'){
          $ordinal=[int]$Matches.ord
        }
        return [pscustomObject]@{is_factory=$true; verb=$verb; root=$root; run_slug=$runSlug; ordinal=$ordinal}
      }
    }
  }
  return [pscustomObject]@{is_factory=$false; verb=''; root=''; run_slug=''; ordinal=$null}
}
New-Item -ItemType Directory -Force -Path $MemoryDir | Out-Null
$cp=Get-Content $ActiveCheckpointPath -Raw | ConvertFrom-Json
$atoms=@($cp.atoms)
$ledgerPath=Join-Path $MemoryDir 'factory_ledger.jsonl'
if(Test-Path $ledgerPath){ Remove-Item $ledgerPath -Force }
$ledger=@(); $coverage=@{}; $rootCoverage=@{}; $verbRootCoverage=@{}; $levelCoverage=@{}; $runCoverage=@{}; $factoryCount=0; $nonFactoryCount=0
foreach($a in $atoms){
  $parsed=ParseFactoryTopic ([string]$a.topic)
  if($parsed.is_factory){
    $factoryCount++
    $level=[int]$a.level
    $sourceMode=[string]$a.source_mode
    $learningKey="$($parsed.verb)|$($parsed.root)|$level|$sourceMode"
    $prereq=if($level -gt 1){"$($parsed.verb)|$($parsed.root)|$($level-1)|$sourceMode"}else{''}
    if(-not $coverage.ContainsKey($learningKey)){ $coverage[$learningKey]=0 }; $coverage[$learningKey]++
    $rk=$parsed.root; if(-not $rootCoverage.ContainsKey($rk)){ $rootCoverage[$rk]=0 }; $rootCoverage[$rk]++
    $vr="$($parsed.verb)|$($parsed.root)"; if(-not $verbRootCoverage.ContainsKey($vr)){ $verbRootCoverage[$vr]=0 }; $verbRootCoverage[$vr]++
    $lk=[string]$level; if(-not $levelCoverage.ContainsKey($lk)){ $levelCoverage[$lk]=0 }; $levelCoverage[$lk]++
    $rs=[string]$parsed.run_slug; if(-not $runCoverage.ContainsKey($rs)){ $runCoverage[$rs]=0 }; $runCoverage[$rs]++
    $rec=[pscustomObject]@{atom_id=$a.atom_id; topic=$a.topic; duplicate_key=$a.duplicate_key; source_mode=$sourceMode; level=$level; verb=$parsed.verb; root=$parsed.root; run_slug=$parsed.run_slug; ordinal=$parsed.ordinal; learning_key=$learningKey; prerequisite_key=$prereq; source_anchor=$a.source_anchor}
    $ledger += $rec
    [IO.File]::AppendAllText((Join-Path (Get-Location).Path $ledgerPath),(($rec|ConvertTo-Json -Compress -Depth 20)+"`n"),$utf8)
  } else { $nonFactoryCount++ }
}
$expectedKeys=@(); foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($level in 1..5){ foreach($mode in @('directed_curriculum','experience_curriculum')){ $expectedKeys += "$verb|$root|$level|$mode" } } } }
$gaps=@(); foreach($k in $expectedKeys){ if(-not $coverage.ContainsKey($k)){ $parts=$k -split '\|'; $gaps += [pscustomObject]@{learning_key=$k; verb=$parts[0]; root=$parts[1]; level=[int]$parts[2]; source_mode=$parts[3]; current_count=0} } }
$undercovered=@(); foreach($k in $expectedKeys){ $count=if($coverage.ContainsKey($k)){[int]$coverage[$k]}else{0}; if($count -lt 2){ $parts=$k -split '\|'; $undercovered += [pscustomObject]@{learning_key=$k; verb=$parts[0]; root=$parts[1]; level=[int]$parts[2]; source_mode=$parts[3]; current_count=$count} } }
$edges=@(); foreach($verb in $verbs){ foreach($root in $topicRoots){ foreach($mode in @('directed_curriculum','experience_curriculum')){ foreach($level in 2..5){ $from="$verb|$root|$($level-1)|$mode"; $to="$verb|$root|$level|$mode"; $edges += [pscustomObject]@{from=$from; to=$to; from_count=if($coverage.ContainsKey($from)){[int]$coverage[$from]}else{0}; to_count=if($coverage.ContainsKey($to)){[int]$coverage[$to]}else{0}; satisfied=($coverage.ContainsKey($from) -and $coverage.ContainsKey($to))} } } } }
$coverageObj=[pscustomObject]@{schema='codex_candidate_factory_coverage_map_v1'; status='PASS_FACTORY_COVERAGE_MAP_V1'; runtime_ready=$false; active_atom_count=$atoms.Count; factory_atom_count=$factoryCount; non_factory_atom_count=$nonFactoryCount; expected_learning_key_count=$expectedKeys.Count; covered_learning_key_count=$coverage.Keys.Count; gap_count=$gaps.Count; undercovered_lt2_count=$undercovered.Count; root_coverage=$rootCoverage; verb_root_coverage=$verbRootCoverage; level_coverage=$levelCoverage; run_coverage=$runCoverage; gaps=@($gaps|Sort-Object current_count,root,verb,level|Select-Object -First 500); undercovered=@($undercovered|Sort-Object current_count,root,verb,level|Select-Object -First 500)}
$graph=[pscustomObject]@{schema='codex_candidate_factory_prerequisite_graph_v1'; status='PASS_FACTORY_PREREQUISITE_GRAPH_V1'; runtime_ready=$false; edge_count=$edges.Count; satisfied_edge_count=@($edges|Where-Object {$_.satisfied}).Count; missing_edge_count=@($edges|Where-Object {-not $_.satisfied}).Count; edges=@($edges)}
$report=[pscustomObject]@{schema='codex_candidate_factory_memory_ladder_report_v1'; status='PASS_FACTORY_MEMORY_LADDER_REPORT_V1'; runtime_ready=$false; active_atom_count=$atoms.Count; factory_atom_count=$factoryCount; ledger_path=$ledgerPath; coverage_map_path=(Join-Path $MemoryDir 'coverage_map.json'); prerequisite_graph_path=(Join-Path $MemoryDir 'prerequisite_graph.json'); covered_learning_key_count=$coverage.Keys.Count; expected_learning_key_count=$expectedKeys.Count; gap_count=$gaps.Count; undercovered_lt2_count=$undercovered.Count; duplicate_topic_count=@($atoms|Group-Object topic|Where-Object{$_.Count -gt 1}).Count; duplicate_key_count=@($atoms|Group-Object duplicate_key|Where-Object{$_.Count -gt 1}).Count; boundary='Factory memory surface only; no generation, no active mutation, no live proof.'}
WriteJson (Join-Path $MemoryDir 'coverage_map.json') $coverageObj 100
WriteJson (Join-Path $MemoryDir 'prerequisite_graph.json') $graph 100
WriteJson (Join-Path $MemoryDir 'factory_memory_ladder_report.json') $report 100
WriteJson 'operations/reports/CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_V1.json' $report 100
$md=@('# CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_V1','',"Status: $($report.status)",'Runtime ready: false','',"Active atoms: $($report.active_atom_count)","Factory atoms: $($report.factory_atom_count)","Covered learning keys: $($report.covered_learning_key_count) / $($report.expected_learning_key_count)","Gap count: $($report.gap_count)","Undercovered <2 count: $($report.undercovered_lt2_count)","Duplicate topics: $($report.duplicate_topic_count)","Duplicate keys: $($report.duplicate_key_count)",'','Boundary: memory surface only; no active mutation.')
[IO.File]::WriteAllText((Join-Path (Get-Location).Path 'operations/reports/CODEX_CANDIDATE_FACTORY_MEMORY_LADDER_V1.md'),($md -join "`r`n"),$utf8)
Write-Host "MEMORY_STATUS=$($report.status)"
Write-Host "ACTIVE_ATOMS=$($report.active_atom_count)"
Write-Host "FACTORY_ATOMS=$($report.factory_atom_count)"
Write-Host "COVERED_KEYS=$($report.covered_learning_key_count)/$($report.expected_learning_key_count)"
Write-Host "GAP_COUNT=$($report.gap_count)"
Write-Host "UNDERCOVERED_LT2=$($report.undercovered_lt2_count)"
Write-Host "DUP_TOPICS=$($report.duplicate_topic_count)"
Write-Host "DUP_KEYS=$($report.duplicate_key_count)"
Write-Host "RUNTIME_READY=false"