[CmdletBinding()]param()
$ErrorActionPreference='Stop'
$RepoRoot=(git rev-parse --show-toplevel).Trim();Set-Location $RepoRoot
$contractPath='self_model/CAPABILITY_INVOCATION_MAP_V1_CONTRACT.json'
$bodyPath='reports/self_development/agent_body_map.json'
$retirementProof='tests/self_development/PHASE84_86_OPERATION_RUNTIME_RETIREMENT_AND_DELETE_V1_PROOF.json'
$outJson='reports/self_development/CAPABILITY_INVOCATION_MAP_V1.json'
$outMd='docs/operations/CAPABILITY_INVOCATION_MAP_V1.md'
$outProof='tests/self_development/CAPABILITY_INVOCATION_MAP_V1_PROOF.json'
foreach($p in @($contractPath,$bodyPath,$retirementProof)){if(-not(Test-Path $p)){throw "SOURCE_MISSING:$p"}}
$c=Get-Content $contractPath -Raw|ConvertFrom-Json
$b=Get-Content $bodyPath -Raw|ConvertFrom-Json
$bodyIds=@($b.components.id)
$tasks=@(Get-ChildItem tasks -File -Filter '*.json'|Sort-Object Name)
$capabilities=New-Object System.Collections.Generic.List[object]
$noId=New-Object System.Collections.Generic.List[object]
$usedTaskRefs=New-Object System.Collections.Generic.List[string]
foreach($f in $tasks){
 $rel='tasks/'+$f.Name
 $t=Get-Content $f.FullName -Raw|ConvertFrom-Json
 $cid=[string]$t.capability_id
 if([string]::IsNullOrWhiteSpace($cid)){
  $noId.Add([pscustomobject][ordered]@{gap_id='TASK_CAPABILITY_ID_MISSING';source_task_ref=$rel;task_id=[string]$t.task_id;reason='Current task source has no explicit capability_id; generator does not fabricate one.'})
  continue
 }
 $usedTaskRefs.Add($rel)
 $gaps=New-Object System.Collections.Generic.List[string]
 $owner=$null
 if($bodyIds -contains $cid){$owner=$cid}else{$gaps.Add('OWNING_ORGAN_UNRESOLVED')}
 $desc=$null
 foreach($field in @('objective','purpose','title')){if($t.PSObject.Properties.Name -contains $field){$v=[string]$t.$field;if(-not[string]::IsNullOrWhiteSpace($v)){$desc=$v;break}}}
 if([string]::IsNullOrWhiteSpace($desc)){$gaps.Add('WHAT_IT_DOES_UNSPECIFIED')}
 $proofs=New-Object System.Collections.Generic.List[string]
 if($t.PSObject.Properties.Name -contains 'runtime_proof_path'){$v=[string]$t.runtime_proof_path;if(-not[string]::IsNullOrWhiteSpace($v)){if(Test-Path $v){$proofs.Add($v)}else{$gaps.Add('EXPLICIT_RUNTIME_PROOF_PATH_MISSING')}}}
 $reports=New-Object System.Collections.Generic.List[string]
 if($t.PSObject.Properties.Name -contains 'runtime_report_path'){$v=[string]$t.runtime_report_path;if(-not[string]::IsNullOrWhiteSpace($v)){if(Test-Path $v){$reports.Add($v)}else{$gaps.Add('EXPLICIT_RUNTIME_REPORT_PATH_MISSING')}}}
 $scripts=New-Object System.Collections.Generic.List[string]
 if($t.PSObject.Properties.Name -contains 'source_program_path'){$v=[string]$t.source_program_path;if(-not[string]::IsNullOrWhiteSpace($v)){if(Test-Path $v){$scripts.Add($v)}else{$gaps.Add('EXPLICIT_SOURCE_PROGRAM_PATH_MISSING')}}}
 $gaps.Add('INPUTS_UNSPECIFIED');$gaps.Add('OUTPUTS_UNSPECIFIED');$gaps.Add('VALIDATOR_REF_UNSPECIFIED');$gaps.Add('INVOCATION_UNSPECIFIED')
 $capabilities.Add([pscustomobject][ordered]@{
  capability_id=$cid
  display_name=(Get-Culture).TextInfo.ToTitleCase(($cid -replace '_',' '))
  owning_organ_id=$owner
  organ_inventory_ref=if($owner){$bodyPath+'#components[id='+$owner+']'}else{$bodyPath}
  what_it_does=$desc
  invocation_modes=@()
  primary_invocation=$null
  inputs=@()
  outputs=@()
  validator_refs=@()
  proof_refs=@($proofs)
  safety_boundary='NOT_INVOKABLE_FROM_V1_MAP_UNLESS_EXPLICIT_COMPLETE_INVOCATION_MODE_IS_PRESENT_AND_VALIDATED'
  maturity='DRAFT_NORMALIZED'
  live_or_lab_status='NOT_PROVEN'
  source_task_refs=@($rel)
  source_script_refs=@($scripts)
  source_report_refs=@($reports)
  gaps=@($gaps|Sort-Object -Unique)
  do_not_use_for=@('direct invocation','live mutation authority','acceptance proof','claiming capability maturity beyond attached proof')
 })
}
$capabilities=@($capabilities|Sort-Object capability_id)
$duplicateCaps=@($capabilities|Group-Object -Property capability_id|Where-Object Count -gt 1)
if($duplicateCaps.Count){throw ('DUPLICATE_CAPABILITY_IDS:'+(($duplicateCaps.Name)-join','))}
$retired=@($c.coverage_requirements_for_v1.retired_task_refs)
$legacy=@(
 [ordered]@{source='self_knowledge/MODULE_INVENTORY.json';role='LEGACY_REFERENCE_ONLY'},
 [ordered]@{source='self_knowledge/CAPABILITY_MANIFEST.json';role='LEGACY_REFERENCE_ONLY'},
 [ordered]@{source='CAPABILITY_ROADMAP.json';role='SOURCE_MATERIAL_NOT_CURRENT_AUTHORITY'},
 [ordered]@{source=$retirementProof;role='RETIREMENT_ACCOUNTING_PROOF'}
)
foreach($r in $retired){$legacy += [ordered]@{source=$r;role='RETIRED_TASK_LEGACY_PROVENANCE_ONLY'}}
$noIdItems=@($noId | ForEach-Object { $_ })
$gapSummary=@(
 [pscustomobject][ordered]@{gap_id='TASKS_WITHOUT_CAPABILITY_ID';count=$noId.Count;items=$noIdItems},
 [pscustomobject][ordered]@{gap_id='CAPABILITIES_WITH_UNRESOLVED_OWNER';count=@($capabilities|Where-Object{$null-eq$_.owning_organ_id}).Count},
 [pscustomobject][ordered]@{gap_id='CAPABILITIES_WITHOUT_VALIDATOR_REF';count=@($capabilities|Where-Object{@($_.validator_refs).Count-eq0}).Count},
 [pscustomobject][ordered]@{gap_id='CAPABILITIES_WITHOUT_INVOCATION_MODE';count=@($capabilities|Where-Object{@($_.invocation_modes).Count-eq0}).Count},
 [pscustomobject][ordered]@{gap_id='CAPABILITIES_WITHOUT_EXPLICIT_INPUTS';count=@($capabilities|Where-Object{@($_.inputs).Count-eq0}).Count},
 [pscustomobject][ordered]@{gap_id='CAPABILITIES_WITHOUT_EXPLICIT_OUTPUTS';count=@($capabilities|Where-Object{@($_.outputs).Count-eq0}).Count}
)
$now=(Get-Date).ToUniversalTime().ToString('o')
$map=[ordered]@{
 schema='capability_invocation_map_v1'
 status='DRAFT_NORMALIZED_WITH_GAPS'
 generated_from=[ordered]@{contract=$contractPath;body_inventory=$bodyPath;task_glob='tasks/*.json';retirement_proof=$retirementProof;generator='operations/self_model/export_capability_invocation_map_v1.ps1';head=(git rev-parse HEAD).Trim()}
 capabilities=$capabilities
 coverage=[ordered]@{current_tasks_seen=$tasks.Count;current_tasks_with_capability_id=$usedTaskRefs.Count;normalized_capabilities=$capabilities.Count;tasks_without_capability_id=$noId.Count;retired_tasks_accounted=$retired.Count;historical_task_baseline=[int]$c.coverage_requirements_for_v1.historical_task_baseline;accounted_total=$tasks.Count+$retired.Count;unexplained_historical_task_loss=[int]$c.coverage_requirements_for_v1.historical_task_baseline-($tasks.Count+$retired.Count);explicit_runtime_proof_paths_kept=@($capabilities|ForEach-Object{$_.proof_refs}|Where-Object{$_}).Count;explicit_source_program_paths_kept=@($capabilities|ForEach-Object{$_.source_script_refs}|Where-Object{$_}).Count;explicit_runtime_report_paths_kept=@($capabilities|ForEach-Object{$_.source_report_refs}|Where-Object{$_}).Count}
 gaps=$gapSummary
 legacy_sources=$legacy
 live_process_touched=$false
 active_memory_mutated=$false
 created_at=$now
}
$map|ConvertTo-Json -Depth 30|Set-Content -LiteralPath $outJson -Encoding UTF8
$md=New-Object System.Collections.Generic.List[string]
$md.Add('# Capability Invocation Map V1')
$md.Add('')
$md.Add('Status: `DRAFT_NORMALIZED_WITH_GAPS`')
$md.Add('')
$md.Add('This map is generated from current task sources and the current body inventory. Missing invocation/validator/organ information remains an explicit gap; it is not guessed.')
$md.Add('')
$md.Add('## Coverage')
$md.Add('')
$md.Add(('- Current tasks: **{0}**' -f $tasks.Count));$md.Add(('- Normalized capabilities: **{0}**' -f $capabilities.Count));$md.Add(('- Tasks without capability_id: **{0}**' -f $noId.Count));$md.Add(('- Retired tasks accounted: **{0}**' -f $retired.Count));$md.Add(('- Historical accounted total: **{0}/{1}**' -f ($tasks.Count+$retired.Count),[int]$c.coverage_requirements_for_v1.historical_task_baseline))
$md.Add('')
$md.Add('## Capabilities')
$md.Add('')
$md.Add('| capability_id | owner | maturity | live/lab | proofs | gaps |')
$md.Add('|---|---|---|---|---:|---:|')
foreach($cap in $capabilities){$md.Add(('| `{0}` | `{1}` | `{2}` | `{3}` | {4} | {5} |' -f $cap.capability_id,$(if($cap.owning_organ_id){$cap.owning_organ_id}else{'UNRESOLVED'}),$cap.maturity,$cap.live_or_lab_status,@($cap.proof_refs).Count,@($cap.gaps).Count))}
$md.Add('')
$md.Add('## Global gaps')
$md.Add('')
foreach($g in $gapSummary){$md.Add(('- `{0}`: {1}' -f $g.gap_id,$g.count))}
$md.Add('')
$md.Add('## Boundary')
$md.Add('')
$md.Add('This draft is not invocation authority, not live proof, and not maturity acceptance. A capability with no complete invocation mode must not be invoked from this map.')
$md|Set-Content -LiteralPath $outMd -Encoding UTF8
$proof=[ordered]@{schema='capability_invocation_map_v1_generation_proof';status='PASS_CAPABILITY_INVOCATION_MAP_V1_DRAFT_GENERATION_CANDIDATE';map_path=$outJson;doc_path=$outMd;generator_path='operations/self_model/export_capability_invocation_map_v1.ps1';contract_path=$contractPath;body_map_path=$bodyPath;current_tasks_seen=$tasks.Count;normalized_capabilities=$capabilities.Count;tasks_without_capability_id=$noId.Count;retired_tasks_accounted=$retired.Count;accounted_total=$tasks.Count+$retired.Count;historical_baseline=[int]$c.coverage_requirements_for_v1.historical_task_baseline;unexplained_historical_task_loss=[int]$c.coverage_requirements_for_v1.historical_task_baseline-($tasks.Count+$retired.Count);map_sha256=(Get-FileHash -Algorithm SHA256 $outJson).Hash;live_process_touched=$false;active_memory_mutated=$false;does_not_prove=@('capability maturity','invocation readiness','live behavior','organ ownership where unresolved');created_at=$now}
$proof|ConvertTo-Json -Depth 20|Set-Content -LiteralPath $outProof -Encoding UTF8
Write-Output ('PASS_CAPABILITY_INVOCATION_MAP_V1_EXPORT|TASKS='+$tasks.Count+'|CAPABILITIES='+$capabilities.Count+'|NO_CAPABILITY_ID='+$noId.Count+'|RETIRED='+$retired.Count+'|ACCOUNTED='+($tasks.Count+$retired.Count))
