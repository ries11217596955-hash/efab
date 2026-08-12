$ErrorActionPreference='Stop'
$errors=New-Object System.Collections.Generic.List[string]
function Add-Err([string]$m){$errors.Add($m)|Out-Null}
function Assert([bool]$ok,[string]$m){if(-not $ok){Add-Err $m}}
function Sha([string]$p){if(Test-Path $p){return (Get-FileHash $p -Algorithm SHA256).Hash};return $null}
$selector='operations/autonomous_inner_motor/select_autonomous_wake_frontier_v1.ps1'
$runner='operations/autonomous_inner_motor/run_autonomous_inner_motor.ps1'
$reasoner='operations/reasoning/build_agent_mind_logic_frame_v1.ps1'
$proofPath='tests/self_development/AUTONOMOUS_WAKE_FRONTIER_SELECTOR_V1_PROOF.json'
foreach($p in @($selector,$runner,$reasoner)){if(-not(Test-Path $p)){Add-Err ('missing:'+ $p)}}
foreach($p in @($selector,$runner)){if(Test-Path $p){$t=$null;$e=$null;[System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $p),[ref]$t,[ref]$e)|Out-Null;foreach($x in $e){Add-Err ((Split-Path $p -Leaf)+':parse:'+ $x.Message)}}}
. $selector
$healthy=Select-AutonomousWakeFrontier -RepoClean $true -ActiveMemoryReady $true -BodyMapAvailable $true -SchoolActive $false -SelfBuildCandidateAvailable $true -FreshSelfBuildGap $false
$dirty=Select-AutonomousWakeFrontier -RepoClean $false -ActiveMemoryReady $true -BodyMapAvailable $true -SchoolActive $false -SelfBuildCandidateAvailable $true -FreshSelfBuildGap $false
$memoryMissing=Select-AutonomousWakeFrontier -RepoClean $true -ActiveMemoryReady $false -BodyMapAvailable $true -SchoolActive $false -SelfBuildCandidateAvailable $true -FreshSelfBuildGap $false
$freshBuild=Select-AutonomousWakeFrontier -RepoClean $true -ActiveMemoryReady $true -BodyMapAvailable $true -SchoolActive $false -SelfBuildCandidateAvailable $true -FreshSelfBuildGap $true -FreshSelfBuildGapText 'fresh capability gap'
$avoidKnowledge=Select-AutonomousWakeFrontier -RepoClean $true -ActiveMemoryReady $true -BodyMapAvailable $true -SchoolActive $false -SelfBuildCandidateAvailable $false -FreshSelfBuildGap $false -AvoidFrontiers @('knowledge_source_gap')
Assert ($healthy.status -eq 'PASS_AUTONOMOUS_WAKE_FRONTIER_SELECTOR_V1') 'healthy_status'
Assert ($healthy.selected_frontier -eq 'knowledge_source_gap') ('healthy_frontier:'+ $healthy.selected_frontier)
Assert (@($healthy.candidates | Where-Object {$_.frontier -eq 'self_build_gap'}).Count -eq 1) 'self_build_candidate_missing'
Assert (($healthy.candidates | Where-Object {$_.frontier -eq 'self_build_gap'} | Select-Object -First 1).fresh_signal -eq $false) 'stale_self_build_marked_fresh'
Assert ($dirty.selected_frontier -eq 'recovery_control_gap') ('dirty_frontier:'+ $dirty.selected_frontier)
Assert ($memoryMissing.selected_frontier -eq 'active_memory_recovery') ('memory_frontier:'+ $memoryMissing.selected_frontier)
Assert ($freshBuild.selected_frontier -eq 'self_build_gap') ('fresh_build_frontier:'+ $freshBuild.selected_frontier)
Assert ($avoidKnowledge.selected_frontier -ne 'knowledge_source_gap') 'avoid_penalty_did_not_change_frontier'
$runnerText=Get-Content $runner -Raw
foreach($n in @('. $wakeFrontierSelectorPath','$autonomousWakeFrontier=Select-AutonomousWakeFrontier','$internalGoal=New-InternalSelfGoal $selfBuild $body $memoryBefore $autonomousWakeFrontier',"source='AUTONOMOUS_WAKE_FRONTIER'",'$internalGoal[''source'']=''OWNER_QUESTION_ACTIVE_GOAL''','$logicProblem=if($internalGoal -and $internalGoal.goal)','$selectiveCompactMemoryRetrieval = New-SelectiveCompactMemoryRetrieval $runId $internalGoal')){Assert ($runnerText.Contains($n)) ('runner_missing:'+ $n)}
$idxSelect=$runnerText.IndexOf('$autonomousWakeFrontier=Select-AutonomousWakeFrontier')
$idxGoal=$runnerText.IndexOf('$internalGoal=New-InternalSelfGoal $selfBuild $body $memoryBefore $autonomousWakeFrontier')
$idxOwner=$runnerText.IndexOf('$internalGoal[''source'']=''OWNER_QUESTION_ACTIVE_GOAL''')
$idxLogic=$runnerText.IndexOf('$logicProblem=if($internalGoal -and $internalGoal.goal)')
Assert ($idxSelect -ge 0 -and $idxGoal -gt $idxSelect -and $idxOwner -gt $idxGoal -and $idxLogic -gt $idxOwner) 'wiring_order_invalid'
# Integration: the healthy self-chosen frontier goal is accepted by topic-general reasoner as its own topic.
$runtime='.runtime/autonomous_wake_frontier_selector_v1'
if(Test-Path $runtime){Remove-Item $runtime -Recurse -Force}
New-Item -ItemType Directory -Force -Path $runtime|Out-Null
$out=Join-Path $runtime 'healthy_reasoning.json'
$ro=@(& powershell -NoProfile -ExecutionPolicy Bypass -File $reasoner -Problem ([string]$healthy.selected_goal) -DisableMemoryRecall -OutputPath $out *>&1|ForEach-Object{[string]$_})
$rc=$LASTEXITCODE
Assert ($rc -eq 0) ('reasoner_exit:'+ $rc)
$r=if(Test-Path $out){Get-Content $out -Raw|ConvertFrom-Json}else{$null}
Assert ($null -ne $r) 'reasoner_output_missing'
if($r){Assert ($r.classification -eq 'GENERAL_LOGIC_TASK') ('reasoner_class:'+ $r.classification);Assert ($r.known[0].claim -eq ('Current reasoning topic: '+[string]$healthy.selected_goal)) 'reasoner_did_not_preserve_frontier_goal';Assert ($r.strongest_hypothesis.kind -eq 'source_gap') ('reasoner_winner:'+ $r.strongest_hypothesis.kind)}
$memRoot='.runtime/active_compact_semantic_memory_v1'
$hashes=[ordered]@{manifest=Sha (Join-Path $memRoot 'manifest.json');index=Sha (Join-Path $memRoot 'index.json');cells=Sha (Join-Path $memRoot 'cells.jsonl')}
$status=if($errors.Count -eq 0){'PASS_AUTONOMOUS_WAKE_FRONTIER_SELECTOR_V1'}else{'FAIL_AUTONOMOUS_WAKE_FRONTIER_SELECTOR_V1'}
$proof=[ordered]@{schema='autonomous_wake_frontier_selector_v1_proof';status=$status;checked_at=(Get-Date).ToUniversalTime().ToString('o');scenarios=[ordered]@{healthy=$healthy;repo_dirty=$dirty;memory_missing=$memoryMissing;fresh_self_build_gap=$freshBuild;avoid_knowledge=$avoidKnowledge};wiring=[ordered]@{selector_before_internal_goal=($idxSelect -ge 0 -and $idxGoal -gt $idxSelect);owner_override_after_autonomous_goal=($idxOwner -gt $idxGoal);reasoner_after_owner_override=($idxLogic -gt $idxOwner);reasoner_topic=if($r){$r.known[0].claim}else{$null};reasoner_winner=if($r){$r.strongest_hypothesis.kind}else{$null}};active_memory_hashes=$hashes;claims_proven=@('No Owner task is required to select an autonomous wake frontier.','Healthy state selects knowledge_source_gap rather than forcing self-build.','Fresh control/recovery signals outrank exploration.','Fresh explicit self-build gap can still win when actually proven current.','Avoid penalty can move the next frontier away from a repeated category.','Selected wake frontier is wired into internalGoal before topic-general reasoning; Owner task remains a later override.');does_not_prove=@('Full AIMO wake/runtime completes with this selector.','The selector has discovered a concrete external-domain research question.','External research is performed.','Learning atom is topic-aware or durable.','LIVE behavior or runtime_ready.');boundary=[ordered]@{lab_selector_only=$true;full_aimo_runtime_launched=$false;action_execution_allowed=$false;active_memory_mutated=$false;web_launched=$false;codex_launched=$false;school_launched=$false};errors=@($errors)}
$proof|ConvertTo-Json -Depth 80|Set-Content $proofPath -Encoding UTF8
$raw=Get-Content $proofPath -Raw;[IO.File]::WriteAllText((Resolve-Path $proofPath),($raw -replace "`r`n","`n").TrimEnd()+"`n",(New-Object Text.UTF8Encoding($false)))
Write-Host ('STATUS='+$status)
Write-Host ('HEALTHY_FRONTIER='+$healthy.selected_frontier)
Write-Host ('DIRTY_FRONTIER='+$dirty.selected_frontier)
Write-Host ('MEMORY_FRONTIER='+$memoryMissing.selected_frontier)
Write-Host ('FRESH_SELF_BUILD_FRONTIER='+$freshBuild.selected_frontier)
Write-Host ('AVOID_KNOWLEDGE_FRONTIER='+$avoidKnowledge.selected_frontier)
Write-Host ('REASONER_WINNER='+$(if($r){$r.strongest_hypothesis.kind}else{'MISSING'}))
if($errors.Count){$errors|ForEach-Object{Write-Host ('ERROR='+$_)};exit 1}
