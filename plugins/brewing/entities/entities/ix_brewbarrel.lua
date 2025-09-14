AddCSLuaFile()

local PLUGIN = PLUGIN;

ENT.Base = "base_entity";
ENT.Type = "anim";
ENT.PrintName = "Brewing Barrel";
ENT.Category = "Helix";
ENT.Spawnable = true;
ENT.RenderGroup = RENDERGROUP_BOTH;

local comboRisk = {
  ["water"] = 0,
  ["ginsparklingwater"] = 2,
  ["ginspecialwater"] = 4,
  ["vodkawater"] = 2,
  ["vodkasparklingwater"] = 3,
  ["vodkaspecialwater"] = 2,
  ["whiskeywater"] = 3,
  ["whiskeysparklingwater"] = 4,
  ["whiskeyspecialwater"] = 4
};

if SERVER then
  function ENT:Initialize()
    self:SetModel("models/props/de_inferno/wine_barrel.mdl");
    self:SetSolid(SOLID_VPHYSICS);
    self:PhysicsInit(SOLID_VPHYSICS);

    local physObj = self:GetPhysicsObject()

    if (IsValid(physObj)) then
      physObj:EnableMotion(true);
      physObj:Wake();
    end;

    print(physObj:IsMoveable());

    self:SetStatus("Idle");
  end;

function ENT:SetupDataTables()
        self:NetworkVar("String", 0, "Status")
    end

    -- Игрок нажимает Е
    function ENT:Use(ply)
        -- проверка кулдауна
        if CurTime() < (self.nextUse or 0) then return end
        self.nextUse = CurTime() + 1 -- 1 секунда кулдаун

        if self:GetStatus() == "Idle" then
            local char = ply:GetCharacter()
            local inv = char and char:GetInventory()
            if not inv then return end

            -- Проверяем рецепты
            for id, recipe in pairs(PLUGIN.recipes) do
                local hasAll = true
                for _, item in ipairs(recipe.input) do
                    if not inv:HasItem(item) then
                        hasAll = false
                        break
                    end
                end

                if hasAll then
                    -- Удаляем ингредиенты
                    for _, item in ipairs(recipe.input) do
                        local found = inv:HasItem(item)
                        if found then found:Remove() end
                    end

                    ply:Notify("Вы начали варку: " .. recipe.output)
                    self:SetStatus("Brewing")

                    -- включаем звук варки
                    self:EmitSound("ambient/water/underwater.wav", 65, 100)

                    timer.Simple(recipe.time, function()
                        if IsValid(self) then
                            -- Останавливаем звук
                            self:StopSound("ambient/water/underwater.wav")

                            -- Проверка риска взрыва
                            if math.random(1, 100) <= recipe.risk then
                                self:EmitSound("weapons/explode5.wav", 100, 100)
                                util.BlastDamage(self, ply, self:GetPos(), 150, 40)
                                local effect = EffectData()
                                effect:SetOrigin(self:GetPos())
                                util.Effect("Explosion", effect)
                                self:Remove()
                                if IsValid(ply) then
                                    ply:Notify("Бочка взорвалась! (" .. recipe.risk .. "% шанс)")
                                end
                            else
                                self:SetStatus("Finished")
                                self.recipeID = id
                                if IsValid(ply) then
                                    ply:Notify("Варка завершена, заберите результат!")
                                end
                            end
                        end
                    end)

                    return
                end
            end

            ply:Notify("У вас нет подходящих ингредиентов!")
        elseif self:GetStatus() == "Finished" then
            local recipe = PLUGIN.recipes[self.recipeID]
            if recipe then
                local char = ply:GetCharacter()
                local inv = char and char:GetInventory()
                if inv then
                    inv:Add(recipe.output)
                    ply:Notify("Вы забрали " .. recipe.output)
                end
            end

            self:SetStatus("Idle")
            self.recipeID = nil
        elseif self:GetStatus() == "Brewing" then
            ply:Notify("Бочка варит, подождите...")
        end
    end

    function ENT:OnRemove()
        -- если бочку убрали, выключаем звук
        self:StopSound("ambient/water/underwater.wav")
    end
end


if CLIENT then
  function ENT:Draw()
    self:DrawModel();
  end;
end;
