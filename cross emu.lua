-- Patch some functions for cross-emu compatibility
xemu = {}
xemu.emuId_bizhawk = 0
xemu.emuId_snes9x  = 1
xemu.emuId_lsnes   = 2

if memory.usememorydomain then
    xemu.emuId = xemu.emuId_bizhawk
elseif memory.readshort then
    xemu.emuId = xemu.emuId_snes9x
else
    xemu.emuId = xemu.emuId_lsnes
end

-- Bitwise operations
if xemu.emuId == xemu.emuId_lsnes then
    xemu.rshift = bit.lrshift -- (logical) right shift
else
    xemu.rshift = bit.rshift
end

xemu.lshift = bit.lshift
xemu.not_ = bit.bnot
xemu.and_ = bit.band
xemu.or_ = bit.bor
xemu.xor = bit.bxor

-- Converts from SNES address model to flat address model (for ROM access)
function snes2pc(p)
    return xemu.and_(xemu.rshift(p, 1), 0x3F8000) + xemu.and_(p, 0x7FFF)
end

-- Define memory access functions
if xemu.emuId == xemu.emuId_bizhawk then
    if memory.getmemorydomainsize("CARTRIDGE_ROM") ~= memory.getcurrentmemorydomainsize() then
        romDomainName = "CARTRIDGE_ROM" -- used by BSNES core
    elseif memory.getmemorydomainsize("CARTROM") ~= memory.getcurrentmemorydomainsize() then
        romDomainName = "CARTROM" -- used by snes9x
    end

    function makeMemoryReader(f)
        return function(p)
            if p < 0x800000 then
                return f(xemu.and_(p, 0x1FFFF), "WRAM")
            else
                return f(snes2pc(p), romDomainName)
            end
        end
    end

    function makeMemoryWriter(f)
        return function(p, v)
            if p < 0x800000 then
                return f(xemu.and_(p, 0x1FFFF), v, "WRAM")
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

    xemu.read_u8      = makeMemoryReader(memory.read_u8)
    xemu.read_u16_le  = makeMemoryReader(memory.read_u16_le)
    xemu.read_s8      = makeMemoryReader(memory.read_s8)
    xemu.read_s16_le  = makeMemoryReader(memory.read_s16_le)
    xemu.write_u8     = makeMemoryWriter(memory.write_u8)
    xemu.write_u16_le = makeMemoryWriter(memory.write_u16_le)

    xemu.read_aram_u8     = makeAramReader(memory.read_u8)
    xemu.read_aram_u16_le = makeAramReader(memory.read_u16_le)
    xemu.read_aram_s8     = makeAramReader(memory.read_s8)
    xemu.read_aram_s16_le = makeAramReader(memory.read_s16_le)
elseif xemu.emuId == xemu.emuId_snes9x then
    xemu.read_u8      = memory.readbyte
    xemu.read_u16_le  = memory.readshort
    xemu.read_s8      = memory.readbytesigned
    xemu.read_s16_le  = memory.readshortsigned
    xemu.write_u8     = memory.writebyte
    xemu.write_u16_le = memory.writeshort
else -- xemu.emuId == lsnes
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

    xemu.read_u8      = makeMemoryReader(memory.readbyte)
    xemu.read_u16_le  = makeMemoryReader(memory.readword)
    xemu.read_s8      = makeMemoryReader(memory.readsbyte)
    xemu.read_s16_le  = makeMemoryReader(memory.readsword)
    xemu.write_u8     = makeMemoryWriter(memory.writebyte)
    xemu.write_u16_le = makeMemoryWriter(memory.writeword)
end

-- GUI functions
if xemu.emuId == xemu.emuId_bizhawk then
    xemu.drawPixel = function(x, y, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        
        gui.drawPixel(x0, y0, x1, y1, fg, bg)
    end
    
    xemu.drawBox = function(x0, y0, x1, y1, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(xemu.and_(bg, 0xFF), 0x18)
        end
        
        gui.drawBox(x0, y0, x1, y1, fg, bg)
    end
    
    xemu.drawLine = function(x0, y0, x1, y1, fg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        
        gui.drawLine(x0, y0, x1, y1, fg)
    end
    
    xemu.drawText = function(x0, y0, x1, y1, fg, bg)
        if fg ~= nil and type(fg) ~= "string" then
            fg = xemu.rshift(fg, 8) + xemu.lshift(xemu.and_(fg, 0xFF), 0x18)
        end
        if bg ~= nil and type(bg) ~= "string" then
            bg = xemu.rshift(bg, 8) + xemu.lshift(xemu.and_(bg, 0xFF), 0x18)
        end
        
        gui.pixelText(x0, y0, x1, y1, fg, bg)
    end
elseif xemu.emuId == xemu.emuId_snes9x then
    xemu.drawPixel = gui.pixel
    xemu.drawBox  = function(x0, y0, x1, y1, fg, bg) gui.box(x0, y0, x1, y1, bg or 0, fg) end
    xemu.drawLine = gui.line
    xemu.drawText = gui.text
else -- emuId == lsnes
    function decodeColour(colour)
        if colour == nil then
            return nil
        end
        
        if type(colour) == "string" then
            if colour == "red" then
                return 0xFF0000
            elseif colour == "orange" then
                return 0x808000
            elseif colour == "yellow" then
                return 0xFFFF00
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
                print(string.format("Colour = %s", colour))
                return
            end
        end

        return xemu.and_(colour, 0xFFFFFF)
    end

    xemu.drawPixel = function(x, y, fg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x = math.floor(x * s_x)
        y = math.floor(y * s_y)
        gui.pixel(x, y, decodeColour(fg))
    end

    xemu.drawBox = function(x0, y0, x1, y1, fg, bg)
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

    xemu.drawLine = function(x0, y0, x1, y1, fg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x0 = math.floor(x0 * s_x)
        y0 = math.floor(y0 * s_y)
        x1 = math.floor(x1 * s_x)
        y1 = math.floor(y1 * s_y)
        gui.line(x0, y0, x1, y1, decodeColour(fg))
    end

    xemu.drawText = function(x, y, text, fg, bg)
        local n_x, n_y = gui.resolution()
        local s_x = n_x / 256
        local s_y = n_y / 224
        x = math.floor(x * s_x)
        y = math.floor(y * s_y)
        gui.text(x, y, text, decodeColour(fg), decodeColour(bg))
    end
end


return xemu
