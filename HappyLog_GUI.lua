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
    mainFrame:SetResizeBounds(100, 50, 800, 400)
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
    -- Create a button attached to the titleFrame
    local toggleButton = CreateFrame("Button", "HappyLogToggleButton", UIParent)
    toggleButton:SetSize(20, 20) -- Set size for the button (slightly smaller to fit the border)
    toggleButton:SetPoint("TOPLEFT", titleFrame, "TOPLEFT", 0, 2) -- Position in the top-left corner

    -- Ensure it stays above other frames
    toggleButton:SetFrameStrata("HIGH")
    toggleButton:SetFrameLevel(10)

    -- Add a circular mask for the button
    local mask = toggleButton:CreateMaskTexture()
    mask:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask") -- Blizzard's circular mask
    mask:SetAllPoints(toggleButton)

    -- Add the custom image
    local texture = toggleButton:CreateTexture(nil, "BACKGROUND")
    texture:SetTexture("Interface\\AddOns\\HappyLog\\Media\\HappyLogCircular.tga") -- Replace with your texture path
    texture:SetAllPoints(toggleButton) -- Ensure the image fills the button
    texture:AddMaskTexture(mask) -- Apply the mask to make the image circular

    -- Add a circular border
    local border = toggleButton:CreateTexture(nil, "OVERLAY")
    border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder") -- Minimap button border texture
    border:SetPoint("CENTER", toggleButton, "CENTER", 10, -12) -- Center the border on the button
    border:SetSize(50, 50) -- Adjust to fit slightly larger than the button


    -- Enable dragging functionality
    toggleButton:SetMovable(true)
    toggleButton:EnableMouse(true)
    toggleButton:RegisterForDrag("LeftButton")
    toggleButton:SetScript("OnDragStart", function(self)
        if not HappyLogDB.lock then -- Check if the frame is locked
            mainFrame:StartMoving() -- Begin moving the parent frame
            mainFrame.isMoving = true
        end
    end)

    toggleButton:SetScript("OnDragStop", function(self)
        if mainFrame.isMoving then
            mainFrame:StopMovingOrSizing() -- Stop moving the frame
            mainFrame.isMoving = false

            -- Save the new position in the database
            local point, _, relativePoint, xOfs, yOfs = mainFrame:GetPoint()
            HappyLogDB.pos_x = xOfs
            HappyLogDB.pos_y = yOfs
            HappyLogDB.point = point
            HappyLogDB.relativePoint = relativePoint
        end
    end)

    -- Add functionality: Toggle the visibility of the main frame
    toggleButton:SetScript("OnClick", function()
        if mainFrame:IsShown() then
            titleFrame:Hide()
            mainFrame:Hide()
            --toggleButton:SetAlpha(0.5) -- Optional: Adjust transparency to indicate the minimized state
        else
            titleFrame:Show()
            mainFrame:Show()
            --toggleButton:SetAlpha(1)
        end
    end)

    return toggleButton
end

local function createTitleFrame(mainFrame)
    -- Create the title frame
    local titleFrame = CreateFrame("Frame", "HappyLogTitleBar", UIParent, "BackdropTemplate")
    titleFrame:SetHeight(20)
    titleFrame:SetPoint("TOPLEFT", mainFrame, "TOPLEFT", 0, 0)
    titleFrame:SetPoint("TOPRIGHT", mainFrame, "TOPRIGHT", 0, 0)
    titleFrame:EnableMouse(true)
    titleFrame:RegisterForDrag("LeftButton")

    titleFrame:SetBackdropColor(0.1, 0.1, 0.1, 1)

    -- Add a title text (optional)
    local titleText = titleFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    titleText:SetPoint("CENTER", titleFrame, "CENTER", 0, -1)
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
        DebugPrint("Warning: HappyLog.columns is empty! Restoring defaults.")
        HappyLog.columns = CopyTable(HappyLog_Data.columns)
    end

    -- Header frame setup
    local headerHeight = 10
    local offsetX = 5 -- Initial padding

    -- Create the header frame
    local headerFrame = CreateFrame("Frame", nil, parent)
    headerFrame:SetHeight(headerHeight)
    headerFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -23)
    headerFrame:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 5, -5)

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
                    headerText:SetTextColor(0.7, 0.7, 0.7)                  

                    table.insert(headerFrame.headers, { header = headerText, column = col })
                    offsetX = offsetX + col.width -- Adjust offset for next column
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
            offsetX = offsetX + 60 -- Adjust offset for the next column
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
    data = data or {}
    local rowHeight = 16
    local parentWidth = parent:GetWidth() - 10 -- Adjust for padding
    local contentHeight = #data * rowHeight
    local visibleHeight = parent:GetHeight() -- Space for visible rows
    -- Clear existing rows and content
    if parent.scrollFrame then
        parent.scrollFrame:Hide()
        parent.scrollFrame:SetParent(nil)
    end

    -- Create the scroll frame
    local scrollFrame = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
    scrollFrame:SetSize(parentWidth, visibleHeight)
    scrollFrame:SetPoint("TOPLEFT", parent, "TOPLEFT", 5, -35)
    scrollFrame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -5, 5)
    parent.scrollFrame = scrollFrame

    -- Create the content frame inside the scroll frame
    local content = CreateFrame("Frame", nil, scrollFrame)
    content:SetSize(parentWidth, math.max(contentHeight, visibleHeight)) -- Ensure content is at least the visible height
    scrollFrame:SetScrollChild(content)
    
    scrollFrame.ScrollBar:SetMinMaxValues(0, math.max(0, contentHeight - visibleHeight))
    scrollFrame.ScrollBar:SetValueStep(rowHeight)
    scrollFrame.ScrollBar:SetValue(0)
    

    scrollFrame:SetScript("OnMouseWheel", function(_, delta)
        local newValue = scrollFrame.ScrollBar:GetValue() - (delta * rowHeight)
        scrollFrame.ScrollBar:SetValue(math.max(0, math.min(newValue, contentHeight - visibleHeight)))
    end)
    scrollFrame.ScrollBar:Hide()
    scrollFrame.ScrollBar:SetWidth(0)
    content.rows = {}

    -- Create rows dynamically
    for i, player in ipairs(data) do
        local row = CreateFrame("Frame", nil, content)
        row:SetSize(parentWidth, rowHeight) -- Adjust this value to control the top gap
        row:SetPoint("TOP", content, "TOP", 0, -(i - 1) * rowHeight)

        -- Background color for row
        local bgColor = (i % 2 == 0) and {0.2, 0.2, 0.2, 0.8} or {0.1, 0.1, 0.1, 0.5}
        row.bg = row:CreateTexture(nil, "BACKGROUND")
        row.bg:SetAllPoints(row)
        row.bg:SetColorTexture(unpack(bgColor))
        -- Hover effect
        row:SetScript("OnEnter", function()
            row.bg:SetColorTexture(0.3, 0.3, 0.5, 0.5) -- Highlight color

            -- Show tooltip with player info
            GameTooltip:SetOwner(row, "ANCHOR_RIGHT")
            GameTooltip:ClearLines()
            GameTooltip:AddLine("Player Information", 1, 0.82, 0)
            GameTooltip:AddLine("Name: " .. (player.name or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Class: " .. (player.class or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Guild: " .. (player.guild or ""), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Zone: " .. (player.zone or "Unknown"), 0.8, 0.8, 0.8)
            GameTooltip:AddLine("Last Message: " .. (player.message or ""), 0.8, 0.8, 0.8)
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

                        -- Dynamically fetch the value based on the column name
                        local value = ""
                        if col.name == "Name" then
                            value = player.name or ""
                            text:SetTextColor(1, 1, 1, 1)
                        elseif col.name == "Class" then
                            value = player.class or ""
                             -- Fetch the class color
                            local classColor = RAID_CLASS_COLORS[string.upper(value)]
                            if classColor then
                                text:SetTextColor(classColor.r, classColor.g, classColor.b, 1)
                            else
                                text:SetTextColor(1, 1, 1, 1) -- Default white for unknown classes
                            end
                        elseif col.name == "Zone" then
                            value = player.zone or ""
                            text:SetTextColor(1, 1, 1, 1)
                        elseif col.name == "Guild" then
                            value = player.guild or ""
                            text:SetTextColor(1, 1, 1, 1)
                        elseif col.name == "Last Message" then
                            value = player.message or ""
                            text:SetTextColor(1, 1, 1, 1)
                        end
                        -- Set the text for this column
                        text:SetText(value)
                        offsetX = offsetX + col.width -- Adjust offset for next column
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
                
                offsetX = offsetX + 60 -- Adjust offset for next column
            end
        end

        table.insert(content.rows, row)
    end
end

function ShowHideFrame()
    local framesToToggle = {
        _G["HappyLogMainFrame"],  -- Main frame
        _G["HappyLogTitleBar"],
    }
    
    -- Find if at least one frame is shown
    local isAnyFrameVisible = false
    for _, frame in ipairs(framesToToggle) do
        if frame and frame:IsShown() then
            isAnyFrameVisible = true
            break
        end
    end

    -- Toggle visibility
    for _, frame in ipairs(framesToToggle) do
        if frame then
            if isAnyFrameVisible then
                frame:Hide()
            else
                frame:Show()
            end
        end
    end
end

-- Initialize UI
local function initializeUI()
    -- Ensure columns are initialized
    if not HappyLog.columns or type(HappyLog.columns) ~= "table" then
        DebugPrint("HappyLog.columns is nil or invalid! Restoring defaults.")
        HappyLog.columns = CopyTable(HappyLogDB.columns or HappyLog_Data.columns)
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

