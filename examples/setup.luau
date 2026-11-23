-- SaveInstance 420 Edition: change the values below, then run this in your executor while in a game.
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
})
