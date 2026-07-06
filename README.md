# kiosk-enroll

Public enrollment scaffold for Xzibit kiosks — the **one thing you paste** on a
fresh machine. It preflight-checks the box, takes a read-only GitHub PAT, then
installs the **kiosk deploy agent** (`kiosk-agent`), which manages every
component (stats, app, scripts) per the fleet manifest.

**This repo is public and contains nothing sensitive** — no token, no data URLs.

## Enrol a kiosk
1. Register the kiosk's hostname in the fleet manifest first
   (`devices.<HOSTNAME>.components` in `kiosk-fleet`).
2. Open an **Administrator PowerShell** on the kiosk and paste:

**Interactive** (recommended — secure token prompt, nothing in shell history):
```powershell
iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v2/enroll.ps1 | iex
```

**Non-interactive** (token via env var so it stays off the command line):
```powershell
$env:GITHUB_TOKEN='github_pat_xxx'; iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v2/enroll.ps1 | iex
```

## What you need
- A fine-grained **read-only PAT** with **Contents:read** on `kiosk-fleet`,
  `kiosk-agent`, and every component repo (e.g. `lfac-av-stats-sync`).
  (Reused across kiosks; rotate yearly.)
- The kiosk registered in the fleet manifest.

## What it does
Installs the agent into the admin-only code root (`C:\ProgramData\Xzibit\Kiosk`),
writes its config (the PAT, SYSTEM/Admins-only), locks the root down, and
registers the daily **SYSTEM** reconcile task. From then on the agent keeps the
machine matching the manifest — deploying/updating components, writing their
config, and managing their scheduled tasks.

## Notes
- The paste URL is pinned to a tag (`v2`) for stability. Cut a new tag if
  `enroll.ps1` changes, and update the URL here.
- Interactive mode reads the PAT with `Read-Host -AsSecureString` and passes it
  to the installer via `$env:GITHUB_TOKEN` — never in history or a command line.
- Keep write access to this repo tight — anything merged here runs on kiosks.
