# kiosk-enroll

Public enrollment scaffold for Xzibit kiosks — the **one thing you paste** on a
fresh machine. It preflight-checks the box, takes a read-only GitHub PAT, then
fetches and runs the private `bootstrap.ps1`, which does the actual install.

**This repo is public and contains nothing sensitive** — no token, no data URLs.
The manifest URL it references is just a pointer (useless without the PAT).

## Enroll a kiosk
Open an **Administrator PowerShell** on the kiosk.

**Interactive** (prompts, secure token entry):
```powershell
iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1/enroll.ps1 | iex
```

**Non-interactive** (everything on the line):
```powershell
& ([scriptblock]::Create((iwr -useb https://raw.githubusercontent.com/xzibit-pty-ltd/kiosk-enroll/v1/enroll.ps1).Content)) -Token 'github_pat_xxx'
```

Add `-SplashPath 'C:\...\splash.json'` if the machine isn't registered in the
fleet manifest yet.

## What you need
- A fine-grained **read-only PAT** with **Contents: read** on `kiosk-fleet` and
  the scripts repo. (Reused across kiosks; rotate yearly.)
- The kiosk's `devices.<HOSTNAME>` block in `kiosk-fleet` (or pass `-SplashPath`).

## Notes
- The paste URL is pinned to the `v1` tag for stability. Cut a new tag if
  `enroll.ps1` changes.
- Interactive mode reads the PAT with `Read-Host -AsSecureString`, so it never
  lands in PowerShell history.
- Keep write access to this repo tight — anything merged here runs on kiosks.
