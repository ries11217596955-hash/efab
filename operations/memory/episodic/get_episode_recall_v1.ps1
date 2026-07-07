function ConvertTo-EpisodicRecallTokenList([string[]]$QueryTerms) {
  $tokens = New-Object System.Collections.Generic.List[string]
  foreach($term in @($QueryTerms)) {
    if([string]::IsNullOrWhiteSpace([string]$term)) { continue }
    $lower = ([string]$term).ToLowerInvariant()
    foreach($part in @($lower -split '[^a-z0-9_\-]+')) {
      $p = ([string]$part).Trim('_','-')
      if($p.Length -ge 3 -and -not $tokens.Contains($p)) { $tokens.Add($p) | Out-Null }
    }
  }
  return @($tokens.ToArray())
}
function Get-EpisodicMemoryRecall {
  param(
    [string[]]$QueryTerms = @(),
    [string[]]$MemoryRoots = @('.runtime/episodic_memory_v1/reasoning_cells','.runtime/episodic_memory_v1/validator_cells','.runtime/episodic_memory_v1/cells'),
    [int]$MaxMatches = 5,
    [int]$MaxCellBytes = 16000,
    [int]$MinScore = 2
  )
  $tokens = @(ConvertTo-EpisodicRecallTokenList -QueryTerms $QueryTerms)
  if(@($tokens).Count -lt 1) {
    return [ordered]@{ available=$false; status='NO_QUERY_TERMS'; query_terms=@($QueryTerms); tokens=@(); matched_count=0; selected=@(); reuse_hints=@(); guardrails=@('episodic recall requires explicit topic/task/query terms'); scanned_count=0; skipped_count=0 }
  }
  $files = New-Object System.Collections.Generic.List[object]
  foreach($root in @($MemoryRoots)) {
    if([string]::IsNullOrWhiteSpace([string]$root)) { continue }
    if(Test-Path $root) { Get-ChildItem $root -Recurse -File -Filter '*.json' -ErrorAction SilentlyContinue | ForEach-Object { $files.Add($_) | Out-Null } }
  }
  $matches = New-Object System.Collections.Generic.List[object]
  $skipped = 0
  foreach($file in @($files.ToArray())) {
    try {
      if($file.Length -gt $MaxCellBytes) { $skipped++; continue }
      $cell = Get-Content $file.FullName -Raw | ConvertFrom-Json
      if($cell.schema -ne 'episodic_memory_cell_v1' -or $cell.memory_type -ne 'episodic') { $skipped++; continue }
      if($cell.raw_trace_included -ne $false) { $skipped++; continue }
      $hay = (@($cell.topic,$cell.situation,$cell.hypothesis,$cell.action_taken,$cell.result,$cell.failure_reason,$cell.correction,$cell.reuse_hint,$cell.status) + @($cell.tags)) -join ' '
      $hay = $hay.ToLowerInvariant()
      $score = 0
      $hits = New-Object System.Collections.Generic.List[string]
      foreach($token in @($tokens)) {
        if($hay -like "*$token*") { $score += 1; if(-not $hits.Contains($token)) { $hits.Add($token) | Out-Null } }
      }
      foreach($term in @($QueryTerms)) {
        $t=([string]$term).ToLowerInvariant().Trim()
        if($t.Length -ge 8 -and $hay -like "*$t*") { $score += 4 }
      }
      if($cell.status -in @('REUSABLE_LESSON','PROVEN_LIVE')) { $score += 1 }
      if(@($cell.proof_refs).Count -gt 0) { $score += 1 }
      if(@($hits.ToArray()).Count -ge 2 -and $score -ge [Math]::Max(1,$MinScore)) {
        $matches.Add([ordered]@{
          path=$file.FullName
          episode_id=$cell.episode_id
          topic=$cell.topic
          status=$cell.status
          confidence=$cell.confidence
          score=$score
          hits=@($hits.ToArray())
          reuse_hint=$cell.reuse_hint
          failure_reason=$cell.failure_reason
          correction=$cell.correction
          proof_ref_count=@($cell.proof_refs).Count
        }) | Out-Null
      }
    } catch { $skipped++ }
  }
  $selected=@($matches.ToArray() | Sort-Object -Property @{Expression={ [int]$_['score'] }; Descending=$true},@{Expression={ [int]@($_['hits']).Count }; Descending=$true},@{Expression={ [string]$_['episode_id'] }; Descending=$false} | Select-Object -First ([Math]::Max(1,$MaxMatches)))
  if(@($selected).Count -lt 1) {
    return [ordered]@{ available=$false; status='NO_RELEVANT_EPISODIC_MEMORY'; query_terms=@($QueryTerms); tokens=@($tokens); matched_count=0; selected=@(); reuse_hints=@(); guardrails=@('do not invent past experience when recall has no match'); scanned_count=@($files.ToArray()).Count; skipped_count=$skipped }
  }
  return [ordered]@{
    available=$true
    status='EPISODIC_RECALL_AVAILABLE'
    query_terms=@($QueryTerms)
    tokens=@($tokens)
    matched_count=@($matches.ToArray()).Count
    selected=@($selected)
    reuse_hints=@($selected | ForEach-Object { $_.reuse_hint } | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    guardrails=@('use episodic recall as experience hint, not as proof by itself','preserve proof_refs for claims','do not copy raw traces into compact memory')
    scanned_count=@($files.ToArray()).Count
    skipped_count=$skipped
  }
}



