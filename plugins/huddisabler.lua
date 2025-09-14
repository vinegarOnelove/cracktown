local PLUGIN = PLUGIN
PLUGIN.name = "HUD disabler"
PLUGIN.author = "Verne"
PLUGIN.desc = "Disables the HUD."

ix.option.Add("DisableHUD", ix.type.bool, false, {
	category = "STALKER Settings",
	description = "Disables the HUD."
})

--[[ This is the function you have to paste after "function PLUGIN:HUDPaint()"

	if ix.option.Get("DisableHUD", false) then
		return false
	else
		--Here goes the rest of the function logic
	end

]]