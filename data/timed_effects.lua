-- Veins of the Earth
-- Copyright (C) 2013 Zireael, Sebsebeleb
--
-- This program is free software: you can redistribute it and/or modify
-- it under the terms of the GNU General Public License as published by
-- the Free Software Foundation, either version 3 of the License, or
-- (at your option) any later version.
--
-- This program is distributed in the hope that it will be useful,
-- but WITHOUT ANY WARRANTY; without even the implied warranty of
-- MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
-- GNU General Public License for more details.
--
-- You should have received a copy of the GNU General Public License
-- along with this program.  If not, see <http://www.gnu.org/licenses/>.


local Stats = require "engine.interface.ActorStats"
local Particles = require "engine.Particles"

load("/data/timed_effects/poisons.lua")

--Conditions for below 0 hp
newEffect{
	name = "DISABLED",
	desc = "Barely alive",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# is barely alive!", "+Disabled" end,
	on_lose = function(self, err) return "#Target# got up from the ground.", "-Disabled" end,
	activate = function(self, eff)
		eff.tmpid = self:addTemporaryValue("movement_speed_bonus", -0.50)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("movement_speed_bonus", eff.tmpid)
	end,
}

newEffect{
	name = "DYING",
	desc = "Bleeding out",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# is bleeding to death!", "+Dying" end,
	on_lose = function(self, err) return "#Target# has become stable.", "-Dying" end,
	activate = function(self, eff)
		eff.tmpid = self:addTemporaryValue("never_move", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("never_move", eff.tmpid)
	end,
}

--Load penalties
newEffect{
	name = "HEAVY_LOAD",
	desc = "Encumbered",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return end, --"#Target# is encumbered!", "+Load" end,
	on_lose = function(self, err) return end, --"#Target# is no longer encumbered.", "-Load" end,
	activate = function(self, eff)
		eff.loadpenaltyId = self:addTemporaryValue("load_penalty", 6)
		eff.maxdexId = self:addTemporaryValue("max_dex_bonus", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("load_penalty", eff.loadpenaltyId)
		self:removeTemporaryValue("max_dex_bonus", eff.maxdexId)
	end,
}

newEffect{
	name = "MEDIUM_LOAD",
	desc = "Encumbered",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return end, --"#Target# is encumbered!", "+Load" end,
	on_lose = function(self, err) return end, --"#Target# is no longer encumbered.", "-Load" end,
	activate = function(self, eff)
		eff.loadpenaltyId = self:addTemporaryValue("load_penalty", 3)
		eff.maxdexId = self:addTemporaryValue("max_dex_bonus", 3)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("load_penalty", eff.loadpenaltyId)
		self:removeTemporaryValue("max_dex_bonus", eff.maxdexId)
	end,
}

-- Basic Conditions

newEffect{
	name = "FELL",
	desc = "Fell to the ground",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# fell!", "+Fell" end,
	on_lose = function(self, err) return "#Target# got up from the ground.", "-Fell" end,
	activate = function(self, eff)
		eff.tmpid = self:addTemporaryValue("never_move", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("never_move", eff.tmpid)
	end,
}

newEffect{
	name = "SLEEP",
	desc = "Sleeping",
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# falls asleep!", "+Sleep" end,
	on_lose = function(self, err) return "#Target# wakes up.", "-Sleep" end,
	activate = function(self, eff)
		eff.tmpid = self:addTemporaryValue("sleep", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("sleep", eff.tmpid)
	end,
}

newEffect{
	name = "BLIND",
	desc = "Blinded",
	long_desc = [[The character cannot see. He takes a -2 penalty to Armor Class and loses his Dexterity bonus to AC (if any). 
		All opponents are considered to have total concealment (50% miss chance) to the blinded character.]],
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# loses sight!", "+Blind" end,
	on_lose = function(self, err) return "#Target# regains sight.", "-Blind" end,

}

--Dummies so that concealment works
newEffect{
	name = "DARKNESS",
	desc = "In magical darkness",
	long_desc = [[The character cannot see. All opponents have partial concealment (20% miss chance).]],
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# loses sight!", "+Blind" end,
	on_lose = function(self, err) return "#Target# regains sight.", "-Blind" end,
}

newEffect{
	name = "FAERIE",
	desc = "Outlined",
	long_desc = [[The character is outlined by a magical ring of fire. All concealment except darkness spell is cancelled.]],
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# is outlined!", "+Outline" end,
	on_lose = function(self, err) return "#Target# is no longer outlined.", "-Outline" end,
	activate = function(self, eff)
        eff.particle = self:addParticles(Particles.new("faerie", 1))
    end,
    deactivate = function(self, eff)
        self:removeParticles(eff.particle)
    end,
}

newEffect{
	name = "FATIGUE",
	desc = "Fatigued",
	long_desc = [["A fatigued character can neither run nor charge and takes a -2 penalty to Strength and Dexterity. Doing anything that would normally cause fatigue causes the fatigued character to become exhausted. After 8 hours of complete rest, fatigued characters are no longer fatigued.]],
	type = "physical",
	status = "detrimental",
	on_gain = function(self, err) return "#Target# is fatigued!", "+Fatigue" end,
	on_lose = function(self, err) return "#Target# is no longer fatigued", "-Fatigue" end,
	activate = function(self, eff)
		local stat = { [Stats.STAT_STR]=-2, [Stats.STAT_DEX]=-2 }
		self:effectTemporaryValue(eff, "inc_stats", stat)
		eff.decrease = self:addTemporaryValue("stat_decrease_str", 1)
		eff.decrease2 = self:addTemporaryValue("stat_decrease_dex", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_decrease_con", eff.decrease)
		self:removeTemporaryValue("stat_decrease_dex", eff.decrease2)
	end
}

newEffect{
	name = "ACIDBURN",
	desc = "Burning from acid",
	type = "physical",
	status = "detrimental",
	parameters = { power=1 },
	on_gain = function(self, err) return "#Target# is covered in acid!", "+Acid" end,
	on_lose = function(self, err) return "#Target# is free from the acid.", "-Acid" end,
	on_timeout = function(self, eff)
		DamageType:get(DamageType.ACID).projector(eff.src or self, self.x, self.y, DamageType.ACID, eff.power)
	end,
}

newEffect{
	name = "INVISIBLE",
	desc = "Invisible",
	type = "physical",
	status = "beneficial",
	parameters = { power=1 },
	on_gain = function(self, err) return "#Target# fades from sight!", "+Invisible" end,
	on_lose = function(self, err) return "#Target# reappears!", "-Invisible" end,
	activate = function(self, eff)
		eff.invis = self:addTemporaryValue("stealth", eff.power)
	--[[	if not self.shader then
			eff.set_shader = true
			self.shader = "invis_edge"
			self:removeAllMOs()
			game.level.map:updateMap(self.x, self.y)
		end]]
	end,
	deactivate = function(self, eff)
	--[[	if eff.set_shader then
			self.shader = nil
			self:removeAllMOs()
			game.level.map:updateMap(self.x, self.y)
		end]]
		self:removeTemporaryValue("stealth", eff.invis)
	end,
}


--Modified ToME 4 code
newEffect{
	name = "FEAR",
	desc = "Panicked",
	type = "mental",
	subtype = { fear=true },
	status = "detrimental",
	parameters = {},
	on_gain = function(self, err) return "#Target# becomes panicked!", "+Panicked" end,
	on_lose = function(self, err) return "#Target# is no longer panicked", "-Panicked" end,
	activate = function(self, eff)
	end,
	deactivate = function(self, eff)
	end,
	do_act = function(self, eff)
		if not self:enoughEnergy() then return nil end
		if eff.source.dead then return true end

		-- apply periodic timer instead of random chance
		if not eff.timer then
			eff.timer = rng.float(0, 100)
		end
		if self:willSave(15) then
			eff.timer = eff.timer 
			game.logSeen(self, "%s struggles against the panic.", self.name:capitalize())
		else
			eff.timer = eff.timer + rng.float(0, 100)
		end
		if eff.timer > 100 then
			eff.timer = eff.timer - 100

			local distance = core.fov.distance(self.x, self.y, eff.source.x, eff.source.y)
			if distance <= eff.range then
				-- in range
				if not self:attr("never_move") then
					local sourceX, sourceY = eff.source.x, eff.source.y

					local bestX, bestY
					local bestDistance = 0
					local start = rng.range(0, 8)
					for i = start, start + 8 do
						local x = self.x + (i % 3) - 1
						local y = self.y + math.floor((i % 9) / 3) - 1

						if x ~= self.x or y ~= self.y then
							local distance = core.fov.distance(x, y, sourceX, sourceY)
							if distance > bestDistance
									and game.level.map:isBound(x, y)
									and not game.level.map:checkAllEntities(x, y, "block_move", self)
									and not game.level.map(x, y, Map.ACTOR) then
								bestDistance = distance
								bestX = x
								bestY = y
							end
						end
					end

					if bestX then
						self:move(bestX, bestY, false)
						game.logPlayer(self, "#F53CBE#You panic and flee from %s.", eff.source.name)
					else
						game.logSeen(self, "#F53CBE#%s panics and tries to flee from %s.", self.name:capitalize(), eff.source.name)
						self:useEnergy(game.energy_to_act * self:combatMovementSpeed(bestX, bestY))
					end
				end
			end
		end
	end,
}

--Magical radiation, Zireael
newEffect{
	name = "MAG_RADIATION",
	desc = "Magical radiation",
	type = "physical",
	status = "detrimental",
	parameters = { power=2 },
	on_gain = function(self, err) return "#Target# is enveloped by underground magical radiation!", "+Radiation" end,
	on_lose = function(self, err) return "#Target# is free from the radiation.", "-Radiation" end,
	on_timeout = function(self, eff)
		DamageType:get(DamageType.FORCE).projector(eff.src or self, self.x, self.y, DamageType.FORCE, eff.power)
	end,
}

--Sebsebeleb
newEffect{
	name = "RAGE",
	desc = "Raging!",
	type = "mental",
	on_gain = function(self, err) return "#Target# is in a furious rage!", "+Rage" end,
	on_lose = function(self, err) return "#Target# has calmed down from the rage", "-Rage" end,
	activate = function(self, eff)
		local inc = { [Stats.STAT_STR]=4, [Stats.STAT_DEX]=4 }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		self:effectTemporaryValue(eff, "will_save", 2)
		self:effectTemporaryValue(eff, "combat_untyped", -2)
		eff.increase = self:addTemporaryValue("stat_increase_dex", 1)
		eff.increase2 = self:addTemporaryValue("stat_increase_str", 1)
	end,
	deactivate = function(self, eff)
		self:setEffect(self.EFF_FATIGUE, 5, {})
		self:removeTemporaryValue("stat_increase_dex", eff.increase)
		self:removeTemporaryValue("stat_increase_str", eff.increase2)

	end,
}

newEffect{
	name = "BLOOD_VENGANCE",
	desc = "Angry!",
	type = "mental",
	activate = function(self, eff)
		local inc = { [Stats.STAT_STR]=2, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_str", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_str", eff.increase)
	end,
}


--Buff spells, Zireael
newEffect{
	name = "BEAR_ENDURANCE",
	desc = "Boost Con!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_CON]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_con", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_con", eff.increase)
	end,
}

newEffect{
	name = "BULL_STRENGTH",
	desc = "Boost Str!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_STR]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_str", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_str", eff.increase)
	end,
}

newEffect{
	name = "EAGLE_SPLENDOR",
	desc = "Boost Cha!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_CHA]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_cha", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_cha", eff.increase)
	end,
}

newEffect{
	name = "OWL_WISDOM",
	desc = "Boost Wis!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_WIS]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_wis", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_wis", eff.increase)
	end,
}

newEffect{
	name = "CAT_GRACE",
	desc = "Boost Dex!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_DEX]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_dex", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_dex", eff.increase)
	end
}

newEffect{
	name = "FOX_CUNNING",
	desc = "Boost Int!",
	type = "mental",
	status = "beneficial",
	activate = function(self, eff)
		local inc = { [Stats.STAT_INT]=4, }
		self:effectTemporaryValue(eff, "inc_stats", inc)
		eff.increase = self:addTemporaryValue("stat_increase_int", 1)
	end,
	deactivate = function(self, eff)
		self:removeTemporaryValue("stat_increase_int", eff.increase)
	end,
}

--Buff spell, Seb
newEffect{
	name = "MAGE_ARMOR",
	desc = "Mage Armor",
	type = "magical",
	status = "beneficial",
	on_gain = function(self, err) return "A field seems to surround #Target#", "+Mage Armor" end,
	on_lose = function(self, err) return "The field around #Target# seems to dissipate", "-Mage Armor" end,
	activate = function(self, eff)
		self:effectTemporaryValue(eff, "combat_armor_ac", 4)
	end,
}

