param(
  [string]$ResultPath = 'reports/self_development/branch_agnostic_map_refresh_result.json',
  [string]$RequiredMarker = 'AUTONOMOUS_INNER_MOTOR_ORGAN',
  [switch]$RequireCurrentHead
)
$ErrorActionPreference = 'Stop'
$args = @('-NoProfile','-ExecutionPolicy','Bypass','-File','validators/validate_agent_body_composition_map_current_v1.ps1','-ResultPath',$ResultPath)
if($RequireCurrentHead){ $args += '-RequireCurrentHead' }
& powershell @args
if($LASTEXITCODE -ne 0){ exit $LASTEXITCODE }
$outRoot='.runtime/map_control/validations'
New-Item -ItemType Directory -Force -Path $outRoot | Out-Null
$out=[ordered]@{
  schema='BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT_VALIDATION_V3'
  status='PASS_BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT'
  checked_at=(Get-Date).ToString('o')
  branch=(git branch --show-current).Trim()
  head=(git rev-parse HEAD).Trim()
  result_path=$ResultPath
  delegated_validator='validators/validate_agent_body_composition_map_current_v1.ps1'
  active_map_schema='AGENT_BODY_COMPOSITION_MAP_V1'
  errors=@()
  boundary='Runtime validation proof only. No tracked validation JSON mutation.'
}
$outPath=Join-Path $outRoot 'branch_agnostic_map_refresh_validation.json'
$out|ConvertTo-Json -Depth 18|Set-Content -Path $outPath -Encoding UTF8
Write-Host 'STATUS=PASS_BRANCH_AGNOSTIC_MAP_REFRESH_CONTRACT'
Write-Host "VALIDATION_PATH=$outPath"