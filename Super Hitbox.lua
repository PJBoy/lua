-- If lsnes complains about "module 'Super Metroid' not found", uncomment the next line and provide the path to the "Super Metroid.lua" file
-- package.path = "C:\\Games\\Lua\\Super Metroid.lua"
-- If Mesen complains about `require` not being recognised, you need to enable Lua IO access in the settings
local xemu = require("cross emu")
local sm = require("Super Metroid")

if console and console.clear then
    console.clear()
elseif print then
    print("\n\n\n\n\n\n\n\n")
    print("\n\n\n\n\n\n\n\n")
end

if gui and gui.clearGraphics then
    gui.clearGraphics()
elseif emu and emu.clearScreen then
    emu.clearScreen()
end

-- Globals
local recordLagHotspots = true
local debugControlsEnabled = 1
local debugFlag = 0
local debugInfoFlag = 0
local doorListFlag = 0
local followSamusFlag = 0--sm.button_B
local tasFlag = 0
local logFlag = 0
local xAdjust = 0
local yAdjust = 0
local doorList = {}

-- Colour constants
local colour_opacity = 0x80

local colour_slope        = 0x00FF0000 + xemu.rshift(colour_opacity, 1)
local colour_solidBlock   = 0xFF000000 + colour_opacity
local colour_specialBlock = 0x0000FF00 + colour_opacity
local colour_doorBlock    = 0x00FFFF00 + colour_opacity
local colour_doorcap      = 0xFF800000 + colour_opacity
local colour_errorBlock   = 0x8000FF00 + colour_opacity

local colour_scroll_red   = 0xFF000000 + xemu.rshift(colour_opacity, 1)
local colour_scroll_blue  = 0x0000FF00 + xemu.rshift(colour_opacity, 1)
local colour_scroll_green = 0x00FF0000 + xemu.rshift(colour_opacity, 1)

local colour_enemy           = 0xFFFFFF00 + colour_opacity
local colour_spriteObject    = 0xFF800000 + colour_opacity
local colour_enemyProjectile = 0x00FF0000 + colour_opacity
local colour_powerBomb       = 0xFFFFFF00 + colour_opacity
local colour_projectile      = 0xFFFF0000 + colour_opacity
local colour_samus           = 0x00FFFF00 + colour_opacity
local colour_camera          = 0x80808000 + colour_opacity

-- Add padding borders in BizHawk (highly resource intensive)
local xExtra = 0
local yExtra = 0
if xemu.emuId == xemu.emuId_bizhawk then
    --xExtra = 256
    --yExtra = 224
    client.SetGameExtraPadding(xExtra, yExtra, xExtra, yExtra)
end

local xExtraBlocks = xemu.rshift(xExtra, 4)
local yExtraBlocks = xemu.rshift(yExtra, 4)

local xExtraScrolls = xemu.rshift(xExtraBlocks, 4)
local yExtraScrolls = xemu.rshift(yExtraBlocks, 4)

-- Adjust drawing to account for the borders
function drawText(x, y, text, fg, bg)
    xemu.drawText(x + xExtra, y + yExtra, text, fg, bg or "black")
end

function drawBox(x0, y0, x1, y1, fg, bg)
    xemu.drawBox(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg, bg or "clear")
end

function drawLine(x0, y0, x1, y1, fg)
    xemu.drawLine(x0 + xExtra, y0 + yExtra, x1 + xExtra, y1 + yExtra, fg)
end

function drawRightTriangle(x0, y0, x1, y1, fg)
    drawLine(x0, y0, x1, y1, fg)
    drawLine(x0, y0, x1, y0, fg)
    drawLine(x1, y0, x1, y1, fg)
end

-- Display CPU usage
if xemu.emuId == xemu.emuId_bizhawk and false then -- GUI drawing functions from on_paint are clearing this text output for some reason...
    idling = false
    lagFrames = 0
    if recordLagHotspots then
        outfile = io.open("lag.txt", "w")
    end

    function idleHook()
        -- Report CPU time used by current frame
        -- NMI occurs at v = 225
        local v = emu.getregister('V')
        local cpu = lagFrames * 100 + (v - 225) % 262 * 100 / 262
        if recordLagHotspots and 100 <= cpu and cpu < 110 then
            outfile:write(string.format("%d: %f\n", emu.framecount(), cpu))
            console.log(string.format("%d: %f", emu.framecount(), cpu))
        end
        drawText(4, 36, string.format('CPU used: %.2f%%', cpu), cpu < 100 and "white" or "red", 0x000000FF)

        idling = true
        lagFrames = 0
    end

    function nmiHook()
        if not idling then
            lagFrames = lagFrames + 1
            drawText(4, 36, string.format('CPU used: %.2f%%', lagFrames * 100), "red", 0x000000FF)
        end

        idling = false
    end

    event.onmemoryexecute(nmiHook, 0x009583)
    event.onmemoryexecute(idleHook, 0x82897A)
end


-- A door database for finding valid OoB doors
local doors = {[0x88FE]=true, [0x890A]=true, [0x8916]=true, [0x8922]=true, [0x892E]=true, [0x893A]=true, [0x8946]=true, [0x8952]=true, [0x895E]=true, [0x896A]=true, [0x8976]=true, [0x8982]=true, [0x898E]=true, [0x899A]=true, [0x89A6]=true, [0x89B2]=true, [0x89BE]=true, [0x89CA]=true, [0x89D6]=true, [0x89E2]=true, [0x89EE]=true, [0x89FA]=true, [0x8A06]=true, [0x8A12]=true, [0x8A1E]=true, [0x8A2A]=true, [0x8A36]=true, [0x8A42]=true, [0x8A4E]=true, [0x8A5A]=true, [0x8A66]=true, [0x8A72]=true, [0x8A7E]=true, [0x8A8A]=true, [0x8A96]=true, [0x8AA2]=true, [0x8AAE]=true, [0x8ABA]=true, [0x8AC6]=true, [0x8AD2]=true, [0x8ADE]=true, [0x8AEA]=true, [0x8AF6]=true, [0x8B02]=true, [0x8B0E]=true, [0x8B1A]=true, [0x8B26]=true, [0x8B32]=true, [0x8B3E]=true, [0x8B4A]=true, [0x8B56]=true, [0x8B62]=true, [0x8B6E]=true, [0x8B7A]=true, [0x8B86]=true, [0x8B92]=true, [0x8B9E]=true, [0x8BAA]=true, [0x8BB6]=true, [0x8BC2]=true, [0x8BCE]=true, [0x8BDA]=true, [0x8BE6]=true, [0x8BF2]=true, [0x8BFE]=true, [0x8C0A]=true, [0x8C16]=true, [0x8C22]=true, [0x8C2E]=true, [0x8C3A]=true, [0x8C46]=true, [0x8C52]=true, [0x8C5E]=true, [0x8C6A]=true, [0x8C76]=true, [0x8C82]=true, [0x8C8E]=true, [0x8C9A]=true, [0x8CA6]=true, [0x8CB2]=true, [0x8CBE]=true, [0x8CCA]=true, [0x8CD6]=true, [0x8CE2]=true, [0x8CEE]=true, [0x8CFA]=true, [0x8D06]=true, [0x8D12]=true, [0x8D1E]=true, [0x8D2A]=true, [0x8D36]=true, [0x8D42]=true, [0x8D4E]=true, [0x8D5A]=true, [0x8D66]=true, [0x8D72]=true, [0x8D7E]=true, [0x8D8A]=true, [0x8D96]=true, [0x8DA2]=true, [0x8DAE]=true, [0x8DBA]=true, [0x8DC6]=true, [0x8DD2]=true, [0x8DDE]=true, [0x8DEA]=true, [0x8DF6]=true, [0x8E02]=true, [0x8E0E]=true, [0x8E1A]=true, [0x8E26]=true, [0x8E32]=true, [0x8E3E]=true, [0x8E4A]=true, [0x8E56]=true, [0x8E62]=true, [0x8E6E]=true, [0x8E7A]=true, [0x8E86]=true, [0x8E92]=true, [0x8E9E]=true, [0x8EAA]=true, [0x8EB6]=true, [0x8EC2]=true, [0x8ECE]=true, [0x8EDA]=true, [0x8EE6]=true, [0x8EF2]=true, [0x8EFE]=true, [0x8F0A]=true, [0x8F16]=true, [0x8F22]=true, [0x8F2E]=true, [0x8F3A]=true, [0x8F46]=true, [0x8F52]=true, [0x8F5E]=true, [0x8F6A]=true, [0x8F76]=true, [0x8F82]=true, [0x8F8E]=true, [0x8F9A]=true, [0x8FA6]=true, [0x8FB2]=true, [0x8FBE]=true, [0x8FCA]=true, [0x8FD6]=true, [0x8FE2]=true, [0x8FEE]=true, [0x8FFA]=true, [0x9006]=true, [0x9012]=true, [0x901E]=true, [0x902A]=true, [0x9036]=true, [0x9042]=true, [0x904E]=true, [0x905A]=true, [0x9066]=true, [0x9072]=true, [0x907E]=true, [0x908A]=true, [0x9096]=true, [0x90A2]=true, [0x90AE]=true, [0x90BA]=true, [0x90C6]=true, [0x90D2]=true, [0x90DE]=true, [0x90EA]=true, [0x90F6]=true, [0x9102]=true, [0x910E]=true, [0x911A]=true, [0x9126]=true, [0x9132]=true, [0x913E]=true, [0x914A]=true, [0x9156]=true, [0x9162]=true, [0x916E]=true, [0x917A]=true, [0x9186]=true, [0x9192]=true, [0x919E]=true, [0x91AA]=true, [0x91B6]=true, [0x91C2]=true, [0x91CE]=true, [0x91DA]=true, [0x91E6]=true, [0x91F2]=true, [0x91FE]=true, [0x920A]=true, [0x9216]=true, [0x9222]=true, [0x922E]=true, [0x923A]=true, [0x9246]=true, [0x9252]=true, [0x925E]=true, [0x926A]=true, [0x9276]=true, [0x9282]=true, [0x928E]=true, [0x929A]=true, [0x92A6]=true, [0x92B2]=true, [0x92BE]=true, [0x92CA]=true, [0x92D6]=true, [0x92E2]=true, [0x92EE]=true, [0x92FA]=true, [0x9306]=true, [0x9312]=true, [0x931E]=true, [0x932A]=true, [0x9336]=true, [0x9342]=true, [0x934E]=true, [0x935A]=true, [0x9366]=true, [0x9372]=true, [0x937E]=true, [0x938A]=true, [0x9396]=true, [0x93A2]=true, [0x93AE]=true, [0x93BA]=true, [0x93C6]=true, [0x93D2]=true, [0x93DE]=true, [0x93EA]=true, [0x93F6]=true, [0x9402]=true, [0x940E]=true, [0x941A]=true, [0x9426]=true, [0x9432]=true, [0x943E]=true, [0x944A]=true, [0x9456]=true, [0x9462]=true, [0x946E]=true, [0x947A]=true, [0x9486]=true, [0x9492]=true, [0x949E]=true, [0x94AA]=true, [0x94B6]=true, [0x94C2]=true, [0x94CE]=true, [0x94DA]=true, [0x94E6]=true, [0x94F2]=true, [0x94FE]=true, [0x950A]=true, [0x9516]=true, [0x9522]=true, [0x952E]=true, [0x953A]=true, [0x9546]=true, [0x9552]=true, [0x955E]=true, [0x956A]=true, [0x9576]=true, [0x9582]=true, [0x958E]=true, [0x959A]=true, [0x95A6]=true, [0x95B2]=true, [0x95BE]=true, [0x95CA]=true, [0x95D6]=true, [0x95E2]=true, [0x95EE]=true, [0x95FA]=true, [0x9606]=true, [0x9612]=true, [0x961E]=true, [0x962A]=true, [0x9636]=true, [0x9642]=true, [0x964E]=true, [0x965A]=true, [0x9666]=true, [0x9672]=true, [0x967E]=true, [0x968A]=true, [0x9696]=true, [0x96A2]=true, [0x96AE]=true, [0x96BA]=true, [0x96C6]=true, [0x96D2]=true, [0x96DE]=true, [0x96EA]=true, [0x96F6]=true, [0x9702]=true, [0x970E]=true, [0x971A]=true, [0x9726]=true, [0x9732]=true, [0x973E]=true, [0x974A]=true, [0x9756]=true, [0x9762]=true, [0x976E]=true, [0x977A]=true, [0x9786]=true, [0x9792]=true, [0x979E]=true, [0x97AA]=true, [0x97B6]=true, [0x97C2]=true, [0x97CE]=true, [0x97DA]=true, [0x97E6]=true, [0x97F2]=true, [0x97FE]=true, [0x980A]=true, [0x9816]=true, [0x9822]=true, [0x982E]=true, [0x983A]=true, [0x9846]=true, [0x9852]=true, [0x985E]=true, [0x986A]=true, [0x9876]=true, [0x9882]=true, [0x988E]=true, [0x989A]=true, [0x98A6]=true, [0x98B2]=true, [0x98BE]=true, [0x98CA]=true, [0x98D6]=true, [0x98E2]=true, [0x98EE]=true, [0x98FA]=true, [0x9906]=true, [0x9912]=true, [0x991E]=true, [0x992A]=true, [0x9936]=true, [0x9942]=true, [0x994E]=true, [0x995A]=true, [0x9966]=true, [0x9972]=true, [0x997E]=true, [0x998A]=true, [0x9996]=true, [0x99A2]=true, [0x99AE]=true, [0x99BA]=true, [0x99C6]=true, [0x99D2]=true, [0x99DE]=true, [0x99EA]=true, [0x99F6]=true, [0x9A02]=true, [0x9A0E]=true, [0x9A1A]=true, [0x9A26]=true, [0x9A32]=true, [0x9A3E]=true, [0x9A4A]=true, [0x9A56]=true, [0x9A62]=true, [0x9A6E]=true, [0x9A7A]=true, [0x9A86]=true, [0x9A92]=true, [0x9A9E]=true, [0x9AAA]=true, [0x9AB6]=true, [0xA18C]=true, [0xA198]=true, [0xA1A4]=true, [0xA1B0]=true, [0xA1BC]=true, [0xA1C8]=true, [0xA1D4]=true, [0xA1E0]=true, [0xA1EC]=true, [0xA1F8]=true, [0xA204]=true, [0xA210]=true, [0xA21C]=true, [0xA228]=true, [0xA234]=true, [0xA240]=true, [0xA24C]=true, [0xA258]=true, [0xA264]=true, [0xA270]=true, [0xA27C]=true, [0xA288]=true, [0xA294]=true, [0xA2A0]=true, [0xA2AC]=true, [0xA2B8]=true, [0xA2C4]=true, [0xA2D0]=true, [0xA2DC]=true, [0xA2E8]=true, [0xA2F4]=true, [0xA300]=true, [0xA30C]=true, [0xA318]=true, [0xA324]=true, [0xA330]=true, [0xA33C]=true, [0xA348]=true, [0xA354]=true, [0xA360]=true, [0xA36C]=true, [0xA378]=true, [0xA384]=true, [0xA390]=true, [0xA39C]=true, [0xA3A8]=true, [0xA3B4]=true, [0xA3C0]=true, [0xA3CC]=true, [0xA3D8]=true, [0xA3E4]=true, [0xA3F0]=true, [0xA3FC]=true, [0xA408]=true, [0xA414]=true, [0xA420]=true, [0xA42C]=true, [0xA438]=true, [0xA444]=true, [0xA450]=true, [0xA45C]=true, [0xA468]=true, [0xA474]=true, [0xA480]=true, [0xA48C]=true, [0xA498]=true, [0xA4A4]=true, [0xA4B0]=true, [0xA4BC]=true, [0xA4C8]=true, [0xA4D4]=true, [0xA4E0]=true, [0xA4EC]=true, [0xA4F8]=true, [0xA504]=true, [0xA510]=true, [0xA51C]=true, [0xA528]=true, [0xA534]=true, [0xA540]=true, [0xA54C]=true, [0xA558]=true, [0xA564]=true, [0xA570]=true, [0xA57C]=true, [0xA588]=true, [0xA594]=true, [0xA5A0]=true, [0xA5AC]=true, [0xA5B8]=true, [0xA5C4]=true, [0xA5D0]=true, [0xA5DC]=true, [0xA5E8]=true, [0xA5F4]=true, [0xA600]=true, [0xA60C]=true, [0xA618]=true, [0xA624]=true, [0xA630]=true, [0xA63C]=true, [0xA648]=true, [0xA654]=true, [0xA660]=true, [0xA66C]=true, [0xA678]=true, [0xA684]=true, [0xA690]=true, [0xA69C]=true, [0xA6A8]=true, [0xA6B4]=true, [0xA6C0]=true, [0xA6CC]=true, [0xA6D8]=true, [0xA6E4]=true, [0xA6F0]=true, [0xA6FC]=true, [0xA708]=true, [0xA714]=true, [0xA720]=true, [0xA72C]=true, [0xA738]=true, [0xA744]=true, [0xA750]=true, [0xA75C]=true, [0xA768]=true, [0xA774]=true, [0xA780]=true, [0xA78C]=true, [0xA798]=true, [0xA7A4]=true, [0xA7B0]=true, [0xA7BC]=true, [0xA7C8]=true, [0xA7D4]=true, [0xA7E0]=true, [0xA7EC]=true, [0xA7F8]=true, [0xA810]=true, [0xA828]=true, [0xA834]=true, [0xA840]=true, [0xA84C]=true, [0xA858]=true, [0xA864]=true, [0xA870]=true, [0xA87C]=true, [0xA888]=true, [0xA894]=true, [0xA8A0]=true, [0xA8AC]=true, [0xA8B8]=true, [0xA8C4]=true, [0xA8D0]=true, [0xA8DC]=true, [0xA8E8]=true, [0xA8F4]=true, [0xA900]=true, [0xA90C]=true, [0xA918]=true, [0xA924]=true, [0xA930]=true, [0xA93C]=true, [0xA948]=true, [0xA954]=true, [0xA960]=true, [0xA96C]=true, [0xA978]=true, [0xA984]=true, [0xA990]=true, [0xA99C]=true, [0xA9A8]=true, [0xA9B4]=true, [0xA9C0]=true, [0xA9CC]=true, [0xA9D8]=true, [0xA9E4]=true, [0xA9F0]=true, [0xA9FC]=true, [0xAA08]=true, [0xAA14]=true, [0xAA20]=true, [0xAA2C]=true, [0xAA38]=true, [0xAA44]=true, [0xAA50]=true, [0xAA5C]=true, [0xAA68]=true, [0xAA74]=true, [0xAA80]=true, [0xAA8C]=true, [0xAA98]=true, [0xAAA4]=true, [0xAAB0]=true, [0xAABC]=true, [0xAAC8]=true, [0xAAD4]=true, [0xAAE0]=true, [0xAAEC]=true, [0xAAF8]=true, [0xAB04]=true, [0xAB10]=true, [0xAB1C]=true, [0xAB28]=true, [0xAB34]=true, [0xAB40]=true, [0xAB4C]=true, [0xAB58]=true, [0xAB64]=true, [0xAB70]=true, [0xAB7C]=true, [0xAB88]=true, [0xAB94]=true, [0xABA0]=true, [0xABAC]=true, [0xABB8]=true, [0xABC4]=true, [0xABCF]=true, [0xABDA]=true, [0xABE5]=true}


-- Draw standard block outline
function standardOutline(colour)
    return function(blockX, blockY, blockIndex, stackLimit)
        drawBox(blockX, blockY, blockX + 15, blockY + 15, colour, "clear")
    end
end

-- Block drawing functions
-- For reasons unbeknownst to me, the recursive calls (for the extension blocks) require this table to be global
outline = {
    -- Air
    [0x00] = function(blockX, blockY, blockIndex, stackLimit) end,

    -- Slope
    [0x01] = function(blockX, blockY, blockIndex, stackLimit)
        local bts = sm.getBts(blockIndex)
        local i_slope = xemu.and_(bts, 0x1F)
        local flip_x = xemu.and_(bts, 0x40) ~= 0
        local flip_y = xemu.and_(bts, 0x80) ~= 0
        
        local p_slope = 0x948B2B + i_slope * 0x10
        
        local ys = {}
        for x = 0, 0xF do
            local i = x
            if flip_x then
                i = 0xF - x
            end
            
            local y = xemu.read_u8(p_slope + i)
            if flip_y and y < 0x10 then
                y = 0xF - y
            end
            
            ys[x] = y
        end
        
        local x_min
        for x = 0, 0xF do
            if ys[x] < 0x10 then
                x_min = x
                break
            end
        end
        
        if x_min == nil then
            return
        end
        
        local x_max
        for i = 0, 0xF do
            local x = 0xF - i
            if ys[x] < 0x10 then
                x_max = x
                break
            end
        end
        
        local y_base = 0xF
        if flip_y then
            y_base = 0xF - y_base
        end
        
        xemu.drawLine(blockX + x_min, blockY + y_base, blockX + x_min, blockY + ys[x_min], colour_slope)
        
        for x = x_min + 1, x_max do
            if ys[x - 1] < 0x10 and ys[x] < 0x10 then
                xemu.drawLine(blockX + x, blockY + ys[x - 1], blockX + x, blockY + ys[x], colour_slope)
            end
        end
        
        xemu.drawLine(blockX + x_max, blockY + y_base, blockX + x_max, blockY + ys[x_max], colour_slope)
        xemu.drawLine(blockX + x_min, blockY + y_base, blockX + x_max, blockY + y_base, colour_slope)
    end,

    -- Spike air
    [0x02] = function(blockX, blockY, blockIndex, stackLimit) end,

    -- Special air
    [0x03] = standardOutline(colour_specialBlock),

    -- Shootable air
    [0x04] = function(blockX, blockY, blockIndex, stackLimit) end,

    -- Horizontal extension
    [0x05] = function (blockX, blockY, blockIndex, stackLimit)
        -- Prevents infinite recursion
        if stackLimit == 0 then
            standardOutline(colour_errorBlock)(blockX, blockY, blockIndex, stackLimit)
            return
        end

        stackLimit = stackLimit - 1
        local bts = sm.getBtsSigned(blockIndex)

        -- Infinite recursion, game would probably freeze if this block reacts to anything
        if bts == 0 then
            standardOutline(colour_errorBlock)(blockX, blockY, blockIndex, stackLimit)
            return
        end

        blockIndex = blockIndex + bts
        outline[xemu.rshift(sm.getLevelDatum(blockIndex), 12)](blockX, blockY, blockIndex, stackLimit)
    end,

    -- Unused air
    [0x06] = function(blockX, blockY, blockIndex, stackLimit) end,

    -- Bombable air
    [0x07] = function(blockX, blockY, blockIndex, stackLimit) end,

    -- Solid block
    [0x08] = standardOutline(colour_solidBlock),

    -- Door block
    [0x09] = standardOutline(colour_doorBlock),

    -- Spike block
    [0x0A] = standardOutline(colour_specialBlock),

    -- Special block
    [0x0B] = standardOutline(colour_specialBlock),

    -- Shootable block
    [0x0C] = function(blockX, blockY, blockIndex, stackLimit)
        -- Colour doors specially
        local bts = sm.getBts(blockIndex)
        if bts >= 0x40 and bts <= 0x43 then
            standardOutline(colour_doorcap)(blockX, blockY, blockIndex, stackLimit)
        else
            standardOutline(colour_specialBlock)(blockX, blockY, blockIndex, stackLimit)
        end
    end,

    -- Vertical extension
    [0x0D] = function(blockX, blockY, blockIndex, stackLimit)
        -- Prevents infinite recursion
        if stackLimit == 0 then
            standardOutline(colour_errorBlock)(blockX, blockY, blockIndex, stackLimit)
            return
        end

        stackLimit = stackLimit - 1
        local bts = sm.getBtsSigned(blockIndex)

        -- Infinite recursion, game would probably freeze if this block reacts to anything
        if bts == 0 then
            standardOutline(colour_errorBlock)(blockX, blockY, blockIndex, stackLimit)
            return
        end

        blockIndex = blockIndex + bts * sm.getRoomWidth()
        outline[xemu.rshift(sm.getLevelDatum(blockIndex), 12)](blockX, blockY, blockIndex, stackLimit)
    end,

    -- Grapple block
    [0x0E] = standardOutline(colour_specialBlock),

    -- Bombable block
    [0x0F] = standardOutline(colour_specialBlock)
}


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
        or gameState == 0xB and doorTransitionFunction ~= 0xE36E
end

function handleDebugControls()
    local input = sm.getInput()
    local changedInput = sm.getChangedInput()

    if xemu.and_(input, sm.button_select) == 0 then
        return
    end

    -- Show the clipdata and BTS of every block on screen
    debugFlag = xemu.xor(debugFlag, xemu.and_(changedInput, sm.button_A))

    -- Show the list of (possibly OoB) door block BTS that exist
    doorListFlag = debugFlag

    -- Lock camera to Samus' position
    followSamusFlag = xemu.xor(followSamusFlag, xemu.and_(changedInput, sm.button_B))

    -- Initialise door list
    for i = 0,0x7F do
        doorList[i] = 0
    end

    if xemu.and_(input, sm.button_A) ~= 0 then
        -- These move the Samus around
        local samusXPosition = sm.getSamusXPosition()
        local samusYPosition = sm.getSamusYPosition()
        samusXPosition = xemu.and_(samusXPosition +             xemu.and_(changedInput, sm.button_right),    0xFFFF)
        samusXPosition = xemu.and_(samusXPosition - xemu.rshift(xemu.and_(changedInput, sm.button_left), 1), 0xFFFF)
        samusYPosition = xemu.and_(samusYPosition + xemu.rshift(xemu.and_(changedInput, sm.button_down), 2), 0xFFFF)
        samusYPosition = xemu.and_(samusYPosition - xemu.rshift(xemu.and_(changedInput, sm.button_up),   3), 0xFFFF)
        sm.setSamusXPosition(samusXPosition)
        sm.setSamusYPosition(samusYPosition)
    else
        -- These move the camera around
        xAdjust = xAdjust + xemu.rshift(xemu.and_(changedInput, sm.button_right), 8) * 256
        xAdjust = xAdjust - xemu.rshift(xemu.and_(changedInput, sm.button_left),  9) * 256
        yAdjust = yAdjust + xemu.rshift(xemu.and_(changedInput, sm.button_down), 10) * 224
        yAdjust = yAdjust - xemu.rshift(xemu.and_(changedInput, sm.button_up),   11) * 224
    end
end

function displayScrollBoundaries(cameraX, cameraY, roomWidth)
    for y = -yExtraScrolls, yExtraScrolls + 1 do
        for x = -xExtraScrolls, xExtraScrolls + 1 do
            local scrollX = x * 0x100 - xemu.and_(cameraX, 0xFF)
            local scrollY = y * 0x100 - xemu.and_(cameraY, 0xFF)

            local scroll = sm.getScroll((xemu.rshift(cameraY + y * 0x100, 8)) * xemu.rshift(roomWidth, 4) + xemu.rshift(cameraX + x * 0x100, 8))

            local colour = colour_scroll_red
            if scroll == 1 then
                colour = colour_scroll_blue
            elseif scroll == 2 then
                colour = colour_scroll_green
            end

            drawBox(scrollX, scrollY, scrollX + 0xFF, scrollY + 0xFF, colour)
            --drawBox(scrollX, scrollY, scrollX + 0xFF, scrollY + 0xFF, colour, colour)
        end
    end
end

function displayCameraMargin()
    local cameraDistanceIndex = sm.getCameraDistanceIndex()
    
    local top = sm.getUpScroller()
    local bottom = sm.getDownScroller()
    local left = xemu.read_u16_le(0x90963F + cameraDistanceIndex)
    local right = xemu.read_u16_le(0x909647 + cameraDistanceIndex)
    
    drawBox(left, top, right, bottom, colour_camera)
end

function displayBlocks(cameraX, cameraY, roomWidth)
    for y = -yExtraBlocks,14 + yExtraBlocks do
        for x = -xExtraBlocks,16 + xExtraBlocks do
            -- Impose a limit on the number of block extensions allowed, otherwise infinite loops can occur
            local stackLimit = 224

            -- Align block outlines graphically
            local blockX = x * 0x10 - xemu.and_(cameraX, 0xF)
            local blockY = y * 0x10 - xemu.and_(cameraY, 0xF)

            -- Blocks are 16x16 px², using a right shift to avoid dealing with floats
            local blockIndex = xemu.rshift(xemu.and_(cameraY + y * 0x10, 0xFFF), 4) * roomWidth
                             + xemu.rshift(xemu.and_(cameraX + x * 0x10, 0xFFFF), 4)

            -- Block type is the most significant 4 bits of level data
            local blockType = xemu.rshift(sm.getLevelDatum(blockIndex), 12)
            if debugFlag ~= 0 or blockType == 6 or blockType == 9 then
                -- Show the block type and BTS of every block
                drawText(blockX + 6, blockY, string.format("%X", blockType), "red")
                drawText(blockX + 4, blockY + 8, string.format("%02X", sm.getBts(blockIndex)), "red")
            end

            -- Draw the block outline depending on its block type
            local f = outline[blockType] or standardOutline(colour_errorBlock)
            f(blockX, blockY, blockIndex, stackLimit)
        end
    end
end

function displayDebugInfo(cameraX, cameraY, roomWidth)
    if debugInfoFlag == 0 then
        return
    end

    local cameraXBlock = xemu.rshift(cameraX, 4)
    local cameraYBlock = xemu.rshift(xemu.and_(cameraY, 0xFFF), 4)
    local clip = 0x7F0000 + xemu.and_(2 + (cameraXBlock + cameraYBlock * roomWidth) * 2, 0xFFFF)
    local clip_end = 0x7F0002 + 0x1FE * roomWidth + 0x1FFE
    local bts_end = 0x7F6402 + roomWidth * sm.getRoomHeight()
    drawText(0, 0, string.format("cameraX: %03X\ncameraY: %03X\nClip: %X\nClip end: %X\nBTS end: %X", cameraXBlock, cameraYBlock, clip, clip_end, bts_end), "cyan")

    if debugFlag == 0 then
        return
    end

    if doorListFlag ~= 0 then
        p_doorList = sm.getDoorListPointer()
        for i = 0,xemu.rshift(clip_end - 0x7F0002, 1) do
            if xemu.and_(sm.getLevelDatum(i), 0xF000) == 0x9000 then
                bts = xemu.and_(sm.getBts(i), 0x7F)
                if doors[xemu.read_u16_le(0x8F0000 + p_doorList + bts * 2)] then
                    doorList[bts] = doorList[bts] + 1
                end
            end
        end
        doorListFlag = 0
    end

    y = 216
    for j = 0,0x7F do
        i = 0x7F - j
        if doorList[i] ~= 0 then
            drawText(0, y, string.format("%02X x %i", i, doorList[i]), "cyan")
            y = y - 8
        end
    end
end

function displayFx(cameraX, cameraY)
    local fxY = sm.getFxYPosition() - cameraY
    local lavaAcidY = sm.getLavaAcidYPosition() - cameraY
    local fxTargetY = sm.getFxTargetYPosition() - cameraY
    drawLine(0, fxY, 255, fxY, 0x004080FF)
    drawLine(0, lavaAcidY, 255, lavaAcidY, 0xFFC080FF)
    drawLine(0, fxTargetY, 255, fxTargetY, 0xFFFFFFFF)
end

function displayKraidHitbox(cameraX, cameraY)
    if sm.getEnemyId(0) ~= 0xE2BF then
        return
    end

    local kraidXPosition = sm.getEnemyXPosition(0)
    local kraidYPosition = sm.getEnemyYPosition(0)
    local p_kraidInstructionList = 0xA70000 + xemu.read_u16_le(0x7E0FAA)

    -- Vulnerable hitbox for Kraid's mouth
    local p_projectileHitbox = xemu.read_u16_le(p_kraidInstructionList - 2)
    if p_projectileHitbox ~= 0xFFFF then
        local kraidLeftOffset   = xemu.read_s16_le(0xA70000 + p_projectileHitbox)
        local kraidTopOffset    = xemu.read_s16_le(0xA70000 + p_projectileHitbox + 2)
        local kraidBottomOffset = xemu.read_s16_le(0xA70000 + p_projectileHitbox + 6)
        local left   = kraidXPosition + kraidLeftOffset   - cameraX
        local top    = kraidYPosition + kraidTopOffset    - cameraY
        local bottom = kraidYPosition + kraidBottomOffset - cameraY
        drawBox(left, top, 256, bottom, 0xFFFFFFFF, "clear")
    end

    -- Invulnerable hitbox for Kraid's mouth
    p_projectileHitbox = xemu.read_u16_le(p_kraidInstructionList - 4)
    local kraidLeftOffset   = xemu.read_s16_le(0xA70000 + p_projectileHitbox)
    local kraidTopOffset    = xemu.read_s16_le(0xA70000 + p_projectileHitbox + 2)
    local kraidBottomOffset = xemu.read_s16_le(0xA70000 + p_projectileHitbox + 6)
    local left   = kraidXPosition + kraidLeftOffset   - cameraX
    local top    = kraidYPosition + kraidTopOffset    - cameraY
    local bottom = kraidYPosition + kraidBottomOffset - cameraY
    drawLine(left, top, 256, top, 0xFFFF80FF)
    drawLine(left, top, left, bottom, 0xFFFF80FF)

    -- Kraid's body
    local kraidSectionTopOffset = -0x8000
    local kraidSectionRightOffset = kraidLeftOffset
    for j = 1,8 do
        local i = 8 - j
        local kraidSectionBottomOffset = xemu.read_s16_le(0xA7B161 + i * 4)
        local kraidSectionLeftOffset   = xemu.read_s16_le(0xA7B161 + i * 4 + 2)
        local left   = kraidXPosition + kraidSectionLeftOffset   - cameraX
        local right  = kraidXPosition + kraidSectionRightOffset  - cameraX
        local top    = kraidYPosition + kraidSectionTopOffset    - cameraY
        local bottom = kraidYPosition + kraidSectionBottomOffset - cameraY

        -- Projectile hitbox is only defined up to Kraid's head, Samus hitbox uses whole table
        if kraidSectionTopOffset <= kraidBottomOffset then
            drawLine(left, top, right, top, 0xFF8080FF)
            drawLine(left, top, left, bottom, 0xFF8080FF)
            local kraidSectionTopOffset    = math.max(kraidSectionTopOffset, kraidBottomOffset)
            local kraidSectionBottomOffset = math.max(kraidSectionBottomOffset, kraidBottomOffset)
            local top    = kraidYPosition + kraidSectionTopOffset    - cameraY
            local bottom = kraidYPosition + kraidSectionBottomOffset - cameraY
            drawLine(left, top, right, top, 0xFFFF80FF)
            drawLine(left, top, left, bottom, 0xFFFFC0C0)
        else
            drawLine(left, top, right, top, 0xFFFFC0C0)
            drawLine(left, top, left, bottom, 0xFFFFC0C0)
        end

        kraidSectionTopOffset   = kraidSectionBottomOffset
        kraidSectionRightOffset = kraidSectionLeftOffset
    end
end

function displayMotherBrainHitbox(cameraX, cameraY)
    if sm.getEnemyId(0) ~= 0xEC7F then
        return
    end

    local p_motherBrainBodyHitbox = 0xA9B427
    local p_motherBrainBrainHitbox = 0xA9B439
    local p_motherBrainNeckHitbox = 0xA9B44B

    local motherBrainHitboxFlags = xemu.read_u16_le(0x7E7808)

    if xemu.and_(motherBrainHitboxFlags, 1) ~= 0 then
        local xPosition = sm.getEnemyXPosition(0)
        local yPosition = sm.getEnemyYPosition(0)
        local n_hitboxes = xemu.read_u16_le(p_motherBrainBodyHitbox)
        local p_hitboxes = p_motherBrainBodyHitbox + 2
        for i = 0,n_hitboxes-1 do
            local leftOffset   = math.abs(xemu.read_s16_le(p_hitboxes + i * 8))
            local topOffset    = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 2))
            local rightOffset  = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 4))
            local bottomOffset = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 6))
            local left   = xPosition - leftOffset   - cameraX
            local top    = yPosition - topOffset    - cameraY
            local right  = xPosition + rightOffset  - cameraX
            local bottom = yPosition + bottomOffset - cameraY
            drawBox(left, top, right, bottom, "green")
        end
    end

    if xemu.and_(motherBrainHitboxFlags, 2) ~= 0 then
        local xPosition = sm.getEnemyXPosition(1)
        local yPosition = sm.getEnemyYPosition(1)
        local n_hitboxes = xemu.read_u16_le(p_motherBrainBrainHitbox)
        local p_hitboxes = p_motherBrainBrainHitbox + 2
        for i = 0,n_hitboxes-1 do
            local leftOffset   = math.abs(xemu.read_s16_le(p_hitboxes + i * 8))
            local topOffset    = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 2))
            local rightOffset  = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 4))
            local bottomOffset = math.abs(xemu.read_s16_le(p_hitboxes + i * 8 + 6))
            local left   = xPosition - leftOffset   - cameraX
            local top    = yPosition - topOffset    - cameraY
            local right  = xPosition + rightOffset  - cameraX
            local bottom = yPosition + bottomOffset - cameraY
            drawBox(left, top, right, bottom, "blue")
        end
    end

    if xemu.and_(motherBrainHitboxFlags, 4) ~= 0 then
        local n_hitboxes = xemu.read_u16_le(p_motherBrainNeckHitbox)
        local p_hitboxes = p_motherBrainNeckHitbox + 2
        for i = 1,3 do
            local xPosition = xemu.read_u16_le(0x7E8044 + i * 6)
            local yPosition = xemu.read_u16_le(0x7E8046 + i * 6)
            for ii = 0,n_hitboxes-1 do
                local leftOffset   = math.abs(xemu.read_s16_le(p_hitboxes + ii * 8))
                local topOffset    = math.abs(xemu.read_s16_le(p_hitboxes + ii * 8 + 2))
                local rightOffset  = math.abs(xemu.read_s16_le(p_hitboxes + ii * 8 + 4))
                local bottomOffset = math.abs(xemu.read_s16_le(p_hitboxes + ii * 8 + 6))
                local left   = xPosition - leftOffset   - cameraX
                local top    = yPosition - topOffset    - cameraY
                local right  = xPosition + rightOffset  - cameraX
                local bottom = yPosition + bottomOffset - cameraY
                drawBox(left, top, right, bottom, "cyan")
            end
        end
    end

    --local x = xemu.read_s16_le(0x7E7814) - cameraX
    --local y = xemu.read_s16_le(0x7E7816) - cameraY
    --drawRightTriangle(x, y, x + 0x70, y - 0x60, "white")
    
    --local xPositionBody = sm.getEnemyXPosition(0)
    --local yPositionBody = sm.getEnemyYPosition(0)
    --drawRightTriangle(xPositionBody, yPositionBody, x, y, "yellow")
end

function displayEnemyHitboxes(cameraX, cameraY)
    local y = 0
    local n_enemies = sm.getNEnemies()
    --drawText(0, 0, string.format("n_enemies: %04X", n_enemies), 0xFF00FFFF)
    if n_enemies == 0 then
        return
    end

    -- Iterate backwards, I want earlier enemies drawn on top of later ones
    for j=1,n_enemies do
        local i = n_enemies - j
        local enemyId = sm.getEnemyId(i)
        if enemyId ~= 0 then
            local enemyXPosition = sm.getEnemyXPosition(i)
            local enemyYPosition = sm.getEnemyYPosition(i)
            local enemyXRadius   = sm.getEnemyXRadius(i)
            local enemyYRadius   = sm.getEnemyYRadius(i)
            local left   = enemyXPosition - enemyXRadius - cameraX
            local top    = enemyYPosition - enemyYRadius - cameraY
            local right  = enemyXPosition + enemyXRadius - cameraX
            local bottom = enemyYPosition + enemyYRadius - cameraY

            -- Draw enemy hitbox
            -- If not using extended spritemap format or frozen, draw simple hitbox
            if xemu.and_(sm.getEnemyExtraProperties(i), 4) == 0 or sm.getEnemyAiHandler(i) == 4 then
                drawBox(left, top, right, bottom, colour_enemy, "clear")
            else
                -- Process extended spritemap format
                local p_spritemap = sm.getEnemySpritemap(i)
                if p_spritemap ~= 0 then
                    local bank = xemu.lshift(sm.getEnemyBank(i), 16)
                    p_spritemap = bank + p_spritemap
                    local n_spritemap = xemu.read_u8(p_spritemap)
                    if n_spritemap ~= 0 then
                        for ii=0,n_spritemap-1 do
                            local entryPointer = p_spritemap + 2 + ii*8
                            local entryXOffset = xemu.read_s16_le(entryPointer)
                            local entryYOffset = xemu.read_s16_le(entryPointer + 2)
                            local entryHitboxPointer = xemu.read_u16_le(entryPointer + 6)
                            if entryHitboxPointer ~= 0 then
                                entryHitboxPointer = bank + entryHitboxPointer
                                local n_hitbox = xemu.read_u16_le(entryHitboxPointer)
                                if n_hitbox ~= 0 then
                                    for iii=0,n_hitbox-1 do
                                        local entryLeft   = xemu.read_s16_le(entryHitboxPointer + 2 + iii*12)
                                        local entryTop    = xemu.read_s16_le(entryHitboxPointer + 2 + iii*12 + 2)
                                        local entryRight  = xemu.read_s16_le(entryHitboxPointer + 2 + iii*12 + 4)
                                        local entryBottom = xemu.read_s16_le(entryHitboxPointer + 2 + iii*12 + 6)
                                        drawBox(
                                            enemyXPosition - cameraX + entryXOffset + entryLeft,
                                            enemyYPosition - cameraY + entryYOffset + entryTop,
                                            enemyXPosition - cameraX + entryXOffset + entryRight,
                                            enemyYPosition - cameraY + entryYOffset + entryBottom,
                                            colour_enemy, "clear"
                                        )
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- Show enemy index and ID
            drawText(left + 16, top, string.format("%u: %04X", i, enemyId), colour_enemy)

            -- Log enemy index and ID to list in top-right
            if logFlag ~= 0 then
                drawText(224, y, string.format("%u: %04X", i, enemyId), colour_enemy, 0xFF)
                --drawText(192, y, string.format("%u: %04X", i, sm.getEnemyInstructionList(i)), colour_enemy, 0xFF)
                --drawText(160, y, string.format("%u: %04X", i, sm.getEnemyAiVariable5(i)), colour_enemy, 0xFF)
                y = y + 8
            end

            -- Show enemy health
            local enemySpawnHealth = xemu.read_u16_le(0xA00004 + enemyId)
            if enemySpawnHealth ~= 0 then
                local enemyHealth = sm.getEnemyHealth(i)
                drawText(left, top - 16, string.format("%u/%u", enemyHealth, enemySpawnHealth), colour_enemy)
                -- Draw enemy health bar
                if enemyHealth ~= 0 then
                    drawBox(left, top - 8, left + enemyHealth * 32 / enemySpawnHealth, top - 5, colour_enemy, colour_enemy)
                    drawBox(left, top - 8, left + 32, top - 5, colour_enemy, "clear")
                end
            end
        end
    end
end

function displaySpriteObjects(cameraX, cameraY)
    for j=1,32 do
        -- Iterate backwards, I want earlier sprite objects drawn on top of later ones
        local i = 32 - j
        local spriteObjectId = sm.getSpriteObjectInstructionList(i)
        if spriteObjectId ~= 0 then
            local spriteObjectXPosition = sm.getSpriteObjectXPosition(i)
            local spriteObjectYPosition = sm.getSpriteObjectYPosition(i)
            local spriteObjectXRadius = 8
            local spriteObjectYRadius = 8
            local left   = spriteObjectXPosition - spriteObjectXRadius - cameraX
            local top    = spriteObjectYPosition - spriteObjectYRadius - cameraY
            local right  = spriteObjectXPosition + spriteObjectXRadius - cameraX
            local bottom = spriteObjectYPosition + spriteObjectYRadius - cameraY

            -- Draw sprite object
            drawBox(left, top, right, bottom, colour_spriteObject, "clear")

            -- Show sprite object index and ID
            drawText(left, top, string.format("%u: %04X", i, spriteObjectId), colour_spriteObject, "black")

            -- Log sprite object index and ID to list in top-left
            if logFlag ~= 0 then
                drawText(0, y, string.format("%u: %04X", i, spriteObjectId), colour_spriteObject, "black")
                y = y + 8
            end
        end
    end
end

function displayEnemyProjectileHitboxes(cameraX, cameraY)
    for j=1,18 do
        -- Iterate backwards, I want earlier enemy projectiles drawn on top of later ones
        local i = 18 - j
        local enemyProjectileId = sm.getEnemyProjectileId(i)
        if enemyProjectileId ~= 0 then
            local enemyProjectileXPosition = sm.getEnemyProjectileXPosition(i)
            local enemyProjectileYPosition = sm.getEnemyProjectileYPosition(i)
            local enemyProjectileXRadius   = sm.getEnemyProjectileXRadius(i)
            local enemyProjectileYRadius   = sm.getEnemyProjectileYRadius(i)
            local left   = enemyProjectileXPosition - enemyProjectileXRadius - cameraX
            local top    = enemyProjectileYPosition - enemyProjectileYRadius - cameraY
            local right  = enemyProjectileXPosition + enemyProjectileXRadius - cameraX
            local bottom = enemyProjectileYPosition + enemyProjectileYRadius - cameraY

            -- Draw enemy projectile hitbox
            drawBox(left, top, right, bottom, colour_enemyProjectile, "clear")
            --drawBox(math.min(left, right - 2), math.min(top, bottom - 2), math.max(right, left + 2), math.max(bottom, top + 2), colour_enemyProjectile, "clear")

            -- Show enemy projectile index and ID
            drawText(left, top, string.format("%u: %04X", i, enemyProjectileId), colour_enemyProjectile)
            --xemu.write_u16_le(0x7E1BD7 + i * 2, xemu.and_(xemu.read_u16_le(0x7E1BD7 + i * 2), 0xEFFF))
            --drawText(left, top, string.format("%04X", xemu.read_u16_le(0x7E1BD7 + i * 2)), 0x00FFFFFF, 0x000000FF)

            -- Log enemy projectile index and ID to list in top-right (after sprite objects)
            if logFlag ~= 0 then
                drawText(0, y, string.format("%u: %04X", i, enemyProjectileId), colour_enemyProjectile)
                y = y + 8
            end
        end
    end
end

function displayPowerBombExplosionHitbox(cameraX, cameraY)
    if sm.getPowerBombFlag() == 0 then
        return
    end

    local powerBombXPosition = sm.getPowerBombXPosition()
    local powerBombYPosition = sm.getPowerBombYPosition()
    local powerBombXRadius = sm.getPowerBombRadius() / 0x100
    local powerBombYRadius = powerBombXRadius * 3 / 4
    local left   = powerBombXPosition - powerBombXRadius - cameraX
    local top    = powerBombYPosition - powerBombYRadius - cameraY
    local right  = powerBombXPosition + powerBombXRadius - cameraX
    local bottom = powerBombYPosition + powerBombYRadius - cameraY

    -- Draw power bomb hitbox
    drawBox(left, top, right, bottom, colour_powerBomb, "clear")
end

function displayProjectileHitboxes(cameraX, cameraY)
    for i=0,9 do
        local projectileXPosition = sm.getProjectileXPosition(i)
        local projectileYPosition = sm.getProjectileYPosition(i)
        local projectileXRadius   = sm.getProjectileXRadius(i)
        local projectileYRadius   = sm.getProjectileYRadius(i)
        local left   = projectileXPosition - projectileXRadius - cameraX
        local top    = projectileYPosition - projectileYRadius - cameraY
        local right  = projectileXPosition + projectileXRadius - cameraX
        local bottom = projectileYPosition + projectileYRadius - cameraY

        -- Draw projectile hitbox
        drawBox(left, top, right, bottom, colour_projectile, "clear")

        -- Show projectile damage
        drawText(left, top - 8, sm.getProjectileDamage(i), colour_projectile)
        -- Show bomb timer
        if sm.getBombTimer(i) ~= 0 then
            if i >= 5 then
                drawText(left, top - 16, sm.getBombTimer(i), colour_projectile)
            else
                drawText(left, top - 16, string.format("%04X", sm.getBombTimer(i)), colour_projectile)
            end
        end
    end
end

function displaySamusHitbox(cameraX, cameraY, samusXPosition, samusYPosition)
    local samusXRadius = sm.getSamusXRadius()
    local samusYRadius = sm.getSamusYRadius()
    if followSamusFlag ~= 0 then
        left   = 128 - samusXRadius
        top    = 112 - samusYRadius
        right  = 128 + samusXRadius
        bottom = 112 + samusYRadius
    else
        left   = samusXPosition - samusXRadius - cameraX
        top    = samusYPosition - samusYRadius - cameraY
        right  = samusXPosition + samusXRadius - cameraX
        bottom = samusYPosition + samusYRadius - cameraY
    end

    -- Draw Samus' hitbox
    drawBox(left, top, right, bottom, colour_samus, "clear")

    -- Show current cooldown time
    local cooldown = sm.getCooldownTimer()
    if cooldown ~= 0 then
        drawText(right, (top + bottom) / 2 - 16, cooldown, "green")
    end

    -- Show current beam charge
    local charge = sm.getChargeCounter()
    if charge ~= 0 then
        drawText(right, (top + bottom) / 2 - 8, charge, "green")
    end

    -- Show recoil/invincibility
    local invincibility = sm.getInvincibilityTimer()
    local recoil = sm.getRecoilTimer()
    if recoil ~= 0 then
        drawText(right, (top + bottom) / 2, recoil, colour_samus)
    elseif invincibility ~= 0 then
        drawText(right, (top + bottom) / 2, invincibility, colour_samus)
    end

    local shine = sm.getShinesparkTimer()
    if shine ~= 0 then
        drawText(right, (top + bottom) / 2 + 8, shine, colour_samus)
    end

    if tasFlag ~= 0 then
        drawText(left, top - 16, string.format("%X.%04X", sm.getSamusXSpeed(), sm.getSamusXSubspeed()), 0xFF00FFFF)
        drawText(left, top - 8,  string.format("%X.%04X", sm.getSamusXMomentum(), sm.getSamusXSubmomentum()), 0xFF00FFFF)
        drawText(left, bottom,   string.format("%X.%04X", sm.getSamusYSpeed(), sm.getSamusYSubspeed()), 0xFF00FFFF)
        drawText(left, bottom + 8, sm.getSpeedBoosterLevel(), 0xFF00FFFF)
    end
end

-- Finally, the main loop
function on_paint()
    if not isValidLevelData() then
        return
    end
    
    local samusXPosition = sm.getSamusXPositionSigned()
    local samusYPosition = sm.getSamusYPositionSigned()
    
    -- Debug controls
    if debugControlsEnabled ~= 0 then
        handleDebugControls()
    end
    
    -- Co-ordinates of the top-left of the screen
    if followSamusFlag ~= 0 then
        cameraX = samusXPosition - 128 + xAdjust
        cameraY = samusYPosition - 112 + yAdjust
    else
        cameraX = sm.getLayer1XPosition()
        cameraY = sm.getLayer1YPosition()
    end
    
    -- Width of the room in blocks
    local roomWidth = sm.getRoomWidth()
    
    -- [[
    displayScrollBoundaries(cameraX, cameraY, roomWidth)
    --displayCameraMargin()
    displayDebugInfo(cameraX, cameraY, roomWidth)
    displayBlocks(cameraX, cameraY, roomWidth)
    displayFx(cameraX, cameraY)
    
    displayKraidHitbox(cameraX, cameraY)
    displayMotherBrainHitbox(cameraX, cameraY)
    displayEnemyHitboxes(cameraX, cameraY)
    y = 0
    displaySpriteObjects(cameraX, cameraY)
    displayEnemyProjectileHitboxes(cameraX, cameraY)
    
    displayPowerBombExplosionHitbox(cameraX, cameraY)
    displayProjectileHitboxes(cameraX, cameraY)
    displaySamusHitbox(cameraX, cameraY, samusXPosition, samusYPosition)
    
    if tasFlag ~= 0 then
        -- Show in-game time
        drawText(216, 0, string.format("%d:%d:%d.%d", sm.getGameTimeHours(), sm.getGameTimeMinutes(), sm.getGameTimeSeconds(), sm.getGameTimeFrames()), 0xFFFFFFFF)
    end
    --]]
end

if xemu.emuId == xemu.emuId_mesen then
    emu.addEventCallback(on_paint, emu.eventType.nmi)
elseif xemu.emuId ~= xemu.emuId_lsnes then
    while true do
        on_paint()
        emu.frameadvance()
    end
end
