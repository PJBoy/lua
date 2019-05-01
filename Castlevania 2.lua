debugFlag = 0

outline = {
    -- Air
    [0x00] = function (tileX, tileY)
    end,
    
    -- vertical half block - right
    [0x01] = function (tileX, tileY)
        gui.box(tileX + 8, tileY, tileX + 15, tileY + 15, "clear", "green")
    end,
    
    -- Ceiling decreasing slope
    [0x02] = function (tileX, tileY)
        gui.line(tileX, tileY, tileX + 15, tileY, "green")
        gui.line(tileX + 15, tileY, tileX + 15, tileY + 15, "green")
        gui.line(tileX, tileY, tileX + 15, tileY + 15, "green")
    end,
    
    -- Transition block
    [0x03] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "orange")
    end,
    
    -- Fake block
    [0x05] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "cyan")
    end,
    
    -- Ceiling increasing slope
    [0x08] = function (tileX, tileY)
        gui.line(tileX, tileY, tileX + 15, tileY, "green")
        gui.line(tileX, tileY, tileX, tileY + 15, "green")
        gui.line(tileX, tileY + 15, tileX + 15, tileY, "green")
    end,
    
    -- 
    [0x09] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "purple")
    end,
    
    -- Normal block
    [0x0A] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "red")
    end,
    
    -- Vertical half block - left
    [0x0B] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 7, tileY + 15, "clear", "green")
    end,
    
    -- Transition block
    [0x0C] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "orange")
    end,
    
    -- No idea, like block Bh, but you can fall through the middle
    [0x0D] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "purple")
    end,
    
    -- Like block Dh
    [0x0E] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "purple")
    end,
    
    -- Lava
    [0x0F] = function (tileX, tileY)
        gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "yellow")
    end 
}

while true do
    -- Simon's quest map data is laid out as a quad-buffered 2d 16x15 layout
    -- 0x0520..27  0x0610..17
    -- :        :  :        :
    -- 0x0600..07  0x06F0..F7
    
    -- 0x0528..2F  0x0618..1F
    -- :        :  :        :
    -- 0x0608..0F  0x06F8..FF
    
    -- Each tile is 4 bits, with the upper 4 bits corresponding with the left of the 2 tiles in a byte
    -- Also note that the camera Y position actually jumps from 0x00DF to 0x0100 etc.
    
    -- Camera position in blocks
    local cameraX = memory.readword(0x0053)
    local cameraY = memory.readword(0x0056)
    cameraY = cameraY - SHIFT(cameraY, 8) * 0x20
    
    for y=0,14 do
        for x=0,8 do
            tileX = x * 16 * 2 - AND(cameraX, 0x001F)
            tileY = y * 16 - AND(cameraY, 0x000F) - 3
            
            local blockX = SHIFT(cameraX, 5) + x
            local blockY = SHIFT(cameraY, 4) + y - 1
            
            --if SHIFT(blockY, 4) > SHIFT(cameraY, 8) or AND(blockY, 0xF) >= 0xF then
            --    blockY = blockY + 1
            --end
            
            local tile = 0
            if AND(blockX * 2, 0x1F) >= 0x10 then
                tile = tile + 0xE8
            end
            if blockY >= 15 then
                tile = tile + 0x08
            end
            
            -- get block's tile number
            a = tile + AND(blockX, 0xF) + blockY % 0xF * 0x10
            
            -- clipdata of two blocks
            clipBoth = memory.readbyte(0x0520 + a)
            
            -- clipdata of each block
            clip0 = SHIFT(clipBoth, 4)
            clip1 = AND(clipBoth, 0xF)
            
            -- Process the block's clipdata nibble
            outlinefunction = outline[clip0] or function(tileX, tileY) gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "purple") end
            outlinefunction(tileX, tileY)
            
            outlinefunction = outline[clip1] or function(tileX, tileY) gui.box(tileX, tileY, tileX + 15, tileY + 15, "clear", "purple") end
            outlinefunction(tileX + 16, tileY)
            
            if debugFlag ~= 0 then
                gui.text(tileX + 6, tileY + 4, string.format("%X", a + 0x520), "#FFFF00", "#00000000")
                if clip0 ~= 0 then
                    gui.text(tileX + 4, tileY + 4, string.format("%X", clip0), "#FFFF00", "#00000000")
                end
                if clip1 ~= 0 then
                    gui.text(tileX + 16 + 4, tileY + 4, string.format("%X", clip1), "#FFFF00", "#00000000")
                end
            end
        end
    end
    
    if debugFlag ~= 0 then
        gui.text(0, 0, string.format(
            "Screen X: %04X\nScreen Y: %04X",
            cameraX,
            cameraY
        ), "#00FFFF")
    end
    
    --local Layer1X, Layer2X, Layer2Scroll = memory.readshort(0x7E0911), memory.readshort(0x7E0917), memory.readbyte(0x7E091B)
    --local Should = SHIFT(Layer2Scroll * Layer1X, 8)
    --local Predicted = Should + Should
    --gui.text(0, 0, string.format("Layer 1 X: %04X\nLayer 2 X: %04X\nLayer2Scroll: %02X\nShould: %04X\nPredicted: %04X", Layer1X, Layer2X, Layer2Scroll, Should, Predicted), "#00FFFF")
    emu.frameadvance()
end