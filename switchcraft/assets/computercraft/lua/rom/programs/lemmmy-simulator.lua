local speech = 0

local swears = {
    "cunt",
    "gay",
    "nigger",
    "faggot",
    "fuck",
    "shit",
    "wank",
    "frenulum",
    "chink winky",
    "youre a chinky fuck"
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
