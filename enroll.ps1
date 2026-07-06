<#
  enroll.ps1  --  PUBLIC enrollment scaffold for Xzibit kiosks.

  The one thing you paste on a fresh kiosk. It installs the kiosk deploy AGENT,
  which then manages every component (stats, app, scripts) per the fleet
  manifest. Contains NOTHING sensitive: no token, no data URLs.

  Interactive (recommended - secure token prompt, nothing in shell history):
    iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v2/enroll.ps1 | iex

  Non-interactive (token via env so it stays off the command line):
    $env:GITHUB_TOKEN='github_pat_xxx'; iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v2/enroll.ps1 | iex

  The kiosk's hostname must be registered in the fleet manifest
  (devices.<HOSTNAME>.components) before enrolling.
#>
param(
  [string]$Token,
  [string]$ManifestUrl = 'https://api.github.com/repos/xzibit-pty-ltd/kiosk-fleet/contents/manifest.json',
  [string]$AgentRepo   = 'xzibit-pty-ltd/kiosk-agent',
  [string]$AgentRef,   # empty => newest release
  [string]$CodeRoot, [string]$DataRoot
)
$ErrorActionPreference = 'Stop'
$IsWin = ($env:OS -eq 'Windows_NT')
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

Say ''
Say '  Xzibit kiosk enrolment' 'Cyan'
Say '  ----------------------'

# --- preflight ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($PSVersionTable.PSVersion.Major -lt 5) { Say "  ERROR: PowerShell 5+ required (found $($PSVersionTable.PSVersion))." 'Red'; return }
if ($IsWin) {
  $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $admin) { Say '  ERROR: run this in an Administrator PowerShell (right-click > Run as administrator).' 'Yellow'; return }
}
Say "  host: $env:COMPUTERNAME   PowerShell: $($PSVersionTable.PSVersion)"

# --- token: -Token, else $env:GITHUB_TOKEN, else secure prompt ---
if (-not $Token) { $Token = $env:GITHUB_TOKEN }
if (-not $Token) {
  $sec = Read-Host '  Paste the read-only GitHub PAT' -AsSecureString
  if ($sec.Length -gt 0) {
    $bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) } finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  }
}
if (-not $Token) { Say '  No token provided - aborting.' 'Red'; return }
$env:GITHUB_TOKEN = $Token   # handed to install-agent via env, never a command-line arg
$h = @{ Authorization = "Bearer $Token"; 'User-Agent' = 'kiosk-enroll'; Accept = 'application/vnd.github.raw' }

# --- resolve the agent release + fetch its installer ---
if (-not $AgentRef) {
  try { $AgentRef = (Invoke-RestMethod -Headers $h "https://api.github.com/repos/$AgentRepo/releases/latest" -TimeoutSec 30).tag_name }
  catch { Say "  ERROR: cannot resolve $AgentRepo latest (the PAT needs Contents:read on it). $($_.Exception.Message)" 'Red'; return }
}
Say "  fetching install-agent ($AgentRepo@$AgentRef) ..."
$ia = Join-Path ([IO.Path]::GetTempPath()) 'install-agent.ps1'
try { Invoke-WebRequest -UseBasicParsing -Headers $h "https://api.github.com/repos/$AgentRepo/contents/install-agent.ps1?ref=$AgentRef" -OutFile $ia -TimeoutSec 60 }
catch { Say "  ERROR: cannot fetch install-agent. Check the PAT has Contents:read on $AgentRepo. $($_.Exception.Message)" 'Red'; return }

# --- run it (token via env; installs agent, ACLs the root, schedules reconcile) ---
$psExe  = if ($IsWin) { 'powershell.exe' } else { 'pwsh' }
$iaArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ia, '-ManifestUrl', $ManifestUrl, '-AgentRepo', $AgentRepo)
if ($CodeRoot) { $iaArgs += @('-CodeRoot', $CodeRoot) }
if ($DataRoot) { $iaArgs += @('-DataRoot', $DataRoot) }
Say '  installing the agent ...' 'Cyan'
& $psExe @iaArgs
$code = $LASTEXITCODE
Remove-Item $ia -Force -ErrorAction SilentlyContinue
Say ''
if ($code -eq 0 -or $null -eq $code) { Say '  enrolment finished - the agent will reconcile this kiosk to the manifest.' 'Green' }
else { Say "  install-agent exited with code $code - see the output above." 'Yellow' }
