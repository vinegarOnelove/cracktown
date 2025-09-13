ITEM.base = "base_weapons"

ITEM.name = "ARC9 Weapon"
ITEM.category = "ARC9 Weapons"
ITEM.weaponCategory = "primary"

ITEM.isARC9Weapon = true
ITEM.defaultPreset = nil 		-- the preset code for the default attachments this item should have.
                                -- this is overwritten by item data when customized, and will do nothing if left as nil
                                -- you can generate one by saving a weapon configuration as a preset and 'exporting' it; paste the code here WITHOUT the leading [PRESET NAME] part


function ITEM:GetWeapon()
    local weapon = self.weapon
    
    if IsValid(weapon) then
        return weapon
    else
        self:SetWeapon(nil)
        return nil
    end
end

function ITEM:SetWeapon(weapon)
    if weapon and IsValid(weapon) then
        self.weapon = weapon
    else
        self.weapon = nil
    end
end

-- return either the default weapon preset or the saved one
function ITEM:GetPreset()
    local weapon = self:GetWeapon()

    if IsValid(weapon) then
        return self:GetData("preset", self.defaultPreset)
    end
end

if CLIENT then
    -- save the current export code into the item data
    function ITEM:SavePreset()
        local weapon = self:GetWeapon()

        if IsValid(weapon) then
            weapon:UpdateItemPreset()
        end
    end
end

function ITEM:OnPostLoadout()
    if (self:GetData("equip")) then
        local client = self.player
        if !IsValid(client) or !client:GetCharacter() then return end

        client.carryWeapons = client.carryWeapons or {}

        local weapon = client:Give(self.class, true)

        if weapon and (IsValid(weapon)) then
            client:RemoveAmmo(weapon:Clip1(), weapon:GetPrimaryAmmoType())
            client.carryWeapons[self.weaponCategory] = weapon

            weapon.ixItem = self

            self:SetWeapon(weapon)

            if (self.OnEquipWeapon) then
                self:OnEquipWeapon(client, weapon)
            end

            ix.arc9.InitWeapon(client, weapon, self)
        else
            --print(Format("[Helix] Cannot give weapon - %s does not exist!", self.class))  -- this does not work right, something to do with the timing of PostPlayerLoadout()?
        end
    end
end

-- this does nothing by intention, as OnLoadout is called *twice* which can lead to duplicate attachments. OnPostLoadout takes care of normal init, so this is just for you to customize
function ITEM:OnLoadout()
    return
end

function ITEM:Equip(client, bNoSelect, bNoSound)
    client.carryWeapons = client.carryWeapons or {}

    for k, _ in client:GetCharacter():GetInventory():Iter() do
        if (k.id != self.id) then
            local itemTable = ix.item.instances[k.id]

            if (!itemTable) then
                client:NotifyLocalized("tellAdmin", "wid!xt")

                return false
            else
                if (itemTable.isWeapon and client.carryWeapons[self.weaponCategory] and itemTable:GetData("equip")) then
                    client:NotifyLocalized("weaponSlotFilled", self.weaponCategory)

                    return false
                end
            end
        end
    end

    if (client:HasWeapon(self.class)) then
        client:StripWeapon(self.class)
    end

    local weapon = client:Give(self.class, !self.isGrenade)

    if weapon and (IsValid(weapon)) then
        local ammoType = weapon:GetPrimaryAmmoType()

        client.carryWeapons[self.weaponCategory] = weapon

        if (!bNoSelect) then
            client:SelectWeapon(weapon:GetClass())
        end

        if (!bNoSound) then
            client:EmitSound(self.useSound, 80)
        end

        -- Remove default given ammo.
        if (client:GetAmmoCount(ammoType) == weapon:Clip1() and self:GetData("ammo", 0) == 0) then
            client:RemoveAmmo(weapon:Clip1(), ammoType)
        end

        -- assume that a weapon with -1 clip1 and clip2 would be a throwable (i.e hl2 grenade)
        -- TODO: figure out if this interferes with any other weapons
        if (weapon:GetMaxClip1() == -1 and weapon:GetMaxClip2() == -1 and client:GetAmmoCount(ammoType) == 0) then
            client:SetAmmo(1, ammoType)
        end

        self:SetData("equip", true)

        weapon.ixItem = self

        if (self.isGrenade) then
            weapon:SetClip1(1)
            client:SetAmmo(0, ammoType)
        end
        
        self:SetWeapon(weapon)

        if (self.OnEquipWeapon) then
            self:OnEquipWeapon(client, weapon)
        end

        ix.arc9.InitWeapon(client, weapon, self)
    end
end

function ITEM:Unequip(client, bPlaySound, bRemoveItem)
    client.carryWeapons = client.carryWeapons or {}

    local weapon = client.carryWeapons[self.weaponCategory]

    if (!IsValid(weapon)) then
        weapon = client:GetWeapon(self.class)
    end

    if weapon and (IsValid(weapon)) then
        weapon.ixItem = nil
        self:SetWeapon(nil)

        self:SetData("ammo", weapon:Clip1())
        client:StripWeapon(self.class)
    end

    if (bPlaySound) then
        client:EmitSound(self.useSound, 80)
    end

    client.carryWeapons[self.weaponCategory] = nil
    self:SetData("equip", nil)
    self:RemovePAC(client)

    if (self.OnUnequipWeapon) then
        self:OnUnequipWeapon(client, weapon)
    end

    if (bRemoveItem) then
        self:Remove()
    end
end