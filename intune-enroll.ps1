<#
  intune-enroll.ps1  --  Intune platform script to enrol/refresh an Xzibit kiosk.

  Deploy via: Intune admin center > Devices > Scripts and remediations >
              Platform scripts > Add (Windows), paste this, assign to the kiosk group.
    Run this script using the logged-on credentials : No   (runs as SYSTEM)
    Enforce script signature check                  : No
    Run script in 64-bit PowerShell                 : Yes

  It hands the token to the public enroll scaffold (which fetches install-agent and
  lays down the agent), then VERIFIES the end-state so Intune shows an accurate
  per-device result.

  Idempotent + rotation:
    - First run bootstraps the agent.
    - Editing this script (e.g. a new token) makes Intune re-run it on assigned
      devices; re-running rewrites agent-config.json, so it doubles as credential
      rotation. (For time-based rotation instead of edit-based, use a Remediation.)

  The PAT below should be a READ-ONLY fine-grained PAT scoped to ALL repositories
  (Contents: read) of the org, so new component repos need no PAT change.
#>

# ===== CONFIG (edit these) ========================================================
$GitHubToken = 'REPLACE_WITH_READONLY_PAT'
$ManifestUrl = 'https://api.github.com/repos/xzibit-pty-ltd/kiosk-fleet/contents/manifest.json'
$EnrollUrl   = 'https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v2/enroll.ps1'
$AgentDir    = 'C:\ProgramData\Xzibit\Kiosk\agent'   # install-agent default CodeRoot\agent
# ==================================================================================

$ErrorActionPreference = 'Stop'
$ProgressPreference    = 'SilentlyContinue'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Log($m) { Write-Output ("[intune-enroll] {0}  {1}" -f (Get-Date -Format 's'), $m) }

if (-not $GitHubToken -or $GitHubToken -eq 'REPLACE_WITH_READONLY_PAT') {
  Log 'ERROR: set $GitHubToken in the script before assigning.'; exit 1
}

try {
  Log "host $env:COMPUTERNAME - fetching enroll scaffold"
  $enroll = Join-Path $env:TEMP 'kiosk-enroll.ps1'
  Invoke-WebRequest -UseBasicParsing -Uri $EnrollUrl -OutFile $enroll -TimeoutSec 60   # public, no token

  $env:GITHUB_TOKEN = $GitHubToken   # via env, never a command-line arg
  try {
    Log 'running enroll (bootstrap on first run; refreshes agent-config/token on re-run)'
    & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $enroll -ManifestUrl $ManifestUrl 2>&1 | ForEach-Object { Log "  $_" }
  } finally {
    $env:GITHUB_TOKEN = $null
    Remove-Item $enroll -Force -ErrorAction SilentlyContinue
  }

  # --- verify end-state (enroll uses `return`, not exit codes, so check ourselves) ---
  $cfgPath = Join-Path $AgentDir 'agent-config.json'
  if (-not (Test-Path $cfgPath)) { Log "FAILED: $cfgPath not written"; exit 1 }
  $cfg = Get-Content -Raw $cfgPath | ConvertFrom-Json
  if ($cfg.githubToken -ne $GitHubToken) { Log 'FAILED: token in agent-config.json does not match (rotation not applied)'; exit 1 }
  if (-not (Get-ScheduledTask -TaskName 'Kiosk Agent Reconcile' -ErrorAction SilentlyContinue)) { Log 'FAILED: reconcile task not registered'; exit 1 }

  Log 'OK: agent installed, credential current, reconcile task registered'
  exit 0
} catch {
  Log "ERROR: $($_.Exception.Message)"
  exit 1
}
