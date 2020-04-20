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

function snes2pc(p)
    return bit.band(rshift(p, 1), 0x3F8000) + bit.band(p, 0x7FFF)
end

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

function makeReader(p, n, signed, interval)
    -- p: Pointer to WRAM
    -- n: Number of bytes to read
    -- signed: Whether or not to sign extend read values
    -- interval: If specified, size of array entries, where p is the address within the first array entry
    --           Returned reader will have an array index parameter

    if n < 1 or n > 2 then
        error(string.format('Trying to make reader with n = %d', n))
    end

    local unsignedReaders = {
        [1] = read_u8,
        [2] = read_u16_le
    }
    local signedReaders = {
        [1] = read_s8,
        [2] = read_s16_le
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

    if n < 1 or n > 2 then
        error(string.format('Trying to make writer with n = %d', n))
    end

    local writers = {
        [1] = write_u8,
        [2] = write_u16_le
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
    getBg3ScrollX             = makeReader(0x7E00B9, 2),
    setBg3ScrollX             = makeWriter(0x7E00B9, 2),
    getBg3ScrollY             = makeReader(0x7E00BB, 2),
    setBg3ScrollY             = makeWriter(0x7E00BB, 2),
    
    getMode7Flag              = makeReader(0x7E0783, 2),
    getDoorDirection          = makeReader(0x7E0791, 2),
    getRoomPointer            = makeReader(0x7E079B, 2),
    getAreaIndex              = makeReader(0x7E079F, 2),
    getRoomWidth              = makeReader(0x7E07A5, 2),
    getRoomHeight             = makeReader(0x7E07A7, 2),
    getRoomWidthInScrolls     = makeReader(0x7E07A9, 2),
    getRoomHeightInScrolls    = makeReader(0x7E07AB, 2),
    getUpScroller             = makeReader(0x7E07AD, 2),
    getDownScroller           = makeReader(0x7E07AF, 2),
    getDoorListPointer        = makeReader(0x7E07B5, 2),
    
    getLayer1XSubposition     = makeReader(0x7E090F, 2),
    getLayer1XPosition        = makeReader(0x7E0911, 2, true),
    setLayer1XPosition        = makeWriter(0x7E0911, 2),
    getLayer1YSubposition     = makeReader(0x7E0913, 2),
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
    
    getCameraDistanceIndex    = makeReader(0x7E0941, 2),
    
    getGameState              = makeReader(0x7E0998, 2),
    getDoorTransitionFunction = makeReader(0x7E099C, 2),
    
    getGameTimeFrames         = makeReader(0x7E09DA, 2),
    getGameTimeSeconds        = makeReader(0x7E09DC, 2),
    getGameTimeMinutes        = makeReader(0x7E09DE, 2),
    getGameTimeHours          = makeReader(0x7E09E0, 2),
    
    getSamusFacingDirection   = makeReader(0x7E0A1E, 1),
    getSamusMovementType      = makeReader(0x7E0A1F, 1),
    getShinesparkTimer        = makeReader(0x7E0A68, 2),
    getFrozenTimeFlag         = makeReader(0x7E0A78, 2),
    getXrayState              = makeReader(0x7E0A7A, 2),
    
    getSamusXPosition         = makeReader(0x7E0AF6, 2),
    getSamusXPositionSigned   = makeReader(0x7E0AF6, 2, true),
    setSamusXPosition         = makeWriter(0x7E0AF6, 2),
    getSamusXSubposition      = makeReader(0x7E0AF8, 2),
    getSamusYPosition         = makeReader(0x7E0AFA, 2),
    getSamusYPositionSigned   = makeReader(0x7E0AFA, 2, true),
    setSamusYPosition         = makeWriter(0x7E0AFA, 2),
    getSamusYSubposition      = makeReader(0x7E0AFC, 2),
    getSamusXRadius           = makeReader(0x7E0AFE, 2),
    getSamusYRadius           = makeReader(0x7E0B00, 2),
    getIdealLayer1XPosition   = makeReader(0x7E0B0A, 2),
    getIdealLayer1YPosition   = makeReader(0x7E0B0E, 2),
    getSamusPreviousXPosition = makeReader(0x7E0B10, 2),
    getSamusPreviousYPosition = makeReader(0x7E0B14, 2),
    getSamusYSubspeed         = makeReader(0x7E0B2C, 2),
    getSamusYSpeed            = makeReader(0x7E0B2E, 2),
    getSpeedBoosterLevel      = makeReader(0x7E0B3F, 2),
    getSamusXSpeed            = makeReader(0x7E0B42, 2),
    getSamusXSubspeed         = makeReader(0x7E0B44, 2),
    getSamusXMomentum         = makeReader(0x7E0B46, 2),
    getSamusXSubmomentum      = makeReader(0x7E0B48, 2),
    
    getCooldownTimer          = makeReader(0x7E0CCC, 2),
    getChargeCounter          = makeReader(0x7E0CD0, 2),
    getPowerBombXPosition     = makeReader(0x7E0CE2, 2),
    getPowerBombYPosition     = makeReader(0x7E0CE4, 2),
    getPowerBombRadius        = makeReader(0x7E0CEA, 2),
    getPowerBombPreRadius     = makeReader(0x7E0CEC, 2),
    getPowerBombFlag          = makeReader(0x7E0CEE, 2),
    
    getXDistanceSamusMoved    = makeReader(0x7E0DA2, 2),
    getXSubdistanceSamusMoved = makeReader(0x7E0DA4, 2),
    getYDistanceSamusMoved    = makeReader(0x7E0DA6, 2),
    getYSubdistanceSamusMoved = makeReader(0x7E0DA8, 2),
    
    getBlockIndex             = makeReader(0x7E0DC4, 2),
    
    getElevatorState          = makeReader(0x7E0E18, 2),
    
    getNEnemies               = makeReader(0x7E0E4E, 2),
    
    getBossNumber             = makeReader(0x7E179C, 2),
    
    getEarthquakeType         = makeReader(0x7E183E, 2),
    getEarthquakeTimer        = makeReader(0x7E1840, 2),
    
    getInvincibilityTimer     = makeReader(0x7E18A8, 2),
    getRecoilTimer            = makeReader(0x7E18AA, 2),
    
    getHdmaObjectIndex        = makeReader(0x7E18B2, 2),
    
    getFxYPosition            = makeReader(0x7E195E, 2),
    setFxYPosition            = makeWriter(0x7E195E, 2),
    getLavaAcidYPosition      = makeReader(0x7E1962, 2),
    setLavaAcidYPosition      = makeWriter(0x7E1962, 2),

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
    getEnemyId                      = makeReader(0x7E0F78, 2, false, 0x40),
    getEnemyXPosition               = makeReader(0x7E0F7A, 2, false, 0x40),
    getEnemyYPosition               = makeReader(0x7E0F7E, 2, false, 0x40),
    getEnemyXRadius                 = makeReader(0x7E0F82, 2, false, 0x40),
    getEnemyYRadius                 = makeReader(0x7E0F84, 2, false, 0x40),
    getEnemyProperties              = makeReader(0x7E0F86, 2, false, 0x40),
    getEnemyExtraProperties         = makeReader(0x7E0F88, 2, false, 0x40),
    getEnemyAiHandler               = makeReader(0x7E0F8A, 2, false, 0x40),
    getEnemyHealth                  = makeReader(0x7E0F8C, 2, false, 0x40),
    getEnemySpritemap               = makeReader(0x7E0F8E, 2, false, 0x40),
    getEnemyTimer                   = makeReader(0x7E0F90, 2, false, 0x40),
    getEnemyInitialisationParameter = makeReader(0x7E0F92, 2, false, 0x40),
    getEnemyInstructionList         = makeReader(0x7E0F92, 2, false, 0x40),
    getEnemyInstructionTimer        = makeReader(0x7E0F94, 2, false, 0x40),
    getEnemyPaletteIndex            = makeReader(0x7E0F96, 2, false, 0x40),
    getEnemyGraphicsIndex           = makeReader(0x7E0F98, 2, false, 0x40),
    getEnemyLayer                   = makeReader(0x7E0F9A, 2, false, 0x40),
    getEnemyInvincibilityTimer      = makeReader(0x7E0F9C, 2, false, 0x40),
    getEnemyFrozenTimer             = makeReader(0x7E0F9E, 2, false, 0x40),
    getEnemyPlasmaTimer             = makeReader(0x7E0FA0, 2, false, 0x40),
    getEnemyShakeTimer              = makeReader(0x7E0FA2, 2, false, 0x40),
    getEnemyFrameCounter            = makeReader(0x7E0FA4, 2, false, 0x40),
    getEnemyBank                    = makeReader(0x7E0FA6, 1, false, 0x40),
    getEnemyAiVariable0             = makeReader(0x7E0FA8, 2, false, 0x40),
    getEnemyAiVariable1             = makeReader(0x7E0FAA, 2, false, 0x40),
    getEnemyAiVariable2             = makeReader(0x7E0FAC, 2, false, 0x40),
    getEnemyAiVariable3             = makeReader(0x7E0FAE, 2, false, 0x40),
    getEnemyAiVariable4             = makeReader(0x7E0FB0, 2, false, 0x40),
    getEnemyAiVariable5             = makeReader(0x7E0FB2, 2, false, 0x40),
    getEnemyParameter1              = makeReader(0x7E0FB4, 2, false, 0x40),
    getEnemyParameter2              = makeReader(0x7E0FB6, 2, false, 0x40),

    -- Enemy projectiles
    getEnemyProjectileId        = makeReader(0x7E1997, 2, false, 2),
    getEnemyProjectileXPosition = makeReader(0x7E1A4B, 2, false, 2),
    getEnemyProjectileYPosition = makeReader(0x7E1A93, 2, false, 2),
    getEnemyProjectileXRadius   = makeReader(0x7E1BB3, 1, false, 2),
    getEnemyProjectileYRadius   = makeReader(0x7E1BB4, 1, false, 2),

    -- PLMs
    getPlmId           = makeReader(0x7E1C37, 2, false, 2),
    getPlmRoomArgument = makeReader(0x7E1DC7, 2, false, 2),

    -- Metatiles
    getMetatileTopLeft     = makeReader(0x7EA000, 2, false, 8),
    getMetatileTopRight    = makeReader(0x7EA002, 2, false, 8),
    getMetatileBottomLeft  = makeReader(0x7EA004, 2, false, 8),
    getMetatileBottomRight = makeReader(0x7EA006, 2, false, 8),

    -- Scroll
    getScroll = makeReader(0x7ECD20, 1, false, 1),

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
