-- Veins of the Earth
-- Zireael 2014-2015
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

--Neutrals
load("/data/general/npcs/neutral.lua", rarity(3))

load("/data/general/npcs/townies_drow.lua", rarity(0))

--TODO: Neutral vermin, animals, elementals, fiends

newEntity{
    base = "BASE_NPC_DROW_T",
    name = "drow innkeeper",
    rarity = 2,
    resolvers.equipnoncursed{
        full_id=true,
        { name = "chain shirt" },
        { name = "long sword",  },
    },
    can_talk = "innkeeper",
}
