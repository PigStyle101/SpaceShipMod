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
            game.simulation.control_up{control = "move-up", notify = false}
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

    player = game.simulation.create_test_player{name = "SpaceShip Pilot"}
    player.teleport((hub and hub.valid and hub.position) or {0, 0}, surface)

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
            local target = (hub and hub.valid and hub.position) or player.position
            return game.simulation.move_cursor({position = target})
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
