PLUGIN.name = "Player Corpses"
PLUGIN.author = "Your Name"
PLUGIN.description = "Оставляет трупы игроков после смерти"

ix.lang.AddTable("russian", {
    corpse = "Труп",
    corpseDesc = "Труп %s.",
    corpseSearch = "Осмотреть",
})

if SERVER then
    util.AddNetworkString("ixCreateCorpse")

    function PLUGIN:PlayerDeath(client, inflictor, attacker)
        timer.Simple(0.1, function()
            if IsValid(client) then
                self:CreateCorpse(client)
            end
        end)
    end

    function PLUGIN:CreateCorpse(client)
        if not IsValid(client) then return end
        
        local pos = client:GetPos()
        local ang = client:EyeAngles()
        ang.p = 0 -- Делаем труп горизонтальным
        
        local corpse = ents.Create("prop_ragdoll")
        if not IsValid(corpse) then return end
        
        corpse:SetModel(client:GetModel())
        corpse:SetPos(pos)
        corpse:SetAngles(ang)
        corpse:SetSkin(client:GetSkin())
        corpse:SetColor(client:GetColor())
        corpse:SetMaterial(client:GetMaterial())
        
        -- Копируем группы тела
        for i = 0, client:GetNumBodyGroups() - 1 do
            corpse:SetBodygroup(i, client:GetBodygroup(i))
        end
        
        corpse:Spawn()
        corpse:Activate()
        
        -- Копируем физические свойства
        timer.Simple(0.1, function()
            if IsValid(corpse) then
                for i = 0, corpse:GetPhysicsObjectCount() - 1 do
                    local phys = corpse:GetPhysicsObjectNum(i)
                    if IsValid(phys) then
                        local bone = client:TranslatePhysBoneToBone(i)
                        if bone then
                            local matrix = client:GetBoneMatrix(bone)
                            if matrix then
                                phys:SetPos(matrix:GetTranslation())
                            end
                        end
                    end
                end
            end
        end)
        
        -- Устанавливаем данные для поиска
        corpse:SetNetVar("playerName", client:Name())
        corpse:SetNetVar("steamID", client:SteamID())
        
        -- Удаляем труп через время
        timer.Create("CorpseCleanup_" .. corpse:EntIndex(), 300, 1, function()
            if IsValid(corpse) then
                corpse:Remove()
            end
        end)
        
        net.Start("ixCreateCorpse")
        net.WriteEntity(corpse)
        net.Broadcast()
    end

    -- Очистка трупов при перезагрузке раунда
    function PLUGIN:OnMapStart()
        for _, ent in pairs(ents.FindByClass("prop_ragdoll")) do
            if ent:GetNetVar("playerName") then
                ent:Remove()
            end
        end
    end
end

if CLIENT then
    net.Receive("ixCreateCorpse", function()
        local corpse = net.ReadEntity()
        
        if IsValid(corpse) then
            -- Добавляем возможность поиска трупа
            local ENT = {}
            
            ENT.Type = "next"
            ENT.Name = "Труп"
            ENT.Description = function(self)
                return string.format("Труп %s.", self:GetNetVar("playerName", "Неизвестного"))
            end
            
            ENT.IsPlayerCorpse = true
            
            function ENT:OnRemove()
                if IsValid(self) and self.searchSound then
                    self.searchSound:Stop()
                end
            end
            
            function ENT:CanAccess(client)
                return true
            end
            
            scripted_ents.Register(ENT, "ix_corpse")
            
            if corpse:GetClass() == "prop_ragdoll" then
                corpse:SetNetVar("id", "ix_corpse")
            end
        end
    end)
end