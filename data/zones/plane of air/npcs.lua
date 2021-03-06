-- Veins of the Earth
-- Zireael 2015
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

--Encounters are dummy npcs
--load("/data/general/npcs/encounters/encounters_generic.lua")
--load("/data/general/npcs/encounters/encounters_specific.lua")

load("/data/general/npcs/elementals.lua", function(e) if e.rarity and e.name and e.name:find("earth") then e.rarity=nil end end, rarity(5))

load("/data/general/npcs/outsider_evil.lua", rarity(10))
load("/data/general/npcs/outsider_good.lua", rarity(15))

load("/data/general/npcs/outsider_air.lua", rarity(0))
load("/data/general/npcs/outsider_fire.lua", rarity(2))
