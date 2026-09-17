from pathlib import Path
import subprocess
import os
import shutil
r=Path(__file__).resolve().parent.parent
s=(r/"saveinstance.luau").read_text(encoding="utf-8")
g=s[s.index("local function GatherDecompileScripts"):s.index("local function RunDecompilePrepass")]
h=r'''
local Enum={RunContext={Server="Server",Client="Client"}}
local function node(name,class,children)
 local n={Name=name,ClassName=class or "Folder",Archivable=true,LinkedSource="",RunContext="Client",children=children or {}}
 function n:GetChildren() return self.children end
 function n:IsA(c) return c==self.ClassName or c=="LuaSourceContainer" and (self.ClassName=="ModuleScript" or self.ClassName=="Script" or self.ClassName=="LocalScript") end
 return n
end
local task={wait=function() end}
'''
t=r'''
local a,b,c=node("a","ModuleScript"),node("b","ModuleScript"),node("c","ModuleScript")
local parent=node("parent","Folder",{a,b})
local outside=node("outside","Folder",{c})
local function check(roots,ignore,di,archive,overrides,expected)
 local result=GatherDecompileScripts(roots,ignore,di,archive,overrides)
 local actual={} for _,v in result do actual[v]=true end
 assert(#result==#expected,"count mismatch")
 for _,v in expected do assert(actual[v],"missing "..v.Name) end
end
check({parent},{},{},false,{}, {a,b})
check({parent},{[a]=true},{},false,{}, {b})
check({parent},{[parent]=false},{},false,{}, {})
check({parent},{},{[parent]=true},false,{}, {})
check({parent},{},{[parent]=false},false,{}, {a,b})
check({parent,a},{},{[parent]=true},false,{}, {a})
check({parent,a},{},{},false,{}, {a,b})
a.Archivable=false check({parent},{},{},true,{}, {b}) a.Archivable=true
a.LinkedSource="asset" check({parent},{},{},false,{}, {b}) a.LinkedSource=""
check({parent},{},{},false,{[parent]={__Children={c}}}, {c})
check({parent},{},{},false,{[a]={__SaveSpecific=true}}, {b})
print("PASS: 11 prepass scope/ignore/archive/override fixtures")
'''
p=r/"tests/.generated-gather.luau";p.write_text(h+g+t)
subprocess.run([os.environ.get("LUAU", shutil.which("luau") or "luau"),str(p)],check=True)
