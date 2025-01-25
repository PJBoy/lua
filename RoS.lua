local displayTileData = 0

function gbromreadshort(address)
    return memory.gbromreadbyte(address + 1) * 0x100 + memory.gbromreadbyte(address)
end

local enemyNames = {
    [0]    = "Tsumari",
    [1]    = "Tsumari",
    [2]    = "Tsumari",
    [3]    = "Tsumari",
    [4]    = "Skreek",
    [5]    = "Skreek",
    [6]    = "Skreek",
    [7]    = "Skreek",
    [8]    = "Skreek projectile",
    [9]    = "Drivel",
    [0xA]  = "Drivel",
    [0xB]  = "Drivel",
    [0xC]  = "Drivel projectile",
    [0xD]  = "Drivel projectile",
    [0xE]  = "Drivel projectile",
    [0xF]  = "Drivel projectile",
    [0x10] = "Drivel projectile",
    [0x11] = "Drivel projectile",
    [0x12] = "Yumbo",
    [0x13] = "Yumbo",
    [0x14] = "Hornoad",
    [0x15] = "Hornoad",
    [0x16] = "Senjoo",
    [0x17] = "Gawron",
    [0x18] = "Gawron",
    [0x19] = "Gawron spawner?",
    [0x1A] = "Gawron spawner?",
    [0x1B] = "Chute leech",
    [0x1C] = "Chute leech",
    [0x1D] = "Chute leech",
    [0x1E] = "",
    [0x1F] = "",
    [0x20] = "Needler",
    [0x21] = "Needler",
    [0x22] = "Needler",
    [0x23] = "Needler",
    [0x24] = "",
    [0x25] = "",
    [0x26] = "",
    [0x27] = "",
    [0x28] = "Skorp",
    [0x29] = "Skorp",
    [0x2A] = "Skorp",
    [0x2B] = "Skorp",
    [0x2C] = "Glow fly",
    [0x2D] = "Glow fly",
    [0x2E] = "Glow fly",
    [0x2F] = "Glow fly",
    [0x30] = "Moheek",
    [0x31] = "Moheek",
    [0x32] = "Moheek",
    [0x33] = "Moheek",
    [0x34] = "Rock icicle",
    [0x35] = "Rock icicle",
    [0x36] = "Rock icicle",
    [0x37] = "Rock icicle",
    [0x38] = "Yumee",
    [0x39] = "Yumee",
    [0x3A] = "Yumee",
    [0x3B] = "Yumee",
    [0x3C] = "Yumee spawner?",
    [0x3D] = "Yumee spawner?",
    [0x3E] = "Octroll",
    [0x3F] = "Octroll",
    [0x40] = "Octroll",
    [0x41] = "Autrack",
    [0x42] = "Autrack",
    [0x43] = "Autrack",
    [0x44] = "Autrack",
    [0x45] = "Autrack projectile",
    [0x46] = "Autoad",
    [0x47] = "Autoad",
    [0x48] = "",
    [0x49] = "",
    [0x4A] = "Wallfire",
    [0x4B] = "Wallfire",
    [0x4C] = "Wallfire",
    [0x4D] = "Wallfire projectile",
    [0x4E] = "Wallfire projectile",
    [0x4F] = "Wallfire projectile",
    [0x50] = "Wallfire projectile",
    [0x51] = "Gunzoo",
    [0x52] = "Gunzoo",
    [0x53] = "Gunzoo",
    [0x54] = "Gunzoo projectile",
    [0x55] = "Gunzoo projectile",
    [0x56] = "Gunzoo projectile",
    [0x57] = "Gunzoo projectile",
    [0x58] = "",
    [0x59] = "Gunzoo projectile",
    [0x5A] = "Gunzoo projectile",
    [0x5B] = "Gunzoo projectile",
    [0x5C] = "Autom",
    [0x5D] = "Autom",
    [0x5E] = "Autom projectile",
    [0x5F] = "Autom projectile",
    [0x60] = "Autom projectile",
    [0x61] = "Autom projectile",
    [0x62] = "Autom projectile",
    [0x63] = "Shirk",
    [0x64] = "Shirk",
    [0x65] = "Septogg",
    [0x66] = "Septogg",
    [0x67] = "Moto",
    [0x68] = "Moto",
    [0x69] = "Moto",
    [0x6A] = "Halzyn",
    [0x6B] = "Ramulken",
    [0x6C] = "Ramulken",
    [0x6D] = "",
    [0x6E] = "",
    [0x6F] = "",
    [0x70] = "",
    [0x71] = "",
    [0x72] = "Proboscum",
    [0x73] = "Proboscum",
    [0x74] = "Proboscum",
    [0x75] = "Missile block",
    [0x76] = "Arachnus",
    [0x77] = "Arachnus",
    [0x78] = "Arachnus",
    [0x79] = "Arachnus",
    [0x7A] = "Arachnus",
    [0x7B] = "Arachnus projectile",
    [0x7C] = "Arachnus projectile",
    [0x7D] = "",
    [0x7E] = "",
    [0x7F] = "",
    [0x80] = "Plasma beam orb",
    [0x81] = "Plasma beam",
    [0x82] = "Ice beam orb",
    [0x83] = "Ice beam",
    [0x84] = "Wave beam orb",
    [0x85] = "Wave beam",
    [0x86] = "Spazer beam orb",
    [0x87] = "Spazer beam",
    [0x88] = "Bombs orb",
    [0x89] = "Bombs",
    [0x8A] = "Screw attack orb",
    [0x8B] = "Screw attack",
    [0x8C] = "Varia suit orb",
    [0x8D] = "Varia suit",
    [0x8E] = "Hi-jump boots orb",
    [0x8F] = "Hi-jump boots",
    [0x90] = "Space jump orb",
    [0x91] = "Space jump",
    [0x92] = "",
    [0x93] = "Spider ball",
    [0x94] = "",
    [0x95] = "Spring ball",
    [0x96] = "",
    [0x97] = "Energy tank",
    [0x98] = "",
    [0x99] = "Missile tank",
    [0x9A] = "Blob thrower?",
    [0x9B] = "Energy refill",
    [0x9C] = "Arachnus orb",
    [0x9D] = "Missile refill",
    [0x9E] = "Blob throw projectile",
    [0x9F] = "Blob throw projectile",
    [0xA0] = "Metroid",
    [0xA1] = "Metroid hatching",
    [0xA2] = "",
    [0xA3] = "Alpha metroid",
    [0xA4] = "Alpha metroid",
    [0xA5] = "Baby metroid egg",
    [0xA6] = "Baby metroid egg",
    [0xA7] = "Baby metroid egg",
    [0xA8] = "Baby metroid",
    [0xA9] = "Baby metroid",
    [0xAA] = "",
    [0xAB] = "",
    [0xAC] = "",
    [0xAD] = "Gamma metroid",
    [0xAE] = "Gamma metroid projectile",
    [0xAF] = "Gamma metroid projectile",
    [0xB0] = "Gamma metroid",
    [0xB1] = "",
    [0xB2] = "Gamma metroid shell",
    [0xB3] = "Zeta metroid hatching",
    [0xB4] = "Zeta metroid",
    [0xB5] = "Zeta metroid",
    [0xB6] = "Zeta metroid",
    [0xB7] = "Zeta metroid",
    [0xB8] = "Zeta metroid",
    [0xB9] = "Zeta metroid",
    [0xBA] = "Zeta metroid",
    [0xBB] = "Zeta metroid",
    [0xBC] = "Zeta metroid",
    [0xBD] = "Zeta metroid",
    [0xBE] = "Zeta metroid projectile",
    [0xBF] = "Omega metroid",
    [0xC0] = "Omega metroid",
    [0xC1] = "Omega metroid",
    [0xC2] = "Omega metroid",
    [0xC3] = "Omega metroid",
    [0xC4] = "Omega metroid",
    [0xC5] = "Omega metroid",
    [0xC6] = "Omega metroid projectile",
    [0xC7] = "Omega metroid projectile",
    [0xC8] = "Omega metroid projectile",
    [0xC9] = "Omega metroid projectile",
    [0xCA] = "Omega metroid projectile",
    [0xCB] = "Omega metroid projectile",
    [0xCC] = "Omega metroid projectile",
    [0xCD] = "",
    [0xCE] = "Metroid",
    [0xCF] = "Metroid",
    [0xD0] = "Flitt",
    [0xD1] = "Flitt",
    [0xD2] = "",
    [0xD3] = "Gravitt",
    [0xD4] = "Gravitt",
    [0xD5] = "Gravitt",
    [0xD6] = "Gravitt",
    [0xD7] = "Gravitt",
    [0xD8] = "Gullugg",
    [0xD9] = "Gullugg",
    [0xDA] = "Gullugg",
    [0xDB] = "Baby metroid egg preview",
    [0xDC] = "",
    [0xDD] = "",
    [0xDE] = "",
    [0xDF] = "",
    [0xE0] = "Small health drop",
    [0xE1] = "Small health drop",
    [0xE2] = "Metroid death / missile door / screw attack explosion",
    [0xE3] = "Metroid death / missile door / screw attack explosion",
    [0xE4] = "Metroid death / missile door / screw attack explosion",
    [0xE5] = "Metroid death / missile door / screw attack explosion",
    [0xE6] = "Metroid death / missile door / screw attack explosion",
    [0xE7] = "Metroid death / missile door / screw attack explosion",
    [0xE8] = "Enemy death explosion",
    [0xE9] = "Enemy death explosion",
    [0xEA] = "Enemy death explosion",
    [0xEB] = "Enemy death explosion extra",
    [0xEC] = "Big energy drop",
    [0xED] = "Big energy drop",
    [0xEE] = "Missile drop",
    [0xEF] = "Missile drop",
    [0xF0] = "Metroid Queen",
    [0xF1] = "Metroid Queen",
    [0xF2] = "Metroid Queen projectile",
    [0xF3] = "Metroid Queen",
    [0xF4] = "",
    [0xF5] = "Metroid Queen",
    [0xF6] = "Metroid Queen",
    [0xF7] = "Metroid Queen",
    [0xF8] = "",
    [0xF9] = "",
    [0xFA] = "",
    [0xFB] = "",
    [0xFC] = "",
    [0xFD] = "Nothing - flitt",
    [0xFE] = ""
}

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
                    --gui.text(tileX, tileY, string.format("%02X", clip), "orange")
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
            
            local enemyName = enemyNames[spriteId] or ""

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
            --gui.text(left, bottom, string.format('%X: %X\n   %d', i, spriteId, health), 'white')
            gui.text(left, bottom, string.format('%X: %X\n%s', i, spriteId, enemyName), 'white')
            
            if enemyName == "" and left > 0 and right < 160 - 8 and top > 0 and bottom < 144 - 8 then
                emu.pause()
            end
        end
    end

    -- Samus
    do
        -- Using Samus' position on screen
        local yPosition = memory.readbyte(0xD03B) - 16
        local xPosition = memory.readbyte(0xD03C) - 8
        local pose = AND(memory.readbyte(0xD020), 0x7F)
        local top    = yPosition + memory.gbromreadbytesigned(0x369B + pose)
        local bottom = yPosition + 16
        local left   = xPosition - 8
        local right  = xPosition + 8

        gui.box(left, top, right, bottom, 'clear', 'cyan')
        
        -- Using Samus' absolute position
    --[[
        local cameraX, cameraY = memory.readshort(0xFFCA), memory.readshort(0xFFC8)
        yPosition = memory.readshort(0xFFC0) - cameraY + 0x62 - 16
        xPosition = memory.readshort(0xFFC2) - cameraX + 0x60 - 8
        top    = yPosition + memory.gbromreadbytesigned(0x369B + pose)
        bottom = yPosition + 15
        left   = xPosition - 7
        right  = xPosition + 7
        
        gui.box(left, top, right, bottom, 'clear', 'green')
    --]]
    end

    -- Show solid thresholds
    --gui.text(0, 0, string.format("Samus: %02X\nEnemy: %02X\nProjectile: %02X", samusSolidThreshold, enemySolidThreshold, projectileSolidThreshold), "cyan")
	vba.frameadvance()
end