local simulations = {}
local DEFAULT_SIMULATION_MODS = { "SpaceShipMod" }
local DEFAULT_SIMULATION_SPEED_UPDATE = "game.speed = 1"

local function apply_default_simulation_mods()
  for _, simulation in pairs(simulations) do
    if type(simulation) == "table" then
      if simulation.mods == nil then
        simulation.mods = { DEFAULT_SIMULATION_MODS[1] }
      end

      if simulation.update and simulation.update ~= "" then
        simulation.update = DEFAULT_SIMULATION_SPEED_UPDATE .. "\n" .. simulation.update
      else
        simulation.update = DEFAULT_SIMULATION_SPEED_UPDATE
      end
    end
  end
end

simulations.spaceship_overview =
{
  save = "__SpaceShipMod__/prototypes/tips-and-tricks/saves/spaceship-overview-space.zip",
  init =
  [[
    require("__core__/lualib/story")

    local function get_space_surface_from_save()
      local player_force = game.forces and game.forces.player
      if player_force and player_force.valid and player_force.platforms then
        for _, platform in pairs(player_force.platforms) do
          if platform and platform.valid and platform.surface and platform.surface.valid then
            return platform.surface
          end
        end
      end

      for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and surface.platform and surface.platform.valid then
          return surface
        end
      end

      return game.surfaces[1]
    end

    local surface = get_space_surface_from_save()

    player = game.simulation.create_test_player{name = "SpaceShip Trainee"}
    player.teleport({0, 0}, surface)

    game.simulation.camera_player = player
    game.simulation.camera_position = player.position
    game.simulation.camera_zoom = 0.7

    storage.character = player.character

    local story_table =
    {
      {
        {
          name = "start",
          init = function() game.forces.player.chart(surface, {{-128, -128}, {128, 128}}) end,
          condition = story_elapsed_check(1)
        },
        { condition = story_elapsed_check(5) },
        {
          condition = story_elapsed_check(2),
          action = function()
            story_jump_to(storage.story, "start")
          end
        }
      }
    }

    tip_story_init(story_table)
  ]]
}

simulations.entering_spaceship_cockpit =
{
  checkboard = false,
  mods = { "SpaceShipMod" },
  save = "__SpaceShipMod__/prototypes/tips-and-tricks/saves/spaceship-overview-space.zip",
  init =
  [[
    require("__core__/lualib/story")

    local function get_space_surface_from_save()
      local player_force = game.forces and game.forces.player
      if player_force and player_force.valid and player_force.platforms then
        for _, platform in pairs(player_force.platforms) do
          if platform and platform.valid and platform.surface and platform.surface.valid then
            return platform.surface
          end
        end
      end

      for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and surface.platform and surface.platform.valid then
          return surface
        end
      end

      return game.surfaces[1]
    end

    local surface = get_space_surface_from_save()
    local platform_hub = surface.find_entities_filtered{name = "space-platform-hub", limit = 1}[1]
    local start_position = (platform_hub and platform_hub.valid and {platform_hub.position.x + 19, platform_hub.position.y - 1}) or {19, -1}

    player = game.players and game.players[1]
    if not (player and player.valid) then
      player = game.simulation.create_test_player{name = "SpaceShip Trainee"}
    end

    player.teleport(start_position, surface)

    game.simulation.camera_player = player
    game.simulation.camera_position = player.position
    game.simulation.camera_zoom = 0.8

    storage.character = player.character
    storage.entering_cockpit_tip_player_index = player.index

    local story_table =
    {
      {
        {
          name = "start",
          init = function()
            game.forces.player.chart(surface, {{-64, -64}, {64, 64}})
            storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
            storage.recent_rocket_arrival_tick[player.index] = nil
            if player.vehicle and player.vehicle.valid then
              pcall(function() player.driving = false end)
            end
            player.teleport(start_position, surface)
          end,
          condition = story_elapsed_check(1)
        },
        {
          condition = story_elapsed_check(2),
          action = function()
            game.simulation.control_press{control = "toggle-driving", notify = false}
          end
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = player.position})
          end,
          action = function()
            game.simulation.control_press{control = "open-gui", notify = false}
          end
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = {player.position.x - 26, player.position.y - 4}})
          end,
          action = function()
            game.simulation.control_press{control = "open-gui", notify = false}
          end
        },
        {
          condition = story_elapsed_check(1),
          action = function()
            game.simulation.control_press{control = "toggle-menu", notify = false}
          end
        },
        { condition = story_elapsed_check(3.17) },
        {
          condition = story_elapsed_check(2)
        }
      }
    }

    tip_story_init(story_table)
  ]],
  update =
  [[
    local player = storage.entering_cockpit_tip_player_index and game.get_player(storage.entering_cockpit_tip_player_index)
    if player and player.valid then
      game.simulation.camera_player = player
      game.simulation.camera_position = player.position
    end
  ]]
}

simulations.first_visit_to_new_planet =
{
  checkboard = false,
  mods = { "SpaceShipMod" },
  save = "__SpaceShipMod__/prototypes/tips-and-tricks/saves/Dropping-to-planet.zip",
  init =
  [[
    require("__core__/lualib/story")

    player = game.players and game.players[1]
    if not (player and player.valid) then
      player = game.simulation.create_test_player{name = "SpaceShip Trainee"}
    end

    local surface = player.surface or game.surfaces[1]
    local hub = surface.find_entities_filtered{name = "spaceship-control-hub", limit = 1}[1]
    local hub_position = (hub and hub.valid and hub.position) or player.position

    game.simulation.camera_player = player
    game.simulation.camera_position = player.position
    game.simulation.camera_zoom = 0.8

    storage.character = player.character
    storage.first_visit_to_new_planet_player_index = player.index

    local story_table =
    {
      {
        {
          name = "start",
          init = function()
            game.forces.player.chart(surface, {{-64, -64}, {64, 64}})
            if player.vehicle and player.vehicle.valid then
              pcall(function() player.driving = false end)
            end
          end,
          condition = story_elapsed_check(1)
        },
        {
          condition = story_elapsed_check(0.4),
          action = function()
            local move_target = {player.position.x + 2, player.position.y}
            game.simulation.move_cursor({position = move_target})
          end
        },
        {
          condition = story_elapsed_check(0.4),
          action = function()
            game.simulation.control_press{control = "toggle-driving", notify = false}
          end
        },
        {
          condition = story_elapsed_check(2)
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = hub_position})
          end,
          action = function()
            game.simulation.control_press{control = "open-gui", notify = false}
          end
        },
        {
          condition = function()
            local target = {hub_position.x + 28, hub_position.y - 4}
            return game.simulation.move_cursor({position = target, speed = 0.2})
          end,
          action = function()
            game.simulation.mouse_click()
          end
        },
        { condition = story_elapsed_check(2) }
      }
    }

    tip_story_init(story_table)
  ]],
  update =
  [[
    local player = storage.first_visit_to_new_planet_player_index and game.get_player(storage.first_visit_to_new_planet_player_index)
    if player and player.valid then
      game.simulation.camera_player = player
      game.simulation.camera_position = player.position
    end
  ]]
}

simulations.station_to_planet_transportation =
{
  checkboard = false,
  mods = { "SpaceShipMod" },
  save = "__SpaceShipMod__/prototypes/tips-and-tricks/saves/spaceship-overview-space.zip",
  init =
  [[
    require("__core__/lualib/story")

    local function get_space_surface_from_save()
      local player_force = game.forces and game.forces.player
      if player_force and player_force.valid and player_force.platforms then
        for _, platform in pairs(player_force.platforms) do
          if platform and platform.valid and platform.surface and platform.surface.valid then
            return platform.surface
          end
        end
      end

      for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and surface.platform and surface.platform.valid then
          return surface
        end
      end

      return game.surfaces[1]
    end

    local surface = get_space_surface_from_save()
    local platform_hub = surface.find_entities_filtered{name = "space-platform-hub", limit = 1}[1]
    if not platform_hub or not platform_hub.valid then
      pcall(function()
        platform_hub = surface.create_entity{name = "space-platform-hub", position = {0, 0}, force = game.forces.player}
      end)
    end

    player = game.players and game.players[1]
    if not (player and player.valid) then
      player = game.simulation.create_test_player{name = "SpaceShip Pilot"}
    end

    game.simulation.camera_player = player
    game.simulation.camera_position = player.position
    game.simulation.camera_zoom = 0.8

    storage.character = player.character
    storage.station_tip_player_index = player.index

    local story_table =
    {
      {
        {
          name = "start",
          init = function()
            game.forces.player.chart(surface, {{-16, -16}, {16, 16}})
            storage.recent_rocket_arrival_tick = storage.recent_rocket_arrival_tick or {}
            storage.recent_rocket_arrival_tick[player.index] = nil
            if player.vehicle and player.vehicle.valid then
              pcall(function() player.driving = false end)
            end
          end,
          condition = story_elapsed_check(1)
        },
        {
          condition = story_elapsed_check(0.12),
          action = function()
            game.simulation.control_down{control = "move-up", notify = false}
          end
        },
        {
          condition = story_elapsed_check(0.08),
          action = function()
            game.simulation.control_up{control = "move-up"}
          end
        },
        {
          condition = story_elapsed_check(0.2),
          action = function()
            game.simulation.control_press{control = "toggle-driving", notify = false}
          end
        },
        {
          condition = story_elapsed_check(6)
        }
      }
    }

    tip_story_init(story_table)
  ]],
  update =
  [[
    local player = storage.station_tip_player_index and game.get_player(storage.station_tip_player_index)
    if player and player.valid then
      game.simulation.camera_player = player
      game.simulation.camera_position = player.position
    end
  ]]
}

simulations.spaceship_gui =
{
  mods = { "SpaceShipMod" },
  save = "__SpaceShipMod__/prototypes/tips-and-tricks/saves/spaceship-gui-space.zip",
  init =
  [[
    require("__core__/lualib/story")

    local function get_space_surface_from_save()
      local player_force = game.forces and game.forces.player
      if player_force and player_force.valid and player_force.platforms then
        for _, platform in pairs(player_force.platforms) do
          if platform and platform.valid and platform.surface and platform.surface.valid then
            return platform.surface
          end
        end
      end

      for _, surface in pairs(game.surfaces) do
        if surface and surface.valid and surface.platform and surface.platform.valid then
          return surface
        end
      end

      return game.surfaces[1]
    end

    local surface = get_space_surface_from_save()
    local hub = surface.find_entities_filtered{name = "spaceship-control-hub", limit = 1}[1]
    local hub_position = (hub and hub.valid and hub.position) or {0, 0}

    player = game.simulation.create_test_player{name = "SpaceShip Pilot"}
    player.teleport(hub_position, surface)

    game.simulation.camera_player = player
    game.simulation.camera_position = player.position
    game.simulation.camera_zoom = 0.8

    storage.character = player.character

    local story_table =
    {
      {
        {
          name = "start",
          init = function() game.forces.player.chart(surface, {{-32, -32}, {32, 32}}) end,
          condition = story_elapsed_check(1)
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = hub_position})
          end,
          action = function()
            game.simulation.control_press{control = "open-gui", notify = false}
          end
        },
        {
          condition = story_elapsed_check(2),
          action = function()
            story_jump_to(storage.story, "start")
          end
        }
      }
    }

    tip_story_init(story_table)
  ]]
}

simulations.creating_space_stations =
{
  init =
  [[
    require("__core__/lualib/story")

    local surface = game.surfaces[1]
    surface.build_checkerboard{{-32, -32}, {32, 32}}

    surface.create_entities_from_blueprint_string
    {
      string = "0eNrtWcGS4iAQ/RfOZEsgUeOvTFkpjO0sNZFkgDjjTvnv2ySZ6M5EJbt7yEEvYoBH9+tHN5EPsilqqIzSjqw+iMpLbcnq6YNY9axl4Z9puQeyIqbMX8BFVhUlOVGi9BbeyYqd6MDYDUgEuhjGT2tKQDvlFLT4zY9jpuv9Bgzi0M+5tt5YJ53C+ZRUpVVNE7Hfm1FHsor4/OSX/QLBx0CweAhC0LO3m7IqjfsOIDoA9JwYeK3BumynCgfG+hEWcj+4dbInaT20Wky/8PV9rR9J5zG2PJsO9h3y9oJuWwFso325rQuIBDkP9BZkSh9w4dIcO5P6X0gF0pS/kNXMWzfY05i+HjA+GWH8bGrGz8ONZ4upGb8YYXw8NeOXZ+Pr4iVS2oLBrfPdh6T3oZX+Vpl2ZyHGAG7a4yq9Uxq7ovwnbs1bwLwlpxufWXBO6efGfwP78gBZrdudDduso2YnCwuU9Bv+qWezwgQJ1iJCVCMeLpyXtc+qbEYJkuzHwLvMXXEkf6bPDqAo36ItaOttt87UuasNhMHwC5guT+9qKMImi+Hs5Kd8CgXDK5/hLqNpQ+i/JUXG7sp73ieWycmb8VB9z8fpm4lggc8fAg8TeBwaq8XIWCXBsVo8YhUWq3PFriT6dYAIXTyoLZi71LZZaSNN5+FX6EWoDJYjZbAMlsHyIYMwGaSjY5V+DVU89Oowu1t00ukWHc7o0EvadRfYsivUuaouZlWyed9pH2evtSxwFezWpdlLH7jaQuaM1C2qLLKu1KN7qA3436TEV0mJL0i51sOv9oirRAZX73RcKuDh1Tt9pIKgVMDj8ZSmf8FoK+wBQm0lc6xChXQ73B9IifRSwU2EEjs71vslXVSAbMy7fQDmSagI2WykCufBlF1AP2R4U4bBpwfGRkYr/PhwAf2I1s1opXfrvGdwqoVezILFxseJTbBwsfGH2ILEJoJPE0yMjFb4ceIC+hGtm9GKw64PkltXECIZBcL4IMj9f6dZMt2LAbEYY/7krgbEcoT507scEOkY8ydX4eJZ0AYS4tYGisMuE+P0Jsg5e0OBydioPAIN5vmIiRyT4Q5P/wN/hbMek2LW3+3AZFb9Ap+S+o+/C33DDO85f2I0oZh7kjVtmrxpcf8waZq+r2/jF0WKfNt/UfQ0Wa/bwPiI91e5lBwwXzd2JXOeJjGPl+liGYvkdPoNTZv2bw==",
      position = {0, 0}
    }

    local silo = surface.find_entities_filtered{name = "rocket-silo"}[1]
    local silo_position = (silo and silo.valid and silo.position) or {0, 0}
    local player_position = {silo_position.x, silo_position.y + 5}

    if silo and silo.valid then
      silo.rocket_parts = silo.prototype.rocket_parts_required
      silo.use_transitional_requests = false
      silo.get_inventory(defines.inventory.rocket_silo_rocket).insert{name = "space-platform-starter-pack", count = 1}
    end

    player = game.simulation.create_test_player{name = "SpaceShip Pilot"}
    player.teleport(player_position, surface)

    game.simulation.camera_player = player
    game.simulation.camera_position = silo_position
    game.simulation.camera_zoom = 1

    storage.character = player.character

    local story_table =
    {
      {
        {
          name = "start",
          init = function()
            game.forces.player.chart(surface, {{-32, -32}, {32, 32}})
            if silo and silo.valid then
              silo.rocket_parts = silo.prototype.rocket_parts_required
              silo.use_transitional_requests = false
              local rocket_inventory = silo.get_inventory(defines.inventory.rocket_silo_rocket)
              if rocket_inventory.get_item_count("space-platform-starter-pack") == 0 then
                rocket_inventory.insert{name = "space-platform-starter-pack", count = 1}
              end
            end
          end,
          condition = story_elapsed_check(5)
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = silo_position})
          end,
          action = function()
            game.simulation.control_press{control = "open-gui", notify = false}
          end
        },
        { condition = story_elapsed_check(0.5) },
        {
          condition = function()
            local target = game.simulation.get_widget_position({type = "text-button-localised-substring", data = "gui-rocket-silo.space-platform-button"})
            return game.simulation.move_cursor({position = target})
          end
        },
        { condition = story_elapsed_check(2) },
        {
          condition = story_elapsed_check(1),
          action = function() player.opened = nil end
        },
        {
          condition = function()
            return game.simulation.move_cursor({position = player_position})
          end
        },
        { condition = story_elapsed_check(3) },
        {
          condition = story_elapsed_check(2),
          action = function()
            story_jump_to(storage.story, "start")
          end
        }
      }
    }

    tip_story_init(story_table)
  ]]
}

simulations.spaceship_actions =
{
  init =
  [[
    require("__core__/lualib/story")

    local surface = game.surfaces[1]
    player = game.simulation.create_test_player{name = "SpaceShip Pilot"}
    player.teleport({0, 0}, surface)

    game.simulation.camera_player = player
    game.simulation.camera_position = {0, 0}
    game.simulation.camera_zoom = 1

    storage.character = player.character

    surface.build_checkerboard({{-14, -10}, {14, 10}})

    for y = -3, 3 do
      for x = -6, 6 do
        surface.set_tiles{{name = "spaceship-flooring", position = {x, y}}}
      end
    end

    surface.create_entity{name = "spaceship-control-hub", position = {0, 0}, force = "player"}
    surface.create_entity{name = "spaceship-docking-port", position = {4, 0}, force = "player"}

    local story_table =
    {
      {
        {
          name = "start",
          init = function() game.forces.player.chart(surface, {{-14, -10}, {14, 10}}) end,
          condition = story_elapsed_check(1)
        },
        {
          condition = function() return game.simulation.move_cursor({position = {0, 0}}) end,
          action = function() game.simulation.control_press{control = "open-gui", notify = false} end
        },
        { condition = story_elapsed_check(1.5) },
        {
          condition = function() return game.simulation.move_cursor({position = {4, 0}}) end,
          action = function() game.simulation.control_press{control = "open-gui", notify = false} end
        },
        {
          condition = story_elapsed_check(2),
          action = function()
            story_jump_to(storage.story, "start")
          end
        }
      }
    }

    tip_story_init(story_table)
  ]]
}

apply_default_simulation_mods()

return simulations
