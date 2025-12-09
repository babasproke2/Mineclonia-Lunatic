local F = core.formspec_escape
local S = core.get_translator and core.get_translator("mcl_lun_nodes") or function(str) return str end
local slot_bg = mcl_formspec and mcl_formspec.get_itemslot_bg_v4 or function() return "" end
local drop_items = (mcl_util and mcl_util.drop_items_from_meta_container and
	mcl_util.drop_items_from_meta_container("main")) or function() end

local function donation_box_formspec(pos)
	local spos = ("%d,%d,%d"):format(pos.x, pos.y, pos.z)
	local meta = core.get_meta(pos)
	local title = meta:get_string("name")
	if title == "" then
		title = S("Donation Box")
	end
	title = F(title)
	return table.concat({
		"formspec_version[4]",
		"size[11.75,15.5]",
		"label[0.375,0.375;", title, "]",
		slot_bg(0.375, 0.75, 9, 9),
		"list[nodemeta:", spos, ";main;0.375,0.75;9,9;]",
		"label[0.375,10.2;", F(S("Inventory")), "]",
		slot_bg(0.375, 10.6, 9, 3),
		"list[current_player;main;0.375,10.6;9,3;9]",
		slot_bg(0.375, 14.55, 9, 1),
		"list[current_player;main;0.375,14.55;9,1;]",
		"listring[nodemeta:", spos, ";main]",
		"listring[current_player;main]",
	})
end

local function donation_box_protected(pos, player)
	if player and core.is_protected(pos, player:get_player_name()) then
		core.record_protection_violation(pos, player:get_player_name())
		return true
	end
	return false
end

minetest.register_node("mcl_lun_nodes:donation_box", {
	paramtype2 = "facedir",
	drawtype = "nodebox",
	is_ground_content = false,
	sounds = mcl_sounds and mcl_sounds.node_sound_wood_defaults() or nil,
	node_box = {
		type = "fixed",
		fixed = {
			{-0.4063, 0.3750, -0.4375, -0.3438, 0.4375, 0.4375},
			{-0.2188, 0.3750, -0.4375, -0.1563, 0.4375, 0.4375},
			{-0.03125, 0.3750, -0.4375, 0.03125, 0.4375, 0.4375},
			{0.1563, 0.3750, -0.4375, 0.2188, 0.4375, 0.4375},
			{0.3438, 0.3750, -0.4375, 0.4063, 0.4375, 0.4375},
			{-0.5000, -0.4375, -0.5000, 0.5000, 0.5000, -0.4375},
			{-0.5000, -0.4375, -0.4375, -0.4375, 0.5000, 0.4375},
			{-0.5000, -0.5000, -0.5000, 0.5000, -0.4375, 0.5000},
			{0.4375, -0.5000, -0.4375, 0.5000, 0.5000, 0.5000},
			{-0.5000, -0.4375, 0.4375, 0.4375, 0.5000, 0.5000}
		}
	},
	description = "The emptiest thing in the world, the perfect storage...",
	tiles = {
		"default_wood.png",
		"default_wood.png",
		"mcl_lun_nodes_donation_box_side.png",
		"mcl_lun_nodes_donation_box_side.png",
		"mcl_lun_nodes_donation_box_side.png",
		"mcl_lun_nodes_donation_box_front.png",
	},
	groups = {
		handy = 1,
		axey = 1,
		deco_block = 1,
		material_wood = 1,
		flammable = -1,
		container = 1,
		pathfinder_partial = 1,
	},
	selection_box = {
		type = "fixed",
		fixed = { -0.5, -0.5, -0.5, 0.5, 0.5, 0.5 },
	},
	_mcl_blast_resistance = 2.5,
	_mcl_hardness = 2.5,
	on_construct = function(pos)
		local meta = core.get_meta(pos)
		meta:set_string("infotext", S("Donation Box"))
		meta:set_string("name", "")
		local inv = meta:get_inventory()
		inv:set_size("main", 9 * 9)
	end,
	after_place_node = function(pos, placer, itemstack)
		local meta = core.get_meta(pos)
		local custom_name = itemstack and itemstack:get_meta():get_string("name") or ""
		meta:set_string("name", custom_name)
		return placer
	end,
	after_dig_node = function(pos, oldnode, oldmeta, digger)
		drop_items(pos, oldnode)
	end,
	allow_metadata_inventory_put = function(pos, listname, _, stack, player)
		if listname ~= "main" then
			return 0
		end
		if donation_box_protected(pos, player) then
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_take = function(pos, listname, _, stack, player)
		if listname ~= "main" then
			return 0
		end
		if donation_box_protected(pos, player) then
			return 0
		end
		return stack:get_count()
	end,
	allow_metadata_inventory_move = function(pos, from_list, from_index, to_list, to_index, count, player)
		if from_list ~= "main" or to_list ~= "main" then
			return 0
		end
		if donation_box_protected(pos, player) then
			return 0
		end
		return count
	end,
	on_rightclick = function(pos, node, clicker)
		if not clicker or not clicker:is_player() then
			return
		end
		local above = core.get_node_or_nil({ x = pos.x, y = pos.y + 1, z = pos.z })
		if above then
			local def = core.registered_nodes[above.name]
			if def and def.groups and def.groups.opaque == 1 then
				return
			end
		end
		core.show_formspec(clicker:get_player_name(),
			string.format("mcl_lun_nodes:donation_box_%d_%d_%d", pos.x, pos.y, pos.z),
			donation_box_formspec(pos))
	end,
})
