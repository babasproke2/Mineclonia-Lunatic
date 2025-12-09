local races_api = {}
_G.mcl_lun_races = races_api
local race_meta_key = "mcl_lun_races:race"
local skin_meta_key = "mcl_lun_races:skin"
local last_race_meta_key = "mcl_lun_races:last_race"
local fly_priv_meta_key = "mcl_lun_races:granted_fly"
local fly_speed_meta_key = "mcl_lun_races:fly_speed"
local float_cap_meta_key = "mcl_lun_races:float_cap"
local elytra_cap_meta_key = "mcl_lun_races:elytra_cap"
local kit_awarded_meta_key = "mcl_lun_races:last_kit_race"
local fan_tier_meta_key = "mcl_lun_races:fan_tier"
local fan_stats_meta_key = "mcl_lun_races:fan_stats"
local FLY_SPEED = 0.15

local rarity_weights = {
	common = 5,
	normal = 3,
	rare = 1,
	["very rare"] = 0.5,
}

local function soundRandom(...)
	local sounds = {}
	for _, sound in ipairs({...}) do
		if sound and sound ~= "" then
			table.insert(sounds, sound)
		end
	end
	if #sounds == 0 then
		return ""
	end
	return sounds[math.random(#sounds)]
end

local race_defs = {
	{
		name = "Ice Fairy",
		rarity = "common",
		scale = { x = 0.7, y = 0.7 },
		eye_height = 1.0 * 0.5,
		eye_height_crouching = 1.4 * 0.5,
		skins = {"cirno.png"},
		flight_mode = "float",
		sounds = {
			random = "mobs_mc_bat_idle",
			damage = "mobs_mc_bat_hurt",
			distance = 10,
			accept = "mobs_mc_bat_idle",
			deny = soundRandom("mobs_mc_bat_hurt.1.ogg", "mobs_mc_bat_hurt.2.ogg", "mobs_mc_bat_hurt.3.ogg"),
			trade = "mobs_mc_bat_idle",
		},
	},
	{
		name = "Greater Fairy",
		rarity = "common",
		scale = { x = 0.75, y = 0.75 },
		eye_height = 1.0 * 0.6,
		eye_height_crouching = 1.4 * 0.6,
		skins = {"daiyousei.png"},
		flight_mode = "float",
		sounds = {
			random = "mobs_mc_bat_idle",
			damage = "mobs_mc_bat_hurt",
			distance = 10,
			accept = "mobs_mc_bat_idle",
			trade = "mobs_mc_bat_idle",
		},
	},
	{
		name = "Flower Fairy",
		rarity = "common",
		scale = { x = 0.65, y = 0.65 },
		eye_height = 1.0 * 0.6,
		eye_height_crouching = 1.4 * 0.6,
		skins = {"daiyousei.png"},
		flight_mode = "float",
		sounds = {
			random = "mobs_mc_bat_idle",
			damage = "mobs_mc_bat_hurt",
			distance = 10,
			accept = "mobs_mc_bat_idle",
			trade = "mobs_mc_bat_idle",
		},
	},
	{
		name = "Human Villager",
		rarity = "normal",
		scale = { x = 0.8, y = 0.8 },
		eye_height = 1.0 * 0.8,
		eye_height_crouching = 1.4 * 0.8,
		skins = {"village_boy_1.png", "village_boy_2.png"},
		fly = false,
	},
	{
		name = "Kappa",
		rarity = "normal",
		scale = { x = 0.65, y = 0.65 },
		eye_height = 1.0 * 0.6,
		eye_height_crouching = 1.4 * 0.6,
		skins = {"village_boy_1.png"},
		fly = false,
	},
	{
		name = "Sin Sack",
		rarity = "rare",
		scale = { x = 1.0, y = 1.0 },
		eye_height = 1.0 * 1.0,
		eye_height_crouching = 1.4 * 1.0,
		skins = {"sin_sack.png"},
		fly = false,
	},
	{
		name = "Crow Tengu",
		rarity = "normal",
		scale = { x = 0.9, y = 0.9 },
		eye_height = 1.0 * 0.9,
		eye_height_crouching = 1.4 * 0.9,
		skins = {"crow_tengu.png"},
		elytra = true,
	},
	{
		name = "Wolf Tengu",
		rarity = "normal",
		skins = {"crow_tengu.png"},
		fly = false,
	},
}

local default_race_sounds = {
	random = "mobs_mc_villager",
	damage = "mobs_mc_villager_hurt",
	distance = 10,
	accept = "mobs_mc_villager_accept",
	deny = "mobs_mc_villager_deny",
	trade = "mobs_mc_villager_trade",
}

local function soundRandom(...)
	local sounds = {}
	for _, sound in ipairs({...}) do
		if sound and sound ~= "" then
			table.insert(sounds, sound)
		end
	end
	if #sounds == 0 then
		return ""
	end
	return sounds[math.random(#sounds)]
end

local villager_defaults = {
	animation = {
		stand_start = 0,
		stand_end = 0,
		walk_start = 0,
		walk_end = 40,
		walk_speed = 35,
		nitwit_start = 41,
		nitwit_end = 81,
		nitwit_speed = 40,
		sleep_start = 82,
		sleep_end = 82,
		sleep_speed = 0,
	},
	movement_speed = 10.0,
	inventory_size = 8,
	trades = {},
	villager_type = "plains",
	profession = nil,
	passive = true,
	hp_min = 20,
	hp_max = 20,
	floats = 1,
	can_despawn = false,
	armor_groups = { fleshy = 100 },
}

for _, def in ipairs(race_defs) do
	def.sounds = def.sounds or table.copy(default_race_sounds)
	def.animation = def.animation or table.copy(villager_defaults.animation)
	def.movement_speed = def.movement_speed or villager_defaults.movement_speed
	def.inventory_size = def.inventory_size or villager_defaults.inventory_size
	def.trades = def.trades or villager_defaults.trades
	def.villager_type = def.villager_type or villager_defaults.villager_type
	def.profession = def.profession or villager_defaults.profession
	def.passive = def.passive or villager_defaults.passive
	def.hp_min = def.hp_min or villager_defaults.hp_min
	def.hp_max = def.hp_max or villager_defaults.hp_max
	def.floats = def.floats or villager_defaults.floats
	def.can_despawn = def.can_despawn or villager_defaults.can_despawn
	def.armor_groups = def.armor_groups or villager_defaults.armor_groups
end

local race_index = {}
for _, def in ipairs(race_defs) do
	race_index[def.name] = def
end

local CROW_BASE_BOOST_FORCE = 24
local CROW_BASE_BOOST_UPWARD = 6
local CROW_BASE_BOOST_COOLDOWN = 10
local crow_last_boost = {}

local fairy_flower_pool = {
	"mcl_flowers:poppy",
	"mcl_flowers:dandelion",
	"mcl_flowers:cornflower",
	"mcl_flowers:blue_orchid",
	"mcl_flowers:allium",
	"mcl_flowers:azure_bluet",
	"mcl_flowers:tulip_red",
	"mcl_flowers:tulip_orange",
	"mcl_flowers:tulip_white",
	"mcl_flowers:tulip_pink",
	"mcl_flowers:oxeye_daisy",
	"mcl_flowers:lily_of_the_valley",
	"mcl_flowers:peony",
	"mcl_flowers:rose_bush",
	"mcl_flowers:sunflower",
}

local prefix_api = rawget(_G, "mcl_lun_prefixes")

local function apply_item_prefix(stack, prefix_id)
	if not stack or stack:is_empty() then
		return stack
	end
	if prefix_api and prefix_api.apply_prefix then
		return prefix_api.apply_prefix(stack, prefix_id)
	end
	return stack
end

local function make_soulbound(stack)
	stack:get_meta():set_string("mcl_lun_races:soulbound", "1")
	return apply_item_prefix(stack, "soulbound")
end

local fan_tiers = {
	standard = {
		force_multiplier = 1.0,
		upward_multiplier = 1.0,
		cooldown = 4,
		durability = 150,
	},
	weak = {
		force_multiplier = 0.8,
		upward_multiplier = 0.8,
		cooldown = 5,
		durability = 100,
		prefix = "weak",
	},
	normal = {
		force_multiplier = 0.9,
		upward_multiplier = 0.9,
		cooldown = 4,
		durability = 150,
		prefix = "normal",
	},
	greater = {
		force_multiplier = 1.0,
		upward_multiplier = 1.0,
		cooldown = 3,
		durability = 200,
		prefix = "greater",
	},
}

local DEFAULT_FAN_TIER = "standard"

local fan_item_defaults = {
	["mcl_lun_races:hauchiwa_fan"] = "weak",
	["mcl_lun_races:hauchiwa_fan_normal"] = "normal",
	["mcl_lun_races:hauchiwa_fan_greater"] = "greater",
}

local function is_hauchiwa_item(name)
	if fan_item_defaults[name] then
		return true
	end
	return name and name:find("mcl_lun_races:hauchiwa_fan", 1, true) == 1
end

local function ensure_stack_object(stack)
	if not stack then
		return ItemStack("")
	end
	if getmetatable(stack) == ItemStack then
		return stack
	end
	if type(stack) == "userdata" and stack.get_meta then
		return stack
	end
	if type(stack) == "string" or type(stack) == "table" then
		local ok = ItemStack(stack)
		if not ok:is_empty() or (type(stack) == "table" and stack.name) then
			return ok
		end
	end
	return ItemStack("")
end

local function roll_variation(base)
	if not base then
		return 0
	end
	local variance = 0.9 + math.random() * 0.2
	return base * variance
end

local function update_fan_description(stack, stats)
	if not stack or stack:is_empty() or not stats then
		return
	end
	local lines = {
		("Force Boost: %+0.1f"):format(stats.force or 0),
		("Lift Bonus: %+0.1f"):format(stats.upward or 0),
		("Cooldown: %0.1fs"):format(stats.cooldown or 0),
		("Durability: %d uses"):format(stats.uses or 0),
	}
	if prefix_api and prefix_api.set_extra_lines then
		prefix_api.set_extra_lines(stack, lines)
	else
		local def = core.registered_items[stack:get_name()]
		local base_desc = def and def.description or stack:get_name()
		stack:get_meta():set_string("description", base_desc .. "\n" .. table.concat(lines, "\n"))
	end
end

local function set_fan_tier(stack, tier)
	stack = ensure_stack_object(stack)
	if not stack or stack:is_empty() then
		return stack
	end
	if not fan_tiers[tier] then
		return stack
	end
	local meta = stack:get_meta()
	meta:set_string(fan_tier_meta_key, tier)
	meta:set_string(fan_stats_meta_key, "")
	local tier_def = fan_tiers[tier]
	if tier_def.prefix then
		stack = apply_item_prefix(stack, tier_def.prefix)
	end
	if prefix_api and prefix_api.set_extra_lines then
		prefix_api.set_extra_lines(stack, {})
	end
	return stack
end

local function get_fan_tier(stack)
	stack = ensure_stack_object(stack)
	if not stack or stack:is_empty() then
		return DEFAULT_FAN_TIER, stack
	end
	local tier = stack:get_meta():get_string(fan_tier_meta_key)
	if tier == "" or not fan_tiers[tier] then
		local default = fan_item_defaults[stack:get_name()]
		if default and fan_tiers[default] then
			local updated = set_fan_tier(stack, default)
			if updated then
				stack = updated
			end
			return default or DEFAULT_FAN_TIER, stack
		end
		return DEFAULT_FAN_TIER, stack
	end
	return tier, stack
end

local function get_fan_stats(stack)
	stack = ensure_stack_object(stack)
	if not stack or stack:is_empty() then
		return nil, stack
	end
	local tier
	tier, stack = get_fan_tier(stack)
	if type(tier) == "table" then
		tier = DEFAULT_FAN_TIER
	end
	local tier_def = fan_tiers[tier] or fan_tiers[DEFAULT_FAN_TIER]
	if tier_def and tier_def.prefix then
		stack = apply_item_prefix(stack, tier_def.prefix)
	end
	local meta = stack:get_meta()
	local raw = meta:get_string(fan_stats_meta_key)
	local stats = raw ~= "" and core.deserialize(raw) or nil
	if type(stats) ~= "table" then
		stats = {
			force = CROW_BASE_BOOST_FORCE * roll_variation(tier_def.force_multiplier or 1),
			upward = CROW_BASE_BOOST_UPWARD * roll_variation(tier_def.upward_multiplier or tier_def.force_multiplier or 1),
			cooldown = math.max(0.5, roll_variation(tier_def.cooldown or CROW_BASE_BOOST_COOLDOWN)),
			uses = math.max(1, math.floor(roll_variation(tier_def.durability or 150))),
			tier = tier,
		}
		meta:set_string(fan_stats_meta_key, core.serialize(stats))
	end
	update_fan_description(stack, stats)
	return stats, stack
end

local function ensure_fan_stack_initialized(stack)
	stack = ensure_stack_object(stack)
	if not stack or stack:is_empty() then
		return stack
	end
	if not is_hauchiwa_item(stack:get_name()) then
		return stack
	end
	local _, initialized = get_fan_stats(stack)
	return initialized or stack
end

local race_kits = {
	["Sin Sack"] = function(inv)
		inv:add_item("main", "mcl_flowers:rose_bush")
		inv:add_item("main", make_soulbound(ItemStack("mcl_mobitems:cooked_beef 8")))
	end,
	["Human Villager"] = function(inv)
		inv:add_item("main", make_soulbound(ItemStack("mcl_core:stick 3")))
		inv:add_item("main", make_soulbound(ItemStack("mcl_mobitems:cooked_porkchop 2")))
	end,
	["Ice Fairy"] = function(inv)
		for i = 1, 3 do
			local flower = fairy_flower_pool[math.random(#fairy_flower_pool)]
			local count = math.random(1, 4)
			inv:add_item("main", make_soulbound(ItemStack(flower .. " " .. count)))
		end
		inv:add_item("main", make_soulbound(ItemStack("mcl_farming:cookie 16")))
	end,
	["Greater Fairy"] = function(inv)
		for i = 1, 3 do
			local flower = fairy_flower_pool[math.random(#fairy_flower_pool)]
			local count = math.random(1, 4)
			inv:add_item("main", make_soulbound(ItemStack(flower .. " " .. count)))
		end
		inv:add_item("main", make_soulbound(ItemStack("mcl_farming:cookie 16")))
	end,
	["Crow Tengu"] = function(inv)
		inv:add_item("main", make_soulbound(ItemStack("mcl_fishing:fish_cooked")))
		inv:add_item("main", make_soulbound(ItemStack("mcl_core:stick 2")))
		local fan = ItemStack("mcl_lun_races:hauchiwa_fan")
		fan = set_fan_tier(fan, "weak")
		fan = make_soulbound(fan)
		fan = ensure_fan_stack_initialized(fan)
		inv:add_item("main", fan)
	end,
}

local function give_race_kit(player, race)
	if not player or not race then
		return
	end
	local kit = race_kits[race]
	if not kit then
		return
	end
	local meta = player:get_meta()
	if meta:get_string(kit_awarded_meta_key) == race then
		return
	end
	local inv = player:get_inventory()
	if not inv then
		return
	end
	kit(inv)
	meta:set_string(kit_awarded_meta_key, race)
end

local function purge_soulbound_items(player)
	local inv = player:get_inventory()
	if not inv then
		return
	end
	local list = inv:get_list("main") or {}
	local changed = false
	for idx, stack in ipairs(list) do
		if not stack:is_empty() then
			local meta = stack:get_meta()
			if meta:get_string("mcl_lun_races:soulbound") == "1" then
				inv:set_stack("main", idx, ItemStack())
				changed = true
			end
		end
	end
	if not changed then
		return
	end
end

local function set_player_flight_speed(player, enabled)
	local updater = rawget(_G, "update_speed")
	if updater then
		updater(player:get_player_name(), enabled and FLY_SPEED or nil)
	else
		player:set_physics_override({ speed = enabled and FLY_SPEED or 1 })
	end
end

local function apply_race_capabilities(player, race_name)
	if not player then
		return
	end
	local def = race_index[race_name or ""]
	local flight_mode = def and def.flight_mode
	local allow_fly_priv = def and def.fly and flight_mode ~= "float"
	local meta = player:get_meta()
	local had_race_fly = meta:get_int(fly_priv_meta_key) == 1
	local had_speed_override = meta:get_int(fly_speed_meta_key) == 1
	local had_float_cap = meta:get_int(float_cap_meta_key) == 1
	local had_elytra_cap = meta:get_int(elytra_cap_meta_key) == 1
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)

	if allow_fly_priv then
		if not privs.fly then
			privs.fly = true
			core.set_player_privs(name, privs)
			meta:set_int(fly_priv_meta_key, 1)
		end
		set_player_flight_speed(player, true)
		meta:set_int(fly_speed_meta_key, 1)
	else
		if had_race_fly and privs.fly then
			privs.fly = nil
			core.set_player_privs(name, privs)
		end
		meta:set_int(fly_priv_meta_key, 0)
		if had_speed_override then
			set_player_flight_speed(player, false)
			meta:set_int(fly_speed_meta_key, 0)
		end
	end

	if had_float_cap then
		meta:set_int(float_cap_meta_key, 0)
		if mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
			mcl_serverplayer.set_fall_flying_capable(player, false)
		end
	end

	if def and def.elytra and mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
		if not had_elytra_cap then
			mcl_serverplayer.set_fall_flying_capable(player, true)
			meta:set_int(elytra_cap_meta_key, 1)
		end
	else
		if had_elytra_cap and mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
			mcl_serverplayer.set_fall_flying_capable(player, false)
		end
		meta:set_int(elytra_cap_meta_key, 0)
	end
end

local function choose_race()
	local total_weight = 0
	for _, def in ipairs(race_defs) do
		local rarity = def.rarity or "normal"
		total_weight = total_weight + (rarity_weights[rarity] or 1)
	end
	local roll = math.random() * total_weight
	local cumulative = 0
	for _, def in ipairs(race_defs) do
		local rarity = def.rarity or "normal"
		cumulative = cumulative + (rarity_weights[rarity] or 1)
		if roll <= cumulative then
			return def.name
		end
	end
	return race_defs[#race_defs].name
end

local function choose_skin(race_name)
	local def = race_index[race_name]
	if not def or #def.skins == 0 then
		return nil
	end
	local idx = math.random(1, #def.skins)
	return def.skins[idx]
end

local function race_has_skin(race_name, texture)
	local def = race_index[race_name]
	if not def then
		return false
	end
	for _, tex in ipairs(def.skins) do
		if tex == texture then
			return true
		end
	end
	return false
end

local function apply_visual_properties(player, race_name)
	local def = race_index[race_name or ""]
	local scale = def and def.scale or { x = 1, y = 1 }
	local eye_height = def and def.eye_height or 1.0 * scale.y
	local eye_height_crouching = def and def.eye_height_crouching or 0.8 * scale.y
	local cb_half = 0.3 * scale.x
	local cb_height = 1.8 * scale.y
	local collisionbox = {
		-cb_half, 0, -cb_half,
		cb_half, cb_height, cb_half,
	}
	local selectionbox = {
		-cb_half, 0, -cb_half,
		cb_half, cb_height, cb_half,
	}
	player:set_properties({
		visual_size = scale,
		collisionbox = collisionbox,
		selectionbox = selectionbox,
		eye_height = eye_height,
		eye_height_crouching = eye_height_crouching,
	})

	if mcl_player and mcl_player.player_set_eye_offset then
		mcl_player.player_set_eye_offset(player, vector.new(0, eye_height, 0), vector.new(0, eye_height, 0))
	else
		player:set_eye_offset(vector.new(0, eye_height, 0), vector.new(0, eye_height, 0))
	end
end

local function is_crow_tengu(player)
	return races_api.get_race(player) == "Crow Tengu"
end

local function crow_cooldown_ready(player, cooldown)
	local name = player:get_player_name()
	local last = crow_last_boost[name]
	if not last then
		return true, 0
	end
	local now = core.get_gametime()
	local cd = cooldown or CROW_BASE_BOOST_COOLDOWN
	local remaining = cd - (now - last)
	return remaining <= 0, math.max(remaining, 0)
end

local function crow_mark_boost(player)
	crow_last_boost[player:get_player_name()] = core.get_gametime()
end

local function crow_can_boost(player)
	local attach = player:get_attach()
	if not attach then
		return false
	end
	local ent = attach:get_luaentity()
	return ent and ent.name == "mcl_armor:elytra_entity"
end

local function crow_apply_boost(player, force, upward_bonus)
	local boost_force = force or CROW_BASE_BOOST_FORCE
	local upward = upward_bonus or CROW_BASE_BOOST_UPWARD
	local dir = player:get_look_dir()
	local forward = vector.new(dir.x, 0, dir.z)
	if forward.x ~= 0 or forward.z ~= 0 then
		forward = vector.normalize(forward)
	else
		forward = vector.new(0, 0, 0)
	end
	local upward_dir = math.max(dir.y, -0.2)
	local boost = {
		x = forward.x * boost_force,
		y = upward_dir * (boost_force * 0.35) + upward,
		z = forward.z * boost_force,
	}
	local target = player
	local attach = player:get_attach()
	if attach and attach:get_luaentity()
		and attach:get_luaentity().name == "mcl_armor:elytra_entity" then
		target = attach
	end
	if target.add_velocity then
		target:add_velocity(boost)
	else
		local current = target:get_velocity() or vector.zero()
		target:set_velocity(vector.add(current, boost))
	end
	crow_mark_boost(player)
	core.sound_play("mcl_fireworks_rocket", {pos = player:get_pos(), gain = 0.4, max_hear_distance = 32}, true)
end

local function crow_try_boost(player, stats)
	if not player or not is_crow_tengu(player) then
		return false
	end
	if not crow_can_boost(player) then
		core.chat_send_player(player:get_player_name(), "You need to be gliding to use the Hauchiwa Fan.")
		return false
	end
	local cooldown = stats and stats.cooldown or CROW_BASE_BOOST_COOLDOWN
	local ready, remaining = crow_cooldown_ready(player, cooldown)
	if not ready then
		core.chat_send_player(player:get_player_name(), string.format("Hauchiwa Fan cooling down (%.1fs)", remaining))
		return false
	end
	crow_apply_boost(player, stats and stats.force, stats and stats.upward)
	return true
end

local function fan_secondary_use(itemstack, user, pointed_thing)
	if not user or not itemstack then
		return itemstack
	end
	local stats
	stats, itemstack = get_fan_stats(itemstack)
	if stats and crow_try_boost(user, stats) then
		itemstack:add_wear_by_uses(stats.uses or 100)
	end
	return itemstack
end

local function register_hauchiwa_fan(itemname, def)
	local tier = def.tier
	local desc = def.description or "Hauchiwa Fan"
	core.register_tool(itemname, {
		description = desc,
		_tt_help = def.help or "Right-click while gliding as a Crow Tengu to boost",
		_doc_items_longdesc = def.longdesc or "A tengu fan that channels burst winds while gliding.",
		inventory_image = def.texture or "hauchiwa_fan.png",
		wield_image = def.texture or "hauchiwa_fan.png",
		wield_scale = { x = 1.5, y = 1.5, z = 1.5 },
		stack_max = 1,
		groups = {stick = 1, flammable = 2, tool = 1, handy = 1},
		_mcl_toollike_wield = true,
		sound = {breaks = "default_tool_breaks"},
		on_secondary_use = function(stack, user, pointed_thing)
			if tier and stack:get_meta():get_string(fan_tier_meta_key) == "" then
				stack = set_fan_tier(stack, tier)
			end
			return fan_secondary_use(stack, user, pointed_thing)
		end,
		tool_capabilities = {
			full_punch_interval = 1.0,
			max_drop_level = 0,
			uses = 200,
			time = { [1] = 3.0, [2] = 3.0, [3] = 3.0 },
			damage_groups = {fleshy = 1},
		},
	})
end

register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan", {
	description = "Weak Hauchiwa Fan",
	tier = "weak",
})

register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan_normal", {
	description = "Normal Hauchiwa Fan",
	tier = "normal",
})

register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan_greater", {
	description = "Greater Hauchiwa Fan",
	tier = "greater",
})

core.register_on_craft(function(itemstack)
	if not itemstack or itemstack:is_empty() then
		return itemstack
	end
	if not is_hauchiwa_item(itemstack:get_name()) then
		return itemstack
	end
	return ensure_fan_stack_initialized(itemstack)
end)

local function refresh_inventory_fan(inv, listname, index)
	if not inv or not listname or not index then
		return
	end
	local stack = inv:get_stack(listname, index)
	if stack:is_empty() or not is_hauchiwa_item(stack:get_name()) then
		return
	end
	local initialized = ensure_fan_stack_initialized(stack)
	inv:set_stack(listname, index, initialized)
end

core.register_on_player_inventory_action(function(player, action, inventory, info)
	if not inventory or type(info) ~= "table" then
		return
	end
	local function handle(listname, index)
		if listname and index then
			refresh_inventory_fan(inventory, listname, index)
		end
	end
	if action == "put" or action == "take" then
		handle(info.list, info.index)
	elseif action == "move" then
		handle(info.from_list, info.from_index)
		handle(info.to_list, info.to_index)
	end
end)

if core.register_on_item_drop then
	core.register_on_item_drop(function(player, itemstack, dropper)
		if not itemstack or itemstack:is_empty() then
			return itemstack
		end
		if is_hauchiwa_item(itemstack:get_name()) then
			itemstack = ensure_fan_stack_initialized(itemstack)
		end
		return itemstack
	end)
end

local function apply_skin(player, texture, race_name)
	if not texture then
		return
	end
	if not mcl_skins or not mcl_skins.texture_to_simple_skin then
		core.log("error", "[mcl_lun_races] mcl_skins is not available, cannot assign texture " .. texture)
		return
	end
	if not mcl_skins.texture_to_simple_skin[texture] then
		core.log("error", "[mcl_lun_races] Texture " .. texture .. " is not registered as a simple skin.")
		return
	end
	local skin_state = mcl_skins.player_skins[player]
	if not skin_state then
		-- default to alex template so that save() has a valid table
		skin_state = table.copy(mcl_skins.alex)
		mcl_skins.player_skins[player] = skin_state
	end
	skin_state.simple_skins_id = texture
	skin_state.base = nil
	skin_state.slim_arms = mcl_skins.texture_to_simple_skin[texture].slim_arms
	mcl_skins.save(player)
	mcl_skins.update_player_skin(player)
end

local function handle_race_transition(player, race)
	if not player or not race or race == "" then
		return false
	end
	local meta = player:get_meta()
	local previous = meta:get_string(last_race_meta_key)
	if previous == race then
		return false
	end
	purge_soulbound_items(player)
	meta:set_string(last_race_meta_key, race)
	meta:set_string(kit_awarded_meta_key, "")
	return true
end

local function apply_full_race_state(player, race, texture)
	if not player or not race or race == "" then
		return
	end
	if texture and texture ~= "" then
		apply_skin(player, texture, race)
	end
	apply_visual_properties(player, race)
	apply_race_capabilities(player, race)
	handle_race_transition(player, race)
	give_race_kit(player, race)
end

local function get_current_simple_skin(player)
	if not mcl_skins or not mcl_skins.player_skins then
		return nil
	end
	local state = mcl_skins.player_skins[player]
	if not state then
		return nil
	end
	return state.simple_skins_id
end

local function ensure_race_assignment(player)
	local meta = player:get_meta()
	local race = meta:get_string(race_meta_key)
	if race == "" then
		race = choose_race()
		meta:set_string(race_meta_key, race)
		meta:set_string("race", race)
	end
	local texture = meta:get_string(skin_meta_key)

	if texture == "" then
		local current_simple = get_current_simple_skin(player)
		if current_simple and race_has_skin(race, current_simple) then
			texture = current_simple
			meta:set_string(skin_meta_key, texture)
		end
	end

	if texture == "" or not race_has_skin(race, texture) then
		local new_texture = choose_skin(race)
		if new_texture then
			texture = new_texture
			meta:set_string(skin_meta_key, texture)
		end
	end

	if texture ~= "" then
		apply_full_race_state(player, race, texture)
	else
		apply_full_race_state(player, race)
	end

	local race_label = race:gsub("^%l", string.upper)
	core.chat_send_player(player:get_player_name(), "Your race: " .. race_label)
end

local function initialize_player_fans(player)
	local inv = player:get_inventory()
	if not inv then
		return
	end
	for _, listname in ipairs({"main", "craft", "hand"}) do
		local list = inv:get_list(listname)
		if list then
			for idx, stack in ipairs(list) do
				if not stack:is_empty() and is_hauchiwa_item(stack:get_name()) then
					inv:set_stack(listname, idx, ensure_fan_stack_initialized(stack))
				end
			end
		end
	end
end

core.register_on_joinplayer(function(player)
	if not player then
		return
	end
	core.after(0, ensure_race_assignment, player)
	core.after(0, initialize_player_fans, player)
end)

local fan_refresh_timer = 0
core.register_globalstep(function(dtime)
	fan_refresh_timer = fan_refresh_timer + dtime
	if fan_refresh_timer < 1 then
		return
	end
	fan_refresh_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		initialize_player_fans(player)
	end
end)

core.register_on_leaveplayer(function(player)
	crow_last_boost[player:get_player_name()] = nil
end)

function races_api.get_race(player)
	if not player then
		return nil
	end
	local meta = player:get_meta()
	return meta:get_string(race_meta_key)
end

races_api.assign_skin = apply_skin
races_api.choose_race = choose_race
races_api.choose_skin = choose_skin
races_api.apply_visual_properties = apply_visual_properties
races_api.race_index = race_index
function races_api.get_definition(race_name)
	return race_index[race_name]
end

core.register_chatcommand("reroll", {
	description = "Re-roll your race and associated skin",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local meta = player:get_meta()
		local race = choose_race()
		meta:set_string(race_meta_key, race)
		meta:set_string("race", race)
		local texture = choose_skin(race)
		if texture then
			meta:set_string(skin_meta_key, texture)
		end
		apply_full_race_state(player, race, texture)
		core.chat_send_player(name, "Your race: " .. race:gsub("^%l", string.upper))
		return true, "Race re-rolled."
		end,
})

core.register_chatcommand("height", {
	params = "<scale 1-100>",
	description = "Temporarily scale your player size for debugging",
	func = function(name, param)
		local player = core.get_player_by_name(name)
		if not player then
			return false, "Player not found."
		end
		local value = tonumber(param)
		if not value or value < 1 or value > 100 then
			return false, "Usage: /height <number between 1 and 100>"
		end
		local scale_factor = value / 100
		local cb_half = 0.3 * scale_factor
		local cb_height = 1.8 * scale_factor
		local eye_height = 1.0 * scale_factor
		player:set_properties({
			visual_size = { x = scale_factor, y = scale_factor },
			collisionbox = { -cb_half, 0, -cb_half, cb_half, cb_height, cb_half },
			selectionbox = { -cb_half, 0, -cb_half, cb_half, cb_height, cb_half },
			eye_height = eye_height,
			eye_height_crouching = 0.8 * scale_factor,
		})
		local eye_offset = vector.new(0, eye_height, 0)
		if mcl_player and mcl_player.player_set_eye_offset then
			mcl_player.player_set_eye_offset(player, eye_offset, eye_offset)
		else
			player:set_eye_offset(eye_offset, eye_offset)
		end
		core.chat_send_player(name, ("Visual size set to %.2f"):format(scale_factor))
		return true
	end,
})

mcl_player.register_on_visual_change(function(player)
	local race = races_api.get_race(player)
	races_api.apply_visual_properties(player, race)
	apply_race_capabilities(player, race)
end)

return races_api
