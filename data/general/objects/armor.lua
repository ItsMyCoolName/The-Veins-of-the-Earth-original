--Veins of the Earth 2013-2016
--Zireael

local Talents = require "engine.interface.ActorTalents"

newEntity{
    define_as = "BASE_OUTFIT",
    slot = "BODY",
    type = "armor",
    material = "leather",
}

newEntity{
    define_as = "BASE_ARMOR",
    slot = "BODY",
    type = "armor",
    addons = "/data/general/objects/properties/bonus_armor.lua",
    egos = "/data/general/objects/properties/armor.lua",
    durability = resolvers.armor_durability(),
    egos_chance = resolvers.ego_chance(), -- egos_chance = { prefix=30, suffix=70},
}

--Armors
newEntity{ base = "BASE_ARMOR",
    define_as = "BASE_LIGHT_ARMOR",
    slot = "BODY",
    type = "armor", subtype="light",
    moddable_tile = resolvers.moddable_tile("leather"),
    display = "(", color=colors.SLATE,
    require = { talent = { Talents.T_LIGHT_ARMOR_PROFICIENCY }, },
    encumber = 10,
    material = "leather",
    name = "light armor",
    desc = "A simple padded armor. Does not offer much protection.\n\n Light armor.",
--    egos = "/data/general/objects/properties/armor.lua", egos_chance = { prefix=30, suffix=70},
    }

newEntity{ base = "BASE_LIGHT_ARMOR",
    name = "cord armor", short_name = "cord",
    image = "tiles/object/armor_cord.png",
    level_range = {1, 10},
    cost = 5,
    rarity = 15,
    desc = "Simple cord twined around your body. Offers little protection.\n\n Light armor.",
    wielder = {
        combat_armor = 1,
        max_dex_bonus = 7,
        spell_fail = 5
    },
}


newEntity{ base = "BASE_LIGHT_ARMOR",
    name = "padded armor", short_name = "padded",
    image = "tiles/object/armor_padded.png",
    level_range = {1, 10},
    rarity = 8,
--    cost = 5,
    cost = resolvers.value{platinum=1},
    wielder = {
		combat_armor = 1,
		max_dex_bonus = 8,
		spell_fail = 5
	},
}


newEntity{ base = "BASE_LIGHT_ARMOR",
    name = "leather armor", short_name = "leather",
    image = "tiles/object/armor_leather.png",
    level_range = {1, 10},
    rarity = 5,
--    cost = 10,
    cost = resolvers.value{silver=150},
    desc = "A set of leather armor.\n\n Light armor.",
    wielder = {
		combat_armor = 2,
		max_dex_bonus = 6,
		spell_fail = 10
	},
}

newEntity{ base = "BASE_LIGHT_ARMOR",
    name = "studded leather", short_name = "studded",
    image = "tiles/object/armor_studded.png",
    level_range = {1, 10},
    rarity = 10,
--    cost = 25,
    cost = resolvers.value{silver=525},
    wielder = {
		combat_armor = 3,
		max_dex_bonus = 5,
		spell_fail = 15,
		armor_penalty = 1
	},
}


newEntity{ base = "BASE_LIGHT_ARMOR",
    name = "chain shirt", short_name = "chain",
    moddable_tile = resolvers.moddable_tile("mail"),
    image = "tiles/object/chain_shirt.png",
    level_range = {1, 10},
    rarity = 15,
--    cost = 100,
    cost = resolvers.value{silver=1250},
    desc = "A set of chain links which covers the torso only.\n\n Light armor.",
    wielder = {
		combat_armor = 4,
		max_dex_bonus = 4,
		spell_fail = 20,
		armor_penalty = 2
	},
    material = "steel",
}

newEntity{ base = "BASE_ARMOR",
    define_as = "BASE_MEDIUM_ARMOR",
    slot = "BODY",
    type = "armor", subtype="medium",
    display = "]", color=colors.SLATE,
    require = { talent = { Talents.T_MEDIUM_ARMOR_PROFICIENCY }, },
    moddable_tile = resolvers.moddable_tile("mail"),
    encumber = 40,
    name = "medium armor",
    material = "steel",
    desc = "A suit of armour made of mail.\n\n Medium armor.",
--    egos = "/data/general/objects/properties/armor.lua", egos_chance = { prefix=30, suffix=70},
}

newEntity{ base = "BASE_MEDIUM_ARMOR",
    name = "chain mail", short_name = "mail",
    image = "tiles/object/chain_armor.png",
    level_range = {1, 10},
    rarity = 12,
--    cost = 150,
    cost = resolvers.value{platinum=2},
    wielder = {
		combat_armor = 5,
		max_dex_bonus = 2,
		spell_fail = 30,
		armor_penalty = 5
	},
}

newEntity{ base = "BASE_MEDIUM_ARMOR",
    name = "scale mail", short_name = "scale",
    image = "tiles/object/scale_armor.png",
    level_range = {1, 10},
    rarity = 14,
--    cost = 50,
    cost = resolvers.value{silver=1700},
    desc = "A suit of armour made of scale.\n\n Medium armor.",
    wielder = {
		combat_armor = 4,
		max_dex_bonus = 3,
		spell_fail = 25,
		armor_penalty = 4
	},
}

newEntity{ base = "BASE_MEDIUM_ARMOR",
    name = "breastplate", short_name = "bplate",
    image = "tiles/object/breastplate.png",
    level_range = {1, 10},
    rarity = 18,
--    cost = 200,
    cost = resolvers.value{silver=4500},
    desc = "This armor only covers the torso.\n\n Medium armor.",
    wielder = {
		combat_armor = 5,
		max_dex_bonus = 3,
		spell_fail = 25,
		armor_penalty = 4
	},
}

newEntity{ base = "BASE_ARMOR",
    define_as = "BASE_HEAVY_ARMOR",
    slot = "BODY",
    type = "armor", subtype="heavy",
    display = "[", color=colors.SLATE,
    require = { talent = { Talents.T_HEAVY_ARMOR_PROFICIENCY }, },
    moddable_tile = resolvers.moddable_tile("heavy"),
    encumber = 50,
    name = "heavy armor",
    material = "steel",
    desc = "A suit of armour made of plate.\n\n Heavy armor.",
--    egos = "/data/general/objects/properties/armor.lua", egos_chance = { prefix=30, suffix=70},
}

newEntity{ base = "BASE_HEAVY_ARMOR",
    name = "plate armor", short_name = "plate",
    image = "tiles/object/plate_armor.png",
    level_range = {1, 10},
    rarity = 18,
--    cost = 600,
    cost = resolvers.value{silver=6500},
    wielder = {
        combat_armor = 7,
        max_dex_bonus = 0,
		spell_fail = 40,
		armor_penalty = 7
    },
}

newEntity{ base = "BASE_HEAVY_ARMOR",
    name = "full plate", short_name = "fplate",
    image = "tiles/object/full_plate.png",
    level_range = {1, 10},
    rarity = 25,
--    cost = 1500,
    cost = resolvers.value{silver=9000},
    desc = "A suit of full plate armour.\n\n Heavy armor.",
    wielder = {
        combat_armor = 8,
        max_dex_bonus = 1,
		spell_fail = 35,
		armor_penalty = 6
    },
}

newEntity{ base = "BASE_HEAVY_ARMOR",
    name = "banded mail", short_name = "banded",
    unided_name = "banded mail",
    image = "tiles/object/banded_armor.png",
    level_range = {1, 10},
    rarity = 10,
--    cost = 250,
    cost = resolvers.value{platinum=8},
    desc = "A suit of banded mail.\n\n Heavy armor.",
    wielder = {
        combat_armor = 7,
        max_dex_bonus = 0,
		spell_fail = 35,
		armor_penalty = 6
    },
}

--Robes
newEntity{ base = "BASE_ARMOR",
    name = "monk robes", short_name = "monk",
    unided_name = "robes",
    subtype = "outfit",
    image = "tiles/new/monk_robes.png",
    moddable_tile = resolvers.moddable_tile("monk"),
    display = "(", color=colors.BLACK,
    encumber = 1,
    rarity = 15,
    level_range = {1, 10},
    cost = resolvers.value{silver=5},
    desc = [[A set of monk robes with a belt.]],
    require = {
        special = {
            fct = function(who, offset)
                if who.classes and who.classes["Monk"] and who.classes["Monk"] > 0 then return true
                else return false end
            end,
            desc = "Monk class",
            }
        },
    material = "leather",
}

newEntity{ base = "BASE_ARMOR",
    name = "archmage robes", short_name = "robes",
    unided_name = "robes",
    subtype = "outfit",
    image = "tiles/object/robes.png",
    moddable_tile = resolvers.moddable_tile("archmage"),
    display = "(", color=colors.RED,
    encumber = 1,
    rarity = 15,
    level_range = {10, 20},
    cost = resolvers.value{gold=500},
    desc = [[Elaborate robes of the kind a mage might wear.]],
    require = {
        special = {
            fct = function(who, offset)
                if who:casterLevel("arcane") > 0 then return true
                else return false end
            end,
            desc = "Ability to cast arcane spells",
            }
        },
    material = "leather",
}

newEntity{ base = "BASE_OUTFIT",
    name = "rags", short_name = "rags",
    unided_name = "rags",
    subtype = "outfit",
    image = "tiles/object/rags.png",
    moddable_tile = resolvers.moddable_tile("rags"),
    display = "(", color=colors.SLATE,
    encumber = 1,
    rarity = 10,
    level_range = {1, 20},
    cost = resolvers.value{silver=2},
    desc = [[A much worn outfit, not much better than rags.]],
}
