AddCSLuaFile( "cl_init.lua" )
AddCSLuaFile( "shared.lua" )
include('shared.lua')

util.AddNetworkString("WOL_BeginSpin") //Triggers a spin to begin
util.AddNetworkString("WOL_BeginBonusSpin") //Triggers a spin to begin
util.AddNetworkString("WOL_StopReel") //Stops a reel from spinning.
util.AddNetworkString("WOL_TriggerLever") //Triggers the lever animation
util.AddNetworkString("WOL_FlashLights") //Cuases the machine to flash for ~1 second
util.AddNetworkString("WOL_BonusSound")
util.AddNetworkString("WOL_TriggerJackpot")
util.AddNetworkString("WOL_OpenPayTable")

sound.Add( {
	name = "reel_spin_motor",
	channel = CHAN_STATIC,
	volume = 1,
	level = 55,
	pitch = { 99, 101 },
	sound = "blues-slots/reel_rotating.ogg"
} ) 

sound.Add( {
	name = "bonus_win",
	channel = CHAN_STATIC,
	volume = 0.4,
	level = 65,
	pitch = { 100, 100 },
	sound = "blues-slots/bonus_sound.ogg"
} ) 

//Returns an ID between 1 and 8 based on the chances configured for the items
local function GetRandomItem()
	local raffle = {}
	for k, v in pairs(WOL_ITEM_CHANCE) do
		for i = 1, v do
			table.insert(raffle, k)
		end
	end
	return table.Random(raffle)
end

function ENT:PlayAnim(prop,anim,speed)
  local id = prop:LookupSequence(anim)
  prop:SetCycle( 0 )
  prop:ResetSequence(id)
  prop:SetPlaybackRate(speed)
end

function ENT:Initialize()
	//Reel model path : models/zerochain/props_casino/wheelofluck/wheelofluck_wheel.mdl
	self:SetModel("models/zerochain/props_casino/wheelofluck/wheelofluck_01.mdl")
	self:PhysicsInit( SOLID_VPHYSICS )
	self:SetMoveType( MOVETYPE_VPHYSICS )
	self:SetSolid( SOLID_VPHYSICS )
	self:SetUseType(SIMPLE_USE)

	local phys = self:GetPhysicsObject()
	if (phys:IsValid()) then
		phys:Wake()
		phys:SetMass(100) -- Set a reasonable mass for physics
		phys:EnableMotion(true) -- Ensure it can be moved initially
	end

	self:SetAutomaticFrameAdvance(true)
	
	self.reels = {}
	//Create the reels
	for i = 4, 6 do
		local bPos, bAng = self:GetBonePosition(i)
		local reel = ents.Create("wol_reel")
		reel:SetPos(bPos)
		reel:SetAngles(bAng)
		reel:SetParent(self)
		reel:Spawn()
		self.reels[i - 3] = reel
	end

	self:SetReelOne(self.reels[1])
	self:SetReelTwo(self.reels[2])
	self:SetReelThree(self.reels[3])

	if self:GetJackpot() == 0 then
		self:SetJackpot(math.random(ix.config.Get("wheelOfLuckMinJackpot"), ix.config.Get("wheelOfLuckMaxJackpot")))
	end

	self:SetBonusSpins(0)
	self:SetLastWin(0)	
	self.isSpinning = false
end

//Spins the reels, give cash reward to spinner (player)
function ENT:Spin()
	if self:GetBonusSpins() < 1 then
		if not self.spinner:GetCharacter():HasMoney(ix.config.Get("wheelOfLuckBet")) then
			self.spinner:ChatPrint(L("wolNotEnoughMoney", self.spinner) .. " (" .. ix.config.Get("wheelOfLuckBet") .. "☋)")
			return //Dont do anything else.
		else
			self.spinner:GetCharacter():TakeMoney(ix.config.Get("wheelOfLuckBet"))
			self.spinner.timeSinceLastSpin = CurTime()
			self.spinner.lastSpunMachine = self

			local jackpotAddPercentage = ix.config.Get("wheelOfLuckJackpotAdd")

			self:SetJackpot(self:GetJackpot() + (ix.config.Get("wheelOfLuckBet") * (jackpotAddPercentage / 100)))
		end

		self.isSpinning = true
		local item1 = GetRandomItem()
		local item2 = GetRandomItem()
		local item3 = GetRandomItem()

		local extraWait = 0

		//This little part essentially makes is to if they have 2 of the same item theres a 50% chance they get the third/
		if item1 == item2 then
			extraWait = 2 //Make them wait 1 more second to see it to build suspence
			local chance = math.random(0, 100)
			if chance < 25 then
				item3 = item2
			end
		end

		//Trigger lever to play 
		net.Start("WOL_TriggerLever")
			net.WriteEntity(self)
		net.Broadcast()

		self:EmitSound("blues-slots/lever_pulled.ogg", 75, 100, 1)


		timer.Simple(0.5, function()
			if not IsValid(self) then return end
			self:SetLastWin(0)

			self:EmitSound("reel_spin_motor") 

			net.Start("WOL_BeginSpin")
				net.WriteEntity(self)
			net.Broadcast()
			timer.Simple(2, function()
				if not IsValid(self) then return end
				self:EmitSound("blues-slots/reel_stop_01.ogg", 60, 100, 1)
				net.Start("WOL_StopReel")
					net.WriteInt(1, 6)
					net.WriteInt(item1, 7)
					net.WriteEntity(self)
				net.Broadcast()
			end)
			timer.Simple(3, function()
				if not IsValid(self) then return end
				self:EmitSound("blues-slots/reel_stop_02.ogg", 60, 100, 1)
				net.Start("WOL_StopReel")
					net.WriteInt(2, 6)
					net.WriteInt(item2, 7)
					net.WriteEntity(self)
				net.Broadcast()
			end)
			local wait = 4
			if extraWait ~= 0 then
				wait = 4 + extraWait
				//Emit suspsense sound
				timer.Simple(3, function()
					if not IsValid(self) then return end
					self:EmitSound("blues-slots/buildup.ogg", 60, 100, 0.9)
				end)
			end

			timer.Simple(wait, function()	
				if not IsValid(self) then return end
				self:StopSound("reel_spin_motor") //Stop rotating sound
				net.Start("WOL_StopReel")
					net.WriteInt(3, 6)
					net.WriteInt(item3, 7)
					net.WriteEntity(self)
				net.Broadcast() 
				local reward = WOL_HandleSpinEnd(spinner, item1, item2, item3) //Test
				
				//If we got some bonus spins then update the client of it.
				if reward.bonusspins > 0 then
					self:SetBonusSpins(self:GetBonusSpins() + reward.bonusspins)
				end

				if reward.bonusspins > 0 or reward.cash > 0 then
					net.Start("WOL_FlashLights")
						net.WriteEntity(self)
						net.WriteTable({[1] = reward.reel1state, [2] = reward.reel2state, [3] = reward.reel3state})
					net.Broadcast() 
				end

				//Updaet the client on what the last amount of cash won was.
				self:SetLastWin(reward.cash)
				self:GivePlayerCashReward(reward.cash)
				if reward.bonusspins <= 0 then
					if reward.winsound ~= nil then
						self:EmitSound(reward.winsound, 70, 100, 0.5)
					else
						self:EmitSound("blues-slots/reel_stop_03.ogg", 60, 100, 1)
					end
				else
					net.Start("WOL_BonusSound")
					net.WriteEntity(self)
					net.WriteBool(true)
					net.Broadcast()
					timer.Simple(1.66, function()
						if not IsValid(self) then return end
						self:SetSkin(1)
					end)
				end

				self.isSpinning = false
			end)
		end)
	else
		//Do bonus spin as there is a bonus spin pending
		local item = math.random(1,20)
		net.Start("WOL_BeginBonusSpin") //Start the bonus spin
		net.WriteEntity(self)
		net.WriteInt(item, 16)
		net.Broadcast()

		self:PlayAnim(self,"press",1)


		self:SetBonusSpins(self:GetBonusSpins() - 1)

		self.isSpinning = true
		timer.Simple(10, function() //Gets called after the bonus spin finished
			if not IsValid(self) then return end
			//Give reward
			local wait = 2
			if item == 1 then
				wait = 0
			end
			timer.Simple(wait, function()
				if not IsValid(self) then return end
				if item ~= 1 then
					self:SetLastWin(WOL_BONUS_ITEMS[item].cash)
					self:GivePlayerCashReward(WOL_BONUS_ITEMS[item].cash)
					if self:GetBonusSpins() < 1 then
						self:EndBonus()
					end
					self.isSpinning = false
				else
					self:SetLastWin(self:GetJackpot())
					self:GivePlayerCashReward(self:GetJackpot())
					self:EndBonus()
					self:SetSkin(4) //Turn off all lights!
					for k ,v in pairs(player.GetAll()) do
						ix.util.NotifyLocalized("wolWonJackpotNoti", v, self.spinner:Nick(), self:GetJackpot())
					end
					self:TriggerJackpot()
				end
			end)
		end)
	end
end

//Ends all tje bonus spins and stuff
function ENT:EndBonus()
	net.Start("WOL_BonusSound")
	net.WriteEntity(self)
	net.WriteBool(false)
	net.Broadcast()
	self:SetSkin(0)
end

//Triggers the jackpot to play the sound
function ENT:TriggerJackpot()
	net.Start("WOL_TriggerJackpot")
	net.WriteEntity(self)
	net.WriteBool(true) 
	net.Broadcast()
	timer.Simple(2.28, function()
		if not IsValid(self) then return end
		self:SetSkin(2)
		self:SetJackpot(0)
	end)
	timer.Simple(42 + 3, function()
		if not IsValid(self) then return end
		net.Start("WOL_TriggerJackpot")
		net.WriteEntity(self)
		net.WriteBool(false) 
		net.Broadcast()
		self:SetJackpot(math.random(100, 2000000))
		self.isSpinning = false
		if self:GetBonusSpins() > 0 then
			//Retrigger bonus so they can finish there spins
			net.Start("WOL_BonusSound")
			net.WriteEntity(self)
			net.WriteBool(true)
			net.Broadcast()
			timer.Simple(1.66, function()
				if not IsValid(self) then return end
				self:SetSkin(1)
			end)
		else
			self:SetSkin(0)
		end
	end)
end

//Handles triggering the maschine
function ENT:Use(act, call)
	if not self.isSpinning and call:IsPlayer() then
		if call ~= self.spinner and self.spinner ~= nil then
			if IsValid(self.spinner) and self.spinner.timeSinceLastSpin == nil then self.spinner.timeSinceLastSpin = 0 end
			if IsValid(self.spinner) and self.spinner.timeSinceLastSpin and CurTime() - self.spinner.timeSinceLastSpin < 30 and self.spinner.lastSpunMachine == self then
				call:ChatPrint("Please wait for "..self.spinner:Nick().." to finish there turn or find a new machine.")
				return
			end
		else
			if IsValid(self.spinner) and self.spinner.lastSpunMachine ~= self then
				if self.spinner.timeSinceLastSpin and CurTime() - self.spinner.timeSinceLastSpin < 30 then
					call:ChatPrint("Please wait "..tostring(30 - math.ceil(CurTime() - self.spinner.timeSinceLastSpin)).." seconds before switching machines.")
					return
				end
			else
				if call.lastSpunMachine ~= self then
					if call.timeSinceLastSpin ~= nil then
						if CurTime() - call.timeSinceLastSpin < 30 then
							call:ChatPrint("Please wait "..tostring(30 - math.ceil(CurTime() - call.timeSinceLastSpin)).." seconds before switching machines.")
							return
						end			
					end
				end
			end
		end
		self.spinner = call //The person who spun it.
		if call.timeSinceLastSpin == nil then call.timeSinceLastSpin = 0 end
		self:Spin()
	end
end

--Logical stuff like winning combinations and stuff here

//A table that contains all possible win combinations
local winningCombinations = {}

function ENT:GivePlayerCashReward(amount)
	if amount > 0 then
		ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
		if amount >= 1500 then
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
		end
		if amount >= 10000 then
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
		end
		if amount >= 100000 then
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
		end
		if amount >= 200000 then
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
			ParticleEffectAttach("wol_money_burst01",PATTACH_POINT_FOLLOW,self,0)
		end
		timer.Simple(4, function()
			if not IsValid(self) then return end
			self:StopParticles()
		end)
		self.spinner:GetCharacter():GiveMoney(amount)
		ix.util.NotifyLocalized("wolWonMoneyNoti", self.spinner, amount)
	end

end

//Adds this as a possible win (pass * to represent any item)
//For cash reward pass the amount you want them to win in cash
//For bonus spins enter the amount of bonus spins they win from this.
//Family makes it so two wins from same same family cannot occure.
local function WOL_AddWinningCombination(family, item1, item2, item3, cashreward, bonusspins, winsound)
	bonusspins = bonusspins or 0
	table.insert(winningCombinations,{family = family, item1 = item1, item2 = item2, item3 = item3, cashreward = cashreward, bonusspins = bonusspins, winsound = winsound})
end

//Pass 3 items and the spinner and it will reward the spinner if a win combination is found (or bonus spins of course)
function WOL_HandleSpinEnd(spinner, item1, item2, item3)
	local reward = WOL_GetWinningItems(item1, item2, item3)
	return reward
end

//Kinda messy but it works so its not a big deal
//It tries to find a match, if it fails then it just return 0 for cash and 0 for reward
function WOL_GetWinningItems(item1, item2, item3)
	//Convert them to there string id's
	item1 = WOL_IDToString(item1)
	item2 = WOL_IDToString(item2)
	item3 = WOL_IDToString(item3)

	local reward = {cash = 0, bonusspins = 0}
	local familiesWon = {}

	for k ,v in pairs(winningCombinations) do
		local item1Match = false
		local item2Match = false
		local item3Match = false

		local item1Contributed = false
		local item2Contributed = false
		local item3Contributed = false

		if v.item1 ~= "*" then
			if v.item1 == item1 then
				item1Match = true
				item1Contributed = true
			end
		else
			item1Match = true
		end

		if v.item2 ~= "*" then
			if v.item2 == item2 then
				item2Match = true
				item2Contributed = true
			end
		else
			item2Match = true
		end

		if v.item3 ~= "*" then
			if v.item3 == item3 then
				item3Match = true
				item3Contributed = true
			end
		else
			item3Match = true
		end

		if item1Match and item2Match and item3Match then
			if not table.HasValue(familiesWon, v.family) then
				reward.cash = reward.cash + v.cashreward
				reward.bonusspins = reward.bonusspins + v.bonusspins
				if reward.reel1state ~= true then reward.reel1state = item1Contributed end
				if reward.reel2state ~= true then reward.reel2state = item2Contributed end
				if reward.reel3state ~= true then reward.reel3state = item3Contributed end

				if v.bonusspins < 1 then
					reward.winsound = v.winsound
				else
					reward.winsound = v.winsound
				end
				table.insert(familiesWon, v.family)
			end
		end
	end
	return reward //Return the reward
end

///////////////////////////////////////////////////////////
//////This is not a config, feel free to edit it but///////
//////if you break it your responsible not me       ///////
///////////////////////////////////////////////////////////

//Bonus spins (Be sure to put single wins underneath all other otherwise they will be chosen instead.)

WOL_AddWinningCombination(1, "bonus", "bonus", "bonus", 25000 , 3)

WOL_AddWinningCombination(1, "bonus", "bonus", "*", 10000, 2, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(1, "bonus", "*", "bonus", 10000, 2, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(1, "*", "bonus", "bonus", 10000, 2, "blues-slots/win_small.ogg")

WOL_AddWinningCombination(1, "bonus", "*", "*", 5000, 1, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(1, "*", "bonus", "*", 5000, 1, "blues-slots/win_small.ogg") 
WOL_AddWinningCombination(1, "*", "*", "bonus", 5000, 1, "blues-slots/win_small.ogg")

//Raspberry
WOL_AddWinningCombination(2, "raspberry", "raspberry", "raspberry", 2500, 0, "blues-slots/win_small.ogg")

//Coins
WOL_AddWinningCombination(3, "coins", "coins", "coins", 10000, 0, "blues-slots/win_small.ogg")

WOL_AddWinningCombination(3, "coins", "coins", "*", 5000, 0, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(3, "*", "coins", "coins", 5000, 0, "blues-slots/win_small.ogg")

//diamonds

WOL_AddWinningCombination(4, "diamond", "diamond", "diamond", 20000, 0, "blues-slots/win_small.ogg")

WOL_AddWinningCombination(4, "diamond", "*", "diamond", 7500, 0, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(4, "*", "diamond", "diamond", 7500, 0, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(4, "diamond", "diamond", "*", 7500, 0, "blues-slots/win_small.ogg")

WOL_AddWinningCombination(4, "diamond", "*", "*", 1000, 0, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(4, "*", "diamond", "*", 1000, 0, "blues-slots/win_small.ogg")
WOL_AddWinningCombination(4, "*", "*", "diamond", 1000, 0, "blues-slots/win_small.ogg")

//Bar 2 (Two bars)
WOL_AddWinningCombination(5, "bar2", "bar2", "bar2", 1750, 0, "blues-slots/win_small.ogg")

//Bar (One bar)
WOL_AddWinningCombination(6, "bar", "bar", "bar", 1000, 0, "blues-slots/win_small.ogg")

//Tripple sevens
WOL_AddWinningCombination(7, "seven", "seven", "seven", 3500, 0, "blues-slots/win_small.ogg")