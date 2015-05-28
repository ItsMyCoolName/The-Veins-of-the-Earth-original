-- Veins of the Earth
-- Zireael 2013-2015
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

require "engine.class"
require "engine.Actor"
require "engine.Autolevel"
require "engine.interface.ActorTemporaryEffects"
require "mod.class.interface.ActorLife"
require "engine.interface.ActorProject"
require "engine.interface.ActorLevel"
require "engine.interface.ActorStats"
require "engine.interface.ActorTalents"
require 'engine.interface.ActorInventory'
require "engine.interface.ActorResource"
require "engine.interface.ActorFOV"
require 'engine.interface.ActorQuest'
require "mod.class.interface.Combat"

require 'mod.class.interface.ActorSkills'

local Map = require "engine.Map"
local Faction = require "engine.Faction"
local DamageType = require "engine.DamageType"

--local NameGenerator = require "engine.NameGenerator"

module(..., package.seeall, class.inherit(engine.Actor,
	mod.class.interface.ActorSkills,
	engine.interface.ActorTemporaryEffects,
	mod.class.interface.ActorLife,
	engine.interface.ActorProject,
	engine.interface.ActorLevel,
	engine.interface.ActorStats,
	engine.interface.ActorTalents,
	engine.interface.ActorInventory,
	engine.interface.ActorResource,
	engine.interface.ActorFOV,
	engine.interface.ActorQuest,
	mod.class.interface.Combat))

function _M:init(t, no_default)
	-- Define some basic combat stats
	self.combat_dr = 0
	self.combat_bab = 0
	self.combat_attack = 0
	self.hit_die = 4
	self.combat_damage = 0

	--Define AC types
	self.combat_armor_ac = 0
	self.combat_magic_armor = 0
	self.combat_shield = 0
	self.combat_magic_shield = 0
	self.combat_natural = 0

	self.combat_protection = 0
	self.combat_dodge = 0
	self.combat_parry = 0

	--for various stuff which isn't above
	self.combat_untyped = 0

	--Define speed
	self.movement_speed = 1
	self.combat_attackspeed = 1

	--Some more combat stuff
	self.more_attacks = 0
	self.poison = self.poison or nil
	self.horse = self.horse or nil

	--Perks
	self.perk = self.perk or ""
	self.perk_item = self.perk_item or ""


	--Challenge Rating & ECL set to 0 & 1
	self.challenge = 0
	self.ecl = 1

	--Skill ranks
	self.max_skill_ranks = 4
	self.cross_class_ranks = math.floor(self.max_skill_ranks/2)

	-- Default melee barehanded damage
	self.combat = { dam = {1,4} }

	--Can now get classes
	self.classes = self.classes or {}

	--Templates (NPC only)
	self.template = self.template or nil
	self.special = self.special or nil

	self.sex = self.sex or "Neuter"
	--Dragons only
	self.age_cat = self.age_cat or nil

	--Saves
	self.will_save = self.will_save or 0
	self.reflex_save = self.reflex_save or 0
	self.fortitude_save = self.fortitude_save or 0

	--Make resists and projectiles work
	t.resists = t.resists or {}
	t.melee_project = t.melee_project or {}
	t.ranged_project = t.ranged_project or {}
	t.can_pass = t.can_pass or {}
	t.on_melee_hit = t.on_melee_hit or {}

	--Default sight & lite ranges
	t.sight = t.sight or 10
	t.lite = t.lite or 0

	--Resources (don't regen)
	t.spell_regen = t.spell_regen or 0
	t.psi_regen = t.psi_regen or 0

	--Actually initiate some basic engine stuff
	engine.Actor.init(self, t, no_default)
	engine.interface.ActorTemporaryEffects.init(self, t)
	mod.class.interface.ActorSkills.init(self, t)
	mod.class.interface.ActorLife.init(self, t)
	engine.interface.ActorProject.init(self, t)
	engine.interface.ActorTalents.init(self, t)
	engine.interface.ActorResource.init(self, t)
	engine.interface.ActorStats.init(self, t)
	engine.interface.ActorInventory.init(self, t)
	engine.interface.ActorLevel.init(self, t)
	engine.interface.ActorFOV.init(self, t)

	-- Short-ciruit the engine's initial forced level-up mechanism, which
	-- doesn't work quite the way we want.
	self.start_level = self.level

	-- Charges for spells
	self.charges = {}
	self.max_charges = {}
	self.allocated_charges = {}

	-- Caster levels
	self.caster_levels = {}

	--Scoring
	self.kills = 0
	self.seen = false

	--Light-related
	self.lite = 0 --Temporary test
	self.infravision = 0

	--Life stuff
	self.life = t.max_life or self.life
	--Wounds system
	self.wounds = self.wounds or 1
	t.max_wounds = t.max_wounds or 1

	self.last_attacker = nil

	self.show_portrait = t.show_portrait or false

	-- Use weapon damage actually
	if not self:getInven("MAIN_HAND") or not self:getInven("OFF_HAND") then return end
	if weapon then dam = weapon.combat.dam
	end

	self:resetCanSeeCache()

	if self.show_portrait then
		self:portraitGen()
	end
end

--Taken from Qi Daozei
function _M:onEntityMerge(a)
    -- Remove stats to make new stats work.  This is necessary for stats on a
    -- derived NPC (like kobold in the example module) to override the base
    -- define_as NPC.
    for i, s in ipairs(_M.stats_def) do
        if a.stats[i] then
            a.stats[s.short_name], a.stats[i] = a.stats[i], nil
        end
    end
end

-- Called when our stats change
function _M:onStatChange(stat, v)
	if stat == "str" then self:checkEncumbrance() end
	if stat == self.STAT_CON then self.max_life = self.max_life + v*2 end
end

function _M:zeroStats()
	if self:getStat('str') == 0 and not self.dead then self:die() end --should be helpless
	if self:getStat('dex') == 0 and not self.dead then self:die() end --should be paralyzed
	if self:getStat('con') == 0 and not self.dead then self:die() end
	if self:getStat('int') == 0 and not self.dead then self:die() end -- should be unconscious
	if self:getStat('wis') == 0 and not self.dead then self:die() end --should be unconscious
	if self:getStat('cha') == 0 and not self.dead then self:die() end --should be unconscious
end

function _M:getName(t)
	t = t or {}
	local name = self.name
	if t.indef_art then
		name = (name:match('^[AEIOUaeiou]') and 'an ' or 'a ') .. name
	end
	return name
end

function _M:act()
	if not engine.Actor.act(self) then return end

	self.changed = true

	--From ToME
	-- If resources are too low, disable sustains
	if (self.mana or 0) < 1 or (self.psi or 0) < 1 then
		for tid, _ in pairs(self.sustain_talents) do
			local t = self:getTalentFromId(tid)
			if (t.sustain_mana and self.mana < 1) then
				self:forceUseTalent(tid, {ignore_energy=true})
			elseif (t.sustain_psi and self.psi < 1) and t.remove_on_zero then
				self:forceUseTalent(tid, {ignore_energy=true})
			end
		end
	end

	--reset AoO flag
	self.madeAoO = false

	-- Cooldown talents
	self:cooldownTalents()

	-- Check terrain special effects
	game.level.map:checkEntity(self.x, self.y, Map.TERRAIN, "on_stand", self)

	-- Regen resources
	self:regenLife()
	self:regenResources()
	-- Compute timed effects
	self:timedEffects()

	--Check if stats aren't 0
	self:zeroStats()
	--Death
	self:deathStuff()

	--Poison timer
	if self.poison_timer then self.poison_timer = self.poison_timer - 1 end

	-- check passive stuff. This should be in actbase I think but I cant get it to work
	if self:knowTalent(self.T_BLOOD_VENGANCE) then
		--Bloodied!
		if self.life / self.max_life < 0.5 then
			self:setEffect(self.EFF_BLOOD_VENGANCE, 1, {})
		end
	end

	if self:attr("sleep") then self.energy.value = 0 end

	--From Startide
	-- Shrug off effects
	for eff_id, params in pairs(self.tmp) do
		local DC = params.DC_ongoing or 10
		local eff = self.tempeffect_def[eff_id]
		if eff.decrease == 0 then
			if self:saveRoll(DC, eff.type) then
				params.dur = 0
			end
		end
	end

	-- Still not dead ?
	if self.dead then return false end

	-- Ok reset the seen cache
	self:resetCanSeeCache()

	if self.on_act then self:on_act() end

	if self.never_act then return false end

	-- Fear (chance to run away)
	if self:hasEffect(self.EFF_FEAR) then
		self.tempeffect_def[self.EFF_FEAR].do_act(self, self:hasEffect(self.EFF_FEAR))
	end

	-- Still enough energy to act ?
	if self.energy.value < game.energy_to_act then return false end

	return true
end

--Are we able to move at all? Currently checks if we are able to move anywhere, aka not if we cant move certain directions
function _M:canMove()
	if self:attr("never_move") then return false end
	return true
end

function _M:move(x, y, force)
	local moved = false
	if not self:canMove() then return moved end

	local ox, oy = self.x, self.y

	 -- Never move, but allow attacking (from Qi Daozei)
        if not force and self:attr("never_move_but_attack") then
            -- NOTE: this asks the collision code to check for attacking - taken from ToME
            if not game.level.map:checkAllEntities(x, y, "block_move", self, true) then
                game.logPlayer(self, "You are unable to move!")
            end
            return false
        end

	if force or self:enoughEnergy() then

		-- Check for confusion or random movement flag.
		local rand_prob = self.ai_state and self.ai_state.random_move or 0
		local rand_move = self:hasEffect(self.EFF_CONFUSED) or rng.range(1,100) <= rand_prob
		if rand_move and self.x and self.y then
			x, y = self.x + rng.range(-1,1), self.y + rng.range(-1,1)
		end

		moved = engine.Actor.move(self, x, y, force)

		--Attacks of opportunity
		if not force and moved and (self.x ~= ox or self.y ~= oy) then
			--logging
		--[[	if self == game.player then
				game.log("Checking for AoO: ox %d, oy %d, x %d, y %d", ox, oy, x, y)
			end]]

			if self:doesProvokeAoO(ox, oy) then self:provokeAoO(ox, oy) end
		end

		if not force and moved and (self.x ~= ox or self.y ~= oy) and not self.did_energy then
				local speed = self:combatMovementSpeed(x, y)
			local use_energy = true

			if use_energy then
					self:useEnergy(game.energy_to_act * speed)
			end
		end
	end
	self.did_energy = nil

	-- This is where we do auto-search for traps.
	local grids = core.fov.circle_grids(self.x, self.y, 1, true)
		for x, yy in pairs(grids) do for y, _ in pairs(yy) do
			local trap = game.level.map(x, y, Map.TRAP)
			--Don't search for pseudo-traps
			if trap and not trap.type == "tutorial"
				--Do stuff
				and not trap:knownBy(self) and self:canSee(trap) and self:skillCheck("search", 15) then
				trap:setKnown(self, true)
				game.level.map:updateMap(x, y)
				game.logPlayer(self, "You have found a trap (%s)!", trap:getName())
			end
		end end

	return moved
end

--- Get the "path string" for this actor
-- See Map:addPathString() for more info
function _M:getPathString()
	local ps = self.open_door and "return {open_door=true,can_pass={" or "return {can_pass={"
	for what, check in pairs(self.can_pass) do
		ps = ps .. what.."="..check..","
	end
	ps = ps.."}}"
--	print("[PATH STRING] for", self.name, " :=: ", ps)
	return ps
end

--Taken from ToME 1.3.0
function _M:displace(target)
	-- Displace
	-- Check we can both walk in the tile we will end up in
	local blocks = game.level.map:checkAllEntitiesLayersNoStop(target.x, target.y, "block_move", self)
	for kind, v in pairs(blocks) do if kind[1] ~= Map.ACTOR and v then return end end
	blocks = game.level.map:checkAllEntitiesLayersNoStop(self.x, self.y, "block_move", target)
	for kind, v in pairs(blocks) do if kind[1] ~= Map.ACTOR and v then return end end

	-- Displace
	local tx, ty, sx, sy = target.x, target.y, self.x, self.y
	target:move(sx, sy, true)
	self:move(tx, ty, true)
	if target.describeFloor then target:describeFloor(target.x, target.y, true) end
	if self.describeFloor then self:describeFloor(self.x, self.y, true) end
end

--NOTE: Monkey patch for log+flyer problems
function _M:setEffect(eff_id, dur, p, silent)
	local visible, srcSeen = game:logVisible(self)  -- should a message be displayed?

	if visible then
    	engine.interface.ActorTemporaryEffects.setEffect(self, eff_id, dur, p, silent)
	else
		engine.interface.ActorTemporaryEffects.setEffect(self, eff_id, dur, p, true)
	end
end


--- Reveals location surrounding the actor
function _M:magicMap(radius, x, y, checker)
	x = x or self.x
	y = y or self.y
	radius = math.floor(radius)

	local ox, oy

	self.x, self.y, ox, oy = x, y, self.x, self.y
	self:computeFOV(radius, "block_sense", function(x, y)
		if not checker or checker(x, y) then
			game.level.map.remembers(x, y, true)
		end
	end, true, true, true)

	self.x, self.y = ox, oy
end

--Descriptive stuff
--From Qi Daozei
function _M:getLogName()
    if self == game.player or (game.level.map.seens(self.x, self.y) and game.player:canSee(self)) then
        return self.name, true
    else
        return "something", false
    end
end

--Helper to color actors in Actor Display
function _M:TextColor()
	local factlevel = Faction:factionReaction(self.faction, game.player.faction)
	if self.faction and Faction.factions[self.faction] then
		if factlevel == 0 then return "#WHITE#"
		elseif factlevel < 0 then return "#LIGHT_RED#"
		elseif factlevel > 0 then return "#LIGHT_GREEN#"
		end
	else end
end

--Helper function to color high & low stats in birther
function _M:birthColorStats(stat)
	if self:getStat(stat) <= 6 then return "#RED#"..self:getStat(stat).."#LAST"
	elseif self:getStat(stat) > 15 then return "#GREEN#"..self:getStat(stat).."#LAST#"
	else return "#WHITE#"..self:getStat(stat).."#LAST#" end
end


--Helper function to color high stats (15+) when loading
function _M:colorHighStats(stat)
	if self:getStat(stat) > 15 then return "#GREEN#"..self:getStat(stat).."#LAST#"
	else return "#WHITE#"..self:getStat(stat).."#LAST#" end
end

--Helpers to color skills
--Incursion style
function _M:colorSkill(skill)

	if self:getSkill(skill) == 0 then return end


	if self:getSkill(skill) > 20 then return "#GOLD#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 15 then return "#LIGHT_RED#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 12 then return "#DARK_RED#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 9 then return "#LIGHT_GREEN#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 6 then return "#ORCHID#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 3 then return "#LIGHT_BLUE#"..self:getSkill(skill).."#LAST#"
	elseif self:getSkill(skill) > 1 then return "#DARK_BLUE#"..self:getSkill(skill).."#LAST#"
	else return "#WHITE#"..self:getSkill(skill).."#LAST#"
	end
end


--Tooltip stuffs
function _M:templateName()
	if self == game.player then end
	if not self.special and not self.template then return "" end


	if self.special ~= nil then
		if game.player.special_known[self.uid] then return self.special
		else return "" end

		--return self.special
	else return "" end
	if self.template ~= nil then
		if game.player.special_known[self.uid] then return self.template
		else return "" end

--		return self.template
	else return "" end
end

function _M:className()
	if self == game.player then end
	if self.classes and self.classes["Fighter"] then return "#LIGHT_BLUE#fighter#LAST#"
	elseif self.classes and self.classes["Cleric"] then return "#LIGHT_BLUE#cleric#LAST#"
	elseif self.classes and self.classes["Barbarian"] then return "#LIGHT_BLUE#barbarian#LAST#"
	elseif self.classes and self.classes["Rogue"] then return "#LIGHT_BLUE#rogue#LAST#"
	elseif self.classes and self.classes["Ranger"] then return "#LIGHT_BLUE#ranger#LAST#"
	elseif self.classes and self.classes["Wizard"] then return "#LIGHT_BLUE#wizard#LAST#"
	elseif self.classes and self.classes["Sorcerer"] then return "#LIGHT_BLUE#sorcerer#LAST#"
	elseif self.classes and self.classes["Druid"] then return "#LIGHT_BLUE#druid#LAST#"
	elseif self.classes and self.classes["Warlock"] then return "#LIGHT_BLUE#warlock#LAST#"
	else return "#LAST#" end
end

function _M:colorStats(stat)
	local player = game.player


	if (self:getStat(stat)-10)/2 > (player:getStat(stat)-10)/2 then return "#RED#"..self:getStat(stat).."#LAST#"
	elseif (self:getStat(stat)-10)/2 < (player:getStat(stat)-10)/2 then return "#GREEN#"..self:getStat(stat).."#LAST#"
	else return "#WHITE#"..self:getStat(stat).."#LAST#" end
end

function _M:formatCR()
    local cr = self:attr('challenge')
    local whole = math.floor(cr)
    local fraction = cr - whole

    if fraction == 0 then fraction = ''
    else fraction = ("1/%i"):format(math.round(1/fraction)) end

    if whole == 0 and fraction == '' then return "0"
    elseif whole == 0 then return fraction
    else return tostring(whole) .. ' ' .. fraction end
end

function _M:colorCR()
	local player = game.player

    if not self:attr("challenge") then
        return "#WHITE#-#LAST#"
    end

	if self.challenge > player.level then return "#FIREBRICK#"..self:formatCR().."#LAST#"
	elseif self.challenge < (player.level - 4) then return "#LIGHT_GREEN#"..self:formatCR().."#LAST#"
	elseif self.challenge < player.level then return "#DARK_GREEN#"..self:formatCR().."#LAST#"
	else return "#GOLD#"..self:formatCR().."#LAST#" end
end

function _M:colorFaction()
	local player = game.player
	local factlevel = Faction:factionReaction(self.faction, game.player.faction)
	if self.faction and Faction.factions[self.faction] then
		if factlevel == 0 then return "#WHITE#neutral#LAST#"
		elseif factlevel < 0 then return "#LIGHT_RED#hostile#LAST#"
		elseif factlevel > 0 then return "#LIGHT_GREEN#friendly#LAST#"
		end
	else end
end

function _M:colorPersonalReaction()
	local player = game.player
	local pfactlevel = self:reactionToward(game.player)
	if pfactlevel == 0 then return "#WHITE#neutral#LAST#"
	elseif pfactlevel < 0 then return "#LIGHT_RED#hostile#LAST#"
	elseif pfactlevel > 0 then return "#LIGHT_GREEN#friendly#LAST#"
	end
end


function _M:tooltip()
	local ts = tstring{}

	ts:add({"color", "WHITE"}, ("%s"):format(self:getDisplayString()), true)

	ts:add({"color", "GOLD"}, ("%s "):format(self:templateName()), {"color", "WHITE"}) ts:add(self.name, {"color", "WHITE"}) ts:add((" %s"):format(self:className()), true)

	if self.type == "humanoid" then ts:add(self.type.." ("..self.subtype..")", true)
	else ts:add(self.type, true)
	end

	if self.life < 0 then ts:add({"color", 255, 0, 0}, "HP: unknown", {"color", "WHITE"}, true)
	else ts:add({"color", 255, 0, 0}, ("HP: %d (%d%%)"):format(self.life, self.life * 100 / self.max_life), {"color", "WHITE"}, true)
	end

	if game.player:hasEffect(game.player.EFF_DEATHWATCH) then
		if self.wounds and self.max_wounds then
			ts:add({"color", 255, 0, 0}, ("Wounds: %d/%d"):format(self.wounds, self.max_wounds), {"color", "WHITE"}, true)
		end
	end

	if game.player:hasEffect(game.player.EFF_KNOW_ALIGNMENT) then ts:add({"color", "WHITE"}, ("%s"):format(self.alignment), true) end

	ts:add({"color", "WHITE"}, ("STR %s "):format(self:colorStats('str'))) ts:add({"color", "WHITE"}, ("DEX %s "):format(self:colorStats('dex'))) ts:add({"color", "WHITE"}, ("CON %s"):format(self:colorStats('con')), true)

	ts:add({"color", "WHITE"}, ("INT %s "):format(self:colorStats('int'))) ts:add({"color", "WHITE"}, ("WIS %s "):format(self:colorStats('wis'))) ts:add({"color", "WHITE"}, ("CHA %s"):format(self:colorStats('cha')), true)

	ts:add({"color", "GOLD"}, ("CR: %s"):format(self:colorCR()), {"color", "WHITE"}, true)

    if self:worthExp(game.player) then ts:add({"color", "GOLD"}, ("XP: %d"):format(self:worthExp(game.player)), {"color", "WHITE"}, true) end

	ts:add({"color", "WHITE"}, self.desc, {"color", "WHITE"}, true)

	ts:add(("Faction reaction: %s"):format(self:colorFaction()), true)

	ts:add(("Personal reaction: %s"):format(self:colorPersonalReaction()), true)

	--Debugging speed stuff
--	ts:add(("Game turn: %s"):format(game.turn/10), true)

--	ts:add(("Global speed: %d"):format(self.global_speed or 1), true)

	ts:add(("Energy remaining: %d"):format(self.energy.value or 1), true)

	ts:add(("Movement speed: %d"):format(self.movement_speed or 1), true)

	ts:add(("Attack speed: %d"):format(self.combat_attackspeed or 1), true)

	ts:add(("Attacks per round: %d"):format((self.movement_speed or 1)/(self.combat_attackspeed or 1)))

	return ts
end

--Detect player alignment
function _M:isPlayerGood()
	if game.player.descriptor.alignment == "Lawful Good" then return true end
	if game.player.descriptor.alignment == "Neutral Good" then return true end
	if game.player.descriptor.alignment == "Chaotic Good" then return true end
end

--Only the Good-Evil axis
function _M:isPlayerNeutral()
	if game.player.descriptor.alignment == "Lawful Neutral" then return true end
	if game.player.descriptor.alignment == "Neutral" then return true end
	if game.player.descriptor.alignment == "Chaotic Neutral" then return true end
end

function _M:isPlayerEvil()
	if game.player.descriptor.alignment == "Lawful Evil" then return true end
	if game.player.descriptor.alignment == "Neutral Evil" then return true end
	if game.player.descriptor.alignment == "Chaotic Evil" then return true end
end

function _M:isPlayerLawful()
	if game.player.descriptor.alignment == "Lawful Good" then return true end
	if game.player.descriptor.alignment == "Lawful Neutral" then return true end
	if game.player.descriptor.alignment == "Lawful Evil" then return true end
end

function _M:isPlayerChaotic()
	if game.player.descriptor.alignment == "Chaotic Good" then return true end
	if game.player.descriptor.alignment == "Chaotic Neutral" then return true end
	if game.player.descriptor.alignment == "Chaotic Evil" then return true end
end


--Detect actor alignment
function _M:isGood()
	local what
	if self ~= game.player then what = self.alignment
	else what = self.descriptor.alignment end

	if what == "Lawful Good" then return true end
	if what == "Neutral Good" then return true end
	if what == "Chaotic Good" then return true end

	return false
end

function _M:isNeutral()
	if self.alignment and self.alignment == "lawful neutral" then return true end
	if self.alignment and self.alignment == "neutral" then return true end
	if self.alignment and self.alignment == "chaotic neutral" then return true end

	return false
end

function _M:isEvil()
	local what
	if self ~= game.player then what = self.alignment
	else what = self.descriptor.alignment end

	if what == "Lawful Evil" then return true end
	if what == "Neutral Evil" then return true end
	if what == "Chaotic Evil" then return true end

	return false
end

function _M:isLawful()
	local what
	if self ~= game.player then what = self.alignment
	else what = self.descriptor.alignment end

	if what == "Lawful Good" then return true end
	if what == "Lawful Neutral" then return true end
	if what == "Lawful Evil" then return true end

	return false
end

function _M:isChaotic()
	local what
	if self ~= game.player then what = self.alignment
	else what = self.descriptor.alignment end

	if what == "Chaotic Good" then return true end
	if what == "Chaotic Neutral" then return true end
	if what == "Chaotic Evil" then return true end

	return false
end


--life regeneration (items or feats)
function _M:regenLife()
	if self.life_regen and not self:attr("no_life_regen") then
		local regen = self.life_regen

		self.life = util.bound(self.life + regen, self.die_at, self.max_life)
	end
end

--End of desc stuff
--Death & dying related stuff
function _M:deathStuff(value, src)
--Wounds system (a combination of SRD & PF)
if (self.life - (value or 0)) >= 0 then return end

--Out of life (vitality points)
if ((self.life or 0) - (value or 0) < 0) then
	local value_remaining = 0

	--only leftover value goes into wounds
	if (value or 0) > 0 then
		value_remaining = math.max((value or 0) - (self.life or 0))
	end

	--don't change vitality
	self.life = 0

	self.wounds = self.wounds - (value_remaining or 0)
--	game.logSeen("Wounds:"..self.wounds.." Hit taken:"..value_remaining)

	--we're tired
	self:setEffect(self.EFF_FATIGUE, 1, {})

	--if we're healed, remove disabled status
	if self.wounds > self.max_wounds/2 and self:hasEffect(self.EFF_DISABLED) then
		self:removeEffect(self.EFF_DISABLED)
	end

	--if below threshold, we're disabled
	if self.wounds <= self.max_wounds/2 then self:setEffect(self.EFF_DISABLED, 1, {}) end

	--wounds can't go negative
	if (self.wounds - (value_remaining or 0)) < 0 then self.wounds = 0 end

	--if out of wounds, we're dead
	if (self.wounds == 0 or (self.wounds - (value_remaining or 0)) == 0) and not self.dead then
		--remove effects
		if self:hasEffect(self.EFF_DISABLED) then self:removeEffect(self.EFF_DISABLED, true) end
		if self:hasEffect(self.EFF_FATIGUE) then self:removeEffect(self.EFF_FATIGUE, true) end
		--Remove any particles we have
		local ps = self:getParticlesList()
		for i, p in ipairs(ps) do self:removeParticles(p) end

		self:die(src)
	end
end

--Standard d20 rules follow
--[[	if (self.life - (value or 0)) > 0 then self:removeEffect(self.EFF_DISABLED) end

	if (self.life - (value or 0)) == 0 then
		--Undead and constructs now die at 0
		if self.type ~= "undead" and self.type ~= "construct" then
			self:setEffect(self.EFF_DISABLED, 1, {})
			self:removeEffect(self.EFF_DYING)
		else
			if self:hasEffect(self.EFF_DYING) then self:removeEffect(self.EFF_DYING) end
			self:die()
		end
	end


	if (self.life - (value or 0)) < 0 then
		self:removeEffect(self.EFF_DISABLED)
		self:setEffect(self.EFF_DYING, 1, {})
		--Monsters bleed out quicker than players and have a smaller chance to stabilize
		if self == game.player then
			--Raging characters are considered stable as long as they are raging
			if self:hasEffect(self.EFF_RAGE) then self.life = 0 end
			if rng.percent(10) then self.life = 0
			else self.life = self.life - 1 end
		else
			if rng.percent(2) then self.life = 0
			else self.life = self.life - 3 end
		end
	end

	--Ensure they can actually die due to bleeding out
	if not self == game.player and (self.life - (value or 0)) <= -10 and not self.dead then
		self:removeEffect(self.EFF_DYING, true, true)

		--Remove any particles we have
		local ps = self:getParticlesList()
		for i, p in ipairs(ps) do self:removeParticles(p) end

		self:die(game.player)
	end
	if self.life <= -10 and not self.dead then
		self:removeEffect(self.EFF_DYING, true, true)

		--Remove any particles we have
		local ps = self:getParticlesList()
		for i, p in ipairs(ps) do self:removeParticles(p) end

		self:die(src) end]]
end



function _M:onTakeHit(value, src, death_note)
	src = src or {}
	if value <=0 then return 0 end

	--if a sleeping target is hit, it will wake up
	if self:hasEffect(self.EFF_SLEEP) then
		self:removeEffect(self.EFF_SLEEP)
		game.logSeen(self, "%s wakes up from being hit!", self:getLogName())
	end

	--stop being fascinated
	if self:hasEffect(self.EFF_FASCINATE) then
		self:removeEffect(self.EFF_FASCINATE)
		game.logSeen(self, "%s is no longer fascinated!", self:getLogName())
	end

	-- Split ?
	if self.clone_on_hit and rng.percent(self.clone_on_hit.chance) then
		-- Find space
		local x, y = util.findFreeGrid(self.x, self.y, 1, true, {[Map.ACTOR]=true})
		if x then
			-- Find a place around to clone
			local a
			if self.clone_base then a = self.clone_base:clone() else a = self:clone() end
			a.life = math.max(1, self.life - value / 2)
			a.clone_on_hit.chance = math.ceil(self.clone_on_hit.chance / 2)
			a.energy.val = 0
			a.exp_worth = 0.1
			a.inven = {}
			a:removeAllMOs()
			a.x, a.y = nil, nil
			game.zone:addEntity(game.level, a, "actor", x, y)
			game.logSeen(self, "%s splits in two!", self.name:capitalize())
			value = value / 2
		end
	end

	if self.on_takehit then value = self:check("on_takehit", value, src, death_note) end

	--Death & dying related stuff
	self:deathStuff(value, src)

	return value
end

function _M:die(src, death_note)
	mod.class.interface.ActorLife.die(self, src, death_note)

	--Remove any particles we have
	local ps = self:getParticlesList()
	for i, p in ipairs(ps) do self:removeParticles(p) end

	-- Trigger on_die effects if any
	for eff_id, p in pairs(self.tmp) do
		local e = self.tempeffect_def[eff_id]
		if e.on_die then e.on_die(self, p) end
	end

	-- Gives the killer some exp for the kill
	local killer
	killer = src or self.last_attacker

	if killer and killer.gainExp then
		killer:gainExp(self:worthExp(killer))
	end

	-- Drop stuff
	local dropx, dropy = self.x, self.y
	if game.level.map:checkAllEntities(dropx, dropy, 'block_move') then
		-- If our grid isn't suitable, find one nearby.
		local cands = {}
		for cx = self.x - 3, self.x + 3 do
			for cy = self.y - 3, self.y + 3 do
				local d = core.fov.distance(self.x, self.y, cx, cy)
				if game.level.map:isBound(cx, cy) and d <= 3 and not game.level.map:checkAllEntities(cx, cy, 'block_move') then
				cands[#cands+1] = {cx, cy, d}
				end
			end
		end
		if #cands > 0 then
			-- Pick nearby spots with higher probability.
			-- [Does this even work, though?]
			table.sort(cands, function(a, b) return a[3] < b[3] end)
			local cand = rng.table(cands)
			dropx, dropy = cand[1], cand[2]
		end
	end

	local invens = {}
	for id, inven in pairs(self.inven) do
		invens[#invens+1] = inven
	end
	-- [Not sure why we're sorting these; I'm following T4's Actor:die()]
	local f = function(a, b) return a.id ~= 1 and (b.id == 1 or a.id < b.id) end
	table.sort(invens, f)
	for id, inven in pairs(invens) do
		for i = #inven, 1, -1 do
			local o = inven[i]
			o.dropped_by = o.dropped_by or self.name
			self:removeObject(inven, i, true)
			game.level.map:addObject(dropx, dropy, o)
		end
	end
	self.inven = {}

	--drop corpses
	if not (self.name == "stirge" or name == "will'o'wisp"
		or self.type == "outsider" or self.type == "demon" or self.type == "elemental" or self.type == "ooze" or self.type == "construct" or self.type == "undead"
		or self.type == "encounter") then

		local corpse = game.zone:makeEntity(game.level, "object", {name="fresh corpse", ego_chance=-1000}, 1, true)

		if corpse then
			corpse.name = self.name.." corpse"
			corpse.unided_name = self.name.." corpse"
			corpse.victim = self
			game.zone:addEntity(game.level, corpse, "object", dropx, dropy)
		end
	end



	if self ~= game.player and dropx == game.player.x and dropy == game.player.y then
		game.log('You feel something roll beneath your feet.')
	end

	-- Register kills for hiscores
	if killer and killer == game.player then
		if self.challenge < (game.player.level - 4) then
			killer.kills = killer.kills
		else
		killer.kills = killer.kills + 1 end
	else end

	self.dead = true -- mark as dead, for scores?

	-- Record kills for kill count
	local player = game.player

	if killer and killer == player then
		player.all_kills = player.all_kills or {}
		player.all_kills[self.name] = player.all_kills[self.name] or 0
		player.all_kills[self.name] = player.all_kills[self.name] + 1
	end

	--Divine reactions
	if killer and killer == player then

		self:deathDivineReaction()

		--live sacrifice on altar
		local t = game.level.map(self.x, self.y, Map.TERRAIN)

		if t.is_altar then
			player:liveSacrifice(self)
		end
	end

	return true
end

--self refers to the monster which was killed, see above
function _M:deathDivineReaction()
	local player = game.player

	if player:isFollowing("None") then end

	if player:isFollowing("Asherath")
		and self.challenge > player.level then
		player:incFavorFor("Asherath", 30*self.challenge)
	end

	if player:isFollowing("Ekliazeh") then
		if self.subtype == "drow" or self.subtype == "goblinoid" or self.type == "giant" then
			player:incFavorFor("Ekliazeh", 25*self.challenge)
		end
		if self.subtype == "dwarf" then --non undead; OR sapient construct
			player:transgress("Ekliazeh", 5, false, "killing a dwarf")
		end
	end

	if player:isFollowing("Hesani")
		and self.type == "undead" then
	--	and self.alignment == "lawful evil" or self.alignment == "neutral evil" or self.alignment == "chaotic evil"
			player:incFavorFor("Hesani", 25*(math.max(1, self.challenge)))
			--TODO: remove favor for killing living
	end

	if player:isFollowing("Immotian") then
		if self.type == "undead" or self.type == "aberration" or self.type == "demon" then --or self.type == "devil"
			player:incFavorFor("Immotian", 10*(math.max(1, self.challenge)))
		end
		if self.type == "dragon" or self.subtype == "fire" then --and self.alignment == "lawful good" or self.alignment == "neutral good" or self.alignment == "chaotic good"
			--5 if it used to be friendly
			player:transgress("Immotian", 2, false, "harming a sacred fire creature")
		end
	end

	if player:isFollowing("Khasrach") then
		if self.subtype == "human" or self.subtype == "elf" or self.subtype == "dwarf" then
	--	and has arcane spellcasting
			player:incFavorFor("Khasrach", 10*(math.max(1, self.challenge)))
		end
		if self.subtype == "orc" and self.challenge >= 2 then
			player:transgress("Khasrach", 1, false, "killing a skillful orc")
		end
	end

	if player:isFollowing("Kysul") then
		if self.type == "aberration" then
	--	if	self.alignment == "lawful evil" or self.alignment == "neutral evil" or self.alignment == "chaotic evil"
			player:incFavorFor("Kysul", 10*self.challenge)
		--else remove favor for killing non evil aberrations
		end
		if self.type == "outsider" then
			player:incFavorFor("Kysul", 5*self.challenge)
		end
	end

	if player:isFollowing("Mara")
		and self.type == "undead" then --and incorporeal
			player:incFavorFor("Mara", 50*self.challenge)
	end

	if player:isFollowing("Maeve")
		and self.subtype == "drow" then
			player:incFavorFor("Maeve", 50*self.challenge)
	end

	if player:isFollowing("Semirath") then
	--	TODO: deduce points for killing normally evil race and self.alignment == "lawful good" or self.alignment == "neutral good" or self.alignment == "chaotic good"
	-- TODO: deduce points for killing non-evil non-outsider non-elemental humanoid
	end

end



function _M:resolveSource()
	if self.summoner_gain_exp and self.summoner then
		return self.summoner:resolveSource()
	else
		return self
	end
end

function _M:resetToFull()
	if self.dead then return end
	self.life = self.max_life
	self.mana = self:setMaxSpellPts()
	self.max_mana = self:setMaxSpellPts()
end

function _M:gainExp(value)
	self.changed = true
	self.exp = math.max(0, self.exp + value)
	while self:getExpChart(self.level + 1) and self.exp >= self:getExpChart(self.level + 1) and (not self.actors_max_level or self.level < self.actors_max_level) do
		-- At max level, if any
		if self.actors_max_level and self.level >= self.actors_max_level then return end
		if self.max_level and self.level >= self.max_level then return end

		self.level = self.level + 1
		self.exp = self.exp - self:getExpChart(self.level)
		self:levelup()
	end

	if self == game.player then game.log("Gained "..value.." XP.") end
end


function _M:levelupMsg()
  -- Subclasses handle the actual mechanics of leveling up; here we just
  -- print the message and add the flyer.
	local stale = false
	if self.level_hiwater then
		stale = self.level_hiwater >= self.level
		self.level_hiwater = math.max(self.level_hiwater, self.level)
	end

	--Add flash for player
	if self == game.player then flash = game.flash.GOOD
	else flash = game.flash.NEUTRAL end

	game.logSeen(self, flash, "#00FFFF#%s %s level %d.#LAST#", self.name, stale and 'regains' or 'gains', self.level)
	if self.x and self.y and game.level.map.seens(self.x, self.y) then
		local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
		game.flyers:add(sx, sy, 80, 0.5, -2, 'LEVEL UP!', stale and {255, 0, 255} or {0, 255, 255})
	end

	-- Return true if this is the first time we've hit this level.
	return not stale
end

function _M:attack(target)
	self:bumpInto(target)
end

function _M:incMoney(v)
	if self.summoner then self = self.summoner end
	self.money = self.money + v
	if self.money < 0 then self.money = 0 end
	self.changed = true
end

function _M:getArmor()
	local ac = self.ac
	local dex_bonus = (self.getDex()-10)/2

	if self:hasEffect(self.EFF_BLIND) then
		ac = ac - 2
		dex_bonus = math.min(dex_bonus, 0) --negate dex bonus, if any
	end

	ac = self.ac + dex_bonus

	return ac
end

--Provided a looong time ago by someone I can't recall (Zonk?).
 function _M:isFlanking(target)
    local x = target.x*2 - self.x
    local y = target.y*2 - self.y
    local z = game.level.map (x, y, MAP.ACTOR)
    if (z and self:reactionToward(z) < 0) then --- should also check if z is 'threatening'
        return true
    else
        return false
    end
end

--Ways for actors to spot enemies
function _M:spotEnemies()
  local seen = false
  -- Check for visible monsters, only see LOS actors, so telepathy wont prevent resting
  core.fov.calc_circle(self.x, self.y, game.level.map.w, game.level.map.h, 8, function(_, x, y) return game.level.map:opaque(x, y) end, function(_, x, y)
  local actor = game.level.map(x, y, game.level.map.ACTOR)
  if actor and self:reactionToward(actor) < 0 and self:canSee(actor) and game.level.map.seens(x, y) then seen = true end
end, nil)
return seen
end

function _M:isThreatened()
	if not self.x then return nil end
	for i, act in ipairs(self.fov.actors_dist) do
        dist = core.fov.distance(self.x, self.y, act.x, act.y)
        if act ~= self and act:reactionToward(self) < 0 and not act.dead then
        	if dist <= 3 then return true
        	else return false end
    	end
    end

    return false
end

function _M:doesProvokeAoO(x, y)
--	if not self.x then return nil end
	if self.dead then return nil end

	for i, act in ipairs(self.fov.actors_dist) do
		dist = core.fov.distance(x, y, act.x, act.y)
        if act ~= self and act:reactionToward(self) < 0 and not act.dead then
			--NOTE: needs to be 2 to trigger even though it doesn't seem logical
			if dist <= 2 --TODO: or 3 and wielding a polearm
			then return true
        	else return false end
    	end
    end

    return false
end

--Helper function for caster classes
--DOESN'T WORK YET!!!
function _M:getStatForSpell(class)
    if self.classes and self.classes[class] then
        if class == "Wizard" then return self:getInt() end
        if class == "Ranger" then return self:getWis() end
        if class == "Cleric" then return self:getWis() end
        if class == "Bard" then return self:getCha() end
        if class == "Shaman" then return self:getCha() end
        if class == "Sorcerer" then return self:getCha() end
        return nil
    end
    return nil
end

function _M:getSpellDC(ab)
	local dc = 10
	if ab.level then dc = dc + ab.level end

	local stat_used = "cha" --default for monsters
	if self.classes then
		if self.classes["Wizard"] and self:spellIsKind(ab, "arcane") then stat_used = "int" end
		if self.classes["Ranger"] and self:spellIsKind(ab, "divine")then stat_used = "wis" end
		if self.classes["Cleric"] and self:spellIsKind(ab, "divine") then stat_used = "wis" end
		if self.classes["Druid"] and self:spellIsKind(ab, "divine") then stat_used = "wis" end
		if self.classes["Bard"] and self:spellIsKind(ab, "arcane") then stat_used = "cha" end
		if self.classes["Shaman"] and self:spellIsKind(ab, "divine") then stat_used = "cha" end
		if self.classes["Sorcerer"] and self:spellIsKind(ab, "arcane") then stat_used = "cha" end
	end

	dc = dc + math.floor((self:getStat(stat_used)-10)/2)

	return dc
end


--- Called before a talent is used
-- Check the actor can cast it
-- @param ab the talent (not the id, the table)
-- @return true to continue, false to stop
function _M:preUseTalent(ab, silent, fake)
	--NOTE: first things first
	if self.dead then return false end
	if not self:enoughEnergy() then return false end


	local tt_def = self:getTalentTypeFrom(ab.type[1])
	if tt_def.all_limited then --all_limited talenttypes all have talents that are daily limited

		--No casting spells if your key stat is <= 9
    --    if self:getStatForSpell("Wizard") <= 9 then
		if self.classes and self.classes["Wizard"] and self:getInt() <= 9 then
			if not silent then game.logPlayer(self, "Your Intelligence is too low!") end
		return false
		end
    --    if self:getStatForSpell("Ranger") <= 9 then
		if self.classes and self.classes["Ranger"] and self:getWis() <= 9 then
			if not silent then game.logPlayer(self, "Your Wisdom is too low!") end
		return false
		end
    --    if self:getStatForSpell("Cleric") <= 9 then
		if self.classes and self.classes["Cleric"] and self:getWis() <= 9 then
			if not silent then game.logPlayer(self, "Your Wisdom is too low!") end
		return false
		end

		if self.classes and self.classes["Bard"] and self:getCha() <= 9 then
    --    if self:getStatForSpell("Bard") <= 9 then
			if not silent then game.logPlayer(self, "Your Charisma is too low!") end
		return false
		end

		--only for Sorcerer & arcane or Shaman & divine
		if self.classes and ((self.classes["Sorcerer"] and self:spellIsKind(ab, "arcane"))
			or (self.classes["Shaman"] and self:spellIsKind(ab, "divine"))) then
			--Check for mana/psi
			if ab.mana and self:getMana() < util.getval(ab.mana, self, ab) then
				if not silent then game.logPlayer(self, "You do not have enough spell points to cast %s.", ab.name) end
				return false
			end
		else
			if self:getCharges(ab) <= 0 then
				if not silent then game.logPlayer(self, "You have to prepare this spell") end
				return false
			end
		end
	end

	-- Check for special prequisites
	if ab.on_pre_use and not ab.on_pre_use(self, ab, silent) then
		return nil
	end

	--Check for psionics
	if ab.psi and self:getPsi() < util.getval(ab.psi, self, ab) then
		if not silent then game.logPlayer(self, "You do not have enough psionic power to cast %s.", ab.name) end
		return false
	end

	if ab.mode == "sustained" then
		if ab.sustain_power and self.max_power < ab.sustain_power and not self:isTalentActive(ab.id) then
			game.logPlayer(self, "You do not have enough power to activate %s.", ab.name)
			return false
		end
	else
		if ab.power and self:getPower() < ab.power then
			game.logPlayer(self, "You do not have enough power to cast %s.", ab.name)
			return false
		end
	end

	if not silent then
	-- Allow for silent talents
		if ab.message ~= nil then
			if ab.message then
				game.logSeen(self, "%s", self:useTalentMessage(ab))
			end
		elseif ab.mode == "sustained" and not self:isTalentActive(ab.id) then
			game.logSeen(self, "%s activates %s.", self:getLogName():capitalize(), self:getTalentName(ab))
		elseif ab.mode == "sustained" and self:isTalentActive(ab.id) then
			game.logSeen(self, "%s deactivates %s.", self:getLogName():capitalize(), self:getTalentName(ab))
		else
			game.logSeen(self, "%s uses %s.", self:getLogName():capitalize(), self:getTalentName(ab))
		end
	end

	--Spell failure!
	if tt_def.all_limited and not fake then

		if self.classes and self.classes["Wizard"] and (self.spell_fail or 0) > 0 and rng.percent(self.spell_fail) then
			game.logPlayer(self, "You armor hinders your spellcasting! Your spell fails!")
			self:useEnergy()
			return false
		end
		if self.classes and self.classes["Sorcerer"] and (self.spell_fail or 0) > 0 and rng.percent(self.spell_fail) then
			game.logPlayer(self, "You armor hinders your spellcasting! Your spell fails!")
			self:useEnergy()
			return false
		end
		if self.classes and self.classes["Bard"] and (self.spell_fail or 0) > 0 and rng.percent(self.spell_fail) then
			game.logPlayer(self, "You armor hinders your spellcasting! Your spell fails!")
			self:useEnergy()
			return false
		end
	end


	return true
end

--- Called before a talent is used
-- Check if it must use a turn, mana, stamina, ...
-- @param ab the talent (not the id, the table)
-- @param ret the return of the talent action
-- @return true to continue, false to stop
function _M:postUseTalent(ab, ret)
	if not ret then return end

	local tt_def = self:getTalentTypeFrom(ab.type[1])

	--remove charge
	if tt_def.all_limited then self:incCharges(ab, -1) end

	self:useEnergy()

	--If Sorcerer/Shaman, use spell points
	if self.classes and (self.classes["Sorcerer"] or self.classes["Shaman"]) then

		if ab.mode == "sustained" then
			if not self:isTalentActive(ab.id) then
				if ab.sustain_mana then
					self.max_mana = self.max_mana - ab.sustain_mana
				end
			else
				if ab.sustain_psi then
					self.max_psi = self.max_psi + ab.sustain_psi
				end
			end
		else
			if ab.mana then
		--	self:incMana(-util.getval(ab.mana, self, ab))
			self:incMana(-util.getval(self:getSpellPoints(ab), self, ab))
			end
		end
	end

	-- Cancel stealth!
	if ab.id ~= self.T_STEALTH and ab.id ~= self.T_HIDE_IN_PLAIN_SIGHT and not util.getval(ab.no_break_stealth, self, ab) then self:breakStealth() end

	return true
end

--- Breaks stealth if active
function _M:breakStealth()
	if self:isTalentActive(self.T_STEALTH) then
--[[		local chance = 0
		if self:knowTalent(self.T_UNSEEN_ACTIONS) then
			chance = self:callTalent(self.T_UNSEEN_ACTIONS,"getChance") + (self:getLck() - 50) * 0.2
		end
		-- Do not break stealth
		if rng.percent(chance) then return end]]

		self:forceUseTalent(self.T_STEALTH, {ignore_energy=true})
		self.changed = true
	end
end


--- Return the full description of a talent
-- You may overload it to add more data (like power usage, ...)
function _M:getTalentFullDescription(t)
	local d = {}

	if t.mode == "passive" then d[#d+1] = "#6fff83#Use mode: #00FF00#Passive"
	elseif t.mode == "sustained" then d[#d+1] = "#6fff83#Use mode: #00FF00#Sustained"
	else d[#d+1] = "#6fff83#Use mode: #00FF00#Activated"
	end

	if t.power or t.sustain_power then d[#d+1] = "#6fff83#Power cost: #7fffd4#"..(t.power or t.sustain_power) end
	if self:getTalentRange(t) > 1 then d[#d+1] = "#6fff83#Range: #FFFFFF#"..self:getTalentRange(t)
	else d[#d+1] = "#6fff83#Range: #FFFFFF#melee/personal"
	end
	if t.cooldown and t.cooldown > 0 then d[#d+1] = "#6fff83#Cooldown: #FFFFFF#"..t.cooldown end

	return table.concat(d, "\n").."\n#6fff83#Description: #FFFFFF#"..t.info(self, t)
end

function _M:isSpell(t)
	local tt_def = self:getTalentTypeFrom(t.type[1])
	local tt = self:getTalentTypeFrom(t)

	if tt_def.all_limited then return true end
	if t.type[1] == "innate/innate" or t.type[1] == "shaman/shaman" or t.type == "sorcerer/sorcerer" then return true end

	return false

end

function _M:getTalentName(t)
	if not self:isSpell(t) then return t.name end
	if self:isSpell(t) then
		if self == game.player then return t.name end
		--Has at least 1 rank in spellcraft
		if game.player.skill_spellcraft > 0 then
			--If player can see the source but he isn't the source
			if self ~= game.player and (game.level.map.seens(self.x, self.y) and game.player:canReallySee(self)) then
				local check = game.player:skillCheck("spellcraft", t.level+15)
				if check then return t.name --end
				else return "something" end
			else return "something" end
		else return "something" end
	end
end

--A chart of spell points to prevent typos
local spell_points_chart = {
	[1] = 1,
	[2] = 3,
	[3] = 5,
	[4] = 7,
	[5] = 9,
	[6] = 11,
	[7] = 13,
	[8] = 15,
	[9] = 17,
}


--Spell points [Incursion/Ernir's Vancian to Psionic conversion]
function _M:getSpellPoints(t)
	if t.mana then
		return spell_points_chart[t.level]
	end
end

local spell_pts_per_level = {
	[1] = 3,
	[2] = 7,
	[3] = 13,
	[4] = 21,
	[5] = 31,
	[6] = 43,
	[7] = 57,
	[8] = 73,
	[9] = 91,
	[10] = 111,
	[11] = 133,
	[12] = 157,
	[13] = 183,
	[14] = 211,
	[15] = 241,
	[16] = 273,
	[17] = 301,
	[18] = 343,
	[19] = 381,
	[20] = 421,
}

function _M:getMaxSpellPts(level)
	return spell_pts_per_level[level]
end

function _M:setMaxSpellPts()
	if not self.classes then return 0 end
	if self.classes and self.classes["Sorcerer"] then
		return self:getMaxSpellPts(self.classes["Sorcerer"])
	end
	if self.classes and self.classes["Shaman"] then
		return self:getMaxSpellPts(self.classes["Shaman"])
	end
	return 0
end


--A chart of EXP worth to prevent typos and errors and mismatches
local exp_worth_chart = {
  [1]	= 400,
  [2]	= 600,
  [3]	= 900,
  [4]	= 1200,
  [5]	= 1500,
  [6]	= 1800,
  [7]	= 2100,
  [8]	= 2500,
  [9]	= 2700,
  [10]	= 3000,
  [11]	= 3300,
  [12]	= 3600,
  [13]	= 4000,
  [14]	= 4200,
  [15]	= 4500,
  [16]	= 4800,
  [17]	= 5000,
  [18]	= 5400,
  [19]	= 5700,
  [20]	= 6000,
}

--- How much experience is this actor worth
-- @param target to whom is the exp rewarded
-- @return the experience rewarded
function _M:worthExp(target)
	--	return (self.exp_worth) end


	local cr = self.challenge
	-- TODO Don't get experience from killing friendlies.
	if self.challenge < (game.player.level - 4) then return 0 end


	--CR below 1
	if self.challenge < 1 then
		if self.challenge == 1/2 then return 200
		elseif self.challenge == 1/3 then return 150
		elseif self.challenge == 1/4 then return 100
		elseif self.challenge == 1/6 then return 65
		elseif self.challenge == 1/8 then return 50
		elseif self.challenge == 1/10 then return 30
		else end
	end

	--Round up for 1 1/2 CR and the like

	if not exp_worth_chart[cr] then
        local new_cr = math.ceil(cr)
        return exp_worth_chart[new_cr]

    --standard
    else
	return exp_worth_chart[cr]
    end
end




--- Can the actor see the target actor
-- This does not check LOS or such, only the actual ability to see it.<br/>
-- Check for telepathy, invisibility, stealth, ...
function _M:canSeeNoCache(actor, def, def_pct)
	if not actor then return false, 0 end

	-- Newsflash: blind people can't see!
	if self:hasEffect(self.EFF_BLIND) then return false,100 end --Like this, the actor actually knows where its target is. Its just bad at hitting


	if actor ~= self and actor.attr and actor:attr("stealth") then
		local check = self:opposedCheck("spot", actor, "hide")
		if not check then
			local check2 = self:opposedCheck("listen", actor, "movesilently")
			if check2 then return false, 100 end --we know where target is thanks to hearing
			return false, 0
		end
	end

	return true, 100
end

--Taken from ToME
function _M:canSee(actor, def, def_pct)
	if not actor then return false, 0 end

	self.can_see_cache = self.can_see_cache or {}
	local s = tostring(def).."/"..tostring(def_pct)

	if self.can_see_cache[actor] and self.can_see_cache[actor][s] then return self.can_see_cache[actor][s][1], self.can_see_cache[actor][s][2] end
	self.can_see_cache[actor] = self.can_see_cache[actor] or {}
	self.can_see_cache[actor][s] = self.can_see_cache[actor][s] or {}

	local res, chance = self:canSeeNoCache(actor, def, def_pct)
	self.can_see_cache[actor][s] = {res,chance}

	-- Make sure the display updates
	if self.player and type(def) == "nil" and actor._mo then actor._mo:onSeen(res) end

	return res, chance
end

--- Reset our own seeing cache
function _M:resetCanSeeCache()
	self.can_see_cache = {}
	setmetatable(self.can_see_cache, {__mode="k"})
end

--- Reset the cache of everything else that had see us on the level
function _M:resetCanSeeCacheOf()
	if not game.level then return end
	for uid, e in pairs(game.level.entities) do
		if e.can_see_cache and e.can_see_cache[self] then e.can_see_cache[self] = nil end
	end
	game.level.map:updateMap(self.x, self.y)
end

--Taken from Qi Daozei
--- Checks if the actor can see the target actor, *including* checking for
--- LOS, lighting, etc.
function _M:canReallySee(actor)
    -- Non-players currently have no light limitations, so just use FOV.
    if not self.fov then self:doFOV() end
    return self:canSee(actor) and self.fov.actors[actor]
end

--- Is the target concealed for us?
-- Returns false if it isn't, or a number (50%/20% concealment) if it is
function _M:isConcealed(actor)
	--check for entropic shield first
	local weapon = (self:getInven("MAIN_HAND") and self:getInven("MAIN_HAND")[1])

	if actor:hasEffect(self.EFF_ENTROPIC_SHIELD) and weapon and weapon.ranged then return 20 end

	--check for blind/darkness
	if self:hasEffect(self.EFF_BLIND) then return 50 end
	if self:hasEffect(self.EFF_DARKNESS) then return 20 end
	if self:hasEffect(self.EFF_FAERIE) then return false end
	--All other effects go here since they're cancelled by faerie fire
	return false
end

--- Can the target be applied some effects
-- @param what a string describing what is being tried
function _M:canBe(what)
	if what == "poison" and self:knowTalent(self.T_POISON_IMMUNITY) then return false end
	if what == "disease" and self:knowTalent(self.T_DISEASE_IMMUNITY) then return false end
	if what == "sleep" and self:knowTalent(self.T_SLEEP_IMMUNITY) then return false end
	if what == "paralysis" and self:knowTalent(self.T_PARALYSIS_IMMUNITY) then return false end
	if what == "confusion" and self:knowTalent(self.T_CONFUSION_IMMUNITY) then return false end

	if what == "acid" and self:knowTalent(self.T_ACID_IMMUNITY) then return false end
	if what == "cold" and self:knowTalent(self.T_COLD_IMMUNITY) then return false end
	if what == "fire" and self:knowTalent(self.T_FIRE_IMMUNITY) then return false end
	if what == "electric" and self:knowTalent(self.T_ELECTRIC_IMMUNITY) then return false end
	if what == "crit" and self:knowTalent(self.T_CRIT_IMMUNITY) then return false end

	if what == "crit" and self.type == "construct" or self.type == "elemental" or self.type == "ooze" or self.type == "plant" or self.type == "undead" then return false end
	if what == "poison" and self.type == "construct" or self.type == "elemental" or self.type == "ooze" or self.type == "plant" or self.type == "undead" then return false end
	if what == "sleep" and self.type == "construct" or self.type == "dragon" or self.type == "elemental" or self.type == "ooze" or self.type == "plant" or self.type == "undead" then return false end
	if what == "paralysis" and self.type == "construct" or self.type == "dragon" or self.type == "elemental" or self.type == "ooze" or self.type == "plant" or self.type == "undead" then return false end
	if what == "stun" and self.type == "construct" or self.type == "elemental" or self.type == "ooze" or self.type == "plant" or self.type == "undead" then return false end
	if what == "disease" and self.type == "construct" or self.type == "undead" then return false end
	if what == "death" and self.type == "construct" or self.type == "undead" then return false end
	if what == "petrification" and self.subtype == "angel" or self.subtype == "archon" then return false end
	if what == "polymorph" and self.type == "ooze" or self.type == "plant" then return false end
	if what == "mind-affecting" and self.type == "construct" and self.type == "ooze" and self.type == "plant" and self.type == "undead" and self.type == "vermin" then return false end
	if what == "blind" and self.type == "ooze" then return false end
	if what == "fatigue" and self.type == "construct" or self.type == "undead" then return false end
--IMPORTANT! This one covers both ability drain, ability damage and energy drain, since those immunities always go together
	if what == "drain" and self.type == "construct" or self.type == "undead" then return false end

	if what == "acid" and self.subtype == "angel" then return false end
	if what == "cold" and self.subtype == "angel" then return false end
	if what == "electric" and self.subtype == "archon" then return false end

	if what == "fire" and self.subtype == "fire" then return false end

	return true
end

-- Tells on_set_temporary_effect() what save to use for a given effect type
--[[local save_for_effects = {
	magical = "combatSpellResist",
	mental = "combatMentalResist",
	physical = "combatPhysicalResist",
}]]

--- Adjust temporary effects (adjusted from ToME)
function _M:on_set_temporary_effect(eff_id, e, p)
	p.getName = self.tempeffect_def[eff_id].getName
	p.resolveSource = self.tempeffect_def[eff_id].resolveSource
	if p.apply_power and (save_for_effects[e.type] or p.apply_save) then
		local save = 0
		p.maximum = p.dur
		p.minimum = p.min_dur or 0 --Default minimum duration is 0. Can specify something else by putting min_dur=foo in p when calling setEffect()
		save = self[p.apply_save or save_for_effects[e.type]](self)

--[[		local percentage = 1 - ((save - p.apply_power)/20)
		local desired = p.maximum * percentage
		local fraction = desired % 1
		desired = math.floor(desired) + (rng.percent(100*fraction) and 1 or 0)
		local duration = math.min(p.maximum, desired)
		p.dur = util.bound(duration, p.minimum or 0, p.maximum)
		p.amount_decreased = p.maximum - p.dur
		local save_type = nil

		if p.apply_save then save_type = p.apply_save else save_type = save_for_effects[e.type] end
		if save_type == "combatPhysicalResist" then p.save_string = "Physical save"
		elseif save_type == "combatMentalResist" then p.save_string = "Mental save"
		elseif save_type == "combatSpellResist" then p.save_string = "Spell save"
		end]]

		p.total_dur = p.dur

		if p.dur > 0 and e.status == "detrimental" then
		--NOTE: do the saves here
	--[[		local saved = self:checkHit(save, p.apply_power, 0, 95)
			local hd = {"Actor:effectSave", saved = saved, save_type = save_type, eff_id = eff_id, e = e, p = p,}
			self:triggerHook(hd)
			self:fireTalentCheck("callbackOnEffectSave", hd)
			saved, eff_id, e, p = hd.saved, hd.eff_id, hd.e, hd.p
			if saved then
				game.logSeen(self, "#ORANGE#%s shrugs off the effect '%s'!", self.name:capitalize(), e.desc)
				return true
			end]]
		end
	end

	--NOTE: Specific stuff goes here (specific interactions)

--	self:fireTalentCheck("callbackOnTemporaryEffect", eff_id, e, p)

	if self.player and not self.tmp[eff_id] then
		p.__set_time = core.game.getTime()
	end
end

--Make it available to all actors
--- wear an object from an inventory
--	@param inven = inventory id to take object from
--	@param item = inventory slot to take from
--	@param o = object to wear
--	@param dst = actor holding object to be worn <self>
--  @param force_inven = force wear to this inventory
--  @param force_item = force wear to this inventory slot #
function _M:doWear(inven, item, o, dst, force_inven, force_item)
    self:removeObject(inven, item, true)
    local ro = self:wearObject(o, true, true, force_inven, force_item)
--	local ro = self:wearObject(o, true, true)
    if ro then
        if type(ro) == "table" then self:addObject(inven, ro, true) end
    elseif not ro then
        self:addObject(inven, o, true)
    end
    self:sortInven()
    self:useEnergy()
    self.changed = true
end


function _M:addedToLevel(level, x, y)
--Warning: got a loop once
--Safeguards against overly high CR monsters
if game.level.level == 1 then
	if self.challenge > (game.level.level + 3) then

		--Create new actor
		local m = game.zone:makeEntity(game.level, "actor", f, nil, true)

		-- Find space
        local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
        if not x then end

		if m and m:canMove(x, y) then
			game.zone:addEntity(game.level, m, "actor", x,y)
		end
		--Despawn the offender
		game.level:removeEntity(self, true)
	end
else
	if self.challenge > (game.level.level + 5) then
		--Create new actor
		local m = game.zone:makeEntity(game.level, "actor", f, nil, true)

		-- Find space
        local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
        if not x then end

		if m and m:canMove(x, y) then
			game.zone:addEntity(game.level, m, "actor", x,y)
		end
		--Despawn the offender
		game.level:removeEntity(self, true)
	end
end


if self.encounter_escort then
                for _, filter in ipairs(self.encounter_escort) do
                        for i = 1, filter.number do

                                if not filter.chance or rng.percent(filter.chance) then
                                        -- Find space
                                        local x, y = util.findFreeGrid(self.x, self.y, 10, true, {[Map.ACTOR]=true})
                                        if not x then break end

                                        -- Find an actor with that filter
                                        local m = game.zone:makeEntity(game.level, "actor", filter, nil, true)

                                        if m and m:canMove(x, y) then

                                                if filter.no_subescort then m.encounter_escort = nil end
                                                if self._empty_drops_escort then m:emptyDrops() end

                                                --Hack?
                                                if filter.challenge then
                                                		--Thanks Seb!
                                                        while m.challenge ~= filter.challenge do
                                                            m = game.zone:makeEntity(game.level, "actor", filter, nil, true)
                                                        end
                                                end
                                                game.zone:addEntity(game.level, m, "actor", x,y)
                                        end

                                --      game.zone:addEntity(game.level, m, "actor", x, y)
                                        if filter.post then filter.post(self, m) end
                                elseif m then m:removed() end
                        end
                end
        end
        self.encounter_escort = nil

self:check("on_added_to_level", level, x, y)


--Auto-remove dummy encounter npcs
if self.type == "encounter" then self:die() end
end


--Cross-class skills, Zireael
function _M:crossClass(skill)
	--List class skills for every class
	local c_barbarian = { appraise = "no", balance = "no", bluff = "no", climb = "yes", concentration = "no", craft = "yes", diplomacy = "no", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "yes", heal = "no", hide = "no", intimidate = "yes", intuition = "no", jump = "yes", knowledge = "no", listen = "yes", movesilently = "no", openlock = "no", pickpocket = "no", ride = "yes", search = "no", sensemotive = "no", spot = "no", swim = "yes", spellcraft = "no", survival = "yes", tumble = "no", usemagic = "no" }
	local c_bard = { appraise = "yes", balance = "yes", bluff = "yes", climb = "yes", concentration = "yes", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "yes", escapeartist = "yes", handleanimal = "no", heal = "no", hide = "yes", intimidate = "no", intuition = "yes", jump = "yes", knowledge = "yes", listen = "yes", movesilently = "yes", openlock = "no", pickpocket = "yes", ride = "no", search = "no", sensemotive = "yes", spot = "no", swim = "yes", spellcraft = "yes", survival = "yes", tumble = "yes", usemagic = "yes" }
	local c_cleric = { appraise = "no", balance = "no", bluff = "no", climb = "no", concentration = "yes", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "no", heal = "yes", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "no", search = "no", sensemotive = "no", spot = "no", swim = "no", spellcraft = "yes", survival = "no", tumble = "no", usemagic = "no" }
	local c_druid = { appraise = "no", balance = "no", bluff = "no", climb = "no", concentration = "yes", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "yes", heal = "yes", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "yes", movesilently = "no", openlock = "no", pickpocket = "no", ride = "yes", search = "no", sensemotive = "no", spot = "yes", swim = "yes", spellcraft = "yes", survival = "yes", tumble = "no", usemagic = "no" }
	local c_fighter = { appraise = "no", balance = "no", bluff = "no", climb = "yes", concentration = "no", craft = "yes", diplomacy = "no", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "yes", heal = "no", hide = "no", intimidate = "yes", intuition = "no", jump = "yes", knowledge = "no", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "yes", search = "no", sensemotive = "no", spot = "no", swim = "yes", spellcraft = "no", survival = "no", tumble = "no", usemagic = "no" }
	local c_monk = { appraise = "no", balance = "yes", bluff = "no", climb = "yes", concentration = "no", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "no", escapeartist = "yes", handleanimal = "no", heal = "no", hide = "yes", intimidate = "no", intuition = "yes", jump = "yes", knowledge = "yes", listen = "yes", movesilently = "yes", openlock = "no", pickpocket = "no", ride = "no", search = "no", sensemotive = "yes", spot = "yes", swim = "yes", spellcraft = "no", survival = "no", tumble = "yes", usemagic = "no" }
	local c_paladin = { appraise = "no", balance = "no", bluff = "no", climb = "no", concentration = "yes", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "yes", heal = "yes", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "yes", search = "no", sensemotive = "yes", spot = "no", swim = "no", spellcraft = "no", survival = "no", tumble = "no", usemagic = "no" }
	local c_ranger = { appraise = "no", balance = "no", bluff = "no", climb = "yes", concentration = "yes", craft = "yes", diplomacy = "no", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "yes", heal = "yes", hide = "yes", intimidate = "no", intuition = "yes", jump = "yes", knowledge = "yes", listen = "yes", movesilently = "yes", openlock = "no", pickpocket = "no", ride = "yes", search = "yes", sensemotive = "no", spot = "yes", swim = "yes", spellcraft = "no", survival = "yes", tumble = "no", usemagic = "no" }
	local c_rogue = { appraise = "yes", balance = "yes", bluff = "yes", climb = "yes", concentration = "no", craft = "yes", diplomacy = "yes", disabledevice = "yes", decipherscript = "yes", escapeartist = "yes", handleanimal = "no", heal = "no", hide = "yes", intimidate = "no", intuition = "yes", jump = "yes", knowledge = "yes", listen = "yes", movesilently = "yes", openlock = "yes", pickpocket = "yes", ride = "no", search = "yes", sensemotive = "yes", spot = "yes", swim = "no", spellcraft = "no", survival = "no", tumble = "yes", usemagic = "yes" }
	local c_sorcerer = { appraise = "no", balance = "no", bluff = "yes", climb = "no", concentration = "yes", craft = "yes", diplomacy = "yes", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "no", heal = "no", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "no", search = "no", sensemotive = "yes", spot = "no", swim = "no", spellcraft = "yes", survival = "no", tumble = "no", usemagic = "no" }
	local c_wizard = { appraise = "no", balance = "no", bluff = "no", climb = "no", concentration = "yes", craft = "yes", diplomacy = "no", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "no", heal = "no", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "no", search = "no", sensemotive = "yes", spot = "no", swim = "no", spellcraft = "yes", survival = "no", tumble = "no", usemagic = "no" }
	local c_warlock = { appraise = "no", balance = "no", bluff = "no", climb = "no", concentration = "yes", craft = "yes", diplomacy = "no", disabledevice = "no", decipherscript = "no", escapeartist = "no", handleanimal = "no", heal = "no", hide = "no", intimidate = "no", intuition = "yes", jump = "no", knowledge = "yes", listen = "no", movesilently = "no", openlock = "no", pickpocket = "no", ride = "no", search = "no", sensemotive = "yes", spot = "no", swim = "no", spellcraft = "yes", survival = "no", tumble = "no", usemagic = "no" }

	if (not skill) then return false end

	if self.last_class and self.last_class == "Barbarian" and c_barbarian[skill] == "no" then return true end
	if self.last_class and self.last_class == "Bard" and c_bard[skill] == "no" then return true end
	if self.last_class and self.last_class == "Cleric" and c_cleric[skill] == "no" then return true end
	if self.last_class and self.last_class == "Druid" and c_druid[skill] == "no" then return true end
	if self.last_class and self.last_class == "Fighter" and c_fighter[skill] == "no" then return true end
	if self.last_class and self.last_class == "Monk" and c_monk[skill] == "no" then return true end
	if self.last_class and self.last_class == "Paladin" and c_paladin[skill] == "no" then return true end
	if self.last_class and self.last_class == "Ranger" and c_ranger[skill] == "no" then return true end
	if self.last_class and self.last_class == "Rogue" and c_rogue[skill] == "no" then return true end
	if self.last_class and self.last_class == "Sorcerer" and c_sorcerer[skill] == "no" then return true end
	if self.last_class and self.last_class == "Wizard" and c_wizard[skill] == "no" then return true end
	if self.last_class and self.last_class == "Warlock" and c_warlock[skill] == "no" then return true end
	if self.last_class and self.last_class == "Shaman" and c_cleric[skill] == "no" then return true end
	if self.last_class and self.last_class == "Shadowdancer" and c_rogue[skill] == "no" then return true end
	if self.last_class and self.last_class == "Assassin" and c_rogue[skill] == "no" then return true end
	if self.last_class and self.last_class == "Loremaster" and c_wizard[skill] == "no" then return true end
	if self.last_class and self.last_class == "Archmage" and c_wizard[skill] == "no" then return true end
	if self.last_class and self.last_class == "Blackguard" and c_paladin[skill] == "no" then return true end
	if self.last_class and self.last_class == "Arcane archer" and c_ranger[skill] == "no" then return true end


	return false
end

function _M:classFeat(tid)
	local Talents = require "engine.interface.ActorTalents"

	--A hardcoded list of class feats per class
	local f_barbarian = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_SHIELD_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes", T_MARTIAL_WEAPON_PROFICIENCY = "yes" }
	local f_bard = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes" }
	local f_cleric = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_HEAVY_ARMOR_PROFICIENCY = "yes", T_SHIELD_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes"  }
	local f_druid = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes" }
	local f_fighter = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_HEAVY_ARMOR_PROFICIENCY = "yes", T_SHIELD_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes", T_MARTIAL_WEAPON_PROFICIENCY = "yes" }
	local f_monk = { T_SIMPLE_WEAPON_PROFICIENCY = "yes", T_STUNNING_FIST = "yes" }
	local f_paladin = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_HEAVY_ARMOR_PROFICIENCY = "yes", T_SHIELD_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes", T_MARTIAL_WEAPON_PROFICIENCY = "yes" }
	local f_ranger = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes", T_MARTIAL_WEAPON_PROFICIENCY = "yes" }
	local f_rogue = { T_LIGHT_ARMOR_PROFICIENCY = "yes", T_MEDIUM_ARMOR_PROFICIENCY = "yes", T_SIMPLE_WEAPON_PROFICIENCY = "yes" }


	if self.classes and self.classes["Barbarian"] and f_barbarian[tid] == "yes" then return true end
	if self.classes and self.classes["Bard"] and f_bard[tid] == "yes" then return true end
	if self.classes and self.classes["Cleric"] and f_cleric[tid] == "yes" then return true end
	if self.classes and self.classes["Druid"] and f_druid[tid] == "yes" then return true end
	if self.classes and self.classes["Fighter"] and f_fighter[tid] == "yes" then return true end
	if self.classes and self.classes["Monk"] and f_monk[tid] == "yes" then return true end
	if self.classes and self.classes["Paladin"] and f_paladin[tid] == "yes" then return true end
	if self.classes and self.classes["Ranger"] and f_ranger[tid] == "yes" then return true end
	if self.classes and self.classes["Rogue"] and f_rogue[tid] == "yes" then return true end

	return false
end

--AC, Sebsebeleb & Zireael
function _M:getAC()
	local dex_bonus = self:getDexMod()
	--Splitting it up to avoid stuff like stacking rings of protection or bracers of armor + armor
--	local base = self.combat_base_ac or 10
	local armor = self.combat_armor_ac or 0
	local shield = self.combat_shield or 0
	local natural = self.combat_natural or 0
	local magic_armor = self.combat_magic_armor or 0
	local magic_shield = self.combat_magic_shield or 0
	local dodge = self.combat_dodge or 0
	local protection = self.combat_protection or 0
	local untyped = self.combat_untyped or 0
	local parry = self.combat_parry or 0

	if self.max_dex_bonus then dex_bonus = math.min(dex_bonus, self.max_dex_bonus) end

	if self.combat_protection then protection = math.min(protection, 5) end

--	if self.combat_parry then if not proficient with the weapon, deduct 4


	--Shield Focus feat
	if self.combat_shield and self:knowTalent(self.T_SHIELD_FOCUS) then shield = shield + 2 end

	local ac_bonuses = armor + magic_armor + shield + magic_shield + natural + protection + dodge + parry


	if config.settings.veins.defensive_roll == true then
		local roll = rng.dice(1,20)
		return math.floor(roll + ac_bonuses + (dex_bonus or 0))
	else

	return math.floor(10 + ac_bonuses + (dex_bonus or 0))
	end
end

--Saving throws, Sebsebeleb & Zireael
function _M:reflexSave(dc)
	if not dc or type(dc) ~= "number" then return end

	local roll = rng.dice(1,20)
	local save = math.floor(self.level / 4) + (self:attr("reflex_save") or 0) + math.max(self:getDexMod(), self:getIntMod())

	if self == game.player then
		local s = ("Reflex save: %d roll + bonus %d = %d versus DC %d"):format(
			roll, save, roll+save, dc)--, success and "success" or "failure")
		game.log(s)
	end

	--Train stats
	if self == game.player then
		if self:getDexMod() >= self:getIntMod() then
			--if dc > 11
			local die = (dc-10)*2
			--poison, disease, traps = cap 30
			--disintegration & anything killing = die*3

			self:exerciseStat("dex", rng.dice(1,die), "dex_save", 60)
		else
			local die = (dc-10)*2
			self:exerciseStat("int", rng.dice(1, die), "int_save", 60)
		end
	end


	return roll ~= 1 and (roll == 20 or roll + save > dc)
end

function _M:fortitudeSave(dc)
	if not dc or type(dc) ~= "number" then return end

	local roll = rng.dice(1,20)
	local save = math.floor(self.level / 4) + (self:attr("fortitude_save") or 0) + math.max(self:getConMod(), self:getStrMod())

	if self == game.player then
		local s = ("Fortitude save: %d roll + %d bonus = %d versus DC %d"):format(
			roll, save, roll+save, dc)--, success and "success" or "failure")
		game.log(s)
	end

	--Train stats
	if self == game.player then
		if self:getConMod() >= self:getStrMod() then
			--if dc > 11
			local die = (dc-10)*2
			--poison, disease, traps = cap 30
			--disintegration & anything killing = die*3

			self:exerciseStat("con", rng.dice(1,die), "con_save", 60)
		else
			local die = (dc-10)*2
			self:exerciseStat("str", rng.dice(1, die), "str_save", 60)
		end
	end

	return roll ~= 1 and (roll == 20 or roll + save > dc)
end

function _M:willSave(dc)
	if not dc or type(dc) ~= "number" then return end

	local roll = rng.dice(1,20)
	local save = math.floor(self.level / 4) + (self:attr("will_save") or 0) + math.max(self:getWisMod(), self:getChaMod())

	if self == game.player then
		local s = ("Will save: %d roll + %d bonus = %d versus DC %d"):format(
			roll, save, roll+save, dc)--, success and "success" or "failure")
		game.log(s)
	end

	--Train stats
	if self == game.player then
		if self:getWisMod() >= self:getChaMod() then
			--if dc > 11
			local die = (dc-10)*2
			--poison, disease, traps = cap 30
			--disintegration & anything killing = die*3

			self:exerciseStat("wis", rng.dice(1,die), "wis_save", 60)
		else
			local die = (dc-10)*2
			self:exerciseStat("cha", rng.dice(1, die), "cha_save", 60)
		end
	end

	return roll ~= 1 and (roll == 20 or roll + save > dc)
end

function _M:saveRoll(DC, type)
	if type == "physical" then self:fortitudeSave(DC) end
	if type == "mental" then self:willSave(DC) end
end


--Metamagic stuff, Sebsebeleb
function useMetamagic(self, t)
	local metaMod = {}
	for tid, _ in pairs(self.talents) do
		local t = self:getTalentFromId(tid)
		local tt = self:getTalentTypeFrom(t)
		if tt == "arcane/metamagic" and self:isTalentActive(t.id) then
			for i,v in ipairs(t.getMod(self, t)) do
				metaMod[i] = (metaMod[i] and metaMod[i] + v) or v
			end
		end
	end
	return metaMod
end

--Spells & spellbook stuff, Sebsebeleb & DG & Zireael
--- The max charge worth you can have in a given spell level
function _M:getMaxMaxCharges(spell_list)
	local t = {}

    --Bonus spells tables
    --12-13
    local stat_bonus_one = {[1] = 1, [2] = 0, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0 }
    --14-15
    local stat_bonus_two = {[1] = 1, [2] = 1, [3] = 0, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0 }
    --16-17
    local stat_bonus_three = {[1] = 1, [2] = 1, [3] = 1, [4] = 0, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0 }
    --18-19
    local stat_bonus_four = {[1] = 1, [2] = 1, [3] = 1, [4] = 1, [5] = 0, [6] = 0, [7] = 0, [8] = 0, [9] = 0 }
    --20-21
    local stat_bonus_five = {[1] = 2, [2] = 1, [3] = 1, [4] = 1, [5] = 1, [6] = 0, [7] = 0, [8] = 0, [9] = 0 }
    --22-23
    local stat_bonus_six = {[1] = 2, [2] = 2, [3] = 1, [4] = 1, [5] = 1, [6] = 1, [7] = 0, [8] = 0, [9] = 0 }
    --24-25
    local stat_bonus_seven = {[1] = 2, [2] = 2, [3] = 2, [4] = 1, [5] = 1, [6] = 1, [7] = 1, [8] = 0, [9] = 0 }
    --26-27
    local stat_bonus_eight = {[1] = 2, [2] = 2, [3] = 2, [4] = 2, [5] = 1, [6] = 1, [7] = 1, [8] = 1, [9] = 0 }
    --28-29
    local stat_bonus_nine = {[1] = 3, [2] = 2, [3] = 2, [4] = 2, [5] = 2, [6] = 1, [7] = 1, [8] = 1, [9] = 1 }
    --30-31
    local stat_bonus_ten = {[1] = 3, [2] = 3, [3] = 2, [4] = 2, [5] = 2, [6] = 2, [7] = 1, [8] = 1, [9] = 1 }

	local l = self.level + 5
	while l > 5 do
        local spells = math.min(8, l)

		t[#t+1] = spells
        local spell_level = #t+1
		--We gain a new spell level every 3 character levels.
		l = l - 2

        --Account for bonus spells here, Zireael
        if (self.classes and self.classes["Wizard"] and self:getInt() >= 12)
        or (self.classes and self.classes["Ranger"] and self:getWis() >= 12)
        or (self.classes and self.classes["Cleric"] and self:getWis() >= 12)
        or (self.classes and self.classes["Bard"] and self:getCha() >= 12)
        then

            if (self.classes and self.classes["Wizard"] and self:getInt() < 14)
            or (self.classes and self.classes["Ranger"] and self:getWis() < 14)
            or (self.classes and self.classes["Cleric"] and self:getWis() < 14)
            or (self.classes and self.classes["Bard"] and self:getCha() < 14)
            then
                spells = spells + stat_bonus_one[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 14 and self:getInt() < 16)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 14 and self:getWis() < 16)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 14 and self:getWis() < 16)
            or (self.classes and self.classes["Bard"] and self:getCha() > 14 and self:getCha() < 16)
            then
                spells = spells + stat_bonus_two[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 16 and self:getInt() < 18)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 16 and self:getWis() < 18)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 16 and self:getWis() < 18)
            or (self.classes and self.classes["Bard"] and self:getCha() > 16 and self:getCha() < 18)
            then
                spells = spells + stat_bonus_three[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 18 and self:getInt() < 20)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 18 and self:getWis() < 20)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 18 and self:getWis() < 20)
            or (self.classes and self.classes["Bard"] and self:getCha() > 18 and self:getCha() < 20)
            then
                spells = spells + stat_bonus_four[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 20 and self:getInt() < 22)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 20 and self:getWis() < 22)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 20 and self:getWis() < 22)
            or (self.classes and self.classes["Bard"] and self:getCha() > 20 and self:getCha() < 22)
            then
                spells = spells + stat_bonus_five[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 22 and self:getInt() < 24)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 22 and self:getWis() < 24)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 22 and self:getWis() < 24)
            or (self.classes and self.classes["Bard"] and self:getCha() > 22 and self:getCha() < 24)
            then
                spells = spells + stat_bonus_six[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 24 and self:getInt() < 26)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 24 and self:getWis() < 26)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 24 and self:getWis() < 26)
            or (self.classes and self.classes["Bard"] and self:getCha() > 24 and self:getCha() < 26)
            then
                spells = spells + stat_bonus_seven[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 26 and self:getInt() < 28)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 26 and self:getWis() < 28)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 26 and self:getWis() < 28)
            or (self.classes and self.classes["Bard"] and self:getCha() > 26 and self:getCha() < 28)
            then
                spells = spells + stat_bonus_eight[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 28 and self:getInt() < 30)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 28 and self:getWis() < 30)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 28 and self:getWis() < 30)
            or (self.classes and self.classes["Bard"] and self:getCha() > 28 and self:getCha() < 30)
            then
                spells = spells + stat_bonus_nine[spell_level]
            end

            if (self.classes and self.classes["Wizard"] and self:getInt() > 30 and self:getInt() < 32)
            or (self.classes and self.classes["Ranger"] and self:getWis() > 30 and self:getWis() < 32)
            or (self.classes and self.classes["Cleric"] and self:getWis() > 30 and self:getWis() < 32)
            or (self.classes and self.classes["Bard"] and self:getCha() > 30 and self:getCha() < 32)
            then
                spells = spells + stat_bonus_ten[spell_level]
            end

        end

        --if class = cleric and spell_list = divine then set 1 additional spell (domain spell)
	end



    return t
end

function _M:getMaxCharges(tid)
	local t = self:getTalentFromId(tid)
	tid = t.id

	local cl, kind = self:casterLevel(t)
	local innatekind = "innate_casting_"..kind
	if self:attr(innatekind) then
		return self:getMaxMaxCharges()[t.level] or 0
	end
	return self.max_charges[tid] or 0
end

function _M:getCharges(tid)
	local t = self:getTalentFromId(tid)
	tid = t.id

	local cl, kind = self:casterLevel(t)
	local innatekind = "innate_casting_"..kind
	if self:attr(innatekind) then
		return self.charges[innatekind..t.level] or 0
	end
	return self.charges[tid] or 0
end

function _M:incMaxCharges(tid, v, spell_list)
	local tt
	local t
	if type(tid) == "table" then
		t = tid
		tt = tid.type[1]
		tid = tid.id
	else
		t = self:getTalentFromId(tid)
		tt = self:getTalentFromId(tid).type[1]
	end

	--Does the player have the spell slots for this level?
	if not self:getMaxMaxCharges()[t.level] then return end

    -- Disallow going below 0.
    v = math.max(-(self.max_charges[tid] or 0), v)

	--Can the player have this many max charges for this type?
	local a = self:getAllocatedCharges(spell_list, t.level)
	if a + v > self:getMaxMaxCharges()[t.level] then return end
	self.max_charges[tid] = (self.max_charges[tid] or 0) + v
	self:incAllocatedCharges(spell_list, t.level, v)
end


--- Set the number of prepared instances of a certain spell
function _M:setMaxCharges(tid, spell_list, v)

	local t
	if type(tid) == "table" then
		t = tid
		tid = tid.id
	else
		t = self:getTalentFromId(tid)
	end

	--Can the player have this many max charges for this type?
	local a = self:getAllocatedCharges(spell_list, tid.level)
	if a + v > self:getMaxMaxCharges()[tid.level] then return end
	self.max_charges[tid] = v
	self:setAllocatedCharges(spell_list, t.level, v)
end

--- Set the number of available instances of a certain spell
function _M:setCharges(tid, v)
	local t = self:getTalentFromId(tid)
	tid = t.id

	--Account for innate casting
	local cl, kind = self:casterLevel(t)
	local innatekind = "innate_casting_"..kind
	if self:attr(innatekind) then
		self.charges[innatekind..t.level] = v
	else
		self.charges[tid] = v
	end
end

--- Increase the number of available instances of a certain spell
function _M:incCharges(tid, v)
	if type(tid) == "table" then tid = tid.id end
	local new = (self:getCharges(tid) or 0) + v
	self:setCharges(tid, new)
end

function _M:getAllocatedCharges(spell_list, level)
	local c = self.allocated_charges[spell_list]
	c = c and c[level]
	return c or 0
end

function _M:setAllocatedCharges(spell_list, level, value)
	if not self.allocated_charges[spell_list] then self.allocated_charges[spell_list] = {} end
	if not self.allocated_charges[spell_list][level] then self.allocated_charges[spell_list][level] = {} end
	self.allocated_charges[spell_list][level] = value
end

function _M:incAllocatedCharges(spell_list, level, value)
	local c = self:getAllocatedCharges(spell_list, level)
	local val = c and (c + value) or value
	self:setAllocatedCharges(spell_list, level, val)
end

function _M:allocatedChargesReset()
	for k, v in pairs(self.max_charges) do
		self.max_charges[k] = 0
	end
	for k, v in pairs(self.charges) do
		self.charges[k] = 0
	end
	for k,v in pairs(self.allocated_charges) do
		for level, value in pairs(self.allocated_charges[k]) do
			self.allocated_charges[k][level] = 0
		end
	end
end

--DarkGod's useful functions
function _M:hasDescriptor(t)
	if not self.descriptor then return false end
	for k, v in pairs(t) do
		if self.descriptor[k] ~= v then return false end
	end
	return true
end

function _M:highestSpellDescriptor(what)
	local list = {}
	for tid, _ in pairs(self.talents) do
		local t = self:getTalentFromId(tid)
		if t.is_spell and t.descriptors and t.descriptors[what] and self:getCharges(t) > 0 then list[#list+1] = t end
	end
	if #list == 0 then return nil end
	table.sort(list, "level")
	return list[#list]
end

function _M:incCasterLevel(kind, v)
	self.caster_levels[kind] = self.caster_levels[kind] or 0
	self.caster_levels[kind] = self.caster_levels[kind] + v
end

function _M:casterLevel(kind)
	if type(kind) == "string" then
		if not self.caster_levels[kind] then return 0, "none" end
		return self.caster_levels[kind], kind
	else
		local t = self:getTalentFromId(kind)
		if not t.spell_kind then return 0, "none" end
		local max, kind = 0, "none"
		for k, _ in pairs(t.spell_kind) do
			max = math.max(max, (self:casterLevel(k)))
			kind = k
		end
		return max, kind
	end
end

function _M:spellIsKind(t, kind)
	if not t then return false end
	if not t.is_spell then return false end
	if not t.spell_kind[kind] then return false end
	return true
end

function _M:levelPassives()
	for tid, _ in pairs(self.talents_def) do
		local t = self:getTalentFromId(tid)
		local tt = self:getTalentTypeFrom(t.type[1])
		if self:knowTalentType(t.type[1]) then
			if tt.passive then
				if self:canLearnTalent(t) then
					self:learnTalent(tid)
					game.log("You learned "..t.name)
				end
			end
		end
	end
end

--Leveling up
function _M:levelup()
	engine.interface.ActorLevel.levelup(self)
	engine.interface.ActorTalents.resolveLevelTalents(self)

	--Player only stuff
	if self == game.player or game.party:hasMember(self) then
		--gain skill ranks
		self.max_skill_ranks = self.max_skill_ranks + 1
		--may level up class (player only)
		self.class_points = self.class_points + 1

		--feat points given every 3 levels. Classes may give additional feat points.
		if self.level % 3 == 0 then self.feat_point = (self.feat_point or 0) + 1 end

		--stat point gained every 4 levels
		if self.level % 4 == 0 then self.stat_point = (self.stat_point or 0) + 1 end

	end


	-- Auto levelup ?
	if self.autolevel then
		engine.Autolevel:autoLevel(self)
	end

	-- Heal up NPC on new level
	if self ~= game.player then self:resetToFull() end

	--NPC only stuff
	if self ~= game.player then

	end



	--Notify player on epic level
	if self.level == 20 and self == game.player then
		Dialog:simpleLongPopup("Level 20!", "You have achieved #GOLD#level 20#WHITE#, congratulations!\n\nThis means you are now an #GOLD#EPIC#LAST# hero!", 400)
	end

	--Notify on party levelups
	if self.x and self.y and game.party:hasMember(self) and not self.silent_levelup then
		local x, y = game.level.map:getTileToScreen(self.x, self.y)
		game.flyers:add(x, y, 80, 0.5, -2, "LEVEL UP!", {0,255,255})
		game.log("#00ffff#Welcome to level %d [%s].", self.level, self.name:capitalize())
		if game.player ~= self then game.log = "Select "..self.name.. " in the party list and press G to use them." end
	end

	--Level up achievements
	if self == game.player then
		if self.level == 10 then world:gainAchievement("LEVEL_10", self) end
		if self.level == 20 then world:gainAchievement("LEVEL_20", self) end
	--[[	if self.level == 30 then world:gainAchievement("LEVEL_30", self) end
		if self.level == 40 then world:gainAchievement("LEVEL_40", self) end
		if self.level == 50 then world:gainAchievement("LEVEL_50", self) end]]
	end

	if self == game.player and game then game:registerDialog(require("mod.dialogs.LevelupDialog").new(self.player)) end

end

function _M:levelClass(name)
	local birther = require "engine.Birther"
	local d = birther:getBirthDescriptor("class", name)

	if not d then end

	if not name then end

	local level = (self.classes[name] or 0) + 1
	self.classes[name] = level
	if self.class_points then
		self.class_points = self.class_points - 1
	end

	if level == 1 then --Apply the descriptor... or not?

	end

	if d.class_desc and d.class_desc.skill_point then
		local skill_point = math.max(1, d.class_desc.skill_point + self:getIntMod())
		if self.level == 1 then skill_point = skill_point * 4 end
		self:attr('skill_point', skill_point)
	end

	self.last_class = name

	d.on_level(self, level, d)
end

function _M:giveLevels(name, n)
	if not name or not n then end

	while n > 0 do
	self:levelClass(name)
	n = n-1
	end
end

--Archery functions
function _M:getShootRange()
	if self:knowTalent(self.T_FAR_SHOT) then
		return (self:getInven("MAIN_HAND")[1].combat.range)*1.5 end

	return self:getInven("MAIN_HAND")[1].combat.range
end


--Encumbrance & auto-ID stuff, Zireael
function _M:on_pickup_object(o)
--	self:checkEncumbrance()

end

function _M:onAddObject(o)
	engine.interface.ActorInventory.onAddObject(self, o)

	self:checkEncumbrance()
end

function _M:onRemoveObject(o)
	engine.interface.ActorInventory.onRemoveObject(self, o)

	self:checkEncumbrance()
end

--- Checks if the given item should respect its slot_forbid value
-- @param o the item to check
-- @param in_inven the inventory id in which the item is worn or tries to be worn
function _M:slotForbidCheck(o, in_inven_id)
	in_inven_id = self:getInven(in_inven_id).id
	if self:knowTalent(self.T_MONKEY_GRIP) and in_inven_id == self.INVEN_MAINHAND and o.slot_forbid == "OFFHAND" then
		return false
	end
	return true
end


--- Can we wear this item?
function _M:canWearObject(o, try_slot)
	local req = rawget(o, "require")

	-- Check prerequisites
	if req then
		-- Obviously this requires the ActorStats interface
		if req.stat then
			for s, v in pairs(req.stat) do
				if self:getStat(s) < v then return nil, "not enough stat" end
			end
		end
		if req.level and self.level < req.level then
			return nil, "not enough levels"
		end
		if req.talent then
			for _, tid in ipairs(req.talent) do
				if type(tid) == "table" then
					if self:getTalentLevelRaw(tid[1]) < tid[2] then return nil, "missing dependency" end
				else
					if not self:knowTalent(tid) then return nil, "missing proficiency" end
				end
			end
		end
	end

	-- Check forbidden slot
	if o.slot_forbid then
		local inven = self:getInven(o.slot_forbid)
		-- If the object cant coexist with that inventory slot and it exists and is not empty, refuse wearing
		if inven and #inven > 0 then
			return nil, "cannot use currently due to an other worn object"
		end
	end

	-- Check that we are not the forbidden slot of any other worn objects
	for id, inven in pairs(self.inven) do
		if self.inven_def[id].is_worn and (not self.inven_def[id].infos or not self.inven_def[id].infos.etheral) then
			for i, wo in ipairs(inven) do
			--	print("check other objects: ", o.name, "other object ", wo.name, "forbids", wo.slot_forbid, "our slot ", try_slot or o.slot)
				if wo.slot_forbid and wo.slot_forbid == (try_slot or o.slot) then
					print(" impossible => ", o.name, wo.name, "::", wo.slot_forbid, try_slot or o.slot)
					return nil, "cannot use currently due to an other worn object"
				end
			end
		end
	end

	-- Any custom checks
	local err = self:check("canWearObjectCustom", o, try_slot)
	if err then return nil, err end

	return true
end



function _M:getMaxEncumbrance()
	local add = 0
	local base = self:getStr()
	local bonus
	local ret
	--Muleback
	if self.muleback then bonus = 8
	else bonus = 0 end

	base = base + (bonus or 0)
	--Streamlined d20's encumbrance
	if base <= 10 then ret = math.floor(10*base)
	else ret = math.ceil((10*base) + (5*(base-10))) end

	--Ant haul
	if self.ant_haul then ret = ret*3 end

	return ret
end

function _M:getEncumbrance()
	local enc = 0

	local fct = function(so) enc = enc + so.encumber end

	-- Compute encumbrance
	for inven_id, inven in pairs(self.inven) do
		for item, o in ipairs(inven) do
				o:forAllStack(fct)
		end
	end

	return math.floor(enc)
end

function _M:checkEncumbrance()
	-- Compute encumbrance
	local enc, max = self:getEncumbrance(), self:getMaxEncumbrance()

	--Light load
	if enc < max * 0.33 then
		--remove any load effects one might have
		if self:hasEffect(self.EFF_MEDIUM_LOAD) then self:removeEffect(self.EFF_MEDIUM_LOAD, true) end
		if self:hasEffect(self.EFF_HEAVY_LOAD) then self:removeEffect(self.EFF_HEAVY_LOAD, true) end
	end


	--Heavy load
	if enc > max * 0.66 then
		--Loadbearer
		if self:knowTalent(self.T_LOADBEARER) and not self:hasEffect(self.EFF_MEDIUM_LOAD) then
			self:setEffect(self.EFF_MEDIUM_LOAD, 2, {}, true)
		end
		--Not loadbearer
		if self:knowTalent(self.T_LOADBEARER) and not self:hasEffect(self.EFF_HEAVY_LOAD) then
			--remove medium load if any
			if self:hasEffect(self.EFF_MEDIUM_LOAD) then self:removeEffect(self.EFF_MEDIUM_LOAD, true) end
			self:setEffect(self.EFF_HEAVY_LOAD, 2, {}, true)
		end
	end


	--Medium load
	if enc > max * 0.33 and not self:knowTalent(self.T_LOADBEARER) and not self:hasEffect(self.EFF_MEDIUM_LOAD) then
		--remove heavy load first
		if self:hasEffect(self.EFF_HEAVY_LOAD) then self:removeEffect(self.EFF_HEAVY_LOAD, true) end
		self:setEffect(self.EFF_MEDIUM_LOAD, 2, {}, true)

	end

	-- We are pinned to the ground if we carry too much
	if not self:hasEffect(self.EFF_ENCUMBERED) and enc > max then
		game.logPlayer(self, "#FF0000#You carry too much--you are encumbered!")
		game.logPlayer(self, "#FF0000#Drop some of your items.")
		self:setEffect(self.EFF_ENCUMBERED, 100000, {})

	if self.x and self.y then
		local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
		game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, rng.float(-2.5, -1.5), "+ENCUMBERED!", {255,0,0}, true)
	end
	elseif self:hasEffect(self.EFF_ENCUMBERED) and enc <= max then
		game.logPlayer(self, "#00FF00#You are no longer encumbered.")
		self:removeEffect(self.EFF_ENCUMBERED)

		if self.x and self.y then
			local sx, sy = game.level.map:getTileToScreen(self.x, self.y)
			game.flyers:add(sx, sy, 30, (rng.range(0,2)-1) * 0.5, rng.float(-2.5, -1.5), "-ENCUMBERED!", {255,0,0}, true)
		end
	end
end

function _M:reactionToward(target)
	local rsrc, rtarget = self, target
	while rsrc.summoner do rsrc = rsrc.summoner end
	while rtarget.summoner do rtarget = rtarget.summoner end

    local v = engine.Actor.reactionToward(self, target)

	--NOTE:actually use the personal reaction
	if rsrc.reaction_actor and rsrc.reaction_actor[rtarget.unique or rtarget.name] then v = v + rsrc.reaction_actor[rtarget.unique or rtarget.name] end

    if self:hasEffect(self.EFF_CHARM) then v = math.max(v, 100) end

    return v
end

--is there a quicker way to do it?
--From most dangerous to weakest
function _M:isPoisoned()
	if self:hasEffect(self.EFF_POISON_EXTRASTRONG_CON) then return EFF_POISON_EXTRASTRONG_CON end
	if self:hasEffect(self.EFF_POISON_DRAGON_BILE) then return EFF_POISON_DRAGON_BILE end
	if self:hasEffect(self.EFF_POISON_STRONG_CON) then return EFF_POISON_STRONG_CON end
	if self:hasEffect(self.EFF_POISON_STRONG_STR) then return EFF_POISON_STRONG_STR end
	if self:hasEffect(self.EFF_POISON_ARSENIC_SEC) then return EFF_POISON_ARSENIC_SEC end
	if self:hasEffect(self.EFF_POISON_MEDIUM_STR) then return EFF_POISON_MEDIUM_STR end
	if self:hasEffect(self.EFF_POISON_MALYSS_PRI) then return EFF_POISON_MALYSS_PRI end
	if self:hasEffect(self.EFF_POISON_MEDIUM_DEX) then return EFF_POISON_MEDIUM_DEX end
	if self:hasEffect(self.EFF_POISON_TERINAV_SEC) then return EFF_POISON_TERINAV_SEC end

	if self:hasEffect(self.EFF_POISON_MALYSS_SEC) then return EFF_POISON_MALYSS_SEC end
	if self:hasEffect(self.EFF_POISON_MOSS_SEC) then return EFF_POISON_MOSS_SEC end
	if self:hasEffect(self.EFF_POISON_DARK_REAVER_SEC) then return EFF_POISON_DARK_REAVER_SEC end
	if self:hasEffect(self.EFF_POISON_INSANITY_MIST_SEC) then return EFF_POISON_INSANITY_MIST_SEC end

	if self:hasEffect(self.EFF_POISON_MEDIUM_CON) then return EFF_POISON_MEDIUM_CON end
	if self:hasEffect(self.EFF_POISON_BLOODROOT_SEC) then return EFF_POISON_BLOODROOT_SEC end
	if self:hasEffect(self.EFF_POISON_WEAK_CON) then return EFF_POISON_WEAK_CON end
	if self:hasEffect(self.EFF_POISON_GREENBLOOD_SEC) then return EFF_POISON_GREENBLOOD_SEC end
	if self:hasEffect(self.EFF_POISON_UNGOL_DUST_SEC) then return EFF_POISON_UNGOL_DUST_SEC end
	if self:hasEffect(self.EFF_POISON_INSANITY_MIST_PRI) then return EFF_POISON_INSANITY_MIST_PRI end
	if self:hasEffect(self.EFF_POISON_MIDDLING_INT) then return EFF_POISON_MIDDLING_INT end
	if self:hasEffect(self.EFF_POISON_MIDDLING_STR) then return EFF_POISON_MIDDLING_STR end
	if self:hasEffect(self.EFF_POISON_UNGOL_DUST_PRI) then return EFF_POISON_UNGOL_DUST_PRI end
	if self:hasEffect(self.EFF_POISON_SHADOW_ESSENCE_PRI) then return EFF_POISON_SHADOW_ESSENCE_PRI end
	if self:hasEffect(self.EFF_POISON_SMALL_CENTIPEDE) then return EFF_POISON_SMALL_CENTIPEDE end
	if self:hasEffect(self.EFF_POISON_TOADSTOOL_SEC) then return EFF_POISON_TOADSTOOL_SEC end
	if self:hasEffect(self.EFF_POISON_TOADSTOOL_PRI) then return EFF_POISON_TOADSTOOL_PRI end

	return nil
end


--Random feats & immunities code
function _M:randomFeat()
	local chance = rng.dice(1,29)

	if chance == 1 then self:learnTalent(self.T_DODGE, true)
	elseif chance == 2 then self:learnTalent(self.T_FINESSE, true)
	elseif chance == 3 then self:learnTalent(self.T_TOUGHNESS, true)
	elseif chance == 4 then self:learnTalent(self.T_ACROBATIC, true)
	elseif chance == 5 then self:learnTalent(self.T_AGILE, true)
	elseif chance == 6 then self:learnTalent(self.T_ALERTNESS, true)
	elseif chance == 7 then self:learnTalent(self.T_ANIMAL_AFFINITY, true)
	elseif chance == 8 then self:learnTalent(self.T_ARTIST, true)
	elseif chance == 9 then self:learnTalent(self.T_ATHLETIC, true)
	elseif chance == 10 then self:learnTalent(self.T_COMBAT_CASTING, true)
	elseif chance == 11 then self:learnTalent(self.T_DEFT_HANDS, true)
	elseif chance == 12 then self:learnTalent(self.T_INVESTIGATOR, true)
	elseif chance == 13 then self:learnTalent(self.T_MAGICAL_APTITUDE, true)
	elseif chance == 14 then self:learnTalent(self.T_MAGICAL_TALENT, true)
	elseif chance == 15 then self:learnTalent(self.T_NEGOTIATOR, true)
	elseif chance == 16 then self:learnTalent(self.T_NIMBLE_FINGERS, true)
	elseif chance == 17 then self:learnTalent(self.T_PERSUASIVE, true)
	elseif chance == 18 then self:learnTalent(self.T_SILVER_PALM, true)
	elseif chance == 19 then self:learnTalent(self.T_STEALTHY, true)
	elseif chance == 20 then self:learnTalent(self.T_THUG, true)
	elseif chance == 21 then self:learnTalent(self.T_TWO_WEAPON_FIGHTING, true)
	elseif chance == 22 then self:randomFocus()
	elseif chance == 23 then self:randomFocus()
	elseif chance == 24 then self:randomFavEnemy()
	elseif chance == 25 then self:randomFavEnemy()
	elseif chance == 26 then self:randomImmunity()
	elseif chance == 27 then self:randomImmunity()
	elseif chance == 28 then self:randomImmunity()
		--[[Commented out due to the problems with on_pre_use
		if chance == 1 then self:learnTalent(self.T_POWER_ATTACK, true)]]

	else self:learnTalent(self.T_IRON_WILL, true)
	--	self.perk = "Iron Will"
	end

end

function _M:randomFocus()
	local chance = rng.dice(1,24)

	if chance == 1 then self:learnTalent(self.T_WEAPON_FOCUS_AXE, true)
	elseif chance == 2 then self:learnTalent(self.T_WEAPON_FOCUS_BATTLEAXE, true)
	elseif chance == 3 then self:learnTalent(self.T_WEAPON_FOCUS_BOW, true)
	elseif chance == 4 then self:learnTalent(self.T_WEAPON_FOCUS_CLUB, true)
	elseif chance == 5 then self:learnTalent(self.T_WEAPON_FOCUS_CROSSBOW, true)
	elseif chance == 6 then self:learnTalent(self.T_WEAPON_FOCUS_DAGGER, true)
	elseif chance == 7 then self:learnTalent(self.T_WEAPON_FOCUS_FALCHION, true)
	elseif chance == 8 then self:learnTalent(self.T_WEAPON_FOCUS_FLAIL, true)
	elseif chance == 9 then self:learnTalent(self.T_WEAPON_FOCUS_HALBERD, true)
	elseif chance == 10 then self:learnTalent(self.T_WEAPON_FOCUS_HAMMER, true)
	elseif chance == 11 then self:learnTalent(self.T_WEAPON_FOCUS_HANDAXE, true)
	elseif chance == 12 then self:learnTalent(self.T_WEAPON_FOCUS_JAVELIN, true)
	elseif chance == 13 then self:learnTalent(self.T_WEAPON_FOCUS_KUKRI, true)
	elseif chance == 14 then self:learnTalent(self.T_WEAPON_FOCUS_MACE, true)
	elseif chance == 15 then self:learnTalent(self.T_WEAPON_FOCUS_MORNINGSTAR, true)
	elseif chance == 16 then self:learnTalent(self.T_WEAPON_FOCUS_RAPIER, true)
	elseif chance == 17 then self:learnTalent(self.T_WEAPON_FOCUS_SCIMITAR, true)
	elseif chance == 18 then self:learnTalent(self.T_WEAPON_FOCUS_SCYTHE, true)
	elseif chance == 19 then self:learnTalent(self.T_WEAPON_FOCUS_SHORTSWORD, true)
	elseif chance == 20 then self:learnTalent(self.T_WEAPON_FOCUS_SPEAR, true)
	elseif chance == 21 then self:learnTalent(self.T_WEAPON_FOCUS_SLING, true)
	elseif chance == 22 then self:learnTalent(self.T_WEAPON_FOCUS_STAFF, true)
	elseif chance == 23 then self:learnTalent(self.T_WEAPON_FOCUS_SWORD, true)

	else self:learnTalent(self.T_WEAPON_FOCUS_TRIDENT, true)	end

end

function _M:randomFavEnemy()
	local chance = rng.dice(1,30)

	if chance == 1 then self:learnTalent(self.T_FAVORED_ENEMY_ABERRATION, true)
	elseif chance == 2 then self:learnTalent(self.T_FAVORED_ENEMY_ANIMAL, true)
	elseif chance == 3 then self:learnTalent(self.T_FAVORED_ENEMY_CONSTRUCT, true)
	elseif chance == 4 then self:learnTalent(self.T_FAVORED_ENEMY_DRAGON, true)
	elseif chance == 5 then self:learnTalent(self.T_FAVORED_ENEMY_ELEMENTAL, true)
	elseif chance == 6 then self:learnTalent(self.T_FAVORED_ENEMY_FEY, true)
	elseif chance == 7 then self:learnTalent(self.T_FAVORED_ENEMY_GIANT, true)
	elseif chance == 8 then self:learnTalent(self.T_FAVORED_ENEMY_MAGBEAST, true)
	elseif chance == 9 then self:learnTalent(self.T_FAVORED_ENEMY_MONSTROUS_HUMANOID, true)
	elseif chance == 10 then self:learnTalent(self.T_FAVORED_ENEMY_OOZE, true)
	elseif chance == 11 then self:learnTalent(self.T_FAVORED_ENEMY_PLANT, true)
	elseif chance == 12 then self:learnTalent(self.T_FAVORED_ENEMY_UNDEAD, true)
	elseif chance == 13 then self:learnTalent(self.T_FAVORED_ENEMY_VERMIN, true)
	elseif chance == 14 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_DWARF, true)
	elseif chance == 15 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_GNOME, true)
	elseif chance == 16 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_DROW, true)
	elseif chance == 17 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_ELF, true)
	elseif chance == 18 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_HUMAN, true)
	elseif chance == 19 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_HALFLING, true)
	elseif chance == 20 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_PLANETOUCHED, true)
	elseif chance == 21 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_AQUATIC, true)
	elseif chance == 22 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_GOBLINOID, true)
	elseif chance == 23 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_REPTILIAN, true)
	elseif chance == 24 then self:learnTalent(self.T_FAVORED_ENEMY_HUMANOID_ORC, true)
	elseif chance == 25 then self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_AIR, true)
	elseif chance == 26 then self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_EARTH, true)
	elseif chance == 27 then self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_EVIL, true)
	elseif chance == 28 then self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_FIRE, true)
	elseif chance == 29 then self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_GOOD, true)

	else self:learnTalent(self.T_FAVORED_ENEMY_OUTSIDER_WATER, true) 	end

end

function _M:randomImmunity()
	local chance = rng.dice(1,10)
	if chance == 1 then self:learnTalent(self.T_POISON_IMMUNITY, true)
	elseif chance == 2 then self:learnTalent(self.T_DISEASE_IMMUNITY, true)
	elseif chance == 3 then self:learnTalent(self.T_SLEEP_IMMUNITY, true)
	elseif chance == 4 then self:learnTalent(self.T_PARALYSIS_IMMUNITY, true)
	elseif chance == 5 then self:learnTalent(self.T_FIRE_RESISTANCE, true)
	elseif chance == 6 then	self:learnTalent(self.T_ACID_RESISTANCE, true)
	elseif chance == 7 then self:learnTalent(self.T_COLD_RESISTANCE, true)
	elseif chance == 8 then self:learnTalent(self.T_ELECTRICITY_RESISTANCE, true)
	elseif chance == 9 then self:learnTalent(self.T_SONIC_RESISTANCE, true)
	else self:learnTalent(self.T_CONFUSION_IMMUNITY, true)
	end
end

function _M:randomSpell()
	local chance = rng.dice(1,4)
	if chance == 1 then self:learnTalent(self.T_ACID_SPLASH_INNATE, true)
	elseif chance == 2 then self:learnTalent(self.T_GREASE_INNATE, true)
	elseif chance == 3 then self:learnTalent(self.T_HLW_INNATE, true)
	else self:learnTalent(self.T_CLW_INNATE, true)
	end
end

--Name stuff
function _M:randomName(race, sex, surname)
local NameGenerator = require "mod.class.NameGenerator"

local name

	if not race then print("[NAMEGEN] You can't generate name without race!") return end
	if not sex then print("[NAMEGEN] You can't generate name without sex!") return end

	print("[NAMEGEN] Generating name for ", race, sex)

	if race == "Human" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.human_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.human_male_def)
			name = namegen:generate() end
	elseif race == "Half-elf" or race == "Half-drow" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.halfelf_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.halfelf_male_def)
			name = namegen:generate() end
	elseif race == "Elf" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.elf_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.elf_male_def)
			name = namegen:generate() end
	elseif race == "Half-orc" or race == "Orc" or race == "Lizardfolk" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.halforc_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.halforc_male_def)
			name = namegen:generate() end
	elseif race == "Dwarf" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.dwarf_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.dwarf_male_def)
			name = namegen:generate() end
	elseif race == "Drow" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.drow_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.drow_male_def)
			name = namegen:generate() end
	elseif race == "Duergar" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.duergar_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.duergar_male_def)
			name = namegen:generate() end
	elseif race == "Deep gnome" or race == "Gnome" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.gnome_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.gnome_male_def)
			name = namegen:generate() end
	elseif race == "Halfling" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.halfling_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.halfling_male_def)
			name = namegen:generate() end
	elseif race == "Kobold" then
		if sex == "Female" then
			local namegen = NameGenerator.new(NameGenerator.kobold_female_def)
			name = namegen:generate()
		else
			local namegen = NameGenerator.new(NameGenerator.kobold_male_def)
			name = namegen:generate() end
	end

	if name == nil then print("[NAMEGEN] Name generation failed") end

	return name

end

--Portrait generator
function _M:portraitGen()
	local path = "/data/gfx/portraits/"
	local doll = path.."base.png"

	if self.show_portrait == true then

		if self.subtype == "drow" then
			doll = path.."base_drow.png"
		end

		self.portrait = doll

		--Now the rest of the face
		local eyes_light = {"amber", "seablue", "seagreen", "yellow"}
		local eyes_medium = {"green", "blue", "gray"}
		local eyes_dark = {"black", "brown"}
		local eyes_red = {"red", "pink"}

		local eyes_dwarf = {}
		local eyes_human = {}
		local eyes_all = {}

		local mouth = {"mouth", "mouth2"}

		local add = {}
		if self.subtype == "drow" then
			add[#add+1] = {image=path.."eyebrows_drow.png"}
		else
			add[#add+1] = {image=path.."eyebrows.png"}
		end

		if self.subtype == "dwarf" then
			table.append(eyes_dwarf, eyes_medium)
			table.append(eyes_dwarf, eyes_dark)
			add[#add+1] = {image=path.."eyes_"..rng.table(eyes_dwarf)..".png" }
		elseif self.subtype == "human" then
			table.append(eyes_human, eyes_light)
			table.append(eyes_all, eyes_medium)
			table.append(eyes_human, eyes_dark)
			add[#add+1] = {image=path.."eyes_"..rng.table(eyes_human)..".png" }
		else
			table.append(eyes_all, eyes_light)
			table.append(eyes_all, eyes_medium)
			table.append(eyes_all, eyes_dark)
			table.append(eyes_all, eyes_red)
			add[#add+1] = {image=path.."eyes_"..rng.table(eyes_all)..".png" }
		end

	--	add[#add+1] = {image=path.."nose.png"}

		add[#add+1] = {image=path..rng.table(mouth)..".png"}

		--Decor
		if self.subtype == "dwarf" then
			add[#add+1] = {image=path.."beard.png"}
		end

		if self.name:find("noble") then
			add[#add+1] = {image=path.."necklace.png"}
		end

		if self.name:find("commoner") or self.name:find("courtesan") then
			add[#add+1] = {image=path.."hood_base.png"}
		end


		self.portrait_table = add
	end
end

--- Setup minimap color for this entity
-- You may overload this method to customize your minimap
function _M:setupMinimapInfo(mo, map)
	if map.actor_player and not map.actor_player:canSee(self) then return end
	local r = map.actor_player and map.actor_player:reactionToward(self) or -100
	if r < 0 then mo:minimap(240, 0, 0)
	elseif r > 0 then mo:minimap(0, 240, 0)
	else mo:minimap(0, 0, 240)
	end
end


--Add healthbars
function _M:defineDisplayCallback()
	if not self._mo then return end

	local backps = self:getParticlesList(true)
	local ps = self:getParticlesList()

	local function tactical(x, y, w, h, zoom, on_map, tlx, tly)
		-- Healthbars code (taken from Hulk)
		if game.level and game.always_target then
			-- Tactical life info
			if on_map then
				local dh = h * 0.1
				local lp = math.max(0, self.life) / self.max_life + 0.0001
				if lp > .75 then -- green
					core.display.drawQuad(x + 3, y + h - dh, w - 6, dh, 129, 180, 57, 128)
					core.display.drawQuad(x + 3, y + h - dh, (w - 6) * lp, dh, 50, 220, 77, 255)
				elseif lp > .5 then -- yellow
					core.display.drawQuad(x + 3, y + h - dh, w - 6, dh, 175, 175, 10, 128)
					core.display.drawQuad(x + 3, y + h - dh, (w - 6) * lp, dh, 240, 252, 35, 255)
				elseif lp > .25 then -- orange
					core.display.drawQuad(x + 3, y + h - dh, w - 6, dh, 185, 88, 0, 128)
					core.display.drawQuad(x + 3, y + h - dh, (w - 6) * lp, dh, 255, 156, 21, 255)
				else -- red
					core.display.drawQuad(x + 3, y + h - dh, w - 6, dh, 167, 55, 39, 128)
					core.display.drawQuad(x + 3, y + h - dh, (w - 6) * lp, dh, 235, 0, 0, 255)
				end
			end
		end

		-- Tactical info (taken from T-Engine)
		if game.level and game.level.map.view_faction then
			local map = game.level.map
			if on_map then
				if not f_self then
					f_self = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_self)
					f_powerful = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_powerful)
					f_danger2 = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_danger2)
					f_danger1 = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_danger1)
					f_friend = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_friend)
					f_enemy = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_enemy)
					f_neutral = game.level.map.tilesTactic:get(nil, 0,0,0, 0,0,0, map.faction_neutral)
				end


				if self.faction then
					local friend = -100
					if not map.actor_player then friend = Faction:factionReaction(map.view_faction, self.faction)
					else friend = map.actor_player:reactionToward(self) end

					if self == map.actor_player then
						f_self:toScreen(x, y, w, h)
					elseif map:faction_danger_check(self) then
						if friend >= 0 then f_powerful:toScreen(x, y, w, h)
						else
							if map:faction_danger_check(self, true) then
								f_danger2:toScreen(x, y, w, h)
							else
								f_danger1:toScreen(x, y, w, h)
							end
						end
					elseif friend > 0 then
						f_friend:toScreen(x, y, w, h)
					elseif friend < 0 then
						f_enemy:toScreen(x, y, w, h)
					else
						f_neutral:toScreen(x, y, w, h)
					end
				end
			end
		end
	end

	local function particles(x, y, w, h, zoom, on_map)
		local e
		local dy = 0
		if h > w then dy = (h - w) / 2 end
		for i = 1, #ps do
			e = ps[i]
			e:checkDisplay()
			if e.ps:isAlive() then e.ps:toScreen(x + w / 2, y + dy + h / 2, true, w / (game.level and game.level.map.tile_w or w))
			else self:removeParticles(e)
			end
		end
	end

	local function backparticles(x, y, w, h, zoom, on_map)
		local e
		local dy = 0
		if h > w then dy = (h - w) / 2 end
		for i = 1, #backps do
			e = backps[i]
			e:checkDisplay()
			if e.ps:isAlive() then e.ps:toScreen(x + w / 2, y + dy + h / 2, true, w / (game.level and game.level.map.tile_w or w))
			else self:removeParticles(e)
			end
		end
	end

	if self._mo == self._last_mo or not self._last_mo then
		self._mo:displayCallback(function(x, y, w, h, zoom, on_map, tlx, tly)
			tactical(tlx or x, tly or y, w, h, zoom, on_map)
			backparticles(x, y, w, h, zoom, on_map)
			particles(x, y, w, h, zoom, on_map)
			return true
		end)
	else
		self._mo:displayCallback(function(x, y, w, h, zoom, on_map, tlx, tly)
			tactical(tlx or x, tly or y, w, h, zoom, on_map)
			backparticles(x, y, w, h, zoom, on_map)
			return true
		end)
		self._last_mo:displayCallback(function(x, y, w, h, zoom, on_map)
			particles(x, y, w, h, zoom, on_map)
			return true
		end)
	end
end

require 'mod.class.patch.ActorTalentDialog'
