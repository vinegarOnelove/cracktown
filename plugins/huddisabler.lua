local PLUGIN = PLUGIN
PLUGIN.name = "HUD disabler"
PLUGIN.author = "Verne"
PLUGIN.desc = "Disables the HUD."

function PLUGIN:ShouldHideBars() 
return true 
end