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

function isYemmelDrunk()
  return true
end

function githubLimits(key)
  key = key or _G._GIT_API_KEY or "guest"

  local url = GITHUB_API_URL .. "/rate_limit"
  if key ~= "guest" then
    url = url .. "?access_token=" .. textutils.urlEncode(_G._GIT_API_KEY)
  end

  local h, err = http.get(url)
  if not h or err then
    error("Error contacting GitHub API: " .. err)
  end

  return json.decode(h.readAll())
end

isYemOn = isYemmelOn
isYemDrunk = isYemmelDrunk
isLemmmyDrunk = isYemmelDrunk
isLemDrunk = isLemmmyDrunk
