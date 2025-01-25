-- Note that BizHawk requires a restart if any included files are modified
local xemu = require("cross emu")
local sm = require("Super Metroid")

-- Define a controller 1 input function
if xemu.emuId == xemu.emuId_bizhawk then
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
elseif xemu.emuId == xemu.emuId_snes9x then
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
local flashTimer = 0

local animationDelays = {
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

    xemu.drawBox(chartOriginX, chartOriginY, chartOriginX + chartWidth, chartOriginY + chartHeight, "black", "black")
    xemu.drawLine(chartOriginX, chartOriginY, chartOriginX, chartOriginY + chartHeight, "white")

    if sm.getSamusMovementType() == 1 and sm.getSpeedBoosterLevel() < 4 then
        local timer = timeUntilTap()

        xemu.drawLine(chartOriginX + timer, chartOriginY, chartOriginX + timer, chartOriginY + chartHeight, "white")
        if timer == 0 then
            colour = "red"
            if xemu.and_(getInput(), sm.getRunBinding()) ~= 0 then
                colour = "green"
            end
            
            flashTimer = flashLength
        end
        
        if flashTimer ~= 0 then
            flashTimer = flashTimer - 1
            xemu.drawLine(chartOriginX - 1, chartOriginY, chartOriginX - 1, chartOriginY + chartHeight, colour)
            xemu.drawLine(chartOriginX + 1, chartOriginY, chartOriginX + 1, chartOriginY + chartHeight, colour)
        end
        
        xemu.drawText(8, 8, string.format("%d %04X", timer, getInput()), 0xFFFFFFFF)
    end
end

while true do
    emu.frameadvance()
    on_paint()
end
