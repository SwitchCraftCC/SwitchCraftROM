-- Hex Editor
-- By Anavrins, inspired by KillaVanilla's

local args = {...}

if pocket or turtle then error("Computers only!", 0) end
if #args < 1 then
	print("Usage: "..fs.getName(shell.getRunningProgram()).." <path>")
	return
end

local fpath = shell.resolve(tostring(args[1]))
local fReadOnly = fs.isReadOnly(fpath)
if fs.exists(fpath) and fs.isDir(fpath) then
	print("Cannot hex edit a directory.")
	return
end

local tW, tH = term.getSize()
local fixwindow = _G._HOST == nil -- Window api crash prevention
local newBinHandle = false
local ptr = 1
local offset = 0
local textMode = false
local shiftPress = false
local inMenu = false
local defaultStatus = "Press Ctrl to access menu"
local status = defaultStatus
local menuIndex = 1
local menuItems = {}
local searchByte = -1
local hexOffset = true
if not fs.isReadOnly(fpath) then
	menuItems[#menuItems+1] = "Save"
end
menuItems[#menuItems+1] = "Text Mode"
menuItems[#menuItems+1] = "Jump"
menuItems[#menuItems+1] = "Insert"
menuItems[#menuItems+1] = "Find"
menuItems[#menuItems+1] = "Exit"

local isColor = term.isColor()
local col = {
	bgColor       = isColor and colors.black or colors.black,
	textColor     = isColor and colors.white or colors.white,
	menuColor     = isColor and colors.yellow or colors.white,
	menuBg        = isColor and colors.gray or colors.gray,
	highlightText = isColor and colors.white or colors.gray,
	highlightBg   = isColor and colors.blue or colors.white,
	searchBg      = isColor and colors.red or colors.white,
	offset        = isColor and colors.lightGray or colors.lightGray,
	separatorH    = isColor and colors.orange or colors.gray,
	separatorV    = isColor and colors.yellow or colors.white,
}

local winHelpMenu = {
	"                                    ",
	"              HexEdit",
	"            by Anavrins",
	"",
	" [+/-] Change low nibble at cursor",
	" +Shft Change high nibble at cursor",
	" [0-F] Set byte value at cursor",
	" [Space] Set byte at cursor to 00",
	" [Del] Remove byte at cursor",
	" [Arrows] Move cursor",
	" [PageUp/Dn] Paged scroll",
	" [Home/End] Goto top/bottom of file",
	"",
}

local winFileChecksum = {
	"          ",
	"  CRC32",
	"",
	"",
}

local wordsize = 8
local brshift = function(n, b)
	local shifted = n / (2^b)
	return shifted-shifted%1
end
local lrotate = function(n, b)
	local s = n/(2^(wordsize-b))
	local f = s%1
	return (s-f) + f*2^wordsize
end
local rrotate = function(n, b)
	local s = n/(2^b)
	local f = s%1
	return (s-f) + f*2^wordsize
end

local function loadFile(path)
	if not fs.exists(path) then return {} end
	local r = {}
	local f = fs.open(path, "rb")
	if f.readAll then -- Check if new version with improved binary handles
		newBinHandle = true
		r = {f.readAll():byte(1,-1)}
	else
		local i = 1
		for b in f.read do
			r[i] = b
			i = i + 1
		end
	end
	f.close()
	return r
end

local function saveFile(path, dat)
	local f = fs.open(path, "wb")
	if f then
		if newBinHandle then
			f.write(string.char(unpack(dat)))
		else
			for i = 1, #dat do
				f.write(dat[i])
			end
		end
		f.close()
		return true
	else return false
	end
end

local function crc32(data)
	local rem = 0xFFFFFFFF
	for i = 1, #data do
		rem = bit32.bxor(rem, data[i])
		for j = 1, 8 do
			rem = bit32.bxor(brshift(rem, 1), bit32.band(0xEDB88320, -bit32.band(rem, 1)))
		end
	end
	return bit32.bnot(rem)
end

local function writeCol(text, fg, bg)
	if fg then term.setTextColor(fg) end
	if bg then term.setBackgroundColor(bg) end
	term.write(text)
end

local function clamp(val, min, max)
	return math.max(min, math.min(max, val))
end

local function batch(t, v)
	return {t[v+1], t[v+2], t[v+3], t[v+4], t[v+5], t[v+6], t[v+7], t[v+8]}
end
local function drawScreen(dat, offset, name, size)
	term.setBackgroundColor(col.bgColor)
	term.setCursorPos(1, 1)
	term.clearLine()
	writeCol(("-- File: %q \[%d bytes\]"):format(name:sub(1,20)..(#name>20 and "..." or ""), size), col.menuColor)

	term.setCursorPos(1, 2)
	for i = -1, 8 do
		if i == -1 then
			writeCol("|", col.separatorV)
			writeCol("Offset. ", col.offset)
			writeCol("| ", col.separatorV)
		elseif i == 8 then
			writeCol("| |", col.separatorV)
			writeCol("ASCIIRep", col.offset)
			writeCol("|", col.separatorV)
		else
			writeCol(i == 4 and "| |" or "|", col.separatorV)
			writeCol(("%02X"):format(i), col.offset)
		end
	end
	term.setCursorPos(1, 3)
	for i = -1, 8 do
		if i == -1 then
			writeCol("|", col.separatorV)
			writeCol("--------", col.separatorH)
			writeCol("| ", col.separatorV)
		elseif i == 8 then
			writeCol("| |", col.separatorV)
			writeCol("--------", col.separatorH)
			writeCol("|", col.separatorV)
		else
			writeCol(i == 4 and "| |" or "|", col.separatorV)
			writeCol("--", col.separatorH)
		end
	end
	for i = 0, tH-6 do
		local byteRow = batch(dat, (offset+1*i)*8 )
		local hexLine = ""
		local asciiLine = ""

		term.setCursorPos(1, 4+i)
		for j = 0, 8 do
			if j == 0 then
				writeCol("|", col.separatorV)
				writeCol((hexOffset and "%08X" or "%08d"):format((offset*8)+(i*8)), col.offset)
				writeCol("| ", col.separatorV)
			else
				writeCol(j == 5 and "| |" or "|", col.separatorV, col.bgColor)
				local hcol = (byteRow[j] == searchByte) and col.searchBg or col.bgColor
				local hl = ptr == j+(offset+1*i)*8
				hcol = hl and col.highlightBg or hcol
				writeCol((byteRow[j] and ("%02X"):format(byteRow[j]) or "  "), hl and col.highlightText or col.textColor, hcol)
			end
		end
		writeCol("| |", col.separatorV, col.bgColor)
		for j = 1, 8 do
			byteRow[j] = byteRow[j] or 32
			byteRow[j] = (fixwindow and byteRow[j] > 0x7E) and 0x00 or byteRow[j]
			local hcol = (byteRow[j] == searchByte) and col.searchBg or col.bgColor
			local hl = ptr == j+(offset+1*i)*8
			hcol = hl and col.highlightBg or hcol
			writeCol(string.char(byteRow[j]), hl and col.highlightText or col.textColor, hcol)
		end
		writeCol("|", col.separatorV, col.bgColor)
	end
end

local function toBin(n)
	local r = ""
	for i = 0, 7 do r = r..bit32.band(brshift(n, i), 1) end
	return r:reverse()
end

local function drawConv(dat, p)
	term.setCursorPos(1, tH-1)
	term.clearLine()
	writeCol("uint8:", col.menuColor, col.bgColor)
	writeCol(("%#3u"):format(dat[p] or 0), col.textColor, col.bgColor)
	writeCol(" | ", col.separatorV, col.bgColor)
	writeCol("16:", col.menuColor, col.bgColor)
	writeCol(("%#5u"):format((dat[p] or 0) + (bit32.lshift(dat[p+1] or 0, 8))), col.textColor, col.bgColor)
	writeCol(" | ", col.separatorV, col.bgColor)
	writeCol("32:", col.menuColor, col.bgColor)
	writeCol(("%#10u"):format((dat[p] or 0) + (bit32.lshift(dat[p+1] or 0, 8)) + (bit32.lshift(dat[p+2] or 0, 16)) + (bit32.lshift(dat[p+3] or 0, 24))), col.textColor, col.bgColor)
	writeCol(" | ", col.separatorV, col.bgColor)
	writeCol("Bin:", col.menuColor, col.bgColor)
	writeCol(("%s"):format(toBin(dat[p] or 0)), col.textColor, col.bgColor)
end

local function drawMenu()
	term.setCursorPos(1, tH)
	term.clearLine()
	if inMenu then
		for i = 1, #menuItems do
			term.setTextColor(col.textColor)
			if i == menuIndex then
				term.setTextColor(col.menuColor)
				term.write("[")
				term.setTextColor(col.textColor)
				term.write(menuItems[i])
				term.setTextColor(col.menuColor)
				term.write("]")
			else
				term.write(" "..menuItems[i].." ")
			end
		end
	else
		term.setTextColor(col.menuColor)
		term.write(status)
		local fptr = ("%X"):format(ptr-1)
		term.setCursorPos(tW - #fptr-7, tH)
		writeCol(" Offset ", col.menuColor)
		writeCol(fptr, col.textColor)
	end
end

local function drawTooltip(tooltip)
	local w = window.create(term.current(), (tW/2)-(#tooltip[1]/2), (tH/2)-(#tooltip/2), #tooltip[1], #tooltip)
	local t = term.redirect(w)
	term.setTextColor(col.menuColor)
	term.setBackgroundColor(col.menuBg)
	term.clear()
	for i = 1, #tooltip do
		term.setCursorPos(1, i)
		term.write(tooltip[i])
	end
	return t
end

print("Loading...")
local data = loadFile(fpath)
local fname = fs.getName(fpath)

term.setBackgroundColor(colors.black)
term.clear()
while true do
	drawScreen(data, offset, fname, #data)
	drawConv(data, ptr)
	drawMenu()
	local event, p1, p2, p3, p4, p5 = os.pullEventRaw()
	if event == "mouse_scroll" and not inMenu then
		offset = offset + p1

	elseif (event == "mouse_click" or event == "mouse_drag") and not inMenu then
		if (p3 > 3 and p3 < tH-1) then
			local lineY = p3-4
			if p2 > 11 and p2 < 25 then
				local lineX = clamp(math.ceil((p2-11)/3), 1, 4)
				ptr = lineX+(offset+lineY)*8
			elseif p2 > 25 and p2 < 39 then
				local lineX = clamp(math.ceil((p2-25)/3), 1, 4)+4
				ptr = lineX+(offset+lineY)*8
			elseif p2 > 40 and p2 < 49 then
				local lineX = clamp(math.ceil((p2-40)), 1, 8)
				ptr = lineX+(offset+lineY)*8
			end
		end

	elseif event == "char" and not inMenu then
		if textMode then
			data[ptr] = p1:byte()
			ptr = ptr+1
		else
			local c = tonumber(p1, 16)
			if c and not (p1 == "-" or p1 == "_") then
				data[ptr] = bit32.band(bit32.bor(bit32.lshift(data[ptr] or 0, 4), c), 0xFF)
			end
		end

	elseif event == "key_up" then
		if p1 == keys.leftShift or p1 == keys.rightShift then shiftPress = false end

	elseif event == "key" then
		if p1 == keys.leftCtrl then
			inMenu = not inMenu
			status = defaultStatus
		end
		if p1 == keys.leftShift or p1 == keys.rightShift then shiftPress = true end

		if inMenu then
			if p1 == keys.left then
				menuIndex = menuIndex - 1
				if menuIndex < 1 then menuIndex = #menuItems end
			elseif p1 == keys.right then
				menuIndex = menuIndex + 1
				if menuIndex > #menuItems then menuIndex = 1 end
			elseif p1 == keys.enter then
				if menuItems[menuIndex] == "Save" then
					local ok = saveFile(fpath, data)
					status = (ok and "Saved to " or "Failed to open ")..fname
				elseif menuItems[menuIndex] == "Jump" then
					local t = drawTooltip({(" "):rep(17)," Jump to offset:", "", ""})
					term.setCursorPos(2,3)
					local i = tonumber(read())
					if i then ptr = i+1 end
					term.redirect(t)
					os.queueEvent("key") -- Trigger re-centering
				elseif menuItems[menuIndex] == "Insert" then
					local t = drawTooltip({(" "):rep(18), " Number of bytes:", "", " Byte Value:", "",""})
					term.setCursorPos(2,3)
					local i = tonumber(read()) or 1
					i = math.min(i, 1024)
					term.setCursorPos(2,5)
					local j = tonumber(read()) or 0
					j = bit32.band(j, 0xFF)
					for l = 1, i do table.insert(data, ptr, j) end
					status = "Added "..i.." bytes of value "..("0x%02X"):format(j)
					term.redirect(t)
				elseif menuItems[menuIndex] == "Find" then
					local t = drawTooltip({(" "):rep(13)," Find bytes:", "", ""})
					term.setCursorPos(2,3)
					local i = tonumber(read())
					searchByte = i and bit32.band(i, 0xFF) or -1
					term.redirect(t)
				elseif menuItems[menuIndex] == "Text Mode" then
					textMode = true
					menuItems[menuIndex] = "Byte Mode"
				elseif menuItems[menuIndex] == "Byte Mode" then
					textMode = false
					menuItems[menuIndex] = "Text Mode"
				elseif menuItems[menuIndex] == "Exit" then break
				end
				inMenu = false
			end
		else
			if p1 == keys.space then data[ptr] = 0
			elseif p1 == keys.delete then table.remove(data, ptr)
			elseif p1 == keys.home then ptr = 1
			elseif p1 == keys["end"] then ptr = #data+1
			elseif p1 == keys.pageUp then ptr = ptr - (tH-6)*8
			elseif p1 == keys.pageDown then ptr = ptr + (tH-6)*8
			elseif p1 == keys.right then
				if shiftPress then data[ptr] = rrotate(data[ptr], 1)
				else ptr = ptr + 1
				end
			elseif p1 == keys.left then
				if shiftPress then data[ptr] = lrotate(data[ptr], 1)
				else ptr = ptr - 1
				end
			elseif p1 == keys.down then
				if shiftPress then data[ptr] = bit32.band(bit32.bnot(data[ptr]), 0xFF)
				else ptr = ptr + 8
				end
			elseif p1 == keys.up then ptr = ptr - 8
			elseif p1 == keys.backspace and textMode then data[ptr] = 0; ptr = ptr - 1
			elseif p1 == keys.minus and not textMode then
				data[ptr] = bit32.band((data[ptr] or 0)-(shiftPress and 0x10 or 0x01), 0xFF)
			elseif (p1 == keys.equals or p1 == keys.numPadAdd) and not textMode then
				data[ptr] = bit32.band((data[ptr] or 0)+(shiftPress and 0x10 or 0x01), 0xFF)
			elseif p1 == keys.f6 then
				local func, err = loadstring(string.char(unpack(data)))
				if err then status = "Could not compile"
				else data = {string.dump(func):byte(1,-1)}
				end
			elseif p1 == keys.f1 then
				local t = drawTooltip(winHelpMenu)
				os.pullEvent("key")
				term.redirect(t)
			elseif p1 == keys.f3 then
				if winFileChecksum[3] == "" then winFileChecksum[3] = (" %08x"):format(crc32(data)) end
				local t = drawTooltip(winFileChecksum)
				os.pullEvent("key")
				term.redirect(t)
			end
			if math.floor((ptr-1)/8) < offset then offset = math.floor((ptr-1)/8)
			elseif math.floor((ptr-1)/8) > offset+(tH-6) then offset = math.floor((ptr-1)/8)-(tH-6)
			end
		end

	elseif event == "term_resize" then tW, tH = term.getSize()
	elseif event == "terminate" then break
	end

	ptr = clamp(ptr, 1, #data+1)
	offset = clamp(offset, 0, math.ceil(((#data+1)/8)-(tH-5)))
end

term.clear()
term.setCursorPos(1,1)