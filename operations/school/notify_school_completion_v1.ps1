param(
  [Parameter(Mandatory=$true)][string]$RepoRoot,
  [Parameter(Mandatory=$true)][string]$SchoolProofPath,
  [string]$ReceiptRoot=(Join-Path $env:ProgramData 'EFAB-Notifications')
)
$ErrorActionPreference='Stop'
Set-Location $RepoRoot
$repo=(Resolve-Path '.').Path
$ctl='operations/control_center/invoke_builder_control_center_v1.ps1'
if(-not(Test-Path $ctl)){throw 'CONTROL_CENTER_MISSING'}
$full=[IO.Path]::GetFullPath((Join-Path $repo $SchoolProofPath));if(-not$full.StartsWith($repo,[StringComparison]::OrdinalIgnoreCase)){throw 'SCHOOL_PROOF_OUTSIDE_REPO'}
if(-not(Test-Path $full -PathType Leaf)){throw 'SCHOOL_PROOF_NOT_FOUND'}
$proof=Get-Content $full -Raw|ConvertFrom-Json;$runId=[string]$proof.run_id;if([string]::IsNullOrWhiteSpace($runId)){throw 'SCHOOL_PROOF_RUN_ID_MISSING'}
$receipt=Join-Path $ReceiptRoot ($runId+'.telegram.json')
foreach($name in @('TELEGRAM_BOT_TOKEN','TELEGRAM_CHAT_ID')){
  if([string]::IsNullOrWhiteSpace([Environment]::GetEnvironmentVariable($name,'Process'))){
    $machine=[Environment]::GetEnvironmentVariable($name,'Machine')
    if(-not[string]::IsNullOrWhiteSpace($machine)){[Environment]::SetEnvironmentVariable($name,$machine,'Process')}
  }
}
if(Test-Path $receipt){$existing=Get-Content $receipt -Raw|ConvertFrom-Json;if([string]$existing.status -eq 'DELIVERED'){Write-Host 'NOTIFICATION_STATUS=ALREADY_DELIVERED';Write-Host ('NOTIFICATION_RECEIPT='+$receipt);exit 0}}
$plan=& $ctl -Mode Run -Action @('school.notification.plan') -SchoolProofPath $SchoolProofPath -Json|ConvertFrom-Json
$pr=@($plan.results|Where-Object id -eq 'school.notification.plan')|Select-Object -First 1
if(-not$pr -or [string]$pr.status -ne 'NOTIFICATION_PLAN_READY'){Write-Host ('NOTIFICATION_STATUS=PLAN_NOT_READY:'+[string]$pr.status);exit 0}
if([string]$pr.transport_state -eq 'MISSING_CREDENTIALS'){Write-Host 'NOTIFICATION_STATUS=PENDING_CREDENTIALS';exit 0}
$send=& $ctl -Mode Run -Action @('school.notification.send') -SchoolProofPath $SchoolProofPath -ConfirmMutation -Json|ConvertFrom-Json
$sr=@($send.results|Where-Object id -eq 'school.notification.send')|Select-Object -First 1
if($sr -and [string]$sr.status -eq 'DELIVERED'){
  if(-not(Test-Path $ReceiptRoot)){New-Item -ItemType Directory -Force -Path $ReceiptRoot|Out-Null}
  [ordered]@{schema='school_completion_notification_receipt_v1';run_id=$runId;proof_sha256=[string]$sr.proof_sha256;channel='telegram';status='DELIVERED';message_id=[int64]$sr.telegram.message_id;date=[int64]$sr.telegram.date;recorded_at=(Get-Date).ToString('o')}|ConvertTo-Json -Depth 8|Set-Content -LiteralPath $receipt -Encoding UTF8
  Write-Host 'NOTIFICATION_STATUS=DELIVERED';Write-Host ('NOTIFICATION_RECEIPT='+$receipt);exit 0
}
Write-Host ('NOTIFICATION_STATUS=DELIVERY_NOT_PROVEN:'+[string]$sr.status)
exit 0
