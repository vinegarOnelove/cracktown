AddCSLuaFile()

local PLUGIN = PLUGIN;

ENT.Base = "base_entity";
ENT.Type = "anim";
ENT.PrintName = "Brewing Barrel";
ENT.Category = "Helix";
ENT.Spawnable = true;
ENT.RenderGroup = RENDERGROUP_BOTH;

-- Настройки здоровья бочки
ENT.MaxHealth = 200
ENT.ExplosionDamage = 40
ENT.ExplosionRadius = 150

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

    -- Устанавливаем здоровье
    self:SetHealth(self.MaxHealth)
    self:SetMaxHealth(self.MaxHealth)
    
    self:SetStatus("Idle");
  end;

  function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("Int", 1, "Health")
    self:NetworkVar("Int", 2, "MaxHealth")
  end

  -- Функция для нанесения урона
  function ENT:OnTakeDamage(dmg)
    local attacker = dmg:GetAttacker()
    local damage = dmg:GetDamage()
    
    -- Уменьшаем здоровье
    local newHealth = self:GetHealth() - damage
    self:SetHealth(math.max(0, newHealth))
    
    -- Эффекты при получении урона
    if damage > 10 then
      self:EmitSound("physics/wood/wood_crate_impact_hard"..math.random(1,3)..".wav", 75, 100)
      
      -- Эффект искр при большом уроне
      if damage > 9750 then
        local effect = EffectData()
        effect:SetOrigin(self:GetPos())
        effect:SetNormal(self:GetUp())
        util.Effect("cball_explode", effect)
      end
    end
    
    -- Проверяем если бочка уничтожена
    if self:GetHealth() <= 0 and not self.Destroyed then
      self:BreakBarrel(attacker)
    end
  end

  -- Функция разрушения бочки
  function ENT:BreakBarrel(attacker)
    if self.Destroyed then return end
    self.Destroyed = true
    
    -- Останавливаем звук варки если он есть
    self:StopSound("ambient/water/underwater.wav")
    
    -- Звук разрушения
    self:EmitSound("physics/wood/wood_crate_break"..math.random(1,5)..".wav", 100, 100)
    
    -- Взрыв если бочка варила
    if self:GetStatus() == "Brewing" then
      util.BlastDamage(self, attacker or self, self:GetPos(), self.ExplosionRadius, self.ExplosionDamage)
      
      local effect = EffectData()
      effect:SetOrigin(self:GetPos())
      util.Effect("Explosion", effect)
      
      self:EmitSound("weapons/explode5.wav", 100, 100)
    else
      -- Обычное разрушение
      local effect = EffectData()
      effect:SetOrigin(self:GetPos())
      effect:SetScale(1)
      util.Effect("GlassImpact", effect)
    end
    
    -- Создаем обломки
    self:CreateDebris()
    
    -- Удаляем бочку через секунду
    timer.Simple(0.2, function()
      if IsValid(self) then
        self:Remove()
      end
    end)
  end

  -- Создание обломков
  function ENT:CreateDebris()
    for i = 1, 5 do
      timer.Simple(i * 0.1, function()
        if IsValid(self) then
          local debris = ents.Create("prop_physics")
          debris:SetModel("models/props_debris/wood_chunk02a.mdl")
          debris:SetPos(self:GetPos() + Vector(math.random(-20,20), math.random(-20,20), 30))
          debris:SetAngles(Angle(math.random(0,360), math.random(0,360), math.random(0,360)))
          debris:Spawn()
          debris:SetCollisionGroup(COLLISION_GROUP_DEBRIS)
          
          -- Удаляем обломки через время
          timer.Simple(10, function()
            if IsValid(debris) then
              debris:Remove()
            end
          end)
        end
      end)
    end
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
                self:BreakBarrel(ply)
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