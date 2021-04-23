-- Note that BizHawk requires a restart if any included files are modified
sm = require("Super Metroid")

-- Patch some functions for cross-emu compatibility
emuId_bizhawk = 0
emuId_snes9x  = 1

if memory.usememorydomain then
    emuId = emuId_bizhawk
elseif memory.readshort then
    emuId = emuId_snes9x
end

-- Define memory access functions
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
elseif emuId == emuId_snes9x then
    read_u8      = memory.readbyte
    read_u16_le  = memory.readshort
    read_s8      = memory.readbytesigned
    read_s16_le  = memory.readshortsigned
    write_u8     = memory.writebyte
    write_u16_le = memory.writeshort
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
end

-- Define a controller 1 input function
if emuId == emuId_bizhawk then
    function getInput()
        local inputTable = joypad.get()
        return (
              (inputTable['P1 B']      and sm.button_B or 0)
            + (inputTable['P1 Y']      and sm.button_Y or 0)
            + (inputTable['P1 Select'] and sm.button_select or 0)
            + (inputTable['P1 Start']  and sm.button_start or 0)
            + (inputTable['P1 Up']     and sm.button_up or 0)
            + (inputTable['P1 Down']   and sm.button_down or 0)
            + (inputTable['P1 Left']   and sm.button_left or 0)
            + (inputTable['P1 Right']  and sm.button_right or 0)
            + (inputTable['P1 A']      and sm.button_A or 0)
            + (inputTable['P1 X']      and sm.button_X or 0)
            + (inputTable['P1 L']      and sm.button_L or 0)
            + (inputTable['P1 R']      and sm.button_R or 0)
        )
    end
elseif emuId == emuId_snes9x then
    function getInput()
        local inputTable = joypad.get()
        return (
              (inputTable['B']      and sm.button_B or 0)
            + (inputTable['Y']      and sm.button_Y or 0)
            + (inputTable['select'] and sm.button_select or 0)
            + (inputTable['start']  and sm.button_start or 0)
            + (inputTable['up']     and sm.button_up or 0)
            + (inputTable['down']   and sm.button_down or 0)
            + (inputTable['left']   and sm.button_left or 0)
            + (inputTable['right']  and sm.button_right or 0)
            + (inputTable['A']      and sm.button_A or 0)
            + (inputTable['X']      and sm.button_X or 0)
            + (inputTable['L']      and sm.button_L or 0)
            + (inputTable['R']      and sm.button_R or 0)
        )
    end
end

-- Globals
flashTimer = 0

animationDelays = {
    [0] = {
        [0] = 2,
        [1] = 3,
        [2] = 2,
        [3] = 3,
        [4] = 2,
        [5] = 3,
        [6] = 2,
        [7] = 3,
        [8] = 2,
        [9] = 3
    },
    [1] = {
        [0] = 2,
        [1] = 3,
        [2] = 2,
        [3] = 3,
        [4] = 2,
        [5] = 3,
        [6] = 2,
        [7] = 3,
        [8] = 2,
        [9] = 3
    },
    [2] = {
        [0] = 2,
        [1] = 2,
        [2] = 2,
        [3] = 2,
        [4] = 2,
        [5] = 2,
        [6] = 2,
        [7] = 2,
        [8] = 2,
        [9] = 2
    },
    [3] = {
        [0] = 1,
        [1] = 2,
        [2] = 1,
        [3] = 2,
        [4] = 1,
        [5] = 2,
        [6] = 1,
        [7] = 2,
        [8] = 1,
        [9] = 2
    },
}


function timeUntilTap()
    local level = sm.getSpeedBoosterLevel()
    local timer = sm.getSamusAnimationFrameTimer()
    local frame = sm.getSamusAnimationFrame()

    for i = frame+1,9 do
        timer = timer + animationDelays[level][i]
    end

    return timer - 1
end


function on_paint()
    local chartOriginX = 0xD0
    local chartOriginY = 6
    local chartWidth = 0x28
    local chartHeight = 0x18
    local flashLength = 4

    gui.drawBox(chartOriginX, chartOriginY, chartOriginX + chartWidth, chartOriginY + chartHeight, "black", "black")
    gui.drawLine(chartOriginX, chartOriginY, chartOriginX, chartOriginY + chartHeight, "white")

    if sm.getSamusMovementType() == 1 and sm.getSpeedBoosterLevel() < 4 then
        local timer = timeUntilTap()

        gui.drawLine(chartOriginX + timer, chartOriginY, chartOriginX + timer, chartOriginY + chartHeight, "white")
        if timer == 0 then
            colour = "red"
            if bit.band(getInput(), sm.getRunBinding()) ~= 0 then
                colour = "green"
            end
            
            flashTimer = flashLength
        end
        
        if flashTimer ~= 0 then
            flashTimer = flashTimer - 1
            gui.drawLine(chartOriginX - 1, chartOriginY, chartOriginX - 1, chartOriginY + chartHeight, colour)
            gui.drawLine(chartOriginX + 1, chartOriginY, chartOriginX + 1, chartOriginY + chartHeight, colour)
        end
        
        gui.drawText(8, 8, string.format("%d %04X", timer, getInput()), 0xFFFFFFFF)
    end
end

gui.register(on_paint)

while true do
    emu.frameadvance()
end
