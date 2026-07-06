<#
  enroll.ps1  --  PUBLIC enrollment scaffold for Xzibit kiosks.

  The one thing you paste on a fresh kiosk. It preflight-checks the machine,
  takes a read-only GitHub PAT, fetches the PRIVATE bootstrap.ps1, and runs it.
  Contains NOTHING sensitive: no token, no LifeFlight URL. The manifest URL is
  just a pointer (useless without the PAT), so it's fine to bake in here.

  Interactive (nice CLI prompt, secure token entry):
    iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1/enroll.ps1 | iex

  Non-interactive (everything on the line):
    & ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1/enroll.ps1).Content)) -Token 'github_pat_xxx' [-SplashPath 'C:\...\splash.json']
#>
param(
  [string]$Token,
  [string]$ManifestUrl  = 'https://api.github.com/repos/xzibit-pty-ltd/kiosk-fleet/contents/manifest.json',
  [string]$ScriptsRepo  = 'xzibit-pty-ltd/lfac-av-stats-sync',
  [string]$BootstrapRef = 'v1.0.2',
  [string]$InstallPath,
  [string]$SplashPath
)
$ErrorActionPreference = 'Stop'
$IsWin = ($env:OS -eq 'Windows_NT')
$interactive = -not $PSBoundParameters.ContainsKey('Token')   # bare run => prompt flow
function Say($m, $c = 'Gray') { Write-Host $m -ForegroundColor $c }

Say ''
Say '  Xzibit kiosk enrollment' 'Cyan'
Say '  -----------------------'

# --- preflight ---
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
if ($PSVersionTable.PSVersion.Major -lt 5) { Say "  ERROR: PowerShell 5+ required (found $($PSVersionTable.PSVersion))." 'Red'; return }
if ($IsWin) {
  $admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
  if (-not $admin) { Say '  ERROR: run this in an Administrator PowerShell (right-click > Run as administrator).' 'Yellow'; return }
}
Say "  host: $env:COMPUTERNAME   PowerShell: $($PSVersionTable.PSVersion)"

# --- token: param, else secure prompt ---
if (-not $Token) {
  $sec = Read-Host '  Paste the read-only GitHub PAT' -AsSecureString
  if ($sec.Length -gt 0) {
    $bstr  = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($sec)
    try { $Token = [Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr) }
    finally { [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr) }
  }
}
if (-not $Token) { Say '  No token provided - aborting.' 'Red'; return }

# --- optional splashPath (interactive only; normally comes from the manifest) ---
if ($interactive -and -not $SplashPath) {
  $sp = Read-Host '  splash.json path (press Enter to use the fleet manifest)'
  if ($sp -and $sp.Trim()) { $SplashPath = $sp.Trim() }
}

# --- fetch the private bootstrap ---
Say "  fetching bootstrap ($ScriptsRepo@$BootstrapRef) ..."
$h  = @{ Authorization = "Bearer $Token"; 'User-Agent' = 'kiosk-enroll'; Accept = 'application/vnd.github.raw' }
$bs = Join-Path ([IO.Path]::GetTempPath()) 'lfac-bootstrap.ps1'
try {
  Invoke-WebRequest -UseBasicParsing -Headers $h "https://api.github.com/repos/$ScriptsRepo/contents/bootstrap.ps1?ref=$BootstrapRef" -OutFile $bs -TimeoutSec 60
} catch {
  Say "  ERROR: could not fetch bootstrap. Check the PAT has read-only Contents on $ScriptsRepo." 'Red'
  Say "         ($($_.Exception.Message))" 'DarkGray'
  return
}

# --- run it ---
$psExe  = if ($IsWin) { 'powershell.exe' } else { 'pwsh' }
$bsArgs = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $bs, '-Token', $Token, '-ManifestUrl', $ManifestUrl)
if ($InstallPath) { $bsArgs += @('-InstallPath', $InstallPath) }
if ($SplashPath)  { $bsArgs += @('-SplashPath',  $SplashPath) }
Say '  running bootstrap ...' 'Cyan'
& $psExe @bsArgs
$code = $LASTEXITCODE
Remove-Item $bs -Force -ErrorAction SilentlyContinue
Say ''
if ($code -eq 0 -or $null -eq $code) { Say '  enrollment finished.' 'Green' } else { Say "  bootstrap exited with code $code - see the log above." 'Yellow' }
