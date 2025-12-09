local S = minetest.get_translator("mcl_lun_items")
local mcl_enchanting = rawget(_G, "mcl_enchanting")
local mcl_util = rawget(_G, "mcl_util")
local mcl_burning = rawget(_G, "mcl_burning")
local wielded_light = rawget(_G, "wielded_light")
local prefix_api = rawget(_G, "mcl_lun_prefixes")

local ROD_SPEED = 25
local ROD_MAX_LIFE = 6
local ROD_MAX_BOUNCES = 3
local ROD_FIRE_COOLDOWN = 0.4
local ROD_META_KEY = "mcl_lun_items:rarity_init"
local ORB_ROTATION_SPEED = math.rad(35)

local rod_variants = {
	{
		name = "mcl_lun_items:purification_rod",
		description = S("Dusty Purification Rod"),
		base_description = S("Purification Rod"),
		prefix = "dusty",
		light_level = 4,
		damage = 3,
	},
	{
		name = "mcl_lun_items:purification_rod_normal",
		description = S("Normal Purification Rod"),
		base_description = S("Purification Rod"),
		prefix = "normal",
		light_level = 5,
		damage = 5,
	},
	{
		name = "mcl_lun_items:purification_rod_legendary",
		description = S("Legendary Purification Rod"),
		base_description = S("Purification Rod"),
		prefix = "legendary",
		light_level = 6,
		damage = 7,
	},
}

local rod_index = {}
for _, def in ipairs(rod_variants) do
	rod_index[def.name] = def
end

local orb_variants = {
	{
		name = "mcl_lun_items:yin_yang_orb_precision",
		description = S("Yin Yang Orb - Precision"),
		texture = "yin_yang_orb_inventory.png",
		groups = {misc = 1},
		light_level = 6,
		damage = 2,
	},
	{
		name = "mcl_lun_items:yin_yang_orb_homing",
		description = S("Yin Yang Orb - Homing"),
		texture = "yin_yang_orb_inventory_purple.png",
		groups = {misc = 1},
		light_level = 6,
		damage = 2,
	},
	{
		name = "mcl_lun_items:yin_yang_orb_bouncing",
		description = S("Yin Yang Orb - Bouncing"),
		texture = "yin_yang_orb_inventory_green.png",
		groups = {misc = 1},
		light_level = 6,
		damage = 2,
	},
}

local ammo_definitions = {
	["mcl_lun_items:yin_yang_orb_precision"] = {
		type = "precision",
		rotation_multiplier = 1,
		gravity = 0,
		bounce_damping = 1,
		model_texture = "yin_yang_orb.png",
		damage = 2,
	},
	["mcl_lun_items:yin_yang_orb_homing"] = {
		type = "homing",
		rotation_multiplier = 1,
		gravity = 0,
		bounce_damping = 1,
		model_texture = "yin_yang_orb_purple.png",
		damage = 2,
	},
	["mcl_lun_items:yin_yang_orb_bouncing"] = {
		type = "bouncing",
		rotation_multiplier = 2,
		gravity = -12,
		bounce_damping = 0.7,
		extra_vertical = 2,
		model_texture = "yin_yang_orb_green.png",
		damage = 2,
	},
}
local ammo_priority = {
	"mcl_lun_items:yin_yang_orb_precision",
	"mcl_lun_items:yin_yang_orb_homing",
	"mcl_lun_items:yin_yang_orb_bouncing",
}

local ammo_labels = {
	["mcl_lun_items:yin_yang_orb_precision"] = S("Precision"),
	["mcl_lun_items:yin_yang_orb_homing"] = S("Precision"),
	["mcl_lun_items:yin_yang_orb_bouncing"] = S("Bouncing"),
}

local player_selected_ammo = {}
local ITEM_STATS = {}
_G.mcl_lun_items_item_stats = ITEM_STATS

local DEFAULT_LIGHT = 3

local function register_item_light(name, level)
	if not name or not wielded_light or not wielded_light.register_item_light then
		return
	end
	local val = level or DEFAULT_LIGHT
	wielded_light.register_item_light(name, val, false)
end

local function consume_orb_ammo(user)
	if not user or not user:is_player() then
		return nil
	end
	local inv = user:get_inventory()
	if not inv then
		return nil
	end
	local name = user:get_player_name()
	local preferred = player_selected_ammo[name]
	local creative = false
	if core.is_creative_enabled and name and name ~= "" then
		creative = core.is_creative_enabled(name)
	end
	local function take(name_to_take)
		local size = inv:get_size("main")
		for idx = 1, size do
			local stack = inv:get_stack("main", idx)
			if stack and stack:get_name() == name_to_take then
				player_selected_ammo[name] = name_to_take
				if not creative then
					stack:take_item(1)
					inv:set_stack("main", idx, stack)
				end
				return true
			end
		end
		return false
	end
	if preferred and ammo_definitions[preferred] and take(preferred) then
		return ammo_definitions[preferred], preferred
	end
	for _, name in ipairs(ammo_priority) do
		if take(name) then
			return ammo_definitions[name], name
		end
	end
	return nil
end

local function is_yin_yang_orb(name)
	return name and name:find("mcl_lun_items:yin_yang_orb_", 1, true) == 1
end

local orb_drop_cfg = {
	color = "#9e9e9e",
	texture = "mcl_particles_bonemeal.png",
	radius = 0.25,
	glow = 6,
	height = 1.2,
}

local particle_settings = {
    ["mcl_lun_items:purification_rod_normal"] = {color = "#a0d1ff"},
    ["mcl_lun_items:purification_rod_legendary"] = {color = "#eb9f9f"},
    ["mcl_lun_races:hauchiwa_fan_normal"] = {color = "#a347ff"},
    ["mcl_lun_races:hauchiwa_fan_greater"] = {color = "#ffb347"},
}

local fan_tier_particle_names = {
    normal = "mcl_lun_races:hauchiwa_fan_normal",
    greater = "mcl_lun_races:hauchiwa_fan_greater",
}

local function build_particle_cfg(entry)
    if not entry then
        return nil
    end
    return {
        color = entry.color,
        texture = orb_drop_cfg.texture,
        radius = orb_drop_cfg.radius,
        glow = orb_drop_cfg.glow,
        height = orb_drop_cfg.height,
    }
end

local function particle_cfg_for_stack(stack)
    if not stack then
        return nil
    end
    if stack:is_empty() then
        return nil
    end
    local cfg = particle_settings[stack:get_name()]
    if cfg then
        return build_particle_cfg(cfg)
    end
    local tier = stack:get_meta():get_string("mcl_lun_races:fan_tier")
    local fallback_name = tier and fan_tier_particle_names[tier]
    if fallback_name then
        return build_particle_cfg(particle_settings[fallback_name])
    end
    return nil
end

local DEFAULT_MOD_LIGHT = 3
local ROD_DURABILITY = 300
local light_schema = {
	["mcl_lun_items:purification_rod"] = 4,
	["mcl_lun_items:purification_rod_normal"] = 5,
	["mcl_lun_items:purification_rod_legendary"] = 6,
}
for _, orb in ipairs(orb_variants) do
	light_schema[orb.name] = 4
end

local function get_mod_light(name)
	return light_schema[name] or DEFAULT_MOD_LIGHT
end

local extra_light_items = {
	["mcl_lun_races:hauchiwa_fan"] = 5,
	["mcl_lun_races:hauchiwa_fan_normal"] = 5,
	["mcl_lun_races:hauchiwa_fan_greater"] = 6,
}

local function register_schema_lighting()
	if not wielded_light or not wielded_light.register_item_light then
		return
	end
	for name, level in pairs(light_schema) do
		register_item_light(name, level or DEFAULT_LIGHT)
	end
	for name, level in pairs(extra_light_items) do
		register_item_light(name, level)
	end
end

local function cycle_ammo_type(itemstack, user, pointed_thing)
	if not user or not user:is_player() then
		return itemstack
	end
	local inv = user:get_inventory()
	if not inv then
		return itemstack
	end
	local name = user:get_player_name()
	local available = {}
	for _, ammo in ipairs(ammo_priority) do
		if inv:contains_item("main", ItemStack(ammo)) then
			available[#available + 1] = ammo
		end
	end
	if #available == 0 then
		minetest.chat_send_player(name, S("No Yin-Yang Orbs available."))
		return itemstack
	end
	local current = player_selected_ammo[name]
	local next_idx = 1
	for idx, ammo in ipairs(available) do
		if ammo == current then
			next_idx = idx % #available + 1
			break
		end
	end
	local selected = available[next_idx]
	player_selected_ammo[name] = selected
	minetest.chat_send_player(name, S("Selected ammo: @1", ammo_labels[selected] or selected))
	return itemstack
end

local function cycle_ammo_on_place(itemstack, placer, pointed_thing)
	if mcl_util and mcl_util.call_on_rightclick and pointed_thing and pointed_thing.type == "node" then
		local rc = mcl_util.call_on_rightclick(itemstack, placer, pointed_thing)
		if rc then
			return rc
		end
	end
	return cycle_ammo_type(itemstack, placer, pointed_thing)
end

local rod_tooltip_map = {}
for _, def in ipairs(rod_variants) do
	rod_tooltip_map[def.name] = def
end

local function current_ammo_label(player)
	local inv = player and player:get_inventory()
	if not inv then
		return nil
	end
	for _, name in ipairs(ammo_priority) do
		if inv:contains_item("main", ItemStack(name)) then
			return ammo_labels[name]
		end
	end
	return nil
end

local function build_rod_description(def, ammo_label)
	local base = def.description or S("Purification Rod")
	local ammo_text = ammo_label or S("No Yin-Yang Orbs")
	local desc = ("%s (%s)"):format(base, ammo_text)
	if def.durability and def.durability > 0 then
		desc = desc .. "\n" .. S("Durability: @1 uses", def.durability)
	end
	return desc
end

local tooltip_timer = 0
core.register_globalstep(function(dtime)
	tooltip_timer = tooltip_timer + dtime
	if tooltip_timer < 1 then
		return
	end
	tooltip_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local ammo_label = current_ammo_label(player)
		local inv = player:get_inventory()
		if not inv then
			goto continue_tooltip
		end
		for _, listname in ipairs({"main", "hand", "craft"}) do
			local list = inv:get_list(listname)
			if not list then
				goto continue_list
			end
			for idx, stack in ipairs(list) do
				local def = rod_tooltip_map[stack:get_name()]
				if def then
					local meta = stack:get_meta()
					local desired = build_rod_description(def, ammo_label)
					if meta:get_string("description") ~= desired then
						meta:set_string("description", desired)
						inv:set_stack(listname, idx, stack)
					end
				end
			end
			::continue_list::
		end
		::continue_tooltip::
	end
end)

local rod_cooldowns = {}

local function rod_ready(user)
	local name = user and user:get_player_name()
	if not name or name == "" then
		return true
	end
	local now = core.get_gametime()
	local next_allowed = rod_cooldowns[name] or 0
	if now < next_allowed then
		return false
	end
	rod_cooldowns[name] = now + ROD_FIRE_COOLDOWN
	return true
end

local function spawn_purification_orb(user, stack_table, ammo_def, ammo_name, rod_stats)
	if not user or not user:is_player() then
		return
	end
	local pos = user:get_pos()
	if not pos then
		return
	end
	local dir = user:get_look_dir()
	local spawn = vector.add(pos, vector.multiply(dir, 0.8))
	spawn.y = spawn.y + 1.5
	minetest.log("action", "[purif] spawn at "..minetest.pos_to_string(spawn).." dir "..minetest.serialize(dir))
	core.sound_play("mcl_lun_items_se_plst00", {pos = spawn, gain = 0.4, max_hear_distance = 16}, true)
	local obj = minetest.add_entity(spawn, "mcl_lun_items:purification_rod_projectile")
	if obj then
		local lua = obj:get_luaentity()
		if lua and lua.initialize then
			local stack
			if stack_table then
				stack = ItemStack(stack_table)
			end
			lua:initialize(user, stack, dir, ammo_def, ammo_name, rod_stats)
		end
	end
end

if wielded_light and wielded_light.register_item_light then
	-- Dummy item identifier used purely for wielded_light tracking
	wielded_light.register_item_light("mcl_lun_items:purification_rod_orb_light", 12, false)
	wielded_light.register_item_light("mcl_lun_items:yin_yang_orb_drop_light", 6, false)
end

register_schema_lighting()

local orb_particle_textures = {
	"touhou_particle_red_32x_1.png",
	"touhou_particle_red_32x_2.png",
	"touhou_particle_red_32x_3.png",
	"touhou_particle_red_32x_4.png",
	"touhou_particle_red_32x_5.png",
	"touhou_particle_red_32x_6.png",
	"touhou_particle_red_32x_7.png",
	"touhou_particle_red_32x_8.png",
}

local ORB_DROP_REFRESH = 0.25
local orb_drop_timer = 0
local function is_purification_rod(name)
	return name and rod_index[name] ~= nil
end

local function ensure_purification_stack(stack)
	if not stack or stack:is_empty() or not is_purification_rod(stack:get_name()) then
		return stack
	end
	local variant = rod_index[stack:get_name()]
	if prefix_api and variant then
		local has_prefix = true
		if prefix_api.list_prefixes then
			has_prefix = false
			for _, id in ipairs(prefix_api.list_prefixes(stack)) do
				if id == variant.prefix then
					has_prefix = true
					break
				end
			end
		end
		if not has_prefix and prefix_api.apply_prefix and variant.prefix then
			stack = prefix_api.apply_prefix(stack, variant.prefix)
		end
		if prefix_api.set_extra_lines then
			prefix_api.set_extra_lines(stack, {
				S("Triple yin-yang volley (0.15s spacing)"),
				S("Bounces: @1", ROD_MAX_BOUNCES),
				S("Lifetime: @1s", ROD_MAX_LIFE),
			})
		end
	end
	stack:get_meta():set_string(ROD_META_KEY, "1")
	return stack
end

local function refresh_purification_stack(inv, listname, index)
	if not inv or not listname or not index then
		return
	end
	local stack = inv:get_stack(listname, index)
	if stack:is_empty() or not is_purification_rod(stack:get_name()) then
		return
	end
	local updated = ensure_purification_stack(stack)
	inv:set_stack(listname, index, updated)
end

core.register_on_player_inventory_action(function(player, action, inventory, info)
	if not inventory or type(info) ~= "table" then
		return
	end
	local function handle(listname, index)
		if listname and index then
			refresh_purification_stack(inventory, listname, index)
		end
	end
	if action == "move" then
		handle(info.from_list, info.from_index)
		handle(info.to_list, info.to_index)
	elseif action == "put" or action == "take" then
		handle(info.list, info.index)
	end
end)

local function initialize_purification_inventory(player)
	local inv = player and player:get_inventory()
	if not inv then
		return
	end
	for _, listname in ipairs({"main", "craft", "hand"}) do
		local list = inv:get_list(listname)
		if list then
			for idx, stack in ipairs(list) do
				if not stack:is_empty() and is_purification_rod(stack:get_name()) then
					inv:set_stack(listname, idx, ensure_purification_stack(stack))
				end
			end
		end
	end
end

core.register_on_craft(function(itemstack)
	if itemstack and not itemstack:is_empty() and is_purification_rod(itemstack:get_name()) then
		itemstack = ensure_purification_stack(itemstack)
	end
	return itemstack
end)

if core.register_on_item_drop then
	core.register_on_item_drop(function(player, itemstack, dropper)
		if not itemstack or itemstack:is_empty() then
			return itemstack
		end
		if is_purification_rod(itemstack:get_name()) then
			itemstack = ensure_purification_stack(itemstack)
		end
		return itemstack
	end)
end

core.register_on_joinplayer(function(player)
	initialize_purification_inventory(player)
end)

local inv_refresh_timer = 0
core.register_globalstep(function(dtime)
	inv_refresh_timer = inv_refresh_timer + dtime
	if inv_refresh_timer < 1 then
		return
	end
	inv_refresh_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		initialize_purification_inventory(player)
	end
end)

local function play_snowball_effect(pos)
	if not pos then
		return
	end
	core.sound_play("mcl_lun_items_se_kira00", {pos = pos, gain = 0.9, max_hear_distance = 16}, true)
	for _, tex in ipairs(orb_particle_textures) do
		core.add_particlespawner({
			amount = 3,
			time = 0.1,
			minpos = pos,
			maxpos = pos,
			minvel = {x = -1, y = -1, z = -1},
			maxvel = {x = 1, y = 1, z = 1},
			minsize = 1,
			maxsize = 2,
			glow = 8,
			texture = tex,
		})
	end
	if wielded_light then
		minetest.add_entity(pos, "mcl_lun_items:purification_rod_explosion_light")
	end
end

local function spawn_particles_at(pos, cfg, opts)
	if not pos or not cfg then
		return
	end
	local radius = (opts and opts.radius) or cfg.radius or 0.2
	local texture = (opts and opts.texture) or cfg.texture or "mcl_particles_bonemeal.png"
	if cfg.color then
		texture = texture .. "^[colorize:" .. cfg.color .. ":180"
	end
	local height = (opts and opts.height) or cfg.height or 1
	local amount = (opts and opts.amount) or math.floor(6 + height * 4)
	core.add_particlespawner({
		amount = amount,
		time = 0.15,
		minpos = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
		maxpos = {x = pos.x + radius, y = pos.y + height, z = pos.z + radius},
		minvel = {x = 0, y = 0.5, z = 0},
		maxvel = {x = 0, y = 0.9, z = 0},
		minsize = 0.3,
		maxsize = 0.5,
		glow = cfg.glow or 6,
		texture = texture,
	})
end

local function spawn_orb_drop_particles(obj, cfg)
	if not obj then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end
	local stack = obj:get_luaentity() and ItemStack(obj:get_luaentity().itemstring or "")
	local cfg = stack and particle_cfg_for_stack(stack)
	if not cfg then
		return
	end
	minetest.log("action", "[mcl_lun_items] orb drop particle for "..stack:get_name())
	spawn_particles_at(pos, cfg)
	if cfg.glow and obj.set_properties and obj:get_luaentity() then
		obj:set_properties({glow = cfg.glow})
	end
end

core.register_globalstep(function(dtime)
	if orb_drop_timer < ORB_DROP_REFRESH then
		orb_drop_timer = orb_drop_timer + dtime
		return
	end
	orb_drop_timer = 0
	local processed = {}
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		if not ppos then
			goto continue_player
		end
		for _, obj in ipairs(core.get_objects_inside_radius(ppos, 20)) do
			if obj and not processed[obj] then
				processed[obj] = true
				local ent = obj:get_luaentity()
				if ent and ent.name == "__builtin:item" then
					local stack = ItemStack(ent.itemstring or "")
					if not stack:is_empty() then
						local cfg = particle_cfg_for_stack(stack)
						if cfg and not ent._mcl_lun_items_orb_particles_spawned then
							if wielded_light and wielded_light.track_item_entity and not ent._mcl_lun_items_orb_light then
								wielded_light.track_item_entity(obj, "orb_drop", "mcl_lun_items:yin_yang_orb_drop_light")
								ent._mcl_lun_items_orb_light = true
							end
							spawn_orb_drop_particles(obj, orb_drop_cfg)
							ent._mcl_lun_items_orb_particles_spawned = true
						end
					end
				end
			end
		end
	::continue_player::
	end
end)


local wield_particle_timer = 0
local function wield_particle_position(player)
	local pos = player:get_pos()
	if not pos then
		return
	end
	local dir = player:get_look_dir()
	local up = {x = 0, y = 1, z = 0}
	local right = vector.cross(up, dir)
	right = vector.normalize(right)
	local forward = vector.multiply(dir, 0.4)
	local right_offset = vector.multiply(right, 0.3)
	local target = vector.add(pos, vector.add(forward, right_offset))
	target.y = target.y + 0.8
	return target
end

core.register_globalstep(function(dtime)
	wield_particle_timer = wield_particle_timer + dtime
	if wield_particle_timer < 0.25 then
		return
	end
	wield_particle_timer = 0
	for _, player in ipairs(core.get_connected_players()) do
		local stack = player:get_wielded_item()
		if stack and not stack:is_empty() then
			local cfg = particle_cfg_for_stack(stack)
			if cfg then
				local pos = wield_particle_position(player)
				if pos then
					minetest.log("action", "[mcl_lun_items] wield particle for "..stack:get_name())
					local height = cfg.height or 1
					local wield_opts = {
						radius = (cfg.radius or 0.2) * 0.4,
						amount = math.floor(height),
						height = height * 0.6,
					}
					spawn_particles_at(pos, cfg, wield_opts)
				end
			else
				minetest.log("action", "[mcl_lun_items] no particle cfg for wielded "..stack:get_name())
			end
		end
	end
end)

local function purification_shoot(stack, user, pointed_thing)
	if not user then
		return stack
	end
	if not rod_ready(user) then
		return stack
	end
	stack = ensure_purification_stack(stack)
	local ammo, ammo_name = consume_orb_ammo(user)
	if not ammo then
		if user and user:get_player_name() then
			minetest.chat_send_player(user:get_player_name(), S("No Yin-Yang orbs available."))
		end
		return stack
	end
	core.sound_play("mcl_lun_items_se_option", {
		pos = user:get_pos(),
		gain = 0.6,
		max_hear_distance = 16,
	}, true)
	local stack_table = stack and stack:to_table() or nil
	local stats = stack_table and ITEM_STATS[stack_table.name]
	spawn_purification_orb(user, stack_table, ammo, ammo_name, stats)
	minetest.after(0.15, function()
		spawn_purification_orb(user, stack_table, ammo, ammo_name, stats)
	end)
	minetest.after(0.30, function()
		spawn_purification_orb(user, stack_table, ammo, ammo_name, stats)
	end)
	if not core.is_creative_enabled(user:get_player_name()) then
		stack:add_wear_by_uses(300)
	end
	return stack
end

local function register_mcl_lun_item(def)
	if not def or not def.name then
		return
	end
	local kind = def.kind or "tool"
	local light_level = def.light_level or DEFAULT_LIGHT
	register_item_light(def.name, light_level)
	if kind == "tool" then
		local desc = def.description or S("Purification Rod")
		if def.durability and def.durability > 0 then
			desc = ("%s\n%s"):format(desc, S("Durability: @1 uses", def.durability))
		end
		local tool_caps = def.tool_capabilities or {
				full_punch_interval = 1.0,
				max_drop_level = 0,
				groupcaps = {
					swordy = {times = {[1]=1.6, [2]=1.6, [3]=1.6}, uses = 300, maxlevel = 1},
					swordy_cobweb = {times = {[1]=0.5}, uses = 300, maxlevel = 1},
					swordy_bamboo = {times = {[1]=0.3}, uses = 300, maxlevel = 1},
				},
				damage_groups = def.damage_groups or {fleshy = 6},
			}
		minetest.register_tool(def.name, {
			description = desc,
			mcl_lun_base_description = def.base_description or def.description or S("Purification Rod"),
			_doc_items_longdesc = def.longdesc or S("A ceremonial wand."),
			inventory_image = def.inventory_image or "gohei.png",
			wield_image = def.wield_image or def.inventory_image or "gohei.png",
			wield_scale = def.wield_scale or {x = 2, y = 2, z = 2},
			stack_max = def.stack_max or 1,
			light_source = light_level,
			groups = def.groups or {tool = 1, weapon = 1, sword = 1, handy = 1, stick = 1, flammable = 1},
			_mcl_toollike_wield = def.mcl_toollike_wield ~= false,
			_mcl_uses = def.uses or def.durability or ROD_DURABILITY,
			sound = def.sound or {breaks = "default_tool_breaks"},
			tool_capabilities = tool_caps,
			on_secondary_use = def.on_secondary_use,
			on_place = def.on_place,
			on_use = def.on_use,
		})
	else
		minetest.register_craftitem(def.name, {
			description = def.description or def.name,
			inventory_image = def.texture or def.inventory_image,
			stack_max = def.stack_max or 16,
			groups = def.groups or {misc = 1},
			light_source = light_level,
		})
	end
	ITEM_STATS[def.name] = {damage = def.damage}
end

for _, orb in ipairs(orb_variants) do
	orb.kind = "craftitem"
	orb.light_level = orb.light_level or DEFAULT_LIGHT
	register_mcl_lun_item(orb)
end

	for _, variant in ipairs(rod_variants) do
		variant.kind = "tool"
		variant.durability = variant.durability or ROD_DURABILITY
		variant.uses = variant.uses or ROD_DURABILITY
		variant.light_level = variant.light_level or DEFAULT_LIGHT
		variant.inventory_image = variant.inventory_image or "gohei.png"
		variant.wield_image = variant.wield_image or variant.inventory_image
		variant.groups = variant.groups or {tool = 1, weapon = 1, sword = 1, handy = 1, stick = 1, flammable = 1}
		variant.tool_capabilities = variant.tool_capabilities or {
			full_punch_interval = 1.0,
			max_drop_level = 0,
			groupcaps = {
				swordy = {times = {[1]=1.6, [2]=1.6, [3]=1.6}, uses = 300, maxlevel = 1},
				swordy_cobweb = {times = {[1]=0.5}, uses = 300, maxlevel = 1},
				swordy_bamboo = {times = {[1]=0.3}, uses = 300, maxlevel = 1},
			},
			damage_groups = variant.damage_groups or {fleshy = 6},
		}
		variant.on_use = purification_shoot
		variant.on_secondary_use = cycle_ammo_type
		variant.on_place = cycle_ammo_on_place
		register_mcl_lun_item(variant)
	end

local purification_projectile = {
	initial_properties = {
		physical = false,
		collide_with_objects = true,
		collisionbox = {0, 0, 0, 0, 0, 0},
		pointable = false,
		visual = "mesh",
		mesh = "mcl_lun_items_purification_orb.obj",
		textures = {"yin_yang_orb.png"},
		visual_size = {x = 4.0, y = 4.0},
		glow = 8,
		automatic_rotate = 0,
		backface_culling = false,
		pointlight = {
			radius = 6,
			intensity = 0.5,
			color = "#eb9f9f",
		},
	},
	velocity = {x = 0, y = 0, z = 0},
	last_pos = nil,
	lifetime = 0,
	max_life = ROD_MAX_LIFE,
	bounces_left = ROD_MAX_BOUNCES,
	shooter = nil,
	shooter_name = "",
	ignore_until = 0,
	damage = 2,
	knockback = 0,
	flame = false,
	rotation_angle = 0,
	base_pitch = 0,
	base_yaw = 0,
	last_node_hit = nil,
	last_node_time = 0,
	left_shooter = false,
}

function purification_projectile:initialize(user, stack, dir, ammo_def, ammo_name, rod_stats)
	self.shooter = user
	self.shooter_name = user:get_player_name() or ""
	self.ignore_until = core.get_gametime() + 0.2
	self.velocity = vector.multiply(dir, ROD_SPEED)
	self.object:set_velocity(self.velocity)
	self.object:set_yaw(user:get_look_horizontal() or 0)
	self.last_pos = self.object:get_pos()
	self.lifetime = 0
	self.bounces_left = ROD_MAX_BOUNCES
	self.max_life = ROD_MAX_LIFE
	local rod_damage = (rod_stats and rod_stats.damage) or 0
	local orb_damage = (ammo_def and ammo_def.damage) or 0
	self.damage = rod_damage + orb_damage
	self.knockback = 0
	self.flame = false
	self.rotation_angle = 0
	local dir = user:get_look_dir()
	local horiz = math.sqrt(dir.x * dir.x + dir.z * dir.z)
	local pitch = math.atan2(dir.y, horiz)
	local yaw = math.atan2(dir.z, dir.x)
	self.base_pitch = -pitch
	self.base_yaw = yaw + math.pi / 2
	self.object:set_rotation({x = self.base_pitch, y = self.base_yaw, z = 0})
	self.left_shooter = false
	self.ammo = ammo_def or ammo_definitions["mcl_lun_items:yin_yang_orb_precision"]
	self.ammo_name = ammo_name
	self.rotation_rate = ORB_ROTATION_SPEED * (self.ammo.rotation_multiplier or 1)
	self.gravity_accel = self.ammo.gravity or 0
	self.is_bouncing = self.ammo.type == "bouncing"
	self.bounce_damping = self.ammo.bounce_damping or 1
	local tex = self.ammo.model_texture or "yin_yang_orb.png"
	if tex and self.object and self.object.set_properties then
		self.object:set_properties({textures = {tex}})
	end

	if stack and mcl_enchanting and mcl_enchanting.get_enchantments then
		local ench = mcl_enchanting.get_enchantments(stack)
		if ench then
			if ench.power then
				self.damage = self.damage + (ench.power / 2) + 0.5
			end
			if ench.punch then
				self.knockback = ench.punch
			end
			if ench.flame then
				self.flame = true
			end
		end
	end
	if wielded_light and wielded_light.track_item_entity then
		wielded_light.track_item_entity(self.object, "purification_orb", "mcl_lun_items:purification_rod_orb_light")
	end
end

local function reflect_velocity(vel, normal)
	normal = vector.normalize(normal)
	local dot = vel.x * normal.x + vel.y * normal.y + vel.z * normal.z
	return {
		x = vel.x - 2 * dot * normal.x,
		y = vel.y - 2 * dot * normal.y,
		z = vel.z - 2 * dot * normal.z,
	}
end

local function should_ignore(self, obj)
	if not obj then
		return true
	end
	if obj == self.shooter and (self.ignore_until >= core.get_gametime() or not self.left_shooter) then
		minetest.log("action", "[purif] ignoring shooter (left="..tostring(self.left_shooter)..")")
		return true
	end
	return false
end

function purification_projectile:get_reason()
	return {
		type = "projectile",
		source = self.shooter,
		direct = self.object,
	}
end

function purification_projectile:explode(pos)
	minetest.log("action", "[purif] explode at "..minetest.pos_to_string(pos or self.object:get_pos()))
	play_snowball_effect(pos or self.object:get_pos())
	self.object:remove()
end

local function round_pos(pos)
	if not pos then
		return nil
	end
	return {
		x = math.floor(pos.x + 0.5),
		y = math.floor(pos.y + 0.5),
		z = math.floor(pos.z + 0.5),
	}
end

local function pos_equal(a, b)
	if not a or not b then
		return false
	end
	return a.x == b.x and a.y == b.y and a.z == b.z
end

function purification_projectile:bounce(normal, hitpos)
	minetest.log("action", "[purif] bounce normal "..minetest.serialize(normal).." remaining "..self.bounces_left)
	self.bounces_left = self.bounces_left - 1
	self.velocity = reflect_velocity(self.velocity, normal or {x = 0, y = 1, z = 0})
	if self.is_bouncing then
		local damp = self.bounce_damping or 1
		self.velocity = vector.multiply(self.velocity, damp)
		local extra_y = self.ammo.extra_vertical or 0
		if extra_y > 0 then
			self.velocity.y = self.velocity.y + extra_y
		end
		local variation = 1 + (math.random() * 0.1 - 0.05)
		self.velocity = vector.multiply(self.velocity, variation)
	end
	self.object:set_velocity(self.velocity)
	if hitpos and normal then
		self.object:set_pos(vector.add(hitpos, vector.multiply(normal, 0.05)))
	elseif hitpos then
		self.object:set_pos(hitpos)
	end
	core.sound_play("mcl_lun_items_se_graze", {pos = hitpos or self.object:get_pos(), gain = 0.4, max_hear_distance = 16}, true)
	self.last_node_hit = round_pos(hitpos or self.object:get_pos())
	self.last_node_time = core.get_gametime()
end

local function axis_to_normal(axis)
	if axis == "x+" then return {x = 1, y = 0, z = 0} end
	if axis == "x-" then return {x = -1, y = 0, z = 0} end
	if axis == "y+" then return {x = 0, y = 1, z = 0} end
	if axis == "y-" then return {x = 0, y = -1, z = 0} end
	if axis == "z+" then return {x = 0, y = 0, z = 1} end
	if axis == "z-" then return {x = 0, y = 0, z = -1} end
	return nil
end

local function is_walkable(pos)
	local node = core.get_node_or_nil(pos)
	if not node then
		return false
	end
	local def = core.registered_nodes[node.name]
	return def and def.walkable
end

function purification_projectile:hit_entity(obj, hitpos)
	if not obj or should_ignore(self, obj) then
		return
	end
	minetest.log("action", "[purif] hit entity "..(obj:get_luaentity() and obj:get_luaentity().name or "unknown").." pos "..minetest.pos_to_string(hitpos or obj:get_pos()))
	local lua = obj:get_luaentity()
	if lua and lua._hittable_by_projectile == false then
		return
	end
	mcl_util.deal_damage(obj, self.damage, self:get_reason())
	if self.knockback > 0 and obj.add_velocity then
		obj:add_velocity(vector.multiply(vector.normalize(self.velocity), self.knockback * 2))
	end
	if self.flame and mcl_burning then
		mcl_burning.set_on_fire(obj, 5)
	end
	self:explode(hitpos)
end

function purification_projectile:on_step(dtime)
	local obj = self.object
	if not obj then
		return
	end
	local rate = self.rotation_rate or 0
	self.rotation_angle = (self.rotation_angle + rate * dtime) % (math.pi * 2)
	obj:set_rotation({x = self.base_pitch, y = self.base_yaw, z = self.rotation_angle})
	self.lifetime = self.lifetime + dtime
	if self.lifetime >= self.max_life then
		self:explode(obj:get_pos())
		return
	end
	local pos = obj:get_pos()
	if not pos then
		self:explode(self.last_pos)
		return
	end
	local last = self.last_pos or pos
	local collided = false
	local shooter_detected = false
	if self.gravity_accel and self.gravity_accel ~= 0 then
		self.velocity = vector.add(self.velocity, {x = 0, y = self.gravity_accel * dtime, z = 0})
	end
	local collided_pos = nil
	for hit in core.raycast(last, pos, true, true) do
		if hit.type == "object" then
			if hit.ref == self.shooter then
				shooter_detected = true
			end
			if hit.ref and hit.ref ~= obj and not should_ignore(self, hit.ref) then
				self:hit_entity(hit.ref, hit.intersection_point or pos)
				collided = true
				break
			end
		elseif hit.type == "node" then
			local under = hit.under
			if under and is_walkable(under) then
				minetest.log("action", "[purif] node hit at "..minetest.pos_to_string(under).." bounces_left="..self.bounces_left)
				local node_pos = under
				local rounded = round_pos(node_pos)
				local now = core.get_gametime()
				if rounded and self.last_node_hit and self.last_node_time and now - self.last_node_time < 0.08 and pos_equal(rounded, self.last_node_hit) then
					goto continue_hit
				end
				local normal = hit.intersection_normal or axis_to_normal(hit.axis) or vector.normalize(vector.subtract(hit.above, under))
				if self.bounces_left > 0 then
					self:bounce(normal, hit.intersection_point or hit.above or pos)
				else
					self:explode(hit.intersection_point or hit.above or pos)
				end
				collided = true
				collided_pos = (self.object and self.object:get_pos()) or self.last_pos
				break
			end
		end
	::continue_hit::
	end
	if not shooter_detected then
		if not self.left_shooter then
			self.left_shooter = true
			self.ignore_until = 0
		end
	end
	if not collided then
		obj:set_velocity(self.velocity)
		self.last_pos = pos
	else
		self.last_pos = collided_pos or self.object:get_pos() or self.last_pos
	end
end

minetest.register_entity("mcl_lun_items:purification_rod_projectile", purification_projectile)

local explosion_light = {
	initial_properties = {
		physical = false,
		pointable = false,
		visual = "sprite",
		textures = {"wieldhand.png"}, -- hidden via zero size
		visual_size = {x = 0, y = 0},
	},
	timer = 0,
	lifetime = 0.3,
}

function explosion_light:on_activate()
	self.timer = 0
	if wielded_light and wielded_light.track_item_entity then
		wielded_light.track_item_entity(self.object, "purification_explosion", "mcl_lun_items:purification_rod_orb_light")
	end
end

function explosion_light:on_step(dtime)
	self.timer = self.timer + dtime
	if self.timer >= (self.lifetime or 0.3) then
		self.object:remove()
	end
end

minetest.register_entity("mcl_lun_items:purification_rod_explosion_light", explosion_light)
