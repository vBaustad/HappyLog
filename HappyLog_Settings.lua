-- Ensure the global HappyLog table exists
HappyLog = HappyLog or {}
HappyLog_Settings = {}

-- Debug helper
local function debugPrint(...)
    if HappyLogDB and HappyLogDB.debug then
        print("|cffffd700[HappyLog Debug]:|r", ...)
    end
end

-- Default column configuration
local defaultColumns = {
    { name = "Name", width = 60},
    { name = "Guild", width = 120},
    { name = "Class", width = 40},
    { name = "Zone", width = 60},
    { name = "Last Message", width = 200},
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
            table.insert(reorderedColumns, nil) -- Placeholder for empty columns
        end
    end

    -- Update HappyLog.columns
    HappyLog.columns = reorderedColumns
end

-- Initialize settings
function HappyLog_Settings.Initialize()
    HappyLogDB = HappyLogDB or {}
    -- Initialize columns and column order
    HappyLogDB.columns = HappyLogDB.columns or CopyTable(defaultColumns)
    HappyLogDB.columnOrder = HappyLogDB.columnOrder or {}

    -- Populate columnOrder with default values if empty
    if #HappyLogDB.columnOrder == 0 then
        for i, col in ipairs(defaultColumns) do
            HappyLogDB.columnOrder[i] = col.name
        end
    end
    
    HappyLog.columns = CopyTable(HappyLogDB.columns)
    updateColumnsOrder()
end

function HappyLog_Settings.createSettingsPanel()
    local panel = CreateFrame("Frame", "HappyLogSettingsPanel", UIParent)
    panel.name = "HappyLog"

    local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
    title:SetPoint("TOPLEFT", 16, -16)
    title:SetText("HappyLog Settings")

    local subtitle = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
    subtitle:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -8)
    subtitle:SetText("Manage visible columns and their order.")

    local dropdowns = {}
    local lastControl

    -- Ensure HappyLogDB.columnOrder has enough entries and maintain size
    local function normalizeColumnOrder()
        HappyLogDB.columnOrder = HappyLogDB.columnOrder or {}
        for i = 1, #defaultColumns do
            if not HappyLogDB.columnOrder[i] then
                HappyLogDB.columnOrder[i] = nil
            end
        end
    end

    -- Function to reorder and normalize the column order
    local function reorderAndNormalizeColumnOrder()
        local filled = {} -- Holds selected column names
        local emptyCount = 0 -- Count of empty slots

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
            table.insert(HappyLogDB.columnOrder, nil) -- Append empty placeholders
        end
        -- Sync HappyLog.columns with the new order
        updateColumnsOrder()
    end

    -- Function to print the current column order with placeholders
    local function printColumnOrder()
        for i, column in ipairs(HappyLogDB.columnOrder) do
            debugPrint(column or "---") -- Show "---" for empty slots
        end
    end

    -- Function to refresh all dropdowns
    local function refreshDropdownOptions()
        for i, dropdown in ipairs(dropdowns) do
            UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
                for _, column in ipairs(defaultColumns) do
                    local info = UIDropDownMenu_CreateInfo()
                    info.text = column.name
                    info.checked = HappyLogDB.columnOrder[i] == column.name
                    info.func = function()
                        -- Update the selected column in this dropdown
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
                        -- Print the current column order
                        printColumnOrder()
                        -- Update the UI
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
                    -- Print the current column order
                    printColumnOrder()
                    -- Update the UI
                    HappyLog.updateUI()
                end
                UIDropDownMenu_AddButton(info)
            end)
        end
    end

    -- Create dropdowns dynamically
    for i = 1, #defaultColumns do
        local dropdown = CreateFrame("Frame", nil, panel, "UIDropDownMenuTemplate")
        dropdown:SetPoint("TOPLEFT", lastControl or subtitle, "BOTTOMLEFT", 0, lastControl and -16 or -24)
        lastControl = dropdown
        UIDropDownMenu_SetText(dropdown, HappyLogDB.columnOrder[i] or "Nothing")
        table.insert(dropdowns, dropdown)
    end

    -- Initialize column order and refresh dropdowns
    normalizeColumnOrder()
    reorderAndNormalizeColumnOrder()
    refreshDropdownOptions()

    -- Register the panel with Blizzard's Settings system
    local category = Settings.RegisterCanvasLayoutCategory(panel, "HappyLog")
    Settings.RegisterAddOnCategory(category)
end


-- Initialize HappyLog settings
HappyLog_Settings.Initialize()
