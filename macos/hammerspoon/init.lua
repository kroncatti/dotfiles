hs.autoLaunch(true)  -- start Hammerspoon at login, so the watchers below are always running

-- Yodoit portable monitor: force brightness on connect and after wake.
-- m1ddc and macOS (hs.screen:getUUID / displayplacer) report the same UUID for this display.
local YODOIT_UUID = "E82D04AC-20BD-424F-964D-25B456B35428"
local M1DDC       = "/opt/homebrew/bin/m1ddc"   -- absolute path: Hammerspoon doesn't load your shell PATH
local BRIGHTNESS  = 100
local DDC_DELAY   = 2                           -- seconds; monitors often ignore DDC right after connecting

local function yodoitConnected()
  for _, s in ipairs(hs.screen.allScreens()) do
    if s:getUUID() == YODOIT_UUID then return true end
  end
  return false
end

local function applyBrightness()
  hs.task.new(M1DDC, function(code, _, err)
    if code ~= 0 then hs.printf("m1ddc failed (%d): %s", code, err) end
  end, { "display", YODOIT_UUID, "set", "luminance", tostring(BRIGHTNESS) }):start()
end

local function applyBrightnessLater()
  hs.timer.doAfter(DDC_DELAY, applyBrightness)
end

local wasConnected = yodoitConnected()

-- Globals on purpose: local watchers get garbage-collected and silently stop firing
yodoitWatcher = hs.screen.watcher.new(function()
  local now = yodoitConnected()
  if now and not wasConnected then applyBrightnessLater() end
  wasConnected = now
end):start()

yodoitWakeWatcher = hs.caffeinate.watcher.new(function(event)
  if event == hs.caffeinate.watcher.systemDidWake and yodoitConnected() then
    applyBrightnessLater()
  end
end):start()

if wasConnected then applyBrightness() end
