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

-- Initialize settings
function HappyLog_Settings.Initialize()
    HappyLogDB = HappyLogDB or {}
    HappyLogDB.columns = HappyLogDB.columns or CopyTable(HappyLog_Data.columns)
    if #HappyLogDB.columnOrder == 0 then
        for i, col in ipairs(HappyLog_Data.columns) do
            HappyLogDB.columnOrder[i] = col.name
        end
    end
    
    HappyLog.columns = CopyTable(HappyLogDB.columns)
    updateColumnsOrder()
end

local function createColumnDropdowns(columnConfigFrame, dropdowns)
    local dropdownWidth = 170
    local dropdownHeight = 40
    local paddingX = 16
    local paddingY = 10

    --TODO: remove this at a later date if we get column suggestions.
    local moreColumnsText = columnConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")    
    moreColumnsText:SetPoint("TOPLEFT", columnConfigFrame, "TOPRIGHT", -150, -16)
    moreColumnsText:SetText("More column suggestions?")

    for i = 1, #HappyLog_Data.columns do
        local header = columnConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        header:SetText("Column " .. i)

        local dropdown = CreateFrame("Frame", nil, columnConfigFrame, "UIDropDownMenuTemplate")

        -- Determine row and column position
        local row = math.floor((i - 1) / 2)
        local col = (i - 1) % 2
        -- Calculate offsets
        local xOffset = 16 + col * (dropdownWidth + paddingX)
        local yOffset = -16 - row * (dropdownHeight + paddingY)

        -- Position headers and dropdowns
        header:SetPoint("TOPLEFT", columnConfigFrame, "TOPLEFT", xOffset, yOffset)
        dropdown:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -16, -4)

        -- Set dropdown properties
        UIDropDownMenu_SetWidth(dropdown, dropdownWidth-20)
        UIDropDownMenu_SetText(dropdown, HappyLogDB.columnOrder[i] or "Nothing")

        -- Store dropdown for future reference
        table.insert(dropdowns, dropdown)
    end
end


local function createSoundDropdown(columnConfigFrame)

    HappyLogSoundDropdown = CreateFrame("Frame", "HappyLogSoundDropdown", columnConfigFrame, "UIDropDownMenuTemplate")

    local header = columnConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    header:SetText("Select Notification Sound")

    header:SetPoint("TOPLEFT", columnConfigFrame, "BOTTOMLEFT", 0, -16)
    HappyLogSoundDropdown:SetPoint("TOPLEFT", header, "BOTTOMLEFT", -16, -4)


    UIDropDownMenu_SetWidth(HappyLogSoundDropdown, 150)
        local selectedSoundName = "Sounds"
        if HappyLogDB.selectedSoundID then
            for _, sound in ipairs(HappyLog_Data.sounds) do
                if sound.id == HappyLogDB.selectedSoundID then
                    selectedSoundName = sound.name
                    break
                end
            end
        end
    UIDropDownMenu_SetText(HappyLogSoundDropdown, selectedSoundName)
end

local function refreshSoundDropdown()
    print(HappyLogDB.selectedSoundID)
    UIDropDownMenu_Initialize(HappyLogSoundDropdown, function(self, level, menuList)
        for _, sound in ipairs(HappyLog_Data.sounds) do
            local info = UIDropDownMenu_CreateInfo()
            info.text = sound.name
            info.checked = HappyLogDB.selectedSoundID == sound.id
            info.func = function()
                DebugPrint("Selected Sound:", sound.id)
                UIDropDownMenu_SetText(HappyLogSoundDropdown, sound.name)
                HappyLogDB.selectedSoundID = sound.id
                PlayNotificationSound(sound.id)
            end
            UIDropDownMenu_AddButton(info, level)
        end
    end)
end

--Change this to a useful frame at a later date. 
local function createComingSoonFrame(parent)
    local comingSoonFrame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    comingSoonFrame:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 0, -100)
    comingSoonFrame:SetSize(600, 180)
    comingSoonFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    comingSoonFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local comingSoonHeader = comingSoonFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    comingSoonHeader:SetPoint("BOTTOMLEFT", comingSoonFrame, "TOPLEFT", 0, 2)
    comingSoonHeader:SetText("More settings coming soon...")
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

local function refreshDropdownOptions(dropdowns)
    for i, dropdown in ipairs(dropdowns) do
        UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
            for _, column in ipairs(HappyLog_Data.columns) do
                local info = UIDropDownMenu_CreateInfo()
                info.text = column.name
                info.checked = HappyLogDB.columnOrder[i] == column.name
                info.func = function()
                    HappyLogDB.columnOrder[i] = column.name
                    UIDropDownMenu_SetText(dropdown, column.name)    
                    
                    -- -- Clear the same item from any other dropdown
                    for j, otherDropdown in ipairs(dropdowns) do
                        if i ~= j and HappyLogDB.columnOrder[j] == column.name then    
                                                    
                            HappyLogDB.columnOrder[j] = "Nothing"
                            UIDropDownMenu_SetText(otherDropdown, "Nothing")
                        end
                    end                    
                    -- Normalize and reorder the column order
                    reorderAndNormalizeColumnOrder()
                    HappyLog.updateUI()
                end
                UIDropDownMenu_AddButton(info, level)
            end

            -- -- Add "Nothing" option
            local info = UIDropDownMenu_CreateInfo()
            info.text = "Nothing"
            info.checked = HappyLogDB.columnOrder[i] == nil
            info.func = function()
                -- Clear the selection for this dropdown
                HappyLogDB.columnOrder[i] = "Nothing"
                UIDropDownMenu_SetText(dropdown, "Nothing")

                -- Normalize and reorder the column order
                reorderAndNormalizeColumnOrder()

                -- Update the UI
                HappyLog.updateUI()
            end
            UIDropDownMenu_AddButton(info)
        end)
    end
end

function HappyLog_Settings.createSettingsPanel()
    local dropdowns = {}
    
    local panel = CreateFrame("Frame", "HappyLogSettingsPanel", UIParent)
    panel.name = "HappyLog"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HappyLog Settings")  
    
    if Settings and Settings.RegisterCanvasLayoutCategory then
        local category = Settings.RegisterCanvasLayoutCategory(panel, "HappyLog")
        Settings.RegisterAddOnCategory(category)
        HappyLog_Settings.category = category
    else
        DebugPrint("|cffff0000[HappyLog]:|r Error: No valid API found to register settings.")
    end

    -- Ensure HappyLogDB.columnOrder has enough entries and maintain size
    local function normalizeColumnOrder()
        HappyLogDB.columnOrder = HappyLogDB.columnOrder or {}
        for i = 1, #HappyLog_Data.columns do
            if not HappyLogDB.columnOrder[i] then
                HappyLogDB.columnOrder[i] = nil
            end
        end
    end

    -- Create Column Configuration Section
    local columnConfigFrame = CreateFrame("Frame", nil, panel, "BackdropTemplate")
    columnConfigFrame:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -30)
    columnConfigFrame:SetSize(600, 180)
    columnConfigFrame:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    columnConfigFrame:SetBackdropColor(0.1, 0.1, 0.1, 0.8)

    local columnConfigHeader = columnConfigFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    columnConfigHeader:SetPoint("BOTTOMLEFT", columnConfigFrame, "TOPLEFT", 0, 2)
    columnConfigHeader:SetText("Configure order and visibility of columns")


    createColumnDropdowns(columnConfigFrame, dropdowns)
    createSoundDropdown(columnConfigFrame)

    --Change this to something useful at a later date
    createComingSoonFrame(columnConfigFrame)

    -- Initialize column order and refresh dropdowns
    normalizeColumnOrder()
    reorderAndNormalizeColumnOrder()
    refreshSoundDropdown()
    refreshDropdownOptions(dropdowns)

  return panel
end

-- Initialize HappyLog settings
HappyLog_Settings.Initialize()
