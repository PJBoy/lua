console.clear()

rshift = bit.rshift

-- Converts from SNES address model to flat address model (for ROM access)
function snes2pc(p)
    return bit.band(rshift(p, 1), 0x3F8000) + bit.band(p, 0x7FFF)
end

-- Define memory access functions
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


function loadNotes()
    local filepath = notes_filenames[i_dropdown]
    io.open(filepath, "a"):close()
    local file = io.open(filepath, "r")
    local text = file:read("*all")
    file:close()
    
    return text
end

function saveNotes()
    local notes_file = io.open(notes_filenames[i_dropdown], "w")
    notes_file:write(notes_text)
    notes_file:close()
end


-- Create files as needed
notes_filenames = {
    [0] = "smz3notes_00.txt",
    [1] = "smz3notes_01.txt",
    [2] = "smz3notes_02.txt",
    [3] = "smz3notes_03.txt",
    [4] = "smz3notes_04.txt",
    [5] = "smz3notes_05.txt",
    [6] = "smz3notes_06.txt",
    [7] = "smz3notes_07.txt",
    [8] = "smz3notes_08.txt",
    [9] = "smz3notes_09.txt",
    [10] = "smz3notes_10.txt",
    [11] = "smz3notes_11.txt",
    [12] = "smz3notes_12.txt",
    [13] = "smz3notes_13.txt"
}

-- Globals
i_dropdown = 0
notes_text = loadNotes()

-- Extra GUI
forms.destroyall()

local width = 640
local height = 240
local x = 0
local y = 0
local fixedWidth = true
local boxType = nil
local multiline = true
local scrollbars = "both"

superform_notes = forms.newform(width, height, "Notes")

local labels = {
    "00 Overworld - light world",
    "01 Overworld - dark world",
    "02 Light world 0 - Hyrule Castle",
    "03 Light world 1 - Eastern Palace",
    "04 Light world 2 - Desert Palace",
    "05 Light world 3 - Tower of Hera",
    "06 Dark world 1 - Palace of Darkness",
    "07 Dark world 2 - Swamp Palace",
    "08 Dark world 3 - Skull Woods",
    "09 Dark world 4 - Thieves' Town",
    "10 Dark world 5 - Ice Palace",
    "11 Dark world 6 - Misery Mire",
    "12 Dark world 7 - Turtle Rock",
    "13 Ganon's Tower"
}
height = 16
dropdown_notes = forms.dropdown(superform_notes, labels, x, y, width, height)

y = height
height = 480 - y
form_notes = forms.textbox(superform_notes, "", width, height, boxType, x, y, multiline, fixedWidth, scrollbars)
forms.settext(form_notes, notes_text)


-- Finally, the main loop
while true do
    local i_dropdown_new = tonumber(forms.getproperty(dropdown_notes, "SelectedIndex"))
    
    if i_dropdown_new ~= i_dropdown then
        i_dropdown = i_dropdown_new
        notes_text = loadNotes()
        forms.settext(form_notes, notes_text)
    else
        local notes_text_new = forms.gettext(form_notes)
        if notes_text_new ~= notes_text then
            notes_text = notes_text_new
            saveNotes()
        end
    end
    
    emu.frameadvance()
end
