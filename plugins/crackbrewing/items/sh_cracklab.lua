ITEM.name = "Крэк лаборатория"
ITEM.description = "Лаборатория для варки веществ, довольно проста в использовании."
ITEM.category = "Наркотики"
ITEM.model = "models/props_lab/crematorcase.mdl"
ITEM.skin = 0
ITEM.width = 2
ITEM.height = 2
ITEM.price = 100

ITEM.functions.SimplePlace = {
    name = "Установить лабораторию",
    icon = "icon16/box.png",
    OnRun = function(item)
        local client = item.player
        local trace = client:GetEyeTrace()
        local pos = trace.HitPos
        
        local brewingbarrel = ents.Create("ix_cracklab")
        brewingbarrel:SetPos(pos + Vector(0, 0, 20))
        brewingbarrel:SetAngles(Angle(0, client:EyeAngles().y, 0))
        brewingbarrel:Spawn()
        brewingbarrel:SetNetVar("owner", client:SteamID())
        
        client:EmitSound("physics/metal/metal_barrel_impact_hard"..math.random(1,7)..".wav", 80)
        client:Notify("Лаборатория установлена!")
        
        return true
    end
}
