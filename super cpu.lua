local xemu = require("cross emu")

console.clear()
gui.clearGraphics()

local colour_irq     = 0xFFFFFF80
local colour_system  = 0x80808080
local colour_enemy   = 0xFF000080
local colour_samus   = 0x00FFFF80
local colour_sprites = 0x0000FF80

-- Globals
local interestPoints = {
    {colour = colour_irq,     address_begin = 0x009583, address_ends = {0x809601},           label = "NMI"},
    {colour = colour_irq,     address_begin = 0x00986A, address_ends = {0x80988A},           label = "IRQ"},
    {colour = 0x00000080,     address_begin = 0x808338, address_ends = {0x80834A},           label = "Wait for NMI"},
    {colour = colour_system,  address_begin = 0x82893D, address_ends = {},                   label = "Main game loop"},
    {colour = colour_enemy,   address_begin = 0xA08EB6, address_ends = {0xA08F76, 0xA08FD3}, label = "Determine which enemies to process"},
    {colour = colour_samus,   address_begin = 0x90E692, address_ends = {0x828B5C, 0x8B8E16}, label = "JSR ($0A42)"},
    {colour = colour_samus,   address_begin = 0xA09785, address_ends = {0x828B65},           label = "Samus / projectile interaction handler"},
    {colour = colour_enemy,   address_begin = 0xA08FD4, address_ends = {0xA09168},           label = "Main enemy routine"},
    {colour = colour_samus,   address_begin = 0x90E722, address_ends = {0x828B6D, 0x8B8E1A}, label = "JSR ($0A44)"},
    {colour = colour_enemy,   address_begin = 0x868104, address_ends = {0x868124},           label = "Enemy projectile handler"},
    {colour = colour_enemy,   address_begin = 0xA09894, address_ends = {0x828B82},           label = "Enemy projectile / Samus collision detection"},
    {colour = colour_enemy,   address_begin = 0xA0996C, address_ends = {0x828B86},           label = "Enemy projectile / projectile detection"},
    {colour = colour_enemy,   address_begin = 0xA0A306, address_ends = {0x828B8A},           label = "Process enemy power bomb interaction"},
    {colour = colour_sprites, address_begin = 0xA0884D, address_ends = {0xA088CF},           label = "Draw Samus, projectiles, enemies and enemy projectiles"},
    {colour = colour_enemy,   address_begin = 0x868390, address_ends = {0x8683B1},           label = "Draw low priority enemy projectiles"},
    {colour = colour_samus,   address_begin = 0x90EB35, address_ends = {0x90EB4A},           label = "Draw Samus and projectiles"},
    {colour = colour_enemy,   address_begin = 0xA09726, address_ends = {0xA09757},           label = "Handle queuing enemy BG2 tilemap VRAM transfer"},
    {colour = colour_samus,   address_begin = 0x82DB69, address_ends = {0x828BAF},           label = "Handle Samus running out of health and increment game time"},
}

local colour = 0
local colour_old = 0

local drawQueue = {}
local colourStack = {}

function drawWrapped(x_from, y_from, x_to, y_to, colour, label)
    --console.log(string.format('(%3d, %3d) -> (%3d, %3d) - %08X %s', x_from, y_from, x_to, y_to, colour, label))
    if y_from == y_to then
        xemu.drawLine(x_from, y_from, x_to, y_to, colour)
    else
        xemu.drawLine(x_from, y_from, 341, y_from, colour)
        if y_to < y_from then
            xemu.drawBox(0, y_from+1, 341, 262, colour, colour)
            y_from = -1
        end
        
        xemu.drawBox(0, y_from+1, 341, y_to-1, colour, colour)
        xemu.drawLine(0, y_to, x_to, y_to, colour)
    end
end

function init()
    client.SetGameExtraPadding(0, 0, 341-256, 262-224)

    for _, point in ipairs(interestPoints) do
        event.onmemoryexecute(function()
            local x = emu.getregister('H')
            local y = emu.getregister('V')
            colourStack[#colourStack+1] = point.colour
            drawQueue[#drawQueue+1] = {x = x, y = y, colour = point.colour, label = point.label}
        end, point.address_begin)
        
        for _, address_end in ipairs(point.address_ends) do
            event.onmemoryexecute(function()
                local x = emu.getregister('H')
                local y = emu.getregister('V')
                drawQueue[#drawQueue+1] = {x = x, y = y, colour = table.remove(colourStack), label = point.label}
            end, address_end)
        end
    end
end


function on_paint()
    if #drawQueue ~= 0 then
        for i = 1, #drawQueue-1 do
            drawWrapped(drawQueue[i].x, drawQueue[i].y, drawQueue[i+1].x, drawQueue[i+1].y, drawQueue[i].colour, drawQueue[i].label)
        end
        
        local i = #drawQueue
        local x_to = emu.getregister('H')
        local y_to = emu.getregister('V')
        drawWrapped(drawQueue[i].x, drawQueue[i].y, x_to, y_to, drawQueue[i].colour, drawQueue[i].label)
        drawQueue = {}
    end
end

init()
while true do
    on_paint()
    emu.frameadvance()
end
