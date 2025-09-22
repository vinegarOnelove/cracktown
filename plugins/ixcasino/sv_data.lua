local PLUGIN = PLUGIN

function PLUGIN:SaveData()
    local saveData

    for _, v in pairs(ents.FindByClass("double_or_nothing")) do
        saveData = saveData or {}
        saveData[#saveData + 1] = {
            Class = v:GetClass(),
            Pos = v:GetPos(),
            Angle = v:GetAngles(),
            Model = v:GetModel(),
            Skin = v:GetSkin(),
            Color = v:GetColor(),
            Material = v:GetMaterial(),
            Movable = IsValid(v:GetPhysicsObject()) and v:GetPhysicsObject():IsMoveable() or false,
            bNoCollision = v:GetCollisionGroup() == COLLISION_GROUP_WORLD,
            Jackpot = v:GetJackpot()
        }
    end

    for _, v in pairs(ents.FindByClass("wheel_of_luck")) do
        saveData[#saveData + 1] = {
            Class = v:GetClass(),
            Pos = v:GetPos(),
            Angle = v:GetAngles(),
            Model = v:GetModel(),
            Skin = v:GetSkin(),
            Color = v:GetColor(),
            Material = v:GetMaterial(),
            Movable = IsValid(v:GetPhysicsObject()) and v:GetPhysicsObject():IsMoveable() or false,
            bNoCollision = v:GetCollisionGroup() == COLLISION_GROUP_WORLD,
            Jackpot = v:GetJackpot()
        }
    end

    self:SetData(saveData)
end

function PLUGIN:LoadData()
    self.stored = self:GetData() or {}

    for _, v in pairs(self.stored) do
        local ent = ents.Create(v.Class)

        if IsValid(ent) then
            ent:SetPos(v.Pos)
            ent:SetAngles(v.Angle)
            ent:SetModel(v.Model)
            ent:SetSkin(v.Skin)
            ent:SetColor(v.Color)
            ent:SetMaterial(v.Material)
            
            -- Spawn the entity first before setting other properties
            ent:Spawn()
            ent:Activate()

            if v.BodyGroups then
                for i, bg in pairs(v.BodyGroups) do
                    ent:SetBodygroup(i, bg)
                end
            end

            if v.SubMaterial then
                for i, sm in pairs(v.SubMaterial) do
                    ent:SetSubMaterial(i - 1, sm)
                end
            end

            -- Check if physics object is valid before using it
            local physObj = ent:GetPhysicsObject()
            if IsValid(physObj) and v.Movable then
                physObj:EnableMotion(true)
            end

            if IsValid(physObj) and not v.Movable then
                physObj:EnableMotion(false)
            end

            if v.bNoCollision then
                ent:SetCollisionGroup(COLLISION_GROUP_WORLD)
            end

            -- Set jackpot after spawning
            if ent.SetJackpot then
                ent:SetJackpot(v.Jackpot or 0)
            end
        end
    end
end