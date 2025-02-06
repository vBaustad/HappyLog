local LibDBIcon = LibStub("LibDBIcon-1.0")
local LDB = LibStub("LibDataBroker-1.1")

local minimapButton  -- Store the button globally to prevent duplicates

local function CreateMinimapButton()
    if minimapButton then
        return minimapButton -- Prevent multiple creations
    end

    local addonName = "HappyLog"
    local minimapButtonDB = {
        profile = {
            minimapButton = {
                hide = false,
                oldIcon = false,
            }
        }
    }

    local function GetIcon()
        -- Return the icon based on your condition
        local iconPath = "Interface\\AddOns\\HappyLog\\Media\\HappyLog.tga"
        return iconPath
    end

    minimapButton = LDB:NewDataObject(addonName, {
        type = "data source",
        text = "HappyLog",
        icon = GetIcon(),
        OnClick = function(clickedFrame, button)
            if button == "RightButton" then
                OpenSettingsPanel()
            elseif button == "LeftButton" then                
                ShowHideFrame()
            end
        end,
        OnTooltipShow = function(tooltip)
            if not tooltip or not tooltip.AddLine then return end
            tooltip:AddLine("HappyLog")
            tooltip:AddLine(" ")
            tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Left Click:|r Toggle HappyLog")
            tooltip:AddLine(GRAY_FONT_COLOR_CODE .. "Right Click:|r HappyLog Settings")
        end,
    })

    LibDBIcon:Register(addonName, minimapButton, minimapButtonDB.profile.minimapButton)
    return minimapButton
end

-- Make the CreateMinimapButton function accessible globally
_G.CreateMinimapButton = CreateMinimapButton
