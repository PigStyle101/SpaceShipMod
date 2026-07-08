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
    starting_status = "unlocked",
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
    starting_status = "unlocked",
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
    order = "z[spaceship]-d[station-to-planet-transportation]",
    indent = 1,
    starting_status = "unlocked",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.station_to_planet_transportation
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-first-visit-to-new-planet",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-f[first-visit-to-new-planet]",
    indent = 1,
    starting_status = "unlocked",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.first_visit_to_new_planet
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-entering-spaceship-cockpit",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-e[entering-spaceship-cockpit]",
    indent = 1,
    starting_status = "unlocked",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.entering_spaceship_cockpit
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-space-ship-gui",
    tag = "[entity=spaceship-control-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-c[space-ship-gui]",
    indent = 1,
    starting_status = "unlocked",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.spaceship_gui
  },
  {
    type = "tips-and-tricks-item",
    name = "spaceship-mod-creating-space-stations",
    tag = "[entity=space-platform-hub]",
    category = "spaceship-mod",
    order = "z[spaceship]-g[creating-space-stations]",
    indent = 1,
    starting_status = "unlocked",
    trigger =
    {
      type = "research",
      technology = "spaceship-construction"
    },
    simulation = simulations.creating_space_stations
  }
})
