ITEM.name = "Горшок для растений"
ITEM.description = "Горшок для растений, довольно прост в использовании."
ITEM.category = "Растения"
ITEM.model = "models/props_junk/terracotta01.mdl"
ITEM.skin = 0
ITEM.width = 2
ITEM.height = 2
ITEM.price = 100
ITEM.iconCam = {
	pos = Vector(188.64, 158.96, 122.03),
	ang = Angle(25, 220, 0),
	fov = 4.73
}
ITEM.exRender = true

ITEM.functions.SimplePlace = {
    name = "Установить горшок",
    icon = "icon16/box.png",
    OnRun = function(item)
        local client = item.player
        local trace = client:GetEyeTrace()
        local pos = trace.HitPos
        
        local brewingbarrel = ents.Create("ix_plant_pot")
        brewingbarrel:SetPos(pos + Vector(0, 0, 20))
        brewingbarrel:SetAngles(Angle(0, client:EyeAngles().y, 0))
        brewingbarrel:Spawn()
        brewingbarrel:SetNetVar("owner", client:SteamID())
        
        client:EmitSound("physics/metal/metal_barrel_impact_hard"..math.random(1,7)..".wav", 80)
        client:Notify("Горшок установлена!")
        
        return true
    end
}
