// Bundles src/*.luau into the single-file saveinstance.luau that the loader URL serves.
//
// Each module becomes a function in a small registry; `require("name")` inside a module
// resolves to another file in src/ (no extension, forward slashes for subfolders).
//
// usage: node tools/bundle.mjs [--deploy <executor workspace dir>]
//   --deploy copies the bundle to <dir>/ssi-dev/saveinstance.luau for live testing.
import { readFileSync, writeFileSync, readdirSync, statSync, mkdirSync, copyFileSync, existsSync } from "node:fs";
import { dirname, join, relative, sep } from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = join(dirname(fileURLToPath(import.meta.url)), "..");
const SRC = join(ROOT, "src");
// Files in src/prelude/ are not modules: they are pasted verbatim at the very top of the
// bundle, before any module code runs (the run-statistics line must come first).
const PRELUDE = join(SRC, "prelude");
const OUT = join(ROOT, "saveinstance.luau");
const ENTRY = "main";

function walk(dir) {
  return readdirSync(dir).flatMap((name) => {
    const full = join(dir, name);
    if (full === PRELUDE) return [];
    return statSync(full).isDirectory() ? walk(full) : full.endsWith(".luau") ? [full] : [];
  });
}

const prelude = existsSync(PRELUDE)
  ? readdirSync(PRELUDE).filter((n) => n.endsWith(".luau")).sort().map((n) => readFileSync(join(PRELUDE, n), "utf8").replace(/\s+$/, ""))
  : [];
const tracked = prelude.length > 0;
if (tracked && !prelude.some((source) => /^local ops = /m.test(source))) {
  throw new Error("src/prelude must define `local ops = ...` (the Script Ops handle passed to main)");
}

const version = JSON.parse(readFileSync(join(ROOT, "version.json"), "utf8")).version;
const modules = walk(SRC)
  .map((file) => ({ name: relative(SRC, file).split(sep).join("/").replace(/\.luau$/, ""), source: readFileSync(file, "utf8") }))
  .sort((a, b) => a.name.localeCompare(b.name));

const names = new Set(modules.map((m) => m.name));
for (const m of modules) {
  for (const [, dep] of m.source.matchAll(/\brequire\(\s*"([^"]+)"\s*\)/g)) {
    if (!names.has(dep)) throw new Error(`${m.name}.luau requires unknown module "${dep}"`);
  }
  if (/^\s*--!/m.test(m.source.split("\n").slice(0, 3).join("\n"))) {
    // Directives only work at the top of the bundle; keep module files free of them.
    throw new Error(`${m.name}.luau starts with a --! directive; put directives in tools/bundle.mjs instead`);
  }
}
if (!names.has(ENTRY)) throw new Error(`missing entry module src/${ENTRY}.luau`);

const parts = [
  "--!optimize 2",
  `-- SaveInstance 420 Edition ${version}`,
  "-- https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition",
  "-- Built from src/ by tools/bundle.mjs. Edit the modules in src/, not this file.",
  ...(tracked
    ? [
        "--",
        "-- NOTICE: this script tracks execution data (run statistics) for robloxscripts.com.",
        "-- The RUN STATISTICS block below says what is sent and how to turn it off.",
      ]
    : []),
  "",
  "local __SSI_VERSION = " + JSON.stringify(version),
  ...prelude.flatMap((source) => [source, ""]),
  "local __modules, __loaded = {}, {}",
  "local function require(name)",
  "\tlocal cached = __loaded[name]",
  "\tif cached ~= nil then return cached end",
  "\tlocal loader = __modules[name]",
  "\tif not loader then error(\"SaveInstance: missing module \" .. tostring(name), 2) end",
  "\tlocal result = loader()",
  "\tif result == nil then result = true end",
  "\t__loaded[name] = result",
  "\treturn result",
  "end",
  "",
];
for (const m of modules) {
  parts.push(`__modules[${JSON.stringify(m.name)}] = function()`);
  parts.push(m.source.replace(/\s+$/, ""));
  parts.push("end", "");
}
// A failed load is reported (when tracking is on) and then raised to the loader as before.
parts.push(
  "local __ok, __saveinstance = pcall(function()",
  `\treturn require(${JSON.stringify(ENTRY)})(__SSI_VERSION, ${tracked ? "ops" : "nil"})`,
  "end)",
  "if not __ok then",
  ...(tracked ? ["\tpcall(function()", '\t\tops.ready(false, "load_error")', '\t\tops.error(__saveinstance, "load")', "\tend)"] : []),
  "\terror(__saveinstance, 0)",
  "end",
  "return __saveinstance",
  ""
);

const bundle = parts.join("\n");
writeFileSync(OUT, bundle);
console.log(`wrote ${OUT}: ${modules.length} modules, ${bundle.length} bytes (${version})`);

const deployIdx = process.argv.indexOf("--deploy");
if (deployIdx !== -1) {
  const target = join(process.argv[deployIdx + 1], "ssi-dev");
  mkdirSync(target, { recursive: true });
  copyFileSync(OUT, join(target, "saveinstance.luau"));
  console.log(`deployed to ${join(target, "saveinstance.luau")}`);
}
