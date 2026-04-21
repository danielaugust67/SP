local env = (type(getgenv) == "function" and getgenv()) or _G
if env and env.seaRemoteCaptureRunning then
    warn("sea_remote_capture already running")
    return
end
if env then env.seaRemoteCaptureRunning = true end

repeat task.wait() until game:IsLoaded()

local function missing(t, f, fallback)
    if type(f) == t then return f end
    return fallback
end

local Support = {
    Clipboard = (typeof(setclipboard) == "function"),
    HookNamecall = (typeof(hookmetamethod) == "function" and typeof(getnamecallmethod) == "function"),
    FileIO = (typeof(writefile) == "function" and typeof(isfile) == "function"),
    AppendFile = (typeof(appendfile) == "function"),
}

local STATUS_FILE = "sea_remote_capture.status.txt"
local LOG_FILE = "sea_remote_capture.log.txt"

local function Timestamp()
    return os.date("%Y-%m-%d %H:%M:%S")
end

local function SaveStatus(text)
    if not Support.FileIO then return end
    pcall(function()
        writefile(STATUS_FILE, string.format("[%s] %s", Timestamp(), text))
    end)
end

local function Log(text)
    local line = string.format("[%s] %s", Timestamp(), text)
    warn("[SeaCapture] " .. text)

    if not Support.FileIO then return end
    pcall(function()
        if Support.AppendFile then
            if not isfile(LOG_FILE) then
                writefile(LOG_FILE, line .. "\n")
            else
                appendfile(LOG_FILE, line .. "\n")
            end
        else
            writefile(LOG_FILE, line .. "\n")
        end
    end)
end

if not Support.HookNamecall then
    SaveStatus("FAILED: hookmetamethod/getnamecallmethod not supported")
    Log("hookmetamethod/getnamecallmethod not supported by this executor")
    return
end

local function GetInstanceExpr(inst)
    if typeof(inst) ~= "Instance" then return "nil" end
    local parts = {}
    local cur = inst
    while cur and cur ~= game do
        table.insert(parts, 1, cur.Name)
        cur = cur.Parent
    end
    local expr = "game"
    for _, p in ipairs(parts) do
        expr = expr .. string.format(":WaitForChild(%q)", p)
    end
    return expr
end

local function SerializeArg(v, depth)
    depth = depth or 0
    if depth > 2 then return "nil" end

    local t = typeof(v)
    if t == "string" then
        return string.format("%q", v)
    elseif t == "number" or t == "boolean" then
        return tostring(v)
    elseif t == "nil" then
        return "nil"
    elseif t == "EnumItem" then
        return tostring(v)
    elseif t == "Instance" then
        return GetInstanceExpr(v)
    elseif t == "Vector3" then
        return string.format("Vector3.new(%s, %s, %s)", tostring(v.X), tostring(v.Y), tostring(v.Z))
    elseif t == "CFrame" then
        local c = {v:GetComponents()}
        return string.format(
            "CFrame.new(%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)",
            tostring(c[1]), tostring(c[2]), tostring(c[3]), tostring(c[4]), tostring(c[5]), tostring(c[6]),
            tostring(c[7]), tostring(c[8]), tostring(c[9]), tostring(c[10]), tostring(c[11]), tostring(c[12])
        )
    elseif t == "table" then
        local items, n = {}, 0
        for k, val in pairs(v) do
            n = n + 1
            if n > 8 then break end
            table.insert(items, string.format("[%s]=%s", SerializeArg(k, depth + 1), SerializeArg(val, depth + 1)))
        end
        return "{" .. table.concat(items, ", ") .. "}"
    end

    return "nil"
end

local function IsSeaTransitionRemote(remote, args)
    local key = ((remote.Name or "") .. " " .. remote:GetFullName()):lower()
    if key:find("teleport") or key:find("portal") or key:find("sea") or key:find("world") then
        return true
    end

    local first = args[1]
    if type(first) == "string" then
        local a = first:lower()
        if a:find("sea") or a:find("world") then
            return true
        end
    end

    return false
end

local Capture = {
    LastCall = "",
    LastTime = 0,
    Count = 0,
}

SaveStatus("RUNNING")
Log("started. Trigger sea/portal teleport to capture remote.")

task.spawn(function()
    while env and env.seaRemoteCaptureRunning do
        SaveStatus(string.format("RUNNING | captures=%d", Capture.Count))
        task.wait(15)
    end
end)

local safeNewCClosure = missing("function", newcclosure, function(f) return f end)
local oldNamecall
oldNamecall = hookmetamethod(game, "__namecall", safeNewCClosure(function(self, ...)
    local method = getnamecallmethod()
    local args = {...}

    if method and (method == "FireServer" or method == "InvokeServer")
        and typeof(self) == "Instance"
        and (self:IsA("RemoteEvent") or self:IsA("RemoteFunction"))
        and IsSeaTransitionRemote(self, args)
    then
        local serializedArgs = {}
        for i = 1, #args do
            table.insert(serializedArgs, SerializeArg(args[i]))
        end

        Capture.LastCall = string.format(
            "%s:%s(%s)",
            GetInstanceExpr(self),
            method,
            table.concat(serializedArgs, ", ")
        )
        Capture.LastTime = tick()
        Capture.Count = Capture.Count + 1

        if Support.Clipboard and setclipboard then
            pcall(setclipboard, Capture.LastCall)
        end

        SaveStatus(string.format("RUNNING | captures=%d", Capture.Count))
        Log("copied remote #" .. tostring(Capture.Count) .. ": " .. Capture.LastCall)
    end

    return oldNamecall(self, ...)
end))
