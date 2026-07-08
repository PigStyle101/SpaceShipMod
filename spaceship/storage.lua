return function(SpaceShip)
    local STORAGE_MODULE_NAME = "spaceship-storage-link"
    local HUB_MAIN_INVENTORY = defines.inventory.chest
    local BASE_HUB_INVENTORY_SIZE = 50
    local BONUS_SLOTS_PER_MODULE = 25

    local function has_ship_floor(ship)
        return ship and ship.floor and next(ship.floor) ~= nil
    end

    local function entity_overlaps_ship_floor(ship, entity)
        if not (ship and entity and entity.valid and has_ship_floor(ship)) then
            return false
        end

        local bb = entity.bounding_box or { left_top = entity.position, right_bottom = entity.position }
        -- Require the full entity footprint to be on spaceship flooring.
        -- Small epsilons avoid accidentally including neighboring tiles when the
        -- bounding box sits exactly on tile boundaries.
        local eps = 0.001
        local left = math.floor(bb.left_top.x + eps)
        local right = math.ceil(bb.right_bottom.x - eps) - 1
        local top = math.floor(bb.left_top.y + eps)
        local bottom = math.ceil(bb.right_bottom.y - eps) - 1

        local has_any_overlap = false

        for x = left, right do
            for y = top, bottom do
                if ship.floor[x .. "," .. y] then
                    has_any_overlap = true
                else
                    return false
                end
            end
        end

        return has_any_overlap
    end

    local function get_ship_storage_modules(ship)
        if not (ship and ship.hub and ship.hub.valid and ship.hub.surface and ship.hub.surface.valid) then
            return {}
        end

        local modules = {}
        local surface = ship.hub.surface

        if ship.bounds then
            modules = surface.find_entities_filtered({
                name = STORAGE_MODULE_NAME,
                area = {
                    { x = ship.bounds.left_top.x - 0.5, y = ship.bounds.left_top.y - 0.5 },
                    { x = ship.bounds.right_bottom.x + 0.5, y = ship.bounds.right_bottom.y + 0.5 }
                }
            })
        else
            modules = surface.find_entities_filtered({
                name = STORAGE_MODULE_NAME,
                area = {
                    { x = ship.hub.position.x - 64, y = ship.hub.position.y - 64 },
                    { x = ship.hub.position.x + 64, y = ship.hub.position.y + 64 }
                }
            })
        end

        local filtered = {}
        for _, module in pairs(modules) do
            if module and module.valid and entity_overlaps_ship_floor(ship, module) then
                filtered[#filtered + 1] = module
            end
        end

        return filtered
    end

    local function get_highest_occupied_slot(inventory)
        if not inventory then return 0 end

        local highest = 0
        for i = 1, #inventory do
            local stack = inventory[i]
            if stack and stack.valid_for_read then
                highest = i
            end
        end

        return highest
    end

    function SpaceShip.refresh_ship_storage_capacity(ship)
        if not (ship and ship.hub and ship.hub.valid and ship.hub.name == "spaceship-control-hub") then
            return
        end

        local inventory = ship.hub.get_inventory(HUB_MAIN_INVENTORY)
        if not inventory then return end

        local modules = get_ship_storage_modules(ship)
        local module_count = #modules
        local target_size = BASE_HUB_INVENTORY_SIZE + (module_count * BONUS_SLOTS_PER_MODULE)
        local highest_occupied_slot = get_highest_occupied_slot(inventory)
        local safe_size = math.max(target_size, highest_occupied_slot)

        local ok
        if safe_size <= BASE_HUB_INVENTORY_SIZE and highest_occupied_slot <= BASE_HUB_INVENTORY_SIZE then
            ok = pcall(function()
                ship.hub.set_inventory_size_override(HUB_MAIN_INVENTORY, nil)
            end)
            if ok then
                ship.storage_capacity_slots = BASE_HUB_INVENTORY_SIZE
            end
        else
            ok = pcall(function()
                ship.hub.set_inventory_size_override(HUB_MAIN_INVENTORY, safe_size)
            end)
            if ok then
                ship.storage_capacity_slots = safe_size
            end
        end

        ship.storage_module_count = module_count
        ship.storage_capacity_target_slots = target_size
    end

    function SpaceShip.refresh_all_ship_storage_capacities()
        for _, ship in pairs(storage.spaceships or {}) do
            SpaceShip.refresh_ship_storage_capacity(ship)
        end
    end

    function SpaceShip.get_ship_for_storage_module(entity)
        if not (entity and entity.valid and entity.name == STORAGE_MODULE_NAME) then
            return nil
        end

        for _, ship in pairs(storage.spaceships or {}) do
            if ship and ship.hub and ship.hub.valid and ship.hub.surface == entity.surface then
                if entity_overlaps_ship_floor(ship, entity) then
                    return ship
                end
            end
        end

        return nil
    end
end
