function quote()
	local h = http.get("http://zen.lemmmy.pw")
	if not h then return "sad time , unhealthy for  mind .  zen uncontact" end
	local quote = h.readAll()
	h.close()
	return quote
end
