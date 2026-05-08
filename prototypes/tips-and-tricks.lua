local simulations = require("__SpaceShipMod__/prototypes/tips-and-tricks-simulations")

data:extend(
{
  {
    type = "tips-and-tricks-item-category",
    name = "spaceship-mod",
    order = "z[spaceship-mod]"
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-header",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-a[header]",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    }
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-overview",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-b[overview]",
    indent = 1,
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.spaceship_overview
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-station-to-planet-transportation",
    tag = "[item=spaceship-docking-port]",
    category = "spaceship-mod",
    order = "z[spaceship]-c[station-to-planet-transportation]",
    indent = 1,
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.station_to_planet_transportation
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-space-ship-gui",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-d[space-ship-gui]",
    indent = 1,
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.spaceship_gui
  }
})
