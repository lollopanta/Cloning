import React from 'react';
import Layout from '@theme/Layout';
import Link from '@docusaurus/Link';
import CodeBlock from '@theme/CodeBlock';

const example = `-- SaveInstance 420 Edition: change the values below, then run this in your executor while in a game.
-- Every option: https://pages.sirmemegithub.com/SaveInstance420Edition/docs/options/

-- getgenv().RSOPS_OFF = true -- remove the "--" at the start to turn off run statistics for robloxscripts.com

local saveinstance = loadstring(game:HttpGet(
    "https://sirmemegithub.com/RealSlimShady2000/SaveInstance420Edition/raw/branch/main/saveinstance.luau"
))()

saveinstance({
    -- What to save
    Mode = "optimized",             -- "full": every service | "scripts": only what holds scripts
    NilInstances = false,           -- true: also save instances parented to nil
    RemovePlayerCharacters = true,  -- false: keep player characters in Workspace
    IsolateLocalPlayer = false,     -- true: also save your PlayerGui, Backpack, ...

    -- Scripts
    Decompile = true,               -- false: skip decompiling (much faster, map only)

    -- StreamingEnabled games
    SetStreaming = false,           -- true: load the rest of the map before saving
    StreamingAreaSize = 10000,      -- size of the area to load around you, in studs

    -- Output
    FilePath = false,               -- "My save": fixed file name (no extension)
    ShowStatus = true,              -- false: hide the progress panel
    NeutralizeLighting = false,     -- true: reset dark or foggy lighting before saving
    SafeMode = false,               -- true: disconnect from the server before writing the file
    Debug = false,                  -- true: write a log to SaveInstance420/ in your workspace
})`;
const routes = [
 ['01', 'Make your first save', 'Run the loader, find the file, and open it in Studio.', '/docs/intro'],
 ['02', 'Fill in streamed regions', 'Choose a request area and check for missing geometry.', '/docs/streaming'],
 ['03', 'Decompile scripts', 'See which decompiler runs, how fast, and what can be recovered.', '/docs/decompilation'],
 ['04', 'Track down a bad export', 'Start with the symptom, then make one change at a time.', '/docs/troubleshooting'],
];
export default function Home() {
 return <Layout title="SaveInstance 420 Edition" description="Practical documentation for SaveInstance 420 Edition. Save places, load streamed regions, and choose a decompiler.">
  <main className="ssi-home">
   <section className="ssi-lead">
    <div className="ssi-intro">
     <p className="ssi-eyebrow">SIRMEME / ROBLOX TOOLS</p>
     <h1>Save the map.<br/><span>Bring the scripts.</span></h1>
     <p className="ssi-deck">SaveInstance 420 Edition exports the place your client can see: map, UI, terrain and decompiled scripts. Version 2 is rewritten from scratch and saves big games in minutes.</p>
     <div className="ssi-actions"><Link className="button button--primary" to="/docs/intro">Make your first save <span aria-hidden="true">↗</span></Link><Link className="ssi-text-link" to="/docs/options">Browse options</Link></div>
     <p className="ssi-credit">Inspired by UniversalSynSaveInstance. Maintained by SirMeme.</p>
    </div>
    <div className="ssi-example"><div className="ssi-example-head"><span>START WITH THIS</span><span>Luau / place export</span></div><CodeBlock language="lua">{example}</CodeBlock><p>Copy the whole script and run it in your executor. Wait for Saved!, then open the .rbxlx file from your executor workspace in Roblox Studio.</p><p>SaveInstance tracks execution data (run statistics) for robloxscripts.com. <Link to="/docs/privacy">What is sent and how to turn it off</Link>.</p></div>
   </section>
   <div className="ssi-defaults" aria-label="Default behavior"><span><b>Scripts</b> On</span><span><b>Decompiles in parallel</b> 16</span><span><b>Streaming sweep</b> Off</span><span><b>SafeMode</b> Off</span></div>
   <section className="ssi-guide"><div><p className="ssi-eyebrow">THE GUIDE</p><h2>What are you <br/>working on?</h2><p>No need to learn every option.<br/>Start with the task in front of you.</p></div><div className="ssi-routes">{routes.map(([n,title,body,to])=><Link key={n} to={to} className="ssi-route"><span className="ssi-route-number">{n}</span><span><h3>{title}</h3><p>{body}</p></span><span aria-hidden="true">↗</span></Link>)}</div></section>
   <aside className="ssi-note"><b>A finished export is not a complete-map guarantee.</b><p>Unloaded regions, server-only scripts, and restricted assets may be absent. Check the result in Studio before relying on it.</p><Link to="/docs/troubleshooting">Know what to check →</Link></aside>
  </main>
 </Layout>;
}
