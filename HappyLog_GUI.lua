-- Default settings for the frame
local default_settings = {
    pos_x = 0, -- Default X offset
    pos_y = 0, -- Default Y offset
    size_x = 520, -- Default width
    size_y = 350, -- Default height
    lock = false, -- Whether the frame is locked
}

local defaultColumns = {
    { name = "Name", width = 100},
    { name = "Guild", width = 100},
    { name = "Class", width = 60},
    { name = "Zone", width = 60},
    { name = "Last Message", width = 150},
}

-- Initialize or restore columns
HappyLogDB = HappyLogDB or {}
HappyLogDB.columns = HappyLog.columns or defaultColumns

-- Ensure the global HappyLog table exists
HappyLog = HappyLog or {}
-- Debug helper
local function debugPrint(...)
    if HappyLogDB and HappyLogDB.debug then
        print("|cffffd700[HappyLog Debug]:|r", ...)
    end
end

-- Apply default settings (assuming HappyLogDB is initialized in HappyLog.lua)
for key, value in pairs(default_settings) do
    if HappyLogDB[key] == nil then
        HappyLogDB[key] = value
    end
end

HappyLogDB.Minimized = HappyLogDB.Minimized or false

-- Initialize settings
HappyLog_Settings.Initialize()

local function createMainFrame()
    local mainFrame = CreateFrame("Frame", "HappyLogMainFrame", UIParent, "BackdropTemplate")
    mainFrame:SetSize(HappyLogDB.size_x or 520, HappyLogDB.size_y or 350)
    
    -- Enable clipping for child frames
    mainFrame:SetClipsChildren(true)

    -- Restore position if available, otherwise use defaults
    if HappyLogDB.pos_x and HappyLogDB.pos_y then
        mainFrame:SetPoint(
            HappyLogDB.point or "CENTER",
            UIParent,
            HappyLogDB.relativePoint or "CENTER",
            HappyLogDB.pos_x,
            HappyLogDB.pos_y
        )
    else
        mainFrame:SetPoint("CENTER", UIParent, "CENTER", 0, 0)
    end

    mainFrame:SetMovable(true)
    mainFrame:SetResizable(true)
    mainFrame:EnableMouse(false)
    mainFrame:SetClampedToScreen(true)

    mainFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    mainFrame:SetBackdropColor(0, 0, 0, 0.8)

    local resizeUpdateTimer = nil

    mainFrame:SetScript("OnSizeChanged", function(self, width, height)
        HappyLogDB.size_x = width
        HappyLogDB.size_y = height

        -- Update header column sizes
        if self.headerFrame then
            local offsetX = 5 -- Initial padding
            local totalWidth = width - 10 -- Adjust for padding

            for _, headerData in ipairs(self.headerFrame.headers) do
                local headerText = headerData.header
                local col = headerData.column
                headerText:SetWidth(col.width)
                headerText:ClearAllPoints()
                headerText:SetPoint("LEFT", self.headerFrame, "LEFT", offsetX, 0)
                offsetX = offsetX + col.width + 2
            end
        end

        -- Throttle row updates
        if not resizeUpdateTimer then
            resizeUpdateTimer = C_Timer.NewTimer(0.1, function()
                HappyLog.updateUI()
                resizeUpdateTimer = nil
            end)
        end
    end)

    return mainFrame
end

-- Create the toggle button
local function createToggleButton(titleFrame, mainFrame)
    local toggleButton = CreateFrame("Button", "HappyLogToggleButton", titleFrame, "UIPanelButtonTemplate")
    toggleButton:SetSize(30, 15)

    -- Attach to the top-left corner of the titleFrame
    toggleButton:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 5, -2)
    toggleButton:SetText(HappyLogDB.Minimized and "+" or "-")

    -- Toggle main frame visibility
    toggleButton:SetScript("OnClick", function()
        if mainFrame:IsShown() then
            mainFrame:Hide()
            titleFrame:SetAlpha(0.5)
            toggleButton:SetText("+")
            HappyLogDB.Minimized = true
        else
            mainFrame:Show()
            toggleButton:SetText("-")
            titleFrame:SetAlpha(1)
            HappyLogDB.Minimized = false
        end
    end)

    return toggleButton
end

local function createTitleFrame(mainFrame)
    -- Create the title frame
    local titleFrame = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
    titleFrame:SetHeight(20)
    titleFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    titleFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    titleFrame:EnableMouse(true)
    titleFrame:RegisterForDrag("LeftButton")

    -- Add a simple backdrop for the title bar
    titleFrame:SetBackdrop({
        bgFile = "Interface/Tooltips/UI-Tooltip-Background",
        edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
        tile = true,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    titleFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)

    -- Add a title text (optional)
    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, 0)
    titleText:SetText("HappyLog")

    -- Dragging functionality
    titleFrame:SetScript("OnDragStart", function(self)
        if not HappyLogDB.lock then
            mainFrame:StartMoving()
        end
    end)

    titleFrame:SetScript("OnDragStop", function(self)
        mainFrame:StopMovingOrSizing()
        local point, relativeTo, relativePoint, xOfs, yOfs = mainFrame:GetPoint()
        HappyLogDB.pos_x = xOfs
        HappyLogDB.pos_y = yOfs
        HappyLogDB.point = point
        HappyLogDB.relativePoint = relativePoint
    end)

    return titleFrame
end

local function createHeaderFrame(parent)   
    if not HappyLog.columns or #HappyLog.columns == 0 then
        debugPrint("Warning: HappyLog.columns is empty! Restoring defaults.")
        HappyLog.columns = CopyTable(defaultColumns)
    end

    -- Header frame setup
    local headerHeight = 20
    local offsetX = 5 -- Initial padding

    -- Create the header frame
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetHeight(headerHeight)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -20)
    headerFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", -5, -20)

    headerFrame.headers = {}

    for _, order in ipairs(HappyLogDB.columnOrder) do
        if order then -- Skip nil or "Nothing"
            for _, col in ipairs(HappyLog.columns) do     
                if order == col.name then
                    local headerText = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                    headerText:SetPoint("LEFT", headerFrame, "LEFT", offsetX, 0)
                    headerText:SetWidth(col.width)
                    headerText:SetJustifyH("LEFT")
                    headerText:SetText(col.name)
                    headerText:SetTextColor(1, 1, 1, 1)

                    table.insert(headerFrame.headers, { header = headerText, column = col })
                    offsetX = offsetX + col.width + 6 -- Adjust offset for next column
                    break
                end
            end
        else
            -- Create an empty placeholder for nil entries
            local emptyHeader = headerFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
            emptyHeader:SetPoint("LEFT", headerFrame, "LEFT", offsetX, 0)
            emptyHeader:SetWidth(60) -- Default width for empty columns
            emptyHeader:SetJustifyH("LEFT")
            emptyHeader:SetText(" ") -- No text for empty columns
            emptyHeader:SetTextColor(0.5, 0.5, 0.5, 1) -- Faded text color
    
            -- Save the empty header as a placeholder
            table.insert(headerFrame.headers, { header = emptyHeader, column = nil })
            offsetX = offsetX + 60 + 6 -- Adjust offset for the next column
        end
    end

    parent.headerFrame = headerFrame
    return headerFrame
end

-- Create the resize button
local function createResizeButton(parent)
    local resizeButton = CreateFrame("Button", nil, parent)
    resizeButton:SetSize(16, 16)
    resizeButton:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -4, 4)

    resizeButton:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
    resizeButton:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
    resizeButton:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")

    -- Ensure the resize button is above other elements
    resizeButton:SetFrameLevel(parent:GetFrameLevel() + 5)
    
    resizeButton:SetScript("OnMouseDown", function(self, button)
        if button == "LeftButton" then
            parent:StartSizing("BOTTOMRIGHT")
        end
    end)   
    
    resizeButton:SetScript("OnMouseUp", function(self, button)
        if button == "LeftButton" then
            parent:StopMovingOrSizing()
            --HappyLog.updateUI()
        end
    end)

    return resizeButton
end

-- Create row entries
local function setupRowEntries(parent, data)
    --sortColumnsByOrder(HappyLog.columns)

    data = data or {}
    local rowHeight = 16
    local parentWidth = parent:GetWidth() - 10 -- Adjust for padding
    local contentHeight = #data * rowHeight
    local visibleHeight = parent:GetHeight() - 45 -- Space for visible rows

    -- Clear existing rows and content
    if parent.scrollFrame then
        parent.scrollFrame:Hide()
        parent.scrollFrame:SetParent(nil)
    end

    -- Create the scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(parentWidth, visibleHeight)
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -37)
    parent.scrollFrame = scrollFrame

    -- Create the content frame inside the scroll frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(parentWidth, math.max(contentHeight, visibleHeight)) -- Ensure content is at least the visible height
    scrollFrame:SetScrollChild(content)

    -- Attach a scroll bar to the scroll frame
    --scrollFrame.ScrollBar:Show()
    scrollFrame.ScrollBar:SetMinMaxValues(0, math.max(0, contentHeight - visibleHeight))
    scrollFrame.ScrollBar:SetValueStep(rowHeight)
    scrollFrame.ScrollBar:SetValue(0)
    

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local newValue = scrollFrame.ScrollBar:GetValue() - (delta * rowHeight)
        scrollFrame.ScrollBar:SetValue(math.max(0, math.min(newValue, contentHeight - visibleHeight)))
    end)
    scrollFrame.ScrollBar:Hide()
    content.rows = {}

    -- Create rows dynamically
    for i, player in ipairs(data) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(parentWidth, rowHeight) -- Adjust this value to control the top gap
        row:SetPoint("TOP", content, "TOP", 0, -(i - 1) * rowHeight)

        -- Background color for row
        local bgColor = (i % 2 == 0) and {0.2, 0.2, 0.2, 0.8} or {0.1, 0.1, 0.1, 0.8}
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(unpack(bgColor))
        -- Hover effect
        row:SetScript("OnEnter", function()
            row.bg:SetColorTexture(0.3, 0.3, 0.5, 0.8) -- Highlight color

            -- Show tooltip with player info
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Player Information", 1, 1, 1)
            GameTooltip:AddLine("Name: " .. (player.name or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Class: " .. (player.class or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Guild: " .. (player.guild or "No Guild"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Zone: " .. (player.zone or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Last Message: " .. (player.message or "No Message"), 0.8, 0.8, 0.8)
            GameTooltip:Show()
        end)
        row:SetScript("OnLeave", function()
            row.bg:SetColorTexture(unpack(bgColor)) -- Restore default color
            GameTooltip:Hide() -- Hide tooltip
        end)

        -- Add text columns dynamically
        local offsetX = 5 -- Initial padding
        
        for _, order in ipairs(HappyLogDB.columnOrder) do
            if order then -- Skip nil or "Nothing"
                for _, col in ipairs(HappyLog.columns) do 
                    if order == col.name then
                        local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                        text:SetFont("Fonts\\FRIZQT__.TTF", 10)
                        text:SetPoint("LEFT", row, "LEFT", offsetX, 0)
                        text:SetWidth(col.width)
                        text:SetJustifyH("LEFT")
                        text:SetWordWrap(false)
                        text:SetTextColor(1, 1, 1, 1)

                        -- Dynamically fetch the value based on the column name
                        local value = ""
                        if col.name == "Name" then
                            value = player.name or ""
                        elseif col.name == "Class" then
                            value = player.class or ""
                        elseif col.name == "Zone" then
                            value = player.zone or ""
                        elseif col.name == "Guild" then
                            value = player.guild or "No Guild"
                        elseif col.name == "Last Message" then
                            value = player.message or ""
                        end
                        -- Set the text for this column
                        text:SetText(value)
                        offsetX = offsetX + col.width + 6 -- Adjust offset for next column
                    end
                end
            else
                local text = row:CreateFontString(nil, "OVERLAY", "GameFontNormal")
                text:SetFont("Fonts\\FRIZQT__.TTF", 10)
                text:SetPoint("LEFT", row, "LEFT", offsetX, 0)
                text:SetWidth(60)                
                text:SetJustifyH("LEFT")
                text:SetWordWrap(false)
                text:SetTextColor(1, 1, 1, 1)
                text:SetText("")
                
                offsetX = offsetX + 60 + 2 -- Adjust offset for next column
            end
        end

        table.insert(content.rows, row)
    end
end

-- Initialize UI
local function initializeUI()
    -- Ensure columns are initialized
    if not HappyLog.columns or type(HappyLog.columns) ~= "table" then
        debugPrint("HappyLog.columns is nil or invalid! Restoring defaults.")
        HappyLog.columns = CopyTable(HappyLogDB.columns or defaultColumns)
    end

    --local parentFrame = createParentFrame()
    local mainFrame = createMainFrame()
    local titleFrame = createTitleFrame(mainFrame)
    local toggleButton = createToggleButton(titleFrame, mainFrame)
    local resizeButton = createResizeButton(mainFrame)

    -- Add the header frame below the title frame
    local headerFrame = createHeaderFrame(mainFrame)

    -- Restore minimized state on reload
    if HappyLogDB.Minimized then
        mainFrame:Hide()
        toggleButton:SetText("+")
    else
        mainFrame:Show()
        toggleButton:SetText("-")
    end

    -- Define updateUI to refresh the data
    HappyLog.updateUI = function()
        -- Refresh headers
        if mainFrame.headerFrame then
            headerFrame:Hide()
            headerFrame:SetParent(nil)
        end
        headerFrame = createHeaderFrame(mainFrame)
    
        -- Refresh rows     
        setupRowEntries(mainFrame, HappyLogDB.data)
    end
    HappyLog.updateUI()
end

-- Wait for PLAYER_LOGIN to initialize saved variables
local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_LOGIN")
eventFrame:SetScript("OnEvent", function()    
    initializeUI() -- Initialize UI after the player logs in
    -- Initialize settings
    HappyLog_Settings.Initialize()
    HappyLog_Settings.createSettingsPanel()
end)

