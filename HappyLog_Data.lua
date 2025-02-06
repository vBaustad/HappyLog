-- HappyLog_Data.lua
if not HappyLog_Data then
    HappyLog_Data = {}
end

local LSM30 = LibStub("LibSharedMedia-3.0", true)

if LSM30 then
    local soundList = LSM30:List("sound") -- Get all registered sounds
    HappyLog_Data.sounds = {}

    for _, soundName in ipairs(soundList) do
        local soundPath = LSM30:Fetch("sound", soundName) -- Get sound file path
        if soundPath then
            table.insert(HappyLog_Data.sounds, { id = soundPath, name = soundName })
        end
    end
end


--- Default Columns for Data Table ---
HappyLog_Data.columns = {
    { name = "Name", width = 80 },
    { name = "Guild", width = 100 },
    { name = "Class", width = 60 },
    { name = "Zone", width = 100 },
    { name = "Last Message", width = 150 },
}

-- --- Predefined Events (if needed) ---
-- -- HappyLog_Data.events = {
-- --     ["PLAYER_LEVEL_UP"] = true,
-- --     ["CHAT_MSG_SYSTEM"] = true,
-- --     ["CHAT_MSG_GUILD"] = true,
-- -- }

-- --- Default Addon Settings ---
HappyLog_Data.defaults = {
    selectedSoundID = 569772, -- Default "Level Up Ding"
    debugMode = false,
    columnOrder = { "Name", "Guild", "Class", "Zone", "Last Message" },
}
