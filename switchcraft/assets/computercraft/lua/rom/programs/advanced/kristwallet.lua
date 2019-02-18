--[[-----------------------------------------------
|               KristWallet by 3d6                |
---------------------------------------------------
| This is the reference wallet for Krist.         |
| It is the basic definition of a functional      |
| Krist program, although it is not as old as the |
| network (we used to just use raw API calls).    |
---------------------------------------------------
 /\  /\  /\  /\  /\  /\  /\  /\  /\  /\  /\  /\  /\
/  \/  \/  \/  \/  \/  \/  \/  \/  \/  \/  \/  \/
---------------------------------------------------
| Do whatever you want with this, but if you make |
| it interact with a currency or network other    |
| than Krist, please give me credit. Thanks <3    |
---------------------------------------------------
| This wallet will NEVER save passwords anywhere. |]]local
-----------------------------------------------]]--
                   version = 16
local latest = 0
local balance = 0
local balance2 = 0
local balance3 = 0
local MOD = 2^32
local MODM = MOD-1
local gui = 0
local page = 0
local lastpage = 0
local scroll = 0
local masterkey = ""
local doublekey = ""
local address = ""
local addressv1 = ""
local addressdv = ""
local addresslv = ""
local subject = ""
local name = ""
local subbal = 0
local subtxs = ""
local stdate = {}
local stpeer = {}
local stval = {}
local blkpeer = {}
local pagespace = ""
local maxspace = ""
local ar = 0
local amt = 0
local availability = 0
local wallet, hud, update, settle, log, readconfig, checkdir, openwallet, makev2address

local function split(inputstr, sep)
        if sep == nil then
                sep = "%s"
        end
        local t={} ; i=1
        for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
                t[i] = str
                i = i + 1
        end
        return t
end

local function readURL(url)
  local resp = http.get(url)
  if not resp then
	log("Could not reach "..url)
    error("Error connecting to server")
	panic()
  end
  local content = resp.readAll():gsub("\n+$", "")
  resp.close()
  return content
end

local function boot()
  for i=1,2 do checkdir() end
  print("Starting KristWallet v"..tostring(version))
  log("Started KristWallet v"..tostring(version))
  update()
  if readconfig("enabled") and latest <= version then
    settle()
    openwallet()
    while page ~= 0 do
      wallet()
    end
    term.setBackgroundColor(32768)
    term.setTextColor(16)
    term.clear()
    term.setCursorPos(1,1)
    log("KristWallet closed safely")
  else
    if not readconfig("enabled") then print("KristWallet is disabled on this computer.") log("Disabled, shutting down") end
  end
  if readconfig("rebootonexit") then
    log("Rebooted computer")
    os.reboot()
  end
end
function update()
  latest = tonumber(readURL(readconfig("versionserver")))
  if latest > version then
    print("An update is available!")
    log("Discovered update")
    if readconfig("autoupdate") and not bench then
      local me = fs.open(fs.getName(shell.getRunningProgram()),"w")
      local nextversion = readURL(readconfig("updateserver"))
      print("Installed update. Run this program again to start v"..latest..".")
      me.write(nextversion)
      me.close()
      log("Installed update")
    else
      log("Ignored update")
      latest = -2
    end
  else
    log("No updates found")
  end
end
function log(text)
  local logfile = fs.open("kst/log_wallet","a")
  logfile.writeLine(tostring(os.day()).."-"..tostring(os.time()).."/"..text)
  logfile.close()
end
local function checkfile(path,default)
  if not fs.exists("kst/"..path) or path == "syncnode" then
    local file = fs.open("kst/"..path,"w")
    file.writeLine(default)
    file.close()
    log("Created file "..path)
    return false
  else
    return true
  end
end
function readconfig(path)
  if fs.exists("kst/"..path) then
    local file = fs.open("kst/"..path,"r")
    local context = file.readAll():gsub("\n+$", "")
    file.close()
    if context == "true" then return true end
    if context == "false" then return false end
    return context
  else
    print("An unknown error happened")
  end
end
function settle()
  if term.isColor() then gui = 1 end
  if term.isColor() and pocket then gui = 2 end
end
local function drawKrist()
  local posx, posy = term.getCursorPos()
  term.setBackgroundColor(1)
  term.setTextColor(32)
  term.write("/")
  term.setBackgroundColor(32)
  term.setTextColor(8192)
  term.write("\\")
  term.setCursorPos(posx,posy+1)
  term.setBackgroundColor(32)
  term.setTextColor(8192)
  term.write("\\")
  term.setBackgroundColor(8192)
  term.setTextColor(32)
  term.write("/")
  term.setCursorPos(posx+2,posy)
end
local function memoize(f)
  local mt = {}
  local t = setmetatable({}, mt)
  function mt:__index(k)
    local v = f(k)
    t[k] = v
    return v
  end
  return t
end
local function make_bitop_uncached(t, m)
  local function bitop(a, b)
    local res,p = 0,1
    while a ~= 0 and b ~= 0 do
      local am, bm = a % m, b % m
      res = res + t[am][bm] * p
      a = (a - am) / m
      b = (b - bm) / m
      p = p*m
    end
    res = res + (a + b) * p
    return res
  end
  return bitop
end
local function make_bitop(t)
  local op1 = make_bitop_uncached(t,2^1)
  local op2 = memoize(function(a) return memoize(function(b) return op1(a, b) end) end)
  return make_bitop_uncached(op2, 2 ^ (t.n or 1))
end
local bxor1 = make_bitop({[0] = {[0] = 0,[1] = 1}, [1] = {[0] = 1, [1] = 0}, n = 4})
local function bxor(a, b, c, ...)
  local z = nil
  if b then
    a = a % MOD
    b = b % MOD
    z = bxor1(a, b)
    if c then z = bxor(z, c, ...) end
    return z
  elseif a then return a % MOD
  else return 0 end
end
local function band(a, b, c, ...)
  local z
  if b then
    a = a % MOD
    b = b % MOD
    z = ((a + b) - bxor1(a,b)) / 2
    if c then z = bit32_band(z, c, ...) end
    return z
  elseif a then return a % MOD
  else return MODM end
end
local function bnot(x) return (-1 - x) % MOD end
local function rshift1(a, disp)
  if disp < 0 then return lshift(a,-disp) end
  return math.floor(a % 2 ^ 32 / 2 ^ disp)
end
local function rshift(x, disp)
  if disp > 31 or disp < -31 then return 0 end
  return rshift1(x % MOD, disp)
end
local function lshift(a, disp)
  if disp < 0 then return rshift(a,-disp) end
  return (a * 2 ^ disp) % 2 ^ 32
end
local function rrotate(x, disp)
  x = x % MOD
  disp = disp % 32
  local low = band(x, 2 ^ disp - 1)
  return rshift(x, disp) + lshift(low, 32 - disp)
end
local k = {
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5,
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}
local function str2hexa(s)
  return (string.gsub(s, ".", function(c) return string.format("%02x", string.byte(c)) end))
end
local function num2s(l, n)
  local s = ""
  for i = 1, n do
    local rem = l % 256
    s = string.char(rem) .. s
    l = (l - rem) / 256
  end
  return s
end
local function s232num(s, i)
  local n = 0
  for i = i, i + 3 do n = n*256 + string.byte(s, i) end
  return n
end
local function preproc(msg, len)
  local extra = 64 - ((len + 9) % 64)
  len = num2s(8 * len, 8)
  msg = msg .. "\128" .. string.rep("\0", extra) .. len
  assert(#msg % 64 == 0)
  return msg
end
local function initH256(H)
  H[1] = 0x6a09e667
  H[2] = 0xbb67ae85
  H[3] = 0x3c6ef372
  H[4] = 0xa54ff53a
  H[5] = 0x510e527f
  H[6] = 0x9b05688c
  H[7] = 0x1f83d9ab
  H[8] = 0x5be0cd19
  return H
end
local function digestblock(msg, i, H)
  local w = {}
  for j = 1, 16 do w[j] = s232num(msg, i + (j - 1)*4) end
  for j = 17, 64 do
    local v = w[j - 15]
    local s0 = bxor(rrotate(v, 7), rrotate(v, 18), rshift(v, 3))
    v = w[j - 2]
    w[j] = w[j - 16] + s0 + w[j - 7] + bxor(rrotate(v, 17), rrotate(v, 19), rshift(v, 10))
  end
 
  local a, b, c, d, e, f, g, h = H[1], H[2], H[3], H[4], H[5], H[6], H[7], H[8]
  for i = 1, 64 do
    local s0 = bxor(rrotate(a, 2), rrotate(a, 13), rrotate(a, 22))
    local maj = bxor(band(a, b), band(a, c), band(b, c))
    local t2 = s0 + maj
    local s1 = bxor(rrotate(e, 6), rrotate(e, 11), rrotate(e, 25))
    local ch = bxor (band(e, f), band(bnot(e), g))
    local t1 = h + s1 + ch + k[i] + w[i]
    h, g, f, e, d, c, b, a = g, f, e, d + t1, c, b, a, t1 + t2
  end
 
  H[1] = band(H[1] + a)
  H[2] = band(H[2] + b)
  H[3] = band(H[3] + c)
  H[4] = band(H[4] + d)
  H[5] = band(H[5] + e)
  H[6] = band(H[6] + f)
  H[7] = band(H[7] + g)
  H[8] = band(H[8] + h)
end
local function sha256(msg)
  msg = preproc(msg, #msg)
  local H = initH256({})
  for i = 1, #msg, 64 do digestblock(msg, i, H) end
  return str2hexa(num2s(H[1], 4) .. num2s(H[2], 4) .. num2s(H[3], 4) .. num2s(H[4], 4) ..
          num2s(H[5], 4) .. num2s(H[6], 4) .. num2s(H[7], 4) .. num2s(H[8], 4))
end
local function panic()
  page = 0
  log("Panicking! Shutting down KristWallet.")
end
local function makeaddressbyte(j)
  if j <= 6 then return "0"
  elseif j <= 13 then return "1"
  elseif j <= 20 then return "2"
  elseif j <= 27 then return "3"
  elseif j <= 34 then return "4"
  elseif j <= 41 then return "5"
  elseif j <= 48 then return "6"
  elseif j <= 55 then return "7"
  elseif j <= 62 then return "8"
  elseif j <= 69 then return "9"
  elseif j <= 76 then return "a"
  elseif j <= 83 then return "b"
  elseif j <= 90 then return "c"
  elseif j <= 97 then return "d"
  elseif j <= 104 then return "e"
  elseif j <= 111 then return "f"
  elseif j <= 118 then return "g"
  elseif j <= 125 then return "h"
  elseif j <= 132 then return "i"
  elseif j <= 139 then return "j"
  elseif j <= 146 then return "k"
  elseif j <= 153 then return "l"
  elseif j <= 160 then return "m"
  elseif j <= 167 then return "n"
  elseif j <= 174 then return "o"
  elseif j <= 181 then return "p"
  elseif j <= 188 then return "q"
  elseif j <= 195 then return "r"
  elseif j <= 202 then return "s"
  elseif j <= 209 then return "t"
  elseif j <= 216 then return "u"
  elseif j <= 223 then return "v"
  elseif j <= 230 then return "w"
  elseif j <= 237 then return "x"
  elseif j <= 244 then return "y"
  elseif j <= 251 then return "z"
  else return "e"
  end
end
function checkdir()
  if fs.isDir("kst") then
    math.randomseed(os.time()) 
    checkfile("log_wallet","-----KRISTWALLET LOG FILE-----")
    checkfile("enabled","true") --Disabling this just makes KristWallet refuse to start.
    checkfile("sweepv1","true")
    checkfile("appendhashes","true") --Disabling this makes it possible to use KristWallet with extremely old addresses.
    checkfile("autoupdate","true")
    checkfile("whitelisted","false")
    checkfile("rebootonexit","false")
    checkfile("autologin","false")
    checkfile("keyAL",sha256(""))
    checkfile("keyLV",sha256(math.random(1000000)..os.time())) --This is where the local vault's krist is stored. DO NOT DESTROY!
    checkfile("versionserver","https://raw.githubusercontent.com/BTCTaras/kristwallet/master/staticapi/version")
    checkfile("updateserver","https://raw.githubusercontent.com/BTCTaras/kristwallet/master/kristwallet")
    checkfile("syncnode","http://krist.ceriat.net/")
    checkfile("whitelist","")
    checkfile("blacklist","")
  else
    fs.makeDir("kst")
  end
end
function openwallet()
  term.setBackgroundColor(8)
  term.clear()
  local krists = 0
  repeat
    term.setCursorPos(3+(3*krists),3)
    drawKrist()
    krists = krists + 1
  until krists == 16
  krists = 0
  repeat
    term.setCursorPos(3+(3*krists),16)
    drawKrist()
    krists = krists + 1
  until krists == 16
  term.setBackgroundColor(8)
  term.setTextColor(32768)
  term.setCursorPos(6,6)
  term.write("Password:")
  term.setCursorPos(6,8)
         -----|---+---------+---------+---------+-----|---+-
  term.write("Please enter your secret password to")
  term.setCursorPos(6,9)
  term.write("use Krist. If this is your first time")
  term.setCursorPos(6,10)
  term.write("using Krist, type your desired password.")
  term.setCursorPos(6,11)
  term.write("You will be able to access your Krist")
  term.setCursorPos(6,12)
  term.write("on any computer on any server as long")
  term.setCursorPos(6,13)
  term.write("as you type in the same password! It will")
  term.setCursorPos(6,14)
  term.write("not be saved or shared with anyone.")
  term.setCursorPos(16,6)
  local password = ""
  if readconfig("autologin") then
    password = readconfig("keyAL")
  else
    password = read("*")
	if password == "" then term.setCursorPos(16,6) password = read("*") end
    if readconfig("appendhashes") then password = sha256("KRISTWALLET"..password) end
  end
  term.clear()
  term.setCursorPos(1,1)
  page = 1+gui*(10*(gui-1))
  if readconfig("appendhashes") then masterkey = password.."-000" else masterkey = password end
  log("Read password")
  addressv1 = string.sub(sha256(masterkey),0,10)
  log("Derived address: "..addressv1)
  address = makev2address(masterkey)
  log("Derived address: "..address)
  balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..addressv1))
  if balance > 0 and readconfig("sweepv1") then local transaction = readURL(readconfig("syncnode").."?pushtx&q="..address.."&pkey="..masterkey.."&amt="..balance); log("Swept hex address") end
  balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
	if balance >= 100000 then log("Woah! There's a small fortune here!") elseif balance > 0 then log("There is some krist here!") end
  if readconfig("whitelisted") then
    local whitelist = readconfig("whitelist")
    if string.find(whitelist, address) == nil then
      log(address.." is not on the whitelist!")
      print("Sorry, this wallet is not on the whitelist for this computer!")
      page = 0
      os.sleep(3)
    end
  else
    local blacklist = readconfig("blacklist")
    if string.find(blacklist, addressv1) ~= nil then
      log(addressv1.." is on the blacklist!")
      print("Your wallet is blocked from this computer!")
      page = 0
      os.sleep(3)
    elseif string.find(blacklist, address) ~= nil then
      log(address.." is on the blacklist!")
      print("Your wallet is blocked from this computer!")
      page = 0
      os.sleep(3)
    end
  end
  addresslv = makev2address(readconfig("keyLV"))
  log("Loaded local vault")
  os.sleep()
  http.post(readconfig("syncnode") .. "/login", "privatekey=" .. textutils.urlEncode(masterkey) .. "&v=2")
  log("Sent pkey hash to auth server")
end
function makev2address(key)
  local protein = {}
  local stick = sha256(sha256(key))
  local n = 0
  local link = 0
  local v2 = "k"
  repeat
    if n < 9 then protein[n] = string.sub(stick,0,2)
    stick = sha256(sha256(stick)) end
    n = n + 1
  until n == 9
  n = 0
  repeat
    link = tonumber(string.sub(stick,1+(2*n),2+(2*n)),16) % 9
    if string.len(protein[link]) ~= 0 then
      v2 = v2 .. makeaddressbyte(tonumber(protein[link],16))
      protein[link] = ''
      n = n + 1
    else
      stick = sha256(stick)
    end
  until n == 9
  return v2
end
local function postgraphic(px,py,id)
  term.setCursorPos(px,py)
  if id == 0 then drawKrist()
  elseif id == 1 then
    --Mined Krist
    term.setCursorPos(px+1,py)
    term.setBackgroundColor(256)
    term.setTextColor(128)
    term.write("/T\\")
    term.setCursorPos(px,py+1)
    term.write("/")
    term.setCursorPos(px+2,py+1)
    term.write("|")
    term.setCursorPos(px+4,py+1)
    term.write("\\")
    term.setCursorPos(px+2,py+2)
    term.write("|")
    term.setCursorPos(px+2,py+3)
    term.write("|")
    term.setCursorPos(px+4,py+2)
    drawKrist()
  elseif id == 2 then
    --Sent Krist
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(16384)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+2,py)
    term.write("/\\")
    term.setCursorPos(px+2,py+1)
    term.write("||")
  elseif id == 3 then
    --Received Krist
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(8192)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+2,py)
    term.write("||")
    term.setCursorPos(px+2,py+1)
    term.write("\\/")
  elseif id == 4 then
    --Sent to yourself
    term.setCursorPos(px,py+2)
    term.setBackgroundColor(256)
    term.setTextColor(16)
    term.write(" ")
    term.setCursorPos(px+1,py+3)
    term.write("    ")
    term.setCursorPos(px+5,py+2)
    term.write(" ")
    term.setBackgroundColor(1)
    term.setCursorPos(px+1,py)
    term.write("/\\||")
    term.setCursorPos(px+1,py+1)
    term.write("||\\/")
  elseif id == 5 then
    --Swept from v1 address
    term.setCursorPos(px+1,py)
    term.setBackgroundColor(256)
    term.setTextColor(128)
    term.write(" v1 ")
    term.setCursorPos(px+2,py+1)
    term.setBackgroundColor(1)
    term.setTextColor(2048)
    term.write("||")
    term.setCursorPos(px+2,py+2)
    term.write("\\/")
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16)
    term.setTextColor(32768)
    term.write(" v2 ")
  elseif id == 6 then
    --Name registered
    term.setBackgroundColor(32)
    term.setTextColor(8192)
    term.setCursorPos(px+4,py)
    term.write("/")
    term.setCursorPos(px+1,py+1)
    term.write("\\")
    term.setCursorPos(px+3,py+1)
    term.write("/")
    term.setCursorPos(px+2,py+2)
    term.write("V")
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16384)
    term.setTextColor(4)
    term.write(".kst")
  elseif id == 7 then
    --Name operation
    term.setBackgroundColor(8)
    term.setTextColor(512)
    term.setCursorPos(px+1,py)
    term.write(" a ")
    term.setBackgroundColor(1)
    term.write("\\")
    term.setBackgroundColor(8)
    term.setCursorPos(px+1,py+1)
    term.write("====")
    term.setCursorPos(px+1,py+2)
    term.write("====")
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16384)
    term.setTextColor(4)
    term.write(".kst")
  elseif id == 8 then
    --Name sent
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16384)
    term.setTextColor(4)
    term.write(".kst")
    term.setTextColor(16384)
    term.setBackgroundColor(1)
    term.setCursorPos(px+2,py)
    term.write("/\\")
    term.setCursorPos(px+2,py+1)
    term.write("||")
  elseif id == 9 then
    --Name received
    term.setCursorPos(px+1,py+3)
    term.setBackgroundColor(16384)
    term.setTextColor(4)
    term.write(".kst")
    term.setTextColor(8192)
    term.setBackgroundColor(1)
    term.setCursorPos(px+1,py)
    term.write("||")
    term.setCursorPos(px+1,py+1)
    term.write("\\/")
    term.setTextColor(16384)
    term.setCursorPos(px+3,py)
    term.write("/\\")
    term.setCursorPos(px+3,py+1)
    term.write("||")
  end
end
function wallet()
  hud()
  local pagebefore = page
  local event, button, xPos, yPos = os.pullEvent("mouse_click")
  if gui == 1 and xPos >= 3 and xPos <= 14 then
    if yPos == 5 then
      page = 1
      balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
    end
    if yPos == 7 then
      page = 2
      subject = address
      scroll = 0
    end
    if yPos == 9 then
      page = 3
      balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
    end
    if yPos == 11 then
      page = 8
    end
    if yPos == 13 then
      page = 4
    end
    if yPos == 15 then
      page = 15
    end
    if yPos == 17 then
      page = 0
    end
  elseif gui == 2 then
    if yPos == 2 and xPos >= 19 and xPos <= 24 then
      page = 0
    end
  end
  local lexm = http.get(readconfig("syncnode").."?listnames="..address)
  local lem = false
  local lexmm
  if lexm.readAll then
	lem = true
	lexmm = lexm.readAll():gsub("\n+$", "")
  end
	
  if page == 1 then
    balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
    if (yPos-7)%5 == 0 and yPos >= 7 and xPos >= 26 and xPos <= 35 then
      subject = string.sub(readURL(readconfig("syncnode").."?listtx="..address.."&overview"),13+(31*((yPos-7)/5)),22+(31*((yPos-7)/5)))
      if string.len(subject) == 10 and subject ~= "N/A(Mined)" and subject ~= "N/A(Names)" then
        page = 2
      end
    end
  elseif page == 2 then
    if yPos > 2 and yPos <= 2+ar-(16*(scroll)) and xPos >= 31 and xPos < 41 then
      if stpeer[(yPos-2)+(16*(scroll))] == "N/A(Mined)" then
        --possibly link to a block later?
      elseif stpeer[(yPos-2)+(16*(scroll))] == "N/A(Names)" then
        --possibly link to a name later??
      else
        subject = stpeer[(yPos-2)+(16*(scroll))]
        scroll = 0
      end
    end
    if yPos == 19 and xPos >= 32 and xPos <= 36 then
      scroll = 0
    end
    if yPos == 19 and xPos >= 38 and xPos <= 41 then
      scroll = math.max(0,scroll-1)
    end
    if yPos == 19 and xPos >= 43 and xPos <= 46 then
      scroll = math.min(lastpage,scroll+1)
    end
    if yPos == 19 and xPos >= 48 then
      scroll = lastpage
    end
    if yPos == 1 and xPos >= 17 then
      page = 6
    end
    log("Page index is "..scroll)
  elseif page == 3 then
    if xPos >= 17 then
      term.setCursorPos(33,5)
      local recipient = read()
      term.setCursorPos(33,6)
      log("Read recipient for transfer")
      local amount = read()
      log("Read amount for transfer")
      local transaction = readURL(readconfig("syncnode").."?pushtx2&q="..recipient.."&pkey="..masterkey.."&amt="..amount)
      balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
      log("Attempting to send "..amount.." KST to "..recipient)
      term.setCursorPos(19,8)
      if transaction == "Success" then
        term.setTextColor(8192)
        term.write("Transfer successful")
        log("Transfer successful")
        term.setTextColor(32768)
      elseif string.sub(transaction,0,5) == "Error" then
        local problem = "An unknown error happened"
        local code = tonumber(string.sub(transaction,6,10))
        if code == 1 then problem = "Insufficient funds available" end
        if code == 2 then problem = "Not enough KST in transaction" end
        if code == 3 then problem = "Can't comprehend amount to send" end
        if code == 4 then problem = "Invalid recipient address" end
        term.setTextColor(16384)
        term.write(problem)
        log(problem)
        term.setTextColor(32768)
      else
        term.setTextColor(16384)
        term.write(transaction)
        term.setTextColor(32768)
      end
      os.sleep(2.5) --lower this if you do tons of transfers
      log("Unfroze display")
    end
  elseif page == 4 then
    if yPos == 3 and xPos >= 19 and xPos <= 31 then
      page = 5
      scroll = 0
    end
    if yPos == 4 and xPos >= 19 and xPos <= 31 then
      page = 10
    end
    if yPos == 3 and xPos >= 35 and xPos <= 48 then
      page = 6
    end
    if yPos == 4 and xPos >= 35 and xPos <= 46 then
      page = 7
    end
  elseif page == 5 then
    if yPos > 2 and xPos >= 27 and xPos <= 36 then
      page = 2
      subject = blkpeer[(yPos-2)]
      scroll = 0
    end
  elseif page == 6 then
    term.setCursorPos(18,1)
    term.write("                       ")
    term.setCursorPos(18,1)
    term.write("ADDRESS ")
    subject = read()
    if string.len(subject) == 10 then
      page = 2
      scroll = 0
    else
      page = 6
    end
  elseif page == 7 then
    if yPos > 2 and yPos <= 18 and xPos >= 20 and xPos < 30 then
      if blkpeer[(yPos-2)] ~= "N/A(Burnt)" then
        page = 2
        subject = blkpeer[(yPos-2)]
        scroll = 0
      end
    end
  elseif page == 15 then
	
	local function isEdit(xpo)
		return xpo >= 39 and xpo <= 42
	end
	local function isSend(xpo)
		return xpo >= 44 and xpo <= 47
	end
	
	if xPos and yPos then
		local listofnames = split(lexmm, ";")
		if yPos == 1 and xPos >= 46 then
			page = 16
		elseif lem and yPos >= 3 and isEdit(xPos) then
			if listofnames[yPos - 3] then
				page = 17
				local nameclicked = yPos - 3
				subject = listofnames[nameclicked]
			end
		elseif lem and yPos >= 3 and isSend(xPos) then
			if listofnames[yPos - 3] then
				page = 18
				local nameclicked = yPos - 3
				subject = listofnames[nameclicked]
			end
		end
	end
  elseif page == 8 then
    if yPos == 3 and xPos >= 19 and xPos <= 30 then
      page = 9
    end
    if yPos == 3 and xPos >= 35 and xPos <= 47 then
      page = 16
    end
    if yPos == 4 and xPos >= 35 and xPos <= 47 then
      --page = 18
    end
    if yPos == 4 and xPos >= 19 and xPos <= 29 then
      page = 13
    end
  elseif page == 18 then
		if yPos == 5 and xPos >= 30 then
      term.setCursorPos(30,5)
      term.write("                           ")
      term.setCursorPos(30,5)
      maxspace = read():lower()
      term.setCursorPos(19,7)
      pagespace = readURL(readconfig("syncnode").."?name_transfer&pkey="..masterkey.."&name="..subject.."&q="..maxspace)
			if pagespace == "Success" then
			end
				term.write("Name transferred")
				log("Tried sending a name to "..maxspace)
				os.sleep(3)
				page = 15
		end
  elseif page == 16 then
    if yPos == 4 and xPos >= 25 then
      term.setCursorPos(25,4)
      term.write("                           ")
      term.setCursorPos(25,4)
      name = read():lower():gsub(".kst",""):gsub(" ","")
      term.setCursorPos(25,4)
      term.write("Please wait...             ")
      if string.len(name) > 0 then
        if name == "a" or name == "name" or name == "id" or name == "owner" or name == "registered" or name == "updated" or name == "expires" or name == "unpaid" then
          availability = 0
        else
          availability = tonumber(readURL(readconfig("syncnode").."?name_check="..name))
          log("Checked "..name..".kst for availability ("..availability..")")
          term.setCursorPos(19,7)
          if availability then
            term.setTextColor(colors.green)
            term.write("Available!")
          else
            term.setTextColor(colors.red)
            term.write("Not available!")
          end
        end
      else
        name = ""
      end
    elseif yPos == 7 and xPos >= 30 and xPos <= 39 and availability == 1 and balance >= 500 then
      availability = 2
      local k = readURL(readconfig("syncnode").."?name_new&pkey="..masterkey.."&name="..name)
    end
  elseif page == 17 then
    if yPos == 5 and xPos >= 25 then
      term.setCursorPos(25,5)
      term.write("                           ")
      term.setCursorPos(25,5)
      zone = read():gsub("http://","")
      term.setCursorPos(25,5)
      term.write("Please wait...             ")
      local sevenminutesleftuntilmaystartsfuckihavetoreleasethisnow = readURL(readconfig("syncnode").."?name_update&pkey="..masterkey.."&name="..subject.."&ar="..zone)
    elseif yPos == 7 and xPos >= 30 and xPos <= 39 and availability == 1 and balance >= 500 then
      availability = 2
      local k = readURL(readconfig("syncnode").."?name_new&pkey="..masterkey.."&name="..name)
    end
  elseif page == 9 then
    if yPos == 4 and xPos >= 30 then
      term.setCursorPos(30,4)
      term.write("                      ")
      term.setCursorPos(30,4)
      doublekey = read("*")
      term.setCursorPos(30,4)
      term.write("Please wait...        ")
      if string.len(doublekey) > 0 then
        doublekey = sha256(masterkey.."-"..sha256(doublekey))
        addressdv = makev2address(doublekey)
        balance2 = tonumber(readURL(readconfig("syncnode").."?getbalance="..addressdv))
        log("Derived double vault "..addressdv)
      else
        addressdv = ""
        balance2 = 0
      end
    end
    if yPos == 5 and xPos >= 33 then
      term.setCursorPos(33,5)
      term.write("                      ")
      term.setCursorPos(33,5)
      amt = read()
      if tonumber(amt) == nil then
        amt = 0
      elseif tonumber(amt) % 1 ~= 0 then
        amt = 0
      elseif tonumber(amt) <= 0 then
        amt = 0
      end
    end
    if yPos == 6 and xPos >= 25 and xPos <= 33 then
      if tonumber(amt) > 0 and string.len(doublekey) > 0 then
        if tonumber(amt) <= balance then
          local transaction = readURL(readconfig("syncnode").."?pushtx2&q="..addressdv.."&pkey="..masterkey.."&amt="..tonumber(amt))
          balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
          balance2 = tonumber(readURL(readconfig("syncnode").."?getbalance="..addressdv))
          log("Put "..amt.." KST in a double vault")
        end
      end
    end
    if yPos == 6 and xPos >= 35 and xPos <= 44 then
      if tonumber(amt) > 0 and string.len(doublekey) > 0 then
        if tonumber(amt) <= balance2 then
          local transaction = readURL(readconfig("syncnode").."?pushtx2&q="..address.."&pkey="..doublekey.."&amt="..tonumber(amt))
          balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
          balance2 = tonumber(readURL(readconfig("syncnode").."?getbalance="..addressdv))
          log("Took "..amt.." KST from a double vault")
        end
      end
    end
  elseif page == 13 then
    if yPos == 5 and xPos >= 33 then
      term.setCursorPos(33,5)
      term.write("                      ")
      term.setCursorPos(33,5)
      term.setTextColor(32768)
      amt = read()
      if tonumber(amt) == nil then
        amt = 0
      elseif tonumber(amt) % 1 ~= 0 then
        amt = 0
      elseif tonumber(amt) <= 0 then
        amt = 0
      end
    end
    if yPos == 6 and xPos >= 25 and xPos <= 33 then
      if tonumber(amt) > 0 then
        if tonumber(amt) <= balance then
          local transaction = readURL(readconfig("syncnode").."?pushtx2&q="..addresslv.."&pkey="..masterkey.."&amt="..tonumber(amt))
          balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
          log("Put "..amt.." KST in a local vault")
        end
      end
    end
    if yPos == 6 and xPos >= 35 and xPos <= 44 then
      if tonumber(amt) > 0 then
        if tonumber(amt) <= balance3 then
          local transaction = readURL(readconfig("syncnode").."?pushtx2&q="..address.."&pkey="..readconfig("keyLV").."&amt="..tonumber(amt))
          balance = tonumber(readURL(readconfig("syncnode").."?getbalance="..address))
          log("Took "..amt.." KST from a local vault")
        end
      end
    end
  end
  if pagebefore ~= page then log("Switched to page "..page) end
end
local function drawTab(text)
  term.setBackgroundColor(512)
  term.write(text)
end
local function drawBtn(text)
  term.setBackgroundColor(32)
  term.write(text)
end
function hud()
  term.setBackgroundColor(1)
  term.setTextColor(32768)
  term.clear()
  if gui == 1 then
    local sidebar = 1
    while sidebar < 51 do
      term.setCursorPos(1,sidebar)
      term.setBackgroundColor(8)
      term.write("                ")
      sidebar = sidebar + 1
    end
    term.setCursorPos(2,2)
    drawKrist()
    term.setBackgroundColor(8)
    term.setTextColor(32768)
    term.write(" KristWallet")
    term.setCursorPos(5,3)
    term.setTextColor(2048)
    term.write("release "..version.."")
    term.setCursorPos(2,19)
    term.write("    by 3d6")
    term.setTextColor(32768)
    term.setCursorPos(3,5)
    drawTab("  Overview  ")
    term.setCursorPos(3,7)
    drawTab("Transactions")
    term.setCursorPos(3,9)
    drawTab(" Send Krist ")
    term.setCursorPos(3,11)
    drawTab(" Special TX ")
    term.setCursorPos(3,13)
    drawTab(" Economicon ")
    term.setCursorPos(3,15)
    drawTab("Name Manager")
    term.setCursorPos(3,17)
    drawTab("    Exit    ")
    term.setBackgroundColor(1)
  elseif gui == 2 then
    term.setCursorPos(1,1)
    term.setBackgroundColor(8)
    term.write("                          ")
    term.setCursorPos(1,2)
    term.write("                          ")
    term.setCursorPos(1,3)
    term.write("                          ")
    term.setCursorPos(1,4)
    term.write("                          ")
    term.setCursorPos(2,2)
    drawKrist()
    term.setBackgroundColor(8)
    term.setTextColor(32768)
    term.write(" KristWallet")
    term.setCursorPos(5,3)
    term.setTextColor(2048)
    term.write("release "..version.."")
    term.setCursorPos(19,2)
    term.setBackgroundColor(16384)
    term.setTextColor(32768)
    term.write(" Exit ")
  end
  if page == 1 then
    term.setCursorPos(19,2)
    term.write("Your address: ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(19,5)
    local recenttransactions = ""
    if tostring(balance) ~= 'nil' then recenttransactions = readURL(readconfig("syncnode").."?listtx="..address.."&overview") end
    local txtype = 0
    local graphics = 0
    if string.len(recenttransactions) > 25 then
      repeat
        if string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == "N/A(Mined)" then txtype = 1
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == "N/A(Names)" and tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) == 0 then txtype = 7
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) == 0 then txtype = 9
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == "N/A(Names)" then txtype = 6
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == address then txtype = 4
        elseif string.sub(recenttransactions,13+(31*graphics),22+(31*graphics)) == addressv1 then txtype = 5
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) < 0 then txtype = 2
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) > 0 then txtype = 3
		else txtype = 8
        end
        postgraphic(19,5+(5*graphics),txtype)
        term.setCursorPos(26,5+(5*graphics))
        term.setBackgroundColor(1)
        term.setTextColor(32768)
        if txtype == 1 then term.write("Mined")
        elseif txtype == 2 then term.write("Sent")
        elseif txtype == 3 then term.write("Received")
        elseif txtype == 4 then term.write("Sent to yourself")
        elseif txtype == 5 then term.write("Imported")
        elseif txtype == 6 then term.write("Name registered")
        elseif txtype == 7 then term.write("Name operation")
        elseif txtype == 8 then term.write("Unknown")
        elseif txtype == 9 then term.write("Name transfer")
        end
        term.setCursorPos(26,6+(5*graphics))
        if txtype == 4 then
          term.setTextColor(32768)
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) > 0 then
          term.setTextColor(8192)
          term.write("+")
        elseif tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics))) == 0 then
          term.setTextColor(16)
        else
          term.setTextColor(16384)
        end
        if txtype < 7 then term.write(tostring(tonumber(string.sub(recenttransactions,23+(31*graphics),31+(31*graphics)))).." KST") end
        term.setCursorPos(26,7+(5*graphics))
        term.setTextColor(32768)
        if txtype ~= 6 then term.setTextColor(512) end
        if txtype == 9 or (txtype > 1 and txtype < 6) then term.write(string.sub(recenttransactions,13+(31*graphics),22+(31*graphics))) end
        --if txtype == 6 then term.write(".kst") end
        term.setCursorPos(26,8+(5*graphics))
        term.setTextColor(128)
        term.write(string.sub(recenttransactions,1+(31*graphics),12+(31*graphics)))
        graphics = graphics + 1
      until graphics >= math.floor(string.len(recenttransactions)/32)
    end
    term.setTextColor(32768)
    term.setCursorPos(19,3)
    term.write("Your balance: ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." KST ")
    term.setTextColor(512)
    local names = tonumber(readURL(readconfig("syncnode").."?getnames="..address))
    if names > 0 then term.write("["..tostring(names).."]") end
    local alert = http.get(readconfig("syncnode").."?alert="..masterkey).readAll()
    if #(alert:gsub("^%s*(.-)%s*$", "%1")) > 0 then
      term.setCursorPos(1,1)
      term.setBackgroundColor(16384)
      term.setTextColor(16)
      term.clearLine()
      term.write(alert)
    end
  elseif page == 2 then
    term.setCursorPos(18,1)
    term.write("Please wait...")
    os.sleep(0)
    subbal = readURL(readconfig("syncnode").."?getbalance="..subject)
    subtxs = readURL(readconfig("syncnode").."?listtx="..subject)
    log("Loaded transactions for address "..subject)
    log("Page index is "..scroll)
    term.setCursorPos(18,1)
    if subtxs == "end" then subbal = 0 end
    term.write("ADDRESS "..subject.." - "..subbal.." KST")
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time         Peer           Value ")
    term.setBackgroundColor(1)
    if subtxs ~= "end" then
      local tx = 0
      local s = 0
      ar = 16*scroll
      repeat
        tx = tx + 1
        stdate[tx] = string.sub(subtxs,1,12)
        subtxs = string.sub(subtxs,13)
        stpeer[tx] = string.sub(subtxs,1,10)
        subtxs = string.sub(subtxs,11)
        stval[tx] = tonumber(string.sub(subtxs,1,9))
        subtxs = string.sub(subtxs,10)
        if stpeer[tx] == subject then stval[tx] = 0 end
      until string.len(subtxs) == 3
      repeat
        ar = ar + 1
        term.setTextColor(32768)
        term.setCursorPos(18,2+ar-(16*(scroll)))
        term.write(stdate[ar])
        if stpeer[ar] ~= "N/A(Mined)" then term.setTextColor(512) end
        if stpeer[ar] == subject then term.setTextColor(32768) end
        if stpeer[ar] == "N/A(Names)" then term.setTextColor(32768) end
        term.setCursorPos(31,2+ar-(16*(scroll)))
        term.write(stpeer[ar])
        term.setCursorPos(50-string.len(tostring(math.abs(stval[ar]))),2+ar-(16*(scroll)))
        if stval[ar] > 0 then
          term.setTextColor(8192)
          term.write("+")
        elseif stval[ar] < 0 then
          term.setTextColor(16384)
        else
          term.setTextColor(32768)
          term.write(" ")
        end
        term.write(tostring(stval[ar]))
      until ar == math.min(tx,16*(scroll+1))
      term.setBackgroundColor(256)
      term.setCursorPos(17,19)
      term.write("                                   ")
      term.setCursorPos(17,19)
      term.setTextColor(32768)
      lastpage = math.floor((tx-1)/16)
      if (1+lastpage) < 100 then maxspace = maxspace.." " end
      if (1+lastpage) < 10 then maxspace = maxspace.." " end
      if (1+scroll) < 100 then pagespace = pagespace.." " end
      if (1+scroll) < 10 then pagespace = pagespace.." " end
      term.write(" Page "..pagespace..(1+scroll).."/"..maxspace..(1+lastpage))
      pagespace = ""
      maxspace = ""
      term.setCursorPos(32,19)
      term.setTextColor(128)
      term.write("First Prev Next Last")
      if (scroll > 0) then
        term.setCursorPos(32,19)
        term.setTextColor(2048)
        term.write("First Prev")
      end
      if (scroll < lastpage and tx > 16) then
        term.setCursorPos(43,19)
        term.setTextColor(2048)
        term.write("Next Last")
      end
    else
      term.write("No transactions to display!")
      term.setBackgroundColor(256)
      term.setCursorPos(17,19)
      term.write("                                   ")
      term.setCursorPos(17,19)
      term.setTextColor(32768)
      term.write(" Page   1/  1")
      term.setCursorPos(32,19)
      term.setTextColor(128)
      term.write("First Prev Next Last")
    end
  elseif page == 3 then
    term.setCursorPos(19,2)
    term.write("Your address: ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(19,3)
    term.write("Your balance: ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." KST")
    term.setTextColor(32768)
    term.setCursorPos(19,5)
    term.write("Recipient:    ")
    term.write("                   ")
    term.setCursorPos(19,6)
    term.write("Amount (KST): ")
    term.write("                   ")
  elseif page == 4 then
    term.setCursorPos(19,2)
    term.write("Mining          Addresses")
    term.setTextColor(512)
    term.setCursorPos(19,3)
    term.write("Latest blocks   Address lookup")
    term.setCursorPos(19,4)
    term.write("Lowest hashes   Top balances")
    term.setCursorPos(19,5)
    --term.write("Lowest nonces   ")
    term.setTextColor(32768)
    term.setCursorPos(19,7)
    --term.write("Economy         Transactions")
    term.setTextColor(512)
    term.setCursorPos(19,8)
    --term.write("KST issuance    Latest transfers")
    term.setCursorPos(19,9)
    --term.write("KST distrib.    Largest transfers")
  elseif page == 5 then
    local blocks = readURL(readconfig("syncnode").."?blocks")
    local tx = 0
    ar = 0
    local height = string.sub(blocks,1,8)
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    height = tonumber(string.sub(blocks,1,8))
    blocks = string.sub(blocks,9)
    local today = string.sub(blocks,1,10)
    blocks = string.sub(blocks,11)
    repeat
      tx = tx + 1
      blktime[tx] = string.sub(blocks,1,8)
      blocks = string.sub(blocks,9)
      blkpeer[tx] = string.sub(blocks,1,10)
      blocks = string.sub(blocks,11)
      blkhash[tx] = string.sub(blocks,1,12)
      blocks = string.sub(blocks,13)
      if stpeer[tx] == subject then stval[tx] = 0 end
    until string.len(blocks) == 0
    term.setCursorPos(18,1)
    term.write("Height: "..tostring(height))
    term.setCursorPos(36,1)
    term.write("Date: "..today)
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time     Miner      Hash          ")
    ----------(" 00:00:00 0000000000 000000000000 ")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(18,2+ar)
      term.write(blktime[ar])
      if blkpeer[ar] ~= "N/A(Burnt)" then term.setTextColor(512) end
      term.setCursorPos(27,2+ar)
      term.write(blkpeer[ar])
      term.setTextColor(32768)
      term.setCursorPos(38,2+ar)
      term.write(blkhash[ar])
    until ar == math.min(tx,17*(scroll+1))
  elseif page == 6 then
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write(" Time         Peer           Value ")
    term.setBackgroundColor(256)
    term.setCursorPos(17,19)
    term.write("                                   ")
    term.setCursorPos(17,19)
    term.setTextColor(32768)
    term.write(" Page    /")
    term.setCursorPos(32,19)
    term.setTextColor(128)
    term.write("First Prev Next Last")
    term.setBackgroundColor(1)
    term.setCursorPos(18,1)
    term.write("ADDRESS (click to edit)")
  elseif page == 7 then
    local blocks = readURL(readconfig("syncnode").."?richapi")
    local tx = 0
    ar = 0
    local height = string.sub(blocks,1,8)
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    repeat
      tx = tx + 1
      blkpeer[tx] = string.sub(blocks,1,10)
      blocks = string.sub(blocks,11)
      blktime[tx] = tonumber(string.sub(blocks,1,8))
      blocks = string.sub(blocks,9)
      blkhash[tx] = string.sub(blocks,1,11)
      blocks = string.sub(blocks,12)
    until string.len(blocks) == 0
    term.setCursorPos(18,1)
    term.write("Krist address rich list")
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.write("R# Address     Balance First seen  ")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(17,2+ar)
      if ar < 10 then term.write(" ") end
      term.write(ar)
      term.setCursorPos(20,2+ar)
      if blkpeer[ar] ~= "N/A(Burnt)" then term.setTextColor(512) end
      term.write(blkpeer[ar])
      term.setTextColor(32768)
      term.setCursorPos(39-string.len(tostring(math.abs(blktime[ar]))),2+ar)
      term.write(blktime[ar])
      term.setCursorPos(40,2+ar)
      term.write(blkhash[ar])
    until ar == 16
  elseif page == 8 then
    term.setCursorPos(19,2)
    term.write("Storage         Names")
    term.setTextColor(512)
    term.setCursorPos(19,3)
    term.write("Double vault    Register name")
    term.setCursorPos(19,4)
    term.write("Local vault")
    term.setCursorPos(19,5)
    --term.write("Disk vault      v1 SHA vault")
    term.setCursorPos(19,6)
    --term.write("SHA vault       v1 wallet")
  elseif page == 9 then
    term.setCursorPos(25,2)
    term.write("Double vault manager")
    term.setCursorPos(19,8)
    term.write("Using double vaults is a way to")
    term.setCursorPos(19,9)
    term.write("store your Krist under an extra")
    term.setCursorPos(19,10)
    term.write("layer of security. You can only")
    term.setCursorPos(19,11)
    term.write("access a double vault from your")
    term.setCursorPos(19,12)
    term.write("wallet (on any server) and then")
    term.setCursorPos(19,13)
    term.write("only after typing an extra pass")
    term.setCursorPos(19,14)
    term.write("code. Double wallets are wholly")
    term.setCursorPos(19,15)
    term.write("invisible to unauthorized users")
    term.setCursorPos(19,16)
    term.write("of your wallet; they can not be")
    term.setCursorPos(19,17)
    term.write("seen or opened without the pass")
    term.setCursorPos(19,18)
    term.write("code set by you.")
    term.setCursorPos(19,4)
    term.write("Pass code: ")
    term.setCursorPos(19,5)
    term.write("Amount (KST): ")
    term.setCursorPos(30,4)
    if string.len(doublekey) == 0 then
      term.setTextColor(256)
      term.write("(click to set)")
    else
      term.setTextColor(8192)
      term.write("Ready: "..balance2.." KST")
      if tonumber(amt) > 0 then
        term.setCursorPos(25,6)
        term.setTextColor(32768)
        term.setBackgroundColor(128)
        if tonumber(amt) <= balance then
          term.setBackgroundColor(2)
        end
        term.write(" Deposit ")
        term.setBackgroundColor(1)
        term.write(" ")
        term.setBackgroundColor(128)
        if tonumber(amt) <= balance2 then
          term.setBackgroundColor(2)
        end
        term.write(" Withdraw ")
        term.setBackgroundColor(1)
      end
    end
    term.setCursorPos(33,5)
    if amt == 0 then
      term.setTextColor(256)
      term.write("(click to set)")
    else
      term.setTextColor(32768)
      term.write(amt)
    end
    term.setTextColor(32768)
  elseif page == 10 then
    local blocks = readURL(readconfig("syncnode").."?blocks&low")
    local tx = 0
    ar = 0
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    repeat
      tx = tx + 1
      blktime[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkpeer[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkhash[tx] = string.sub(blocks,1,20)
      blocks = string.sub(blocks,21)
    until string.len(blocks) == 0
    term.setCursorPos(17,1)
    term.setBackgroundColor(256)
    term.write(" Date   Block# Hash                ")
    ----------(" Feb 28 000000 000000000000oooooooo")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(18,1+ar)
      term.write(blktime[ar])
      term.setCursorPos(31-string.len(tostring(math.abs(tonumber(blkpeer[ar])))),1+ar)
      term.write(tonumber(blkpeer[ar]))
      term.setTextColor(256)
      term.setCursorPos(32,1+ar)
      term.write(blkhash[ar])
      term.setTextColor(32768)
      term.setCursorPos(32,1+ar)
      term.write(string.sub(blkhash[ar],1,12))
    until ar == math.min(tx,18)
  elseif page == 11 then
    local blocks = readURL(readconfig("syncnode").."?blocks&low&lownonce")
    local tx = 0
    ar = 0
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    repeat
      tx = tx + 1
      blktime[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkpeer[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkhash[tx] = string.sub(blocks,1,12)
      blocks = string.sub(blocks,13)
    until string.len(blocks) == 0
    term.setCursorPos(17,1)
    term.setBackgroundColor(256)
    term.write(" Date   Block# Nonce               ")
    ----------(" Feb 28 000000 000000000000")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(18,1+ar)
      term.write(blktime[ar])
      term.setCursorPos(31-string.len(tostring(math.abs(tonumber(blkpeer[ar])))),1+ar)
      term.write(tonumber(blkpeer[ar]))
      term.setTextColor(32768)
      term.setCursorPos(32,1+ar)
      term.write(tonumber(blkhash[ar]))
    until ar == math.min(tx,18)
  elseif page == 12 then
    local blocks = readURL(readconfig("syncnode").."?blocks&low&highnonce")
    local tx = 0
    ar = 0
    local blktime = {}
    blkpeer = {}
    local blkhash = {}
    repeat
      tx = tx + 1
      blktime[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkpeer[tx] = string.sub(blocks,1,6)
      blocks = string.sub(blocks,7)
      blkhash[tx] = string.sub(blocks,1,12)
      blocks = string.sub(blocks,13)
    until string.len(blocks) == 0
    term.setCursorPos(17,1)
    term.setBackgroundColor(256)
    term.write(" Date   Block# Nonce               ")
    ----------(" Feb 28 000000 000000000000")
    term.setBackgroundColor(1)
    repeat
      ar = ar + 1
      term.setCursorPos(18,1+ar)
      term.write(blktime[ar])
      term.setCursorPos(31-string.len(tostring(math.abs(tonumber(blkpeer[ar])))),1+ar)
      term.write(tonumber(blkpeer[ar]))
      term.setTextColor(32768)
      term.setCursorPos(32,1+ar)
      term.write(tonumber(blkhash[ar]))
    until ar == math.min(tx,18)
  elseif page == 13 then
    balance3 = tonumber(readURL(readconfig("syncnode").."?getbalance="..addresslv))
    term.setCursorPos(25,2)
    term.write("Local vault manager")
    term.setCursorPos(19,8)
    term.write("Local vaults are a place to put")
    term.setCursorPos(19,9)
    term.write("Krist in the form of a file on")
    term.setCursorPos(19,10)
    term.write("a computer. Unlike traditional")
    term.setCursorPos(19,11)
    term.write("wallets, local vaults can only")
    term.setCursorPos(19,12)
    term.write("be accessed on the computer")
    term.setCursorPos(19,13)
    term.write("they were initially created on.")
    term.setCursorPos(19,14)
    term.write("If you do this, please ensure")
    term.setCursorPos(19,15)
    term.write("that this computer is never")
    term.setCursorPos(19,16)
    term.write("stolen or broken, as your money")
    term.setCursorPos(19,17)
    term.write("may be lost if you don't have a")
    term.setCursorPos(19,18)
    term.write("backup.")
    term.setCursorPos(19,4)
    term.write("KST put here: "..balance3)
    term.setCursorPos(19,5)
    term.write("Amount (KST): ")
    term.setCursorPos(33,5)
    if amt == 0 then
      term.setTextColor(256)
      term.write("(click to set)")
    else
      term.setTextColor(32768)
      term.write(amt)
    end
    if tonumber(amt) > 0 then
      term.setCursorPos(25,6)
      term.setTextColor(32768)
      term.setBackgroundColor(128)
      if tonumber(amt) <= balance then
        term.setBackgroundColor(2)
      end
      term.write(" Deposit ")
      term.setBackgroundColor(1)
      term.write(" ")
      term.setBackgroundColor(128)
      if tonumber(amt) <= balance3 then
        term.setBackgroundColor(2)
      end
      term.write(" Withdraw ")
      term.setBackgroundColor(1)
    end
  elseif page == 14 then
    term.setBackgroundColor(1)
    term.setCursorPos(19,2)
    term.write("Local settings")
    --deprecated for now
  elseif page == 15 then
    term.setBackgroundColor(1)
    term.setCursorPos(18,1)
    term.write(".KST domain name manager     [New]")
    term.setCursorPos(46,1)
    term.setBackgroundColor(32)
    term.setTextColor(1)
    term.write(" + NEW")
    term.setCursorPos(17,2)
    term.setBackgroundColor(256)
    term.setTextColor(32768)
    term.write(" Name                 Actions      ")
    term.setBackgroundColor(1)
    term.setCursorPos(18,3)
    local namelist = readURL(readconfig("syncnode").."?listnames="..address)
	local splitname = split(namelist, ";")
	

    if #splitname == 0 then
      term.setTextColor(256)
      term.write("No names to display!")
    else
      local namecount = 1
      repeat
				local thisname = splitname[namecount]
				--namelist:sub(0,namelist:find(";")-1)
        term.setTextColor(32768)
        term.setCursorPos(18,3+namecount)
        term.write(splitname[namecount]..".kst")
        term.setCursorPos(39,3+namecount)
        term.setTextColor(512)
        if thisname == "a" or thisname == "name" or thisname == "owner" or thisname == "updated" or thisname == "registered" or thisname == "expires" or thisname == "id" or thisname == "unpaid" then term.setTextColor(256) end
        term.write("Edit Send ")
        term.setTextColor(256)
        term.write("Go")
        namecount = namecount + 1
      until namecount == #splitname+1
    end
    --term.write("a.kst                Edit Send Go")
    term.setBackgroundColor(1)
  elseif page == 16 then
    term.setBackgroundColor(1)
    term.setCursorPos(20,2)
    term.write(".KST domain name registration")
    term.setCursorPos(19,4)
    term.write("Name: ")
    if name == "" then
      term.setTextColor(colors.lightGray)
      term.write("(click to set)")
    else
      term.write(name)
      term.setTextColor(colors.lightGray)
      term.write(".kst")
    end
    term.setTextColor(colors.black)
    term.setCursorPos(19,5)
    term.write("Cost: 500 KST")
    term.setCursorPos(19,7)
    --term.write("Available! [Register]")
    if name == "" then
      term.setTextColor(colors.blue)
      term.write("Please select a name!")
    elseif availability == 1 then
      term.setTextColor(colors.green)
      term.write("Available! ")
      --if balance >= 500 then
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.lime)
        term.write(" Register ")
        term.setBackgroundColor(colors.white)
      --end
    elseif availability == 2 then
      term.setTextColor(colors.yellow)
      term.write("Name registered!")
    else
      term.setTextColor(colors.red)
      term.write("Not available!")
    end
    term.setTextColor(colors.black)
    term.setCursorPos(19,9)
    term.write(".KST domain names are used on")
    term.setCursorPos(19,10)
    term.write("the KristScape browser. For")
    term.setCursorPos(19,11)
    term.write("more information, please see")
    term.setCursorPos(19,12)
    term.write("the Krist thread.")
    term.setCursorPos(19,14)
    term.write("All Krist spent on names will")
    term.setCursorPos(19,15)
    term.write("be added to the value of")
    term.setCursorPos(19,16)
    term.write("future blocks; essentially")
    term.setCursorPos(19,17)
    term.write("being \"re-mined.\"")
  elseif page == 17 then
    term.setBackgroundColor(1)
    term.setCursorPos(28,2)
    term.write(".KST zone file")
    term.setCursorPos(19,4)
    term.write("Name: "..subject)
    term.setTextColor(colors.lightGray)
    term.write(".kst")
    term.setTextColor(colors.black)
    term.setCursorPos(19,7)
    term.write("Your name's zone file is the")
    term.setCursorPos(19,8)
    term.write("URL of the site it is pointing")
    term.setCursorPos(19,9)
    term.write("to. When KristScape navigates")
    term.setCursorPos(19,10)
    term.write("to a name, it will make an HTTP")
    term.setCursorPos(19,11)
    term.write("get request to the above URL.")
    term.setCursorPos(19,12)
    term.write("The zone record should not")
    term.setCursorPos(19,13)
    term.write("include a protocol (http://)")
    term.setCursorPos(19,14)
    term.write("and shouldn't end with a")
    term.setCursorPos(19,15)
    term.write("slash. You can redirect a name")
    term.setCursorPos(19,16)
    term.write("to another name by making the")
    term.setCursorPos(19,17)
    term.write("first character of the record")
    term.setCursorPos(19,18)
    term.write("a dollar sign; e.g. $krist.kst")
    term.setTextColor(colors.black)
    term.setCursorPos(19,5)
    term.write("Zone: ")
    zone = readURL(readconfig("syncnode").."?a="..subject)
    if zone == "" then
      term.setTextColor(colors.lightGray)
      term.write("(click to set)")
    else
      term.write(zone)
    end
  elseif page == 18 then
    term.setBackgroundColor(1)
    term.setCursorPos(28,2)
    term.write("Name transfer")
    term.setCursorPos(19,4)
    term.write("Name: "..subject)
    term.setTextColor(colors.lightGray)
    term.write(".kst")
    term.setTextColor(colors.black)
    term.setCursorPos(19,5)
    term.write("Recipient: ")
  elseif page == 21 then
    term.setBackgroundColor(1)
    term.setCursorPos(4,6)
    term.write("Address - ")
    term.setTextColor(16384)
    term.write(address)
    term.setTextColor(32768)
    term.setCursorPos(4,7)
    term.write("Balance - ")
    term.setTextColor(1024)
    if tostring(balance) == 'nil' then balance = 0 end
    term.write(tostring(balance).." KST")
    term.setTextColor(32768)
    term.setCursorPos(3,9)
  end
end
boot()
