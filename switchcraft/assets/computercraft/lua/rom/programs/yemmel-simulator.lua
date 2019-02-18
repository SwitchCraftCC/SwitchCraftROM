local speech = 0

local swears = {
	"I'm not drunk",
	"I'm definitely not drunk",
	"Not drunk",
	"Notd rubk",
	"Drunkn't",
	"nicht drunk",
	"NO DRINK",
	"imn otdrunk"
}

local function swear()
    print(swears[math.random(1,#swears)])
end

local function correct(input)
    if input > 6000 and input < 9000 then
        return true
    else
        return false
    end
end

while not correct(speech) do
    swear()
    speech = math.random(1,9000)
    sleep(0)
end
