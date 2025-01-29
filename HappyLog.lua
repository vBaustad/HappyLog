if not HappyLogDB then
    HappyLogDB = {}
end
if not HappyLog then
    HappyLog = {}
end

-- Debug helper
local function debugPrint(...)
    if HappyLogDB and HappyLogDB.debug then
        print("|cffffd700[HappyLog Debug]:|r", ...)
    end
end

-- Initialize HappyLogDB.data as an empty table if it doesn't exist
HappyLogDB.data = HappyLogDB.data or {}
HappyLogDB.confirmedSixties = HappyLogDB.confirmedSixties or {}
HappyLogDB.lastPlayerMessage = HappyLogDB.lastPlayerMessage or {}
C_ChatInfo.RegisterAddonMessagePrefix("HappyLog")
HappyLog.updateUI = HappyLog.updateUI or function() end
local secretKey = "HappyLogHash" -- Change this to something unique

-- Set debug mode
HappyLogDB.debug = false

-- Sound notification
local function playNotificationSound()
    PlaySound(888)
end

local function capitalizeFirstLetter(str)
    if not str or str == "" then
        return ""
    end
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

local function generateHash(message)
    local hash = 0
    for i = 1, #message do
        local byte = string.byte(message, i)
        hash = (hash + byte * i) % 100000
    end
    return tostring(hash)
end

local function onChatMsgSystem(event, message)
    if not message then
        debugPrint("Error: Received system message is nil.")
        return
    end

    debugPrint("Received system message:", message)

    -- Your processing logic here
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
        debugPrint("Added to confirmedSixties:", name)
    end
end

local function handleAddonMessage(event, text, sender, ...)
    local channelName = "happylogalertschannel"
    local _, _, _, _, _, _, _, channelIndex, receivedChannel = ...

    -- Ensure the message is from our custom channel
    if receivedChannel and receivedChannel:lower() ~= channelName then
        return
    end
    
    local prefix, receivedHash, parsedText = text:match("^(HappyLog):(%d+):(.*)$")
    if not prefix or not receivedHash or not parsedText then
        debugPrint("|cffffa500[HappyLog]:|r Ignoring manually typed message (incorrect format):", text)
        return
    end

    local expectedHash = generateHash(parsedText .. secretKey)

    if receivedHash ~= expectedHash then
        debugPrint("|cffff0000[HappyLog]:|r Invalid hash! Message ignored.")
        return
    end

    -- Now correctly extract the name and other details
    local name, guild, level, race, class, zone, lastMessage = strsplit(";", parsedText)

    -- Trim name to ensure no extra spaces
    local trimmedName = name:match("^%s*(.-)%s*$"):lower()

    level = tonumber(level)

    if type(HappyLogDB.data) ~= "table" then
        debugPrint("Error: HappyLogDB.data is not a table!")
        HappyLogDB.data = {}
    end
  

    -- Check if the name exists in the confirmedSixties array
    local existsInConfirmedSixties = false
    for _, confirmedName in ipairs(HappyLogDB.confirmedSixties or {}) do
        local trimmedConfirmed = confirmedName:match("^%s*(.-)%s*$"):lower()
        if trimmedConfirmed == trimmedName then
            existsInConfirmedSixties = true
            debugPrint("Character exists in sixties table:", trimmedConfirmed)
            break
        end
    end

    if existsInConfirmedSixties then
        -- Add to data table
        table.insert(HappyLogDB.data, {
            name = capitalizeFirstLetter(name),
            guild = capitalizeFirstLetter(guild or "No Guild"),
            class = capitalizeFirstLetter(class),
            zone = capitalizeFirstLetter(zone),
            message = lastMessage or "",
        })

        if HappyLog.updateUI then
            HappyLog.updateUI()
            debugPrint("HappyLog.updateUI was successfully called")
        else
            debugPrint("Error: HappyLog.updateUI is nil! Possible initialization issue.")
        end
        -- Play sound
        playNotificationSound()
    else 
        debugPrint("Character does not exists in sixties table")     
    end  
end

local function stripRealm(name)
    return name:match("^(.-)-") or name -- Strips the realm name if present
end

local function trackPlayerMessage(event, text, playerName, ...)
    if stripRealm(playerName) == UnitName("player") then
        HappyLogDB.lastPlayerMessage = text
        debugPrint("Updated last player message:", HappyLogDB.lastPlayerMessage)
    end
end

local function sendTestSystemMessage()
    local testMessage = "Sparebanko has reached level 60!"
    print("|cffffd700[Test]:|r", testMessage)
    ChatFrame1:AddMessage(testMessage)
    onChatMsgSystem("CHAT_MSG_SYSTEM", testMessage)
end

local function joinAddonChannel()
    local channelName = "happylogalertschannel"
    JoinChannelByName(channelName, nil, nil, false)
    debugPrint("|cffffd700[HappyLog]:|r Joined or already in channel:", channelName)
end

local frame = CreateFrame("Frame")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "PLAYER_LEVEL_UP" then
        local level = ...
        debugPrint("Player leveled up to:", level)

        if HappyLogDB.debug == true then
            level = 60
        end
        -- Check if the player reached level 60
        if level == 60 then
            print("Congratulations on reaching level 60!")

            -- Gather player information
            local name = UnitName("player") -- Player's name
            local guildName = GetGuildInfo("player") or "No Guild" -- Player's guild name
            local _, race = UnitRace("player") -- Player's race
            local _, class = UnitClass("player") -- Player's class
            local zone = GetZoneText() -- Current zone name
            local message = HappyLogDB.lastPlayerMessage -- Optional custom message

            -- Serialize the data
            local serialized = string.format("%s;%s;%d;%s;%s;%s;%s",
                name,
                guildName,
                level,
                race,
                class,
                zone,
                message
            )

            local channelName = "happylogalertschannel"
            local channelIndex = GetChannelName(channelName)
            
            if channelIndex and channelIndex > 0 then
                local hash = generateHash(serialized .. secretKey)
                local safeMessage = "HappyLog:" .. hash .. ":" .. serialized

                SendChatMessage(safeMessage, "CHANNEL", nil, channelIndex)
                debugPrint("Sent addon message to channel:", channelName)
            else
                debugPrint("|cffff0000[HappyLog]:|r Channel not found. Make sure you're connected.")
            end
        end

    elseif event == "CHAT_MSG_SYSTEM" then
        local message = ...
        onChatMsgSystem(event, message)
    elseif event == "CHAT_MSG_CHANNEL" then
        local text, sender, _, _, _, _, _, channelIndex, channelName = ...

        -- Check if this message is from our custom channel
        if channelName and channelName:lower() == "happylogalertschannel" then
            debugPrint("|cffffd700[HappyLog]:|r Received message in correct channel:", text)
            handleAddonMessage(event, text, sender, ...)
        end
    elseif event:match("^CHAT_MSG") then
        -- Track the player's last chat message
        trackPlayerMessage(event, ...)
    elseif event == "PLAYER_LOGIN" then
        joinAddonChannel()
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

-- Slash command for testing
SLASH_HAPPYLOG1 = "/hltest"
SLASH_HAPPYLOGDEBUG1 = "/hldebug"
SLASH_HAPPYLOGCLEAR1 = "/hlclear"
SLASH_HAPPYLOGSETTINGS1 = "/happylog"
SLASH_HAPPYLOGSETTINGS2 = "/hl"
SLASH_CONFIRMEDSIXTIES1 = "/sixties"
SLASH_TESTSYSTEMMSG1 = "/testmsg"
SLASH_TESTLASTMSG1 = "/hlmsg"
SLASH_TESTLEVELUP1 = "/hllvl"


SlashCmdList["TESTLEVELUP"] = function(level)
    if HappyLogDB.debug then
        level = tonumber(level) or 60 -- Default to level 60 if no argument is provided
        print("|cffffd700[Test]:|r Simulating level-up to level", level)
        -- Trigger your level-up logic
        frame:GetScript("OnEvent")(frame, "PLAYER_LEVEL_UP", level)
    end
end

SlashCmdList["CONFIRMEDSIXTIES"] = function()
    if HappyLogDB.debug then
        debugPrint("Confirmed Sixties:")
        for _, name in ipairs(HappyLogDB.confirmedSixties) do
            debugPrint("-", name)
        end
    end
end

SlashCmdList["TESTLASTMSG"] = function()
    if HappyLogDB.debug then
        debugPrint("Last Message: " .. HappyLogDB.lastPlayerMessage) 
    end
end

SlashCmdList["HAPPYLOGSETTINGS"] = function(msg)
    local category = Settings.GetCategory("HappyLog")
    if category then
        Settings.OpenToCategory(category)
    else
        debugPrint("HappyLog: Unable to open settings. The category might not be registered yet.")
    end
end

SlashCmdList["TESTSYSTEMMSG"] = function()
    if HappyLogDB.debug then
        sendTestSystemMessage()
    end
end

SlashCmdList["HAPPYLOG"] = function()
    if HappyLogDB.debug then
        debugPrint("In /hltest command. HappyLog:", HappyLog, "HappyLog.updateUI:", HappyLog.updateUI)

        if not HappyLog.updateUI then
            debugPrint("Error: HappyLog.updateUI is nil before calling handleAddonMessage.")
            return
        end

        local testData = {
            name = "TestPlayer",
            guild = "TestGuild",
            level = 60,
            race = "Orc",
            class = "Warrior",
            zone = "Orgrimmar",
            message = "This is a test message!",
        }
        local serialized = string.format("%s;%s;%d;%s;%s;%s;%s",
            testData.name,
            testData.guild,
            testData.level,
            testData.race,
            testData.class,
            testData.zone,
            testData.message
        )
        handleAddonMessage(nil, nil, "HappyLog", serialized, nil, "Tester")
    end
end

SlashCmdList["HAPPYLOGCLEAR"] = function()
    if HappyLogDB.debug then
        -- Clear the HappyLogDB.data table
        if HappyLogDB and HappyLogDB.data then
            wipe(HappyLogDB.data) -- Efficiently clears the table
            debugPrint("|cffffd700[HappyLog]:|r Data table has been cleared.")
        else
            debugPrint("|cffffd700[HappyLog]:|r No data to clear.")
        end

        -- Update the UI
        if HappyLog.updateUI then
            HappyLog.updateUI()
        end
    end
end

SlashCmdList["HAPPYLOGDEBUG"] = function(msg)
    if not HappyLogDB then
        print("|cffff0000[HappyLog]:|r Error - HappyLogDB is not initialized.")
        return
    end
    -- Toggle debug mode
    if HappyLogDB.debug then
        HappyLogDB.debug = false
        print("|cffffd700[HappyLog]:|r Debug mode |cffff0000DISABLED|r.")
    else
        HappyLogDB.debug = true
        print("|cffffd700[HappyLog]:|r Debug mode |cff00ff00ENABLED|r.")
    end

    -- Optional: Print the current state of HappyLogDB.debug
    print("|cffffd700[HappyLog]:|r Current debug state:", HappyLogDB.debug and "ENABLED" or "DISABLED")
end
