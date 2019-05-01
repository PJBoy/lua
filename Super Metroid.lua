-- Also patch some functions for cross-emu compatability (at least between snes9x and BizHawk)
if memory.usememorydomain then
    function snes2pc(p)
        return bit.band(bit.rshift(p, 1), 0x3F8000) + bit.band(p, 0x7FFF)
    end
    
    function makeMemoryReader(f)
        return function(p)
            if p < 0x800000 then
                return f(bit.band(p, 0x1FFFF), "WRAM")
            else
                -- BizHawk bug: having to add $80:0000 for whatever reason
                return f(snes2pc(p) + 0x800000, "CARTROM")
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p < 0x800000 then
                return f(bit.band(p, 0x1FFFF), v, "WRAM")
            else
                -- BizHawk bug: having to add $80:0000 for whatever reason
                -- Writing to ROM in Bizhawk doesn't actually work, but hoping it might one day...
                return f(snes2pc(p) + 0x800000, v, "CARTROM")
            end
        end
    end

    read_u8   = makeMemoryReader(memory.read_u8)
    read_u16  = makeMemoryReader(memory.read_u16_le)
    read_s8   = makeMemoryReader(memory.read_s8)
    read_s16  = makeMemoryReader(memory.read_s16_le)
    write_u8  = makeMemoryWriter(memory.write_u8)
    write_u16 = makeMemoryWriter(memory.write_u16_le)
else
    read_u8   = memory.readbyte
    read_u16  = memory.readshort
    read_s8   = memory.readbytesigned
    read_s16  = memory.readshortsigned
    write_u8  = memory.writebyte
    write_u16 = memory.writeshort
end

gui.drawBox  = gui.drawBox or function(x0, y0, x1, y1, fg, bg) gui.box(x0, y0, x1, y1, bg, fg) end
gui.drawLine = gui.drawLine or gui.line
gui.drawText = gui.pixelText or gui.text

function makeReader(p, n, signed, interval)
    -- p: Pointer to WRAM
    -- n: Number of bytes to read
    -- signed: Whether or not to sign extend read values
    -- interval: If specified, size of array entries, where p is the address within the first array entry
    --           Returned reader will have an array index parameter

    local unsignedReaders = {
        [1] = read_u8,
        [2] = read_u16
    }
    local signedReaders = {
        [1] = read_s8,
        [2] = read_s16
    }

    local reader = unsignedReaders[n]
    if signed then
        reader = signedReaders[n]
    end

    if interval then
        return function(i) return reader(p + i * interval) end
    else
        return function() return reader(p) end
    end
end

function makeWriter(p, n, interval)
    -- p: Pointer to WRAM
    -- n: Number of bytes to write
    -- interval: If specified, size of array entries, where p is the address within the first array entry
    --           Returned writer will have an array index parameter

    local writers = {
        [1] = write_u8,
        [2] = write_u16
    }

    local writer = writers[n]
    if interval then
        return function(i, v) return writer(p + i * interval, v) end
    else
        return function(v) return writer(p, v) end
    end
end

return {
    button_B      = 0x8000,
    button_Y      = 0x4000,
    button_select = 0x2000,
    button_start  = 0x1000,
    button_up     = 0x800,
    button_down   = 0x400,
    button_left   = 0x200,
    button_right  = 0x100,
    button_A      = 0x80,
    button_X      = 0x40,
    button_L      = 0x20,
    button_R      = 0x10,

    getBg1TilemapOptions      = makeReader(0x7E0058, 2),
    getBg2TilemapOptions      = makeReader(0x7E0059, 2),
    getInput                  = makeReader(0x7E008B, 2),
    getChangedInput           = makeReader(0x7E008F, 2),
    getBg1ScrollX             = makeReader(0x7E00B1, 2),
    setBg1ScrollX             = makeWriter(0x7E00B1, 2),
    getBg1ScrollY             = makeReader(0x7E00B3, 2),
    setBg1ScrollY             = makeWriter(0x7E00B3, 2),
    getBg2ScrollX             = makeReader(0x7E00B5, 2),
    setBg2ScrollX             = makeWriter(0x7E00B5, 2),
    getBg2ScrollY             = makeReader(0x7E00B7, 2),
    setBg2ScrollY             = makeWriter(0x7E00B7, 2),
    getMode7Flag              = makeReader(0x7E0783, 2),
    getDoorDirection          = makeReader(0x7E0791, 2),
    getAreaIndex              = makeReader(0x7E079F, 2),
    getRoomWidth              = makeReader(0x7E07A5, 2),
    getRoomHeight             = makeReader(0x7E07A7, 2),
    getUpScroller             = makeReader(0x7E07AD, 2),
    getDownScroller           = makeReader(0x7E07AF, 2),
    getDoorListPointer        = makeReader(0x7E07B5, 2),
    getLayer1XPosition        = makeReader(0x7E0911, 2, true),
    setLayer1XPosition        = makeWriter(0x7E0911, 2),
    getLayer1YPosition        = makeReader(0x7E0915, 2, true),
    setLayer1YPosition        = makeWriter(0x7E0915, 2),
    getLayer2XPosition        = makeReader(0x7E0917, 2, true),
    getLayer2YPosition        = makeReader(0x7E0919, 2, true),
    getLayer2XScroll          = makeReader(0x7E091B, 1),
    getLayer2YScroll          = makeReader(0x7E091C, 1),
    getBg1ScrollXOffset       = makeReader(0x7E091D, 2, true),
    getBg1ScrollYOffset       = makeReader(0x7E091F, 2, true),
    getBg2ScrollXOffset       = makeReader(0x7E0921, 2, true),
    getBg2ScrollYOffset       = makeReader(0x7E0923, 2, true),
    getGameState              = makeReader(0x7E0998, 2),
    getDoorTransitionFunction = makeReader(0x7E099C, 2),
    getGameTimeFrames         = makeReader(0x7E09DA, 2),
    getGameTimeSeconds        = makeReader(0x7E09DC, 2),
    getGameTimeMinutes        = makeReader(0x7E09DE, 2),
    getGameTimeHours          = makeReader(0x7E09E0, 2),
    getShinesparkTimer        = makeReader(0x7E0A68, 2),
    getFrozenTimeFlag         = makeReader(0x7E0A78, 2),
    getSamusXPosition         = makeReader(0x7E0AF6, 2),
    getSamusXPositionSigned   = makeReader(0x7E0AF6, 2, true),
    setSamusXPosition         = makeWriter(0x7E0AF6, 2),
    getSamusYPosition         = makeReader(0x7E0AFA, 2),
    getSamusYPositionSigned   = makeReader(0x7E0AFA, 2, true),
    setSamusYPosition         = makeWriter(0x7E0AFA, 2),
    getSamusXRadius           = makeReader(0x7E0AFE, 2),
    getSamusYRadius           = makeReader(0x7E0B00, 2),
    getSamusYSubspeed         = makeReader(0x7E0B2C, 2),
    getSamusYSpeed            = makeReader(0x7E0B2E, 2),
    getSpeedBoosterLevel      = makeReader(0x7E0B3F, 2),
    getSamusXSubspeed         = makeReader(0x7E0B42, 2),
    getSamusXSpeed            = makeReader(0x7E0B44, 2),
    getSamusXMomentum         = makeReader(0x7E0B46, 2),
    getSamusXSubmomentum      = makeReader(0x7E0B48, 2),
    getCooldownTimer          = makeReader(0x7E0CCC, 2),
    getChargeCounter          = makeReader(0x7E0CD0, 2),
    getPowerBombXPosition     = makeReader(0x7E0CE2, 2),
    getPowerBombYPosition     = makeReader(0x7E0CE4, 2),
    getPowerBombRadius        = makeReader(0x7E0CEA, 2),
    getPowerBombFlag          = makeReader(0x7E0CEE, 2),
    getBlockIndex             = makeReader(0x7E0DC4, 2),
    getElevatorState          = makeReader(0x7E0E18, 2),
    getNEnemies               = makeReader(0x7E0E4E, 2),
    getBossNumber             = makeReader(0x7E179C, 2),
    getEarthquakeType         = makeReader(0x7E183E, 2),
    getEarthquakeTimer        = makeReader(0x7E1840, 2),
    getInvincibilityTimer     = makeReader(0x7E18A8, 2),
    getRecoilTimer            = makeReader(0x7E18AA, 2),
    
    -- OAM
    getOamXLow                = makeReader(0x7E0370, 1, false, 4),
    setOamXLow                = makeWriter(0x7E0370, 1, 4),
    getOamY                   = makeReader(0x7E0371, 1, false, 4),
    setOamY                   = makeWriter(0x7E0371, 1, 4),
    getOamProperties          = makeReader(0x7E0372, 2, false, 4),
    getOamHigh                = makeReader(0x7E0570, 1, false, 1),
    setOamHigh                = makeWriter(0x7E0570, 1, 1),

    -- Projectiles
    getProjectileXPosition = makeReader(0x7E0B64, 2, false, 2),
    getProjectileYPosition = makeReader(0x7E0B78, 2, false, 2),
    getProjectileXRadius   = makeReader(0x7E0BB4, 2, false, 2),
    getProjectileYRadius   = makeReader(0x7E0BC8, 2, false, 2),
    getProjectileType      = makeReader(0x7E0C18, 2, false, 2),
    getProjectileDamage    = makeReader(0x7E0C2C, 2, false, 2),
    getBombTimer           = makeReader(0x7E0C7C, 2, false, 2),

    -- Enemies
    getEnemyId                 = makeReader(0x7E0F78, 2, false, 0x40),
    getEnemyXPosition          = makeReader(0x7E0F7A, 2, false, 0x40),
    getEnemyYPosition          = makeReader(0x7E0F7E, 2, false, 0x40),
    getEnemyXRadius            = makeReader(0x7E0F82, 2, false, 0x40),
    getEnemyYRadius            = makeReader(0x7E0F84, 2, false, 0x40),
    getEnemyProperties         = makeReader(0x7E0F86, 2, false, 0x40),
    getEnemyExtraProperties    = makeReader(0x7E0F88, 2, false, 0x40),
    getEnemyAiHandler          = makeReader(0x7E0F8A, 2, false, 0x40),
    getEnemyHealth             = makeReader(0x7E0F8C, 2, false, 0x40),
    getEnemySpritemap          = makeReader(0x7E0F8E, 2, false, 0x40),
    getEnemyTimer              = makeReader(0x7E0F90, 2, false, 0x40),
    getEnemyInstructionList    = makeReader(0x7E0F92, 2, false, 0x40),
    getEnemyInstructionTimer   = makeReader(0x7E0F94, 2, false, 0x40),
    getEnemyPaletteIndex       = makeReader(0x7E0F96, 2, false, 0x40),
    getEnemyGraphicsIndex      = makeReader(0x7E0F98, 2, false, 0x40),
    getEnemyLayer              = makeReader(0x7E0F9A, 2, false, 0x40),
    getEnemyInvincibilityTimer = makeReader(0x7E0F9C, 2, false, 0x40),
    getEnemyFrozenTimer        = makeReader(0x7E0F9E, 2, false, 0x40),
    getEnemyPlasmaTimer        = makeReader(0x7E0FA0, 2, false, 0x40),
    getEnemyShakeTimer         = makeReader(0x7E0FA2, 2, false, 0x40),
    getEnemyFrameCounter       = makeReader(0x7E0FA4, 2, false, 0x40),
    getEnemyBank               = makeReader(0x7E0FA6, 1, false, 0x40),

    -- Enemy projectiles
    getEnemyProjectileId        = makeReader(0x7E1997, 2, false, 2),
    getEnemyProjectileXPosition = makeReader(0x7E1A4B, 2, false, 2),
    getEnemyProjectileYPosition = makeReader(0x7E1A93, 2, false, 2),
    getEnemyProjectileXRadius   = makeReader(0x7E1BB3, 1, false, 2),
    getEnemyProjectileYRadius   = makeReader(0x7E1BB4, 1, false, 2),

    -- Metatiles
    getMetatileTopLeft     = makeReader(0x7EA000, 2, false, 8),
    getMetatileTopRight    = makeReader(0x7EA002, 2, false, 8),
    getMetatileBottomLeft  = makeReader(0x7EA004, 2, false, 8),
    getMetatileBottomRight = makeReader(0x7EA006, 2, false, 8),
    
    -- Sprite objects
    getSpriteObjectInstructionList = makeReader(0x7EEF78, 2, false, 2),
    getSpriteObjectXPosition       = makeReader(0x7EF0F8, 2, false, 2),
    getSpriteObjectYPosition       = makeReader(0x7EF1F8, 2, false, 2),

    -- Blocks
    getLevelDatum      = makeReader(0x7F0002, 2, false, 2),
    getBts             = makeReader(0x7F6402, 1, false, 1),
    getBtsSigned       = makeReader(0x7F6402, 1, true,  1),
    getBackgroundDatum = makeReader(0x7F9602, 2, false, 2),
}
