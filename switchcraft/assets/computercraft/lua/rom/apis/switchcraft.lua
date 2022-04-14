local GITHUB_API_URL = "https://api.github.com"

function tps()
  local h = http.get("http://tps.switchcraft.pw")
  if not h then return 0 end
  local tps = tonumber(h.readAll())
  h.close()
  return tps
end

function isYemmelOn()
  return true, "big brother is watching you"
end

function isDrunk(n)
  local h, err = http.get("https://lemmmy.pw/bac?u=" .. textutils.urlEncode(n))
  if err then error("Not ok") end
  
  local data = textutils.unserialiseJSON(h.readAll())
  return data.drunk
end

function isYemmelDrunk()
  return isDrunk("Yemmel")
end
isYemDrunk = isYemmelDrunk

function isLemmmyDrunk()
  return isDrunk("Lemmmy")
end
isLemDrunk = isLemmmyDrunk

function githubLimits(key)
  key = key or _G._GIT_API_KEY or "guest"
  local headers = {}

  local url = GITHUB_API_URL .. "/rate_limit"
  if key ~= "guest" then
    headers.Authorization =  'token ' .. key
  end

  local h, err = http.get(url, headers)
  if not h or err then
    error("Error contacting GitHub API: " .. err)
  end

  return json.decode(h.readAll())
end

isYemOn = isYemmelOn
