# 2.0.0: complete rewrite

SaveInstance 420 Edition is rebuilt from scratch as small modules in `src/`, bundled into the same single `saveinstance.luau`, so the loader URL does not change.

## Fixed

- `attempt to call a nil value` at startup. 1.x downloaded `UniversalMethodFinder` from `luau/SomeHub`, which now returns 404. 2.0 downloads no code.
- Newer properties were silently dropped. The `setup.rbxcdn.com` API dump 1.x relied on is stale (684 classes against 960 in the current build), so properties such as `UIListLayout.Wraps`/`HorizontalFlex`, the `*Content` asset properties and classes like `ParticleEmitter2D` were missing from saves.
- Legacy asset properties are written as `<ContentId>` (they were written as the pre-645 `<Content><url>` form) and new `Content` properties as `<Content><uri>`.
- Part colors are rounded, not truncated, when converted to `Color3uint8` (fixes off-by-one color channels).
- `Instance.Tags` is written as a `SharedString`, its current serialized type.
- Engine-injected default player scripts (`PlayerModule`, `RbxCharacterSounds`, ...) are left out instead of saved as broken empty copies, so movement works in Studio play tests.

## Changed

- Property list: live `ReflectionService` on the client, merged with a snapshot generated from Roblox-Client-Tracker's Full API dump (`tools/gen-schema.mjs`). No runtime download.
- Base64, hashing and SharedString keys use the engine's `EncodingService` (native speed on every executor); executor encoders are a validated fallback.
- Decompiling runs as a pool (`DecompileConcurrency`, default 16) over unique bytecode, with per-script deadlines (30 s for HTTP hooks, 10 s native), one slow-script retry, and a session cache keyed by bytecode hash. Timed-out threads are abandoned, never cancelled (cancelling a native decompile crashes Volt).
- The installed `decompile()` is identified: native functions by executor name, hooks by the service address they contain (Oracle, lua.expert, Konstant, Medal), or by the 1.x `__SaveInstanceDecompiler` registration. Every answer is checked: provider error text is never saved or cached, rate limits halve the requests in flight and retry, and key or quota errors stop decompiling at once.
- Output streams to disk in 4 MB chunks; work yields every 8 ms of CPU time (`YieldBudget`).
- Extras (nil instances, isolated players, extra instances, readme) are saved under `ServerStorage.SaveInstance420`.
- The result of `saveinstance()` is a table (`ok`, `path`, `bytes`, `instances`, `scripts`, `warnings`, ...), and live progress is published in `getgenv().SaveInstance420Status`.
- Debug logs are written to `SaveInstance420/debug <time>.log`.
- **Run statistics:** SaveInstance tracks execution data for robloxscripts.com (Script Ops): versions, executor, game ids, device type, and counts of save types, decompiler kinds, options and errors, with a check-in every 5 minutes. It never sends account names or ids, and never anything from the saved place. Turn it off with `getgenv().RSOPS_OFF = true` or `rsops/optout.txt` (see `docs/privacy.md`).

## Not carried over yet

- `StreamingPreview` (the area visualizer) and `ExportObj` (mesh export to .obj).
- `StreamingRequireComplete`, `StreamingCancel`, `StreamingValidate`, `Anonymous`, and the `DecompilePrepass*` / `Prepass*` options. Decompiling is always a concurrent prepass now; use `DecompileConcurrency`, `DecompilerApiUrl` and `DecompilerApiGap` instead.

## Known limits

- Unions saved by newer Studio builds keep their geometry in `SolidMeshHolder`, which no executor can read, so those unions open as boxes. Older unions (`MeshData2`) save fully.
- Server scripts, ServerStorage and ServerScriptService never reach the client.

## Validation

Live on Volt 1.4.0.3 with the Oracle loader in autoexec, Roblox 0.748, Blox Fruits:

- Full place: 167,018 instances, 177.7 MB in 4 min 46 s. 5,005 scripts decompiled through Oracle, 907 reused, 5 failed (Oracle returned nothing), 74 server-only. No Oracle error text in any of the 11,750 saved sources.
- 43 scripts through Oracle: 1.3 s. Simulated expired key: stopped after 2 requests. Simulated rate limit: backed off 4 s, then 8 s, and finished with every script decompiled.
- The same place with `Decompile = false`: 165,184 instances, 136 MB in 23 s.
- `tools/validate.py` passed on every output: unique referents, every Ref and SharedString key resolves, no duplicate properties, valid base64.

Opening the files in Studio still needs a hands-on check.
