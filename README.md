# kiosk-enroll

Public enrollment scaffold for Xzibit kiosks — the **one thing you paste** on a
fresh machine. It preflight-checks the box, takes a read-only GitHub PAT, then
fetches and runs the private `bootstrap.ps1`, which does the actual install.

**This repo is public and contains nothing sensitive** — no token, no data URLs.
The manifest URL it references is just a pointer (useless without the PAT).

## Enroll a kiosk
Open an **Administrator PowerShell** on the kiosk.

**Interactive** (recommended — secure token prompt, nothing in shell history):
```powershell
iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1.1/enroll.ps1 | iex
```

**Non-interactive** (token via env var so it stays off the command line):
```powershell
$env:GITHUB_TOKEN='github_pat_xxx'; iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1.1/enroll.ps1 | iex
```

If the machine isn't registered in the fleet manifest yet, run interactively —
it prompts for the `splash.json` path.

## What you need
- A fine-grained **read-only PAT** with **Contents: read** on `kiosk-fleet` and
  the scripts repo. (Reused across kiosks; rotate yearly.)
- The kiosk's `devices.<HOSTNAME>` block in `kiosk-fleet` (or pass `-SplashPath`).

## Notes
- The paste URL is pinned to a tag (`v1.1`) for stability. Cut a new tag if
  `enroll.ps1` changes, and update the URL here.
- Interactive mode reads the PAT with `Read-Host -AsSecureString` and passes it
  to bootstrap via `$env:GITHUB_TOKEN` — so the token never lands in PowerShell
  history nor in any process command line.
- Keep write access to this repo tight — anything merged here runs on kiosks.
