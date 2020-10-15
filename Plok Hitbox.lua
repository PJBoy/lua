-- Patch some functions for cross-emu compatibility
emuId_bizhawk = 0
emuId_snes9x  = 1
emuId_lsnes   = 2

if memory.usememorydomain then
    emuId = emuId_bizhawk
elseif memory.readshort then
    emuId = emuId_snes9x
else
    emuId = emuId_lsnes
end

if emuId == emuId_lsnes then
    rshift = bit.lrshift
else
    rshift = bit.rshift
end

-- Converts from SNES address model to flat address model (for ROM access)
function snes2pc(p)
    return bit.band(rshift(p, 1), 0x3F8000) + bit.band(p, 0x7FFF)
end

-- Define memory access functions
if emuId == emuId_bizhawk then
    function makeMemoryReader(f)
        return function(p)
            if p < 0x800000 then
                return f(bit.band(p, 0x1FFFF), "WRAM")
            else
                return f(snes2pc(p), "CARTROM")
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p < 0x800000 then
                return f(bit.band(p, 0x1FFFF), v, "WRAM")
            else
                print(string.format('Error: trying to write to ROM address %X', p))
                -- Writing to ROM in Bizhawk doesn't actually work, but hoping it might one day...
                return f(snes2pc(p), v, "CARTROM")
            end
        end
    end

    read_u8      = makeMemoryReader(memory.read_u8)
    read_u16_le  = makeMemoryReader(memory.read_u16_le)
    read_s8      = makeMemoryReader(memory.read_s8)
    read_s16_le  = makeMemoryReader(memory.read_s16_le)
    write_u8     = makeMemoryWriter(memory.write_u8)
    write_u16_le = makeMemoryWriter(memory.write_u16_le)
    
    gui.drawBox  = gui.drawBox or function(x0, y0, x1, y1, fg, bg) gui.box(x0, y0, x1, y1, bg, fg) end
    gui.drawLine = gui.drawLine or gui.line
    gui.drawText = gui.pixelText or gui.text
elseif emuId == emuId_snes9x then
    read_u8      = memory.readbyte
    read_u16_le  = memory.readshort
    read_s8      = memory.readbytesigned
    read_s16_le  = memory.readshortsigned
    write_u8     = memory.writebyte
    write_u16_le = memory.writeshort
    
    gui.drawBox  = function(x0, y0, x1, y1, fg, bg) gui.box(x0, y0, x1, y1, bg, fg) end
    gui.drawLine = gui.line
    gui.drawText = gui.text
else -- emuId == lsnes
    function makeMemoryReader(f)
        return function(p)
            if p < 0x800000 then
                return f(p)
            else
                return f("ROM", snes2pc(p))
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p < 0x800000 then
                return f(p, v)
            else
                print(string.format('Error: trying to write to ROM address %X', p))
            end
        end
    end
    
    read_u8      = makeMemoryReader(memory.readbyte)
    read_u16_le  = makeMemoryReader(memory.readword)
    read_s8      = makeMemoryReader(memory.readsbyte)
    read_s16_le  = makeMemoryReader(memory.readsword)
    write_u8     = makeMemoryWriter(memory.writebyte)
    write_u16_le = makeMemoryWriter(memory.writeword)
    
    function decodeColour(colour)
        if colour == "red" then
            return 0xFF0000
        elseif colour == "orange" then
            return 0x808000
        elseif colour == "white" then
            return 0xFFFFFF
        elseif colour == "black" then
            return 0x000000
        elseif colour == "green" then
            return 0x00FF00
        elseif colour == "purple" then
            return 0xFF00FF
        elseif colour == "cyan" then
            return 0x00FFFF
        elseif colour == "blue" then
            return 0x0000FF
        elseif colour == "clear" then
            return 0xFF000000
        else
            if type(colour) == "string" then
                print(string.format("Colour = %s", colour))
            end
            return bit.band(colour, 0xFFFFFF)
        end
    end
    
    gui.drawBox = function(x0, y0, x1, y1, fg, bg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x0, x1 = math.min(x0, x1), math.max(x0, x1)
        y0, y1 = math.min(y0, y1), math.max(y0, y1)
        x0 = math.floor(x0 * s_x)
        y0 = math.floor(y0 * s_y)
        x1 = math.floor(x1 * s_x)
        y1 = math.floor(y1 * s_y)
        gui.rectangle(x0, y0, x1 - x0, y1 - y0, 1, decodeColour(fg), decodeColour(bg))
    end
    
    gui.drawLine = function(x0, y0, x1, y1, fg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x0 = math.floor(x0 * s_x)
        y0 = math.floor(y0 * s_y)
        x1 = math.floor(x1 * s_x)
        y1 = math.floor(y1 * s_y)
        gui.line(x0, y0, x1, y1, decodeColour(fg))
    end
    
    gui.drawText = function(x, y, text, fg, bg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x = math.floor(x * s_x)
        y = math.floor(y * s_y)
        gui.text(x, y, text, decodeColour(fg), decodeColour(bg))
    end
end


-- Globals
debugFlag = 1 -- Enables displaying block data inside block hitboxes
transparency = 0xFF -- 0xFF is opaque, 0 is invisible

-- Add padding borders in BizHawk (highly resource intensive)
xExtra = 0
yExtra = 0
if emuId == emuId_bizhawk then
    --xExtra = 256
    --yExtra = 224
    client.SetGameExtraPadding(xExtra, yExtra, xExtra, yExtra)
end

xExtraBlocks = rshift(xExtra, 4)
yExtraBlocks = rshift(yExtra, 4)

-- Adjust drawing to account for the borders
function drawText(x, y, text, fg, bg)
    gui.drawText(x + xExtra, y + yExtra, text, fg, bg or "clear")
end

function drawBox(x0, y0, x1, y1, fg, bg)
    gui.drawBox(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg + transparency, bg or "clear")
end

function drawLine(x0, y0, x1, y1, fg)
    gui.drawLine(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg + transparency)
end


function isValidLevelData()
    return true
end

function displayScrollBoundaries(cameraX, cameraY)
    for i=0,1 + xExtra * 2 / 256 do
        local x = 256 + xExtra - i * 256 - bit.band(cameraX, 0xFF)
        drawLine(x, -yExtra, x, 223 + yExtra, 0xFFFFFF00)
    end
    for i=0,1 + yExtra * 2 / 256 do
        local y = 256 + yExtra - i * 256 - bit.band(cameraY, 0xFF)
        drawLine(-xExtra, y, 255 + xExtra, y, 0xFFFFFF00)
    end
end

function displayBlocks(cameraX, cameraY, roomWidth)
    for y = -yExtraBlocks,14 + yExtraBlocks do
        for x = -xExtraBlocks,16 + xExtraBlocks do
            -- Align block outlines graphically
            local blockX = x * 16 - bit.band(cameraX, 0xF)
            local blockY = y * 16 - bit.band(cameraY, 0xF)

            -- Blocks are 16x16 px², using a right shift to avoid dealing with floats
            local blockIndex = rshift(bit.band(cameraY + y * 16, 0xFFFF), 4) * roomWidth
                             + rshift(bit.band(cameraX + x * 16, 0xFFFF), 4)

            -- Get tilemap entry and translate into block data via $7E:2000 table
            local tilemapEntry = read_u16_le(0x7E3000 + blockIndex * 2)
            local blockData = bit.band(tilemapEntry, 0x4000) + read_u16_le(0x7E2000 + rshift(bit.band(tilemapEntry, 0x3F0), 1) + bit.band(tilemapEntry, 0xF))
            
            -- 0x4000 is X flip flag, 0x8000 might be Y flip?
            local blockType = bit.band(blockData, 0xFFF)
            
            if debugFlag ~= 0 then
                -- Show the block type of every block. LSB then MSB. Don't bother for air (or flipped air)
                if bit.band(blockData, 0xBFFF) ~= 0 then
                    drawText(blockX + 4, blockY, string.format("%02X", bit.band(blockData, 0xFF)), "white")
                    drawText(blockX + 4, blockY+8, string.format("%02X", rshift(blockData, 8)), "white")
                end
            end

            -- Draw the block outline depending on its block type
            if blockType == 1 then
                -- Spike?
                drawBox(blockX, blockY, blockX + 15, blockY + 15, 0xFF00FF00)
            elseif blockType == 2 then
                -- Solid block
                drawBox(blockX, blockY, blockX + 15, blockY + 15, 0xFF000000)
            elseif blockType >= 3 then
                -- Slope
                local flipX = 1
                if bit.band(tilemapEntry, 0x4000) ~= 0 then
                    flipX = -1
                    blockX = blockX + 15
                end

                local slopeType = blockType - 3
                local p_slopeDefinition = 0x83E964 + slopeType * 16 * 2
                for xx = 0,14 do
                    local yy_from = read_s16_le(p_slopeDefinition + xx * 2)
                    local yy_to = read_s16_le(p_slopeDefinition + xx * 2 + 2)
                    if yy_from ~= -1 and yy_from ~= 0x11 and yy_to ~= -1 and yy_to ~= 0x11 then
                        drawLine(blockX + xx * flipX, blockY + yy_from, blockX + (xx + 1) * flipX, blockY + yy_to, 0x00FF0000)
                    end
                end
            end
        end
    end
end

function displayPlokHitbox(cameraX, cameraY, plokXPosition, plokYPosition)
    plokXRadius = 0x0
    plokYRadius = 0x10
    left   = plokXPosition - plokXRadius - cameraX
    top    = plokYPosition - plokYRadius - cameraY
    right  = plokXPosition + plokXRadius - cameraX
    bottom = plokYPosition + plokYRadius - cameraY
    
    -- Draw plok's hitbox
    drawBox(left, top, right, bottom, 0x00FFFF00)
end

-- Finally, the main loop
function on_paint()
    if not isValidLevelData() then
        return
    end
    
    local plokXPosition = read_u16_le(0x7E0426)
    local plokYPosition = read_u16_le(0x7E0428) + 0x10
    
    -- Co-ordinates of the top-left of the screen
    local cameraX = read_u16_le(0x7E006A)
    local cameraY = read_u16_le(0x7E006C)
    
    -- Width of the room in blocks
    local roomWidth = read_u16_le(0x7E008A)

    --displayScrollBoundaries(cameraX, cameraY)
    displayBlocks(cameraX + 0x20, cameraY + 0x20, roomWidth)
    displayPlokHitbox(cameraX, cameraY, plokXPosition, plokYPosition)
end

if emuId ~= emuId_lsnes then
    while true do
        on_paint();
        emu.frameadvance()
    end
end
