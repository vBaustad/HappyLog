local AceComm = LibStub("AceComm-3.0")
local addonName = "HappyLog"

-- Ensure the global namespace exists
if not HappyLog then
    HappyLog = {}
end
-- Ensure the saved variable table exists
if not HappyLogDB then
    HappyLogDB = {}
end

-- Ensure all sub-tables exist to prevent nil errors
HappyLogDB.data = HappyLogDB.data or {}
HappyLogDB.confirmedSixties = HappyLogDB.confirmedSixties or {}
HappyLogDB.lastPlayerMessage = HappyLogDB.lastPlayerMessage or ""
HappyLogDB.columns = HappyLogDB.columns or {}
HappyLogDB.columnOrder = HappyLogDB.columnOrder or {}
HappyLogDB.Minimized = HappyLogDB.Minimized or false
HappyLogDB.minimap = HappyLogDB.minimap or {}
HappyLogDB.selectedSoundID = HappyLogDB.selectedSoundID
HappyLogDB.colors = HappyLogDB.colors or true
HappyLogDB.debug = HappyLogDB.debug or false
HappyLog_Settings = {}
C_ChatInfo.RegisterAddonMessagePrefix("HappyLog")
HappyLog.updateUI = HappyLog.updateUI or function() end

local addonChannelName = "happylogalertschannel"
local receivedNonces = {}
local secretKey = "HappyLogSecretKey489!"

local function generateHash(message)
    local hash = 0
    for i = 1, #message do
        local byte = string.byte(message, i)
        hash = (hash + byte * i) % 100000 
    end
    return tostring(hash)
end

local function JoinAddonChannel()
    local channelIndex = GetChannelName(addonChannelName)
    if channelIndex == 0 then
        JoinChannelByName(addonChannelName, nil, DEFAULT_CHAT_FRAME:GetID(), false)
        DebugPrint("|cffffd700[HappyLog]:|r Joined custom addon channel:", addonChannelName)
    else
        DebugPrint("|cffffd700[HappyLog]:|r Already in channel:", addonChannelName)
    end
end


local function sendAddonMessage(serialized)
    local channelIndex = GetChannelName(addonChannelName)

    if channelIndex and channelIndex > 0 then        
        local hash = generateHash(serialized .. secretKey)
        local safeMessage = "HappyLog:" .. hash .. ":" .. serialized
        SendChatMessage(safeMessage, "CHANNEL", nil, channelIndex)
    else
        DebugPrint("|cffff0000[HappyLog]:|r Channel not found. Make sure you're connected.")
    end
end

local function onChatMsgSystem(event, message)
    if not message then
        DebugPrint("Error: Received system message is nil.")
        return
    end
    
    local name = message:match("^(%S+) has reached level 60!")
    if name then

        -- Ensure the confirmedSixties table exists before accessing it
        HappyLogDB.confirmedSixties = HappyLogDB.confirmedSixties or {}

        -- Check if the name is already in the table to prevent duplicates
        for _, existingName in ipairs(HappyLogDB.confirmedSixties) do
            if existingName == name then
                return -- Name already exists; do nothing
            end
        end
        -- Add the name to the array
        table.insert(HappyLogDB.confirmedSixties, name)
    end
end

local function handleAddonMessage(event, text, sender, ...) 
    -- Extract player data
    local name, guild, level, race, class, zone, lastMessage = strsplit(";", text)
    C_Timer.After(5, function()
        -- Add to data if confirmed
        local existsInConfirmedSixties = false
        for _, confirmedName in ipairs(HappyLogDB.confirmedSixties or {}) do
            if confirmedName == name or HappyLogDB.debug == true then
                existsInConfirmedSixties = true
                break
            end
        end

        if existsInConfirmedSixties then
            table.insert(HappyLogDB.data, {
                name = CapitalizeFirstLetter(name),
                guild = guild and CapitalizeFirstLetter(guild) or "No Guild",
                class = CapitalizeFirstLetter(class),
                zone = CapitalizeFirstLetter(zone),
                message = lastMessage or "",
                date = date("%b %d, %Y")
            })

            -- Update UI
            if HappyLog.updateUI then
                HappyLog.updateUI()
                DebugPrint("|cffffd700[HappyLog]:|r Updated UI with new player data.")
            end

            -- Play notification sound
            PlayNotificationSound(HappyLogDB.selectedSoundID)
        else
            DebugPrint("|cffff0000[HappyLog]:|r Character does not exist in confirmedSixties. Ignoring message.")
        end
    end)
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        DebugPrint("Player leveled up to:", level)
    
        if HappyLogDB.debug == true then
            level = 60
        end
    
        -- Check if the player reached level 60
        if level == 60 then
           DebugPrint("|cffffd700[HappyLog]:|r Congratulations on reaching level 60!")  
            C_Timer.After(5, function() end)

            -- Gather player information
            local name = UnitName("player") -- Player's name
            local guildName = GetGuildInfo("player") or "" -- Player's guild name
            local _, race = UnitRace("player") -- Player's race
            local _, class = UnitClass("player") -- Player's class
            local zone = GetZoneText() -- Current zone name
            local message = HappyLogDB.lastPlayerMessage or "" -- Custom last message
            
            local timestamp = time() -- Current Unix timestamp
            local nonce = tostring(math.random(10000, 99999)) -- Unique random number

            -- Serialize the data
            local serialized = string.format("%s;%s;%d;%s;%s;%s;%s;%s;%s",
                name,
                guildName,
                level,
                race,
                class,
                zone,
                message,
                timestamp,
                nonce
            )
            sendAddonMessage(serialized)         

        end
    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        onChatMsgSystem(event, message)
    elseif event == "CHAT_MSG_CHANNEL" then
        local text, sender, _, _, _, _, _, channelIndex, channelName = ...

        -- Ensure message comes from the correct channel
        if channelName and channelName:lower() == addonChannelName then
            DebugPrint("|cffffd700[HappyLog]:|r Received message in correct channel:", text)
    
            -- Extract Hash & Message
            local prefix, receivedHash, parsedText = text:match("^(HappyLog):(%d+):(.*)$")
            if not prefix or not receivedHash or not parsedText then
                DebugPrint("|cffffa500[HappyLog]:|r Ignoring manually typed message (incorrect format):", text)
                return
            end
    
            -- Extract player data and nonce
            local name, guild, level, race, class, zone, lastMessage, timestamp, nonce = strsplit(";", parsedText)
    
            -- Ensure timestamp is valid and not too old
            local currentTime = time()
            if not timestamp or tonumber(timestamp) < currentTime - 30 then
                DebugPrint("|cffff0000[HappyLog]:|r Message expired or invalid timestamp. Ignoring.")
                return
            end
    
            timestamp = tonumber(timestamp) -- Convert to number

            -- Allow messages up to 2 minutes old
            if timestamp < currentTime - 120 then
                DebugPrint("|cffff0000[HappyLog]:|r Message expired (older than 2 minutes). Ignoring.")
                return
            end

            -- Prevent Replay Attacks - Check Nonce
            if receivedNonces[nonce] then
                DebugPrint("|cffff0000[HappyLog]:|r Duplicate message detected! Ignoring replayed message.")
                return
            end
    
            -- Store the nonce to prevent replay attacks
            receivedNonces[nonce] = true
    
            -- Store the nonce to prevent replay attacks
            table.insert(receivedNonces, nonce)
            CleanOldNonces(receivedNonces)

            -- Recalculate the Hash using the same nonce & timestamp
            local expectedHash = generateHash(parsedText .. secretKey)
    
            -- Compare Hashes
            if receivedHash ~= expectedHash then
                DebugPrint("|cffff0000[HappyLog]:|r Invalid hash! Message ignored.")
                return
            end
    
            -- Hash is valid, process message
            DebugPrint("|cffffd700[HappyLog]:|r Valid addon message received from", sender, ":", parsedText)
    
            -- Process Addon Message Securely (Message is Now Verified)
            handleAddonMessage(event, parsedText, sender, ...)
        end
    elseif event:match("^CHAT_MSG") then
        -- Track the player's last chat message
        TrackPlayerMessage(event, ...)
    elseif event == "PLAYER_LOGIN" then
        JoinAddonChannel()
        LoadAllSounds()
    elseif event == "ADDON_LOADED" then
        -- Call the function to create and display the minimap button
        if CreateMinimapButton then
            CreateMinimapButton()
        end
    end
end)

-- Register events
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_LEVEL_UP")
frame:RegisterEvent("CHAT_MSG_SYSTEM")
frame:RegisterEvent("CHAT_MSG_CHANNEL")
frame:RegisterEvent("CHAT_MSG_SAY")
frame:RegisterEvent("CHAT_MSG_YELL")
frame:RegisterEvent("CHAT_MSG_PARTY")
frame:RegisterEvent("CHAT_MSG_PARTY_LEADER")
frame:RegisterEvent("CHAT_MSG_RAID")
frame:RegisterEvent("CHAT_MSG_RAID_LEADER")
frame:RegisterEvent("CHAT_MSG_WHISPER")
frame:RegisterEvent("CHAT_MSG_GUILD")
frame:RegisterEvent("ADDON_LOADED")

-- Slash command for testing
SLASH_HAPPYLOGSETTINGS1 = "/happylog"
SLASH_HAPPYLOGSETTINGS2 = "/hl"
SLASH_HAPPYLOGDEBUG1 = "/hldebug"
SLASH_HAPPYLOGCLEARALL1 = "/hlclearall"
SLASH_HAPPYLOGCLEARLAST1 = "/hlclearlast"
SLASH_CONFIRMEDSIXTIES1 = "/sixties"
SLASH_HAPPYLOG1 = "/hltest"


SlashCmdList["HAPPYLOG"] = function()
    if HappyLogDB.debug then
        DebugPrint("In /hltest command. HappyLog:", HappyLog, "HappyLog.updateUI:", HappyLog.updateUI)

        if not HappyLog.updateUI then
            DebugPrint("Error: HappyLog.updateUI is nil before calling handleAddonMessage.")
            return
        end

        local timestamp = time() -- Current Unix timestamp
        local nonce = tostring(math.random(10000, 99999)) -- Unique random number

        local testData = {
            name = "Sinfulsally",
            guild = "TestGuild",
            level = 60,
            race = "Orc",
            class = "Warrior",
            zone = "Orgrimmar",
            message = "This is a test message!",
        }
        local serialized = string.format("%s;%s;%d;%s;%s;%s;%s;%s;%s",
            testData.name,
            testData.guild,
            testData.level,
            testData.race,
            testData.class,
            testData.zone,
            testData.message,
            timestamp,
            nonce
        )
        handleAddonMessage("HappyLog", serialized, nil, "Tester")
    end
end

SlashCmdList["CONFIRMEDSIXTIES"] = function()
    if HappyLogDB.debug then
        DebugPrint("Confirmed Sixties:")
        for _, name in ipairs(HappyLogDB.confirmedSixties) do
            DebugPrint("-", name)
        end
    end
end

SlashCmdList["HAPPYLOGSETTINGS"] = function(msg)
    local category = Settings.GetCategory("HappyLog")
    if category then
        Settings.OpenToCategory(category)
    else
        DebugPrint("HappyLog: Unable to open settings. The category might not be registered yet.")
    end
end

SlashCmdList["HAPPYLOGCLEARALL"] = function()
    if HappyLogDB.debug then
        -- Clear the HappyLogDB.data table
        if HappyLogDB and HappyLogDB.data then
            wipe(HappyLogDB.data) -- Efficiently clears the table
            DebugPrint("|cffffd700[HappyLog]:|r Data table has been cleared.")
        else
            DebugPrint("|cffffd700[HappyLog]:|r No data to clear.")
        end

        -- Update the UI
        if HappyLog.updateUI then
            HappyLog.updateUI()
        end
    end
end

SlashCmdList["HAPPYLOGCLEARLAST"] = function()
    if HappyLogDB.debug then
        -- Clear the HappyLogDB.data table
        if HappyLogDB and HappyLogDB.data and #HappyLogDB.data > 0 then
            local removedEntry = table.remove(HappyLogDB.data) -- Removes the last entry
            DebugPrint("|cffffd700[HappyLog]:|r Last entry removed: " .. tostring(removedEntry))
        else
            DebugPrint("|cffffd700[HappyLog]:|r No data to remove.")
        end
        -- Update the UI
        if HappyLog.updateUI then
            HappyLog.updateUI()
        end
    end
end

SlashCmdList["HAPPYLOGDEBUG"] = function(msg)
    if not HappyLogDB then
       DebugPrint("|cffff0000[HappyLog]:|r Error - HappyLogDB is not initialized.")
        return
    end
    -- Toggle debug mode
    if HappyLogDB.debug then
        HappyLogDB.debug = false
       DebugPrint("|cffffd700[HappyLog]:|r Debug mode |cffff0000DISABLED|r.")
    else
        HappyLogDB.debug = true
       DebugPrint("|cffffd700[HappyLog]:|r Debug mode |cff00ff00ENABLED|r.")
    end

    -- Optional:DebugPrint the current state of HappyLogDB.debug
   DebugPrint("|cffffd700[HappyLog]:|r Current debug state:", HappyLogDB.debug and "ENABLED" or "DISABLED")
end
