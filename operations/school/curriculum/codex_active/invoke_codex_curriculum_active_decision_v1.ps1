param([Parameter(Mandatory=$true)][string]$TaskText,[switch]$AsJson)
$ErrorActionPreference="Stop"
$repoRoot=(git rev-parse --show-toplevel).Trim(); Set-Location $repoRoot
$map=Get-Content reports/self_development/SELF_MODEL_ACTIVE_MAP.json -Raw | ConvertFrom-Json
if(-not ($map.PSObject.Properties.Name -contains "active_codex_curriculum_digest_checkpoint_path")){ throw "CODEX_CURRICULUM_ACTIVE_POINTER_MISSING" }
$cpPath=$map.active_codex_curriculum_digest_checkpoint_path
$cp=Get-Content $cpPath -Raw | ConvertFrom-Json
$text=$TaskText.ToLowerInvariant()
$hitList=@()
foreach($a in $cp.atoms){
  $topic=([string]$a.topic).ToLowerInvariant()
  $objective=([string]$a.objective).ToLowerInvariant()
  $expected=([string]$a.expected_behavior).ToLowerInvariant()
  $score=0
  foreach($token in @($topic,($topic -replace "_"," "))){ if($token -and $text.Contains($token)){ $score+=5 } }
  foreach($word in ($topic -split "_")){ if($word.Length -ge 4 -and $text.Contains($word)){ $score+=2 } }
  if($text.Contains("proof") -and ($topic -match "proof|claim")){ $score+=4 }
  if($text.Contains("school") -and ($topic -match "school|life")){ $score+=4 }
  if($text.Contains("codex") -and ($topic -match "codex|validator|side_effects")){ $score+=3 }
  if($text.Contains("duplicate") -and ($topic -match "duplicate")){ $score+=4 }
  if($text.Contains("budget") -and ($topic -match "budget|run")){ $score+=4 }
  if($text.Contains("return") -and ($topic -match "return")){ $score+=4 }
  if($text.Contains("active") -and ($topic -match "active|checkpoint")){ $score+=3 }
  if($score -gt 0){ $hitList += [pscustomObject]@{score=$score; atom=$a} }
}
$selected=@($hitList | Sort-Object score -Descending | Select-Object -First 3)
$baseline="Generic decision: proceed from task text without curriculum-specific guard."
if($selected.Count -gt 0){
  $rules=@($selected | ForEach-Object { $_.atom.expected_behavior })
  $ids=@($selected | ForEach-Object { $_.atom.atom_id })
  $topics=@($selected | ForEach-Object { $_.atom.topic })
  $active="Active curriculum decision: apply " + (($topics) -join ", ") + " guard(s): " + (($rules) -join " | ")
  $status="PASS"
} else {
  $ids=@(); $topics=@(); $active=$baseline; $status="NO_MATCH"
}
$result=[pscustomObject]@{schema="codex_curriculum_active_decision_v1"; status=$status; runtime_ready=$false; task_text=$TaskText; baseline_decision=$baseline; active_decision=$active; behavior_delta_status=if($active -ne $baseline){"PASS"}else{"FAIL"}; atom_count=$ids.Count; atom_ids_used=$ids; matched_topics=$topics; checkpoint_path=$cpPath; boundary="Uses active repo-body Codex curriculum digest pointer; does not mutate state."}
if($AsJson){ $result | ConvertTo-Json -Depth 20 } else { $result }