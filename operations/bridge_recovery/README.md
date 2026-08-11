# Bridge channels backup

This directory intentionally contains one current backup of the local Bridge/channel stack.

Archive: `BRIDGE_CHANNELS_BACKUP_CURRENT.zip`
Created: 2026-08-11
SHA256: `EDA9955632115821B5AFBE0A587140AC4B11C59848F7C554076462B7DA36112F`
Size: 236881 bytes

Included configuration/code sources:
- `H:\bridge`
- `C:\ProgramData\EFAB-Primary`
- `C:\ProgramData\EFAB-Rescue`
- `C:\ProgramData\EFAB-PC-Control`
- `C:\ProgramData\EFAB-Ngrok`
- `C:\ProgramData\EFAB-Bridge-Monitor`
- 10 current channel-related Windows Scheduled Task definitions

The archive preserves source-path structure so the local channel stack can be reconstructed after loss of the PC.

Excluded intentionally: credentials/tokens/secrets, `.env`, logs/jsonl, runs/reports/proofs, runtime/state, backups/bak files and temporary/test output. Credentials must be provisioned separately during recovery.

Do not add older generations beside this file. Refresh by replacing `BRIDGE_CHANNELS_BACKUP_CURRENT.zip` and updating this README/hash.