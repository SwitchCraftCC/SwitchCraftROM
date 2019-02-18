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

isYemOn = isYemmelOn
isYemDrunk = isYemmelDrunk
isLemmmyDrunk = isYemmelDrunk
isLemDrunk = isLemmmyDrunk
