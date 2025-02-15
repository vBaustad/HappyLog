-- HappyLog_Data.lua
if not HappyLog_Data then
    HappyLog_Data = {}
end

local LSM30 = LibStub("LibSharedMedia-3.0", true)

function LoadAllSounds()
    if not LSM30 then return end

    local soundTable = LSM30:HashTable("sound") -- Get all registered sounds
    HappyLog_Data.sounds = {}

    for soundName, soundPath in pairs(soundTable) do
        if soundPath and soundPath ~= "" then -- Ensure path is valid
            table.insert(HappyLog_Data.sounds, { id = soundPath, name = soundName })
        end
    end

   DebugPrint("HappyLog: Loaded " .. #HappyLog_Data.sounds .. " sounds from LibSharedMedia!") -- Debugging
end



--- Default Columns for Data Table ---
HappyLog_Data.columns = {
    { name = "Name", width = 80 },
    { name = "Guild", width = 100 },
    { name = "Class", width = 60 },
    { name = "Zone", width = 100 },
    { name = "Last Message", width = 150 },
    { name = "Date", width = 100 }
}