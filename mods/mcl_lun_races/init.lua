
local mcl_player = rawget(_G, "mcl_player")
local races_api = {}
_G.mcl_lun_races = races_api

-- --- Constants & Metadata Keys ---
local KB_RACE = "mcl_lun_races:race"
local KB_SKIN = "mcl_lun_races:skin"
local KB_LAST_RACE = "mcl_lun_races:last_race"
local KB_GRANTED_FLY = "mcl_lun_races:granted_fly"
local KB_FLY_SPEED = "mcl_lun_races:fly_speed"
local KB_FLOAT_CAP = "mcl_lun_races:float_cap"
local KB_ELYTRA_CAP = "mcl_lun_races:elytra_cap"
local KB_KIT_AWARDED = "mcl_lun_races:last_kit_race"

local FLY_SPEED = 0.15

-- --- Utility Functions ---

local function sound_random(...)
	local sounds = {}
	for _, sound in ipairs({...}) do
		if sound and sound ~= "" then
			table.insert(sounds, sound)
		end
	end
	if #sounds == 0 then return "" end
	return sounds[math.random(#sounds)]
end

-- --- Race Class ---

local Race = {}
Race.__index = Race

function Race.new(name, def)
	local self = setmetatable({}, Race)
	self.name = name
	self.rarity = def.rarity or "normal"
	self.scale = def.scale or {x = 1, y = 1}
	self.eye_height = def.eye_height or (1.0 * self.scale.y)
	self.eye_height_crouching = def.eye_height_crouching or (0.8 * self.scale.y)
	self.skins = def.skins or {}
	self.flight_mode = def.flight_mode
	self.fly = def.fly
	self.elytra = def.elytra
	self.sounds = def.sounds or {
		random = "mobs_mc_villager",
		damage = "mobs_mc_villager_hurt",
		distance = 10,
		accept = "mobs_mc_villager_accept",
		deny = "mobs_mc_villager_deny",
		trade = "mobs_mc_villager_trade",
	}
	self.kit_func = def.kit_func
	return self
end

function Race:apply_visuals(player)
	local cb_half = 0.3 * self.scale.x
	local cb_height = 1.8 * self.scale.y
	local collisionbox = {-cb_half, 0, -cb_half, cb_half, cb_height, cb_half}
	local selectionbox = {-cb_half, 0, -cb_half, cb_half, cb_height, cb_half}

	player:set_properties({
		visual_size = self.scale,
		collisionbox = collisionbox,
		selectionbox = selectionbox,
		eye_height = self.eye_height,
		eye_height_crouching = self.eye_height_crouching,
	})

	local eye_offset = vector.new(0, self.eye_height, 0)
	if mcl_player and mcl_player.player_set_eye_offset then
		mcl_player.player_set_eye_offset(player, eye_offset, eye_offset)
	else
		player:set_eye_offset(eye_offset, eye_offset)
	end
end

local FAN_FIRE_COOLDOWN = 0.35
local fan_cooldowns = {}

local function fan_ready(user)
	if not user then
		return true
	end
	local name = user:get_player_name()
	if not name or name == "" then
		return true
	end
	local now = core.get_gametime()
	local next_allowed = fan_cooldowns[name] or 0
	if now < next_allowed then
		return false
	end
	fan_cooldowns[name] = now + FAN_FIRE_COOLDOWN
	return true
end

function Race:apply_capabilities(player)
	local meta = player:get_meta()
	local name = player:get_player_name()
	local privs = core.get_player_privs(name)
	
	local flight_mode = self.flight_mode
	local allow_fly_priv = self.fly and flight_mode ~= "float"

	local had_race_fly = meta:get_int(KB_GRANTED_FLY) == 1
	local had_speed_override = meta:get_int(KB_FLY_SPEED) == 1
	local had_float_cap = meta:get_int(KB_FLOAT_CAP) == 1
	local had_elytra_cap = meta:get_int(KB_ELYTRA_CAP) == 1

	-- Flight ability handling
	if allow_fly_priv then
		if not privs.fly then
			privs.fly = true
			core.set_player_privs(name, privs)
			meta:set_int(KB_GRANTED_FLY, 1)
		end
		
		-- Set flight speed
		local updater = rawget(_G, "update_speed")
		if updater then
			updater(name, FLY_SPEED)
		else
			player:set_physics_override({ speed = FLY_SPEED })
		end
		meta:set_int(KB_FLY_SPEED, 1)
	else
		if had_race_fly and privs.fly then
			privs.fly = nil
			core.set_player_privs(name, privs)
		end
		meta:set_int(KB_GRANTED_FLY, 0)
		if had_speed_override then
			local updater = rawget(_G, "update_speed")
			if updater then
				updater(name, nil)
			else
				player:set_physics_override({ speed = 1 })
			end
			meta:set_int(KB_FLY_SPEED, 0)
		end
	end

	-- Floating capability
	if had_float_cap then
		meta:set_int(KB_FLOAT_CAP, 0)
		if mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
			mcl_serverplayer.set_fall_flying_capable(player, false)
		end
	end

	-- Elytra capability
	if self.elytra and mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
		if not had_elytra_cap then
			mcl_serverplayer.set_fall_flying_capable(player, true)
			meta:set_int(KB_ELYTRA_CAP, 1)
		end
	else
		if had_elytra_cap and mcl_serverplayer and mcl_serverplayer.set_fall_flying_capable then
			mcl_serverplayer.set_fall_flying_capable(player, false)
		end
		meta:set_int(KB_ELYTRA_CAP, 0)
	end
end

function Race:give_kit(player)
	if not self.kit_func then return end
	local meta = player:get_meta()
	if meta:get_string(KB_KIT_AWARDED) == self.name then return end
	
	local inv = player:get_inventory()
	if not inv then return end
	
	self.kit_func(inv)
	meta:set_string(KB_KIT_AWARDED, self.name)
end

function Race:get_random_skin()
	if #self.skins == 0 then return nil end
	return self.skins[math.random(#self.skins)]
end

function Race:has_skin(texture)
	for _, tex in ipairs(self.skins) do
		if tex == texture then return true end
	end
	return false
end

-- --- Race Registry ---

local Registry = {
	races = {},
	weights = {
		common = 5,
		normal = 3,
		rare = 1,
		["very rare"] = 0.5,
	}
}

function Registry.register(name, def)
	local race = Race.new(name, def)
	Registry.races[name] = race
end

function Registry.get(name)
	return Registry.races[name]
end

function Registry.roll()
	local list = {}
	local total_weight = 0
	for name, race in pairs(Registry.races) do
		local w = Registry.weights[race.rarity] or 1
		total_weight = total_weight + w
		table.insert(list, {race = race, weight = w})
	end
	
	local roll = math.random() * total_weight
	local cumulative = 0
	for _, item in ipairs(list) do
		cumulative = cumulative + item.weight
		if roll <= cumulative then
			return item.race
		end
	end
	-- Fallback
	for _, item in ipairs(list) do return item.race end
end

-- --- Helper Functions (Prefixes & Soulbound) ---

local prefix_api = rawget(_G, "mcl_lun_prefixes")

local function apply_item_prefix(stack, prefix_id)
	if not stack or stack:is_empty() then return stack end
	if prefix_api and prefix_api.apply_prefix then
		return prefix_api.apply_prefix(stack, prefix_id)
	end
	return stack
end

local function make_soulbound(stack)
	stack:get_meta():set_string("mcl_lun_races:soulbound", "1")
	return apply_item_prefix(stack, "soulbound")
end

local function purge_soulbound_items(player)
	local inv = player:get_inventory()
	if not inv then return end
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
end

-- --- Kits Configuration ---

local fairy_flower_pool = {
	"mcl_flowers:poppy", "mcl_flowers:dandelion", "mcl_flowers:cornflower",
	"mcl_flowers:blue_orchid", "mcl_flowers:allium", "mcl_flowers:azure_bluet",
	"mcl_flowers:tulip_red", "mcl_flowers:tulip_orange", "mcl_flowers:tulip_white",
	"mcl_flowers:tulip_pink", "mcl_flowers:oxeye_daisy", "mcl_flowers:lily_of_the_valley",
	"mcl_flowers:peony", "mcl_flowers:rose_bush", "mcl_flowers:sunflower",
}

-- --- Fan Logic (Preserved & Adapted) ---
-- Kept separate as it's item logic, but adapted to interact with Race system

local fan_tier_meta_key = "mcl_lun_races:fan_tier"
local fan_stats_meta_key = "mcl_lun_races:fan_stats"

local fan_tiers = {
	standard = {force_multiplier = 1.0, upward_multiplier = 1.0, cooldown = 4, durability = 150},
	weak = {force_multiplier = 0.8, upward_multiplier = 0.8, cooldown = 5, durability = 100, prefix = "weak"},
	normal = {force_multiplier = 0.9, upward_multiplier = 0.9, cooldown = 4, durability = 150, prefix = "normal"},
	greater = {force_multiplier = 1.0, upward_multiplier = 1.0, cooldown = 3, durability = 200, prefix = "greater"},
}

local DEFAULT_FAN_TIER = "standard"
local fan_item_defaults = {
	["mcl_lun_races:hauchiwa_fan"] = "weak",
	["mcl_lun_races:hauchiwa_fan_normal"] = "normal",
	["mcl_lun_races:hauchiwa_fan_greater"] = "greater",
}

local function ensure_stack_object(stack)
	if not stack then return ItemStack("") end
	if getmetatable(stack) == ItemStack then return stack end
	if type(stack) == "userdata" and stack.get_meta then return stack end
	return ItemStack(stack)
end

local function set_fan_tier(stack, tier)
	stack = ensure_stack_object(stack)
	if stack:is_empty() or not fan_tiers[tier] then return stack end
	local meta = stack:get_meta()
	meta:set_string(fan_tier_meta_key, tier)
	meta:set_string(fan_stats_meta_key, "")
	local tier_def = fan_tiers[tier]
	if tier_def.prefix then stack = apply_item_prefix(stack, tier_def.prefix) end
	if prefix_api and prefix_api.set_extra_lines then prefix_api.set_extra_lines(stack, {}) end
	return stack
end

local function get_fan_tier(stack)
	stack = ensure_stack_object(stack)
	if stack:is_empty() then return DEFAULT_FAN_TIER, stack end
	local tier = stack:get_meta():get_string(fan_tier_meta_key)
	if tier == "" or not fan_tiers[tier] then
		local default = fan_item_defaults[stack:get_name()]
		if default and fan_tiers[default] then
			local updated = set_fan_tier(stack, default)
			return default, updated
		end
		return DEFAULT_FAN_TIER, stack
	end
	return tier, stack
end

local function roll_variation(base)
	if not base then return 0 end
	return base * (0.9 + math.random() * 0.2)
end

local function update_fan_description(stack, stats)
	if not stack or stack:is_empty() or not stats then return end
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

local CROW_BASE_BOOST_FORCE = 24
local CROW_BASE_BOOST_UPWARD = 6
local CROW_BASE_BOOST_COOLDOWN = 10
local CROW_DISTANCE_BONUS = 3
local crow_last_boost = {}

local function get_fan_stats(stack)
	stack = ensure_stack_object(stack)
	if stack:is_empty() then return nil, stack end
	local tier, updated_stack = get_fan_tier(stack)
	stack = updated_stack
	
	local tier_def = fan_tiers[tier] or fan_tiers[DEFAULT_FAN_TIER]
	local meta = stack:get_meta()
	local raw = meta:get_string(fan_stats_meta_key)
	local stats = raw ~= "" and core.deserialize(raw) or nil
	
	if type(stats) ~= "table" then
		local base_force = CROW_BASE_BOOST_FORCE * roll_variation(tier_def.force_multiplier or 1)
		stats = {
			force = base_force * 1.3,
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
	if not stack or stack:is_empty() then return stack end
	if not fan_item_defaults[stack:get_name()] and not stack:get_name():find("mcl_lun_races:hauchiwa_fan", 1, true) then return stack end
	local _, initialized = get_fan_stats(stack)
	return initialized
end

-- --- Register Races ---

Registry.register("Ice Fairy", {
	rarity = "common",
	scale = {x = 0.7, y = 0.7},
	skins = {"cirno.png"},
	flight_mode = "float",
	sounds = {
		random = "mobs_mc_bat_idle",
		damage = "mobs_mc_bat_hurt",
		distance = 10,
		accept = "mobs_mc_bat_idle",
		deny = sound_random("mobs_mc_bat_hurt.1.ogg", "mobs_mc_bat_hurt.2.ogg", "mobs_mc_bat_hurt.3.ogg"),
		trade = "mobs_mc_bat_idle",
	},
	kit_func = function(inv)
		for i = 1, 3 do
			local flower = fairy_flower_pool[math.random(#fairy_flower_pool)]
			local count = math.random(1, 4)
			inv:add_item("main", make_soulbound(ItemStack(flower .. " " .. count)))
		end
		inv:add_item("main", make_soulbound(ItemStack("mcl_farming:cookie 16")))
	end
})

Registry.register("Greater Fairy", {
	rarity = "common",
	scale = {x = 0.75, y = 0.75},
	skins = {"daiyousei.png"},
	flight_mode = "float",
	sounds = {
		random = "mobs_mc_bat_idle",
		damage = "mobs_mc_bat_hurt",
		distance = 10,
		accept = "mobs_mc_bat_idle",
		trade = "mobs_mc_bat_idle",
	},
	kit_func = function(inv)
		for i = 1, 3 do
			local flower = fairy_flower_pool[math.random(#fairy_flower_pool)]
			local count = math.random(1, 4)
			inv:add_item("main", make_soulbound(ItemStack(flower .. " " .. count)))
		end
		inv:add_item("main", make_soulbound(ItemStack("mcl_farming:cookie 16")))
	end
})

Registry.register("Flower Fairy", {
	rarity = "common",
	scale = {x = 0.65, y = 0.65},
	skins = {"daiyousei.png"},
	flight_mode = "float",
	sounds = {
		random = "mobs_mc_bat_idle",
		damage = "mobs_mc_bat_hurt",
		distance = 10,
		accept = "mobs_mc_bat_idle",
		trade = "mobs_mc_bat_idle",
	},
})

Registry.register("Human Villager", {
	rarity = "normal",
	scale = {x = 0.8, y = 0.8},
	skins = {"village_boy_1.png", "village_boy_2.png"},
	fly = false,
	kit_func = function(inv)
		inv:add_item("main", make_soulbound(ItemStack("mcl_core:stick 3")))
		inv:add_item("main", make_soulbound(ItemStack("mcl_mobitems:cooked_porkchop 2")))
	end
})

Registry.register("Kappa", {
	rarity = "normal",
	scale = {x = 0.65, y = 0.65},
	skins = {"village_boy_1.png"},
	fly = false,
})

Registry.register("Sin Sack", {
	rarity = "rare",
	scale = {x = 1.0, y = 1.0},
	skins = {"sin_sack.png"},
	fly = false,
	kit_func = function(inv)
		inv:add_item("main", "mcl_flowers:rose_bush")
		inv:add_item("main", make_soulbound(ItemStack("mcl_mobitems:cooked_beef 8")))
	end
})

Registry.register("Crow Tengu", {
	rarity = "normal",
	scale = {x = 0.9, y = 0.9},
	skins = {"crow_tengu.png"},
	elytra = true,
	kit_func = function(inv)
		inv:add_item("main", make_soulbound(ItemStack("mcl_fishing:fish_cooked")))
		inv:add_item("main", make_soulbound(ItemStack("mcl_core:stick 2")))
		local fan = ItemStack("mcl_lun_races:hauchiwa_fan")
		fan = set_fan_tier(fan, "weak")
		fan = make_soulbound(fan)
		fan = ensure_fan_stack_initialized(fan)
		inv:add_item("main", fan)
	end
})

Registry.register("Wolf Tengu", {
	rarity = "normal",
	skins = {"crow_tengu.png"},
	fly = false,
})


-- --- API Logic ---

local function apply_skin_texture(player, texture)
	if not texture then return end
	if not mcl_skins or not mcl_skins.texture_to_simple_skin then return end
	if not mcl_skins.texture_to_simple_skin[texture] then return end

	local skin_state = mcl_skins.player_skins[player]
	if not skin_state then
		skin_state = table.copy(mcl_skins.alex)
		mcl_skins.player_skins[player] = skin_state
	end
	skin_state.simple_skins_id = texture
	skin_state.base = nil
	skin_state.slim_arms = mcl_skins.texture_to_simple_skin[texture].slim_arms
	mcl_skins.save(player)
	mcl_skins.update_player_skin(player)
end

function races_api.get_race(player)
	if not player then return nil end
	return player:get_meta():get_string(KB_RACE)
end

function races_api.get_definition(name)
	return Registry.get(name)
end

local function apply_race_full(player, race_name, forced_texture)
	local race = Registry.get(race_name)
	if not race then return end
	
	-- Transition Logic
	local meta = player:get_meta()
	local last_race = meta:get_string(KB_LAST_RACE)
	if last_race ~= race.name then
		purge_soulbound_items(player)
		meta:set_string(KB_LAST_RACE, race.name)
		meta:set_string(KB_KIT_AWARDED, "")
	end

	-- Skin
	local texture = forced_texture
	if not texture then
		local current = meta:get_string(KB_SKIN)
		if current ~= "" and race:has_skin(current) then
			texture = current
		else
			-- Check mcl_skins match
			if mcl_skins and mcl_skins.player_skins and mcl_skins.player_skins[player] then
				local s = mcl_skins.player_skins[player].simple_skins_id
				if s and race:has_skin(s) then texture = s end
			end
		end
	end
	if not texture then texture = race:get_random_skin() end
	
	if texture then
		apply_skin_texture(player, texture)
		meta:set_string(KB_SKIN, texture)
	end

	-- Visuals & Caps
	race:apply_visuals(player)
	race:apply_capabilities(player)
	race:give_kit(player)
end

local function ensure_player_race(player)
	local meta = player:get_meta()
	local current = meta:get_string(KB_RACE)
	if current == "" or not Registry.get(current) then
		local race = Registry.roll()
		current = race.name
		meta:set_string(KB_RACE, current)
		meta:set_string("race", current) -- legacy key?
	end
	apply_race_full(player, current)
	local race_label = current:gsub("^%l", string.upper)
	core.chat_send_player(player:get_player_name(), "Your race: " .. race_label)
end

	local function play_hauchiwa_attack_animation(player)
		if not player or not player:is_player() then
			return
		end
		if mcl_player and mcl_player.force_swing_animation then
			mcl_player.force_swing_animation(player, 0.4)
		elseif mcl_player and mcl_player.player_set_animation then
			mcl_player.player_set_animation(player, "mine")
		else
			player:set_animation({x = 189, y = 198}, 30, 0)
		end
	end

-- --- Fan Item Registration ---

	local function register_hauchiwa_fan(itemname, def)
	local tier = def.tier
local HAUCHIWA_CLICK_SOUND = "mcl_lun_items_se_option"
	local function fire_projectile(user)
		if not fan_ready(user) then
			return
		end
		if user then
			core.sound_play(HAUCHIWA_CLICK_SOUND, {
				pos = user:get_pos(),
				gain = 0.7,
				max_hear_distance = 32,
			}, true)
		end
		if rawget(_G, "mcl_lun_items_launch_hauchiwa_projectile") then
			mcl_lun_items_launch_hauchiwa_projectile(user)
		end
		play_hauchiwa_attack_animation(user)
	end
	core.register_tool(itemname, {
			description = def.description or "Hauchiwa Fan",
			_tt_help = "Right-click while gliding as a Crow Tengu to boost",
			_doc_items_longdesc = "A tengu fan that channels burst winds while gliding.",
			inventory_image = "hauchiwa_fan.png",
			wield_image = "hauchiwa_fan.png",
		wield_scale = { x = 1.5, y = 1.5, z = 1.5 },
		stack_max = 1,
		groups = {stick = 1, flammable = 2, tool = 1, handy = 1},
		_mcl_toollike_wield = true,
		sound = {breaks = "default_tool_breaks"},
		on_use = function(stack, user, pointed_thing)
			fire_projectile(user)
			return stack
		end,
		on_secondary_use = function(stack, user, pointed_thing)
			fire_projectile(user)
			return stack
		end,
		tool_capabilities = {
			full_punch_interval = 1.0, max_drop_level = 0, uses = 200,
			time = {[1]=3.0, [2]=3.0, [3]=3.0}, damage_groups = {fleshy = 1}
		},
	})
end

register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan", {description="Weak Hauchiwa Fan", tier="weak"})
register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan_normal", {description="Normal Hauchiwa Fan", tier="normal"})
register_hauchiwa_fan("mcl_lun_races:hauchiwa_fan_greater", {description="Greater Hauchiwa Fan", tier="greater"})

-- Crafts & Inventory Hooks for Fans
core.register_on_craft(function(itemstack)
	if not itemstack or itemstack:is_empty() then return itemstack end
	return ensure_fan_stack_initialized(itemstack)
end)

local function refresh_inventory_fan(inv, listname, index)
	if not inv or not listname or not index then return end
	local stack = inv:get_stack(listname, index)
	if stack:is_empty() then return end
	inv:set_stack(listname, index, ensure_fan_stack_initialized(stack))
end

core.register_on_player_inventory_action(function(player, action, inventory, info)
	if not inventory or type(info) ~= "table" then return end
	local function handle(listname, index)
		if listname and index then refresh_inventory_fan(inventory, listname, index) end
	end
	if action == "put" or action == "take" then
		handle(info.list, info.index)
	elseif action == "move" then
		handle(info.from_list, info.from_index)
		handle(info.to_list, info.to_index)
	end
	if action == "move" then -- Also check source
		handle(info.from_list, info.from_index) 
	end
end)

if core.register_on_item_drop then
	core.register_on_item_drop(function(player, itemstack, dropper)
		if not itemstack or itemstack:is_empty() then return itemstack end
		return ensure_fan_stack_initialized(itemstack)
	end)
end

-- --- Commands & Callbacks ---

core.register_chatcommand("reroll", {
	description = "Re-roll your race",
	func = function(name)
		local player = core.get_player_by_name(name)
		if not player then return false, "Player not found." end
		local meta = player:get_meta()
		local race = Registry.roll()
		local rname = race.name
		meta:set_string(KB_RACE, rname)
		meta:set_string("race", rname)
		meta:set_string(KB_SKIN, "") -- Clear skin to force re-roll
		apply_race_full(player, rname)
		core.chat_send_player(name, "Race re-rolled to: " .. rname)
		return true
	end
})

core.register_on_joinplayer(function(player)
	core.after(0, function()
		ensure_player_race(player)
		local inv = player:get_inventory()
		if inv then
			for _, list in ipairs({"main", "craft", "hand"}) do
				for i=1, inv:get_size(list) do refresh_inventory_fan(inv, list, i) end
			end
		end
	end)
end)

core.register_globalstep(function(dtime)
	-- Periodic inventory refresh for fans? Original had it every 1s.
	-- We'll keep it simple to avoid lag, relying on hooks mostly.
end)

core.register_on_leaveplayer(function(player)
	crow_last_boost[player:get_player_name()] = nil
end)

mcl_player.register_on_visual_change(function(player)
	local rname = races_api.get_race(player)
    local race = Registry.get(rname)
	if race then
		race:apply_visuals(player)
		race:apply_capabilities(player)
	end
end)

-- Initialize fan refresh timer if strictly needed, mimicking original:
local fan_refresh_timer = 0
core.register_globalstep(function(dtime)
	fan_refresh_timer = fan_refresh_timer + dtime
	if fan_refresh_timer < 1 then return end
	fan_refresh_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local inv = player:get_inventory()
		if inv then
			for _, list in ipairs({"main", "hand"}) do
				for i=1, inv:get_size(list) do refresh_inventory_fan(inv, list, i) end
			end
		end
	end
end)

return races_api
