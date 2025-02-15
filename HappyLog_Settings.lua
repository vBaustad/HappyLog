local AceGUI = LibStub("AceGUI-3.0")
local AceConfig = LibStub("AceConfig-3.0")
local AceConfigDialog = LibStub("AceConfigDialog-3.0")
local AceConfigRegistry = LibStub("AceConfigRegistry-3.0")

HappyLog = HappyLog or {} 

HappyLog.options = {
    name = "HappyLog",
    handler = HappyLog,
    type = 'group',
    args = {
        generalHeader = {
            type = "header",
            name = "|cFF00FF00HappyLog Settings",
            order = 1,
        },
        columnOrder = {
            type = "group",
            name = "Column Configuration",
            order = 2,
            inline = true,
            args = {}
        },
        soundSettings = {
            type = "group",
            name = "Sound Settings",
            order = 3,
            inline = true,
            args = {
                selectedSound = {
                    type = "select",
                    name = "Notification Sound",
                    desc = "Select the sound for notifications.",
                    values = function()
                        local soundList = {}
                    
                        if not HappyLog_Data or not HappyLog_Data.sounds then
                           DebugPrint("|cFFFF0000[HappyLog] ERROR: HappyLog_Data.sounds is NIL! Initializing empty table.|r")
                            HappyLog_Data.sounds = {}
                        end
                    
                        if #HappyLog_Data.sounds == 0 then
                           DebugPrint("|cFFFF0000[HappyLog] ERROR: No sounds available in HappyLog_Data.sounds!|r")
                            soundList["none"] = "No Sounds Available"
                        else
                            for _, sound in ipairs(HappyLog_Data.sounds) do
                                soundList[sound.id] = sound.name
                            end
                        end
                    
                        return soundList
                    end
                    ,
                    get = function()
                        if HappyLogDB.selectedSoundID then
                            return HappyLogDB.selectedSoundID
                        end
                    
                        -- Set default sound by name
                        local defaultSoundName = "Tada Fanfare" -- Change this to your preferred sound name
                    
                        if HappyLog_Data.sounds and #HappyLog_Data.sounds > 0 then
                            for _, sound in ipairs(HappyLog_Data.sounds) do
                                if sound.name == defaultSoundName then
                                    return sound.id
                                end
                            end
                        end
                    
                        return "none" -- Fallback if the sound isn't found
                    end,
                    set = function(_, value)
                        HappyLogDB.selectedSoundID = value
                        PlayNotificationSound(value)
                    end,
                    order = 1,
                }
            }
        },
        rowSettings = {
            type = "group",
            name = "Row Settings",
            order = 4,
            inline = true,
            args = {
                enableColors = {
                    type = "toggle",
                    name = "Enable Colored Rows",
                    desc = "Toggle colors for guild and player rows in the table.",
                    get = function()
                        return HappyLogDB.colors
                    end,
                    set = function(_, value)
                        HappyLogDB.colors = value
                       DebugPrint("|cFFFFA500[HappyLog] Row colors are now " .. (value and "ENABLED" or "DISABLED") .. "!|r")
                        HappyLog.updateUI() -- Refresh the UI
                    end,
                    order = 1,
                }
            }
        },

    }
}

local function updateColumnsOrder()
    local reorderedColumns = {}

    -- Create a map for quick lookup
    local columnMap = {}
    for _, col in ipairs(HappyLogDB.columns) do
        columnMap[col.name] = col
    end

    -- Rebuild columns based on columnOrder
    for _, columnName in ipairs(HappyLogDB.columnOrder) do
        if columnName and columnName ~= "Nothing" then
            table.insert(reorderedColumns, columnMap[columnName])
        else
            table.insert(reorderedColumns, nil)
        end
    end

    -- Update HappyLog.columns
    HappyLog.columns = reorderedColumns
end

function HappyLog_Settings.Initialize()
    HappyLogDB = HappyLogDB or {}

    -- Debugging output
   DebugPrint("|cFFFFA500[HappyLog] Initializing HappyLogDB...|r")
    if not HappyLogDB.columnOrder then
       DebugPrint("|cFFFF0000[HappyLog] columnOrder is NIL at start of Initialize!|r")
    else
       DebugPrint("|cFF00FF00[HappyLog] columnOrder exists with " .. #HappyLogDB.columnOrder .. " entries.|r")
    end

    -- Ensure `columnOrder` exists
    HappyLogDB.columnOrder = HappyLogDB.columnOrder or {}

    -- Ensure `columns` exists
    HappyLogDB.columns = HappyLogDB.columns or CopyTable(HappyLog_Data.columns)

    if #HappyLogDB.columnOrder == 0 then
       DebugPrint("|cFFFF0000[HappyLog] columnOrder is EMPTY. Populating defaults...|r")
        for i, col in ipairs(HappyLog_Data.columns) do
            HappyLogDB.columnOrder[i] = col.name
        end
    end

    HappyLog.columns = CopyTable(HappyLogDB.columns)
    updateColumnsOrder()
end

-- Function to reorder and normalize the column order
local function reorderAndNormalizeColumnOrder()
    local filled = {}
    local emptyCount = 0

    -- Collect filled columns and count empty slots
    for _, column in ipairs(HappyLogDB.columnOrder) do
        if column then
            table.insert(filled, column)
        else
            emptyCount = emptyCount + 1
        end
    end

    -- Reset columnOrder with filled columns first, followed by empty slots
    HappyLogDB.columnOrder = filled
    for i = 1, emptyCount do
        table.insert(HappyLogDB.columnOrder, nil)
    end    
    updateColumnsOrder()
end


local function refreshColumnDropdowns()
    
    HappyLog.options.args.columnOrder.args = {} 

    for i = 1, #HappyLog_Data.columns do
        HappyLog.options.args.columnOrder.args["column" .. i] = {
            type = "select",
            name = "Column " .. i,
            desc = "Select which column to show in position " .. i,
            values = function()
                local columnList = { ["-----"] = "-----" }
                for _, col in ipairs(HappyLog_Data.columns) do
                    columnList[col.name] = col.name
                end
            
                return columnList
            end,
            get = function()
                return HappyLogDB.columnOrder[i] or "-----"
            end,
            set = function(_, value)
               DebugPrint("|cFFFFA500[HappyLog] Column " .. i .. " changed to: " .. value .. "|r")
            
                -- Ensure no duplicate column selections
                for j, selected in ipairs(HappyLogDB.columnOrder) do
                    if j ~= i and selected == value then
                        HappyLogDB.columnOrder[j] = "-----"
                    end
                end
            
                HappyLogDB.columnOrder[i] = value
                reorderAndNormalizeColumnOrder()

                LibStub("AceConfigRegistry-3.0"):NotifyChange("HappyLog")
                if HappyLog.updateUI then
                   DebugPrint("|cFF00FF00[HappyLog] Calling updateUI() after column change...|r")
                    HappyLog.updateUI()
                else
                   DebugPrint("|cFFFF0000[HappyLog] ERROR: updateUI() is missing!|r")
                end
            end,
            order = i,
        }
    end    
   DebugPrint("|cFF00FF00[HappyLog] columnOrder dropdowns refreshed!|r")
end


-- Register the options table with AceConfig
AceConfig:RegisterOptionsTable("HappyLog", HappyLog.options)
AceConfigDialog:AddToBlizOptions("HappyLog", "HappyLog")

-- Initialize HappyLog settings
HappyLog_Settings.Initialize()
refreshColumnDropdowns() -- Ensure dropdowns are populated

