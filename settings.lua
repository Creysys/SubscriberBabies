subscriberBabiesSettings = {
	--change this to your channel
	twitchchannel = "cobaltstreak",
	--will each sub have the same entity every time? (true/false)
	subSeed = true,
	--if true change this number to switch to a different set of sub dependent entities
	subSeedOffset = 666,
	--tyrone is not letting me access the gui offset so you have to adjust this yourself im sorry :S
	subMessagePos = Vector(45, 45),
	--subscriber message color (0 to 1, a = transparency)
	subMessageColor = { r = 0.8, g = 0.4, b = 0.15, a = 0.85 },
	--subscriber message duration in seconds
	subMessageDuration = 5,
	--subscriber message fade out duration in seconds
	subMessageFadeDuration = 1,
	--subscriber name color
	subNameColor = { r = 1, g = 1, b = 1, a = 0.85 },
	--spawns a few test subs on startup
	debug = true,

	subEnemies = {
		{ type = EntityType.ENTITY_BOOMFLY, variant = 0, subType = 0 }
	},

	subFriendlies = {
		{ type = EntityType.ENTITY_BOOMFLY, variant = 0, subType = 0 }
	}
}