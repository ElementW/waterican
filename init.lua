local MODNAME = "waterican"

--
-- Waterican (by gravgun)
-- v1.2
-- A mod that add watering cans that make crops grow faster.
--
-- LICENSE: GPLv3+
--          ('cuz every time you use proprietary software, a kitten dies)
--
-- Why that name?
--  Because somehow when I wrote "watering can" fast I actually wrote "waterican".
--  

local function rn() return math.random()-.5 end
local function rr(min, max) return min + math.random() * (max-min) end

local function waternode(user, pos)
	local node = minetest.get_node(pos)
	local nodedef = minetest.registered_nodes[node.name]
	if nodedef == nil then
		return -- dafuq?
	end

	-- General soil wetting
	local soil = nodedef.soil
	if soil and node.name == soil.dry then
		minetest.set_node(pos, {name=soil.wet})
		return
	end

	-- Farming soil wetting (compatibility with Farming Redo)
	if node.name == "farming:soil" then
		minetest.set_node(pos, {name="farming:soil_wet"})
		return
	end

	-- Seed growth
	if minetest.get_item_group(node.name, "seed") > 0 and nodedef.fertility then
		local grow = false
		local node_under = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if node_under == nil then
			return
		end
		-- Can this seed grow on the node that's beneath it?
		for _, v in pairs(nodedef.fertility) do
			if minetest.get_item_group(node_under.name, v) > 0 then
				grow = true
			end
		end
		if grow then
			minetest.set_node(pos, {name=node.name:gsub("seed_", "") .. "_1"})
		end
		return
	end

	-- Plant growth
	local plant_nbr_s, plant_nbr_e = string.find(node.name, "_[0-9]+$")
	if minetest.get_item_group(node.name, "plant") > 0 and plant_nbr_s then
		local plant_nbr = tonumber(string.sub(node.name, plant_nbr_s+1, plant_nbr_e))
		local orig_name = string.sub(node.name, 0, plant_nbr_s)
		local next = orig_name .. (plant_nbr+1)
		if minetest.registered_nodes[next] then
			minetest.set_node(pos, {name=next})
		end
		return
	end

	-- Cactus growth
	if node.name == "default:cactus" then
		default.grow_cactus(pos, minetest.get_node(pos))
		return
	end

	-- Papyrus growth
	if node.name == "default:papyrus" then
		default.grow_papyrus(pos, minetest.get_node(pos))
		return
	end

	-- Grow grass on dirt
	-- Convery dry grass to grass
	if (node.name == "default:dirt" and minetest.find_node_near(pos, 1, {"default:dirt_with_grass"}))
	   or (node.name == "default:dirt_with_dry_grass")
	   and math.random() > 0.4 then
		local above = {x = pos.x, y = pos.y + 1, z = pos.z}
		local name = minetest.get_node(above).name
		local above_nodedef = minetest.registered_nodes[name]
		if name ~= "ignore" and above_nodedef and
		   ((above_nodedef.sunlight_propagates or above_nodedef.paramtype == "light") and above_nodedef.liquidtype == "none") then
			minetest.set_node(pos, {name="default:dirt_with_grass"})
		end
		return
	end

	-- Put out fire
	if node.name == "fire:basic_flame" then
		minetest.set_node(pos, {name="air"})
		minetest.sound_play("default_cool_lava",
			{pos = pos, max_hear_distance = 16, gain = 0.25})
		return
	end

	-- Tree growth
	if math.random() > 0.9 then
		-- The code in this `if` statement is copied from the `default` mod, therefore is LGPLv2.1+.
		-- If Minetest coredevs had the lil' idea to plan ahead, they would have **named** ABMs
		-- so we can reuse them OR added a way to force ABMs to trigger on certain nodes.
		-- But no, they seem way too dumb for that simple shit.
		local node_under = minetest.get_node_or_nil({x = pos.x, y = pos.y - 1, z = pos.z})
		if not node_under then
			return
		end
		local name_under = node_under.name
		local is_soil = minetest.get_item_group(name_under, "soil")
		if is_soil == 0 then
			return
		end

		local mapgen = minetest.get_mapgen_params().mgname
		if node.name == "default:sapling" then
			minetest.log("action", "A sapling grows into a tree at "..
				minetest.pos_to_string(pos))
			if mapgen == "v6" then
				default.grow_tree(pos, random(1, 4) == 1)
			else
				default.grow_new_apple_tree(pos)
			end
		elseif node.name == "default:junglesapling" then
			minetest.log("action", "A jungle sapling grows into a tree at "..
				minetest.pos_to_string(pos))
			if mapgen == "v6" then
				default.grow_jungle_tree(pos)
			else
				default.grow_new_jungle_tree(pos)
			end
		elseif node.name == "default:pine_sapling" then
			minetest.log("action", "A pine sapling grows into a tree at "..
				minetest.pos_to_string(pos))
			if mapgen == "v6" then
				default.grow_pine_tree(pos)
			else
				default.grow_new_pine_tree(pos)
			end
		elseif node.name == "default:acacia_sapling" then
			minetest.log("action", "An acacia sapling grows into a tree at "..
				minetest.pos_to_string(pos))
			default.grow_new_acacia_tree(pos)
		end
	end
end

local function water(user, minp, maxp, chance)
	for x=minp.x,maxp.x do
		for y=minp.y,maxp.y do
			for z=minp.z,maxp.z do
				if math.random() < chance then
					waternode(user, {x=x, y=y, z=z})
				end
			end
		end
	end
	local particle_count = math.random(1, 4) * (maxp.x-minp.x+1) * (maxp.z-minp.z+1)
	for _=0,particle_count do
		minetest.add_particle({
			pos = {x = rr(minp.x, maxp.x), y = maxp.y + 0.7, z = rr(minp.z, maxp.z) },
			vel = {x=rn()*.6, y=0, z=rn()*.6},
			acc = {x=0, y=-10, z=0},
			expirationtime = math.random()*2+1,
			size = 1,
			collisiondetection = true,
			vertical = false,
			texture = "waterican_droplet.png",
			playername = user:get_player_name()
		})
	end
end

local function reg_waterican(def)
	local img = "waterican_waterican.png"
	if def.color then
		img = img .. "^[colorize:" .. def.color .. "^waterican_waterican_alphaoverlay.png"
	end
	local matname = ""
	if def.materialname then
		 matname = " (" .. def.materialname .. ")"
	end
	local toolname = MODNAME .. ":waterican_" .. def.material
	minetest.register_tool(toolname, {
		description = "Waterican" .. matname,
		liquids_pointable = true,
		inventory_image = img,
		wield_image = img .. "^[transformFX",
		wield_scale = {x = 1, y = 1, z = 6},
		on_use = function(itemstack, user, pointed_thing)
			local wear = itemstack:get_wear()

			-- Refill if pointing at water and not already full
			if pointed_thing.type == "node" then
				local node = minetest.get_node(pointed_thing.under)
				-- Don't check for default, since Watericans that
				-- wear out are only available if default is.
				if node.name == "default:water_source" then
					if wear > 0 then
						itemstack:set_wear(0)
						minetest.set_node(pointed_thing.under, {name="air"})
						return itemstack
					end
					return
				end
			end

			-- Worn out = no more water.
			if wear == 65534 then
				return
			end

			if pointed_thing.type == "node" then
				p = pointed_thing.under
				if user:get_player_control().sneak then
					water(user, {x=p.x,y=p.y-1,z=p.z}, p, def.chance)
				else
					water(user, {x=p.x-1,y=p.y-1,z=p.z-1}, {x=p.x+1,y=p.y,z=p.z+1}, def.chance)
				end
			end
			if def.uses then
				local wearadd = 0
				if user:get_player_control().sneak then
					wearadd = 65534/(def.uses*9)+1
				else
					wearadd = 65534/def.uses+1
				end
				wearadd = math.min(wearadd, 65534-wear)
				itemstack:add_wear(wearadd)
				return itemstack
			end
		end
	})
	return toolname
end

reg_waterican({material = "op", chance = 1})
if default then
	local reg_craft = function(...) end
	if bucket then
		reg_craft = function (out, item)
			minetest.register_craft({
				output = out,
				recipe = {
					{"", "", item},
					{item, "bucket:bucket_water", item},
					{"", item, ""}
				},
				replacements = {
					{"bucket:bucket_water", "bucket:bucket_empty", ""}
				}
			})
		end
	end
	reg_craft(reg_waterican({material = "diamond", materialname = "Diamond", color = "#00FFFF", uses = 60, chance = 0.8}),
	  "default:diamond")
	reg_craft(reg_waterican({material = "mese", materialname = "Mese", color = "#FFFF00", uses = 50, chance = 0.7}),
	  "default:mese_crystal")
	reg_craft(reg_waterican({material = "gold", materialname = "Gold", color = "#E6C717", uses = 40, chance = 0.6}),
	  "default:gold_ingot")
	reg_craft(reg_waterican({material = "steel", materialname = "Steel", color = "#CCCCCC", uses = 30, chance = 0.5}),
	  "default:steel_ingot")
	reg_craft(reg_waterican({material = "bronze", materialname = "Bronze", color = "#FF873D", uses = 20, chance = 0.4}),
	  "default:bronze_ingot")
	reg_craft(reg_waterican({material = "stone", materialname = "Stone", color = "#7F7F7F", uses = 15, chance = 0.3}),
	  "default:cobble")
	reg_craft(reg_waterican({material = "wood", materialname = "Wood", color = "#6C4913", uses = 10, chance = 0.2}),
	  "group:wood")
end