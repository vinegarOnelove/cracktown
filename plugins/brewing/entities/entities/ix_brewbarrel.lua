AddCSLuaFile()

local PLUGIN = PLUGIN;

ENT.Base = "base_anim";
ENT.Type = "anim";
ENT.PrintName = "Brewing Barrel";
ENT.Category = "Helix";
ENT.Spawnable = true;
ENT.RenderGroup = RENDERGROUP_BOTH;
ENT.AutomaticFrameAdvance = true;

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

-- Локализация статусов для бочки
PLUGIN.barrelStatusText = PLUGIN.barrelStatusText or {
    ["Idle"] = "Пустая",
    ["Brewing"] = "Варка...",
    ["Finished"] = "Готово!"
}

function ENT:SetupDataTables()
    self:NetworkVar("String", 0, "Status")
    self:NetworkVar("Int", 1, "Health")
    self:NetworkVar("Int", 2, "MaxHealth")
end

if SERVER then
  function ENT:Initialize()
    self:SetModel("models/props/de_inferno/wine_barrel.mdl");
    self:SetSolid(SOLID_VPHYSICS);
    self:PhysicsInit(SOLID_VPHYSICS);
    self:SetUseType(SIMPLE_USE);

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
  -- Глобальные функции для безопасного доступа
  function SafeGetClass(ent)
      if not IsValid(ent) then return "invalid" end
      if not isfunction(ent.GetClass) then return "no_getclass" end
      return ent:GetClass() or "unknown"
  end

  function SafeGetStatus(ent)
      if not IsValid(ent) then return "invalid" end
      if not isfunction(ent.GetStatus) then return "no_getstatus" end
      return ent:GetStatus() or "unknown"
  end

  function ENT:Initialize()
      self.statusInitialized = false
      self.lastStatusCheck = 0
  end

  function ENT:Think()
      if CurTime() > self.lastStatusCheck + 1 then
          self.lastStatusCheck = CurTime()
          
          if isfunction(self.GetStatus) and self:GetStatus() then
              self.statusInitialized = true
          end
      end
      
      self:NextThink(CurTime() + 0.5)
      return true
  end

  function ENT:Draw()
      self:DrawModel()
      
      if not self.statusInitialized then return end
      
      local distance = self:GetPos():Distance(LocalPlayer():GetPos())
      if distance > 300 then return end
      
      local status = SafeGetStatus(self)
      local localizedStatus = PLUGIN.barrelStatusText[status] or status
      
      local ang = self:GetAngles()
      ang:RotateAroundAxis(ang:Up(), 90)
      ang:RotateAroundAxis(ang:Forward(), 90)
      
      -- Единый стиль: Выше и с небольшим смещением вперед
      local pos = self:GetPos() + self:GetUp() * 70 + self:GetForward() * 5
      
      cam.Start3D2D(pos, ang, 0.1)
          -- Фон с закругленными углами (единый стиль)
          draw.RoundedBox(8, -50, -20, 100, 35, Color(0, 0, 0, 230))
          
          -- Рамка в зависимости от статуса (единый стиль)
          if status == "Brewing" then
              surface.SetDrawColor(255, 150, 0, 255)
          elseif status == "Finished" then
              surface.SetDrawColor(0, 255, 0, 255)
          else
              surface.SetDrawColor(150, 150, 150, 255)
          end
          surface.DrawOutlinedRect(-50, -20, 100, 35, 2)
          
          -- Текст статуса с жирным шрифтом (единый стиль)
          draw.SimpleText(localizedStatus, "DermaDefaultBold", 0, 0, 
              color_white, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
              
          -- Иконка для статуса варки (единый стиль)
          if status == "Brewing" then
              draw.SimpleText("⚡", "DermaDefault", 40, -15, 
                  Color(255, 200, 0), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
          end
      cam.End3D2D()
  end

  -- Исправленный хук с защитными проверками (единый стиль)
  hook.Add("PopulateEntityInfo", "ixBrewBarrelInfo", function(tooltip, ent)
      -- 🔥 ЗАЩИТНЫЕ ПРОВЕРКИ
      if not IsValid(ent) then return end
      if not isfunction(ent.GetClass) then return end
      if SafeGetClass(ent) ~= "ix_brewbarrel" then return end
      
      if not isfunction(ent.GetStatus) then return end
      
      local status = SafeGetStatus(ent)
      local localizedStatus = PLUGIN.barrelStatusText[status] or status
      
      -- Заголовок (единый стиль)
      local name = tooltip:AddRow("name")
      name:SetText("Бочка для варки алкоголя")
      name:SetBackgroundColor(Color(100, 50, 20))
      name:SetImportant()
      name:SizeToContents()
      
      -- Статус (единый стиль)
      local statusRow = tooltip:AddRow("status")
      statusRow:SetText("Статус: " .. localizedStatus)
      statusRow:SetBackgroundColor(Color(50, 25, 10))
      statusRow:SizeToContents()
      -- Дополнительная информация (единый стиль)
      if status == "Brewing" then
          local info = tooltip:AddRow("info")
          info:SetText("Идет процесс варки алкоголя...")
          info:SetBackgroundColor(Color(80, 40, 0))
          info:SizeToContents()
      elseif status == "Finished" then
          local info = tooltip:AddRow("info")
          info:SetText("Нажмите E чтобы забрать готовый продукт")
          info:SetBackgroundColor(Color(0, 80, 0))
          info:SizeToContents()
      end
  end)
end