return function(SpaceShip)
    function SpaceShip.create_combined_renders(ship, tiles, scan, offset)
        local player = ship.player
        if not player or not player.valid then
            return
        end

        local processed_tiles = {}
        local combined_renders = {}

        if not scan then
            -- Calculate the offset to make the reference tile start at (0, 0)
            local reference_tile = ship.reference_tile
            if not reference_tile then
                game.print("Error: Reference tile is missing from ship data.")
                return
            end
            offset = {
                x = -reference_tile.position.x + offset.x,
                y = -reference_tile.position.y + offset.y
            }
        end
        local function is_processed(x, y)
            return processed_tiles[x .. "," .. y]
        end
        local function mark_processed(x, y)
            processed_tiles[x .. "," .. y] = true
        end
        -- Sort tiles by their position, starting from the bottom-right
        local sorted_tiles = {}
        for _, tile_data in pairs(tiles) do
            table.insert(sorted_tiles, tile_data)
        end
        table.sort(sorted_tiles, function(a, b)
            if a.position.y == b.position.y then
                return a.position.x > b.position.x -- Sort by x descending
            end
            return a.position.y > b.position.y     -- Sort by y descending
        end)

        for _, tile_data in ipairs(sorted_tiles) do
            local x, y = tile_data.position.x, tile_data.position.y
            if not is_processed(x, y) then
                -- Start a new square area
                local square_size = 1
                local valid_square = true

                while valid_square do
                    for dx = 0, square_size do
                        for dy = 0, square_size do
                            local check_x = x - dx
                            local check_y = y - dy
                            local tile_key = check_x .. "," .. check_y

                            if not tiles[tile_key] or is_processed(check_x, check_y) then
                                valid_square = false
                                break
                            end
                        end
                        if not valid_square then
                            break
                        end
                    end

                    if valid_square then
                        square_size = square_size + 1
                    end
                end

                square_size = square_size - 1 -- Adjust to the last valid size
                for dx = 0, square_size - 1 do
                    for dy = 0, square_size - 1 do
                        mark_processed(x - dx, y - dy)
                    end
                end

                local snapped_left_top = {
                    x = math.floor(x - square_size + 0.5 + offset.x),
                    y = math.floor(y - square_size + 0.5 + offset.y)
                }
                local snapped_right_bottom = {
                    x = math.floor(x + 0.5 + offset.x),
                    y = math.floor(y + 0.5 + offset.y)
                }

                local render_id = rendering.draw_rectangle({
                    color = { r = 0.5, g = 0.5, b = 1, a = 0.4 }, -- Light blue tint
                    surface = player.surface,
                    left_top = snapped_left_top,
                    right_bottom = snapped_right_bottom,
                    filled = true,
                    players = { player.index },
                    only_in_alt_mode = false
                })

                table.insert(combined_renders, render_id)
            end
        end

        -- Handle any remaining unprocessed tiles (shouldn't happen, but just in case)
        for _, tile_data in pairs(tiles) do
            local x, y = tile_data.position.x, tile_data.position.y
            if not is_processed(x, y) then
                local left_top = { x = x - 0.5 + offset.x, y = y - 0.5 + offset.y }
                local right_bottom = { x = x + 0.5 + offset.x, y = y + 0.5 + offset.y }

                local render_id = rendering.draw_rectangle({
                    color = { r = 0.5, g = 0.5, b = 1, a = 0.4 }, -- Light blue tint
                    surface = player.surface,
                    left_top = left_top,
                    right_bottom = right_bottom,
                    filled = true,
                    players = { player.index },
                    only_in_alt_mode = false
                })

                table.insert(combined_renders, render_id)
                mark_processed(x, y)
            end
        end

        game.print("Total Renders: " ..
            #combined_renders ..
            " (combined from " .. table_size(tiles) .. " tiles)")
        return combined_renders
    end
end
