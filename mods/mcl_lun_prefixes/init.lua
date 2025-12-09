local api = {}
_G.mcl_lun_prefixes = api

local prefix_meta_key = "mcl_lun_prefixes:list"
local extra_meta_key = "mcl_lun_prefixes:extra"
local prefixes = {}
local prefix_particle_configs = {
	weak = {
		color = "#9e9e9e",
		texture = "mcl_particles_bonemeal.png",
		radius = 0.25,
		glow = 6,
		light = 2,
		color_desc = false,
	},
	normal = {
		color = "#ffffff",
		texture = "mcl_particles_bonemeal.png",
		radius = 0.18,
		glow = 10,
		light = 3,
		color_desc = false,
	},
	greater = {
		color = "#ff9147",
		texture = "mcl_particles_nether_portal.png",
		radius = 0.15,
		glow = 14,
		light = 4,
		color_desc = true,
	},
	dusty = {
		color = "#c7a07a",
		texture = "mcl_particles_bonemeal.png",
		radius = 0.25,
		glow = 7,
		light = 2,
		color_desc = false,
	},
	legendary = {
		color = "#ff6b6b",
		texture = "mcl_particles_nether_portal.png",
		radius = 0.2,
		glow = 15,
		light = 5,
		color_desc = true,
	},
}

local function sanitize_serialized(meta)
	local raw = meta:get_string(prefix_meta_key)
	if raw == "" then
		return {}
	end
	local ok = core.deserialize(raw)
	if type(ok) ~= "table" then
		return {}
	end
	local cleaned = {}
	for _, id in ipairs(ok) do
		if type(id) == "string" and prefixes[id] then
			cleaned[#cleaned + 1] = id
		end
	end
	return cleaned
end

local function sort_prefixes(list)
	table.sort(list, function(a, b)
		local da = prefixes[a] or {}
		local db = prefixes[b] or {}
		local wa = da.weight or 0
		local wb = db.weight or 0
		if wa == wb then
			return (da.label or a) < (db.label or b)
		end
		return wa > wb
	end)
end

local function read_extra_lines(meta)
	local raw = meta:get_string(extra_meta_key)
	if raw == "" then
		return {}
	end
	local ok = core.deserialize(raw)
	if type(ok) ~= "table" then
		return {}
	end
	local lines = {}
	for _, line in ipairs(ok) do
		if type(line) == "string" and line ~= "" then
			lines[#lines + 1] = line
		end
	end
	return lines
end

local function desc_has_prefix(desc, label)
	if not desc or desc == "" or not label or label == "" then
		return false
	end
	local desc_lower = desc:lower()
	local label_lower = label:lower()
	if desc_lower:sub(1, #label_lower) ~= label_lower then
		return false
	end
	local next_char = desc_lower:sub(#label_lower + 1, #label_lower + 1)
	return next_char == "" or next_char == " "
end

local function get_description_color(prefix_list)
	if not prefix_list then
		return nil
	end
	for _, id in ipairs(prefix_list) do
		local cfg = prefix_particle_configs[id]
		if cfg and cfg.color_desc and cfg.color then
			return cfg.color
		end
	end
	return nil
end

local function compose_description(stack, prefix_list, extra_lines)
	local def = core.registered_items[stack:get_name()]
	if not def or not def.description or def.description == "" then
		return
	end
	local base_desc = def.mcl_lun_base_description or def.description
	local color_hex = get_description_color(prefix_list)
	local labels = {}
	for _, id in ipairs(prefix_list or {}) do
		local pref = prefixes[id]
		if pref then
			local label = pref.label or id
			if label ~= "" and not desc_has_prefix(base_desc, label) then
				labels[#labels + 1] = label
			end
		end
	end
	local desc = base_desc
	if #labels > 0 then
		desc = table.concat(labels, " ") .. " " .. desc
	end
	if extra_lines and #extra_lines > 0 then
		desc = desc .. "\n" .. table.concat(extra_lines, "\n")
	end
	if color_hex and core.colorize then
		desc = core.colorize(color_hex, desc)
	end
	stack:get_meta():set_string("description", desc)
end

local function update_description(stack, prefix_list, extra_lines)
	local meta = stack:get_meta()
	compose_description(stack, prefix_list, extra_lines or read_extra_lines(meta))
end

function api.register_prefix(id, def)
	if type(id) ~= "string" or id == "" then
		return
	end
	def = def or {}
	prefixes[id] = {
		label = def.label or id,
		weight = def.weight or 0,
	}
end

function api.apply_prefix(stack, id)
	if not stack or stack:is_empty() then
		return stack
	end
	local pref = prefixes[id]
	if not pref then
		return stack
	end
	local meta = stack:get_meta()
	local list = sanitize_serialized(meta)
	local found = false
	for _, existing in ipairs(list) do
		if existing == id then
			found = true
			break
		end
	end
	if not found then
		list[#list + 1] = id
		sort_prefixes(list)
		meta:set_string(prefix_meta_key, core.serialize(list))
	end
	update_description(stack, list)
	return stack
end

function api.list_prefixes(stack)
	if not stack or stack:is_empty() then
		return {}
	end
	return sanitize_serialized(stack:get_meta())
end

function api.meta_key()
	return prefix_meta_key
end

function api.set_extra_lines(stack, lines)
	if not stack or stack:is_empty() then
		return
	end
	local meta = stack:get_meta()
	if lines and #lines > 0 then
		meta:set_string(extra_meta_key, core.serialize(lines))
	else
		meta:set_string(extra_meta_key, "")
	end
	update_description(stack, sanitize_serialized(meta), lines or {})
end

function api.get_extra_lines(stack)
	if not stack or stack:is_empty() then
		return {}
	end
	return read_extra_lines(stack:get_meta())
end

api.register_prefix("soulbound", { label = "Soulbound", weight = 10 })
api.register_prefix("legendary", { label = "Legendary", weight = 9 })
api.register_prefix("weak", { label = "Weak", weight = 8 })
api.register_prefix("normal", { label = "Normal", weight = 7 })
api.register_prefix("greater", { label = "Greater", weight = 6 })
api.register_prefix("dusty", { label = "Dusty", weight = 5 })

local light_nodes = {}
for id, cfg in pairs(prefix_particle_configs) do
	if cfg.light then
		local nodename = "mcl_lun_prefixes:light_" .. id
		cfg.light_node = nodename
		core.register_node(nodename, {
			description = "Prefix Light (" .. id .. ")",
			drawtype = "airlike",
			paramtype = "light",
			walkable = false,
			pointable = false,
			diggable = false,
			buildable_to = true,
			sunlight_propagates = true,
			light_source = math.min(14, math.max(1, math.floor(cfg.light))),
			groups = {not_in_creative_inventory = 1, not_in_craft_guide = 1},
			drop = "",
		})
		light_nodes[nodename] = true
	end
end

local function get_prefix_particle_config(stack)
	if not api.list_prefixes then
		return nil
	end
	local list = api.list_prefixes(stack)
	for _, id in ipairs(list) do
		local cfg = prefix_particle_configs[id]
		if cfg then
			return cfg
		end
	end
	return nil
end

local function spawn_prefix_particles(obj, cfg)
	if not obj or not cfg then
		return
	end
	local pos = obj:get_pos()
	if not pos then
		return
	end
	local radius = cfg.radius or 0.1
	local texture = cfg.texture or "mcl_particles_bonemeal.png"
	if cfg.color then
		texture = texture .. "^[colorize:" .. cfg.color .. ":180"
	end
	local height = 0.5 + math.random() * 1.5
	core.add_particlespawner({
		amount = math.floor(6 + height * 4),
		time = 0.2,
		minpos = {x = pos.x - radius, y = pos.y, z = pos.z - radius},
		maxpos = {x = pos.x + radius, y = pos.y + height, z = pos.z + radius},
		minvel = {x = 0, y = 0.5, z = 0},
		maxvel = {x = 0, y = 1.2, z = 0},
		minacc = {x = 0, y = 0, z = 0},
		maxacc = {x = 0, y = 0, z = 0},
		minsize = 0.25,
		maxsize = 0.55,
		glow = 10,
		texture = texture,
	})
end

local active_light_nodes = {}

local function positions_equal(a, b)
	return a and b and a.x == b.x and a.y == b.y and a.z == b.z
end

local function clear_light_for_obj(obj)
	local info = active_light_nodes[obj]
	if not info then
		return
	end
	local node = core.get_node_or_nil(info.pos)
	if node and node.name == info.node then
		core.remove_node(info.pos)
	end
	active_light_nodes[obj] = nil
end

local function ensure_light_for_obj(obj, cfg)
	local nodename = cfg.light_node
	if not nodename then
		clear_light_for_obj(obj)
		return
	end
	local pos = obj:get_pos()
	if not pos then
		clear_light_for_obj(obj)
		return
	end
	local target = vector.round(pos)
	local info = active_light_nodes[obj]
	if info and positions_equal(info.pos, target) and info.node == nodename then
		info.active = true
		return
	end
	if info then
		clear_light_for_obj(obj)
	end
	local current = core.get_node_or_nil(target)
	if not current then
		return
	end
	if current.name ~= "air" and current.name ~= nodename then
		return
	end
	core.set_node(target, {name = nodename})
	active_light_nodes[obj] = {pos = target, node = nodename, active = true}
end

local particle_timer = 0
core.register_globalstep(function(dtime)
	particle_timer = particle_timer + dtime
	if particle_timer < 0.25 then
		return
	end
	particle_timer = 0
	local processed = {}
	for _, player in ipairs(core.get_connected_players()) do
		local ppos = player:get_pos()
		if ppos then
			for _, obj in ipairs(core.get_objects_inside_radius(ppos, 20)) do
				if obj and not processed[obj] then
					processed[obj] = true
					local ent = obj:get_luaentity()
					if ent and ent.name == "__builtin:item" then
						local itemstring = ent.itemstring or ""
						local stack = ItemStack(itemstring)
						if not stack:is_empty() then
									local cfg = get_prefix_particle_config(stack)
									if cfg then
										if cfg.glow and obj.set_properties then
											local ent_glow = ent._mcl_lun_prefixes_glow or 0
											if ent_glow ~= cfg.glow then
												obj:set_properties({glow = cfg.glow})
												ent._mcl_lun_prefixes_glow = cfg.glow
											end
										end
										ensure_light_for_obj(obj, cfg)
										spawn_prefix_particles(obj, cfg)
									else
										if ent._mcl_lun_prefixes_glow then
											obj:set_properties({glow = 0})
											ent._mcl_lun_prefixes_glow = nil
										end
										clear_light_for_obj(obj)
									end
						end
					end
				end
			end
		end
	end
	for obj, info in pairs(active_light_nodes) do
		if not info.active or not obj:get_pos() then
			clear_light_for_obj(obj)
		else
			info.active = nil
		end
	end
end)
