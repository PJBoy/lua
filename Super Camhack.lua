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

The third problem - Samus goes off-screen (removed):
    It's easy enough to detect when Samus goes off-screen, ideally the camera would focus around Samus' position in that case.
    In order to make the camera follow Samus, I'll need to:
        Configure the room drawing relative to Samus' position and set the BG position registers accordingly
        Rewrite the positions of all sprites in OAM (either directly or via $0370)
        Optional: Detect bosses and handle layer 2 accordingly (not done)
        Optional: Make a smooth transition function from one camera source to the other (not done)
        Optional: Draw off-screen sprites, including: (not done)
            Samus
            Enemies
            Enemy projectiles
            Sprite objects
        Need to consider FX / HDMA effects like power bombs and water (not done)
        Optional: Keep camera within room boundaries

The fourth problem - x-ray prevents scrolling:
    X-ray and probably other things like R-mode or whatever prevent scrolling (via $0A78)
    The fix here is to force scrolling manually by setting the BG positions every frame
--]]

console.clear()

-- Note that BizHawk requires a restart if any included files are modified
sm = require("Super Metroid")

function vramWrite(p, v)
    -- In SNES land, VRAM is addressed with 16-bit bytes with address space $0000..7FFF;
    -- in emu land, VRAM is addressed with the usual 8-bit bytes with address space $0000..FFFF
    memory.write_u16_le(bit.band(p, 0x7FFF) * 2, v, "VRAM")
end

function isValidLevelData()
    -- The screen refresh should only be done when the game is in a valid state to draw the level data.
    -- Game state 8 is main gameplay, level data is always valid.
    -- Game states 9, Ah and Bh are the various stages of going through a door,
    -- the level data is only invalid when the door transition function is $E36E during game state Bh.
    -- Game states Ch..12h are the various stages of pausing and unpausing,
    -- the level data is only invalid during game states Eh..10h
    -- Game state 2Ah is the demo
    local gameState = sm.getGameState()
    local doorTransitionFunction = sm.getDoorTransitionFunction()

    return
           8 <= gameState and gameState < 0xB
        or 0xC <= gameState and gameState < 0xE
        or 0x11 <= gameState and gameState < 0x13
        or 0x2A == gameState
        --or gameState == 0xB and doorTransitionFunction ~= 0xE36E
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
    setBg1Scroll(bg1Scroll_backup)
    setBg2Scroll(bg2Scroll_backup)

    if not isValidLevelData() or sm.getMode7Flag() ~= 0 or sm.getElevatorState() ~= 0 then
        return
    end

    local layer1Position = getLayer1Position()
    local layer1XBlock = bit.arshift(layer1Position.x, 4)
    local layer1YBlock = bit.arshift(layer1Position.y, 4)

    if
           math.abs(layer1XBlock - previousLayer1XBlock) > 1
        or math.abs(layer1YBlock - previousLayer1YBlock) > 1
        or sm.getFrozenTimeFlag() ~= 0
    then
        local bg1VramBaseAddress = bit.band(sm.getBg1TilemapOptions(), 0xFC) * 0x100
        drawLayer(bg1VramBaseAddress, sm.getBg1ScrollXOffset(), layer1XBlock, layer1YBlock, sm.getLevelDatum)
    end

    previousLayer1XBlock = layer1XBlock
    previousLayer1YBlock = layer1YBlock

    local isCustomLayer2 = (1 - bit.band(sm.getLayer2XScroll(), 1)) * (1 - bit.band(sm.getLayer2YScroll(), 1))
    if isCustomLayer2 ~= 0 then
        local layer2XBlock, layer2YBlock

        local layer2XPosition = calculateLayer2Coordinate(layer1Position.x, sm.getLayer2XScroll())
        if layer2XPosition ~= nil then
            layer2XBlock = bit.arshift(layer2XPosition, 4)
        else
            layer2XBlock = previousLayer2XBlock
        end

        local layer2YPosition = calculateLayer2Coordinate(layer1Position.y, sm.getLayer2YScroll())
        if layer2YPosition ~= nil then
            layer2YBlock = bit.arshift(layer2YPosition, 4)
        else
            layer2YBlock = previousLayer2YBlock
        end

        if
               math.abs(layer2XBlock - previousLayer2XBlock) > 1
            or math.abs(layer2YBlock - previousLayer2YBlock) > 1
        then
            local bg2VramBaseAddress = bit.band(sm.getBg2TilemapOptions(), 0xFC) * 0x100
            drawLayer(bg2VramBaseAddress, sm.getBg2ScrollXOffset(), layer2XBlock, layer2YBlock, sm.getBackgroundDatum)
        end

        previousLayer2XBlock = layer2XBlock
        previousLayer2YBlock = layer2YBlock
    end
end

function fixBgScroll()
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

function calculateLayer2Coordinate(v, layer2Scroll)
    if layer2Scroll == 0 then
        return v
    elseif layer2Scroll == 1 then
        return nil
    else
        return bit.arshift(v * bit.rshift(layer2Scroll, 1), 7)
    end
end

function getLayer1Position()
    return
    {
        x = sm.getLayer1XPosition(),
        y = sm.getLayer1YPosition()
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

function recordXrayOrigin()
    xrayOriginPosition = getBg1Scroll()
    xrayOriginPosition.x = bit.band(xrayOriginPosition.x, 0xFFF0)
    xrayOriginPosition.y = bit.band(xrayOriginPosition.y, 0xFFF0)
end

-- Globals
xrayOriginPosition = {x = 0, y = 0}
bg1Scroll_backup = getBg1Scroll()
bg2Scroll_backup = getBg2Scroll()

-- Persistent state for drawViewableRoom
previousLayer1XBlock = 0
previousLayer1YBlock = 0
previousLayer2XBlock = 0
previousLayer2YBlock = 0

-- Execute at end of non-lag branch of NMI handler,
-- noting that lag frames don't do graphical updates (this usefully excludes message boxes)
event.onmemoryexecute(drawViewableRoom, 0x8095F4)

-- Execute at beginning of BG scroll offset calculation
event.onmemoryexecute(fixBgScroll, 0x80AE29)

event.onmemoryexecute(recordXrayOrigin, 0x91D0D3)

-- Debug:
--[[
for k,v in pairs(memory.getmemorydomainlist()) do
    console.log(string.format('%X - %-10s - %Xh bytes', k, v, memory.getmemorydomainsize(v)))
end
--]]

while true do
    -- BizHawk won't let me set the hardware registers, so I'm relying on the game's hardware register update, which occurs during NMI.
    -- Thus, I'm setting the game's mirror of BG1/2 scroll at the beginning of NMI and reverting them at the end of NMI, so that the game's behaviour can't change.
    bg1Scroll_backup = getBg1Scroll()
    bg2Scroll_backup = getBg2Scroll()

    if isValidLevelData() and sm.getMode7Flag() == 0 and sm.getElevatorState() == 0 then
        local layer1Position = getLayer1Position()
        local frozenTime = sm.getFrozenTimeFlag()

        -- Emulate earthquakes
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
        
        sm.setBg1ScrollX(layer1Position.x + bg1XOffset + sm.getBg1ScrollXOffset())
        sm.setBg1ScrollY(layer1Position.y + bg1YOffset + sm.getBg1ScrollYOffset())
        
        if frozenTime ~= 0 then
            -- X-ray is active
            sm.setBg2ScrollX(bit.band(sm.getBg1ScrollX() - xrayOriginPosition.x, 0xFFFF))
            sm.setBg2ScrollY(bit.band(sm.getBg1ScrollY() - xrayOriginPosition.y, 0xFFFF))
        else
            local layer2XPosition = calculateLayer2Coordinate(layer1Position.x, sm.getLayer2XScroll())
            if layer2XPosition ~= nil then
                sm.setBg2ScrollX(layer2XPosition + bg2XOffset + sm.getBg2ScrollXOffset())
            end

            local layer2YPosition = calculateLayer2Coordinate(layer1Position.y, sm.getLayer2YScroll())
            if layer2YPosition ~= nil then
                sm.setBg2ScrollY(layer2YPosition + bg2YOffset + sm.getBg2ScrollYOffset())
            end
        end
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

    --gui.drawText(8, 32, string.format('Frozen time: %04X', memory.read_u8(0x0A78, "WRAM")), 'white', 'black')
    --]]

    emu.frameadvance()
end
