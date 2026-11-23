---
sidebar_position: 6
title: Run statistics and privacy
---

# Run statistics and privacy

**SaveInstance 420 Edition tracks execution data (run statistics) for robloxscripts.com.** When the script loads, it starts robloxscripts.com's [Script Ops](https://robloxscripts.com/script-ops) reporter. The maintainer uses these numbers to see how many people run SaveInstance, on which executors, and whether saves work.

## What is sent

| When | What |
|---|---|
| When SaveInstance loads | SaveInstance's version, the reporter's version, Roblox's version, your executor and its version, the game's place id, universe id and place version, the server kind, device type, OS, Roblox's language, whether your executor reads Roblox's error codes, and start-up time. |
| Every 5 minutes while the game runs | Re-runs, whether SaveInstance loaded, and counts of what you used: the save type (place, model, scripts mode), the decompiler kind (for example Oracle or native), the options switched on (streaming, nil instances, ...), whether each save worked, and how many errors happened. |
| When the session ends | Why it ended (left, kicked, disconnected, ...) and Roblox's error code. |

## What is never sent

- Your Roblox user id, name or display name. The reporter reads them only to remove them from any text before sending.
- The server's JobId, private server ids, or hardware ids.
- Anything from the place you save: no instances, scripts, names or file paths.

Error and kick text is scrubbed of names and file paths on your device and again on robloxscripts.com, and is kept only when the project collects text. For SaveInstance that setting is off, so only counts are kept.

The reporter runs on its own thread and cannot stop a save: if robloxscripts.com is down or blocked, SaveInstance works the same.

## Turn it off

Any of these stops it:

```lua
getgenv().RSOPS_OFF = true -- before loading SaveInstance
```

- Create the file `rsops/optout.txt` in your executor's workspace folder (turns it off for every script that uses Script Ops).
- `RSOps.off()` stops it for the rest of the current game session.

The reporter checks these before every message it sends.

## The code

The tracking line is the first thing in `saveinstance.luau`, right under a comment that explains it (source: `src/prelude/telemetry.luau`). The reporter it loads, `https://robloxscripts.com/ops/v1.lua`, is one plain readable file: no obfuscation, no hooks, no files written.
