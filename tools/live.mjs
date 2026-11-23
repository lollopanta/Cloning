// Live development loop against a running game, through the ExecutorMCP bridge.
//
//   node tools/live.mjs check                 bundle, copy into the executor workspace, compile in-game
//   node tools/live.mjs save "{ Decompile = false }"   ...then run a save, follow its progress, validate the file
//   node tools/live.mjs eval "return game.PlaceId"     run Luau in the game and print the result
//
// Environment:
//   SSI_BRIDGE     ExecutorMCP bridge (default http://127.0.0.1:16384)
//   SSI_WORKSPACE  executor workspace folder (default: Volt's, auto-detected)
//   SSI_OPS=1      let `save` runs report run statistics to robloxscripts.com (off by default)
import { execFileSync } from "node:child_process";
import { existsSync } from "node:fs";
import { dirname, join } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const BRIDGE = process.env.SSI_BRIDGE || "http://127.0.0.1:16384";
const LOCAL = process.env.LOCALAPPDATA || "";
const WORKSPACE =
  process.env.SSI_WORKSPACE ||
  [join(LOCAL, "Volt (Staging)", "workspace"), join(LOCAL, "Volt", "workspace")].find((p) => existsSync(p));

async function luau(code, timeout = 30000) {
  const res = await fetch(`${BRIDGE}/api/tool`, {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ type: "get-data-by-code", code, timeout, sourceName: "ssi-live" }),
  });
  const body = await res.json().catch(() => ({}));
  if (!res.ok || body.error) throw new Error(body.error || `bridge returned HTTP ${res.status}`);
  return body.result;
}

function deploy() {
  if (!WORKSPACE) throw new Error("executor workspace not found; set SSI_WORKSPACE");
  execFileSync(process.execPath, [join(ROOT, "tools", "bundle.mjs"), "--deploy", WORKSPACE], { stdio: "inherit" });
}

const LOAD = 'loadstring(readfile("ssi-dev/saveinstance.luau"), "=saveinstance")';

async function check() {
  deploy();
  const out = await luau(`local f, e = ${LOAD} return f and "compiled OK" or ("COMPILE ERROR: " .. tostring(e))`);
  console.log(out);
  if (!String(out).includes("compiled OK")) process.exit(1);
}

async function save(optionsLua) {
  await check();
  const options = optionsLua || "{}";
  // Development runs stay out of the robloxscripts.com run statistics (SSI_OPS=1 includes them).
  // The reporter checks RSOPS_OFF while the bundle loads, so the user's own value comes back after.
  const opsOff = process.env.SSI_OPS === "1" ? "nil" : "true";
  await luau(`
    local previousOff = getgenv().RSOPS_OFF
    if ${opsOff} then getgenv().RSOPS_OFF = true end
    local saveinstance = ${LOAD}()
    getgenv().RSOPS_OFF = previousOff
    getgenv().SSI_LIVE_RESULT = nil
    local options = ${options}
    options.FilePath = options.FilePath or "ssi-dev/live"
    task.spawn(function()
      local ok, result = pcall(saveinstance, options)
      getgenv().SSI_LIVE_RESULT = ok and result or { ok = false, error = tostring(result) }
    end)
    return "started"`);
  for (;;) {
    await new Promise((r) => setTimeout(r, 3000));
    const status = await luau(`
      local s = getgenv().SaveInstance420Status or {}
      local r = getgenv().SSI_LIVE_RESULT
      if r then
        return string.format("DONE ok=%s path=%s instances=%s bytes=%s elapsed=%.1fs error=%s", tostring(r.ok), tostring(r.path),
          tostring(r.instances), tostring(r.bytes), r.elapsed or 0, tostring(r.error))
      end
      return string.format("%s %s/%s (%.0fs)", tostring(s.phase), tostring(s.done), tostring(s.total), s.elapsed or 0)`);
    const line = String(status).match(/"([^"]*)"/)?.[1] ?? String(status);
    console.log(line);
    if (line.startsWith("DONE")) {
      const path = line.match(/path=(\S+)/)?.[1];
      if (line.includes("ok=true") && path && path !== "nil") {
        execFileSync("python", ["-I", join(ROOT, "tools", "validate.py"), join(WORKSPACE, path)], { stdio: "inherit" });
      } else {
        process.exit(1);
      }
      return;
    }
  }
}

const [command, arg] = process.argv.slice(2);
try {
  if (command === "check") await check();
  else if (command === "save") await save(arg);
  else if (command === "eval") console.log(await luau(arg));
  else {
    console.error('usage: node tools/live.mjs check | save "<options table>" | eval "<luau>"');
    process.exit(2);
  }
} catch (error) {
  console.error(error.message);
  process.exit(1);
}
