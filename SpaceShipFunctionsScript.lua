local SpaceShipFunctions = {}

-- Function to check if a table contains a value
function SpaceShipFunctions.table_contains(tbl, value)
    for k, v in pairs(tbl) do
        if k == value then
            return true -- Value found
        end
        if v == value then
            return true
        end
    end
    return false -- Value not found
end

-- Function to list all space platforms in the player's chat
function SpaceShipFunctions.list_space_platforms(player)
    -- Ensure the player is valid
    if not player or not player.valid then
        game.print("Error: Invalid player.")
        return
    end

    -- Retrieve all surfaces and filter for space platforms
    local space_platforms = {}
    for _, surface in pairs(player.force.platforms) do
        if surface.type == "space-platform" then
            table.insert(space_platforms, surface.name)
        end
    end

    -- Display the list of space platforms to the player
    if #space_platforms > 0 then
        player.print("Available Space Platforms:")
        for _, platform_name in ipairs(space_platforms) do
            player.print("- " .. platform_name)
        end
    else
        player.print("No space platforms found.")
    end
end

return SpaceShipFunctions
