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

-- Define memory access functions and patch some functions for cross-emu compatibility
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

    function makeAramReader(f)
        return function(p)
            return f(p, "APURAM")
        end
    end

    read_u8      = makeMemoryReader(memory.read_u8)
    read_u16_le  = makeMemoryReader(memory.read_u16_le)
    read_s8      = makeMemoryReader(memory.read_s8)
    read_s16_le  = makeMemoryReader(memory.read_s16_le)
    write_u8     = makeMemoryWriter(memory.write_u8)
    write_u16_le = makeMemoryWriter(memory.write_u16_le)
    
    read_aram_u8     = makeAramReader(memory.read_u8)
    read_aram_u16_le = makeAramReader(memory.read_u16_le)
    read_aram_s8     = makeAramReader(memory.read_s8)
    read_aram_s16_le = makeAramReader(memory.read_s16_le)

    gui.drawBox  = gui.drawBox or function(x0, y0, x1, y1, fg, bg) gui.box(x0, y0, x1, y1, bg, fg) end
    gui.drawLine = gui.drawLine or gui.line
    gui.drawText = gui.pixelText or gui.text
    gui.register = event.onframestart
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

function makeReader(p, n, is_signed, interval, is_aram)
    -- p: Pointer to WRAM (or ARAM)
    -- n: Number of bytes to read
    -- is_signed: Whether or not to sign extend read values
    -- interval: If specified, size of array entries, where p is the address within the first array entry
    --           Returned reader will have an array index parameter
    -- is_aram: Whether or not to read from ARAM

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
    
    if is_aram then
        unsignedReaders = {
            [1] = read_aram_u8,
            [2] = read_aram_u16_le
        }
        signedReaders = {
            [1] = read_aram_s8,
            [2] = read_aram_s16_le
        }
    end

    local reader = unsignedReaders[n] or function() return 0 end
    if is_signed then
        reader = signedReaders[n] or function() return 0 end
    end

    if interval then
        return function(i) return reader(p + i * interval) end
    else
        return function() return reader(p) end
    end
end

function makeAramReader(p, n, is_signed, interval)
    return makeReader(p, n, is_signed, interval, true)
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
    
    getRunBinding             = makeReader(0x7E09B6, 2),

    getGameTimeFrames         = makeReader(0x7E09DA, 2),
    getGameTimeSeconds        = makeReader(0x7E09DC, 2),
    getGameTimeMinutes        = makeReader(0x7E09DE, 2),
    getGameTimeHours          = makeReader(0x7E09E0, 2),

    getSamusFacingDirection   = makeReader(0x7E0A1E, 1),
    getSamusMovementType      = makeReader(0x7E0A1F, 1),
    getShinesparkTimer        = makeReader(0x7E0A68, 2),
    getFrozenTimeFlag         = makeReader(0x7E0A78, 2),
    getXrayState              = makeReader(0x7E0A7A, 2),
    
    getSamusAnimationFrameTimer = makeReader(0x7E0A94, 2),
    getSamusAnimationFrame      = makeReader(0x7E0A96, 2),

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
    getFxTargetYPosition      = makeReader(0x7E197A, 2),

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
    
    
    -- ARAM --
    --getAram_currentSound1 = makeAramReader(0x0392, 1),
    
-- [[
    -- CPU IO cache registers
    getAram_cpuIo_read                              = makeAramReader(0x0, 1, false, 1),
    getAram_cpuIo_write                             = makeAramReader(0x4, 1, false, 1),
    getAram_cpuIo_read_prev                         = makeAramReader(0x8, 1, false, 1),
    
    getAram_musicTrackStatus                        = makeAramReader(0xC, 1),
    getAram_zero                                    = makeAramReader(0xD, 2),
    
    -- Temporaries
    getAram_note                                    = makeAramReader(0xF, 2),
    getAram_panningBias                             = makeAramReader(0xF, 2),
    getAram_dspVoiceVolumeIndex                     = makeAramReader(0x11, 1),
    getAram_noteModifiedFlag                        = makeAramReader(0x12, 1),
    getAram_misc0                                   = makeAramReader(0x13, 2),
    getAram_misc1                                   = makeAramReader(0x15, 2),
    
    getAram_randomNumber                            = makeAramReader(0x17, 2),
    getAram_enableSoundEffectVoices                 = makeAramReader(0x19, 1),
    getAram_disableNoteProcessing                   = makeAramReader(0x1A, 1),
    getAram_p_return                                = makeAramReader(0x1B, 2),
    
    -- Sound 1
    getAram_sound1_instructionListPointerSet        = makeAramReader(0x1D, 2),
    getAram_sound1_p_charVoiceBitset                = makeAramReader(0x1F, 2),
    getAram_sound1_p_charVoiceMask                  = makeAramReader(0x21, 2),
    getAram_sound1_p_charVoiceIndex                 = makeAramReader(0x23, 2),
    
    -- Sounds
    getAram_sound_p_instructionListsLow             = makeAramReader(0x25, 1, false, 1),
    getAram_sound_p_instructionListsHigh            = makeAramReader(0x2D, 1, false, 1),
    
    getAram_trackPointers                           = makeAramReader(0x35, 2, false, 2),
    getAram_p_tracker                               = makeAramReader(0x45, 2),
    getAram_trackerTimer                            = makeAramReader(0x47, 1),
    getAram_soundEffectsClock                       = makeAramReader(0x48, 1),
    getAram_trackIndex                              = makeAramReader(0x49, 1),
    
    -- DSP cache
    getAram_keyOnFlags                              = makeAramReader(0x4A, 1),
    getAram_keyOffFlags                             = makeAramReader(0x4B, 1),
    getAram_musicVoiceBitset                        = makeAramReader(0x4C, 1),
    getAram_flg                                     = makeAramReader(0x4D, 1),
    getAram_noiseEnableFlags                        = makeAramReader(0x4E, 1),
    getAram_echoEnableFlags                         = makeAramReader(0x4F, 1),
    getAram_pitchModulationFlags                    = makeAramReader(0x50, 1),
    
    -- Echo
    getAram_echoTimer                               = makeAramReader(0x51, 1),
    getAram_echoDelay                               = makeAramReader(0x52, 1),
    getAram_echoFeedbackVolume                      = makeAramReader(0x53, 1),
    
    -- Music
    getAram_musicTranspose                          = makeAramReader(0x54, 1),
    getAram_musicTrackClock                         = makeAramReader(0x55, 1),
    getAram_musicTempo                              = makeAramReader(0x56, 2),
    getAram_dynamicMusicTempoTimer                  = makeAramReader(0x58, 1),
    getAram_targetMusicTempo                        = makeAramReader(0x59, 1),
    getAram_musicTempoDelta                         = makeAramReader(0x5A, 2),
    getAram_musicVolume                             = makeAramReader(0x5C, 2),
    getAram_dynamicMusicVolumeTimer                 = makeAramReader(0x5E, 1),
    getAram_targetMusicVolume                       = makeAramReader(0x5F, 1),
    getAram_musicVolumeDelta                        = makeAramReader(0x60, 2),
    getAram_musicVoiceVolumeUpdateBitset            = makeAramReader(0x62, 1),
    getAram_percussionInstrumentsBaseIndex          = makeAramReader(0x63, 1),
    
    -- Echo
    getAram_echoVolumeLeft                          = makeAramReader(0x64, 2),
    getAram_echoVolumeRight                         = makeAramReader(0x66, 2),
    getAram_echoVolumeLeftDelta                     = makeAramReader(0x68, 2),
    getAram_echoVolumeRightDelta                    = makeAramReader(0x6A, 2),
    getAram_dynamicEchoVolumeTimer                  = makeAramReader(0x6C, 1),
    getAram_targetEchoVolumeLeft                    = makeAramReader(0x6D, 1),
    getAram_targetEchoVolumeRight                   = makeAramReader(0x6E, 1),
    
    -- Track
    getAram_trackNoteTimers                         = makeAramReader(0x6F, 1, false, 2),
    getAram_trackNoteRingTimers                     = makeAramReader(0x70, 1, false, 2),
    getAram_trackRepeatedSubsectionCounters         = makeAramReader(0x7F, 1, false, 2),
    getAram_trackDynamicVolumeTimers                = makeAramReader(0x80, 1, false, 2),
    getAram_trackDynamicPanningTimers               = makeAramReader(0x8F, 1, false, 2),
    getAram_trackPitchSlideTimers                   = makeAramReader(0x90, 1, false, 2),
    getAram_trackPitchSlideDelayTimers              = makeAramReader(0x9F, 1, false, 2),
    getAram_trackVibratoDelayTimers                 = makeAramReader(0xA0, 1, false, 2),
    getAram_trackVibratoExtents                     = makeAramReader(0xAF, 1, false, 2),
    getAram_trackTremoloDelayTimers                 = makeAramReader(0xB0, 1, false, 2),
    getAram_trackTremoloExtents                     = makeAramReader(0xBF, 1, false, 2),
    
    -- Sounds
    getAram_p_echoBuffer                            = makeAramReader(0xCE, 2),
    getAram_sound2_instructionListPointerSet        = makeAramReader(0xD0, 2),
    getAram_sound2_p_charVoiceBitset                = makeAramReader(0xD2, 2),
    getAram_sound2_p_charVoiceMask                  = makeAramReader(0xD4, 2),
    getAram_sound2_p_charVoiceIndex                 = makeAramReader(0xD6, 2),
    getAram_sound3_instructionListPointerSet        = makeAramReader(0xD8, 2),
    getAram_sound3_p_charVoiceBitset                = makeAramReader(0xDA, 2),
    getAram_sound3_p_charVoiceMask                  = makeAramReader(0xDC, 2),
    getAram_sound3_p_charVoiceIndex                 = makeAramReader(0xDE, 2),
    
    getAram_trackDynamicVibratoTimers               = makeAramReader(0x100, 1), -- todo
    
    -- Music
    getAram_trackNoteLengths                        = makeAramReader(0x200, 1, false, 2),
    getAram_trackNoteRingLengths                    = makeAramReader(0x201, 1, false, 2),
    getAram_trackNoteVolume                         = makeAramReader(0x210, 1, false, 2),
    getAram_trackInstrumentIndices                  = makeAramReader(0x211, 1, false, 2),
    getAram_trackInstrumentPitches                  = makeAramReader(0x220, 1, false, 2),
    getAram_trackRepeatedSubsectionAddresses        = makeAramReader(0x230, 1, false, 2),
    getAram_trackRepeatedSubsectionReturnAddresses  = makeAramReader(0x240, 1, false, 2),
    getAram_trackSlideLengths                       = makeAramReader(0x250, 1, false, 2),
    getAram_trackSlideDelays                        = makeAramReader(0x251, 1, false, 2),
    getAram_trackSlideDirections                    = makeAramReader(0x260, 1, false, 2),
    getAram_trackSlideExtents                       = makeAramReader(0x261, 1, false, 2),
    getAram_trackVibratoPhases                      = makeAramReader(0x270, 1, false, 2),
    getAram_trackVibratoRates                       = makeAramReader(0x271, 1, false, 2),
    getAram_trackVibratoDelays                      = makeAramReader(0x280, 1, false, 2),
    getAram_trackDynamicVibratoLengths              = makeAramReader(0x281, 1, false, 2),
    getAram_trackVibratoExtentDeltas                = makeAramReader(0x290, 1, false, 2),
    getAram_trackStaticVibratoExtents               = makeAramReader(0x291, 1, false, 2),
    getAram_trackTremoloPhases                      = makeAramReader(0x2A0, 1, false, 2),
    getAram_trackTremoloRates                       = makeAramReader(0x2A1, 1, false, 2),
    getAram_trackTremoloDelays                      = makeAramReader(0x2B0, 1, false, 2),
    getAram_trackTransposes                         = makeAramReader(0x2B1, 1, false, 2),
    getAram_trackVolumes                            = makeAramReader(0x2C0, 1, false, 2),
    getAram_trackVolumeDeltas                       = makeAramReader(0x2D0, 1, false, 2),
    getAram_trackTargetVolumes                      = makeAramReader(0x2E0, 1, false, 2),
    getAram_trackOutputVolumes                      = makeAramReader(0x2E1, 1, false, 2),
    getAram_trackPanningBiases                      = makeAramReader(0x2F0, 1, false, 2),
    getAram_trackPanningBiasDeltas                  = makeAramReader(0x300, 1, false, 2),
    getAram_trackTargetPanningBiases                = makeAramReader(0x310, 1, false, 2),
    getAram_trackPhaseInversionOptions              = makeAramReader(0x311, 1, false, 2),
    getAram_trackSubnotes                           = makeAramReader(0x320, 1, false, 2),
    getAram_trackNotes                              = makeAramReader(0x321, 1, false, 2),
    getAram_trackNoteDeltas                         = makeAramReader(0x330, 1, false, 2),
    getAram_trackTargetNotes                        = makeAramReader(0x340, 1, false, 2),
    getAram_trackSubtransposes                      = makeAramReader(0x341, 1, false, 2),
    getAram_trackSkipNewNotesFlags                  = makeAramReader(0x350, 1, false, 2),
    
    getAram_i_globalChannel                         = makeAramReader(0x35F, 1),
    getAram_i_voice                                 = makeAramReader(0x360, 1),
    getAram_i_soundLibrary                          = makeAramReader(0x351, 1),
    
    -- Sound 1
    getAram_i_sound1                                = makeAramReader(0x362, 1),
    getAram_sound1_i_channel                        = makeAramReader(0x363, 1),
    getAram_sound1_n_voices                         = makeAramReader(0x364, 1),
    getAram_sound1_i_voice                          = makeAramReader(0x365, 1),
    getAram_sound1_remainingEnabledSoundVoices      = makeAramReader(0x366, 1),
    getAram_sound1_voiceId                          = makeAramReader(0x367, 1),
    getAram_sound1_2i_channel                       = makeAramReader(0x368, 1),
    
    -- Sound 2
    getAram_i_sound2                                = makeAramReader(0x369, 1),
    getAram_sound2_i_channel                        = makeAramReader(0x36A, 1),
    getAram_sound2_n_voices                         = makeAramReader(0x36B, 1),
    getAram_sound2_i_voice                          = makeAramReader(0x36C, 1),
    getAram_sound2_remainingEnabledSoundVoices      = makeAramReader(0x36D, 1),
    getAram_sound2_voiceId                          = makeAramReader(0x36E, 1),
    getAram_sound2_2i_channel                       = makeAramReader(0x36F, 1),
    
    -- Sound 3
    getAram_i_sound3                                = makeAramReader(0x370, 1),
    getAram_sound3_i_channel                        = makeAramReader(0x371, 1),
    getAram_sound3_n_voices                         = makeAramReader(0x372, 1),
    getAram_sound3_i_voice                          = makeAramReader(0x373, 1),
    getAram_sound3_remainingEnabledSoundVoices      = makeAramReader(0x374, 1),
    getAram_sound3_voiceId                          = makeAramReader(0x375, 1),
    getAram_sound3_2i_channel                       = makeAramReader(0x376, 1),
    
    -- Sounds
    getAram_sounds                                  = makeAramReader(0x377, 1, false, 1),
    getAram_sound_enabledVoices                     = makeAramReader(0x37A, 1, false, 1),
    getAram_sound_priorities                        = makeAramReader(0x37D, 1, false, 1),
    getAram_sound_initialisationFlags               = makeAramReader(0x380, 1, false, 1),
    
    -- Sound channels
    getAram_sound_i_instructionLists                = makeAramReader(0x383, 1, false, 1),
    getAram_sound_instructionTimers                 = makeAramReader(0x38B, 1, false, 1),
    getAram_sound_disableBytes                      = makeAramReader(0x393, 1, false, 1),
    getAram_sound_voiceBitsets                      = makeAramReader(0x39B, 1, false, 1),
    getAram_sound_voiceMasks                        = makeAramReader(0x3A3, 1, false, 1),
    getAram_sound_voiceIndices                      = makeAramReader(0x3AB, 1, false, 1),
    getAram_sound_dspIndices                        = makeAramReader(0x3B3, 1, false, 1),
    getAram_sound_trackOutputVolumeBackups          = makeAramReader(0x3BB, 1, false, 1),
    getAram_sound_trackPhaseInversionOptionsBackups = makeAramReader(0x3C3, 1, false, 1),
    getAram_sound_releaseFlags                      = makeAramReader(0x3CB, 1, false, 1),
    getAram_sound_releaseTimers                     = makeAramReader(0x3D3, 1, false, 1),
    getAram_sound_repeatCounters                    = makeAramReader(0x3DB, 1, false, 1),
    getAram_sound_repeatPoints                      = makeAramReader(0x3E3, 1, false, 1),
    getAram_sound_adsrSettingsLow                   = makeAramReader(0x3EB, 1, false, 1),
    getAram_sound_adsrSettingsHigh                  = makeAramReader(0x3F3, 1, false, 1),
    getAram_sound_updateAdsrSettingsFlags           = makeAramReader(0x3FB, 1, false, 1),
    getAram_sound_notes                             = makeAramReader(0x403, 1, false, 1),
    getAram_sound_subnotes                          = makeAramReader(0x40B, 1, false, 1),
    getAram_sound_subnoteDeltas                     = makeAramReader(0x413, 1, false, 1),
    getAram_sound_targetNotes                       = makeAramReader(0x41B, 1, false, 1),
    getAram_sound_pitchSlideFlags                   = makeAramReader(0x423, 1, false, 1),
    getAram_sound_legatoFlags                       = makeAramReader(0x42B, 1, false, 1),
    getAram_sound_pitchSlideLegatoFlags             = makeAramReader(0x433, 1, false, 1),
    
    getAram_disableProcessingCpuIo2                 = makeAramReader(0x43B, 1),
    getAram_i_echoFirFilterSet                      = makeAramReader(0x43C, 1),
    getAram_sound3LowHealthPriority                 = makeAramReader(0x43D, 1),
    
    getAram_noteRingLengthTable                     = makeAramReader(0x3852, 1, false, 1),
    getAram_noteVolumeTable                         = makeAramReader(0x385A, 1, false, 1),
    getAram_instrumentTable                         = makeAramReader(0x386A, 1, false, 1),
    getAram_trackerData                             = makeAramReader(0x3954, 1, false, 1),
    getAram_echoBuffer                              = makeAramReader(0x4A00, 1, false, 1),
    getAram_sampleTable                             = makeAramReader(0x6A00, 1, false, 1),
    getAram_sampleData                              = makeAramReader(0x6B00, 1, false, 1),
-- ]]
}
