local args = {...}

local function printUsage()
  error("Usage: bigmonitor <facing> <width> <height> [basic]")
end

local DIR_MAPPING = {
  north = { friendly = "towards negative X", x = -1, z =  0, dir = 2 },
  south = { friendly = "towards positive X", x =  1, z =  0, dir = 3 },
  west = { friendly = "towards positive Z", x =  0, z =  1, dir = 4 },
  east = { friendly = "towards negative Z", x =  0, z = -1, dir = 5 },
}

if #args < 3 then printUsage() end

local dirArg = (args[1]):lower()
if not _.some(_.keys(DIR_MAPPING), _.partial(_.ops.equals, dirArg)) then printUsage() end
local dir = DIR_MAPPING[dirArg]
local width = tonumber(args[2])
local height = tonumber(args[3])
local basic = #args >= 4 and args[4]:lower() == "basic"

term.setTextColour(colours.green)
print(string.format(
  "A %d x %d monitor will be placed ABOVE this command computer %s. Are you sure you want to do this? [Y/N] ",
  width, height, dir.friendly
))
if read():lower() ~= "y" then error("Cancelled.") end

local startX, startY, startZ = commands.getBlockPosition()

for y = 0, height - 1 do
  for x = 0, width - 1 do
    local success, output = commands.setblock(
      startX + (x * dir.x),
      startY + y + 1,
      startZ + (x * dir.z),
      "computercraft:peripheral",
      basic and 10 or 12,
      "replace",
      {
        dir = dir.dir,
        xIndex = x,
        yIndex = y,
        width = width,
        height = height
      }
    )

    if not success then
      for _, line in pairs(output) do
        printError(line)
      end
    end
  end
end