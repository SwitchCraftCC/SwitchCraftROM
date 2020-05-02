local completion = require("cc.completion")

shell.setCompletionFunction("rom/programs/command/bigmonitor.lua", function(shell, nIndex, sText, tPreviousText)
  if nIndex == 1 then
    return completion.choice(sText, {"north", "east", "south", "west"}, true)
  end
end)