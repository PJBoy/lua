local xemu = require("cross emu")
local sm = require("Super Metroid")

function trim(s)
    return string.match(s, "^%s*(.-)%s*$")
end

function rtrim(s)
    return string.gsub(s, "%s*$", "")
end

function pairsByKeys (t, f)
  local a = {}
  for n in pairs(t) do table.insert(a, n) end
  table.sort(a, f)
  local i = 0 
  local iter = function()
    i = i + 1
    if a[i] == nil then return nil
    else return a[i], t[a[i]]
    end
  end
  return iter
end

-- Globals
local enemyDatabase
local superform
local dropdown_main
local form_main
local i_enemy
local superform_ridley = nil -- I'd rather not declare this variable, but bizhawk doesn't clear the value of globals to nil between script reloads

-- Colour constants
local colour_opacity = 0x80
local colour_enemy = 0xFFFFFF00 + colour_opacity


function isValidLevelData()
    -- The screen refresh should only be done when the game is in a valid state to draw the level data.
    -- Game state 8 is main gameplay, level data is always valid.
    -- Game states 9, Ah and Bh are the various stages of going through a door,
    -- the level data is only invalid when the door transition function is $E36E during game state Bh(?).
    -- Game states Ch..12h are the various stages of pausing and unpausing
    -- the level data is only invalid during game states Eh..10h,
    -- but Dh sets up the BG position for the map
    -- Game state 2Ah is the demo
    local gameState = sm.getGameState()
    local doorTransitionFunction = sm.getDoorTransitionFunction()

    return
           8 <= gameState and gameState < 0xB
        or 0xC <= gameState and gameState < 0xD
        or 0x11 <= gameState and gameState < 0x13
        or 0x2A == gameState
        or gameState == 0xB and doorTransitionFunction ~= 0xE36E
end

function loadEnemyDatabase()
    local readMode_enemy = 0
    local readMode_detail = 1
    local readMode_detailList = 2
    
    local file = io.open("enemy data.txt", "r")
    local text = file:read("*all")
    file:close()
    
    enemyDatabase = {}
    local readMode = readMode_enemy
    local enemyId = 0
    local address = ""
    
    for line in text:gmatch("([^\n]*)\n?") do
        line = trim(line)
        if line ~= "" then
            if readMode == readMode_enemy then
                if line == "{" then
                    readMode = readMode_detail
                else
                    enemyId = tonumber(line, 0x10)
                    enemyDatabase[enemyId] = {}
                end
            elseif readMode == readMode_detail then
                if line == "}" then
                    readMode = readMode_enemy
                elseif line == "{" then
                    readMode = readMode_detailList
                    enemyDatabase[enemyId][address .. "_list"] = {}
                else
                    address = trim(string.match(line, "[^:]+")) -- address or name or width
                    local value = trim(string.match(line, "[^:]+:(.+)"))
                    enemyDatabase[enemyId][address] = value
                end
            elseif readMode == readMode_detailList then
                if line == "}" then
                    readMode = readMode_detail
                else
                    local value = tonumber(trim(string.match(line, "[^:]+")), 0x10)
                    local description = trim(string.match(line, "[^:]+:(.+)"))
                    enemyDatabase[enemyId][address .. "_list"][value] = description
                end
            end
        end
    end
end

function initGui()
    gui.clearGraphics()
    forms.destroyall()

    local super_width = 500
    local super_height = 1050
    
    local labels = {}
    for i = 0, 31 do
        labels[i] = string.format("%02X", i)
    end
    
    local x = 0
    local y = 0
    local width = super_width
    local height = super_height
    local fixedWidth = true
    local boxType = nil
    local multiline = true
    local scrollbars = "both"

    superform = forms.newform(super_width, super_height, "Enemy info")
    
    height = 16
    dropdown_main = forms.dropdown(superform, labels, x, y, width, height)

    y = height + 4
    height = super_height - y
    form_main = forms.textbox(superform, "", width, height, x, y, multiline, fixedWidth, scrollbars)

    i_enemy = 0
end

function updateForm_dropdown(dropdown)
    local i_dropdown_new = tonumber(forms.getproperty(dropdown_main, "SelectedIndex"))
    i_enemy = i_dropdown_new
end

function updateForm_main(form)
    local text_enemyId                 = "ID"
    local text_enemyPositionX          = "X position"
    local text_enemyPositionY          = "Y position"
    local text_enemyRadiusX            = "X radius"
    local text_enemyRadiusY            = "Y radius"
    local text_enemyProperties         = "Properties"
    local text_enemyExtraProperties    = "Extra properties"
    local text_enemyAiHandler          = "AI handler"
    local text_enemyHealth             = "Health"
    local text_p_enemySpritemap        = "Spritemap pointer"
    local text_enemyTimer              = "Timer"
    local text_p_enemyInstructionList  = "Instruction list pointer"
    local text_enemyInstructionTimer   = "Instruction timer"
    local text_i_enemyPalette          = "Palette index"
    local text_i_enemyVramTiles        = "VRAM tiles index"
    local text_enemyLayer              = "Layer"
    local text_enemyFlashTimer         = "Flash timer"
    local text_enemyFrozenTimer        = "Frozen timer"
    local text_enemyInvincibilityTimer = "Invincibility timer"
    local text_enemyShakeTimer         = "Shake timer"
    local text_enemyFrameCounter       = "Frame counter"
    local text_enemyBank               = "Bank"
    local text_enemyAiVariable0        = "$0FA8"
    local text_enemyAiVariable1        = "$0FAA"
    local text_enemyAiVariable2        = "$0FAC"
    local text_enemyAiVariable3        = "$0FAE"
    local text_enemyAiVariable4        = "$0FB0"
    local text_enemyAiVariable5        = "$0FB2"
    local text_enemyParameter1         = "Parameter 1"
    local text_enemyParameter2         = "Parameter 2"
    
    local enemyId = sm.getEnemyId(i_enemy)
    local p_enemyHeader = 0xA00000 + enemyId
    local enemyBank = xemu.read_u8(p_enemyHeader + 0xC)
    
    -- Load any extra enemy database info
    local customEnemyName = ""
    local aiVariable0Description = ""
    local aiVariable1Description = ""
    local aiVariable2Description = ""
    local aiVariable3Description = ""
    local aiVariable4Description = ""
    local aiVariable5Description = ""
    local parameter1Description = ""
    local parameter2Description = ""
    local otherDescriptions = {}
    local width = 25
    if enemyDatabase[enemyId] ~= nil then
        -- Custom enemy name
        customEnemyName = enemyDatabase[enemyId]["name"] or customEnemyName
        
        -- Custom variable label width
        width = enemyDatabase[enemyId]["width"] or width
        
        -- Custom variable names
        for k, v in pairs(enemyDatabase[enemyId]) do
            if k == "0FA8" then
                text_enemyAiVariable0 = enemyDatabase[enemyId]["0FA8"] or text_enemyAiVariable0
                if enemyDatabase[enemyId]["0FA8_list"] ~= nil then
                    aiVariable0Description = enemyDatabase[enemyId]["0FA8_list"][sm.getEnemyAiVariable0(i_enemy)] or ""
                end
            elseif k == "0FAA" then
                text_enemyAiVariable1 = enemyDatabase[enemyId]["0FAA"] or text_enemyAiVariable1
                if enemyDatabase[enemyId]["0FAA_list"] ~= nil then
                    aiVariable1Description = enemyDatabase[enemyId]["0FAA_list"][sm.getEnemyAiVariable1(i_enemy)] or ""
                end
            elseif k == "0FAC" then
                text_enemyAiVariable2 = enemyDatabase[enemyId]["0FAC"] or text_enemyAiVariable2
                if enemyDatabase[enemyId]["0FAC_list"] ~= nil then
                    aiVariable2Description = enemyDatabase[enemyId]["0FAC_list"][sm.getEnemyAiVariable2(i_enemy)] or ""
                end
            elseif k == "0FAE" then
                text_enemyAiVariable3 = enemyDatabase[enemyId]["0FAE"] or text_enemyAiVariable3
                if enemyDatabase[enemyId]["0FAE_list"] ~= nil then
                    aiVariable3Description = enemyDatabase[enemyId]["0FAE_list"][sm.getEnemyAiVariable3(i_enemy)] or ""
                end
            elseif k == "0FB0" then
                text_enemyAiVariable4 = enemyDatabase[enemyId]["0FB0"] or text_enemyAiVariable4
                if enemyDatabase[enemyId]["0FB0_list"] ~= nil then
                    aiVariable4Description = enemyDatabase[enemyId]["0FB0_list"][sm.getEnemyAiVariable4(i_enemy)] or ""
                end
            elseif k == "0FB2" then
                text_enemyAiVariable5 = enemyDatabase[enemyId]["0FB2"] or text_enemyAiVariable5
                if enemyDatabase[enemyId]["0FB2_list"] ~= nil then
                    aiVariable5Description = enemyDatabase[enemyId]["0FB2_list"][sm.getEnemyAiVariable5(i_enemy)] or ""
                end
            elseif k == "0FB4" then
                text_enemyParameter1 = enemyDatabase[enemyId]["0FB4"] or text_enemyParameter1
                if enemyDatabase[enemyId]["0FB4_list"] ~= nil then
                    parameter1Description = enemyDatabase[enemyId]["0FB4_list"][sm.getEnemyParameter1(i_enemy)] or ""
                end
            elseif k == "0FB6" then
                text_enemyParameter2 = enemyDatabase[enemyId]["0FB6"] or text_enemyParameter2
                if enemyDatabase[enemyId]["0FB6_list"] ~= nil then
                    parameter2Description = enemyDatabase[enemyId]["0FB6_list"][sm.getEnemyParameter2(i_enemy)] or ""
                end
            elseif not string.match(k, "_list$") and tonumber(k, 0x10) ~= nil then
                otherDescriptions[k] = {['address'] = v, ['value'] = ""}
                if enemyDatabase[enemyId][k .. "_list"] ~= nil then
                    otherDescriptions[k]['value'] = enemyDatabase[enemyId][k .. "_list"][xemu.read_u16_le(tonumber(k, 0x10) + i_enemy * 0x40)] or ""
                end
            end
        end
    end
    
    text_enemyId                 = string.format("%- 25s %04X",      text_enemyId                 .. ":", sm.getEnemyId(i_enemy))
    text_enemyPositionX          = string.format("%- 25s % 4X.%04X", text_enemyPositionX          .. ":", sm.getEnemyXPosition(i_enemy), sm.getEnemyXSubposition(i_enemy))
    text_enemyPositionY          = string.format("%- 25s % 4X.%04X", text_enemyPositionY          .. ":", sm.getEnemyYPosition(i_enemy), sm.getEnemyYSubposition(i_enemy))
    text_enemyRadiusX            = string.format("%- 25s % 4X",      text_enemyRadiusX            .. ":", sm.getEnemyXRadius(i_enemy))
    text_enemyRadiusY            = string.format("%- 25s % 4X",      text_enemyRadiusY            .. ":", sm.getEnemyYRadius(i_enemy))
    text_enemyProperties         = string.format("%- 25s % 4X",      text_enemyProperties         .. ":", sm.getEnemyProperties(i_enemy))
    text_enemyExtraProperties    = string.format("%- 25s % 4X",      text_enemyExtraProperties    .. ":", sm.getEnemyExtraProperties(i_enemy))
    text_enemyAiHandler          = string.format("%- 25s % 4X",      text_enemyAiHandler          .. ":", sm.getEnemyAiHandler(i_enemy))
    text_enemyHealth             = string.format("%- 25s % 4X",      text_enemyHealth             .. ":", sm.getEnemyHealth(i_enemy))
    text_p_enemySpritemap        = string.format("%- 25s %04X",      text_p_enemySpritemap        .. ":", sm.getEnemySpritemap(i_enemy))
    text_enemyTimer              = string.format("%- 25s % 4X",      text_enemyTimer              .. ":", sm.getEnemyTimer(i_enemy))
    text_p_enemyInstructionList  = string.format("%- 25s %04X",      text_p_enemyInstructionList  .. ":", sm.getEnemyInstructionList(i_enemy))
    text_enemyInstructionTimer   = string.format("%- 25s % 4X",      text_enemyInstructionTimer   .. ":", sm.getEnemyInstructionTimer(i_enemy))
    text_i_enemyPalette          = string.format("%- 25s % 4X",      text_i_enemyPalette          .. ":", sm.getEnemyPaletteIndex(i_enemy))
    text_i_enemyVramTiles        = string.format("%- 25s % 4X",      text_i_enemyVramTiles        .. ":", sm.getEnemyGraphicsIndex(i_enemy))
    text_enemyLayer              = string.format("%- 25s % 4X",      text_enemyLayer              .. ":", sm.getEnemyLayer(i_enemy))
    text_enemyFlashTimer         = string.format("%- 25s % 4X",      text_enemyFlashTimer         .. ":", sm.getEnemyInvincibilityTimer(i_enemy))
    text_enemyFrozenTimer        = string.format("%- 25s % 4X",      text_enemyFrozenTimer        .. ":", sm.getEnemyFrozenTimer(i_enemy))
    text_enemyInvincibilityTimer = string.format("%- 25s % 4X",      text_enemyInvincibilityTimer .. ":", sm.getEnemyPlasmaTimer(i_enemy))
    text_enemyShakeTimer         = string.format("%- 25s % 4X",      text_enemyShakeTimer         .. ":", sm.getEnemyShakeTimer(i_enemy))
    text_enemyFrameCounter       = string.format("%- 25s % 4X",      text_enemyFrameCounter       .. ":", sm.getEnemyFrameCounter(i_enemy))
    text_enemyBank               = string.format("%- 25s % 4X",      text_enemyBank               .. ":", sm.getEnemyBank(i_enemy))
    text_enemyAiVariable0        = string.format("%- 25s % 4X",      text_enemyAiVariable0        .. ":", sm.getEnemyAiVariable0(i_enemy))
    text_enemyAiVariable1        = string.format("%- 25s % 4X",      text_enemyAiVariable1        .. ":", sm.getEnemyAiVariable1(i_enemy))
    text_enemyAiVariable2        = string.format("%- 25s % 4X",      text_enemyAiVariable2        .. ":", sm.getEnemyAiVariable2(i_enemy))
    text_enemyAiVariable3        = string.format("%- 25s % 4X",      text_enemyAiVariable3        .. ":", sm.getEnemyAiVariable3(i_enemy))
    text_enemyAiVariable4        = string.format("%- 25s % 4X",      text_enemyAiVariable4        .. ":", sm.getEnemyAiVariable4(i_enemy))
    text_enemyAiVariable5        = string.format("%- 25s % 4X",      text_enemyAiVariable5        .. ":", sm.getEnemyAiVariable5(i_enemy))
    text_enemyParameter1         = string.format("%- 25s % 4X",      text_enemyParameter1         .. ":", sm.getEnemyParameter1(i_enemy))
    text_enemyParameter2         = string.format("%- 25s % 4X",      text_enemyParameter2         .. ":", sm.getEnemyParameter2(i_enemy))
    
    -- Read debug enemy name
    local p_enemyName = xemu.read_u16_le(p_enemyHeader + 0x3E)
    if p_enemyName ~= 0 then
        p_enemyName = 0xB40000 + p_enemyName
        local enemyName = ""
        for i = 0, 9 do
            enemyName = enemyName .. string.char(xemu.read_u8(p_enemyName + i))
        end
        
        enemyName = rtrim(enemyName)
        
        -- Put before custom enemy name if any
        if customEnemyName ~= "" then
            enemyName = enemyName .. ". " .. customEnemyName
        end
        
        text_enemyId = text_enemyId .. string.format(" (%s)", enemyName)
    elseif customEnemyName ~= "" then
        text_enemyId = string.format("(%s)", customEnemyName)
    end
    
    if aiVariable0Description ~= "" then text_enemyAiVariable0 = text_enemyAiVariable0 .. ". " .. aiVariable0Description end
    if aiVariable1Description ~= "" then text_enemyAiVariable1 = text_enemyAiVariable1 .. ". " .. aiVariable1Description end
    if aiVariable2Description ~= "" then text_enemyAiVariable2 = text_enemyAiVariable2 .. ". " .. aiVariable2Description end
    if aiVariable3Description ~= "" then text_enemyAiVariable3 = text_enemyAiVariable3 .. ". " .. aiVariable3Description end
    if aiVariable4Description ~= "" then text_enemyAiVariable4 = text_enemyAiVariable4 .. ". " .. aiVariable4Description end
    if aiVariable5Description ~= "" then text_enemyAiVariable5 = text_enemyAiVariable5 .. ". " .. aiVariable5Description end
    if parameter1Description  ~= "" then text_enemyParameter1  = text_enemyParameter1  .. ". " .. parameter1Description  end
    if parameter2Description  ~= "" then text_enemyParameter2  = text_enemyParameter2  .. ". " .. parameter2Description  end
    
    local otherText = ""
    for k, v in pairsByKeys(otherDescriptions) do
        local fmt = string.format("%%- %ds %% 4X", width)
        otherText = otherText .. string.format(fmt, v['address'] .. ":", xemu.read_u16_le(tonumber(k, 0x10) + i_enemy * 0x40))
        if v['value'] ~= "" then
            otherText = otherText .. ". " .. v['value']
        end
        
        otherText = otherText .. "\r\n"
    end

    forms.settext(form, ""
        .. string.format("Current enemy index: %X\r\n", i_enemy)
        .. "\n"
        .. text_enemyId                 .. "\r\n"
        .. text_enemyPositionX          .. "\r\n"
        .. text_enemyPositionY          .. "\r\n"
        .. text_enemyRadiusX            .. "\r\n"
        .. text_enemyRadiusY            .. "\r\n"
        .. text_enemyProperties         .. "\r\n"
        .. text_enemyExtraProperties    .. "\r\n"
        .. text_enemyAiHandler          .. "\r\n"
        .. text_enemyHealth             .. "\r\n"
        .. text_p_enemySpritemap        .. "\r\n"
        .. text_enemyTimer              .. "\r\n"
        .. text_p_enemyInstructionList  .. "\r\n"
        .. text_enemyInstructionTimer   .. "\r\n"
        .. text_i_enemyPalette          .. "\r\n"
        .. text_i_enemyVramTiles        .. "\r\n"
        .. text_enemyLayer              .. "\r\n"
        .. text_enemyFlashTimer         .. "\r\n"
        .. text_enemyFrozenTimer        .. "\r\n"
        .. text_enemyInvincibilityTimer .. "\r\n"
        .. text_enemyShakeTimer         .. "\r\n"
        .. text_enemyFrameCounter       .. "\r\n"
        .. text_enemyBank               .. "\r\n"
        .. "\r\n"
        .. text_enemyAiVariable0        .. "\r\n"
        .. text_enemyAiVariable1        .. "\r\n"
        .. text_enemyAiVariable2        .. "\r\n"
        .. text_enemyAiVariable3        .. "\r\n"
        .. text_enemyAiVariable4        .. "\r\n"
        .. text_enemyAiVariable5        .. "\r\n"
        .. text_enemyParameter1         .. "\r\n"
        .. text_enemyParameter2         .. "\r\n"
        .. otherText
    )
    forms.refresh(form)
end

function initGui_ridley()
    local super_width = 600
    local super_height = 200
    
    local x = 0
    local y = 0
    local width = super_width
    local height = super_height
    local fixedWidth = true
    local boxType = nil
    local multiline = true
    local scrollbars = "both"

    superform_ridley = forms.newform(super_width, super_height, "Ridley tail")
    
    form_ridley = forms.label(superform_ridley, "", x, y, width, height, fixedWidth)
end

function updateForm_ridley()
    n_segments = 7

    local text_2020 = "Active flag:        "
    local text_2022 = "Stagger angle:      "
    local text_2024 = "Movement direction: "
    local text_2026 = "Distance:           "
    local text_2028 = "Target distance:    "
    local text_202A = "Angle:              "
    local text_202C = "X position:         "
    local text_202E = "Y position:         "
    local text_2030 = "X offset:           "
    local text_2032 = "Y offset:           "

    local separator = ""
    for i = 0, n_segments - 1 do
        text_2020 = text_2020 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2020 + i * 0x14))
        text_2022 = text_2022 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2022 + i * 0x14))
        text_2024 = text_2024 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2024 + i * 0x14))
        text_2026 = text_2026 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2026 + i * 0x14))
        text_2028 = text_2028 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2028 + i * 0x14))
        text_202A = text_202A .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E202A + i * 0x14))
        text_202C = text_202C .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E202C + i * 0x14))
        text_202E = text_202E .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E202E + i * 0x14))
        text_2030 = text_2030 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2030 + i * 0x14))
        text_2032 = text_2032 .. separator .. string.format("% 4Xh", xemu.read_u16_le(0x7E2032 + i * 0x14))

        separator = " | "
    end
    
    forms.settext(form_ridley, ""
        .. text_2020 .. "\n"
        .. text_2022 .. "\n"
        .. text_2024 .. "\n"
        .. text_2026 .. "\n"
        .. text_2028 .. "\n"
        .. text_202A .. "\n"
        .. text_202C .. "\n"
        .. text_202E .. "\n"
        .. text_2030 .. "\n"
        .. text_2032 .. "\n"
    )
    
    forms.refresh(form_ridley)
end

function displayEnemyHitbox()
    local enemyId = sm.getEnemyId(i_enemy)
    if enemyId ~= 0 then
        local cameraX = sm.getLayer1XPosition()
        local cameraY = sm.getLayer1YPosition()
        local enemyXPosition = sm.getEnemyXPosition(i_enemy)
        local enemyYPosition = sm.getEnemyYPosition(i_enemy)
        local enemyXRadius   = sm.getEnemyXRadius(i_enemy)
        local enemyYRadius   = sm.getEnemyYRadius(i_enemy)
        local left   = enemyXPosition - enemyXRadius - cameraX
        local top    = enemyYPosition - enemyYRadius - cameraY
        local right  = enemyXPosition + enemyXRadius - cameraX
        local bottom = enemyYPosition + enemyYRadius - cameraY

        -- Draw enemy hitbox
        -- If not using extended spritemap format or frozen, draw simple hitbox
        if xemu.and_(sm.getEnemyExtraProperties(i_enemy), 4) == 0 or sm.getEnemyAiHandler(i_enemy) == 4 then
            xemu.drawBox(left, top, right, bottom, colour_enemy, "clear")
        else
            -- Process extended spritemap format
            local p_spritemap = sm.getEnemySpritemap(i_enemy)
            if p_spritemap ~= 0 then
                local bank = xemu.lshift(sm.getEnemyBank(i_enemy), 0x10)
                p_spritemap = bank + p_spritemap
                local n_spritemap = xemu.read_u8(p_spritemap)
                if n_spritemap ~= 0 then
                    for ii=0,n_spritemap-1 do
                        local entryPointer = p_spritemap + 2 + ii*8
                        local entryXOffset     = xemu.read_s16_le(entryPointer)
                        local entryYOffset     = xemu.read_s16_le(entryPointer + 2)
                        local p_entrySpritemap = xemu.read_u16_le(entryPointer + 4)
                        local p_entryHitbox    = xemu.read_u16_le(entryPointer + 6)
                        if p_entryHitbox ~= 0 then
                            p_entryHitbox = bank + p_entryHitbox
                            local n_hitbox = xemu.read_u16_le(p_entryHitbox)
                            if n_hitbox ~= 0 then
                                for iii=0,n_hitbox-1 do
                                    local entryLeft    = xemu.read_s16_le(p_entryHitbox + 2 + iii*12)
                                    local entryTop     = xemu.read_s16_le(p_entryHitbox + 2 + iii*12 + 2)
                                    local entryRight   = xemu.read_s16_le(p_entryHitbox + 2 + iii*12 + 4)
                                    local entryBottom  = xemu.read_s16_le(p_entryHitbox + 2 + iii*12 + 6)
                                    local p_entryTouch = xemu.read_u16_le(p_entryHitbox + 2 + iii*12 + 8)
                                    local p_entryShot  = xemu.read_u16_le(p_entryHitbox + 2 + iii*12 + 0xA)
                                    
                                    xemu.drawBox(
                                        enemyXPosition - cameraX + entryXOffset + entryLeft,
                                        enemyYPosition - cameraY + entryYOffset + entryTop,
                                        enemyXPosition - cameraX + entryXOffset + entryRight,
                                        enemyYPosition - cameraY + entryYOffset + entryBottom,
                                        colour_enemy, "clear"
                                    )
                                    
                                    -- Show enemy shot pointer
                                    --xemu.drawText(
                                    --    enemyXPosition - cameraX + entryXOffset + entryLeft + 1,
                                    --    enemyYPosition - cameraY + entryYOffset + entryTop + 1,
                                    --    string.format("%d: %X", ii, p_entryShot),
                                    --    colour, 0x000000FF
                                    --)
                                end
                            end
                        end
                    end
                end
            end
        end

        -- Show enemy index and ID
        xemu.drawText(left + 16, top, string.format("%u: %04X", i_enemy, enemyId), colour_enemy)
    end
end

function specialEnemyDisplay_ridley(is_norfair)
    local tailColours = {
        [0] = 0xFF000000 + colour_opacity,
        [1] = 0x0091FF00 + colour_opacity,
        [2] = 0xFFDA0000 + colour_opacity,
        [3] = 0x4800FF00 + colour_opacity,
        [4] = 0x48FF0000 + colour_opacity,
        [5] = 0xFF00DA00 + colour_opacity,
        [6] = 0x00FF9100 + colour_opacity
    }
    
    local cameraX = sm.getLayer1XPosition()
    local cameraY = sm.getLayer1YPosition()
    
    -- Draw tail
    local xPosition_prev = sm.getEnemyXPosition(0)
    local yPosition_prev = sm.getEnemyYPosition(0)
    
    for i = 0,6 do
        local xPosition = xemu.read_u16_le(0x7E202C + i*0x14)
        local yPosition = xemu.read_u16_le(0x7E202E + i*0x14)
        xemu.drawLine(
            xPosition_prev - cameraX,
            yPosition_prev - cameraY,
            xPosition - cameraX,
            yPosition - cameraY,
            tailColours[i]
        )
        
        xPosition_prev = xPosition
        yPosition_prev = yPosition
    end
    
    if superform_ridley == nil then
        initGui_ridley()
    end
    
    updateForm_ridley()
end

function specialEnemyDisplay()
    local enemyId = sm.getEnemyId(i_enemy)
    if enemyId == 0xE13F then
        specialEnemyDisplay_ridley(false)
    elseif enemyId == 0xE17F then
        specialEnemyDisplay_ridley(true)
    end
end

function init()
    console.clear()
    initGui()
    loadEnemyDatabase()
end

function main()
    if not isValidLevelData() then
        return
    end

    updateForm_dropdown(dropdown_main)
    updateForm_main(form_main)
    displayEnemyHitbox()
    specialEnemyDisplay()
end

init()
while true do
    main()
    emu.frameadvance()
end
