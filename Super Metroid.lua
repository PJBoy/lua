local xemu = require("cross emu")

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
        [1] = xemu.read_u8,
        [2] = xemu.read_u16_le
    }
    local signedReaders = {
        [1] = xemu.read_s8,
        [2] = xemu.read_s16_le
    }

    if is_aram then
        unsignedReaders = {
            [1] = xemu.read_aram_u8,
            [2] = xemu.read_aram_u16_le
        }
        signedReaders = {
            [1] = xemu.read_aram_s8,
            [2] = xemu.read_aram_s16_le
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

function makeAggregateReader(readers)
    return function(i) return readers[i + 1] end
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
        [1] = xemu.write_u8,
        [2] = xemu.write_u16_le
    }

    local writer = writers[n]
    if interval then
        return function(i, v) return writer(p + i * interval, v) end
    else
        return function(v) return writer(p, v) end
    end
end

local sm = {}

-- Button bitmasks --
sm.button_B      = 0x8000
sm.button_Y      = 0x4000
sm.button_select = 0x2000
sm.button_start  = 0x1000
sm.button_up     = 0x800
sm.button_down   = 0x400
sm.button_left   = 0x200
sm.button_right  = 0x100
sm.button_A      = 0x80
sm.button_X      = 0x40
sm.button_L      = 0x20
sm.button_R      = 0x10

-- WRAM --
sm.getBg1TilemapOptions      = makeReader(0x7E0058, 2)
sm.getBg2TilemapOptions      = makeReader(0x7E0059, 2)

sm.getInput                  = makeReader(0x7E008B, 2)
sm.getChangedInput           = makeReader(0x7E008F, 2)

sm.getBg1ScrollX             = makeReader(0x7E00B1, 2)
sm.setBg1ScrollX             = makeWriter(0x7E00B1, 2)
sm.getBg1ScrollY             = makeReader(0x7E00B3, 2)
sm.setBg1ScrollY             = makeWriter(0x7E00B3, 2)
sm.getBg2ScrollX             = makeReader(0x7E00B5, 2)
sm.setBg2ScrollX             = makeWriter(0x7E00B5, 2)
sm.getBg2ScrollY             = makeReader(0x7E00B7, 2)
sm.setBg2ScrollY             = makeWriter(0x7E00B7, 2)
sm.getBg3ScrollX             = makeReader(0x7E00B9, 2)
sm.setBg3ScrollX             = makeWriter(0x7E00B9, 2)
sm.getBg3ScrollY             = makeReader(0x7E00BB, 2)
sm.setBg3ScrollY             = makeWriter(0x7E00BB, 2)

sm.getMode7Flag              = makeReader(0x7E0783, 2)
sm.getDoorDirection          = makeReader(0x7E0791, 2)
sm.getRoomPointer            = makeReader(0x7E079B, 2)
sm.getAreaIndex              = makeReader(0x7E079F, 2)
sm.getRoomWidth              = makeReader(0x7E07A5, 2)
sm.getRoomHeight             = makeReader(0x7E07A7, 2)
sm.getRoomWidthInScrolls     = makeReader(0x7E07A9, 2)
sm.getRoomHeightInScrolls    = makeReader(0x7E07AB, 2)
sm.getUpScroller             = makeReader(0x7E07AD, 2)
sm.getDownScroller           = makeReader(0x7E07AF, 2)
sm.getDoorListPointer        = makeReader(0x7E07B5, 2)

sm.getLayer1XSubposition     = makeReader(0x7E090F, 2)
sm.getLayer1XPosition        = makeReader(0x7E0911, 2, true)
sm.setLayer1XPosition        = makeWriter(0x7E0911, 2)
sm.getLayer1YSubposition     = makeReader(0x7E0913, 2)
sm.getLayer1YPosition        = makeReader(0x7E0915, 2, true)
sm.setLayer1YPosition        = makeWriter(0x7E0915, 2)
sm.getLayer2XPosition        = makeReader(0x7E0917, 2, true)
sm.getLayer2YPosition        = makeReader(0x7E0919, 2, true)
sm.getLayer2XScroll          = makeReader(0x7E091B, 1)
sm.getLayer2YScroll          = makeReader(0x7E091C, 1)
sm.getBg1ScrollXOffset       = makeReader(0x7E091D, 2, true)
sm.getBg1ScrollYOffset       = makeReader(0x7E091F, 2, true)
sm.getBg2ScrollXOffset       = makeReader(0x7E0921, 2, true)
sm.getBg2ScrollYOffset       = makeReader(0x7E0923, 2, true)

sm.getDownwardsElevatorDelayTimer = makeReader(0x7E092F, 2)

sm.getCameraDistanceIndex    = makeReader(0x7E0941, 2)

sm.getGameState              = makeReader(0x7E0998, 2)
sm.getDoorTransitionFunction = makeReader(0x7E099C, 2)

sm.getEquippedItems         = makeReader(0x7E09A2, 2)
sm.getCollectedItems        = makeReader(0x7E09A4, 2)
sm.getEquippedBeams         = makeReader(0x7E09A6, 2)
sm.getCollectedBeams        = makeReader(0x7E09A8, 2)

sm.getRunBinding             = makeReader(0x7E09B6, 2)

sm.getSamusHealth           = makeReader(0x7E09C2, 2)
sm.getSamusMaxHealth        = makeReader(0x7E09C4, 2)
sm.getSamusMissiles         = makeReader(0x7E09C6, 2)
sm.getSamusMaxMissiles      = makeReader(0x7E09C8, 2)
sm.getSamusSuperMissiles    = makeReader(0x7E09CA, 2)
sm.getSamusMaxSuperMissiles = makeReader(0x7E09CC, 2)
sm.getSamusPowerBombs       = makeReader(0x7E09CE, 2)
sm.getSamusMaxPowerBombs    = makeReader(0x7E09D0, 2)
sm.getSamusMaxReserveHealth = makeReader(0x7E09D4, 2)
sm.getSamusReserveHealth    = makeReader(0x7E09D6, 2)

sm.getGameTimeFrames         = makeReader(0x7E09DA, 2)
sm.getGameTimeSeconds        = makeReader(0x7E09DC, 2)
sm.getGameTimeMinutes        = makeReader(0x7E09DE, 2)
sm.getGameTimeHours          = makeReader(0x7E09E0, 2)

sm.getSamusPreviousMovementType = makeReader(0x7E0A11, 1)
sm.getSamusPose                 = makeReader(0x7E0A1C, 1)
sm.getSamusFacingDirection      = makeReader(0x7E0A1E, 1)
sm.getSamusMovementType         = makeReader(0x7E0A1F, 1)
sm.getKnockbackDirection        = makeReader(0x7E0A52, 2)
sm.getSamusMovementHandler      = makeReader(0x7E0A58, 2)
sm.getSamusPoseInputHandler     = makeReader(0x7E0A60, 2)
sm.getShinesparkTimer           = makeReader(0x7E0A68, 2, true)
sm.getFrozenTimeFlag            = makeReader(0x7E0A78, 2)
sm.getXrayState                 = makeReader(0x7E0A7A, 2)

sm.getSamusAnimationFrameTimer = makeReader(0x7E0A94, 2)
sm.getSamusAnimationFrame      = makeReader(0x7E0A96, 2)
sm.getSpecialSamusPaletteType  = makeReader(0x7E0ACC, 2)

sm.getSamusXPosition           = makeReader(0x7E0AF6, 2)
sm.getSamusXPositionSigned     = makeReader(0x7E0AF6, 2, true)
sm.setSamusXPosition           = makeWriter(0x7E0AF6, 2)
sm.getSamusXSubposition        = makeReader(0x7E0AF8, 2)
sm.getSamusYPosition           = makeReader(0x7E0AFA, 2)
sm.getSamusYPositionSigned     = makeReader(0x7E0AFA, 2, true)
sm.setSamusYPosition           = makeWriter(0x7E0AFA, 2)
sm.getSamusYSubposition        = makeReader(0x7E0AFC, 2)
sm.getSamusXRadius             = makeReader(0x7E0AFE, 2)
sm.getSamusYRadius             = makeReader(0x7E0B00, 2)
sm.getIdealLayer1XPosition     = makeReader(0x7E0B0A, 2)
sm.getIdealLayer1YPosition     = makeReader(0x7E0B0E, 2)
sm.getSamusPreviousXPosition   = makeReader(0x7E0B10, 2)
sm.getSamusPreviousYPosition   = makeReader(0x7E0B14, 2)
sm.getSamusYSubspeed           = makeReader(0x7E0B2C, 2)
sm.getSamusYSpeed              = makeReader(0x7E0B2E, 2)
sm.getSamusYDirection          = makeReader(0x7E0B36, 2)
sm.getSamusRunningMomentumFlag = makeReader(0x7E0B3C, 2)
sm.getSpeedBoosterLevel        = makeReader(0x7E0B3F, 2)
sm.getSamusXSpeed              = makeReader(0x7E0B42, 2)
sm.getSamusXSubspeed           = makeReader(0x7E0B44, 2)
sm.getSamusXMomentum           = makeReader(0x7E0B46, 2)
sm.getSamusXSubmomentum        = makeReader(0x7E0B48, 2)

sm.getCooldownTimer          = makeReader(0x7E0CCC, 2)
sm.getChargeCounter          = makeReader(0x7E0CD0, 2)
sm.getPowerBombXPosition     = makeReader(0x7E0CE2, 2)
sm.getPowerBombYPosition     = makeReader(0x7E0CE4, 2)
sm.getPowerBombRadius        = makeReader(0x7E0CEA, 2)
sm.getPowerBombPreRadius     = makeReader(0x7E0CEC, 2)
sm.getPowerBombFlag          = makeReader(0x7E0CEE, 2)

sm.getXDistanceSamusMoved    = makeReader(0x7E0DA2, 2)
sm.getXSubdistanceSamusMoved = makeReader(0x7E0DA4, 2)
sm.getYDistanceSamusMoved    = makeReader(0x7E0DA6, 2)
sm.getYSubdistanceSamusMoved = makeReader(0x7E0DA8, 2)

sm.getBlockIndex             = makeReader(0x7E0DC4, 2)

sm.getElevatorState          = makeReader(0x7E0E18, 2)

sm.getNEnemies               = makeReader(0x7E0E4E, 2)

sm.getBossNumber             = makeReader(0x7E179C, 2)

sm.getEarthquakeType         = makeReader(0x7E183E, 2)
sm.getEarthquakeTimer        = makeReader(0x7E1840, 2)

sm.getInvincibilityTimer     = makeReader(0x7E18A8, 2)
sm.getRecoilTimer            = makeReader(0x7E18AA, 2)

sm.getHdmaObjectIndex        = makeReader(0x7E18B2, 2)

sm.getFxYPosition            = makeReader(0x7E195E, 2)
sm.setFxYPosition            = makeWriter(0x7E195E, 2)
sm.getLavaAcidYPosition      = makeReader(0x7E1962, 2)
sm.setLavaAcidYPosition      = makeWriter(0x7E1962, 2)
sm.getFxTargetYPosition      = makeReader(0x7E197A, 2)

sm.getMessageBoxIndex = makeReader(0x7E1C1F, 2)

sm.getPlmEnableFlag = makeReader(0x7E1C23, 2)

-- OAM
sm.getOamXLow                = makeReader(0x7E0370, 1, false, 4)
sm.setOamXLow                = makeWriter(0x7E0370, 1, 4)
sm.getOamY                   = makeReader(0x7E0371, 1, false, 4)
sm.setOamY                   = makeWriter(0x7E0371, 1, 4)
sm.getOamProperties          = makeReader(0x7E0372, 2, false, 4)
sm.getOamHigh                = makeReader(0x7E0570, 1, false, 1)
sm.setOamHigh                = makeWriter(0x7E0570, 1, 1)

-- Projectiles
sm.getProjectileXPosition = makeReader(0x7E0B64, 2, false, 2)
sm.getProjectileYPosition = makeReader(0x7E0B78, 2, false, 2)
sm.getProjectileXRadius   = makeReader(0x7E0BB4, 2, false, 2)
sm.getProjectileYRadius   = makeReader(0x7E0BC8, 2, false, 2)
sm.getProjectileXVelocity = makeReader(0x7E0BDC, 2, false, 2)
sm.getProjectileYVelocity = makeReader(0x7E0BF0, 2, false, 2)
sm.getProjectileType      = makeReader(0x7E0C18, 2, false, 2)
sm.getProjectileDamage    = makeReader(0x7E0C2C, 2, false, 2)
sm.getBombTimer           = makeReader(0x7E0C7C, 2, false, 2)

-- Enemies
sm.getEnemyId                      = makeReader(0x7E0F78, 2, false, 0x40)
sm.getEnemyXPosition               = makeReader(0x7E0F7A, 2, false, 0x40)
sm.getEnemyXSubposition            = makeReader(0x7E0F7C, 2, false, 0x40)
sm.getEnemyYPosition               = makeReader(0x7E0F7E, 2, false, 0x40)
sm.getEnemyYSubposition            = makeReader(0x7E0F80, 2, false, 0x40)
sm.getEnemyXRadius                 = makeReader(0x7E0F82, 2, false, 0x40)
sm.getEnemyYRadius                 = makeReader(0x7E0F84, 2, false, 0x40)
sm.getEnemyProperties              = makeReader(0x7E0F86, 2, false, 0x40)
sm.getEnemyExtraProperties         = makeReader(0x7E0F88, 2, false, 0x40)
sm.getEnemyAiHandler               = makeReader(0x7E0F8A, 2, false, 0x40)
sm.getEnemyHealth                  = makeReader(0x7E0F8C, 2, false, 0x40)
sm.getEnemySpritemap               = makeReader(0x7E0F8E, 2, false, 0x40)
sm.getEnemyTimer                   = makeReader(0x7E0F90, 2, false, 0x40)
sm.getEnemyInitialisationParameter = makeReader(0x7E0F92, 2, false, 0x40)
sm.getEnemyInstructionList         = makeReader(0x7E0F92, 2, false, 0x40)
sm.getEnemyInstructionTimer        = makeReader(0x7E0F94, 2, false, 0x40)
sm.getEnemyPaletteIndex            = makeReader(0x7E0F96, 2, false, 0x40)
sm.getEnemyGraphicsIndex           = makeReader(0x7E0F98, 2, false, 0x40)
sm.getEnemyLayer                   = makeReader(0x7E0F9A, 2, false, 0x40)
sm.getEnemyInvincibilityTimer      = makeReader(0x7E0F9C, 2, false, 0x40)
sm.getEnemyFrozenTimer             = makeReader(0x7E0F9E, 2, false, 0x40)
sm.getEnemyPlasmaTimer             = makeReader(0x7E0FA0, 2, false, 0x40)
sm.getEnemyShakeTimer              = makeReader(0x7E0FA2, 2, false, 0x40)
sm.getEnemyFrameCounter            = makeReader(0x7E0FA4, 2, false, 0x40)
sm.getEnemyBank                    = makeReader(0x7E0FA6, 1, false, 0x40)
sm.getEnemyAiVariable0             = makeReader(0x7E0FA8, 2, false, 0x40)
sm.getEnemyAiVariable1             = makeReader(0x7E0FAA, 2, false, 0x40)
sm.getEnemyAiVariable2             = makeReader(0x7E0FAC, 2, false, 0x40)
sm.getEnemyAiVariable3             = makeReader(0x7E0FAE, 2, false, 0x40)
sm.getEnemyAiVariable4             = makeReader(0x7E0FB0, 2, false, 0x40)
sm.getEnemyAiVariable5             = makeReader(0x7E0FB2, 2, false, 0x40)
sm.getEnemyParameter1              = makeReader(0x7E0FB4, 2, false, 0x40)
sm.getEnemyParameter2              = makeReader(0x7E0FB6, 2, false, 0x40)

-- Enemy projectiles
sm.getEnemyProjectileId        = makeReader(0x7E1997, 2, false, 2)
sm.getEnemyProjectileXPosition = makeReader(0x7E1A4B, 2, false, 2)
sm.getEnemyProjectileYPosition = makeReader(0x7E1A93, 2, false, 2)
sm.getEnemyProjectileXRadius   = makeReader(0x7E1BB3, 1, false, 2)
sm.getEnemyProjectileYRadius   = makeReader(0x7E1BB4, 1, false, 2)

-- PLMs
sm.getPlmId               = makeReader(0x7E1C37, 2, false, 2)
sm.getPlmRoomArgument     = makeReader(0x7E1DC7, 2, false, 2)
sm.getPlmInstructionTimer = makeReader(0x7EDE1C, 2, false, 2)

-- Metatiles
sm.getMetatileTopLeft     = makeReader(0x7EA000, 2, false, 8)
sm.getMetatileTopRight    = makeReader(0x7EA002, 2, false, 8)
sm.getMetatileBottomLeft  = makeReader(0x7EA004, 2, false, 8)
sm.getMetatileBottomRight = makeReader(0x7EA006, 2, false, 8)

-- Scroll
sm.getScroll = makeReader(0x7ECD20, 1, false, 1)

-- Sprite objects
sm.getSpriteObjectInstructionList = makeReader(0x7EEF78, 2, false, 2)
sm.getSpriteObjectXPosition       = makeReader(0x7EF0F8, 2, false, 2)
sm.getSpriteObjectYPosition       = makeReader(0x7EF1F8, 2, false, 2)

-- Blocks
sm.getLevelDatum      = makeReader(0x7F0002, 2, false, 2)
sm.getBts             = makeReader(0x7F6402, 1, false, 1)
sm.getBtsSigned       = makeReader(0x7F6402, 1, true,  1)
sm.getBackgroundDatum = makeReader(0x7F9602, 2, false, 2)


-- ARAM --
-- CPU IO cache registers
sm.getAram_cpuIo_read      = makeAramReader(0x0, 1, false, 1)
sm.getAram_cpuIo_write     = makeAramReader(0x4, 1, false, 1)
sm.getAram_cpuIo_read_prev = makeAramReader(0x8, 1, false, 1)

sm.getAram_musicTrackStatus = makeAramReader(0xC, 1)

-- Temporaries
sm.getAram_note                = makeAramReader(0x10, 2)
sm.getAram_panningBias         = makeAramReader(0x10, 2)
sm.getAram_dspVoiceVolumeIndex = makeAramReader(0x12, 1)
sm.getAram_noteModifiedFlag    = makeAramReader(0x13, 1)
sm.getAram_misc0               = makeAramReader(0x14, 2)
sm.getAram_misc1               = makeAramReader(0x16, 2)

sm.getAram_randomNumber            = makeAramReader(0x18, 2)
sm.getAram_enableSoundEffectVoices = makeAramReader(0x1A, 1)
sm.getAram_disableNoteProcessing   = makeAramReader(0x1B, 1)
sm.getAram_p_return                = makeAramReader(0x20, 2)

-- Sound 1
sm.getAram_sound1_instructionListPointerSet = makeAramReader(0x22, 2)
sm.getAram_sound1_p_charVoiceBitset         = makeAramReader(0x24, 2)
sm.getAram_sound1_p_charVoiceMask           = makeAramReader(0x26, 2)
sm.getAram_sound1_p_charVoiceIndex          = makeAramReader(0x28, 2)

-- Sounds
sm.getAram_sound1_channel0_p_instructionList = makeAramReader(0x2A, 2)
sm.getAram_sound1_channel1_p_instructionList = makeAramReader(0x2C, 2)
sm.getAram_sound1_channel2_p_instructionList = makeAramReader(0x2E, 2)

sm.getAram_trackPointers     = makeAramReader(0x30, 2, false, 2)
sm.getAram_p_tracker         = makeAramReader(0x40, 2)
sm.getAram_trackerTimer      = makeAramReader(0x42, 1)
sm.getAram_soundEffectsClock = makeAramReader(0x43, 1)
sm.getAram_trackIndex        = makeAramReader(0x44, 1)

-- DSP cache
sm.getAram_keyOnFlags           = makeAramReader(0x45, 1)
sm.getAram_keyOffFlags          = makeAramReader(0x46, 1)
sm.getAram_musicVoiceBitset     = makeAramReader(0x47, 1)
sm.getAram_flg                  = makeAramReader(0x48, 1)
sm.getAram_noiseEnableFlags     = makeAramReader(0x49, 1)
sm.getAram_echoEnableFlags      = makeAramReader(0x4A, 1)
sm.getAram_pitchModulationFlags = makeAramReader(0x5B, 1)

-- Echo
sm.getAram_echoTimer          = makeAramReader(0x4C, 1)
sm.getAram_echoDelay          = makeAramReader(0x4D, 1)
sm.getAram_echoFeedbackVolume = makeAramReader(0x4E, 1)

-- Music
sm.getAram_musicTranspose                 = makeAramReader(0x50, 1)
sm.getAram_musicTrackClock                = makeAramReader(0x51, 1)
sm.getAram_musicTempo                     = makeAramReader(0x52, 2)
sm.getAram_dynamicMusicTempoTimer         = makeAramReader(0x54, 1)
sm.getAram_targetMusicTempo               = makeAramReader(0x55, 1)
sm.getAram_musicTempoDelta                = makeAramReader(0x56, 2)
sm.getAram_musicVolume                    = makeAramReader(0x58, 2)
sm.getAram_dynamicMusicVolumeTimer        = makeAramReader(0x5A, 1)
sm.getAram_targetMusicVolume              = makeAramReader(0x5B, 1)
sm.getAram_musicVolumeDelta               = makeAramReader(0x5C, 2)
sm.getAram_musicVoiceVolumeUpdateBitset   = makeAramReader(0x5E, 1)
sm.getAram_percussionInstrumentsBaseIndex = makeAramReader(0x5F, 1)

-- Echo
sm.getAram_echoVolumeLeft         = makeAramReader(0x60, 2)
sm.getAram_echoVolumeRight        = makeAramReader(0x62, 2)
sm.getAram_echoVolumeLeftDelta    = makeAramReader(0x64, 2)
sm.getAram_echoVolumeRightDelta   = makeAramReader(0x66, 2)
sm.getAram_dynamicEchoVolumeTimer = makeAramReader(0x68, 1)
sm.getAram_targetEchoVolumeLeft   = makeAramReader(0x69, 1)
sm.getAram_targetEchoVolumeRight  = makeAramReader(0x6A, 1)

-- Track
sm.getAram_trackNoteTimers                 = makeAramReader(0x70, 1, false, 2)
sm.getAram_trackNoteRingTimers             = makeAramReader(0x71, 1, false, 2)
sm.getAram_trackRepeatedSubsectionCounters = makeAramReader(0x80, 1, false, 2)
sm.getAram_trackDynamicVolumeTimers        = makeAramReader(0x90, 1, false, 2)
sm.getAram_trackDynamicPanningTimers       = makeAramReader(0x91, 1, false, 2)
sm.getAram_trackPitchSlideTimers           = makeAramReader(0xA0, 1, false, 2)
sm.getAram_trackPitchSlideDelayTimers      = makeAramReader(0xA1, 1, false, 2)
sm.getAram_trackVibratoDelayTimers         = makeAramReader(0xB0, 1, false, 2)
sm.getAram_trackVibratoExtents             = makeAramReader(0xB1, 1, false, 2)
sm.getAram_trackTremoloDelayTimers         = makeAramReader(0xC0, 1, false, 2)
sm.getAram_trackTremoloExtents             = makeAramReader(0xC1, 1, false, 2)

-- Sounds
sm.getAram_sound1_channel3_p_instructionList = makeAramReader(0xD0, 2)
sm.getAram_p_echoBuffer                      = makeAramReader(0xD2, 2)
sm.getAram_sound2_instructionListPointerSet  = makeAramReader(0xD4, 2)
sm.getAram_sound2_p_charVoiceBitset          = makeAramReader(0xD6, 2)
sm.getAram_sound2_p_charVoiceMask            = makeAramReader(0xD8, 2)
sm.getAram_sound2_p_charVoiceIndex           = makeAramReader(0xDA, 2)
sm.getAram_sound2_channel0_p_instructionList = makeAramReader(0xDC, 2)
sm.getAram_sound2_channel1_p_instructionList = makeAramReader(0xDE, 2)
sm.getAram_sound3_instructionListPointerSet  = makeAramReader(0xE0, 2)
sm.getAram_sound3_p_charVoiceBitset          = makeAramReader(0xE2, 2)
sm.getAram_sound3_p_charVoiceMask            = makeAramReader(0xE4, 2)
sm.getAram_sound3_p_charVoiceIndex           = makeAramReader(0xE6, 2)
sm.getAram_sound3_channel0_p_instructionList = makeAramReader(0xE8, 2)
sm.getAram_sound3_channel1_p_instructionList = makeAramReader(0xEA, 2)

-- Music
sm.getAram_trackDynamicVibratoTimers              = makeAramReader(0x100, 1, false, 2)
sm.getAram_trackNoteLengths                       = makeAramReader(0x200, 1, false, 2)
sm.getAram_trackNoteRingLengths                   = makeAramReader(0x201, 1, false, 2)
sm.getAram_trackNoteVolume                        = makeAramReader(0x210, 1, false, 2)
sm.getAram_trackInstrumentIndices                 = makeAramReader(0x211, 1, false, 2)
sm.getAram_trackInstrumentPitches                 = makeAramReader(0x220, 2, false, 2)
sm.getAram_trackRepeatedSubsectionAddresses       = makeAramReader(0x230, 2, false, 2)
sm.getAram_trackRepeatedSubsectionReturnAddresses = makeAramReader(0x240, 2, false, 2)
sm.getAram_trackSlideLengths                      = makeAramReader(0x280, 1, false, 2)
sm.getAram_trackSlideDelays                       = makeAramReader(0x281, 1, false, 2)
sm.getAram_trackSlideDirections                   = makeAramReader(0x290, 1, false, 2)
sm.getAram_trackSlideExtents                      = makeAramReader(0x291, 1, false, 2)
sm.getAram_trackVibratoPhases                     = makeAramReader(0x2A0, 1, false, 2)
sm.getAram_trackVibratoRates                      = makeAramReader(0x2A1, 1, false, 2)
sm.getAram_trackVibratoDelays                     = makeAramReader(0x2B0, 1, false, 2)
sm.getAram_trackDynamicVibratoLengths             = makeAramReader(0x2B1, 1, false, 2)
sm.getAram_trackVibratoExtentDeltas               = makeAramReader(0x2C0, 1, false, 2)
sm.getAram_trackStaticVibratoExtents              = makeAramReader(0x2C1, 1, false, 2)
sm.getAram_trackTremoloPhases                     = makeAramReader(0x2D0, 1, false, 2)
sm.getAram_trackTremoloRates                      = makeAramReader(0x2D1, 1, false, 2)
sm.getAram_trackTremoloDelays                     = makeAramReader(0x2E0, 1, false, 2)
sm.getAram_trackTransposes                        = makeAramReader(0x2F0, 1, false, 2)
sm.getAram_trackVolumes                           = makeAramReader(0x300, 2, false, 2)
sm.getAram_trackVolumeDeltas                      = makeAramReader(0x310, 2, false, 2)
sm.getAram_trackTargetVolumes                     = makeAramReader(0x320, 1, false, 2)
sm.getAram_trackOutputVolumes                     = makeAramReader(0x321, 1, false, 2)
sm.getAram_trackPanningBiases                     = makeAramReader(0x330, 2, false, 2)
sm.getAram_trackPanningBiasDeltas                 = makeAramReader(0x340, 2, false, 2)
sm.getAram_trackTargetPanningBiases               = makeAramReader(0x350, 1, false, 2)
sm.getAram_trackPhaseInversionOptions             = makeAramReader(0x351, 1, false, 2)
sm.getAram_trackSubnotes                          = makeAramReader(0x360, 1, false, 2)
sm.getAram_trackNotes                             = makeAramReader(0x361, 1, false, 2)
sm.getAram_trackNoteDeltas                        = makeAramReader(0x370, 2, false, 2)
sm.getAram_trackTargetNotes                       = makeAramReader(0x380, 1, false, 2)
sm.getAram_trackSubtransposes                     = makeAramReader(0x381, 1, false, 2)

-- Sound 1
sm.getAram_sound1                                   = makeAramReader(0x392, 1)
sm.getAram_i_sound1                                 = makeAramReader(0x393, 1)
sm.getAram_sound1_i_instructionLists                = makeAramReader(0x394, 1, false, 1)
sm.getAram_sound1_instructionTimers                 = makeAramReader(0x398, 1, false, 1)
sm.getAram_sound1_disableBytes                      = makeAramReader(0x39C, 1, false, 1)
sm.getAram_sound1_i_channel                         = makeAramReader(0x3A0, 1)
sm.getAram_sound1_n_voices                          = makeAramReader(0x3A1, 1)
sm.getAram_sound1_i_voice                           = makeAramReader(0x3A2, 1)
sm.getAram_sound1_remainingEnabledSoundVoices       = makeAramReader(0x3A3, 1)
sm.getAram_sound1_initialisationFlag                = makeAramReader(0x3A4, 1)
sm.getAram_sound1_voiceId                           = makeAramReader(0x3A5, 1)
sm.getAram_sound1_voiceBitsets                      = makeAramReader(0x3A6, 1, false, 1)
sm.getAram_sound1_voiceMasks                        = makeAramReader(0x3AA, 1, false, 1)
sm.getAram_sound1_2i_channel                        = makeAramReader(0x3AE, 1)
sm.getAram_sound1_voiceIndices                      = makeAramReader(0x3AF, 1, false, 1)
sm.getAram_sound1_enabledVoices                     = makeAramReader(0x3B3, 1)
sm.getAram_sound1_dspIndices                        = makeAramReader(0x3B4, 1, false, 1)
sm.getAram_sound1_trackOutputVolumeBackups          = makeAramReader(0x3B8, 1, false, 2)
sm.getAram_sound1_trackPhaseInversionOptionsBackups = makeAramReader(0x3B9, 1, false, 2)
sm.getAram_sound1_releaseFlags                      = makeAramReader(0x3C0, 1, false, 2)
sm.getAram_sound1_releaseTimers                     = makeAramReader(0x3C1, 1, false, 2)
sm.getAram_sound1_repeatCounters                    = makeAramReader(0x3C8, 1, false, 1)
sm.getAram_sound1_repeatPoints                      = makeAramReader(0x3CC, 1, false, 1)
sm.getAram_sound1_adsrSettings                      = makeAramReader(0x3D0, 1, false, 2)
sm.getAram_sound1_updateAdsrSettingsFlags           = makeAramReader(0x3D8, 1, false, 1)
sm.getAram_sound1_notes                             = makeAramReader(0x3DC, 1, false, 7)
sm.getAram_sound1_subnotes                          = makeAramReader(0x3DD, 1, false, 7)
sm.getAram_sound1_subnoteDeltas                     = makeAramReader(0x3DE, 1, false, 7)
sm.getAram_sound1_targetNotes                       = makeAramReader(0x3DF, 1, false, 7)
sm.getAram_sound1_pitchSlideFlags                   = makeAramReader(0x3E0, 1, false, 7)
sm.getAram_sound1_legatoFlags                       = makeAramReader(0x3E1, 1, false, 7)
sm.getAram_sound1_pitchSlideLegatoFlags             = makeAramReader(0x3E2, 1, false, 7)

-- Sound 2
sm.getAram_sound2                                   = makeAramReader(0x3F8, 1)
sm.getAram_i_sound2                                 = makeAramReader(0x3F9, 1)
sm.getAram_sound2_i_instructionLists                = makeAramReader(0x3FA, 1, false, 1)
sm.getAram_sound2_instructionTimers                 = makeAramReader(0x3FC, 1, false, 1)
sm.getAram_sound2_disableBytes                      = makeAramReader(0x3FE, 1, false, 1)

sm.getAram_trackSkipNewNotesFlags                   = makeAramReader(0x400, 1, false, 2)

sm.getAram_sound2_i_channel                         = makeAramReader(0x440, 1)
sm.getAram_sound2_n_voices                          = makeAramReader(0x441, 1)
sm.getAram_sound2_i_voice                           = makeAramReader(0x442, 1)
sm.getAram_sound2_remainingEnabledSoundVoices       = makeAramReader(0x443, 1)
sm.getAram_sound2_initialisationFlag                = makeAramReader(0x444, 1)
sm.getAram_sound2_voiceId                           = makeAramReader(0x445, 1)
sm.getAram_sound2_voiceBitsets                      = makeAramReader(0x446, 1, false, 1)
sm.getAram_sound2_voiceMasks                        = makeAramReader(0x448, 1, false, 1)
sm.getAram_sound2_2i_channel                        = makeAramReader(0x44A, 1)
sm.getAram_sound2_voiceIndices                      = makeAramReader(0x44B, 1, false, 1)
sm.getAram_sound2_enabledVoices                     = makeAramReader(0x44D, 1)
sm.getAram_sound2_dspIndices                        = makeAramReader(0x44E, 1, false, 1)
sm.getAram_sound2_trackOutputVolumeBackups          = makeAramReader(0x450, 1, false, 2)
sm.getAram_sound2_trackPhaseInversionOptionsBackups = makeAramReader(0x451, 1, false, 2)
sm.getAram_sound2_releaseFlags                      = makeAramReader(0x454, 1, false, 2)
sm.getAram_sound2_releaseTimers                     = makeAramReader(0x455, 1, false, 2)
sm.getAram_sound2_repeatCounters                    = makeAramReader(0x458, 1, false, 1)
sm.getAram_sound2_repeatPoints                      = makeAramReader(0x45A, 1, false, 1)
sm.getAram_sound2_adsrSettings                      = makeAramReader(0x45C, 1, false, 2)
sm.getAram_sound2_updateAdsrSettingsFlags           = makeAramReader(0x460, 1, false, 1)
sm.getAram_sound2_notes                             = makeAramReader(0x462, 1, false, 7)
sm.getAram_sound2_subnotes                          = makeAramReader(0x463, 1, false, 7)
sm.getAram_sound2_subnoteDeltas                     = makeAramReader(0x464, 1, false, 7)
sm.getAram_sound2_targetNotes                       = makeAramReader(0x465, 1, false, 7)
sm.getAram_sound2_pitchSlideFlags                   = makeAramReader(0x466, 1, false, 7)
sm.getAram_sound2_legatoFlags                       = makeAramReader(0x467, 1, false, 7)
sm.getAram_sound2_pitchSlideLegatoFlags             = makeAramReader(0x468, 1, false, 7)

-- Sound 3
sm.getAram_sound3                                   = makeAramReader(0x470, 1)
sm.getAram_i_sound3                                 = makeAramReader(0x471, 1)
sm.getAram_sound3_i_instructionLists                = makeAramReader(0x472, 1, false, 1)
sm.getAram_sound3_instructionTimers                 = makeAramReader(0x474, 1, false, 1)
sm.getAram_sound3_disableBytes                      = makeAramReader(0x476, 1, false, 1)
sm.getAram_sound3_i_channel                         = makeAramReader(0x478, 1)
sm.getAram_sound3_n_voices                          = makeAramReader(0x479, 1)
sm.getAram_sound3_i_voice                           = makeAramReader(0x47A, 1)
sm.getAram_sound3_remainingEnabledSoundVoices       = makeAramReader(0x47B, 1)
sm.getAram_sound3_initialisationFlag                = makeAramReader(0x47C, 1)
sm.getAram_sound3_voiceId                           = makeAramReader(0x47D, 1)
sm.getAram_sound3_voiceBitsets                      = makeAramReader(0x47E, 1, false, 1)
sm.getAram_sound3_voiceMasks                        = makeAramReader(0x480, 1, false, 1)
sm.getAram_sound3_2i_channel                        = makeAramReader(0x482, 1)
sm.getAram_sound3_voiceIndices                      = makeAramReader(0x483, 1, false, 1)
sm.getAram_sound3_enabledVoices                     = makeAramReader(0x485, 1)
sm.getAram_sound3_dspIndices                        = makeAramReader(0x486, 1, false, 1)
sm.getAram_sound3_trackOutputVolumeBackups          = makeAramReader(0x488, 1, false, 2)
sm.getAram_sound3_trackPhaseInversionOptionsBackups = makeAramReader(0x489, 1, false, 2)
sm.getAram_sound3_releaseFlags                      = makeAramReader(0x48C, 1, false, 2)
sm.getAram_sound3_releaseTimers                     = makeAramReader(0x48D, 1, false, 2)
sm.getAram_sound3_repeatCounters                    = makeAramReader(0x490, 1, false, 1)
sm.getAram_sound3_repeatPoints                      = makeAramReader(0x492, 1, false, 1)
sm.getAram_sound3_adsrSettings                      = makeAramReader(0x494, 1, false, 2)
sm.getAram_sound3_updateAdsrSettingsFlags           = makeAramReader(0x498, 1, false, 1)
sm.getAram_sound3_notes                             = makeAramReader(0x49A, 1, false, 7)
sm.getAram_sound3_subnotes                          = makeAramReader(0x49B, 1, false, 7)
sm.getAram_sound3_subnoteDeltas                     = makeAramReader(0x49C, 1, false, 7)
sm.getAram_sound3_targetNotes                       = makeAramReader(0x49D, 1, false, 7)
sm.getAram_sound3_pitchSlideFlags                   = makeAramReader(0x49E, 1, false, 7)
sm.getAram_sound3_legatoFlags                       = makeAramReader(0x49F, 1, false, 7)
sm.getAram_sound3_pitchSlideLegatoFlags             = makeAramReader(0x4A0, 1, false, 7)

sm.getAram_disableProcessingCpuIo2 = makeAramReader(0x4A9, 1)
sm.getAram_i_echoFirFilterSet      = makeAramReader(0x4B1, 1)
sm.getAram_sound3LowHealthPriority = makeAramReader(0x4BA, 1)
sm.getAram_sound_priorities        = makeAramReader(0x4BB, 1, false, 1)

sm.getAram_echoBuffer          = makeAramReader(0x500, 1, false, 1)
sm.getAram_noteRingLengthTable = makeAramReader(0x5800, 1, false, 1)
sm.getAram_noteVolumeTable     = makeAramReader(0x5808, 1, false, 1)
sm.getAram_trackerData         = makeAramReader(0x6C00, 1, false, 1)
sm.getAram_instrumentTable     = makeAramReader(0x6C00, 1, false, 1)
sm.getAram_sampleTable         = makeAramReader(0x6D00, 1, false, 1)
sm.getAram_sampleData          = makeAramReader(0x6E00, 1, false, 1)

-- Wrapper readers
sm.getAram_i_sound                                 = makeAggregateReader({sm.getAram_i_sound1                                , sm.getAram_i_sound2                                , sm.getAram_i_sound3                                })
sm.getAram_sound_instructionListPointerSet         = makeAggregateReader({sm.getAram_sound1_instructionListPointerSet        , sm.getAram_sound2_instructionListPointerSet        , sm.getAram_sound3_instructionListPointerSet        })
sm.getAram_sound_p_charVoiceBitset                 = makeAggregateReader({sm.getAram_sound1_p_charVoiceBitset                , sm.getAram_sound2_p_charVoiceBitset                , sm.getAram_sound3_p_charVoiceBitset                })
sm.getAram_sound_p_charVoiceMask                   = makeAggregateReader({sm.getAram_sound1_p_charVoiceMask                  , sm.getAram_sound2_p_charVoiceMask                  , sm.getAram_sound3_p_charVoiceMask                  })
sm.getAram_sound_p_charVoiceIndex                  = makeAggregateReader({sm.getAram_sound1_p_charVoiceIndex                 , sm.getAram_sound2_p_charVoiceIndex                 , sm.getAram_sound3_p_charVoiceIndex                 })
sm.getAram_sound                                   = makeAggregateReader({sm.getAram_sound1                                  , sm.getAram_sound2                                  , sm.getAram_sound3                                  })
sm.getAram_sound_i_instructionLists                = makeAggregateReader({sm.getAram_sound1_i_instructionLists               , sm.getAram_sound2_i_instructionLists               , sm.getAram_sound3_i_instructionLists               })
sm.getAram_sound_instructionTimers                 = makeAggregateReader({sm.getAram_sound1_instructionTimers                , sm.getAram_sound2_instructionTimers                , sm.getAram_sound3_instructionTimers                })
sm.getAram_sound_disableBytes                      = makeAggregateReader({sm.getAram_sound1_disableBytes                     , sm.getAram_sound2_disableBytes                     , sm.getAram_sound3_disableBytes                     })
sm.getAram_sound_i_channel                         = makeAggregateReader({sm.getAram_sound1_i_channel                        , sm.getAram_sound2_i_channel                        , sm.getAram_sound3_i_channel                        })
sm.getAram_sound_n_voices                          = makeAggregateReader({sm.getAram_sound1_n_voices                         , sm.getAram_sound2_n_voices                         , sm.getAram_sound3_n_voices                         })
sm.getAram_sound_i_voice                           = makeAggregateReader({sm.getAram_sound1_i_voice                          , sm.getAram_sound2_i_voice                          , sm.getAram_sound3_i_voice                          })
sm.getAram_sound_remainingEnabledSoundVoices       = makeAggregateReader({sm.getAram_sound1_remainingEnabledSoundVoices      , sm.getAram_sound2_remainingEnabledSoundVoices      , sm.getAram_sound3_remainingEnabledSoundVoices      })
sm.getAram_sound_initialisationFlag                = makeAggregateReader({sm.getAram_sound1_initialisationFlag               , sm.getAram_sound2_initialisationFlag               , sm.getAram_sound3_initialisationFlag               })
sm.getAram_sound_voiceId                           = makeAggregateReader({sm.getAram_sound1_voiceId                          , sm.getAram_sound2_voiceId                          , sm.getAram_sound3_voiceId                          })
sm.getAram_sound_voiceBitsets                      = makeAggregateReader({sm.getAram_sound1_voiceBitsets                     , sm.getAram_sound2_voiceBitsets                     , sm.getAram_sound3_voiceBitsets                     })
sm.getAram_sound_voiceMasks                        = makeAggregateReader({sm.getAram_sound1_voiceMasks                       , sm.getAram_sound2_voiceMasks                       , sm.getAram_sound3_voiceMasks                       })
sm.getAram_sound_2i_channel                        = makeAggregateReader({sm.getAram_sound1_2i_channel                       , sm.getAram_sound2_2i_channel                       , sm.getAram_sound3_2i_channel                       })
sm.getAram_sound_voiceIndices                      = makeAggregateReader({sm.getAram_sound1_voiceIndices                     , sm.getAram_sound2_voiceIndices                     , sm.getAram_sound3_voiceIndices                     })
sm.getAram_sound_enabledVoices                     = makeAggregateReader({sm.getAram_sound1_enabledVoices                    , sm.getAram_sound2_enabledVoices                    , sm.getAram_sound3_enabledVoices                    })
sm.getAram_sound_dspIndices                        = makeAggregateReader({sm.getAram_sound1_dspIndices                       , sm.getAram_sound2_dspIndices                       , sm.getAram_sound3_dspIndices                       })
sm.getAram_sound_trackOutputVolumeBackups          = makeAggregateReader({sm.getAram_sound1_trackOutputVolumeBackups         , sm.getAram_sound2_trackOutputVolumeBackups         , sm.getAram_sound3_trackOutputVolumeBackups         })
sm.getAram_sound_trackPhaseInversionOptionsBackups = makeAggregateReader({sm.getAram_sound1_trackPhaseInversionOptionsBackups, sm.getAram_sound2_trackPhaseInversionOptionsBackups, sm.getAram_sound3_trackPhaseInversionOptionsBackups})
sm.getAram_sound_releaseFlags                      = makeAggregateReader({sm.getAram_sound1_releaseFlags                     , sm.getAram_sound2_releaseFlags                     , sm.getAram_sound3_releaseFlags                     })
sm.getAram_sound_releaseTimers                     = makeAggregateReader({sm.getAram_sound1_releaseTimers                    , sm.getAram_sound2_releaseTimers                    , sm.getAram_sound3_releaseTimers                    })
sm.getAram_sound_repeatCounters                    = makeAggregateReader({sm.getAram_sound1_repeatCounters                   , sm.getAram_sound2_repeatCounters                   , sm.getAram_sound3_repeatCounters                   })
sm.getAram_sound_repeatPoints                      = makeAggregateReader({sm.getAram_sound1_repeatPoints                     , sm.getAram_sound2_repeatPoints                     , sm.getAram_sound3_repeatPoints                     })
sm.getAram_sound_adsrSettings                      = makeAggregateReader({sm.getAram_sound1_adsrSettings                     , sm.getAram_sound2_adsrSettings                     , sm.getAram_sound3_adsrSettings                     })
sm.getAram_sound_updateAdsrSettingsFlags           = makeAggregateReader({sm.getAram_sound1_updateAdsrSettingsFlags          , sm.getAram_sound2_updateAdsrSettingsFlags          , sm.getAram_sound3_updateAdsrSettingsFlags          })
sm.getAram_sound_notes                             = makeAggregateReader({sm.getAram_sound1_notes                            , sm.getAram_sound2_notes                            , sm.getAram_sound3_notes                            })
sm.getAram_sound_subnotes                          = makeAggregateReader({sm.getAram_sound1_subnotes                         , sm.getAram_sound2_subnotes                         , sm.getAram_sound3_subnotes                         })
sm.getAram_sound_subnoteDeltas                     = makeAggregateReader({sm.getAram_sound1_subnoteDeltas                    , sm.getAram_sound2_subnoteDeltas                    , sm.getAram_sound3_subnoteDeltas                    })
sm.getAram_sound_targetNotes                       = makeAggregateReader({sm.getAram_sound1_targetNotes                      , sm.getAram_sound2_targetNotes                      , sm.getAram_sound3_targetNotes                      })
sm.getAram_sound_pitchSlideFlags                   = makeAggregateReader({sm.getAram_sound1_pitchSlideFlags                  , sm.getAram_sound2_pitchSlideFlags                  , sm.getAram_sound3_pitchSlideFlags                  })
sm.getAram_sound_legatoFlags                       = makeAggregateReader({sm.getAram_sound1_legatoFlags                      , sm.getAram_sound2_legatoFlags                      , sm.getAram_sound3_legatoFlags                      })
sm.getAram_sound_pitchSlideLegatoFlags             = makeAggregateReader({sm.getAram_sound1_pitchSlideLegatoFlags            , sm.getAram_sound2_pitchSlideLegatoFlags            , sm.getAram_sound3_pitchSlideLegatoFlags            })

sm.getAram_sound1_p_instructionList = makeAggregateReader({sm.getAram_sound1_channel0_p_instructionList, sm.getAram_sound1_channel1_p_instructionList, sm.getAram_sound1_channel2_p_instructionList, sm.getAram_sound1_channel3_p_instructionList})
sm.getAram_sound2_p_instructionList = makeAggregateReader({sm.getAram_sound2_channel0_p_instructionList, sm.getAram_sound2_channel1_p_instructionList})
sm.getAram_sound3_p_instructionList = makeAggregateReader({sm.getAram_sound3_channel0_p_instructionList, sm.getAram_sound3_channel1_p_instructionList})
sm.getAram_sound_p_instructionList = makeAggregateReader({sm.getAram_sound1_p_instructionList, sm.getAram_sound2_p_instructionList, sm.getAram_sound3_p_instructionList})

--[[
-- CPU IO cache registers
sm.getAram_cpuIo_read                              = makeAramReader(0x0, 1, false, 1)
sm.getAram_cpuIo_write                             = makeAramReader(0x4, 1, false, 1)
sm.getAram_cpuIo_read_prev                         = makeAramReader(0x8, 1, false, 1)

sm.getAram_musicTrackStatus                        = makeAramReader(0xC, 1)
sm.getAram_zero                                    = makeAramReader(0xD, 2)

-- Temporaries
sm.getAram_note                                    = makeAramReader(0xF, 2)
sm.getAram_panningBias                             = makeAramReader(0xF, 2)
sm.getAram_dspVoiceVolumeIndex                     = makeAramReader(0x11, 1)
sm.getAram_noteModifiedFlag                        = makeAramReader(0x12, 1)
sm.getAram_misc0                                   = makeAramReader(0x13, 2)
sm.getAram_misc1                                   = makeAramReader(0x15, 2)

sm.getAram_randomNumber                            = makeAramReader(0x17, 2)
sm.getAram_enableSoundEffectVoices                 = makeAramReader(0x19, 1)
sm.getAram_disableNoteProcessing                   = makeAramReader(0x1A, 1)
sm.getAram_p_return                                = makeAramReader(0x1B, 2)

-- Sound 1
sm.getAram_sound1_instructionListPointerSet        = makeAramReader(0x1D, 2)
sm.getAram_sound1_p_charVoiceBitset                = makeAramReader(0x1F, 2)
sm.getAram_sound1_p_charVoiceMask                  = makeAramReader(0x21, 2)
sm.getAram_sound1_p_charVoiceIndex                 = makeAramReader(0x23, 2)

-- Sounds
sm.getAram_sound_p_instructionListsLow             = makeAramReader(0x25, 1, false, 1)
sm.getAram_sound_p_instructionListsHigh            = makeAramReader(0x2D, 1, false, 1)

sm.getAram_trackPointers                           = makeAramReader(0x35, 2, false, 2)
sm.getAram_p_tracker                               = makeAramReader(0x45, 2)

-- TODO: this is invalidated up to 0xF0
sm.getAram_trackerTimer                            = makeAramReader(0x47, 1)
sm.getAram_soundEffectsClock                       = makeAramReader(0x48, 1)
sm.getAram_trackIndex                              = makeAramReader(0x49, 1)

-- DSP cache
sm.getAram_keyOnFlags                              = makeAramReader(0x4A, 1)
sm.getAram_keyOffFlags                             = makeAramReader(0x4B, 1)
sm.getAram_musicVoiceBitset                        = makeAramReader(0x4C, 1)
sm.getAram_flg                                     = makeAramReader(0x4D, 1)
sm.getAram_noiseEnableFlags                        = makeAramReader(0x4E, 1)
sm.getAram_echoEnableFlags                         = makeAramReader(0x4F, 1)
sm.getAram_pitchModulationFlags                    = makeAramReader(0x50, 1)

-- Echo
sm.getAram_echoTimer                               = makeAramReader(0x51, 1)
sm.getAram_echoDelay                               = makeAramReader(0x52, 1)
sm.getAram_echoFeedbackVolume                      = makeAramReader(0x53, 1)

-- Music
sm.getAram_musicTranspose                          = makeAramReader(0x54, 1)
sm.getAram_musicTrackClock                         = makeAramReader(0x55, 1)
sm.getAram_musicTempo                              = makeAramReader(0x56, 2)
sm.getAram_dynamicMusicTempoTimer                  = makeAramReader(0x58, 1)
sm.getAram_targetMusicTempo                        = makeAramReader(0x59, 1)
sm.getAram_musicTempoDelta                         = makeAramReader(0x5A, 2)
sm.getAram_musicVolume                             = makeAramReader(0x5C, 2)
sm.getAram_dynamicMusicVolumeTimer                 = makeAramReader(0x5E, 1)
sm.getAram_targetMusicVolume                       = makeAramReader(0x5F, 1)
sm.getAram_musicVolumeDelta                        = makeAramReader(0x60, 2)
sm.getAram_musicVoiceVolumeUpdateBitset            = makeAramReader(0x62, 1)
sm.getAram_percussionInstrumentsBaseIndex          = makeAramReader(0x63, 1)

-- Echo
sm.getAram_echoVolumeLeft                          = makeAramReader(0x64, 2)
sm.getAram_echoVolumeRight                         = makeAramReader(0x66, 2)
sm.getAram_echoVolumeLeftDelta                     = makeAramReader(0x68, 2)
sm.getAram_echoVolumeRightDelta                    = makeAramReader(0x6A, 2)
sm.getAram_dynamicEchoVolumeTimer                  = makeAramReader(0x6C, 1)
sm.getAram_targetEchoVolumeLeft                    = makeAramReader(0x6D, 1)
sm.getAram_targetEchoVolumeRight                   = makeAramReader(0x6E, 1)

-- Track
sm.getAram_trackNoteTimers                         = makeAramReader(0x6F, 1, false, 2)
sm.getAram_trackNoteRingTimers                     = makeAramReader(0x70, 1, false, 2)
sm.getAram_trackRepeatedSubsectionCounters         = makeAramReader(0x7F, 1, false, 2)
sm.getAram_trackDynamicVolumeTimers                = makeAramReader(0x80, 1, false, 2)
sm.getAram_trackDynamicPanningTimers               = makeAramReader(0x8F, 1, false, 2)
sm.getAram_trackPitchSlideTimers                   = makeAramReader(0x90, 1, false, 2)
sm.getAram_trackPitchSlideDelayTimers              = makeAramReader(0x9F, 1, false, 2)
sm.getAram_trackVibratoDelayTimers                 = makeAramReader(0xA0, 1, false, 2)
sm.getAram_trackVibratoExtents                     = makeAramReader(0xAF, 1, false, 2)
sm.getAram_trackTremoloDelayTimers                 = makeAramReader(0xB0, 1, false, 2)
sm.getAram_trackTremoloExtents                     = makeAramReader(0xBF, 1, false, 2)

-- Sounds
sm.getAram_p_echoBuffer                            = makeAramReader(0xCE, 2)
sm.getAram_sound2_instructionListPointerSet        = makeAramReader(0xD0, 2)
sm.getAram_sound2_p_charVoiceBitset                = makeAramReader(0xD2, 2)
sm.getAram_sound2_p_charVoiceMask                  = makeAramReader(0xD4, 2)
sm.getAram_sound2_p_charVoiceIndex                 = makeAramReader(0xD6, 2)
sm.getAram_sound3_instructionListPointerSet        = makeAramReader(0xD8, 2)
sm.getAram_sound3_p_charVoiceBitset                = makeAramReader(0xDA, 2)
sm.getAram_sound3_p_charVoiceMask                  = makeAramReader(0xDC, 2)
sm.getAram_sound3_p_charVoiceIndex                 = makeAramReader(0xDE, 2)

sm.getAram_trackDynamicVibratoTimers               = makeAramReader(0x100, 1, false, 2)

-- Music
sm.getAram_trackNoteLengths                        = makeAramReader(0x200, 1, false, 2)
sm.getAram_trackNoteRingLengths                    = makeAramReader(0x201, 1, false, 2)
sm.getAram_trackNoteVolume                         = makeAramReader(0x210, 1, false, 2)
sm.getAram_trackInstrumentIndices                  = makeAramReader(0x211, 1, false, 2)
sm.getAram_trackInstrumentPitches                  = makeAramReader(0x220, 1, false, 2)
sm.getAram_trackRepeatedSubsectionAddresses        = makeAramReader(0x230, 1, false, 2)
sm.getAram_trackRepeatedSubsectionReturnAddresses  = makeAramReader(0x240, 1, false, 2)
sm.getAram_trackSlideLengths                       = makeAramReader(0x250, 1, false, 2)
sm.getAram_trackSlideDelays                        = makeAramReader(0x251, 1, false, 2)
sm.getAram_trackSlideDirections                    = makeAramReader(0x260, 1, false, 2)
sm.getAram_trackSlideExtents                       = makeAramReader(0x261, 1, false, 2)
sm.getAram_trackVibratoPhases                      = makeAramReader(0x270, 1, false, 2)
sm.getAram_trackVibratoRates                       = makeAramReader(0x271, 1, false, 2)
sm.getAram_trackVibratoDelays                      = makeAramReader(0x280, 1, false, 2)
sm.getAram_trackDynamicVibratoLengths              = makeAramReader(0x281, 1, false, 2)
sm.getAram_trackVibratoExtentDeltas                = makeAramReader(0x290, 1, false, 2)
sm.getAram_trackStaticVibratoExtents               = makeAramReader(0x291, 1, false, 2)
sm.getAram_trackTremoloPhases                      = makeAramReader(0x2A0, 1, false, 2)
sm.getAram_trackTremoloRates                       = makeAramReader(0x2A1, 1, false, 2)
sm.getAram_trackTremoloDelays                      = makeAramReader(0x2B0, 1, false, 2)
sm.getAram_trackTransposes                         = makeAramReader(0x2B1, 1, false, 2)
sm.getAram_trackVolumes                            = makeAramReader(0x2C0, 1, false, 2)
sm.getAram_trackVolumeDeltas                       = makeAramReader(0x2D0, 1, false, 2)
sm.getAram_trackTargetVolumes                      = makeAramReader(0x2E0, 1, false, 2)
sm.getAram_trackOutputVolumes                      = makeAramReader(0x2E1, 1, false, 2)
sm.getAram_trackPanningBiases                      = makeAramReader(0x2F0, 1, false, 2)
sm.getAram_trackPanningBiasDeltas                  = makeAramReader(0x300, 1, false, 2)
sm.getAram_trackTargetPanningBiases                = makeAramReader(0x310, 1, false, 2)
sm.getAram_trackPhaseInversionOptions              = makeAramReader(0x311, 1, false, 2)
sm.getAram_trackSubnotes                           = makeAramReader(0x320, 1, false, 2)
sm.getAram_trackNotes                              = makeAramReader(0x321, 1, false, 2)
sm.getAram_trackNoteDeltas                         = makeAramReader(0x330, 1, false, 2)
sm.getAram_trackTargetNotes                        = makeAramReader(0x340, 1, false, 2)
sm.getAram_trackSubtransposes                      = makeAramReader(0x341, 1, false, 2)
sm.getAram_trackSkipNewNotesFlags                  = makeAramReader(0x350, 1, false, 2)

sm.getAram_i_globalChannel                         = makeAramReader(0x35F, 1)
sm.getAram_i_voice                                 = makeAramReader(0x360, 1)
sm.getAram_i_soundLibrary                          = makeAramReader(0x351, 1)

-- Sound 1
sm.getAram_i_sound1                                = makeAramReader(0x362, 1)
sm.getAram_sound1_i_channel                        = makeAramReader(0x363, 1)
sm.getAram_sound1_n_voices                         = makeAramReader(0x364, 1)
sm.getAram_sound1_i_voice                          = makeAramReader(0x365, 1)
sm.getAram_sound1_remainingEnabledSoundVoices      = makeAramReader(0x366, 1)
sm.getAram_sound1_voiceId                          = makeAramReader(0x367, 1)
sm.getAram_sound1_2i_channel                       = makeAramReader(0x368, 1)

-- Sound 2
sm.getAram_i_sound2                                = makeAramReader(0x369, 1)
sm.getAram_sound2_i_channel                        = makeAramReader(0x36A, 1)
sm.getAram_sound2_n_voices                         = makeAramReader(0x36B, 1)
sm.getAram_sound2_i_voice                          = makeAramReader(0x36C, 1)
sm.getAram_sound2_remainingEnabledSoundVoices      = makeAramReader(0x36D, 1)
sm.getAram_sound2_voiceId                          = makeAramReader(0x36E, 1)
sm.getAram_sound2_2i_channel                       = makeAramReader(0x36F, 1)

-- Sound 3
sm.getAram_i_sound3                                = makeAramReader(0x370, 1)
sm.getAram_sound3_i_channel                        = makeAramReader(0x371, 1)
sm.getAram_sound3_n_voices                         = makeAramReader(0x372, 1)
sm.getAram_sound3_i_voice                          = makeAramReader(0x373, 1)
sm.getAram_sound3_remainingEnabledSoundVoices      = makeAramReader(0x374, 1)
sm.getAram_sound3_voiceId                          = makeAramReader(0x375, 1)
sm.getAram_sound3_2i_channel                       = makeAramReader(0x376, 1)

-- Sounds
sm.getAram_sounds                                  = makeAramReader(0x377, 1, false, 1)
sm.getAram_sound_enabledVoices                     = makeAramReader(0x37A, 1, false, 1)
sm.getAram_sound_priorities                        = makeAramReader(0x37D, 1, false, 1)
sm.getAram_sound_initialisationFlags               = makeAramReader(0x380, 1, false, 1)

-- Sound channels
sm.getAram_sound_i_instructionLists                = makeAramReader(0x383, 1, false, 1)
sm.getAram_sound_instructionTimers                 = makeAramReader(0x38B, 1, false, 1)
sm.getAram_sound_disableBytes                      = makeAramReader(0x393, 1, false, 1)
sm.getAram_sound_voiceBitsets                      = makeAramReader(0x39B, 1, false, 1)
sm.getAram_sound_voiceMasks                        = makeAramReader(0x3A3, 1, false, 1)
sm.getAram_sound_voiceIndices                      = makeAramReader(0x3AB, 1, false, 1)
sm.getAram_sound_dspIndices                        = makeAramReader(0x3B3, 1, false, 1)
sm.getAram_sound_trackOutputVolumeBackups          = makeAramReader(0x3BB, 1, false, 1)
sm.getAram_sound_trackPhaseInversionOptionsBackups = makeAramReader(0x3C3, 1, false, 1)
sm.getAram_sound_releaseFlags                      = makeAramReader(0x3CB, 1, false, 1)
sm.getAram_sound_releaseTimers                     = makeAramReader(0x3D3, 1, false, 1)
sm.getAram_sound_repeatCounters                    = makeAramReader(0x3DB, 1, false, 1)
sm.getAram_sound_repeatPoints                      = makeAramReader(0x3E3, 1, false, 1)
sm.getAram_sound_adsrSettingsLow                   = makeAramReader(0x3EB, 1, false, 1)
sm.getAram_sound_adsrSettingsHigh                  = makeAramReader(0x3F3, 1, false, 1)
sm.getAram_sound_updateAdsrSettingsFlags           = makeAramReader(0x3FB, 1, false, 1)
sm.getAram_sound_notes                             = makeAramReader(0x403, 1, false, 1)
sm.getAram_sound_subnotes                          = makeAramReader(0x40B, 1, false, 1)
sm.getAram_sound_subnoteDeltas                     = makeAramReader(0x413, 1, false, 1)
sm.getAram_sound_targetNotes                       = makeAramReader(0x41B, 1, false, 1)
sm.getAram_sound_pitchSlideFlags                   = makeAramReader(0x423, 1, false, 1)
sm.getAram_sound_legatoFlags                       = makeAramReader(0x42B, 1, false, 1)
sm.getAram_sound_pitchSlideLegatoFlags             = makeAramReader(0x433, 1, false, 1)

sm.getAram_disableProcessingCpuIo2                 = makeAramReader(0x43B, 1)
sm.getAram_i_echoFirFilterSet                      = makeAramReader(0x43C, 1)
sm.getAram_sound3LowHealthPriority                 = makeAramReader(0x43D, 1)

sm.getAram_noteRingLengthTable                     = makeAramReader(0x3855, 1, false, 1)
sm.getAram_noteVolumeTable                         = makeAramReader(0x385D, 1, false, 1)
sm.getAram_instrumentTable                         = makeAramReader(0x386D, 1, false, 1)
sm.getAram_trackerData                             = makeAramReader(0x3957, 1, false, 1)
sm.getAram_sampleTable                             = makeAramReader(0x4A00, 1, false, 1)
sm.getAram_sampleData_echoBuffer                   = makeAramReader(0x4B00, 1, false, 1)
-- ]]


return sm
