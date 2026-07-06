[CmdletBinding()]
param(
  [string]$OperationId = "validate_json_schema_with_python_jsonschema",
  [string]$PlanPath = "operations/smoke_trials/FIRST_SMOKE_INSTALL_TRIAL_V1_PLAN.json",
  [string]$OperationContractPath = "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json",
  [string]$FixturesRoot = "operations/smoke_trials/fixtures/json_schema_validation",
  [string]$OutputReportPath = "reports/operations/FIRST_SMOKE_INSTALL_TRIAL_REPORT.json",
  [string]$TempRoot = $env:TEMP,
  [string]$RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$Phase = "PHASE_85"
$CapabilityId = "first_smoke_install_trial_v1"
$PackageName = "jsonschema"
$MaterialId = "mat_python_jsonschema_001"
$InstallMode = "TEMP_VENV_ONLY"
$NextAllowedStep = "PHASE86_OPERATION_RUNTIME_SKELETON_V1"
$ProtectedStatePaths = @(
  "materials/MATERIAL_CATALOG.json",
  "materials/MATERIAL_POLICY.json",
  "materials/quarantine/QUARANTINE_BATCH_001.json",
  "materials/quarantine/mat_json_schema_ajv_001/MATERIAL_CARD.json",
  "materials/quarantine/mat_python_jsonschema_001/MATERIAL_CARD.json",
  "operations/registry.json",
  "operations/contracts/validate_json_schema_with_ajv.contract.json",
  "operations/contracts/validate_json_schema_with_python_jsonschema.contract.json"
)

function Join-RepoPath {
  param([string]$Path)

  if ([System.IO.Path]::IsPathRooted($Path)) {
    return [System.IO.Path]::GetFullPath($Path)
  }

  return [System.IO.Path]::GetFullPath((Join-Path $RepoRoot $Path))
}

function Get-UtcStamp {
  return (Get-Date).ToUniversalTime().ToString("o")
}

function Read-JsonRequired {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    throw "MISSING_JSON=$Path"
  }

  return (Get-Content -LiteralPath $fullPath -Raw | ConvertFrom-Json)
}

function Write-JsonFile {
  param(
    [string]$Path,
    [object]$Object
  )

  $fullPath = Join-RepoPath $Path
  $directory = Split-Path -Parent $fullPath
  if (-not (Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }

  $json = ($Object | ConvertTo-Json -Depth 100) -replace "`r`n", "`n"
  if (-not $json.EndsWith("`n")) {
    $json += "`n"
  }
  [System.IO.File]::WriteAllText($fullPath, $json, [System.Text.UTF8Encoding]::new($false))
}

function Get-PropertyInfo {
  param(
    [object]$Object,
    [string]$Name
  )

  if ($null -eq $Object) {
    return $null
  }

  return $Object.PSObject.Properties | Where-Object { $_.Name -ieq $Name } | Select-Object -First 1
}

function Get-PropertyValue {
  param(
    [object]$Object,
    [string]$Name
  )

  $property = Get-PropertyInfo -Object $Object -Name $Name
  if ($null -eq $property) {
    return $null
  }

  return $property.Value
}

function Get-FileSha256 {
  param([string]$Path)

  $fullPath = Join-RepoPath $Path
  if (-not (Test-Path -LiteralPath $fullPath)) {
    return ""
  }
  return (Get-FileHash -LiteralPath $fullPath -Algorithm SHA256).Hash
}

function Get-ProtectedStateHashes {
  $hashes = [ordered]@{}
  foreach ($path in $ProtectedStatePaths) {
    $hashes[$path] = Get-FileSha256 -Path $path
  }
  return $hashes
}

function Compare-HashMaps {
  param(
    [object]$Before,
    [object]$After
  )

  foreach ($property in $Before.GetEnumerator()) {
    if (-not $After.Contains($property.Key)) {
      return $false
    }
    if ($After[$property.Key] -ne $property.Value) {
      return $false
    }
  }
  return $true
}

function Test-PathInside {
  param(
    [string]$CandidatePath,
    [string]$RootPath
  )

  $candidate = [System.IO.Path]::GetFullPath($CandidatePath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  $root = [System.IO.Path]::GetFullPath($RootPath).TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
  return $candidate.Equals($root, [System.StringComparison]::OrdinalIgnoreCase) -or
    $candidate.StartsWith($root + [System.IO.Path]::DirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase) -or
    $candidate.StartsWith($root + [System.IO.Path]::AltDirectorySeparatorChar, [System.StringComparison]::OrdinalIgnoreCase)
}

function Invoke-CapturedProcess {
  param(
    [string]$FilePath,
    [string[]]$Arguments,
    [string]$WorkingDirectory
  )

  $psi = [System.Diagnostics.ProcessStartInfo]::new()
  $psi.FileName = $FilePath
  foreach ($argument in $Arguments) {
    [void]$psi.ArgumentList.Add($argument)
  }
  $psi.WorkingDirectory = $WorkingDirectory
  $psi.RedirectStandardOutput = $true
  $psi.RedirectStandardError = $true
  $psi.UseShellExecute = $false
  $psi.CreateNoWindow = $true

  $process = [System.Diagnostics.Process]::Start($psi)
  $stdout = $process.StandardOutput.ReadToEnd()
  $stderr = $process.StandardError.ReadToEnd()
  $process.WaitForExit()

  return [pscustomobject]@{
    file_path = $FilePath
    arguments = @($Arguments)
    working_directory = $WorkingDirectory
    exit_code = $process.ExitCode
    stdout = $stdout.Trim()
    stderr = $stderr.Trim()
  }
}

function Resolve-PythonCommand {
  $py = Get-Command "py" -ErrorAction SilentlyContinue
  if ($null -ne $py) {
    try {
      $probe = Invoke-CapturedProcess -FilePath $py.Source -Arguments @("-3", "--version") -WorkingDirectory $RepoRoot
      if ($probe.exit_code -eq 0) {
        return [pscustomobject]@{
          label = "py -3"
          file_path = $py.Source
          prefix_arguments = @("-3")
          probe = $probe
        }
      }
    } catch {
      # Fall through to python below.
    }
  }

  $python = Get-Command "python" -ErrorAction SilentlyContinue
  if ($null -ne $python) {
    $probe = Invoke-CapturedProcess -FilePath $python.Source -Arguments @("--version") -WorkingDirectory $RepoRoot
    if ($probe.exit_code -eq 0) {
      return [pscustomobject]@{
        label = "python"
        file_path = $python.Source
        prefix_arguments = @()
        probe = $probe
      }
    }
  }

  throw "PYTHON_NOT_DISCOVERED"
}

function New-InitialReport {
  param([object]$ProtectedHashesBefore)

  return [ordered]@{
    report_id = "FIRST_SMOKE_INSTALL_TRIAL_REPORT"
    phase = $Phase
    capability_id = $CapabilityId
    status = "FAIL"
    generated_at = Get-UtcStamp
    operation_id = $OperationId
    related_material_id = $MaterialId
    package_name = $PackageName
    install_mode = $InstallMode
    sandbox_path = ""
    venv_path = ""
    sandbox_path_inside_repo = $false
    python_discovered = ""
    python_version = ""
    pip_version = ""
    package_version = ""
    venv_created = $false
    sandbox_install_attempted = $false
    sandbox_install_exit_code = -1
    package_import_pass = $false
    smoke_valid_case_pass = $false
    smoke_invalid_case_pass = $false
    global_install_performed = $false
    repo_dependency_folder_created = $false
    operation_marked_trusted = $false
    material_marked_trusted = $false
    execution_scope = "TEMP_VENV_ONLY"
    fixture_paths = [ordered]@{
      schema_path = (Join-Path $FixturesRoot "schema.json").Replace("\", "/")
      valid_instance_path = (Join-Path $FixturesRoot "valid_instance.json").Replace("\", "/")
      invalid_instance_path = (Join-Path $FixturesRoot "invalid_instance.json").Replace("\", "/")
    }
    command_evidence_summary = [ordered]@{}
    protected_state_hashes_before = $ProtectedHashesBefore
    protected_state_hashes_after = [ordered]@{}
    protected_state_unchanged = $false
    next_allowed_step = $NextAllowedStep
    cut_list = @(
      "Do not install globally.",
      "Do not use per-user package installation.",
      "Do not run npm, choco, or winget.",
      "Do not clone repositories.",
      "Do not create repo-local dependency folders.",
      "Do not create production wrappers.",
      "Do not mark operations or materials trusted.",
      "Do not mutate catalog, policy, quarantine cards, registry, or operation contracts."
    )
  }
}

Write-Host "FIRST_SMOKE_INSTALL_TRIAL_START"
Write-Host "SMOKE_OPERATION_ID=$OperationId"

$protectedHashesBefore = Get-ProtectedStateHashes
$report = New-InitialReport -ProtectedHashesBefore $protectedHashesBefore
$sandboxPath = ""

try {
  foreach ($marker in @("CAPABILITY_ROADMAP.json", "GENESIS_STATE.json", "TASK_QUEUE.json", "packs/registry.json", "orchestrator/run.ps1")) {
    if (-not (Test-Path -LiteralPath (Join-RepoPath $marker))) {
      throw "STOP=WRONG_AGENT_BUILDER_REPO missing $marker"
    }
  }

  if ([string]::IsNullOrWhiteSpace($TempRoot)) {
    $TempRoot = [System.IO.Path]::GetTempPath()
  }

  $plan = Read-JsonRequired $PlanPath
  if ("$(Get-PropertyValue -Object $plan -Name "selected_operation_id")" -ne $OperationId) {
    throw "PLAN_OPERATION_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $plan -Name "install_mode")" -ne $InstallMode) {
    throw "PLAN_INSTALL_MODE_MISMATCH"
  }

  $contract = Read-JsonRequired $OperationContractPath
  if ("$(Get-PropertyValue -Object $contract -Name "operation_id")" -ne $OperationId) {
    throw "CONTRACT_OPERATION_ID_MISMATCH"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "status")" -ne "CONTRACT_READY") {
    throw "CONTRACT_STATUS_NOT_READY"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "execution_mode")" -ne "NO_EXECUTION") {
    throw "CONTRACT_EXECUTION_MODE_NOT_NO_EXECUTION"
  }
  if ("$(Get-PropertyValue -Object $contract -Name "status")" -eq "TRUSTED_OPERATION") {
    throw "TRUSTED_OPERATION_FORBIDDEN"
  }

  $schemaPath = Join-RepoPath (Join-Path $FixturesRoot "schema.json")
  $validPath = Join-RepoPath (Join-Path $FixturesRoot "valid_instance.json")
  $invalidPath = Join-RepoPath (Join-Path $FixturesRoot "invalid_instance.json")
  foreach ($fixturePath in @($schemaPath, $validPath, $invalidPath)) {
    if (-not (Test-Path -LiteralPath $fixturePath)) {
      throw "MISSING_FIXTURE=$fixturePath"
    }
    Get-Content -LiteralPath $fixturePath -Raw | ConvertFrom-Json | Out-Null
  }

  $tempRootFull = [System.IO.Path]::GetFullPath($TempRoot)
  if (Test-PathInside -CandidatePath $tempRootFull -RootPath $RepoRoot) {
    throw "TEMP_ROOT_INSIDE_REPO_FORBIDDEN=$tempRootFull"
  }

  $sandboxPath = Join-Path $tempRootFull ("e_factory_phase85_" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $sandboxPath -Force | Out-Null
  $report["sandbox_path"] = $sandboxPath
  $report["sandbox_path_inside_repo"] = (Test-PathInside -CandidatePath $sandboxPath -RootPath $RepoRoot)
  if ([bool]$report["sandbox_path_inside_repo"]) {
    throw "SANDBOX_INSIDE_REPO_FORBIDDEN=$sandboxPath"
  }
  Write-Host "SMOKE_SANDBOX_ROOT=$sandboxPath"

  $python = Resolve-PythonCommand
  $report["python_discovered"] = $python.label
  $report["python_version"] = $python.probe.stdout
  if ([string]::IsNullOrWhiteSpace($report["python_version"])) {
    $report["python_version"] = $python.probe.stderr
  }
  Write-Host "PYTHON_DISCOVERED=$($python.label)"

  $venvPath = Join-Path $sandboxPath "venv"
  $venvArgs = @($python.prefix_arguments) + @("-m", "venv", $venvPath)
  $venvResult = Invoke-CapturedProcess -FilePath $python.file_path -Arguments $venvArgs -WorkingDirectory $sandboxPath
  $report["command_evidence_summary"]["venv_create"] = [ordered]@{
    exit_code = $venvResult.exit_code
    stdout = $venvResult.stdout
    stderr = $venvResult.stderr
  }
  if ($venvResult.exit_code -ne 0) {
    throw "VENV_CREATE_FAILED_EXIT_$($venvResult.exit_code)"
  }
  $report["venv_path"] = $venvPath
  $report["venv_created"] = $true
  Write-Host "VENV_CREATED=TRUE"

  $venvPython = Join-Path $venvPath "Scripts/python.exe"
  if (-not (Test-Path -LiteralPath $venvPython)) {
    $venvPython = Join-Path $venvPath "bin/python"
  }
  if (-not (Test-Path -LiteralPath $venvPython)) {
    throw "VENV_PYTHON_NOT_FOUND"
  }

  $report["sandbox_install_attempted"] = $true
  Write-Host "SANDBOX_INSTALL_ATTEMPTED=TRUE"
  $installResult = Invoke-CapturedProcess -FilePath $venvPython -Arguments @("-m", "pip", "install", "--disable-pip-version-check", $PackageName) -WorkingDirectory $sandboxPath
  $report["sandbox_install_exit_code"] = $installResult.exit_code
  $report["command_evidence_summary"]["install"] = [ordered]@{
    exit_code = $installResult.exit_code
    stdout_tail = ($installResult.stdout -split "`n" | Select-Object -Last 20) -join "`n"
    stderr_tail = ($installResult.stderr -split "`n" | Select-Object -Last 20) -join "`n"
  }
  Write-Host "SANDBOX_INSTALL_EXIT_CODE=$($installResult.exit_code)"
  if ($installResult.exit_code -ne 0) {
    throw "SANDBOX_INSTALL_FAILED_EXIT_$($installResult.exit_code)"
  }

  $pipVersion = Invoke-CapturedProcess -FilePath $venvPython -Arguments @("-m", "pip", "--version") -WorkingDirectory $sandboxPath
  $report["pip_version"] = $pipVersion.stdout

  $packageProbe = Invoke-CapturedProcess -FilePath $venvPython -Arguments @("-c", "import importlib.metadata as m; import jsonschema; print(m.version('jsonschema'))") -WorkingDirectory $sandboxPath
  $report["package_import_pass"] = ($packageProbe.exit_code -eq 0)
  $report["package_version"] = $packageProbe.stdout
  $report["command_evidence_summary"]["package_import"] = [ordered]@{
    exit_code = $packageProbe.exit_code
    stdout = $packageProbe.stdout
    stderr = $packageProbe.stderr
  }
  if (-not [bool]$report["package_import_pass"]) {
    throw "PACKAGE_IMPORT_FAILED"
  }
  Write-Host "PACKAGE_IMPORT_PASS=TRUE"

  $smokeScriptPath = Join-Path $sandboxPath "jsonschema_smoke.py"
  $smokeScript = @'
import json
import sys
from pathlib import Path

from jsonschema import ValidationError, validate

schema_path, valid_path, invalid_path = sys.argv[1:4]
schema = json.loads(Path(schema_path).read_text(encoding="utf-8"))
valid_instance = json.loads(Path(valid_path).read_text(encoding="utf-8"))
invalid_instance = json.loads(Path(invalid_path).read_text(encoding="utf-8"))

result = {
    "valid_case_pass": False,
    "invalid_case_pass": False,
    "invalid_error": "",
}

try:
    validate(instance=valid_instance, schema=schema)
    result["valid_case_pass"] = True
except Exception as exc:
    result["valid_error"] = str(exc)

try:
    validate(instance=invalid_instance, schema=schema)
    result["invalid_error"] = "invalid fixture unexpectedly passed"
except ValidationError as exc:
    result["invalid_case_pass"] = True
    result["invalid_error"] = exc.message

print(json.dumps(result, sort_keys=True))
sys.exit(0 if result["valid_case_pass"] and result["invalid_case_pass"] else 1)
'@
  [System.IO.File]::WriteAllText($smokeScriptPath, $smokeScript, [System.Text.UTF8Encoding]::new($false))

  $smokeResult = Invoke-CapturedProcess -FilePath $venvPython -Arguments @($smokeScriptPath, $schemaPath, $validPath, $invalidPath) -WorkingDirectory $sandboxPath
  $smokeJson = $null
  if (-not [string]::IsNullOrWhiteSpace($smokeResult.stdout)) {
    $smokeJson = $smokeResult.stdout | ConvertFrom-Json
  }
  $report["smoke_valid_case_pass"] = [bool](Get-PropertyValue -Object $smokeJson -Name "valid_case_pass")
  $report["smoke_invalid_case_pass"] = [bool](Get-PropertyValue -Object $smokeJson -Name "invalid_case_pass")
  $report["command_evidence_summary"]["smoke"] = [ordered]@{
    exit_code = $smokeResult.exit_code
    stdout = $smokeResult.stdout
    stderr = $smokeResult.stderr
  }
  if ($smokeResult.exit_code -ne 0) {
    throw "SMOKE_SCRIPT_FAILED_EXIT_$($smokeResult.exit_code)"
  }
  if (-not [bool]$report["smoke_valid_case_pass"]) {
    throw "SMOKE_VALID_CASE_FAILED"
  }
  if (-not [bool]$report["smoke_invalid_case_pass"]) {
    throw "SMOKE_INVALID_CASE_FAILED"
  }
  Write-Host "SMOKE_VALID_CASE_PASS=TRUE"
  Write-Host "SMOKE_INVALID_CASE_PASS=TRUE"

  $protectedHashesAfter = Get-ProtectedStateHashes
  $report["protected_state_hashes_after"] = $protectedHashesAfter
  $report["protected_state_unchanged"] = Compare-HashMaps -Before $protectedHashesBefore -After $protectedHashesAfter
  if (-not [bool]$report["protected_state_unchanged"]) {
    throw "PROTECTED_STATE_MUTATED"
  }

  $report["status"] = "PASS"
  Write-Host "GLOBAL_INSTALL_PERFORMED=FALSE"
  Write-Host "OPERATION_MARKED_TRUSTED=FALSE"
  Write-JsonFile -Path $OutputReportPath -Object $report
  Write-Host "FIRST_SMOKE_INSTALL_TRIAL_REPORT_WRITTEN=$OutputReportPath"
  Write-Host "FIRST_SMOKE_INSTALL_TRIAL_COMPLETE"

  return [pscustomobject]$report
} catch {
  $failureMessage = $_.Exception.Message
  $report["status"] = "FAIL"
  $report["failure"] = $failureMessage
  $protectedHashesAfter = Get-ProtectedStateHashes
  $report["protected_state_hashes_after"] = $protectedHashesAfter
  $report["protected_state_unchanged"] = Compare-HashMaps -Before $protectedHashesBefore -After $protectedHashesAfter
  Write-JsonFile -Path $OutputReportPath -Object $report
  Write-Host "FAIL=$failureMessage"
  Write-Host "FIRST_SMOKE_INSTALL_TRIAL_REPORT_WRITTEN=$OutputReportPath"
  throw
}
