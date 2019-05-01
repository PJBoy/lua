displayTileData = 0

function gbromreadshort(address)
    return memory.gbromreadbyte(address + 1) * 0x100 + memory.gbromreadbyte(address)
end

while true do
    local cameraX, cameraY = memory.readbyte(0xC206), memory.readbyte(0xC205)

    local width = 32

    local samusSolidThreshold = memory.readbyte(0xD056)
    local enemySolidThreshold = memory.readbyte(0xD069)
    local projectileSolidThreshold = memory.readbyte(0xD08A)
    local maxSolidThreshold = math.max(samusSolidThreshold, enemySolidThreshold, projectileSolidThreshold)
    local minSolidThreshold = math.min(samusSolidThreshold, enemySolidThreshold, projectileSolidThreshold)

    for y=0,18 do
        for x=0,20 do
            tileX, tileY = x*8 - AND(cameraX, 7), y*8 - AND(cameraY, 7)

            local tilemapValue = memory.readbyte(0x9800 + SHIFT(AND(cameraY + y * 8, 0xFF), 3) * width + SHIFT(AND(cameraX + x * 8, 0xFF), 3))
            local clip = memory.readbyte(0xDC00 + tilemapValue)
            if tilemapValue < maxSolidThreshold then
                if tilemapValue < 4 or clip ~= 0 and AND(clip, 0xF9) == clip then
                    gui.box(tileX, tileY, tileX + 7, tileY + 7, "clear", "orange")
                    gui.text(tileX, tileY, string.format("%02X", clip), "orange")
                elseif clip ~= 0 then
                    gui.box(tileX, tileY, tileX + 7, tileY + 7, "clear", "purple")
                    gui.text(tileX, tileY, string.format("%02X", clip), "purple")
                elseif tilemapValue >= minSolidThreshold then
                    gui.box(tileX, tileY, tileX + 7, tileY + 7, "clear", "yellow")
                    gui.text(tileX, tileY, string.format("%02X", tilemapValue), "yellow")
                else
                    gui.box(tileX, tileY, tileX + 7, tileY + 7, "clear", "red")
                end
            elseif clip ~= 0 then
                if AND(clip, 0xF9) == clip then
                    gui.text(tileX, tileY, string.format("%02X", clip), "orange")
                else
                    gui.text(tileX, tileY, string.format("%02X", clip), "purple")
                end
            end
            if displayTileData ~= 0 and tilemapValue ~= 0xFF then
                gui.text(tileX, tileY, string.format("%02X", tilemapValue), "red")
            end
        end
    end

    -- Enemies
    for i=0,15 do
        local p_enemy = 0xC600 + i * 0x20
        if memory.readbyte(p_enemy) == 0 then
            local yPosition = memory.readbyte(p_enemy + 1) - 16
            local xPosition = memory.readbyte(p_enemy + 2) - 8
            local spriteId  = memory.readbyte(p_enemy + 3)
            local health    = memory.readbyte(p_enemy + 0xC)

            local p_hitbox = gbromreadshort(0xE839 + spriteId * 2) + 0x8000
            local topOffset    = memory.gbromreadbytesigned(p_hitbox)
            local bottomOffset = memory.gbromreadbytesigned(p_hitbox + 1)
            local leftOffset   = memory.gbromreadbytesigned(p_hitbox + 2)
            local rightOffset  = memory.gbromreadbytesigned(p_hitbox + 3)

            local top    = yPosition + topOffset
            local bottom = yPosition + bottomOffset
            local left   = xPosition + leftOffset
            local right  = xPosition + rightOffset

            gui.box(left, top, right, bottom, 'clear', 'white')
            gui.text(left, bottom, string.format('%X: %X\n   %d', i, spriteId, health), 'white')
        end
    end

    -- Samus
    do
        -- Using Samus' position on screen
        local yPosition = memory.readbyte(0xD03B) - 16
        local xPosition = memory.readbyte(0xD03C) - 8
        local top    = yPosition - 16
        local bottom = yPosition + 16
        local left   = xPosition - 8
        local right  = xPosition + 8

        gui.box(left, top, right, bottom, 'clear', 'cyan')
        
        -- Using Samus' absolute position
        local cameraX, cameraY = memory.readshort(0xFFCA), memory.readshort(0xFFC8)
        yPosition = memory.readshort(0xFFC0) - cameraY + 0x62 - 16
        xPosition = memory.readshort(0xFFC2) - cameraX + 0x60 - 8
        top    = yPosition - 15
        bottom = yPosition + 15
        left   = xPosition - 7
        right  = xPosition + 7
        
        gui.box(left, top, right, bottom, 'clear', 'green')
    end

    -- Show solid thresholds
    --gui.text(0, 0, string.format("Samus: %02X\nEnemy: %02X\nProjectile: %02X", samusSolidThreshold, enemySolidThreshold, projectileSolidThreshold), "cyan")
	vba.frameadvance()
end