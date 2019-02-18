-- SwitchCraft chatbox legacy handler by Yemmel
-- Contact Yemmel#2747 regarding any issues

SERVER_URL = "wss://chat.switchcraft.pw"

closeReasons = {
  ["SERVER_STOPPING"] = 4000,
  ["EXTERNAL_GUESTS_NOT_ALLOWED"] = 4001,
  ["UNKNOWN_LICENCE_KEY"] = 4002,
  ["INVALID_LICENCE_KEY"] = 4003,
  ["DISABLED_LICENCE_KEY"] = 4004,
  ["CHANGED_LICENCE_KEY"] = 4005,
}

-- connection params
local running = false
local connected = false
local ws, wsURL, licenceKey
local licenceOwner, capabilities, players
local connectionAttempts = 0
local chatboxError, chatboxErrorCode

function _shouldStart()
  return settings.get("chatbox.licence_key") ~= nil
end

local function getLicenceKey()
  return settings.get("chatbox.licence_key"):gsub("%s+", "")
end

local function isVerbose()
  return settings.get("chatbox.verbose", false)
end

local function log(message)
  if not isVerbose() then return end
  local oldColour = term.getTextColour()
  term.setTextColour(colours.lightGrey)
  print("\n" .. message)
  term.setTextColour(oldColour)
end

local function handleEventMessage(data)
  if not data.event then return end

  if data.event == "join" then
    os.queueEvent("join", data.user.name or data.user.uuid, data)
  elseif data.event == "leave" then
    os.queueEvent("leave", data.user.name or data.user.uuid, data)
  elseif data.event == "death" then
    os.queueEvent(
      "death",
      data.user.name or data.user.uuid,
      data.source and (data.source.name or data.source.uuid) or nil,
      data.text,
      data
    )
  elseif data.event == "afk" then
    os.queueEvent("afk", data.user.name or data.user.uuid, data)
  elseif data.event == "afkReturn" then
    os.queueEvent("afk_return", data.user.name or data.user.uuid, data)
  end
end

local function handleMessageMessage(data)
  local event = "chat"
  if     data.channel == "discord" then event = "chat_discord"
  elseif data.channel == "me"      then event = "chat_me"
  elseif data.channel == "chatbox" then event = "chat_chatbox" end

  local source
  if data.channel == "discord" then
    source = {data.discordUser.name and (data.discordUser.name .. data.discordUser.discriminator) or data.discordUser.id}
  elseif data.channel == "chatbox" then
    source = {data.rawName, data.user.name or data.user.uuid}
  else
    source = {data.user.name or data.user.uuid}
  end

  os.queueEvent(
    event,
    unpack(source),
    data.rawText or data.text,
    data
  )
end

local function handleCommandMessage(data)
  os.queueEvent(
    "command",
    data.user.name or data.user.uuid,
    data.command,
    data.args,
    data
  )
end

local function handleMessage(eventData)
  local rawMessage = eventData[3]
  local data = json.decode(rawMessage)

  if not data or not data.type then return end

  if data.type == "hello" then
    connected = true
    licenceOwner = data.licenceOwner
    capabilities = data.capabilities
  elseif data.type == "players" then
    players = data.players
  elseif data.type == "event" then
    handleEventMessage(data)
  elseif data.type == "message" then
    handleMessageMessage(data)
  elseif data.type == "command" then
    handleCommandMessage(data)
  end
end

-- return true if we should retry
local function handleClose(eventData)
  chatboxError = eventData[3]; local err = chatboxError
  chatboxErrorCode = eventData[4]; local code = chatboxErrorCode

  if code == closeReasons.SERVER_STOPPING then
    return false
  elseif code == closeReasons.UNKNOWN_LICENCE_KEY
      or code == closeReasons.INVALID_LICENCE_KEY
      or code == closeReasons.DISABLED_LICENCE_KEY
      or code == closeReasons.CHANGED_LICENCE_KEY then
    printError("Chatbox error: ")
    printError(err)
    return false
  else
    connectionAttempts = connectionAttempts + 1

    if connectionAttempts >= 3 then
      printError("Couldn't connect to chatbox server after 3 attempts: ")
      printError((chatboxError or "unknown") .. " (" .. (chatboxErrorCode or "unknown") .. ")")

      return false
    else
      return true
    end
  end
end

-- prefix arg is no longer used
function say(text, name, prefix, mode)
  if not isConnected() or not ws then error("Chatbox is not connected.", 2) end
  if not hasCapability("say") then error("You do not have the 'say' capability.", 2) end
  if type(text) ~= "string" then error("Invalid argument #1. Expected string.", 2) end
  if name and type(name) ~= "string" then error("Invalid argument #2. Expected string.", 2) end
  if mode and mode ~= "markdown" and mode ~= "format" then error("Invalid mode argument #4. Must be 'markdown' or 'format'.", 2) end

  ws.send(json.encode({
    type = "say",
    text = text,
    name = name,
    mode = mode or "markdown"
  }))

  return true -- compat
end

function tell(user, text, name, prefix, mode)
  if not isConnected() or not ws then error("Chatbox is not connected.", 2) end
  if not hasCapability("tell") then error("You do not have the 'tell' capability.", 2) end
  if type(user) ~= "string" then error("Invalid argument #1. Expected string.", 2) end
  if type(text) ~= "string" then error("Invalid argument #2. Expected string.", 2) end
  if name and type(name) ~= "string" then error("Invalid argument #3. Expected string.", 2) end
  if mode and mode ~= "markdown" and mode ~= "format" then error("Invalid mode argument #5. Must be 'markdown' or 'format'.", 2) end

  ws.send(json.encode({
    type = "tell",
    user = user,
    text = text,
    name = name,
    mode = mode or "markdown"
  }))

  return true -- compat
end

function stop()
  running = false
  if ws then ws.close() end
end

function run()
  if running then
    error("Chatbox is already running.", 2)
  end
  running = true

  log("Connecting to chatbox server at " .. SERVER_URL)
  licenceKey = getLicenceKey()
  wsURL = SERVER_URL .. "/" .. textutils.urlEncode(licenceKey)

  http.websocketAsync(wsURL)

  while running do
    local eventData = {os.pullEventRaw()}
    local event = eventData[1]

    if event == "websocket_success" and eventData[2] == wsURL then
      ws = eventData[3]
    elseif event == "websocket_message" and eventData[2] == wsURL then
      local ok, err = pcall(handleMessage, eventData)
      if not ok then
        log("Chatbox error: " .. err)
      end
    elseif event == "websocket_closed" and eventData[2] == wsURL then
      if handleClose(eventData) then
        running = false
        run()
      end
    end
  end

  return chatboxError ~= nil and chatboxErrorCode ~= nil, chatboxError, chatboxErrorCode
end

function getError()
  return chatboxError, chatboxErrorCode
end

function isConnected()
  return running and connected
end

function getLicenceOwner()
  return licenceOwner
end

function getCapabilities()
  return capabilities or {}
end

function getPlayers()
  return players or {}
end

-- legacy compat
function getPlayerList()
  if not players then return {} end
  local out = {}
  for i, player in pairs(players) do
    out[i] = player.name or player.uuid
  end
  return out
end

function hasCapability(capability)
  if not capabilities then return false end
  for _, cap in pairs(capabilities) do
    if cap:lower() == capability:lower() then return true end
  end
  return false
end
