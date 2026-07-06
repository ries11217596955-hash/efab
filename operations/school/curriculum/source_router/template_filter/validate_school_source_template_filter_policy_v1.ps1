param([string]$PolicyPath='operations/school/curriculum/source_router/template_filter/school_source_template_filter_policy.json')
$ErrorActionPreference='Stop'
Set-Location (git rev-parse --show-toplevel).Trim()
if(-not(Test-Path $PolicyPath)){ throw "POLICY_MISSING:$PolicyPath" }
$p=Get-Content $PolicyPath -Raw | ConvertFrom-Json
$blockers=@()
if($p.schema -ne 'school_source_template_filter_policy_v1'){ $blockers+='SCHEMA_BAD' }
if(@($p.source_ladder).Count -lt 8){ $blockers+='SOURCE_LADDER_TOO_SMALL' }
foreach($tier in @('official_docs','sponsored_ad','seo_scraper_content_farm')){ if(@($p.source_ladder.tier) -notcontains $tier){ $blockers += "TIER_MISSING:$tier" } }
$ad=@($p.source_ladder|Where-Object{$_.tier -eq 'sponsored_ad'}|Select-Object -First 1)
if(-not $ad -or [double]$ad.authority_score -ne 0 -or $ad.action -ne 'reject'){ $blockers+='SPONSORED_AD_NOT_REJECTED' }
if(@($p.blocked_result_types) -notcontains 'sponsored'){ $blockers+='SPONSORED_BLOCK_MISSING' }
if(@($p.blocked_result_types) -notcontains 'ad'){ $blockers+='AD_BLOCK_MISSING' }
if(-not $p.source_selection_rules.internal_factory_healthy){ $blockers+='INTERNAL_HEALTHY_RULE_MISSING' }
if(-not $p.source_selection_rules.internal_factory_stale){ $blockers+='INTERNAL_STALE_RULE_MISSING' }
if(-not $p.source_selection_rules.external_required_or_codex_unavailable){ $blockers+='EXTERNAL_ESCALATION_RULE_MISSING' }
if($p.boundary -notmatch 'not school brain|not accepted memory|not source proof'){ $blockers+='BOUNDARY_WEAK' }
$status=if($blockers.Count -eq 0){'PASS_SCHOOL_SOURCE_TEMPLATE_FILTER_POLICY_V1'}else{'FAIL_SCHOOL_SOURCE_TEMPLATE_FILTER_POLICY_V1'}
$proof='operations/reports/SCHOOL_SOURCE_TEMPLATE_FILTER_POLICY_VALIDATION_V1.json'
New-Item -ItemType Directory -Force -Path (Split-Path $proof -Parent) | Out-Null
[ordered]@{schema='school_source_template_filter_policy_validation_v1';status=$status;policy_path=$PolicyPath;blockers=@($blockers);source_ladder_count=@($p.source_ladder).Count;checked_at=(Get-Date).ToString('o')} | ConvertTo-Json -Depth 60 | Set-Content -LiteralPath $proof -Encoding UTF8
Write-Host "TEMPLATE_FILTER_POLICY_STATUS=$status"
Write-Host "TEMPLATE_FILTER_POLICY_PROOF=$proof"
if($status -notlike 'PASS_*'){ exit 1 }
