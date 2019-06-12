--[[
Notes on Super Metroid scrolling and drawing.

BG vs layers:
    BG1/2/3 are used to refer to the physical SNES graphics layers.
    Layer 1/2/3 are used to refer to the logical Super Metroid room data layers and corresponds to BG1/2/3 respectively.
    Layer 1 is the main level data (the one with clip data), layer 2 is the background and layer 3 is the HUD and foreground.

The main variables involved are:
    Layer 1 position ($0911, $0915)
    BG1 position ($B1, $B3)
    BG1 offset ($091D, $091F)

    Layer 1 position describes the logical position of the top left corner of the screen, relative to the top-left corner of the room.
    BG1 position describes the position of the BG1 tilemap in VRAM.
    BG1 offset is the displacement from layer 1 position to BG1 position.

    When starting a game or loading a save, the BG1 offset is set to an arbitrary multiple of 100h.
    Thereafter, during main gameplay, the BG1 position updated to [layer 1 position] + [BG1 offset] every frame.
    At the start of door transition, the two positions desynch:
        The layer 1 position is set so that it scrolls to door's destination position
        The new BG1 offset is calculated

The first problem - misaligned doors:
    This problem arises when the door transition is triggered when the screen isn't aligned with the edge of the screen.
    In this case, the new BG1 offset will be calculated to be a value that isn't a multiple of 100h.

    The PLM drawing routine makes a hard assumption that [layer 1 position] & FFh = [BG1 position] & FFh,
    so things like doors closing and blocks crumbling are drawn in the wrong place on screen.

    The scrolling routine doesn't make this assumption and actually determines the drawing destination in VRAM based on the BG1 position;
    however, if the BG1 offset isn't a multiple of 10h, then the entire BG1 will still be incorrectly displaced by [BG1 offset] % 10h pixels.

    The fix here is to simply to forcibly align the BG1 position with the layer 1 position before BG1 offset calculation.

The second problem - scrolling too fast:
    The scrolling routines assume that only one row or column of (16px) blocks would ever need updated per frame.
    When breaking this assumption, spurious blocks show up instead of the intended ones.
    Patching the game's scrolling routine causes lag and quickly desynchs TASes;
    even adding a small (< 10 cycles) check in the NMI to conditionally redraw the screen causes desynchs
    (the original approach was to make a save state, enable screen redrawing, dump the fixed screen, load the savestate and disable screen redrawing).
    Patching the NMI can't be by lua in BizHawk either (cannot write to cart memory), so there's no zero-cycle way around the synch issue.

    The approach used now is to fully reimplement screen redrawing in lua manually, writing to VRAM directly.

The third problem - Samus goes off-screen:
    It's easy enough to detect when Samus goes off-screen, ideally the camera would focus around Samus' position in that case.
    In order to make the camera follow Samus, I'll need to:
        ~~Configure the room drawing relative to Samus' position and set the BG position registers accordingly~~
        ~~Detect bosses and handle layer 2 accordingly~~
        ~~Acknowledge room boundaries (ignoring scroll zones)~~
        ~~Optional: Also acknowledge doors and try to keep them on the edge of the screen~~
        Actually, lets go through all the scroll PLMs and enable all the scroll zones that way instead,
        this will require rewriting large portions of the scrolling routines instead.
        
        Rewrite the positions of all sprites in OAM (either directly or via $0370),
        this is awkward because some sprites (Samus, single part enemies) wrap the screen,
        where as others (multipart enemies, enemy projectiles) have off-screen handling behaviour;
        the spritemap processing routines in bank $81 aren't hijackable because the spritemap pointer parameter is kept in the Y register
        (BizHawk can't read registers, emu.getregister(s) returns garbage values)
        Optional: Draw off-screen sprites, including: (not done)
            Samus
            Enemies
            Enemy projectiles
            Sprite objects
        Configure BG3 drawing and HDMA, including:
            Power bombs (this was a lot of work)
            Liquids (water, lava, acid) (done this lazily, might need to redo)

The fourth problem - x-ray prevents scrolling:
    X-ray and probably other things like R-mode or whatever prevent scrolling (via $0A78)
    The fix here is to force scrolling manually by setting the BG positions every frame
--]]

console.clear()

-- Note that BizHawk requires a restart if any included files are modified
sm = require("Super Metroid")

function snes2pc(p)
    return bit.band(bit.rshift(p, 1), 0x3F8000) + bit.band(p, 0x7FFF)
end

function romRead(p, n, signed)
    -- p: Pointer to ROM
    -- n: Number of bytes to read
    -- signed: Whether or not to sign extend read values

    local unsignedReaders = {
        [1] = memory.read_u8,
        [2] = memory.read_u16_le
    }
    local signedReaders = {
        [1] = memory.read_s8,
        [2] = memory.read_s16_le
    }

    if signed then
        return signedReaders[n](snes2pc(p), "CARTROM")
    else
        return unsignedReaders[n](snes2pc(p), "CARTROM")
    end
end

function vramWrite(p, v)
    -- In SNES land, VRAM is addressed with 16-bit bytes with address space $0000..7FFF;
    -- in emu land, VRAM is addressed with the usual 8-bit bytes with address space $0000..FFFF
    memory.write_u16_le(bit.band(p, 0x7FFF) * 2, v, "VRAM")
end

function clamp(v, v_min, v_max)
    return math.min(math.max(v, v_min), v_max)
end

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
        --or gameState == 0xB and doorTransitionFunction ~= 0xE36E
end

function getSamusPosition()
    return
    {
        x = sm.getSamusXPositionSigned(),
        y = sm.getSamusYPositionSigned()
    }
end

function getLayer1Position()
    return
    {
        x = sm.getLayer1XPosition(),
        y = sm.getLayer1YPosition(),
        subX = sm.getLayer1XSubposition(),
        subY = sm.getLayer1YSubposition()
    }
end

function getBg1Scroll()
    return
    {
        x = sm.getBg1ScrollX(),
        y = sm.getBg1ScrollY()
    }
end

function getBg2Scroll()
    return
    {
        x = sm.getBg2ScrollX(),
        y = sm.getBg2ScrollY()
    }
end

function setBg1Scroll(bg1Scroll)
    sm.setBg1ScrollX(bg1Scroll.x)
    sm.setBg1ScrollY(bg1Scroll.y)
end

function setBg2Scroll(bg2Scroll)
    sm.setBg2ScrollX(bg2Scroll.x)
    sm.setBg2ScrollY(bg2Scroll.y)
end


function adjustSprites(xOffset, yOffset)
    -- For sprites that are drawn off-screen,
    -- Y position E0h is used by generic sprites,
    -- and F0h is used by multi-sprite enemies and enemy projectiles
    
    local n = 0 -- debug

    for i = 0,127 do
        local spriteY = sm.getOamY(i)
        if spriteY ~= 0xE0 and spriteY ~= 0xF0 then
            local i_oamHigh = bit.rshift(i, 2) -- byte index
            local i_spriteXHigh = i % 4 * 2 -- bit index
            local oamHigh = sm.getOamHigh(i_oamHigh)
            local spriteXHigh = bit.band(bit.rshift(oamHigh, i_spriteXHigh), 1)
            
            local spriteX = sm.getOamXLow(i) + spriteXHigh * 0x100
            local spriteTileIndex = bit.band(sm.getOamProperties(i), 0x1FF)
            
            local spriteX_old = spriteX
            local spriteY_old = spriteY
            
            spriteX = spriteX - xOffset
            spriteY = spriteY - yOffset
            if
                --spriteTileIndex < 0x20 -- Samus
                spriteTileIndex < 0x6D -- Non-enemies
                or
                    -0x20 < spriteY and spriteY < 0xE0
                and -0x20 < spriteX and spriteX < 0x100
            then
                -- oamHigh = oamHigh & ~(1 << i_spriteXHigh) | (spriteX >> 8 & 1) << i_spriteXHigh
                spriteXHigh = bit.band(bit.rshift(spriteX, 8), 1)
                spriteXHighMask = bit.bnot(bit.lshift(1, i_spriteXHigh))
                oamHigh = bit.bor(bit.band(oamHigh, spriteXHighMask), bit.lshift(spriteXHigh, i_spriteXHigh))
                
                sm.setOamXLow(i, spriteX)
                sm.setOamHigh(i_oamHigh, oamHigh)
                sm.setOamY(i, spriteY)
                
                
                -- Debug
            --[[
                spriteX = bit.band(spriteX, 0x1FF)
                spriteY = bit.band(spriteY, 0xFF)
                gui.drawText(8, n * 8, string.format('(%03X, %02X) => (%03X, %02X)', spriteX_old, spriteY_old, spriteX, spriteY), "white", "black")
                n = n + 1
            --]]
            else
                sm.setOamY(i, 0xE0)
            end
        end
    end
end

function getScrolls()
    -- Here we load the game's scroll values and also process all the scroll PLMs in the current room,
    -- the goal is to free camera movement as much as possible whilst still having reasonable scrolling boundaries

    local roomWidth = sm.getRoomWidthInScrolls()
    local roomHeight = sm.getRoomHeightInScrolls()

    local scrolls = {}
    for y = 0, roomHeight - 1 do
        scrolls[y] = {}
        for x = 0, roomWidth - 1 do
            scrolls[y][x] = sm.getScroll(y * roomWidth + x)
        end
    end

    for i = 0, 0x27 do
        if sm.getPlmId(i) == 0xB703 then
            p_scrollData = 0x8F0000 + sm.getPlmRoomArgument(i)
            while true do
                local i_scroll = romRead(p_scrollData, 1)
                if bit.band(i_scroll, 0x80) ~= 0 then
                    break
                end

                local v_scroll = romRead(p_scrollData + 1, 1)
                if v_scroll ~= 0 then
                    local x = i_scroll % roomWidth
                    local y = (i_scroll - x) / roomWidth
                    if y < 0 or y >= roomHeight or x < 0 or x >= roomWidth then
                        console.log(string.format('Error: bad scroll data, PLM room argument = %X, scroll data entry = %X', sm.getPlmRoomArgument(i), p_scrollData))
                    else
                        scrolls[y][x] = v_scroll
                    end
                end

                p_scrollData = p_scrollData + 2
            end
        end
    end

    -- Hardcoded scroll hacks
    local p_room = sm.getRoomPointer()

    -- Kraid's room
    if p_room == 0xA59F then
        scrolls[1][1] = 1
    end

    -- Wrecked Ship spike floor hall
    if p_room == 0xC98E then
        scrolls[2][1] = 1
    end

    -- Sandy Maridia mainstreet
    if p_room == 0xD340 then
        scrolls[1][3] = 1
    end

    return scrolls
end

function calculateLayer2Coordinate(v, layer2Scroll)
    -- Return value of nil means the background doesn't scroll
    
    if layer2Scroll == 0 then
        return v
    elseif layer2Scroll == 1 then
        return nil
    else
        return bit.arshift(v * bit.rshift(layer2Scroll, 1), 7)
    end
end

function drawLayer(vramBaseAddress, bgScrollXOffset, layerBlockX, layerBlockY, getBlock)
    local roomWidth = sm.getRoomWidth()
    for y = 0,15 do
        for x = 0,16 do
            local vramAddress = vramBaseAddress + ((layerBlockY + y) % 0x10 * 0x20 + (layerBlockX + x) % 0x10) * 2
            if ((layerBlockX + x) % 0x20 >= 0x10) ~= (bgScrollXOffset % 0x200 >= 0x100) then
                vramAddress = vramAddress + 0x400
            end

            local block = getBlock((layerBlockY + y) * roomWidth + layerBlockX + x)
            local i_metatile = bit.band(block, 0x3FF)
            local flipFlags = bit.lshift(bit.band(block, 0xC00), 4)
            local tile_topLeft     = bit.bxor(flipFlags, sm.getMetatileTopLeft(i_metatile))
            local tile_topRight    = bit.bxor(flipFlags, sm.getMetatileTopRight(i_metatile))
            local tile_bottomLeft  = bit.bxor(flipFlags, sm.getMetatileBottomLeft(i_metatile))
            local tile_bottomRight = bit.bxor(flipFlags, sm.getMetatileBottomRight(i_metatile))
            if flipFlags == 0 then
                vramWrite(vramAddress,        tile_topLeft)
                vramWrite(vramAddress + 1,    tile_topRight)
                vramWrite(vramAddress + 0x20, tile_bottomLeft)
                vramWrite(vramAddress + 0x21, tile_bottomRight)
            elseif flipFlags == 0x4000 then
                vramWrite(vramAddress,        tile_topRight)
                vramWrite(vramAddress + 1,    tile_topLeft)
                vramWrite(vramAddress + 0x20, tile_bottomRight)
                vramWrite(vramAddress + 0x21, tile_bottomLeft)
            elseif flipFlags == 0x8000 then
                vramWrite(vramAddress,        tile_bottomLeft)
                vramWrite(vramAddress + 1,    tile_bottomRight)
                vramWrite(vramAddress + 0x20, tile_topLeft)
                vramWrite(vramAddress + 0x21, tile_topRight)
            else
                vramWrite(vramAddress,        tile_bottomRight)
                vramWrite(vramAddress + 1,    tile_bottomLeft)
                vramWrite(vramAddress + 0x20, tile_topRight)
                vramWrite(vramAddress + 0x21, tile_topLeft)
            end
        end
    end
end

function drawViewableRoom()
    -- Note: screen refreshing used to only be required if more than one block was scrolled,
    -- because the game should be able to handle that just fine.
    -- But there was nonetheless a graphical issue when coming down the Norfair elevator in the 100% TAS >_>
    -- So now the threshold has been lowered to *any* movement :(

    -- Some bosses (probably just Kraid) actually read the BG1/2 scroll values,
    -- so restoring their original values now that NMI has ended and the PPU registers have been updated
    if sm.getBossNumber() ~= 0 then
        setBg1Scroll(bg1Scroll_backup)
        setBg2Scroll(bg2Scroll_backup)
    end

    if not isValidLevelData() or sm.getMode7Flag() ~= 0 then-- or sm.getElevatorState() ~= 0 then
        return
    end

    local layer1Position = getLayer1Position()
    local layer1XBlock = bit.arshift(cameraPosition.x, 4)
    local layer1YBlock = bit.arshift(cameraPosition.y, 4)

    if
           layer1Position.x ~= cameraPosition.x
        or layer1Position.y ~= cameraPosition.y
        or math.abs(layer1XBlock - previousLayer1XBlock) > 0 -- See note above
        or math.abs(layer1YBlock - previousLayer1YBlock) > 0
        or sm.getFrozenTimeFlag() ~= 0
    then
        local bg1VramBaseAddress = bit.band(sm.getBg1TilemapOptions(), 0xFC) * 0x100
        drawLayer(bg1VramBaseAddress, sm.getBg1ScrollXOffset(), layer1XBlock, layer1YBlock, sm.getLevelDatum)
    end

    previousLayer1XBlock = layer1XBlock
    previousLayer1YBlock = layer1YBlock

    -- isCustomLayer2 = ~sm.getLayer2XScroll() & ~sm.getLayer2YScroll() & 1
    local isCustomLayer2 = (1 - sm.getLayer2XScroll() % 2) * (1 - sm.getLayer2YScroll() % 2)
    if isCustomLayer2 ~= 0 then
        local layer2XBlock, layer2YBlock

        local layer2XPosition = calculateLayer2Coordinate(cameraPosition.x, sm.getLayer2XScroll())
        if layer2XPosition ~= nil then
            layer2XBlock = bit.arshift(layer2XPosition, 4)
        else
            layer2XBlock = previousLayer2XBlock
        end

        local layer2YPosition = calculateLayer2Coordinate(cameraPosition.y, sm.getLayer2YScroll())
        if layer2YPosition ~= nil then
            layer2YBlock = bit.arshift(layer2YPosition, 4)
        else
            layer2YBlock = previousLayer2YBlock
        end

        if
               layer1Position.x ~= cameraPosition.x
            or layer1Position.y ~= cameraPosition.y
            or math.abs(layer2XBlock - previousLayer2XBlock) > 0 -- See note above
            or math.abs(layer2YBlock - previousLayer2YBlock) > 0
        then
            local bg2VramBaseAddress = bit.band(sm.getBg2TilemapOptions(), 0xFC) * 0x100
            drawLayer(bg2VramBaseAddress, sm.getBg2ScrollXOffset(), layer2XBlock, layer2YBlock, sm.getBackgroundDatum)
        end

        previousLayer2XBlock = layer2XBlock
        previousLayer2YBlock = layer2YBlock
    end
end

function nmiHook()
    -- BizHawk won't let me set the hardware registers,
    -- so I'm relying on the game's hardware register update, which occurs during NMI.
    -- Thus, I'm setting the game's mirror of BG1/2 scroll at the beginning of NMI,
    -- and reverting them at the end of NMI if necessary for the game's behaviour to not change.
    bg1Scroll_backup = getBg1Scroll()
    bg2Scroll_backup = getBg2Scroll()

    if isValidLevelData() and sm.getMode7Flag() == 0 then
        local layer1Position = getLayer1Position()
        local frozenTime = sm.getFrozenTimeFlag()

        -- Debug
    --[[
        gui.drawText(8, 32, string.format(
            'Camera position:   %04X %04X',
            bit.band(cameraPosition.x, 0xFFFF),
            bit.band(cameraPosition.y, 0xFFFF)
        ), 'white', 'black')
    --]]

        -- Emulate earthquakes. Doesn't work for non-standard earthquakes like Crocomire's room >_>
    --[[
        local bg1XOffset = 0
        local bg1YOffset = 0
        local bg2XOffset = 0
        local bg2YOffset = 0
        local earthquakeTimer = sm.getEarthquakeTimer()
        if earthquakeTimer ~= 0 then
            local earthquakeType = sm.getEarthquakeType()
            local direction = earthquakeType % 3
            local intensity = math.floor(earthquakeType / 3) % 3 + 1
            local layers = math.floor(earthquakeType / 9)

            if bit.band(earthquakeTimer, 2) ~= 0 then
                intensity = -intensity
            end

            local xOffset = 0
            local yOffset = 0
            if direction == 0 then
                xOffset = intensity
            elseif direction == 1 then
                yOffset = intensity
            else
                xOffset = intensity
                yOffset = intensity
            end

            if layers == 0 then
                bg1XOffset = xOffset
                bg1YOffset = yOffset
            elseif layers == 1 or layers == 2 then
                bg1XOffset = xOffset
                bg1YOffset = yOffset
                bg2XOffset = xOffset
                bg2YOffset = yOffset
            else
                bg2XOffset = xOffset
                bg2YOffset = yOffset
            end
        end
    --]]

        -- Calculate BG offsets due to earthquakes this way instead,
        -- taking the difference between the partially calculated BG scroll and the actual BG scroll
        local bg1XOffset = 0
        local bg1YOffset = 0
        local bg2XOffset = 0
        local bg2YOffset = 0

        if frozenTime == 0 then -- don't modify BG registers during x-ray
            bg1XOffset = bg1Scroll_backup.x - (layer1Position.x + sm.getBg1ScrollXOffset())
            bg1YOffset = bg1Scroll_backup.y - (layer1Position.y + sm.getBg1ScrollYOffset())
            bg2XOffset = bg2Scroll_backup.x - (sm.getLayer2XPosition() + sm.getBg2ScrollXOffset())
            bg2YOffset = bg2Scroll_backup.y - (sm.getLayer2YPosition() + sm.getBg2ScrollYOffset())
        end

        -- The game's scrolling is disabled when time is frozen, so force graphical updates
        if layer1Position.x ~= cameraPosition.x or layer1Position.y ~= cameraPosition.y or frozenTime ~= 0 then
            -- BG1 is simple enough
            sm.setBg1ScrollX(cameraPosition.x + bg1XOffset + sm.getBg1ScrollXOffset())
            sm.setBg1ScrollY(cameraPosition.y + bg1YOffset + sm.getBg1ScrollYOffset())
            
            -- BG2 depends on whether or not there's a boss and whether or not x-ray is active
            if sm.getBossNumber() == 0 then
                local xrayState = sm.getXrayState()
                if xrayState == 1 or xrayState == 2 then
                    -- X-ray is active
                    sm.setBg2ScrollX(bit.band(bg1Scroll_backup.x - xrayOriginPosition.x, 0xFFFF))
                    sm.setBg2ScrollY(bit.band(bg1Scroll_backup.y - xrayOriginPosition.y, 0xFFFF))
                else
                    local layer2XPosition = calculateLayer2Coordinate(cameraPosition.x, sm.getLayer2XScroll())
                    if layer2XPosition ~= nil then
                        sm.setBg2ScrollX(layer2XPosition + bg2XOffset + sm.getBg2ScrollXOffset())
                    end

                    local layer2YPosition = calculateLayer2Coordinate(cameraPosition.y, sm.getLayer2YScroll())
                    if layer2YPosition ~= nil then
                        sm.setBg2ScrollY(layer2YPosition + bg2YOffset + sm.getBg2ScrollYOffset())
                    end
                end
            else
                -- Boss room
                local bg2Scroll = getBg2Scroll()
                bg2Scroll.x = bg2Scroll.x + cameraPosition.x - layer1Position.x
                bg2Scroll.y = bg2Scroll.y + cameraPosition.y - layer1Position.y
                sm.setBg2ScrollX(bg2Scroll.x)
                sm.setBg2ScrollY(bg2Scroll.y)
            end

            local xOffset = cameraPosition.x - layer1Position.x
            local yOffset = cameraPosition.y - layer1Position.y

            adjustSprites(xOffset, yOffset)
        end

        -- Debug - scroll viewer
    --[[
        local scrolls = getScrolls()
        local roomWidth = sm.getRoomWidthInScrolls()
        local roomHeight = sm.getRoomHeightInScrolls()
        local colours = {[0] = "red", "blue", "green"}
        for y = 0, roomHeight - 1 do
            for x = 0, roomWidth - 1 do
                gui.drawBox(x * 0x100 - cameraPosition.x, y * 0x100 - cameraPosition.y, x * 0x100 - cameraPosition.x + 0xFF, y * 0x100 - cameraPosition.y + 0xFF, colours[scrolls[y][x] ], "clear")
                gui.drawText(x * 0x100 - cameraPosition.x, y * 0x100 - cameraPosition.y, string.format('%02X', scrolls[y][x]), colours[scrolls[y][x] ], "clear")
            end
        end
    --]]
    else
        -- Level data is invalid or mode 7 is active
        cameraPosition = getLayer1Position()
    end

    -- Debug:
--[[
    gui.drawText(8, 8, string.format(
        'Layer position:    %04X %04X %04X %04X',
        bit.band(sm.getLayer1XPosition(), 0xFFFF),
        bit.band(sm.getLayer1YPosition(), 0xFFFF),
        bit.band(sm.getLayer2XPosition(), 0xFFFF),
        bit.band(sm.getLayer2YPosition(), 0xFFFF)
    ), 'white', 'black')

    gui.drawText(8, 16, string.format(
        'BG position:       %04X %04X %04X %04X',
        sm.getBg1ScrollX(),
        sm.getBg1ScrollY(),
        sm.getBg2ScrollX(),
        sm.getBg2ScrollY()
    ), 'white', 'black')

    gui.drawText(8, 24, string.format(
        'BG scroll offsets: %04X %04X %04X %04X',
        bit.band(sm.getBg1ScrollXOffset(), 0xFFFF),
        bit.band(sm.getBg1ScrollYOffset(), 0xFFFF),
        bit.band(sm.getBg2ScrollXOffset(), 0xFFFF),
        bit.band(sm.getBg2ScrollYOffset(), 0xFFFF)
    ), 'white', 'black')
--]]
end


function fixBgScroll()
    -- This function is called at the beginning of BG scroll offset calculation (door transition)
    -- Set the BG1/2 X/Y scrolls to be a multiple of 100h difference from layer 1 X/Y position

    if sm.getAreaIndex() == 6 then
        -- Please don't break Ceres...
        return
    end

    local layer1XPosition = bit.band(sm.getLayer1XPosition(), 0xFF)
    local layer1YPosition = bit.band(sm.getLayer1YPosition(), 0xFF)

    sm.setBg1ScrollX(layer1XPosition)
    sm.setBg1ScrollY(layer1YPosition)
    sm.setBg2ScrollX(layer1XPosition)
    sm.setBg2ScrollY(layer1YPosition)
end

function recordXrayOrigin()
    xrayOriginPosition = getBg1Scroll()
    xrayOriginPosition.x = bit.band(xrayOriginPosition.x, 0xFFF0)
    xrayOriginPosition.y = bit.band(xrayOriginPosition.y, 0xFFF0)
end

function adjustLavaAcidPosition()
    -- This actually *could* cause desynchs, but it hasn't for the 100% TAS ^_^;
    lavaAcidYPosition = sm.getLavaAcidYPosition()
    if lavaAcidYPosition ~= 0xFFFF then
        local layer1Position = getLayer1Position()
        local yOffset = cameraPosition.y - layer1Position.y
        sm.setLavaAcidYPosition(lavaAcidYPosition - yOffset)
    end
end

function restoreLavaAcidPosition()
    sm.setLavaAcidYPosition(lavaAcidYPosition)
end

function adjustWaterPosition()
    -- This actually *could* cause desynchs, and it does :< (Wrecked Ship east exit)
    waterYPosition = sm.getFxYPosition()
    if waterYPosition ~= 0xFFFF then
        local layer1Position = getLayer1Position()
        local yOffset = cameraPosition.y - layer1Position.y
        sm.setFxYPosition(math.max(0, waterYPosition - yOffset))
    end
end

function restoreWaterPosition()
    mainmemory.write_u16_le(0x1962, waterYPosition)
end

function calculatePowerBombHdmaTablePointers(powerBombRadius)
    if sm.getFrozenTimeFlag() ~= 0 then
        return
    end

    local powerBombXPosition = sm.getPowerBombXPosition()
    local powerBombYPosition = sm.getPowerBombYPosition()
    local i_hdmaObject = sm.getHdmaObjectIndex()

    CE6 = mainmemory.read_u16_le(0x0CE6)
    local CE8 = mainmemory.read_u16_le(0x0CE8)

    if -0x100 <= powerBombXPosition - cameraPosition.x and powerBombXPosition - cameraPosition.x < 0x200 then
        CE6 = powerBombXPosition - cameraPosition.x + 0x100
    end

    if powerBombRadius < 0x100 then
        CE8 = 0
    elseif
            -0x100 <= powerBombXPosition - cameraPosition.x and powerBombXPosition - cameraPosition.x < 0x200
        and -0x100 <= powerBombYPosition - cameraPosition.y and powerBombYPosition - cameraPosition.y < 0x200
    then
        CE8 = 0x1FF - (powerBombYPosition - cameraPosition.y)
    else
        CE8 = 0x2FF
    end

    --mainmemory.write_u16_le(0x0CE6, CE6) -- causes desynchs
    mainmemory.write_u16_le(0x18D8 + i_hdmaObject, 0x9800 + CE8 * 3)
    mainmemory.write_u16_le(0x18DA + i_hdmaObject, 0xA101 + CE8 * 3)
end

function calculatePowerBombHdmaDataTables_part1(powerBombRadiusX, powerBombRadiusY)
    local x = powerBombRadiusY
    local left, right

    for y = 0x60, 0x7F do
        local t = bit.rshift(powerBombRadiusX * romRead(0x88A226 + y, 1), 8)
        local r = bit.rshift(powerBombRadiusX * romRead(0x88A206 + y, 1), 8)

        if CE6 < 0x100 then
            if CE6 + r < 0x100 then
                left = 0xFF
                right = 0
            else
                left = 0
                right = CE6 + r
            end
        elseif CE6 < 0x200 then
            left = math.max(0, CE6 % 0x100 - r)
            right = math.min(0xFF, CE6 % 0x100 + r)
        else
            if CE6 % 0x100 - r >= 0 then
                left = 0xFF
                right = 0
            else
                left = CE6 % 0x100 - r
                right = 0xFF
            end
        end

        while true do
            mainmemory.write_u8(0xC406 + x, left)
            mainmemory.write_u8(0xC506 + x, right)
            if x == t then
                break
            end

            x = x - 1
        end
    end

    repeat
        mainmemory.write_u8(0xC406 + x, left)
        mainmemory.write_u8(0xC506 + x, right)
        x = x - 1
    until x < 0

    x = powerBombRadiusY + 1
    while x ~= 0xC0 do
        mainmemory.write_u8(0xC406 + x, 0xFF)
        mainmemory.write_u8(0xC506 + x, 0)
        x = x + 1
    end
end

function calculatePowerBombHdmaDataTables_part2(y)
    for x = 0, 0xBF do
        local r = romRead(0x880000 + y, 1)
        if 0x100 <= CE6 and CE6 < 0x200 and r == 0 then
            return
        end

        if CE6 < 0x100 then
            if CE6 + r < 0x100 then
                left = 0xFF
                right = 0
            else
                left = 0
                right = CE6 + r
            end
        elseif CE6 < 0x200 then
            left = math.max(0, CE6 % 0x100 - r)
            right = math.min(0xFF, CE6 % 0x100 + r)
        else
            if CE6 % 0x100 - r >= 0 then
                left = 0xFF
                right = 0
            else
                left = CE6 % 0x100 - r
                right = 0xFF
            end
        end

        mainmemory.write_u8(0xC406 + x, left)
        mainmemory.write_u8(0xC506 + x, right)
        y = y + 1
    end
end

function adjustPowerBombPosition_stage1()
    local layer1Position = getLayer1Position()

    if layer1Position.x == cameraPosition.x and layer1Position.y == cameraPosition.y then
        return
    end

    local powerBombRadius = sm.getPowerBombPreRadius()
    local powerBombRadiusX = bit.rshift(powerBombRadius, 8)
    local powerBombRadiusY = bit.rshift(powerBombRadiusX * 0xBF, 8)

    calculatePowerBombHdmaTablePointers(powerBombRadius)
    calculatePowerBombHdmaDataTables_part1(powerBombRadiusX, powerBombRadiusY)
end

function adjustPowerBombPosition_stage2()
    local layer1Position = getLayer1Position()

    if layer1Position.x == cameraPosition.x and layer1Position.y == cameraPosition.y then
        return
    end

    local powerBombRadius = sm.getPowerBombPreRadius()
    local CF2 = mainmemory.read_u16_le(0x0CF2)

    calculatePowerBombHdmaTablePointers(powerBombRadius)
    calculatePowerBombHdmaDataTables_part2(CF2)
end

function adjustPowerBombPosition_stage3()
    local layer1Position = getLayer1Position()

    if layer1Position.x == cameraPosition.x and layer1Position.y == cameraPosition.y then
        return
    end

    local powerBombRadius = sm.getPowerBombRadius()
    local powerBombRadiusX = bit.rshift(powerBombRadius, 8)
    local powerBombRadiusY = bit.rshift(powerBombRadiusX * 0xBF, 8)

    calculatePowerBombHdmaTablePointers(powerBombRadius)
    calculatePowerBombHdmaDataTables_part1(powerBombRadiusX, powerBombRadiusY)
end

function adjustPowerBombPosition_stage4()
    local layer1Position = getLayer1Position()

    if layer1Position.x == cameraPosition.x and layer1Position.y == cameraPosition.y then
        return
    end

    local powerBombRadius = sm.getPowerBombRadius()
    local CF2 = mainmemory.read_u16_le(0x0CF2)

    calculatePowerBombHdmaTablePointers(powerBombRadius)
    calculatePowerBombHdmaDataTables_part2(CF2)
end

function handleHorizontalScrolling()
    local samusXPosition = sm.getSamusXPosition()
    local samusPreviousXPosition = sm.getSamusPreviousXPosition()

    if samusXPosition == samusPreviousXPosition then
        handleHorizontalAutoscrolling()
        return
    end

    local isScrollingRight = (sm.getSamusFacingDirection() ~= 4)
    if mainmemory.read_u16_le(0x0A52) ~= 0 or sm.getSamusMovementType() == 0x10 or mainmemory.read_u16_le(0x0B4A) == 1 then
        isScrollingRight = not isScrollingRight
    end

    local idealLayer1XPosition
    if isScrollingRight then
        idealLayer1XPosition = samusXPosition - romRead(0x90963F + sm.getCameraDistanceIndex(), 2)
    else
        idealLayer1XPosition = samusXPosition - romRead(0x909647 + sm.getCameraDistanceIndex(), 2)
    end

    if idealLayer1XPosition == cameraPosition.x then
        return
    end

    local xSubdistanceSamusMoved = sm.getXSubdistanceSamusMoved()
    local xDistanceSamusMoved = sm.getXDistanceSamusMoved()
    if idealLayer1XPosition > cameraPosition.x then
        -- Propagate carry
        if cameraPosition.subX + xSubdistanceSamusMoved >= 0x10000 then
            cameraPosition.x = cameraPosition.x + 1
        end
        cameraPosition.subX = (cameraPosition.subX + xSubdistanceSamusMoved) % 0x10000
        cameraPosition.x = cameraPosition.x + xDistanceSamusMoved
        scrollHandler_right(idealLayer1XPosition)
    else
        -- Propagate borrow
        if cameraPosition.subX - xSubdistanceSamusMoved < 0 then
            cameraPosition.x = cameraPosition.x - 1
        end
        cameraPosition.subX = (cameraPosition.subX - xSubdistanceSamusMoved) % 0x10000
        cameraPosition.x = cameraPosition.x - xDistanceSamusMoved
        scrollHandler_left(idealLayer1XPosition)
    end
end

function handleVerticalScrolling()
    local samusYPosition = sm.getSamusYPosition()
    local samusPreviousYPosition = sm.getSamusPreviousYPosition()

    if getSamusPreviousYPosition == samusPreviousYPosition then
        handleVerticalAutoscrolling()
        return
    end

    local idealLayer1YPosition
    if mainmemory.read_u16_le(0x0B36) ~= 1 then
        idealLayer1YPosition = samusYPosition - sm.getUpScroller()
    else
        idealLayer1YPosition = samusYPosition - sm.getDownScroller()
    end

    if idealLayer1YPosition == cameraPosition.y then
        return
    end

    local ySubdistanceSamusMoved = sm.getYSubdistanceSamusMoved()
    local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
    if idealLayer1YPosition > cameraPosition.y then
        if cameraPosition.subY + ySubdistanceSamusMoved >= 0x10000 then
            cameraPosition.y = cameraPosition.y + 1
        end
        cameraPosition.subY = (cameraPosition.subY + ySubdistanceSamusMoved) % 0x10000
        cameraPosition.y = cameraPosition.y + yDistanceSamusMoved
        scrollHandler_down(idealLayer1YPosition)
    else
        if cameraPosition.subY - ySubdistanceSamusMoved < 0 then
            cameraPosition.y = cameraPosition.y - 1
        end
        cameraPosition.subY = (cameraPosition.subY - ySubdistanceSamusMoved) % 0x10000
        cameraPosition.y = cameraPosition.y - yDistanceSamusMoved
        scrollHandler_up(idealLayer1YPosition)
    end
end

function handleHorizontalAutoscrolling()
    local newLayer1Position = cameraPosition
    local roomWidth = sm.getRoomWidth() * 16
    local scrolls = getScrolls()

    cameraPosition.x = clamp(cameraPosition.x, 0, roomWidth - 0x100)

    local cameraScrollX = bit.rshift(cameraPosition.x, 8)
    local cameraScrollY = bit.rshift(cameraPosition.y + 0x80, 8)
    if scrolls[cameraScrollY][cameraScrollX] == 0 then
        local rightScrollBoundary = bit.band(cameraPosition.x, 0xFF00) + 0x100
        local xDistanceSamusMoved = sm.getXDistanceSamusMoved()
        if newLayer1Position.x + xDistanceSamusMoved + 2 < rightScrollBoundary then
            newLayer1Position.x = newLayer1Position.x + xDistanceSamusMoved + 2
            cameraScrollX = bit.rshift(newLayer1Position.x, 8)
            if scrolls[cameraScrollY][cameraScrollX + 1] == nil or scrolls[cameraScrollY][cameraScrollX + 1] == 0 then
                cameraPosition.x = bit.band(newLayer1Position.x, 0xFF00)
            else
                cameraPosition.x = newLayer1Position.x
            end
        else
            cameraPosition.x = rightScrollBoundary
        end
    else
        if scrolls[cameraScrollY][cameraScrollX + 1] == nil or scrolls[cameraScrollY][cameraScrollX + 1] == 0 then
            local leftScrollBoundary = bit.band(cameraPosition.x, 0xFF00)
            local xDistanceSamusMoved = sm.getXDistanceSamusMoved()
            if newLayer1Position.x - xDistanceSamusMoved - 2 >= leftScrollBoundary then
                newLayer1Position.x = newLayer1Position.x - xDistanceSamusMoved - 2
                cameraScrollX = bit.rshift(newLayer1Position.x, 8)
                if scrolls[cameraScrollY][cameraScrollX] == 0 then
                    cameraPosition.x = bit.band(newLayer1Position.x, 0xFF00) + 0x100
                else
                    cameraPosition.x = newLayer1Position.x
                end
            else
                cameraPosition.x = leftScrollBoundary
            end
        end
    end
end

function handleVerticalAutoscrolling()
    local newLayer1Position = cameraPosition
    local roomHeight = sm.getRoomHeight() * 16
    local scrolls = getScrolls()

    local cameraScrollX = bit.rshift(cameraPosition.x + 0x80, 8)
    local cameraScrollY = bit.rshift(cameraPosition.y, 8)
    if scrolls[cameraScrollY][cameraScrollX] == 1 then
        cameraPosition.y = clamp(cameraPosition.y, 0, roomHeight - 0x100)
    else
        cameraPosition.y = clamp(cameraPosition.y, 0, roomHeight - 0x100 + 0x1F)
    end

    local cameraScrollY = bit.rshift(cameraPosition.y, 8)
    if scrolls[cameraScrollY][cameraScrollX] == 0 then
        local bottomScrollBoundary = bit.band(cameraPosition.y, 0xFF00) + 0x100
        local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
        if newLayer1Position.y + yDistanceSamusMoved + 2 < bottomScrollBoundary then
            newLayer1Position.y = newLayer1Position.y + yDistanceSamusMoved + 2
            cameraScrollY = bit.rshift(newLayer1Position.y, 8)
            if scrolls[cameraScrollY + 1] == nil or scrolls[cameraScrollY + 1][cameraScrollX] == 0 then
                cameraPosition.y = bit.band(newLayer1Position.y, 0xFF00)
            else
                cameraPosition.y = newLayer1Position.y
            end
        else
            cameraPosition.y = bottomScrollBoundary
        end
    else
        if scrolls[cameraScrollY + 1] == nil or scrolls[cameraScrollY + 1][cameraScrollX] == 0 then
            local topScrollBoundary = bit.band(cameraPosition.y, 0xFF00)
            local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
            if newLayer1Position.y - yDistanceSamusMoved - 2 >= topScrollBoundary then
                newLayer1Position.y = newLayer1Position.y - yDistanceSamusMoved - 2
                cameraScrollY = bit.rshift(newLayer1Position.y, 8)
                if scrolls[cameraScrollY][cameraScrollX] == 0 then
                    cameraPosition.y = bit.band(newLayer1Position.y, 0xFF00) + 0x100
                else
                    cameraPosition.y = newLayer1Position.y
                end
            else
                cameraPosition.y = topScrollBoundary
            end
        end
    end
end

function scrollHandler_right(idealLayer1XPosition)
    local newLayer1Position = cameraPosition
    local roomWidth = sm.getRoomWidth() * 16

    if cameraPosition.x > idealLayer1XPosition then
        cameraPosition.x = idealLayer1XPosition
        cameraPosition.subX = 0
    end

    if cameraPosition.x > roomWidth - 0x100 then
        cameraPosition.x = roomWidth - 0x100
    else
        local scrolls = getScrolls()
        local cameraScrollX = bit.rshift(cameraPosition.x, 8) + 1
        local cameraScrollY = bit.rshift(cameraPosition.y + 0x80, 8)
        if scrolls[cameraScrollY][cameraScrollX] == 0 then
            local leftScrollBoundary = bit.band(cameraPosition.x, 0xFF00)
            local xDistanceSamusMoved = sm.getXDistanceSamusMoved()
            cameraPosition.x = math.max(leftScrollBoundary, newLayer1Position.x - xDistanceSamusMoved - 2)
        end
    end
end

function scrollHandler_left(idealLayer1XPosition)
    local newLayer1Position = cameraPosition

    if cameraPosition.x < idealLayer1XPosition then
        cameraPosition.x = idealLayer1XPosition
        cameraPosition.subX = 0
    end

    if cameraPosition.x < 0 then
        cameraPosition.x = 0
    else
        local scrolls = getScrolls()
        local cameraScrollX = bit.rshift(cameraPosition.x, 8)
        local cameraScrollY = bit.rshift(cameraPosition.y + 0x80, 8)
        if scrolls[cameraScrollY][cameraScrollX] == 0 then
            local rightScrollBoundary = bit.band(cameraPosition.x, 0xFF00) + 0x100
            local xDistanceSamusMoved = sm.getXDistanceSamusMoved()
            cameraPosition.x = math.min(rightScrollBoundary, newLayer1Position.x + xDistanceSamusMoved + 2)
        end
    end
end

function scrollHandler_down(idealLayer1YPosition)
    local newLayer1Position = cameraPosition
    local roomHeight = sm.getRoomHeight() * 16
    local scrolls = getScrolls()

    local cameraScrollX = bit.rshift(cameraPosition.x + 0x80, 8)
    local cameraScrollY = bit.rshift(cameraPosition.y, 8)
    local Y_933
    if scrolls[cameraScrollY][cameraScrollX] == 1 then
        Y_933 = 0
    else
        Y_933 = 0x1F
    end

    if cameraPosition.y > idealLayer1YPosition then
        cameraPosition.y = idealLayer1YPosition
        cameraPosition.subY = 0
    end

    local topScrollBoundary = roomHeight - 0x100 + Y_933
    if topScrollBoundary >= cameraPosition.y then
        if scrolls[cameraScrollY + 1] == nil or scrolls[cameraScrollY + 1][cameraScrollX] == 0 then
            topScrollBoundary = bit.band(cameraPosition.y, 0xFF00) + Y_933
            if topScrollBoundary < cameraPosition.y then
                local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
                cameraPosition.y = math.max(topScrollBoundary, newLayer1Position.y - yDistanceSamusMoved - 2)
            end
        end
    else
        local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
        cameraPosition.y = math.max(topScrollBoundary, newLayer1Position.y - yDistanceSamusMoved - 2)
    end
end

function scrollHandler_up(idealLayer1YPosition)
    local newLayer1Position = cameraPosition

    if cameraPosition.y < idealLayer1YPosition then
        cameraPosition.y = idealLayer1YPosition
        cameraPosition.subY = 0
    end

    if cameraPosition.y < 0 then
        cameraPosition.y = 0
    else
        local scrolls = getScrolls()
        local cameraScrollX = bit.rshift(cameraPosition.x + 0x80, 8)
        local cameraScrollY = bit.rshift(cameraPosition.y, 8)
        if scrolls[cameraScrollY][cameraScrollX] == 0 then
            local bottomScrollBoundary = bit.band(cameraPosition.y, 0xFF00) + 0x100
            local yDistanceSamusMoved = sm.getYDistanceSamusMoved()
            cameraPosition.y = math.min(bottomScrollBoundary, newLayer1Position.y + yDistanceSamusMoved + 2)
        end
    end
end


function initialiseGlobals()
    -- Globals
    xrayOriginPosition = {x = 0, y = 0}
    cameraPosition = getLayer1Position()
    bg1Scroll_backup = getBg1Scroll()
    bg2Scroll_backup = getBg2Scroll()
    lavaAcidYPosition = 0xFFFF
    waterYPosition = 0xFFFF
    CE6 = mainmemory.read_u16_le(0x0CE6)

    -- Persistent state for drawViewableRoom
    previousLayer1XBlock = 0
    previousLayer1YBlock = 0
    previousLayer2XBlock = 0
    previousLayer2YBlock = 0
end

initialiseGlobals()


-- Reinitialise variables on loading savestate
event.onloadstate(initialiseGlobals)

-- Execute at end of non-lag branch of NMI handler,
-- noting that lag frames don't do graphical updates (this usefully excludes message boxes)
event.onmemoryexecute(drawViewableRoom, 0x8095F4)

-- Execute at beginning of non-lag branch of NMI handler
event.onmemoryexecute(nmiHook, 0x80959E)

-- Execute at beginning of BG scroll offset calculation
event.onmemoryexecute(fixBgScroll, 0x80AE29)

-- Execute when x-ray is activated
event.onmemoryexecute(recordXrayOrigin, 0x91D0D3)

-- Execute for the duration of lava/acid HDMA calculations
event.onmemoryexecute(adjustLavaAcidPosition, 0x88B3DE)
event.onmemoryexecute(restoreLavaAcidPosition, 0x88B477)

-- Execute for the duration of water HDMA calculations
event.onmemoryexecute(adjustWaterPosition, 0x88C4BE)
event.onmemoryexecute(restoreWaterPosition, 0x88C569)

-- Execute for the duration of power bomb HDMA calculations
-- Main explosion
event.onmemoryexecute(adjustPowerBombPosition_stage3, 0x888E55)
event.onmemoryexecute(adjustPowerBombPosition_stage4, 0x888EE5)

-- Pre-explosion
event.onmemoryexecute(adjustPowerBombPosition_stage1, 0x88914B)
event.onmemoryexecute(adjustPowerBombPosition_stage2, 0x8891DB)

-- Crystal flash
event.onmemoryexecute(adjustPowerBombPosition_stage3, 0x88A5BE)

-- Execute at the beginning of scrolling routine
event.onmemoryexecute(handleHorizontalScrolling, 0x9095A0)
event.onmemoryexecute(handleVerticalScrolling, 0x90964F)


-- Debug:
--[[
for k,v in pairs(memory.getmemorydomainlist()) do
    console.log(string.format('%X - %-10s - %Xh bytes', k, v, memory.getmemorydomainsize(v)))
end
--]]

while true do
    emu.frameadvance()
end
