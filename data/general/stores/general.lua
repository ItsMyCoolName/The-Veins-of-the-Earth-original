newEntity{
	define_as = "GENERAL",
	name = "general store",
	display = '2', color=colors.UMBER,
	store = {
		purse = 10000,
--		nb_fill = 20,
		empty_before_restock = false,
		filters = {
			{type="weapon", subtype="shortsword", id=true },
			{type="weapon", subtype="sword", id=true, },
			{type="weapon", subtype="waraxe", id=true, },
			{type="weapon", subtype="battleaxe", id=true, },
			{type="weapon", subtype="mace", id=true,},
			{type="weapon", subtype="dagger", id=true, },
			{type="weapon", subtype="staff", id=true, },
			{type="weapon", subtype="crossbow", id=true, },
			{type="weapon", subtype="bow", id=true, },
			{type="weapon", subtype="sling", id=true, },
			{type="ammo", id=true, },
			{type="ammo", id=true, },
			{type="armor", subtype="heavy", id=true, },
			{type="armor", subtype="shield", id=true, },
			{type="armor", subtype="light", id=true, },
			{type="armor", subtype="medium", id=true, },
		},
	},
}
