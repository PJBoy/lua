xemu = require("cross emu gba")

if console and console.clear then
    console.clear()
elseif print then
    print("\n\n\n\n\n\n\n\n")
    print("\n\n\n\n\n\n\n\n")
end

if gui and gui.clearGraphics then
    gui.clearGraphics()
elseif emu and emu.clearScreen then
    emu.clearScreen()
end

-- Globals
debugControlsEnabled = true
blockInfoFlag = 0
logFlag = 1

DisplayEnemyData = 0
DisplayRoomBoxes = 1
DisplaySamusBox = 1
DisplayProjectileBoxes = 1
DisplayEnemyBoxes = 1
EnemyHAdjust = 0
EnemyVAdjust = 0
AVISkipDoorTransitions = 0
AVIFullMapView = 0

-- Colour constants
colour_opacity = 0xFF

colour_slope        = 0x00FF0000 + colour_opacity
colour_solidBlock   = 0xFF000000 + colour_opacity
colour_specialBlock = 0x0000FF00 + colour_opacity
colour_doorcap      = 0xFF800000 + colour_opacity
colour_errorBlock   = 0x8000FF00 + colour_opacity

colour_scroll_red   = 0xFF000000 + xemu.rshift(colour_opacity, 1)
colour_scroll_blue  = 0x0000FF00 + xemu.rshift(colour_opacity, 1)
colour_scroll_green = 0x00FF0000 + xemu.rshift(colour_opacity, 1)

colour_enemy           = 0xFFFFFF00 + colour_opacity
colour_spriteObject    = 0xFF800000 + colour_opacity
colour_enemyProjectile = 0x00FF0000 + colour_opacity
colour_powerBomb       = 0xFFFFFF00 + colour_opacity
colour_projectile      = 0xFFFF0000 + colour_opacity
colour_samus           = 0x00FFFF00 + colour_opacity
colour_armCannon       = 0x00FF0000 + colour_opacity
colour_camera          = 0x80808000 + colour_opacity

-- Add padding borders in BizHawk (highly resource intensive)
xExtra = 0
yExtra = 0
if xemu.emuId == xemu.emuId_bizhawk then
    --xExtra = 256
    --yExtra = 224
    client.SetGameExtraPadding(xExtra, yExtra, xExtra, yExtra)
end

xExtraBlocks = xemu.rshift(xExtra, 4)
yExtraBlocks = xemu.rshift(yExtra, 4)

xExtraScrolls = xemu.rshift(xExtraBlocks, 4)
yExtraScrolls = xemu.rshift(yExtraBlocks, 4)

-- Adjust drawing to account for the borders
function drawText(x, y, text, fg, bg)
    xemu.drawText(x + xExtra, y + yExtra, text, fg, bg or "black")
end

function drawPixel(x, y, fg, bg)
    xemu.drawPixel(x + xExtra, y + yExtra, fg)
end

function drawBox(x0, y0, x1, y1, fg, bg)
    xemu.drawBox(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg, bg or "clear")
end

function drawLine(x0, y0, x1, y1, fg)
    xemu.drawLine(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg)
end

function drawRightTriangle(x0, y0, x1, y1, fg)
    drawLine(x0, y0, x1, y1, fg)
    drawLine(x0, y0, x1, y0, fg)
    drawLine(x1, y0, x1, y1, fg)
end


-- Draw standard block outline
function standardOutline(colour)
    return function(blockX, blockY)
        drawBox(blockX, blockY, blockX + 0xF, blockY + 0xF, colour, "clear")
    end
end

-- Block drawing functions
outline = {
    -- Air
    [0x00] = function(blockX, blockY) end,
    
    -- Normal block
    [0x01] = standardOutline(colour_solidBlock),
         
     -- 45° down-right slope
    [0x02] = function(blockX, blockY) drawRightTriangle(blockX + 0xF, blockY + 0xF, blockX, blockY, colour_slope) end,
         
     -- 45° down-left slope
    [0x03] = function(blockX, blockY) drawRightTriangle(blockX, blockY + 0xF, blockX + 0xF, blockY, colour_slope) end,
         
     -- Higher 22.5° down-right slope
    [0x04] = function(blockX, blockY)
        xemu.drawLine(blockX, blockY, blockX + 0xF, blockY + 7, colour_slope)
        xemu.drawLine(blockX, blockY + 0xF, blockX + 0xF, blockY + 0xF, colour_slope)
        xemu.drawLine(blockX, blockY, blockX, blockY + 0xF, colour_slope)
        xemu.drawLine(blockX + 0xF, blockY + 8, blockX + 0xF, blockY + 0xF, colour_slope)
    end,
    
    -- Lower 22.5° down-right slope
    [0x05] = function(blockX, blockY) drawRightTriangle(blockX + 0xF, blockY + 0xF, blockX, blockY + 8, colour_slope) end,
    
    -- Lower 22.5° down-left slope
    [0x06] = function(blockX, blockY) drawRightTriangle(blockX, blockY + 0xF, blockX + 0xF, blockY + 8, colour_slope) end,
    
    -- Higher 22.5° down-left slope
    [0x07] = function(blockX, blockY)
        xemu.drawLine(blockX, blockY + 7, blockX + 0xF, blockY, colour_slope)
        xemu.drawLine(blockX, blockY + 0xF, blockX + 0xF, blockY + 0xF, colour_slope)
        xemu.drawLine(blockX + 0xF, blockY, blockX + 0xF, blockY + 0xF, colour_slope)
        xemu.drawLine(blockX, blockY + 8, blockX, blockY + 0xF, colour_slope)
    end,

    -- Transition blocks
    [0x09] = function(blockX, blockY) end,
    
    -- Items
    [0x0A] = standardOutline(colour_specialBlock),
    
    -- Door blocks
    [0x0B] = standardOutline(colour_doorcap),
}


function handleDebugControls()
    local input = xemu.read_u16_le(0x30011E8)
    local changedInput = xemu.read_u16_le(0x30011EC)

    if xemu.and_(input, xemu.button_select) == 0 then
        return
    end

    -- Show the clipdata and BTS of every block on screen
    blockInfoFlag = xemu.xor(blockInfoFlag, xemu.and_(changedInput, xemu.button_A))
end

function displayBlocks(cameraX, cameraY)
    local roomWidth = xemu.read_u16_le(0x30000A0)
    for y = -yExtraBlocks, 10 + yExtraBlocks do
        for x = -xExtraBlocks, 15 + xExtraBlocks do
            -- Align block outlines graphically
            local blockX = x * 0x10 - xemu.and_(cameraX, 0xF)
            local blockY = y * 0x10 - xemu.and_(cameraY, 0xF)

            -- Blocks are 16x16 px², using a right shift to avoid dealing with floats
            local blockIndex = xemu.rshift(cameraY + y * 0x10, 4) * roomWidth
                             + xemu.rshift(cameraX + x * 0x10, 4)

            local blockClip = xemu.read_u16_le(0x2026000 + blockIndex * 2)
            if blockClip < 0x8000 then
                if blockInfoFlag ~= 0 then
                    xemu.drawText(blockX + 4, blockY + 4, string.format("%02X", blockClip), "red")
                end
                blockType = xemu.read_u8(0x83F0834 + blockClip)
            else
                blockClip = xemu.and_(blockClip, 0x7FFF)
                blockType = xemu.read_u8(0x83BF5C0 + blockType)
                if blockInfoFlag ~= 0 then
                    xemu.drawText(blockX + 4, blockY + 4, string.format("%02X", blockClip), "orange")
                end
            end

            -- Draw the block outline depending on its block type
            local f = outline[blockType] or standardOutline(colour_errorBlock)
            f(blockX, blockY)
        end
    end
end

function displayEnemyHitboxes(cameraX, cameraY)
    local y = 0

    -- Iterate backwards, I want earlier enemies drawn on top of later ones
    for j=1,0x18 do
        local i = 0x18 - j
        local p_enemyData = 0x3000140 + i * 0x38
        if xemu.read_u16_le(p_enemyData) ~= 0 then
            local enemyXPosition = xemu.read_u16_le(p_enemyData + 4)
            local enemyYPosition = xemu.read_u16_le(p_enemyData + 2)
            local top    = xemu.rshift(enemyYPosition + xemu.read_s16_le(p_enemyData + 0xA), 2) - cameraY
            local bottom = xemu.rshift(enemyYPosition + xemu.read_s16_le(p_enemyData + 0xC), 2) - cameraY
            local left   = xemu.rshift(enemyXPosition + xemu.read_s16_le(p_enemyData + 0xE), 2) - cameraX
            local right  = xemu.rshift(enemyXPosition + xemu.read_s16_le(p_enemyData + 0x10), 2) - cameraX

            -- Draw enemy hitbox
            drawBox(left, top, right, bottom, colour_enemy, "clear")

            -- Show enemy index and ID
            local enemyId = xemu.read_u8(p_enemyData + 0x1D)
            drawText(left + 16, top, string.format("%u: %02X", i, enemyId), colour_enemy)

            -- Log enemy index and ID to list in top-right
            if logFlag ~= 0 then
                drawText(208, y, string.format("%u: %04X", i, enemyId), colour_enemy, 0xFF)
                y = y + 8
            end

            -- Show enemy health
            local enemySpawnHealth = xemu.read_u16_le(0x82E4D4C + enemyId * 0xE)
            if enemySpawnHealth ~= 0 then
                local enemyHealth = xemu.read_u16_le(p_enemyData + 0x14)
                drawText(left, top - 16, string.format("%u/%u", enemyHealth, enemySpawnHealth), colour_enemy)
                -- Draw enemy health bar
                if enemyHealth ~= 0 then
                    drawBox(left, top - 8, left + enemyHealth * 32 / enemySpawnHealth, top - 5, colour_enemy, colour_enemy)
                    drawBox(left, top - 8, left + 32, top - 5, colour_enemy, "clear")
                end
            end
        end
    end
end

function displayProjectileHitboxes(cameraX, cameraY)
    for i=0,9 do
        local p_projectile = 0x03000960 + i * 0x20
        if xemu.read_u16_le(p_projectile) ~= 0 then
            local projectileXPosition = xemu.read_u16_le(p_projectile + 0xA)
            local projectileYPosition = xemu.read_u16_le(p_projectile + 8)
            local top    = xemu.rshift(projectileYPosition + xemu.read_s16_le(p_projectile + 0x16), 2) - cameraY
            local bottom = xemu.rshift(projectileYPosition + xemu.read_s16_le(p_projectile + 0x18), 2) - cameraY
            local left   = xemu.rshift(projectileXPosition + xemu.read_s16_le(p_projectile + 0x1A), 2) - cameraX
            local right  = xemu.rshift(projectileXPosition + xemu.read_s16_le(p_projectile + 0x1C), 2) - cameraX

            -- Draw projectile hitbox
            drawBox(left, top, right, bottom, colour_projectile, "clear")
				
            -- Show projectile damage
            local projectileType = xemu.read_u8(p_projectile + 0xF)
            local beams = xemu.read_u8(0x0300131A)
            local projectileDamage
            if projectileType == 4 then -- Uncharged wave/ice beam
                if xemu.and_(beams, 0x10) then
                    projectileDamage = 6 -- Ice beam
                else
                    projectileDamage = 3 -- Wave beam
                end
            elseif projectileType == 9 then -- Charged wave beam
                if xemu.and_(beams, 0x10) then
                    projectileDamage = 12 -- Ice beam
                else
                    projectileDamage = 9 -- Wave beam
                end
            elseif projectileType == 0xF then -- Flare
                if xemu.and_(beams, 0x18) then
                    projectileDamage = 15 -- Wave/Ice
                elseif xemu.and_(beams, 4) then
                    projectileDamage = 12 -- Plasma
                elseif xemu.and_(beams, 2) then
                    projectileDamage = 9 -- Wide
                else
                    projectileDamage = 6 -- Charge
                end
            else
                local normalDamages = {2, 2, 3, 3, nil, nil, 10, 15, 9, nil, 10, 30, 40, 45, 45, nil, 8, 50, 1}
                projectileDamage = normalDamages[projectileType + 1] -- All others
            end
            
            drawText(left, top - 8, projectileDamage, colour_projectile)
            
            -- Show bomb timer
            if projectileType == 0x10 or projectileType == 0x11 then
                local bombTimer = xemu.read_u8(p_projectile + 0x1E)
                drawText(left, top - 16, bombTimer, colour_projectile)
            end
        end
    end
end

function displaySamusHitbox(cameraX, cameraY)
    local samusXPosition = xemu.read_u16_le(0x0300125A)
    local samusYPosition = xemu.read_u16_le(0x0300125C)
    local left   = xemu.rshift(samusXPosition + xemu.read_s16_le(0x03001268), 2) - cameraX
    local top    = xemu.rshift(samusYPosition + xemu.read_s16_le(0x0300126A), 2) - cameraY
    local right  = xemu.rshift(samusXPosition + xemu.read_s16_le(0x0300126C), 2) - cameraX
    local bottom = xemu.rshift(samusYPosition + xemu.read_s16_le(0x0300126E), 2) - cameraY

    -- Draw Samus' hitbox
    drawBox(left, top, right, bottom, colour_samus, "clear")
    
    -- Draw arm cannon point
    drawPixel(xemu.rshift(xemu.read_u16_le(0x3000B82), 2) - cameraX, xemu.rshift(xemu.read_u16_le(0x3000B80), 2) - cameraY, colour_armCannon)

    -- Show current cooldown time
    local cooldown = xemu.read_u16_le(0x0300124E)
    if cooldown ~= 0 then
        drawText(right, (top + bottom) / 2 - 16, cooldown, "green")
    end

    -- Show current beam charge
    local charge = xemu.read_u8(0x03001250)
    if charge ~= 0 then
        drawText(right, (top + bottom) / 2 - 8, charge, "green")
    end

    -- Show recoil/invincibility
    local invincibility = xemu.read_u8(0x03001249)
    if invincibility ~= 0 then
        drawText(right, (top + bottom) / 2, invincibility, colour_samus)
    end

    -- Show shinespark timer
    local shine = xemu.read_u16_le(0x030012DC)
    if shine ~= 0 then
        drawText(right, (top + bottom) / 2 + 8, shine, colour_samus)
    end
end

function main()
    -- Debug controls
    if debugControlsEnabled ~= 0 then
        handleDebugControls()
    end
	
	local cameraX, cameraY = xemu.rshift(xemu.read_u16_le(0x3001228), 2), xemu.rshift(xemu.read_u16_le(0x300122A), 2)
    
    displayBlocks(cameraX, cameraY)
    displayEnemyHitboxes(cameraX, cameraY)
    displaySamusHitbox(cameraX, cameraY)
    displayProjectileHitboxes(cameraX, cameraY)
end

xemu.run(main)
