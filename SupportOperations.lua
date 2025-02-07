local maxNonces = 1000 -- Keep only the last 1000 nonces

-- Ensure global HappyLog exists
if not HappyLog then
    HappyLog = {}
end

-- Debug Print Function
function DebugPrint(...)
    if HappyLogDB and HappyLogDB.debug then
        print("|cffffd700[HappyLog Debug]:|r", ...)
    end
end

-- Function to safely check if a table is empty
function IsTableEmpty(t)
    return next(t) == nil
end

-- Function to capitalize the first letter of a string
function CapitalizeFirstLetter(str)
    if not str or str == "" then return "" end
    return str:sub(1,1):upper() .. str:sub(2):lower()
end

-- Function to safely copy a table
function SafeCopyTable(original)
    if type(original) ~= "table" then return {} end
    return CopyTable(original)
end

-- Sound notification
function PlayNotificationSound(sound)        
    PlaySoundFile(sound, "master")  
end

function CapitalizeFirstLetter(str)
    if not str or str == "" then
        return ""
    end
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

function StripRealm(name)
    return name:match("^(.-)-") or name -- Strips the realm name if present
end

function TrackPlayerMessage(event, text, playerName, ...)
    if StripRealm(playerName) == UnitName("player") then
        HappyLogDB.lastPlayerMessage = text
        DebugPrint("Updated last player message:", HappyLogDB.lastPlayerMessage)
    end
end

function JoinAddonChannel()
    local channelName = "happylogalertschannel"
    JoinChannelByName(channelName, nil, nil, false)
    DebugPrint("|cffffd700[HappyLog]:|r Joined or already in channel:", channelName)
end

function CleanOldNonces(receivedNonces)
    if #receivedNonces > maxNonces then
        local excess = #receivedNonces - maxNonces
        for i = 1, excess do
            table.remove(receivedNonces, 1) -- Remove oldest entries
        end
    end
end

function OpenSettingsPanel()   
    if Settings and Settings.OpenToCategory then        
        Settings.OpenToCategory(HappyLog_Settings.category.ID)
        Settings.OpenToCategory(HappyLog_Settings.category.ID)
    else
        print("|cffff0000[HappyLog]:|r No valid settings panel API found!")
    end
end

-- Function to print the current column order with placeholders
function PrintColumnOrder()
    for i, column in ipairs(HappyLogDB.columnOrder) do
        DebugPrint(column or "---")
    end
end   