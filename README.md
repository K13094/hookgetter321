# OSRS Hook Discovery Service

Automated service that monitors for OSRS gamepack updates and generates fresh hooks.json using BetterDeob.

## Features

- Checks for gamepack updates at :01 and :31 of each hour
- Automatically runs BetterDeob when changes detected
- IPVanish VPN support (all traffic routed through VPN)
- All files accessible/editable from host via volume mounts
- TrueNAS Scale / Dockge ready

## Directory Structure

After deployment, these folders are accessible from your TrueNAS:
```
osrs-hook-service/
  data/           # hooks.json, gamepack.jar, SHA checksums
  output/         # BetterDeob output files
  scripts/        # Editable shell scripts
  better-deob/    # BetterDeob tool
  gluetun/        # VPN config storage
```

## Setup for TrueNAS Scale / Dockge

### 1. Copy BetterDeob

Copy the `better-deob-field-hooks 4` folder into this directory and rename it to `better-deob`:

```bash
cp -r "/path/to/better-deob-field-hooks 4" ./better-deob
```

### 2. Configure Environment

```bash
cp .env.example .env
# Edit .env with your IPVanish credentials
```

Required variables:
- `IPVANISH_USER` - Your IPVanish email
- `IPVANISH_PASS` - Your IPVanish password
- `IPVANISH_COUNTRY` - (Optional) Server country, defaults to "United States"

### 3. Deploy in Dockge

1. Create new stack in Dockge
2. Upload this folder or paste the docker-compose.yml
3. Set environment variables in Dockge UI
4. Start the stack

## Output Files

After gamepack update detection:
- `data/hooks.json` - Latest hooks for RTBot
- `data/gamepack.jar` - Current gamepack
- `data/gamepack.sha256` - SHA for change detection

## RTBot Integration

Point your HookManager to fetch from your TrueNAS share or copy hooks.json to RTBot:
```
/path/to/osrs-hook-service/data/hooks.json
```

## Logs

```bash
# In Dockge UI or via command line:
docker logs -f osrs-hook-service
docker logs -f osrs-hooks-vpn
```

## Editing Scripts

All scripts in `./scripts/` are mounted and editable. Changes take effect immediately (no rebuild needed).
