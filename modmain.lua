-- GLOBAL.CHEATS_ENABLED = true
-- GLOBAL.require("debugkeys")
-- GLOBAL.require("debugtools")


--- Sort through the bag and return the items' new offsets.
--
-- @param items
-- @param bag Bag ID
-- @param offset
-- @return Sorted item offsets
local function sortItems(items, bag, offset)
	table.sort(items, function(a, b)

		-- Sort by name then value.
		if bag[offset].sortBy == 'name' then
			if bag[offset].contents[a].obj.name ~= bag[offset].contents[b].obj.name then
				return bag[offset].contents[a].obj.name < bag[offset].contents[b].obj.name
			end
			return bag[offset].contents[a].value > bag[offset].contents[b].value

		-- Sort by value then name.
		else
			if bag[offset].contents[a].value ~= bag[offset].contents[b].value then
				return bag[offset].contents[a].value > bag[offset].contents[b].value
			end
			return bag[offset].contents[a].obj.name < bag[offset].contents[b].obj.name
		end
	end)

	return items
end

--- Does the item provide armour?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsArmour(inst)
	return inst.components.armor ~= nil
end

--- Is the item a food for the current player?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsFood(inst)
	local itemIsGear = inst.components.edible and inst.components.edible.foodtype == GLOBAL.FOODTYPE.GEARS
	return inst.components.edible and (inst.components.perishable or itemIsGear)
end

--- Is the item a light?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsLight(inst)
	return inst.components.lighter and inst.components.fueled
end

--- Is the item a priority resource?
-- These items were manually selected from a frequency analysis of recipe components in the game
-- as of 10th March 2015. The idea is that the player will care most about having a quantity of
-- these items (because they are used commonly in item recipes), so let's sort them together.
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsResource(inst)
	-- Highest frequency to lowest fequency
	local items = {
		"Twigs",
		"Nightmare Fuel",
		"Rope",
		"Gold Nugget",
		"Boards",
		"Silk",
		"Papyrus",
		"Cut Grass",
		"Thulecite",
		"Cut Stone",
		"Flint",
		"Log",
		"Living Log",
		"Pig Skin",
		"Thulecite Fragments",
	}

	for i = 1, #items do
		local keys = {}
		if items[i] == inst.name then
			return true
		end
	end

	return false
end

--- Is the item a tool?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsTool(inst)
	return inst.components.tool and inst.components.equippable and inst.components.finiteuses
end

--- Is the item a weapon?
--
-- @param inst InventoryItem object
-- @return bool
local function itemIsWeapon(inst)
	return inst.components.weapon ~= nil
end

--- Sorts the player's inventory into a sensible order.
--
-- @param player Sort this player's inventory.
-- @param maxLights Max. number of torches to sort.
-- @param backpackCategory Category of item to sort into backpack.
local function sortInventory(player, maxLights, backpackCategory)
	local inventory    = player and player.components.inventory or nil
	local isPlayerHurt = (player.components.health:GetPercent() * 100) <= 30
	local backpack     = inventory and inventory:GetOverflowContainer() or nil
	local armourBag    = { contents = {}, sortBy = 'value', type = 'armour' }
	local foodBag      = { contents = {}, sortBy = 'value', type = 'food' }
	local lightBag     = { contents = {}, sortBy = 'value', type = 'light' }
	local miscBag      = { contents = {}, sortBy = 'name',  type = 'misc' }
	local resourceBag  = { contents = {}, sortBy = 'name',  type = 'resources' }
	local toolBag      = { contents = {}, sortBy = 'name',  type = 'tools' }
	local weaponBag    = { contents = {}, sortBy = 'value', type = 'weapons' }

	if player:HasTag("playerghost") or not inventory then
		return
	end

	local backpackSlotCount = backpack and backpack:GetNumSlots() or 0
	local invSlotCount      = inventory:GetNumSlots()
	local totalSlots        = backpackSlotCount + invSlotCount


	-- Categorise the player's inventory.
	for i = 1, totalSlots do
		local item = nil

		-- Loop through the main inventory and the backpack.
		if i <= invSlotCount then
			item = inventory:GetItemInSlot(i)

		else
			if not backpack then
				return
			end

			item = backpack:GetItemInSlot(i - invSlotCount)
		end

		-- Figure out what kind of item we're dealing with.
		if item then
			local bag  = miscBag
			local sort = 0

			-- Armour (chest and head)
			if itemIsArmour(item) then
				bag  = armourBag
				sort = item.components.armor:GetPercent()

			-- Food
			elseif itemIsFood(item) then
				bag  = foodBag
				sort = isPlayerHurt and item.components.edible.healthvalue or item.components.edible.hungervalue

			-- Light
			elseif itemIsLight(item) then
				bag  = lightBag
				sort = item.components.fueled:GetPercent()

				-- If bag has more lights than maxLights, store the extras in miscBag.
				if #lightBag.contents >= maxLights then
					bag = miscBag
				end

			-- Priority resources
			elseif itemIsResource(item) then
				bag = resourceBag

			-- Tools
			elseif itemIsTool(item) then
				bag  = toolBag
				sort = item.components.finiteuses:GetUses()

			-- Weapons (MUST be below the tools block)
			elseif itemIsWeapon(item) then
				bag  = weaponBag
				sort = item.components.weapon.damage
			end


			table.insert(bag.contents, {
				obj   = item,
				value = sort
			})
		end

		-- Detach the item from the player's inventory.
		inventory:RemoveItem(item, true)
	end

	local backpackOffset  = 0
	local inventoryOffset = 0


	--[[
	"Oh you may not think I'm pretty,
	But don't judge on what you see,
	I'll eat myself if you can find
	A smarter hat than me."
	--]]
	local sortingHat = {
		lightBag,
		toolBag,
		weaponBag,
		foodBag,
		armourBag,
		resourceBag,
		miscBag,
	}


	-- Sort the categorised items.
	for i = 1, #sortingHat do
		local keys = {}
		for key in pairs(sortingHat[i].contents) do
			table.insert(keys, key)
		end

		-- keys contains the sorted order for the current bag (sortingHat[i]).
		keys = sortItems(keys, sortingHat, i)

		for _, key in ipairs(keys) do
			-- Has the player chosen to store this type of item in their backpack?
			if backpack and sortingHat[i].type == backpackCategory then
				backpackOffset = backpackOffset + 1;
				backpack:GiveItem(sortingHat[i].contents[key].obj, backpackOffset, nil)

			else
				-- Otherwise, put the item in the player's inventory, if there's room.
				if inventory:NumItems() < invSlotCount then
					inventoryOffset = inventoryOffset + 1;
					inventory:GiveItem(sortingHat[i].contents[key].obj, inventoryOffset, nil)

				-- The inventory is full, put item in backpack. Overflow!
				elseif backpack then
					backpackOffset = backpackOffset + 1;
					backpack:GiveItem(sortingHat[i].contents[key].obj, backpackOffset, nil)
				end
			end
		end

	end
end

--- Inventory must be sorted server-side, so listen for a RPC.
AddModRPCHandler(modname, "dsiRemoteSortInventory", function(player, modVersion, maxLights, backpackCategory)
	sortInventory(player, maxLights, backpackCategory)
end)


--- Press "G" to sort your inventory.
GLOBAL.TheInput:AddKeyDownHandler(GLOBAL.KEY_G, function()
	local backpackCategory = GetModConfigData("backpackCategory")
	local maxLights        = GLOBAL.tonumber(GetModConfigData("maxLights"))
	local modVersion       = GLOBAL.KnownModIndex:GetModInfo(modname).version

	-- Server-side
	if GLOBAL.TheNet:GetIsServer() then
		sortInventory(GLOBAL.ThePlayer, maxLights, backpackCategory)

	-- Client-side
	else
		SendModRPCToServer(MOD_RPC[modname]["dsiRemoteSortInventory"], modVersion, maxLights, backpackCategory)
	end

	GLOBAL.ThePlayer.SoundEmitter:PlaySound("dontstarve/creatures/perd/gobble")
end)
