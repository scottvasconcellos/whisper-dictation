-- WhisperDictation Tier 2: when the app writes ~/.whisper-trigger/paste-request,
-- send Cmd+V (paste) and delete the file. Requires Hammerspoon Accessibility.
-- Add to ~/.hammerspoon/init.lua:  require("whisper-paste-watcher")

local triggerDir = os.getenv("HOME") .. "/.whisper-trigger"
local pasteRequestPath = triggerDir .. "/paste-request"

local function doPaste()
  local f = io.open(pasteRequestPath, "r")
  if not f then return end
  f:close()
  os.remove(pasteRequestPath)
  hs.eventtap.keyStroke({ "cmd" }, "v")
end

local watcher = hs.pathwatcher.new(triggerDir, function()
  -- Any change in trigger dir (e.g. paste-request created) -> try paste
  doPaste()
end)
watcher:start()
print("[WhisperDictation] Hammerspoon paste watcher active: " .. pasteRequestPath)
