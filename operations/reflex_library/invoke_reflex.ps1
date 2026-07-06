param(
  [Parameter(Mandatory=$true)]
  [ValidateSet('READ_FILE_SUMMARY','VALIDATE_JSON','INSPECT_REPO_STATUS','INSPECT_ACTIVE_MEMORY','QUERY_ACTIVE_MEMORY','COMPARE_TASK_TO_MEMORY','DETECT_REPETITION','PROPOSE_NEXT_TASK')]
  [string]$Reflex,
  [string]$TargetPath,
  [string]$Task,
  [string]$Query,
  [string]$ProofPath,
  [int]$Limit = 8
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
Set-Location $repoRoot

function New-BaseResult([string]$Name) {
  [ordered]@{
    schema = 'AGENT_REFLEX_RESULT_V1'
    reflex = $Name
    at = (Get-Date).ToString('o')
    status = 'PASS'
    repo_root = $repoRoot
    mutation_allowed = $false
    mutation_performed = $false
    codex_launched = $false
    web_research_performed = $false
    school_started = $false
    background_process_started = $false
    result = $null
    errors = @()
  }
}

function Write-Result($Result) {
  $json = $Result | ConvertTo-Json -Depth 16
  if (-not [string]::IsNullOrWhiteSpace($ProofPath)) {
    $dir = Split-Path $ProofPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    [IO.File]::WriteAllText((Join-Path $repoRoot $ProofPath), ($json -replace "`r`n","`n"), [Text.UTF8Encoding]::new($false))
  }
  $json
}

function Get-RelativePath([string]$Path) {
  if ([string]::IsNullOrWhiteSpace($Path)) { return $null }
  $p = $Path -replace '\\','/'
  $p = $p.TrimStart('/','\')
  return $p
}

function Search-Memory([string]$Needle, [int]$Take) {
  $memPath = '.runtime/active_compact_semantic_memory_v1/cells.jsonl'
  if (-not (Test-Path -LiteralPath $memPath)) { return @() }
  $terms = @(($Needle -split '[^A-Za-z0-9_\-]+' | Where-Object { $_.Length -ge 3 } | Select-Object -Unique))
  if($terms.Count -eq 0) { $terms = @($Needle) }
  $matches = New-Object System.Collections.Generic.List[object]
  $index = 0
  foreach($line in Get-Content -LiteralPath $memPath) {
    $index += 1
    if([string]::IsNullOrWhiteSpace($line)) { continue }
    $rawLower = $line.ToLowerInvariant()
    $score = 0
    foreach($t in $terms) { if($rawLower.Contains($t.ToLowerInvariant())) { $score += 1 } }
    if($score -gt 0) {
      $summary = $line.Substring(0,[Math]::Min(360,$line.Length))
      try {
        $o = $line | ConvertFrom-Json
        foreach($key in @('theme','summary','uses','canonical_rule','label','title','kind','cell_id','id')) {
          if($o.PSObject.Properties.Name -contains $key) {
            $v=$o.$key
            if($null -ne $v) {
              $summary = ($v | ConvertTo-Json -Compress -Depth 4)
              if($summary.Length -gt 360) { $summary = $summary.Substring(0,360) }
              break
            }
          }
        }
      } catch { }
      $matches.Add([ordered]@{ cell_index=$index; score=$score; summary=$summary }) | Out-Null
    }
  }
  @($matches.ToArray() | Sort-Object -Property score -Descending | Select-Object -First $Take)
}
$out = New-BaseResult $Reflex
try {
  switch($Reflex) {
    'READ_FILE_SUMMARY' {
      $rel = Get-RelativePath $TargetPath
      if(-not (Test-Path -LiteralPath $rel)) { throw "target_missing:$rel" }
      $item=Get-Item -LiteralPath $rel
      $lines=@(Get-Content -LiteralPath $rel -TotalCount 20 -ErrorAction SilentlyContinue)
      $out.result=[ordered]@{ path=$rel; exists=$true; bytes=$item.Length; first_lines=@($lines); sha256=(Get-FileHash -Algorithm SHA256 $rel).Hash }
    }
    'VALIDATE_JSON' {
      $rel = Get-RelativePath $TargetPath
      if(-not (Test-Path -LiteralPath $rel)) { throw "target_missing:$rel" }
      $null = Get-Content -LiteralPath $rel -Raw | ConvertFrom-Json
      $out.result=[ordered]@{ path=$rel; json_valid=$true }
    }
    'INSPECT_REPO_STATUS' {
      $status=@(git status --short --untracked-files=all)
      $out.result=[ordered]@{ branch=(git branch --show-current).Trim(); head=(git rev-parse HEAD).Trim(); dirty=($status.Count -gt 0); status=@($status) }
    }
    'INSPECT_ACTIVE_MEMORY' {
      $manifest='.runtime/active_compact_semantic_memory_v1/manifest.json'
      $cells='.runtime/active_compact_semantic_memory_v1/cells.jsonl'
      $m=Get-Content -LiteralPath $manifest -Raw|ConvertFrom-Json
      $out.result=[ordered]@{ manifest_path=$manifest; cells_path=$cells; run_id=$m.run_id; runtime_ready=$m.runtime_ready; cells_count=((Get-Content $cells|Measure-Object -Line).Lines); cells_sha256=(Get-FileHash -Algorithm SHA256 $cells).Hash }
    }
    'QUERY_ACTIVE_MEMORY' {
      if([string]::IsNullOrWhiteSpace($Query)) { $Query=$Task }
      $candidates = Search-Memory -Needle $Query -Take $Limit
      $out.result=[ordered]@{ query=$Query; candidate_count=@($candidates).Count; candidates=@($candidates) }
    }
    'COMPARE_TASK_TO_MEMORY' {
      if([string]::IsNullOrWhiteSpace($Query)) { $Query=$Task }
      $candidates = Search-Memory -Needle $Query -Take $Limit
      $classification = if(@($candidates).Count -eq 0){'NO_USEFUL_MEMORY'} elseif(($candidates|Select-Object -First 1).score -ge 3){'PARTIAL_MATCH'} else {'LOW_RELEVANCE'}
      $out.result=[ordered]@{ task=$Task; query=$Query; relevance=$classification; candidates_checked=@($candidates).Count; best_match=(@($candidates)|Select-Object -First 1); gap_after_memory=$(if($classification -eq 'NO_USEFUL_MEMORY'){'memory did not provide useful candidate for current task'}elseif($classification -eq 'LOW_RELEVANCE'){'memory candidate exists but relevance is weak'}else{'memory partially helps but does not complete task'}); next_learning_need='task-selection/reflex-use knowledge connected to active memory' }
    }
    'DETECT_REPETITION' {
      $rel = Get-RelativePath $TargetPath
      if(-not (Test-Path -LiteralPath $rel)) { throw "target_missing:$rel" }
      $p=Get-Content -LiteralPath $rel -Raw|ConvertFrom-Json
      $events=@($p.test_life.recent_events)
      $groups=@($events|Group-Object selected|Sort-Object Count -Descending|ForEach-Object{[ordered]@{selected=$_.Name; count=$_.Count}})
      $out.result=[ordered]@{ proof=$rel; events=@($events).Count; selected_groups=$groups; repeated_pattern=($groups.Count -gt 0 -and ($groups|Select-Object -First 1).count -gt 5) }
    }
    'PROPOSE_NEXT_TASK' {
      $out.result=[ordered]@{ proposed_task='use active memory to choose next safe read-only development task'; rationale='motor should consult memory before repeating scripted treadmill'; safe_next_reflexes=@('INSPECT_ACTIVE_MEMORY','QUERY_ACTIVE_MEMORY','COMPARE_TASK_TO_MEMORY','READ_FILE_SUMMARY') }
    }
  }
} catch {
  $out.status='FAIL'
  $out.errors=@($_.Exception.Message)
}
Write-Result $out
if($out.status -ne 'PASS') { exit 1 }
