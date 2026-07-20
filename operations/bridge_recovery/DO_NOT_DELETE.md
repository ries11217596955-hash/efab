# DO NOT DELETE - EFAB Bridge Recovery Pack

Source of truth for restoring the GPT Action Bridge on another Windows PC.

Rules:
- Never commit tokens, passwords, ngrok config, lock files, runtime, or raw logs.
- Run scripts/install_bridge.ps1 on the new PC.
- Then run scripts/validate_bridge.ps1.
- A restore is accepted only when validator status is PASS.
- Current live Bridge remains H:\bridge until a separately authorized migration.
