--[[
	
Copyright 2024 Liam Matthews

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

	http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.

]]

--! (If gotten from Steam Workshop) LICENSE is in vehicle_0.xml
--! (If gotten from anywhere else) LICENSE is in LICENSE and vehicle_0.xml

-- Author: Toastery
-- GitHub: https://github.com/Toast732
-- Workshop: https://steamcommunity.com/id/Toastery7/myworkshopfiles/?appid=573090
--
--- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--- If you have any issues, please report them here: https://github.com/nameouschangey/STORMWORKS_VSCodeExtension/issues - by Nameous Changey

ADDON_VERSION = "(0.4.0.26)"
IS_DEVELOPMENT_VERSION = string.match(ADDON_VERSION, "(%d%.%d%.%d%.%d)")

SHORT_ADDON_NAME = "ICM"

---@diagnostic disable:duplicate-doc-field
---@diagnostic disable:duplicate-doc-alias
---@diagnostic disable:duplicate-set-field
---@diagnostic disable:inject-field

-- shortened library names
m = matrix
s = server

ISLAND = {
	FACTION = {
		NEUTRAL = "neutral",
		AI = "ai",
		PLAYER = "player"
	}
}

VEHICLE = {
	STATE = {
		PATHING = "pathing", -- follow path
		HOLDING = "holding", -- hold position
		STATIONARY = "stationary" -- used for turrets
	},
	TYPE = {
		BOAT = "boat",
		LAND = "land",
		PLANE = "plane",
		HELI = "heli",
		TURRET = "turret"
	},
	SPEED = {
		BOAT = 8,
		LAND = 10,
		PLANE = 60,
		HELI = 40,
		MULTIPLIERS = {
			LAND = {
				AGGRESSIVE = 1.25,
				NORMAL = 0.9,
				ROAD = 1,
				BRIDGE = 0.7,
				OFFROAD = 0.75
			}
		}
	}
}

CONVOY = {
	MOVING = "moving",
	WAITING = "waiting"
}

debug_types = {
	[-1] = "all",
	[0] = "chat",
	"error",
	"profiler",
	"map",
	"graph_node",
	"driving",
	"vehicle",
	"function",
	"traceback"
}

time = { -- the time unit in ticks, irl time, not in game
	second = 60,
	minute = 3600,
	hour = 216000,
	day = 5184000
}

MAX_SQUAD_SIZE = 3
MIN_ATTACKING_SQUADS = 2
MAX_ATTACKING_SQUADS = 3

TARGET_VISIBILITY_VISIBLE = "visible"
TARGET_VISIBILITY_INVESTIGATE = "investigate"

REWARD = "reward"
PUNISH = "punish"

RESUPPLY_SQUAD_INDEX = 1

CAPTURE_RADIUS = 1500
RESUPPLY_RADIUS = 200
ISLAND_CAPTURE_AMOUNT_PER_SECOND = 1

WAYPOINT_CONSUME_DISTANCE = 100

explosion_depths = {
	plane = -4,
	land = -4,
	heli = -4,
	boat = -17,
	turret = -999
}

DEFAULT_SPAWNING_DISTANCE = 10 -- the fallback option for how far a vehicle must be away from another in order to not collide, highly reccomended to set tag

CRUISE_HEIGHT = 300
built_locations = {}
flag_prefab = nil
is_dlc_weapons = false
g_debug_speed_multiplier = 1
g_air_vehicles_kamikaze = false

debug_mode_blinker = false -- blinks between showing the vehicle type icon and the vehicle command icon on the map

-- please note: this is not machine learning, this works by making a
-- vehicle spawn less or more often, depending on the damage it did
-- compared to the damage it has taken
ai_training = {
	punishments = {
		-0.1,
		-0.2,
		-0.3,
		-0.5,
		-0.7
	},
	rewards = {
		0.1,
		0.2,
		0.3,
		0.5,
		1
	}
}

scout_requirement = time.minute*40

capture_speeds = {
	1,
	1.5,
	1.75
}

g_holding_pattern = {
	{
		x=500,
		z=500
	},
	{
		x=500,
		z=-500
	},
	{
		x=-500,
		z=-500
	},
	{
		x=-500,
		z=500
	}
}

g_is_air_ready = true
g_is_boats_ready = false
g_count_squads = 0
g_count_attack = 0
g_count_patrol = 0

SQUAD = {
	COMMAND = {
		NONE = "no_command", -- no command
		ATTACK = "attack", -- attack island
		DEFEND = "defend", -- defend island
		INVESTIGATE = "investigate", -- investigate position (player left sight)
		ENGAGE = "engage", -- attack player
		PATROL = "patrol", -- patrol around island
		STAGE = "stage", -- stage attack against island
		RESUPPLY = "resupply", -- resupply ammo
		TURRET = "turret", -- this is a turret
		RETREAT = "retreat", -- not implemented yet, used for retreating
		SCOUT = "scout", -- scout island
		CARGO = "cargo" -- cargo vehicle
	}
}

addon_setup = false

---@class squadron
---@field command string the squadron's command
---@field vehicle_type string the vehicle type this squadron is made up of
---@field role string the role this squadron has
---@field vehicles table<integer, vehicle_object> the vehicles in this squadron
---@field target_island AI_ISLAND|PLAYER_ISLAND|ISLAND|nil the island this squadron is targetting
---@field target_vehicles table<integer, TargetVehicle>|nil the vehicles this squadron is targetting
---@field target_players table<integer, TargetPlayer>|nil the players this squadron is targetting

g_savedata = {
	ai_base_island = nil, ---@type AI_ISLAND
	player_base_island = nil,
	islands = {},
	loaded_islands = {}, -- islands which are loaded
	ai_army = { 
		squadrons = { ---@type table<integer, squadron>
			[RESUPPLY_SQUAD_INDEX] = {
				command = SQUAD.COMMAND.RESUPPLY,
				vehicle_type = "",
				role = "",
				vehicles = {},
				target_island = nil
			}
		},
		squad_vehicles = {} -- stores which squad the vehicles are assigned to, indexed via the vehicle's id, with this we can get the vehicle we want the data for without needing to check every single enemy ai vehicle
	},
	players = {
		online = {}, -- indexed by peer_id, value is steam_id, to index individual_data
		individual_data = {},
		global_data = {}
	},
	player_vehicles = {},
	cargo_vehicles = {},
	constructable_vehicles = {},
	seat_states = {},
	vehicle_list = {},
	prefabs = {}, 
	is_attack = false,
	info = {
		version_history = {
			{
				version = ADDON_VERSION,
				ticks_played = 0,
				backup_g_savedata = {}
			}
		},
		addons = {
			default_conquest_mode = false,
			ai_paths = false
		},
		mods = {
			NSO = false
		},
		setup = false
	},
	tick_counter = 0,
	game_tick_counter = 0,
	sweep_and_prune = { -- used for sweep and prune, capture detection
		flags = { -- only updates order in oncreate and is_world_create
			x = {},
			z = {}
		},
		ai_pairs = {}
	},
	ai_history = {
		has_defended = 0, -- logs the time in ticks the player attacked at
		defended_charge = 0, -- the charge for it to detect the player is attacking, kinda like a capacitor
		scout_death = -1, -- saves the time the scout plane was destroyed, allows the players some time between each time the scout comes
	},
	ai_knowledge = {
		last_seen_positions = {}, -- saves the last spot it saw each player, and at which time (tick counter)
		scout = {}, -- the scout progress of each island
	},
	cache = {
		cargo = {
			island_distances = {
				sea = {},
				land = {},
				air = {}
			},
			best_routes = {}
		}
	},
	cache_stats = {
		reads = 0,
		writes = 0,
		failed_writes = 0,
		resets = 0
	},
	profiler = {
		working = {},
		total = {},
		display = {
			average = {},
			max = {},
			current = {}
		},
		ui_id = nil
	},
	debug = {
		chat = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		error = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		profiler = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		map = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		graph_node = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		driving = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		vehicle = {
			enabled = false,
			default = false,
			needs_setup_on_reload = false
		},
		["function"] = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true
		},
		traceback = {
			enabled = false,
			default = false,
			needs_setup_on_reload = true,
			stack = {}, -- the stack of function calls.
			stack_size = 0, -- the size of the stack, used so we don't actually have to remove things from the stack to save on performance.
			funct_names = {}, -- the names of the functions in the stack, so we can use numberical ids in the stack instead for performance and memory usage.
			funct_count = 0 -- the total number of functions, used to optimise the setup phase for tracebacks.
		}
	},
	tick_extensions = {
		cargo_vehicle_spawn = 0
	},
	graph_nodes = {
		init = false,
		init_debug = false,
		nodes = {}
	},
	flags = {},
	libraries = {
		capture_point_payments = {
			sleep_tracker = {
				normal = 0,
				total = 0
			},
			last_payout = 0.2916666667
		}
	}
}

-- libraries
require("libraries.addon.commands.commands") -- the command library
require("libraries.addon.commands.flags") -- the flag command library

require("libraries.addon.components.addonLocationUtils") -- functions for addon locations and environment mods
require("libraries.addon.components.spawningUtils") -- functions used by the spawn vehicle function
require("libraries.addon.components.tags") -- functions related to getting tags from components inside of mission and environment locations

require("libraries.addon.script.addonCommunication") -- functions for addon to addon communication
require("libraries.addon.script.cache") -- functions relating to the custom 
require("libraries.addon.script.compatibility") -- functions used for making the mod backwards compatible
require("libraries.addon.script.debugging") -- functions for debugging
require("libraries.addon.script.map") -- functions for drawing on the map
require("libraries.addon.script.matrix") -- custom matrix functions
require("libraries.addon.script.pathfinding") -- functions for pathfinding
require("libraries.addon.script.players") -- functions relating to Players
require("libraries.addon.script.safeServer") -- safer functions for the server functions.
require("libraries.addon.script.setup") -- functions for script/world setup.

require("libraries.addon.vehicles.ai") -- functions relating to their AI
require("libraries.addon.vehicles.characters") -- functions for characters, such as setting them into seats.

require("libraries.icm.capturePointPayments") -- controls the payroll system for how many islands you hold.
require("libraries.icm.cargo") -- functions relating to the Convoys and Cargo Vehicles
require("libraries.icm.island") -- functions relating to islands
require("libraries.icm.objective") -- functions for the main objectives.
require("libraries.icm.spawnModifiers") -- functions relating to the Adaptive AI
require("libraries.icm.squad") -- functions for squads

require("libraries.icm.vehicles.vehicleGroup") -- functions for getting the vehicle group_id from the vehicle_id.
require("libraries.icm.vehicles.vehicle") -- functions related to vehicles, and parsing data on them
--require("libraries.icm.vehicles.vehicleFires") -- functions for handling fires on the AI vehicles.

require("libraries.utils.executionQueue") -- functions for queuing functions for conditions to be met.
require("libraries.utils.math") -- custom math functions
require("libraries.utils.string") -- custom string functions
require("libraries.utils.tables") -- custom table functions

--[[
		Functions
--]]

function setupRules()
	d.print("Setting up rules...", true, 0)
	--* holds non configurable settings
	--* made to make all the rules to be in one organised consistant place
	RULES = {
		LOGISTICS = { --? for the logistics/cargo AI
			CARGO = { --? cargo specific rules

				transfer_time = time.minute * 3, -- how long it takes to transfer the cargo

				VEHICLES = { --? rules for the vehicles which transport the cargo
					spawn_time = g_savedata.settings.CONVOY_FREQUENCY -- how long after a cargo vehicle is killed can another be spawned
				},
				ISLANDS = { --? rules for the islands
					max_capacity = 10000 *  g_savedata.settings.CARGO_CAPACITY_MULTIPLIER, -- the max amount of each resource islands can hold
					ai_base_generation = 350 -- the amount of cargo the ai's main base can generate per hour
				}
			},
			CONVOY = { --? convoy specific rules
				min_escorts = 2, -- minimum amount of escorts in a convoy
				max_escorts = 4, -- maximum amount of escorts in a convoy
				base_wait_time = time.second * 45, -- the time a vehicle will wait till it just continues anyways
				boat = { --? rules specific for boats
					min_distance = 50, -- have the one behind stop
					target_distance = 150, -- + spawning distance of both vehicles
					max_distance = 400
				},
				land = { --? rules specific for land vehicles
					min_distance = 15,
					target_distance = 60, -- + spawning distance of both vehicles
					max_distance = 120
				},
				plane = { --? rules specific for planes
					min_distance = 75, -- make the one in front have its target altitude be higher
					target_distance = 250, -- + spawning distance of both vehicles 
					max_distance = 1000 -- lots of buffer space, however, do not wait if one is falling behind
				},
				heli = { --? rules specific for helis
					min_distance = 55, -- make the one behind stop moving so it gives it space
					target_distance = 150, -- + spawning distance of both vehicles
					max_distance = 450 -- have them wait for the one which is behind
				}
			},
			COSTS = {
				RESOURCE_VALUES = { -- how much each litre of resource is worth
					oil = 10, -- non jet or diesel vehicles (turrets, electric vehicles, etc)
					diesel = 10, -- diesel vehicles
					jet_fuel = 10 -- jet vehicles
				}
			}
		},
		SETTINGS = { --? for the settings command
			--[[
			EXAMPLE = { -- the setting variable itself
				min = { -- set to nil to ignore
					value = 0, -- if they're trying to set the setting below or at this value, it will warn them
					message = "This can cause the ai to have 0 health, causing them to be instantly killed"
				}, 
				max = { -- set to nil to ignore
					value = 100, -- if they're trying to set the setting above or at this value, it will warn them
					message = "This can cause the ai to have infinite health, causing them to never be killed"
				},
				input_multiplier = time.minute -- the multiplier for the input, so they can enter in minutes instead of ticks, for example
			}
			]]
			ENEMY_HP_MODIFIER = {
				min = {
					value = 0,
					message = "the AI to have 0 health, causing them to be instantly killed without taking any damage."
				},
				max = nil,
				input_multiplier = 1
			},
			AI_PRODUCTION_TIME_BASE = {
				min = {
					value = 0,
					message = "the AI to produce vehicles instantly, causing a constant tps drop and possibly crashing your game."
				},
				max = nil,
				input_multiplier = time.minute
			},
			CAPTURE_TIME = {
				min = {
					value = 0,
					message = "all of the islands to constantly switch factions, creating a huge tps drop due to the amount of notifcation windows, or for no islands to be capturable, or for all islands to be suddenly given to the player."
				},
				max = nil,
				input_multiplier = time.minute
			},
			ISLAND_COUNT = {
				min = {
					value = 1,
					message = "the addon breaking completely and permanently. There needs to be at least 2 islands, 1 for ai's main base, 1 for your main base, this can cause issues."
				},
				max = {
					value = 22,
					message = "improper calculations and lower performance. There are currently only 21 islands which you can have, setting it above 21 can cause issues."
				},
				input_multiplier = 1
			},
			CARGO_GENERATION_MULTIPLIER = {
				min = {
					value = 0,
					message = "no cargo being generated. If you want to disable cargo, do \"?impwep setting CARGO_MODE false\" instead."
				},
				max = nil,
				input_multiplier = 1
			},
			CARGO_CAPACITY_MULTIPLIER = {
				min = {
					value = 0,
					message = "no cargo being stored or generated at islands. If you want to disable cargo mode, do \"?impwep setting CARGO_MODE false\" instead."
				},
				max = nil,
				input_multiplier = 1
			},
			CONVOY_FREQUENCY = {
				min = nil,
				max = nil,
				input_multiplier = time.minute
			},
			CARGO_VEHICLE_DESPAWN_TIMER = {
				min = nil,
				max = nil,
				input_multiplier = time.minute
			}
		}
	}
end

function warningChecks(peer_id)
	-- check for if they have the weapons dlc enabled

	if not s.dlcWeapons() then
		d.print("ERROR: it seems you do not have the weapons dlc enabled, or you do not have the weapon dlc, the addon will not function!", false, 1, peer_id)
	end
	
	-- check if they left the default addon enabled
	if g_savedata.info.addons.default_conquest_mode then
		d.print("ERROR: The default addon for conquest mode was left enabled! This will cause issues and bugs! Please create a new world with the default addon disabled!", false, 1, peer_id)
		is_dlc_weapons = false

	elseif not g_savedata.info.addons.ai_paths then
		d.print("ERROR: The AI Paths addon was left disabled! This addon uses it for pathfinding for the ships, you may have issues with the ship's pathfinding! Please make a new world with the \"AI Paths\" Addon enabled", false, 1, peer_id)
	end

	-- if they are in a development verison
	if IS_DEVELOPMENT_VERSION then
		d.print("Hey! Thanks for using and testing a development version! Just note you will very likely experience errors!", false, 0, peer_id)
		--d.print("VERY COOL DEBUG VERSION!", false, 0, peer_id)
	end

	-- get version data, to check if world is outdated
	--[[local version_data, is_success = comp.getVersionData()
	if version_data.is_outdated then
		d.print("ERROR: world seems to be outdated, this shouldn't be possible!", false, 1, peer_id)
		--[[
		if IS_COMPATIBLE_WITH_OLDER_VERSIONS == "FALSE" then
			d.print("WARNING: This world is outdated, and this version has been marked as uncompatible with older worlds! If you encounter any errors, try using \"?impwep full_reload\", however this command is very dangerous, and theres no guarentees it will fix the issue", false, 1, peer_id)
		elseif IS_COMPATIBLE_WITH_OLDER_VERSIONS == "FULL_RELOAD" then
			d.print("WARNING: This world is outdated, and this version has been marked as uncompatible with older worlds! However, this is fixable via ?impwep full_reload (tested).", false, 1, peer_id)
		end
	end]]

	if g_savedata.info.mods.NSO then
		d.print("ICM has automatically detected the use of the NSO mod. ICM has official support for NSO, so things have been moved around and added to give a great experience with NSO.", false, 0, peer_id)
	end
end

--[[ 

	checkbox settings

	seems like really dumb code, but for the checkboxes to be default true, we have to do this strange workaround.
	
	to have it default true, you must wrap true in quotes.
	you also cannot have any commas inside of the text, for checkboxes and sliders, as that will break it
]]

local PERFORMANCE_MODE = property.checkbox("Performance Mode (Disables tracebacks.)", false)
local SINKING_MODE = property.checkbox("Sinking Mode (Ships sink then explode.)", "true")
local ISLAND_CONTESTING = property.checkbox("Point Contesting (Factions block eachothers progress when they're both trying to capture the same point)", "true")
local CARGO_MODE = property.checkbox("Cargo Mode (AI needs to transport resources to make more vehicles.)", "true")
local AIR_CRASH_MODE = property.checkbox("Air Crash Mode (Air vehicles explode whenever they crash.)", "true")
local PAUSE_WHEN_NONE_ONLINE = property.checkbox("Pause the addon when nobody's online (For dedicated servers - so the AI doesn't keep advancing when people are asleep.)", "true")
local CAPTURE_POINT_PAYMENTS = property.checkbox("Capture Point Payments (Get weekly payments for how many capture points you hold.)", "true")

function onCreate(is_world_create)

	-- setup settings
	if not g_savedata.settings then
		g_savedata.settings = {
			PERFORMANCE_MODE = PERFORMANCE_MODE,
			SINKING_MODE = SINKING_MODE,
			CONTESTED_MODE = ISLAND_CONTESTING,
			CARGO_MODE = CARGO_MODE,
			AIR_CRASH_MODE = AIR_CRASH_MODE,
			CAPTURE_POINT_PAYMENTS = CAPTURE_POINT_PAYMENTS,
			ENEMY_HP_MODIFIER = property.slider("AI HP Modifier", 0.1, 10, 0.1, 1),
			AI_PRODUCTION_TIME_BASE = property.slider("AI Production Time (Mins)", 1, 60, 1, 15) * 60 * 60,
			CAPTURE_TIME = property.slider("AI Capture Time (Mins) | Player Capture Time (Mins) / 5", 10, 600, 1, 60) * 60 * 60,
			MAX_BOAT_AMOUNT = property.slider("Max amount of AI Ships", 0, 40, 1, 10),
			MAX_LAND_AMOUNT = property.slider("Max amount of AI Land Vehicles", 0, 40, 1, 10),
			MAX_PLANE_AMOUNT = property.slider("Max amount of AI Planes", 0, 40, 1, 10),
			MAX_HELI_AMOUNT = property.slider("Max amount of AI Helicopters", 0, 40, 1, 10),
			MAX_TURRET_AMOUNT = property.slider("Max amount of AI Turrets (Per island)", 0, 7, 1, 3),
			AI_INITIAL_SPAWN_COUNT = property.slider("AI Initial Spawn Count", 0, 30, 1, 5),
			AI_INITIAL_ISLAND_AMOUNT = property.slider("Percent of Islands which are AI", 0, 100, 1, 20) * 0.01,
			ISLAND_COUNT = property.slider("Percent of Islands that are available", 0, 100, 1,100) * 0.01,
			CARGO_GENERATION_MULTIPLIER = property.slider("Cargo Generation Multiplier (multiplies cargo generated by this)", 0.1, 5, 0.1, 1),
			CARGO_CAPACITY_MULTIPLIER = property.slider("Cargo Capacity Multiplier (multiplier for capacity of each island)", 0.1, 5, 0.1, 1),
			CONVOY_FREQUENCY = property.slider("Cargo Convoy Cooldown (Mins)", 5, 60, 1, 30) * 60 * 60,
			CARGO_VEHICLE_DESPAWN_TIMER = property.slider("Cargo Vehicle Despawn Timer (Mins)", 0, 120, 1, 60) * time.minute,
			PAUSE_WHEN_NONE_ONLINE = PAUSE_WHEN_NONE_ONLINE,
		}

		g_savedata.debug.traceback.default = not g_savedata.settings.PERFORMANCE_MODE
	end

	-- checks for AI Paths addon
	g_savedata.info.addons.ai_paths = table.pack(s.getAddonIndex("AI Paths"))[2]

	c.overrides() -- override some functions

	ac.executeOnReply( -- setup world after 1 tick, to prevent issues with the addon indexes getting mixed up
		SHORT_ADDON_NAME, -- addon we're expecting the reply from
		"onCreate()", -- the message content
		0, -- the port to recieve this from
		function()
			setupMain(is_world_create)
		end, -- function to execute when we get the reply
		1, -- how many times this can be triggered
		20 -- how many seconds to wait till we expire it
	)

	ac.sendCommunication("onCreate()", 0)

	if is_world_create then
		d.print("Setting up ICM for the first time, this may take a few seconds.", false, 0)
	end
end

function setupMain(is_world_create)

	is_dlc_weapons = s.dlcWeapons()

	-- checks for Vanilla Conquest Mode addon
	local _, is_success = s.getAddonIndex("DLC Weapons AI")
	if is_success then
		g_savedata.info.addons.default_conquest_mode = true
		is_dlc_weapons = false
	end

	-- start the timer for when the world has started to be setup
	local world_setup_time = s.getTimeMillisec()

	comp.verify() -- backwards compatibility check

	-- check for NSO mod
	local nso_tile, got_nso_tile = s.getTile(m.translation(-8000, 0, -12000))
	g_savedata.info.mods.NSO = got_nso_tile and nso_tile.cost > 0

	warningChecks(-1)

	if is_dlc_weapons then

		setupRules()

		p.updatePathfinding()

		d.print("building locations and prefabs...", true, 0)

		sup.createVehiclePrefabs()

		if is_world_create then
			d.print("setting up world...", true, 0)

			d.print("getting y level of all graph nodes...", true, 0)

			--[[ 
				cause createPathY to execute, which will get the y level of all graph nodes
				otherwise the game would freeze for a bit after the player loaded in, looking like the game froze
				instead it looks like its taking a bit longer to create the world.
			]]
			s.pathfind(m.translation(0, 0, 0), m.translation(0, 0, 0), "", "") 

			d.print("setting up spawn zones...", true, 0)

			local spawn_zones = sup.spawnZones()

			-- add them to a list indexed by which island the zone belongs to
			-- local tile_zones = sup.sortSpawnZones(spawn_zones)

			d.print("populating constructable vehicles with spawning modifiers...", true, 0)

			sm.create()

			local start_island = s.getStartIsland()

			d.print("creating player's main base...", true, 0)

			-- init player base
			local islands = s.getZones("capture")

			-- filter NSO and non NSO exclusive islands
			for island_index, island in pairs(islands) do
				if not g_savedata.info.mods.NSO and Tags.has(island.tags, "NSO") then
					d.print("removed "..island.name.." because it is NSO exclusive", true, 0)
					table.remove(islands, island_index)
				elseif g_savedata.info.mods.NSO and Tags.has(island.tags, "not_NSO") then
					table.remove(islands, island_index)
					d.print("removed "..island.name.." because it's incompatible with NSO", true, 0)
				end
			end

			for island_index, island in ipairs(islands) do

				local island_tile = s.getTile(island.transform)
				if island_tile.name == start_island.name or (island_tile.name == "data/tiles/island_43_multiplayer_base.xml" and g_savedata.player_base_island == nil) then
					if not Tags.has(island, "not_main_base") then
						local flag = s.spawnAddonComponent(m.multiply(island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
						---@class PLAYER_ISLAND
						g_savedata.player_base_island = {
							name = island.name,
							index = island_index,
							flag_vehicle = flag,
							transform = island.transform,
							tags = island.tags,
							faction = ISLAND.FACTION.PLAYER,
							is_contested = false,
							capture_timer = g_savedata.settings.CAPTURE_TIME,
							ui_id = server.getMapID() --[[@as SWUI_ID]],
							assigned_squad_index = -1,
							zones = {
								turrets = {},
								land = {},
								sea = {}
							},
							payroll_multiplier = Tags.getValue(island.tags, "payroll_multiplier", false) or 1,
							ai_capturing = 0,
							players_capturing = 0,
							defenders = 0,
							is_scouting = false,
							last_defended = 0,
							cargo = {
								oil = 0,
								jet_fuel = 0,
								diesel = 0
							},
							cargo_transfer = {
								oil = 0,
								jet_fuel = 0,
								diesel = 0
							},
							object_type = "island"
						}
						
						-- only break if the island's name is the same as the island the player is starting at
						-- as breaking if its the multiplayer base could cause the player to always start at the multiplayer base in specific scenarios
						if island_tile.name == start_island.name then
							break
						end
					end
				end
			end

			d.print("Setup Player island: "..g_savedata.player_base_island.index.." \""..g_savedata.player_base_island.name.."\"", true, 0)

			islands[g_savedata.player_base_island.index] = nil

			d.print("creating ai's main base...", true, 0)


			-- get all possible AI base islands and put them into a table along with their distance
			local possible_ai_islands = {}
			for island_index, island in pairs(islands) do
				local distance = m.xzDistance(island.transform, g_savedata.player_base_island.transform)
				if not Tags.has(island.tags, "not_main_base") and not Tags.has(island.tags, "not_main_base_ai") then
					table.insert(possible_ai_islands, {
						distance = distance,
						index = island_index
					})
				end
			end
			-- sort all the islands by distance, greatest to least
			table.sort(possible_ai_islands, function(a, b) return a.distance > b.distance end)

			-- set the ai's main base as a random one of the furthest 25% of the islands
			local ai_base_index = possible_ai_islands[math.random(math.ceil(#possible_ai_islands * 0.25))].index

			-- haha harbour base override go brr
			--[[
			for island_index, island in pairs(islands) do
				if island.name == "Harbour Base" then
					ai_base_index = island_index
					d.print("haha harbour base override go brr", false, 0)
				end
			end
			]]

			d.print("AI base index:"..tostring(ai_base_index), true, 0)

			--* set up ai base

			local ai_island = islands[ai_base_index]

			--local island_tile, is_success = s.getTile(ai_island.transform)

			local flag = s.spawnAddonComponent(m.multiply(ai_island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
			---@class AI_ISLAND
			g_savedata.ai_base_island = {
				name = ai_island.name,
				index = ai_base_index,
				flag_vehicle = flag,
				transform = ai_island.transform,
				tags = ai_island.tags,
				faction = ISLAND.FACTION.AI,
				is_contested = false,
				capture_timer = 0,
				ui_id = server.getMapID() --[[@as SWUI_ID]],
				assigned_squad_index = -1,
				production_timer = 0,
				zones = {
					turrets = {},
					land = {},
					sea = {}
				},
				ai_capturing = 0,
				players_capturing = 0,
				defenders = 0,
				is_scouting = false,
				last_defended = 0,
				cargo = {
					oil = 7500,
					jet_fuel = 7500,
					diesel = 7500
				},
				cargo_transfer = {
					oil = 0,
					jet_fuel = 0,
					diesel = 0
				},
				object_type = "island"
			}

			d.print("Setup AI Base island: "..g_savedata.ai_base_island.index.." \""..g_savedata.ai_base_island.name.."\"", true, 0)

			--g_savedata.ai_base_island.zones = tile_zones[island_tile.name]

			islands[ai_base_index] = nil

			d.print("setting up remaining neutral islands...", true, 0)

			local islands_count = table.length(islands) * g_savedata.settings.ISLAND_COUNT

			-- set up remaining neutral islands
			for island_index, island in pairs(islands) do
				local island_tile, _ = s.getTile(island.transform)

				local flag = s.spawnAddonComponent(m.multiply(island.transform, flag_prefab.transform), s.getAddonIndex(), flag_prefab.location_index, flag_prefab.object_index, 0)
				---@class ISLAND
				local new_island = {
					name = island.name,
					index = island_index,
					flag_vehicle = flag,
					transform = island.transform,
					tags = island.tags,
					faction = ISLAND.FACTION.NEUTRAL,
					is_contested = false,
					capture_timer = g_savedata.settings.CAPTURE_TIME / 2,
					ui_id = server.getMapID() --[[@as SWUI_ID]],
					assigned_squad_index = -1,
					zones = {
						turrets = {},
						land = {},
						sea = {}
					},
					payroll_multiplier = Tags.getValue(island.tags, "payroll_multiplier", false) or 1,
					ai_capturing = 0,
					players_capturing = 0,
					defenders = 0,
					is_scouting = false,
					last_defended = 0,
					cargo = {
						oil = 0,
						jet_fuel = 0,
						diesel = 0
					},
					cargo_transfer = {
						oil = 0,
						jet_fuel = 0,
						diesel = 0
					},
					object_type = "island"
				}

				--new_island.zones = tile_zones[island_tile.name]

				g_savedata.islands[new_island.index] = new_island
				d.print("Setup neutral island: "..new_island.index.." \""..island.name.."\"", true, 0)

				-- stop creating new islands if we've reached the island limit
				if(table.length(g_savedata.islands) >= islands_count) then
					break
				end
			end

			-- link the zones to the island which is closest to the zone

			for zone_type, zones in pairs(spawn_zones) do

				for _, zone in ipairs(zones) do

					-- first, check if this zone has a tag indicating which island it belongs to
					if Tags.has(zone.tags, "owner", true) then
						local owner_name = Tags.getValue(zone.tags, "owner", true)

						if not owner_name then
							d.print("zone says it has a owner, but failed to get the name of the owner!", true, 1)
							goto setupMain_setupIslands_setupZones_continue_zone
						end

						-- find the capture point which shares the name of the zone's owner override
						
						-- check ai base island
						if g_savedata.ai_base_island.name == owner_name then
							table.insert(g_savedata.ai_base_island.zones[zone_type], zone)
							goto setupMain_setupIslands_setupZones_continue_zone
						end

						-- check player base island
						if g_savedata.player_base_island.name == owner_name then
							table.insert(g_savedata.player_base_island.zones[zone_type], zone)
							goto setupMain_setupIslands_setupZones_continue_zone
						end

						-- check other islands
						for _, island in pairs(g_savedata.islands) do
							if island.name == owner_name then
								table.insert(island.zones[zone_type], zone)
								goto setupMain_setupIslands_setupZones_continue_zone
							end
						end
					end
				
					-- get start with distance from ai island
					local closest_island = g_savedata.ai_base_island
					local closest_distance = matrix.xzDistance(zone.transform, g_savedata.ai_base_island.transform)

					-- check if player base is closer
					local player_island_distance = matrix.xzDistance(zone.transform, g_savedata.player_base_island.transform)
					if closest_distance > player_island_distance then
						closest_distance = player_island_distance
						closest_island = g_savedata.player_base_island --[[@as PLAYER_ISLAND]]
					end

					-- check all of the other islands
					for _, island in pairs(g_savedata.islands) do
						local island_distance = matrix.xzDistance(zone.transform, island.transform)
						if closest_distance > island_distance then
							closest_distance = island_distance
							closest_island = island
						end
					end

					-- add to the island which was closest, if its within 2000m
					if closest_distance <= 2000 then
						table.insert(closest_island.zones[zone_type], zone)
					end

					::setupMain_setupIslands_setupZones_continue_zone::
				end
			end
			d.print("setting up additional data...")

			-- sets up their positions for sweep and prune
			for island_index, island in pairs(g_savedata.islands) do
				table.insert(g_savedata.sweep_and_prune.flags.x, { 
					island_index = island.index,
					x = island.transform[13]
				})
				table.insert(g_savedata.sweep_and_prune.flags.z, { 
					island_index = island.index,
					z = island.transform[15]
				})
			end

			-- sort the islands from least to most by their x coordinate
			table.sort(g_savedata.sweep_and_prune.flags.x, function(a, b) return a.x < b.x end)
			-- sort the islands from least to most by their z coordinate
			table.sort(g_savedata.sweep_and_prune.flags.z, function(a, b) return a.z < b.z end)

			-- sets up scouting data
			for _, island in pairs(g_savedata.islands) do
				table.tabulate(g_savedata.ai_knowledge.scout, island.name)
				g_savedata.ai_knowledge.scout[island.name].scouted = 0
			end

			-- calculate number of islands to capture
			local islands_to_capture = math.floor(islands_count * g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT)

			-- AI captures set amount of islands
			for i = 1, islands_to_capture do
				local t, _ = Objective.getIslandToAttack()
				t.capture_timer = 0 -- causes the AI to capture nearest ally
				t.faction = ISLAND.FACTION.AI
				t.cargo = {
					oil = math.random(550, 2000),
					jet_fuel = math.random(550, 2000),
					diesel = math.random(550, 2000)
				}
			end

			d.print("completed setting up world!", true, 0)

			d.print("spawning initial ai vehicles...", true, 0)
				
			for i = 1, g_savedata.settings.AI_INITIAL_SPAWN_COUNT * math.ceil(math.min(math.max(g_savedata.settings.AI_INITIAL_ISLAND_AMOUNT, 1), #g_savedata.islands - 1)/2) do
				v.spawnRetry(nil, nil, true, nil, nil, 5) -- spawn initial ai
			end
			d.print("all initial ai vehicles spawned!")
		else
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for _, vehicle_object in pairs(squad.vehicles) do

					-- Reset map for all of the vehicles
					s.removeMapObject(-1, vehicle_object.ui_id)
					s.removeMapLabel(-1, vehicle_object.ui_id)
					s.removeMapLine(-1, vehicle_object.ui_id)
					for i = 0, #vehicle_object.path - 1 do
						local waypoint = vehicle_object.path[i]
						if waypoint then
							s.removeMapLine(-1, waypoint.ui_id)
						end
					end

					-- Reset the transform histories.
					vehicle_object.transform_history = {}
				end
			end
			s.removeMapObject(-1, g_savedata.player_base_island.ui_id)
			s.removeMapObject(-1, g_savedata.ai_base_island.ui_id)
		end
	end

	g_savedata.info.setup = true
	-- this one will reset every reload/load of the world, this ensures that tracebacks wont be enabled before setupMain is finished.
	addon_setup = true

	for debug_type, debug_setting in pairs(g_savedata.debug) do
		if (debug_setting.needs_setup_on_reload and debug_setting.enabled) or (is_world_create and debug_setting.default) then
			local debug_id = d.debugIDFromType(debug_type)

			if debug_setting.needs_setup_on_reload then
				d.handleDebug(debug_id, true, 0)
			end

			d.setDebug(debug_id, -1, true)
		end
	end

	d.print(("%s%.3f%s"):format("ICM setup complete! took: ", millisecondsSince(world_setup_time)/1000, "s"), true, 0)
end

function onCaptureIsland(island, new_faction, old_faction) -- triggers whenever an island is captured
	-- reset cached cargo best routes
	d.print("Clearing cached cargo best routes", true, 0)
	Cache.reset("cargo_best_routes")
end

function captureIsland(island, override, peer_id)
	local faction_to_set = nil

	if not override then
		if island.capture_timer <= 0 and island.faction ~= ISLAND.FACTION.AI then -- Player Lost Island
			faction_to_set = ISLAND.FACTION.AI
		elseif island.capture_timer >= g_savedata.settings.CAPTURE_TIME and island.faction ~= ISLAND.FACTION.PLAYER then -- Player Captured Island
			faction_to_set = ISLAND.FACTION.PLAYER
		end
	end

	-- set it to the override, otherwise if its supposted to be capped then set it to the specified, otherwise set it to ignore
	faction_to_set = override or faction_to_set or "ignore"

	-- set it to ai
	if faction_to_set == ISLAND.FACTION.AI then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = 0
		island.faction = ISLAND.FACTION.AI
		g_savedata.is_attack = false
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND CAPTURED", "The enemy has captured "..island.name..". (set manually by "..name.." via command)", 3)
		else
			s.notify(-1, "ISLAND CAPTURED", "The enemy has captured "..island.name..".", 3)
		end

		island.is_scouting = false
		g_savedata.ai_knowledge.scout[island.name].scouted = scout_requirement

		sm.train(REWARD, "defend", 4)
		sm.train(PUNISH, "attack", 5)

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad.command == SQUAD.COMMAND.ATTACK or squad.command == SQUAD.COMMAND.STAGE then
				setSquadCommand(squad, SQUAD.COMMAND.NONE) -- free squads from objective
			end
		end
	-- set it to player
	elseif faction_to_set == ISLAND.FACTION.PLAYER then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
		island.faction = ISLAND.FACTION.PLAYER
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND CAPTURED", "Successfully captured "..island.name..". (set manually by "..name.." via command)", 4)
		else
			s.notify(-1, "ISLAND CAPTURED", "Successfully captured "..island.name..".", 4)
		end

		g_savedata.ai_knowledge.scout[island.name].scouted = 0

		sm.train(REWARD, "defend", 1)
		sm.train(REWARD, "attack", 2)

		-- update vehicles looking to resupply
		for _, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	-- set it to neutral
	elseif faction_to_set == ISLAND.FACTION.NEUTRAL then
		onCaptureIsland(island, faction_to_set, island.faction)
		island.capture_timer = g_savedata.settings.CAPTURE_TIME/2
		island.faction = ISLAND.FACTION.NEUTRAL
		updatePeerIslandMapData(-1, island)

		if peer_id then
			name = s.getPlayerName(peer_id)
			s.notify(-1, "ISLAND SET NEUTRAL", "Successfully set "..island.name..". (set manually by "..name.." via command)", 1)
		else
			s.notify(-1, "ISLAND SET NEUTRAL", "Successfully set "..island.name..".", 1)
		end

		island.is_scouting = false
		g_savedata.ai_knowledge.scout[island.name].scouted = 0

		-- update vehicles looking to resupply
		for _, vehicle_object in pairs(g_savedata.ai_army.squadrons[1].vehicles) do
			p.resetPath(vehicle_object)
		end
	elseif island.capture_timer > g_savedata.settings.CAPTURE_TIME then -- if its over 100% island capture
		island.capture_timer = g_savedata.settings.CAPTURE_TIME
	elseif island.capture_timer < 0 then -- if its less than 0% island capture
		island.capture_timer = 0
	end
end

function onPlayerJoin(steam_id, name, peer_id)

	if not g_savedata.info.setup then
		d.print("Setting up ICM for the first time, this may take a few seconds.", false, 0, peer_id)
	end

	eq.queue(
		function()
			return is_dlc_weapons and addon_setup
		end,
		function(self)

			local peer_id = self:getVar("peer_id")
			local steam_id = self:getVar("steam_id")

			Players.onJoin(steam_id, peer_id)

			warningChecks(peer_id)

			for _, island in pairs(g_savedata.islands) do
				updatePeerIslandMapData(peer_id, island)
			end
	
			s.removeMapObject(peer_id, g_savedata.ai_base_island.ui_id)
			s.addMapObject(peer_id, g_savedata.ai_base_island.ui_id, 0, 10, g_savedata.ai_base_island.transform[13], g_savedata.ai_base_island.transform[15], 0, 0, 0, 0, g_savedata.ai_base_island.name.." ("..g_savedata.ai_base_island.faction..")", 1, "", 255, 0, 0, 255)
	
			s.removeMapObject(peer_id, g_savedata.player_base_island.ui_id)
			s.addMapObject(peer_id, g_savedata.player_base_island.ui_id, 0, 10, g_savedata.player_base_island.transform[13], g_savedata.player_base_island.transform[15], 0, 0, 0, 0, g_savedata.player_base_island.name.." ("..g_savedata.player_base_island.faction..")", 1, "", 0, 255, 0, 255)
		
			local player = Players.dataBySID(steam_id)

			if player then
				for debug_type, debug_data in pairs(g_savedata.debug) do
					if debug_data.auto_enable then
						d.setDebug(d.debugIDFromType(debug_type), peer_id, true)
					end
				end
			end
		end,
		{
			peer_id = peer_id,
			steam_id = tostring(steam_id)
		},
		1,
		-1
	)
end

function onVehicleDamaged(vehicle_id, amount, x, y, z, body_id)
	if not is_dlc_weapons then
		return
	end

	-- get the group_id of this vehicle.
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil.
	if not group_id then
		d.print(("Vehicle %s was damaged, but getting it's group_id failed!"):format(vehicle_id), true, 1)
		return
	end

	local player_vehicle = g_savedata.player_vehicles[vehicle_id]

	if player_vehicle then
		local damage_prev = player_vehicle.current_damage
		player_vehicle.current_damage = player_vehicle.current_damage + amount

		if damage_prev <= player_vehicle.damage_threshold and player_vehicle.current_damage > player_vehicle.damage_threshold then
			player_vehicle.death_pos = player_vehicle.transform
		end
		if amount > 0 then -- checks if it was actual damage and not from the player repairing their vehicle
			-- attempts to estimate which vehicles did the damage, as to not favour the vehicles that are closest
			-- give it to all vehicles within 3000m of the player, and that are targeting the player's vehicle
			local valid_ai_vehicles = {}
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then
					for group_id, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.target_vehicle_id == vehicle_id then -- if the ai vehicle is targeting the vehicle which was damaged
							if m.xzDistance(player_vehicle.transform, vehicle_object.transform) <= 2500 and vehicle_object.state.is_simulating then -- if the ai vehicle is 2500m or less away from the player, and is 
								valid_ai_vehicles[group_id] = vehicle_object
							end
						end
					end
				end
			end
			-- <valid ai> = all the enemy ai vehicles within 3000m of the player, and that are targeting the player
			-- <ai amount> = number of <valid ai>
			--
			-- for all the <valid ai>, add the damage dealt to the player / <ai_amount> to their damage dealt property
			-- this is used to tell if that vehicle, the type of vehicle, its strategy and its role was effective
			for _, vehicle_object in pairs(valid_ai_vehicles) do
				-- ensure that the damage dealt field for this group_id is filled.
				vehicle_object.damage_dealt[group_id] = vehicle_object.damage_dealt[group_id] or 0
				vehicle_object.damage_dealt[group_id] = vehicle_object.damage_dealt[group_id] + amount/table.length(valid_ai_vehicles)
			end
		end

	else

		local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)

		if vehicle_object and squad_index then

			--[[VehicleFires.onAIVehicleDamaged(
				vehicle_id,
				{
					x = x,
					y = y,
					z = z
				},
				amount
			)]]

			--d.print(("body_id: %i\ndamage: %s\nmain_body_id: %i"):format(body_id, amount, vehicle_object.main_body), true, 0)

			if body_id == 0 or body_id == vehicle_object.main_body then -- makes sure the damage was on the ai's main body
				if vehicle_object.current_damage == nil then 
					vehicle_object.current_damage = 0
					d.print("reset damage", true, 0)
				end

				local damage_prev = vehicle_object.current_damage
				vehicle_object.current_damage = vehicle_object.current_damage + amount

				--d.print("current damage: "..vehicle_object.current_damage)

				local enemy_hp = vehicle_object.health * g_savedata.settings.ENEMY_HP_MODIFIER

				if g_savedata.settings.SINKING_MODE then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						enemy_hp = enemy_hp * 2.5
					else
						enemy_hp = enemy_hp * 8
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							enemy_hp = enemy_hp * 10
						end
					end
				end

				if damage_prev <= (enemy_hp * 2) and vehicle_object.current_damage > (enemy_hp * 2) then
					d.print("Killing vehicle "..group_id.." instantly, as the damage it took is over twice its max health", true, 0)
					v.kill(vehicle_object, true)
				elseif damage_prev <= enemy_hp and vehicle_object.current_damage > enemy_hp then
					d.print("Killing vehicle "..group_id.." as it took too much damage", true, 0)
					v.kill(vehicle_object)
				end
			end
		end
	end
end

function onVehicleTeleport(vehicle_id, peer_id, x, y, z)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id].current_damage = 0
		end

		local group_id = VehicleGroup.getGroupID(vehicle_id)

		-- Ensure the group_id is not nil
		if not group_id then
			d.print(("Vehicle %s was teleported, but getting it's group_id failed!"):format(vehicle_id), true, 1)
			return
		end

		-- updates the vehicle's position
		local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)
		if squad_index then
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[13] = x
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[14] = y
			g_savedata.ai_army.squadrons[squad_index].vehicles[group_id].transform[15] = z

			--d.print(("Vehicle %s from group %s was teleported to %0.1fx, %0.1fy, %0.1fz."):format(vehicle_id, group_id, x, y, z), true, 0)
		end
	end
end

function onVehicleSpawn(vehicle_id, peer_id, x, y, z, cost)
	if not is_dlc_weapons then
		return
	end

	if pl.isPlayer(peer_id) then
		d.print("Player Spawned Vehicle "..vehicle_id, true, 0)

		-- get the mass of it
		local vehicle_data, is_success = server.getVehicleData(vehicle_id)

		local mass = nil

		if is_success then
			mass = vehicle_data.mass
		end

		-- player spawned vehicle
		g_savedata.player_vehicles[vehicle_id] = {
			current_damage = 0,
			damage_threshold = 100,
			death_pos = nil,
			ui_id = server.getMapID() --[[@as SWUI_ID]],
			mass = mass
		}

		return
	end
end

function onVehicleDespawn(vehicle_id, peer_id)
	if is_dlc_weapons then
		if g_savedata.player_vehicles[vehicle_id] ~= nil then
			g_savedata.player_vehicles[vehicle_id] = nil

			-- make sure to clear this vehicle from all AI
			for _, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.target_vehicles and squad.target_vehicles[vehicle_id] then
					squad.target_vehicles[vehicle_id] = nil

					for _, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.target_vehicle_id then
							vehicle_object.target_vehicle_id = nil
						end
					end
				end
			end
		end
	end

	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil
	if not group_id then
		d.print(("Vehicle %s was despawned, but getting it's group_id failed!"):format(vehicle_id), true, 1)
		return
	end

	--[[
		Don't despawn the vehicle if the vehicle_id that was despawned, is not the main vehicle_id of this vehicle.
	]]

	-- Get the main vehicle_id.
	local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

	-- ensure we got the main_vehicle_id
	if not main_vehicle_id then
		d.print("(onVehicleDespawn) main_vehicle_id is nil", true, 1)
		return
	end

	-- If the vehicle_ids are not equal, return, as it wasn't the main_vehicle_id which was despawned.
	if main_vehicle_id ~= vehicle_id then
		return
	end

	local vehicle_object, squad_index, squad = Squad.getVehicle(group_id)
	d.print("(onVehicleDespawn) group_id: "..group_id.." peer_id: "..peer_id, true, 0)
	if vehicle_object and squad_index then
		d.print("(onVehicleDespawn) AI vehicle: "..vehicle_object.name.." ("..group_id..")", true, 0)
		--VehicleFires.onAIVehicleDespawn(vehicle_id)
		cleanVehicle(squad_index, group_id)
	elseif vehicle_object or squad then
		d.print("(onVehicleDespawn) AI vehicle: "..group_id.." does not have a squad index! squad: "..(squad and "exists" or "doesn't exist").." vehicle_object: "..(vehicle_object and "exists" or "doesn't exist"), true, 0)
	end
end

function cleanVehicle(squad_index, group_id)

	-- get the squadron
	local squadron = g_savedata.ai_army.squadrons[squad_index]

	-- squadron does not exist
	if not squadron then
		d.print(("(cleanVehicle) Squadron %s doesn't exist! Was trying to clean vehicle with group_id %s"):format(squad_index, group_id), true, 1)
		return
	end

	-- get the vehicle_object
	local vehicle_object = squadron.vehicles[group_id]

	if not vehicle_object then
		d.print(("(cleanVehicle) vehicle_object %s doesn't exist! Was trying to clean vehicle from squadron %s"):format(group_id, squad_index), true, 1)

		return
	end

	d.print("cleaning vehicle: "..group_id, true, 0)

	s.removeMapObject(-1, vehicle_object.ui_id)
	s.removeMapLabel(-1, vehicle_object.ui_id)
	s.removeMapLine(-1, vehicle_object.ui_id)
	for i = 0, #vehicle_object.path - 1 do
		local waypoint = vehicle_object.path[i]
		if waypoint then
			s.removeMapLine(-1, waypoint.ui_id)
		end
	end

	s.removeMapLine(-1, vehicle_object.driving.ui_id)

	s.removePopup(-1, vehicle_object.ui_id)

	s.removeMapID(-1, vehicle_object.ui_id)
	s.removeMapID(-1, vehicle_object.driving.ui_id)

	-- remove it from the sweep and prune pairs
	g_savedata.sweep_and_prune.ai_pairs[group_id] = nil

	if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET and vehicle_object.spawnbox_index ~= nil then
		for island_index, island in pairs(g_savedata.islands) do		
			if island.name == vehicle_object.home_island.name then
				island.zones.turrets[vehicle_object.spawnbox_index].is_spawned = false
			end
		end
		-- its from the ai's main base
		if g_savedata.ai_base_island.name == vehicle_object.home_island.name then
			g_savedata.ai_base_island.zones.turrets[vehicle_object.spawnbox_index].is_spawned = false
		end
	end

	for _, object_id in pairs(vehicle_object.survivors) do
		s.despawnObject(object_id, true)
	end

	if vehicle_object.fire_id ~= nil then
		s.despawnObject(vehicle_object.fire_id, true)
	end

	g_savedata.ai_army.squadrons[squad_index].vehicles[group_id] = nil
	g_savedata.ai_army.squad_vehicles[group_id] = nil -- reset squad vehicle list

	if squad_index ~= RESUPPLY_SQUAD_INDEX then
		if table.length(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
			g_savedata.ai_army.squadrons[squad_index] = nil

			for island_index, island in pairs(g_savedata.islands) do
				if island.assigned_squad_index == squad_index then
					island.assigned_squad_index = -1
				end
			end
		end
	end
end

function onVehicleUnload(vehicle_id)
	if not is_dlc_weapons then
		d.print("(onVehicleUnload) is_dlc_weapons is false", true, 0)
		return
	end

	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- Ensure the group_id is not nil
	if not group_id then
		d.print(("Vehicle %s was unloaded, but getting it's group_id failed!"):format(vehicle_id), true, 1)
		return
	end

	local island, got_island = Island.getDataFromGroupID(group_id)
	if got_island and island then
		d.print(("Island %s was unloaded"):format(island.name), true, 0)
		g_savedata.loaded_islands[island.index] = nil
		return
	end

	local vehicle_object, squad_index, _ = Squad.getVehicle(group_id)

	if squad_index and vehicle_object then

		--[[
			Don't mark the vehicle as unloaded if the vehicle_id that was unloaded, is not the main vehicle_id of this vehicle.
		]]

		-- Get the main vehicle_id.
		local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

		-- ensure we got the main_vehicle_id
		if not main_vehicle_id then
			d.print("(onVehicleUnload) main_vehicle_id is nil", true, 1)
			return
		end

		-- If the vehicle_ids are not equal, return, as it wasn't the main_vehicle_id which was despawned.
		if main_vehicle_id ~= vehicle_id then
			return
		end

		-- reset it's transform history
		vehicle_object.transform_history = {}

		if vehicle_object.is_killed == true then
			cleanVehicle(squad_index, group_id)
		else
			d.print("(onVehicleUnload): set vehicle "..group_id.." pseudo. Name: "..vehicle_object.name, true, 0)
			vehicle_object.state.is_simulating = false
		end
	end
end

function setVehicleKeypads(group_id, vehicle_object, squad)
	local squad_vision = squadGetVisionData(squad)
	local target = nil

	local function setKeypad(group_id, keypad_name, value)
		local vehicle_ids = server.getVehicleGroup(group_id)

		if not vehicle_ids then
			d.print(("<line>: Failed to get vehicle group for the group_id: %s"):format(group_id), true, 1)
			return
		end

		if type(vehicle_ids) ~= "table" then
			d.print(("<line>: vehicle_ids is not a table? value: %s type: %s"):format(vehicle_ids, type(vehicle_ids)), true, 1)
			return
		end

		-- Go through each of the vehicles in this group.
		for vehicle_index = 1, #vehicle_ids do
			local vehicle_id = vehicle_ids[vehicle_index]
			-- set the keypad on each vehicle in this group
			server.setVehicleKeypad(vehicle_id, keypad_name, value)
		end
	end

	if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
		target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj

		local target_vehicle_id = vehicle_object.target_vehicle_id

		if g_savedata.player_vehicles[target_vehicle_id] and not g_savedata.player_vehicles[target_vehicle_id].mass then
			local vehicle_data, is_success = s.getVehicleData(target_vehicle_id)

			if is_success then
				g_savedata.player_vehicles[target_vehicle_id].mass = vehicle_data.mass
			end
		end

		if g_savedata.player_vehicles[target_vehicle_id].mass then -- target vehicle's mass
			setKeypad(group_id, "AI_TARGET_MASS", g_savedata.player_vehicles[target_vehicle_id].mass)
		end

	elseif pl.isPlayer(vehicle_object.target_player_id) and squad_vision.visible_players_map[vehicle_object.target_player_id] then

		target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
		setKeypad(group_id, "AI_TARGET_MASS", 50) -- player's mass

	else
		setKeypad(group_id, "AI_TARGET_MASS", 0) -- no target
	end
	if target then -- set the target's position on keypads
		setKeypad(group_id, "AI_TARGET_X", target.last_known_pos[13])
		setKeypad(group_id, "AI_TARGET_Y", target.last_known_pos[14])
		setKeypad(group_id, "AI_TARGET_Z", target.last_known_pos[15])
	end
end

--[[function onObjectLoad(object_id)
	local object_data = server.getObjectData(object_id)

	if object_data.object_type == 58 then -- fire
		VehicleFires.onFireSpawn(object_id, object_data)
	end
end]]

--[[
function onSpawnAddonComponent(id, name, type, addon_index)
	d.print("(onSpawnAddonComponent) id: "..tostring(id).."\nname: "..tostring(name).."\ntype: "..tostring(type).."\naddon_index: "..tostring(addon_index), true, 0)
end]]

--[[function onCharacterSit(object_id, vehicle_id, seat_name)
	d.print(("(onCharacterSit) object_id: %i\nvehicle_id: %i\nseat_name: %s"):format(object_id, vehicle_id, seat_name))
end]]

-- called whenever an AI is properly spawned, data set, and set into seat.
function onCharacterPrepared(object_id, vehicle_id, seat_name)

	-- get the group_id this vehicle is in
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	-- check if we got the group_id
	if not group_id then
		d.print(("(onCharacterPrepared) failed to get group_id for vehicle_id: %s"):format(vehicle_id), true, 0)
		return
	end

	local vehicle_object, _, squad = Squad.getVehicle(group_id)

	-- check if we got the vehicle_object
	if not vehicle_object then
		d.print(("(onCharacterPrepared) failed to get vehicle_object for group_id: %s"):format(group_id), true, 0)
		return
	end

	-- check if we got the squad
	if not squad then
		d.print(("(onCharacterPrepared) failed to get squad for group_id: %s"):format(group_id), true, 0)
		return
	end

	vehicle_object._prepared_survivors = vehicle_object._prepared_survivors or {}
	table.insert(vehicle_object._prepared_survivors, object_id)

	-- if we've prepared all of our survivors
	if #vehicle_object._prepared_survivors == #vehicle_object.survivors then
		vehicle_object._prepared_survivors = nil
		d.print("(onCharacterPrepared) all characters prepared!", true, 0)
		squadInitVehicleCommand(squad, vehicle_object) -- init their commands
	end
end

function onVehicleLoad(vehicle_id)
	-- return if the addon is disabled
	if not is_dlc_weapons then
		return
	end

	-- if this is the players vehicle, get data on it
	if g_savedata.player_vehicles[vehicle_id] ~= nil then
		local player_vehicle_data = s.getVehicleData(vehicle_id)
		if player_vehicle_data.voxels then
			g_savedata.player_vehicles[vehicle_id].damage_threshold = player_vehicle_data.voxels / 4
			g_savedata.player_vehicles[vehicle_id].transform = s.getVehiclePos(vehicle_id)
		end
		return
	end

	-- get the vehicle's group_id
	local group_id = VehicleGroup.getGroupID(vehicle_id)

	if not group_id then
		return
	end

	-- set tooltips for main islands, and mark the island as loaded
	local island, got_island = Island.getDataFromGroupID(group_id)
	if got_island and island then
		g_savedata.loaded_islands[island.index] = true

		if island.index == g_savedata.ai_base_island.index then
			s.setVehicleTooltip(vehicle_id, "AI Main Base, Cannot be Captured.")
		elseif island.index == g_savedata.player_base_island.index then
			s.setVehicleTooltip(vehicle_id, "Your Main Base, Cannot be Captured by AI.")
		end
		return
	end

	-- check if the ai needs to purchase this vehicle
	local vehicle_object, _, _ = Squad.getVehicle(group_id)

	if vehicle_object then
		d.print("(onVehicleLoad) AI Vehicle Loaded: "..tostring(vehicle_object.name), true, 0)
		local prefab, _ = v.getPrefab(vehicle_object.name)

		if not prefab or not prefab.fully_created then
			v.createPrefab(group_id)
		end 

		if vehicle_object.costs.buy_on_load then
			local _, _, was_purchased = v.purchaseVehicle(vehicle_object.name, vehicle_object.home_island.name, vehicle_object.costs.purchase_type)
			if was_purchased then
				vehicle_object.costs.buy_on_load = false
			elseif vehicle_object.costs.purchase_type == 0 then
				d.print("(onVehicleLoad) unable to afford "..vehicle_object.name..", killing vehicle "..group_id, true, 0)
				v.kill(vehicle_object, true, true)
			end
		end
	end

	-- say the vehicle has loaded
	-- spawn the AI npcs if they've not yet been spawned
	-- and make sure its not spawning inside another vehicle
	if vehicle_object then
		d.print("(onVehicleLoad) set vehicle simulating: "..group_id, true, 0)
		d.print("(onVehicleLoad) vehicle name: "..vehicle_object.name, true, 0)
		vehicle_object.state.is_simulating = true

		if #vehicle_object.survivors == 0 then
			vehicle_object.survivors = c.createAndSetCharactersIntoSeat(vehicle_id, c.valid_seats.enemy_ai)
		end

		local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

		-- check to make sure no vehicles are too close, as this could result in them spawning inside each other
		for _, checking_squad in pairs(g_savedata.ai_army.squadrons) do
			for _, checking_vehicle_object in pairs(checking_squad.vehicles) do
				if checking_vehicle_object.group_id ~= group_id then
					if m.distance(vehicle_object.transform, checking_vehicle_object.transform) < (vehicle_object.spawning_transform.distance or DEFAULT_SPAWNING_DISTANCE) + checking_vehicle_object.spawning_transform.distance then
						if not vehicle_object.path[2] then
							d.print("(onVehicleLoad) cancelling spawning vehicle, due to its proximity to vehicle "..group_id, true, 1)

							-- refund the cargo to the island which was sending the cargo
							Cargo.refund(group_id)

							v.kill(vehicle_object, true, true)
							return
						else
							v.teleport(vehicle_object, m.translation(vehicle_object.path[2].x, vehicle_object.path[2].y, vehicle_object.path[2].z))
							break
						end
					end
				end
			end
		end

		--? check if this is a cargo vehicle, if so then set the cargo in its tanks
		if g_savedata.cargo_vehicles[group_id] then
			if main_vehicle_id then
				--* set the cargo in its tanks
				local large_tank_capacity = 703.125

				for tank_set = 1, 3 do
					for tank_id = 0, (vehicle_object.cargo.capacity/large_tank_capacity) - 1 do

						Cargo.setTank(main_vehicle_id, "RESOURCE_TYPE_"..(tank_set-1).."_"..tank_id, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].amount/(vehicle_object.cargo.capacity/large_tank_capacity), true)
					end
					Cargo.setKeypad(main_vehicle_id, "RESOURCE_TYPE_"..(tank_set-1), g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type)

					d.print(("set %sL of %s into tank set %i on cargo vehicle %i"):format(g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].amount, g_savedata.cargo_vehicles[group_id].requested_cargo[tank_set].cargo_type, tank_set, group_id), true, 0)
				end
			else
				d.print(("Could not find main_vehicle_id for cargo vehicle! group_id: %s"):format(group_id), true, 1)
			end
		end

		if vehicle_object.is_resupply_on_load then
			vehicle_object.is_resupply_on_load = false
			
			--Reset the vehicle state and reload					
			if main_vehicle_id then
				-- resetVehicleState current issues: it unseats all its crew, and other bodys inside it like missiles or torpedos will fall out or end up glitched inside it.
				-- also only works when the vehicles loaded
				-- s.resetVehicleState(main_vehicle_id)
				reload(main_vehicle_id)
			else
				d.print(("failed to resupply because main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
			end
		end

		d.print("(onVehicleLoad) #of survivors: "..tostring(#vehicle_object.survivors), true, 0)
		refuel(group_id)
	end
end

function tickGamemode(game_ticks)
	d.startProfiler("tickGamemode()", true)

	-- check squad vehicle positions, every 10 seconds
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do -- go through every squad vehicle
		for vehicle_index, vehicle_object in pairs(squad.vehicles) do -- go through every vehicle in that squad
			if isTickID(vehicle_index, time.second*10) then -- every 10 seconds
				local has_island = false
				-- checks to make sure the target vehicle is valid
				if not vehicle_object.is_killed -- makes sure the vehicle isnt dead
					and vehicle_object.role ~= "scout" -- makes sure the vehicle isn't a scout vehicle
					and vehicle_object.role ~= "cargo" -- makes sure the vehicle isn't a cargo vehicle
					and squad.command ~= SQUAD.COMMAND.RESUPPLY -- makes sure the squad isnt resupplying
					then
					
					if squad.target_island then -- makes sure it has a target island
						has_island = true
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] = squad.target_island -- sets to check this vehicle with its target island in sweep and prune
					end
				end

				if not has_island then -- if it doesnt have a matching island
					if g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] then -- checks if it is in the pre_pairs table
						g_savedata.sweep_and_prune.ai_pairs[vehicle_object.group_id] = nil -- removes it from the pre_pairs table
					end
				end
			end
		end
	end

	-- tick capture rates
	--local capture_tick_rate = g_savedata.settings.CAPTURE_TIME/400/5 -- time it takes for it to move 0.25%
	local capture_tick_rate = 60 -- tick every second.
	if isTickID(0, capture_tick_rate) then -- ticks the time it should take to move 0.25%
		-- check all ai that are within the capture radius
		for group_id, island in pairs(g_savedata.sweep_and_prune.ai_pairs) do
			local vehicle_object, _, _ = Squad.getVehicle(group_id)
			if vehicle_object then

				local capture_radius = island.faction == ISLAND.FACTION.AI and CAPTURE_RADIUS or CAPTURE_RADIUS / 1.5 -- capture radius is normal if the ai owns the island, otherwise its / 1.5

				-- if the ai vehicle is within the capture radius
				-- and the island is not the ai's main island
				-- and the island is not the player's main island
				if m.xzDistance(vehicle_object.transform, island.transform) <= capture_radius and island.index ~= g_savedata.ai_base_island.index and island.index ~= g_savedata.player_base_island.index then
					g_savedata.islands[island.index].ai_capturing = g_savedata.islands[island.index].ai_capturing + 1
				end
			else
				d.print("(tickGamemode) vehicle_object is nil! Group ID: "..tostring(group_id).."\nRemoving from sweep and prune pairs to check", true, 1)
				--local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
				--d.print("vehicle existed before? "..tostring(vehicle_object ~= nil), true, 0)
				g_savedata.sweep_and_prune.ai_pairs[group_id] = nil
				--local vehicle_object, squad, squad_index = Squad.getVehicle(vehicle_id)
				--d.print("vehicle existed after? "..tostring(vehicle_object ~= nil), true, 0)
			end
		end

		-- check all players that are within the capture radius
		for player_index, player in pairs(s.getPlayers()) do -- go through all players
			local player_transform = s.getPlayerPos(player.id)

			local player_x = player_transform[13]
			local player_z = player_transform[15]

			local player_pairs = {
				x = {},
				xz = {},
				data = {
					islands = {},
					players = {}
				}
			}

			-- x axis
			for i = 1, #g_savedata.sweep_and_prune.flags.x do -- for all the flags/capture zones
				local distance = math.abs(player_x-g_savedata.sweep_and_prune.flags.x[i].x) -- gets the x distance between the player and the capture point
				local capture_radius = g_savedata.islands[g_savedata.sweep_and_prune.flags.x[i].island_index].faction == ISLAND.FACTION.PLAYER and CAPTURE_RADIUS / 5 or CAPTURE_RADIUS / 100 -- capture radius / 5 if the player owns the island, otherwise its / 100
				if distance <= capture_radius then -- if they are within the capture radius
					-- get the z coord of the selected island
					local z_coord = nil
					for ii = 1, #g_savedata.sweep_and_prune.flags.z do
						if g_savedata.sweep_and_prune.flags.z[ii].island_index == g_savedata.sweep_and_prune.flags.x[i].island_index then
							z_coord = g_savedata.sweep_and_prune.flags.z[ii].z
							break
						end
					end
					table.insert(player_pairs.x, { -- add them to the pairs in the x table
						peer_id = player.id, 
						island_index = g_savedata.sweep_and_prune.flags.x[i].island_index, 
						z = z_coord,
						distance = distance
					})
				end
			end

			-- z axis
			for i = 1, #player_pairs.x do
				local distance = math.abs(player_z - player_pairs.x[i].z) -- gets the z distance between the player and the capture point
				local capture_radius = g_savedata.islands[g_savedata.sweep_and_prune.flags.z[i].island_index].faction == ISLAND.FACTION.PLAYER and CAPTURE_RADIUS / 5 or CAPTURE_RADIUS / 100 -- capture radius / 5 if the player owns the island, otherwise its / 100
				if distance <= capture_radius then -- if they are within the capture radius
					table.insert(player_pairs.xz, {
						peer_id = player_pairs.x[i].peer_id,
						island_index = player_pairs.x[i].island_index,
						distance = player_pairs.x[i].distance + distance
					})
				end
			end

			-- clean up, if the player is capturing multiple islands, make them only capture the closest one to them
			-- if the island has multiple people capturing it, add them together into one
			for i = 1, #player_pairs.xz do
				local peer_id = player_pairs.xz[i].peer_id
				if not player_pairs.data.players[peer_id] then -- if this is the only island we know the player is capturing so far
					local island_index = player_pairs.xz[i].island_index
					-- player data
					player_pairs.data.players[peer_id] = {
						island_index = island_index,
						distance = player_pairs.xz[i].distance
					}
					-- island data
					player_pairs.data.islands[island_index] = {}
					player_pairs.data.islands[island_index].number_capturing = (player_pairs.data.islands[island_index].number_capturing or 0) + 1
				--[[
					
					! Disabled, as the code would likely error before, as island_index is not defined.
				
				else -- if the player has been detected to be capturing multiple islands
				 local distance = player_pairs.xz[i].distance
					-- if the distance from this island is less than the island that we checked before
					if player_pairs.data.players[peer_id].distance > distance then
						-- changes old island data
						player_pairs.data.islands[player_pairs.data.players[peer_id].island_index].number_capturing = player_pairs.data.islands[island_index].number_capturing - 1 -- remove 1 from the number capturing that island
						-- updates player data
						player_pairs.data.players[peer_id] = {
							island_index = player_pairs.xz[i].island_index,
							distance = distance
						}
						-- updates new island data
						player_pairs.data.islands[island_index].number_capturing = (player_pairs.data.islands[island_index].number_capturing or 0) + 1
					end
				]]
				end
			end

			for island_index, island in pairs(player_pairs.data.islands) do
				g_savedata.islands[island_index].players_capturing = island.number_capturing
			end
		end

		-- tick spawning for ai vehicles (to remove as will be replaced to be dependant on logistics system)
		g_savedata.ai_base_island.production_timer = g_savedata.ai_base_island.production_timer + capture_tick_rate * game_ticks
		if g_savedata.ai_base_island.production_timer > g_savedata.settings.AI_PRODUCTION_TIME_BASE then
			g_savedata.ai_base_island.production_timer = 0

			local spawned, vehicle_data = v.spawn("turret", "turret", false, g_savedata.ai_base_island)
			if not spawned then
				d.print("failed to spawn turret at "..g_savedata.ai_base_island.name.."\nError:\n"..vehicle_data, true, 1)
			end
			
			local spawned, vehicle_data = v.spawn(nil, nil, false, nil, 0)
			if not spawned then
				d.print("failed to spawn vehicle\nError:\n"..vehicle_data, true, 1)
			end
		end

		-- update islands
		for island_index, island in pairs(g_savedata.islands) do

			-- spawn turrets at owned islands (to remove as will be replaced to be dependant on logistics system)
			if island.faction == ISLAND.FACTION.AI and g_savedata.ai_base_island.production_timer == 0 then
				-- check to see if turrets are disabled
				if g_savedata.settings.MAX_TURRET_AMOUNT > 0 then
					local spawned, vehicle_data = v.spawn("turret", "turret", false, island)
					if not spawned then
						d.print("failed to spawn turret at "..island.name.."\nError:\n"..vehicle_data, true, 1)
					end
				end
			end

			-- display new capture data
			if island.players_capturing > 0 and island.ai_capturing > 0 and g_savedata.settings.CONTESTED_MODE then -- if theres ai and players capping, and if contested mode is enabled
				if island.is_contested == false then -- notifies that an island is being contested
					s.notify(-1, "ISLAND CONTESTED", "An island is being contested!", 1)
					island.is_contested = true
				end
			else
				island.is_contested = false
				if island.players_capturing > 0 and g_savedata.settings.CAPTURE_TIME > island.capture_timer then -- tick player progress if theres one or more players capping
					island.capture_timer = island.capture_timer + ((ISLAND_CAPTURE_AMOUNT_PER_SECOND * 5) * capture_speeds[math.min(island.players_capturing, 3)]) * capture_tick_rate * game_ticks

				elseif island.ai_capturing > 0 and 0 < island.capture_timer then -- tick AI progress if theres one or more ai capping
					island.capture_timer = island.capture_timer - (ISLAND_CAPTURE_AMOUNT_PER_SECOND * capture_speeds[math.min(island.ai_capturing, 3)]) * capture_tick_rate * game_ticks
				end
			end

			-- makes sure its within limits
			island.capture_timer = math.clamp(island.capture_timer, 0, g_savedata.settings.CAPTURE_TIME)
			
			-- displays tooltip on vehicle
			local cap_percent = island.capture_timer/g_savedata.settings.CAPTURE_TIME * 100

			local capturing_status = "Revolting" -- should never happen, but why not
			if island.is_contested then -- if the point is contested (both teams trying to cap)
				--s.setVehicleTooltip(island.flag_vehicle.id, "Contested: "..cap_percent.."%")
				capturing_status = "Contested"
				cp_status = "Remove the ${enemy_capturing_count} enemies to resume capturing."
			elseif island.faction ~= ISLAND.FACTION.PLAYER then -- if the player doesn't own the point
				if island.ai_capturing == 0 and island.players_capturing == 0 then -- if nobody is capping the point
					--s.setVehicleTooltip(island.flag_vehicle.id, "Capture: "..cap_percent.."%")
					capturing_status = "Capture"
					cp_status = "Get closer to the capture point to begin capturing."
				elseif island.ai_capturing == 0 then -- if players are capping the point
					--s.setVehicleTooltip(island.flag_vehicle.id, "Capturing: "..cap_percent.."%")
					capturing_status = "Capturing"
					cp_status = "${time_until_faction_change} until under player control."
				else -- if ai is capping the point
					--s.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
					capturing_status = "Losing"
					cp_status = "${time_until_faction_change} until under enemy control."
				end
			else -- if the player does own the point
				if island.ai_capturing == 0 and island.players_capturing == 0 or cap_percent == 100 then -- if nobody is capping the point or its at 100%
					--s.setVehicleTooltip(island.flag_vehicle.id, "Captured: "..cap_percent.."%")
					capturing_status = "Captured"
					cp_status = "Under full player control."
				elseif island.ai_capturing == 0 then -- if players are capping the point
					--s.setVehicleTooltip(island.flag_vehicle.id, "Re-Capturing: "..cap_percent.."%")
					capturing_status = "Re-Capturing"
					cp_status = "${time_until_faction_change} until under full player control."
				else -- if ai is capping the point
					--s.setVehicleTooltip(island.flag_vehicle.id, "Losing: "..cap_percent.."%")
					capturing_status = "Losing"
					cp_status = "${time_until_faction_change} until under enemy control."
				end
			end

			-- format the tooltip
			local capture_vehicle_tooltip = ("%s: %0.2f%%\n%s"):format(capturing_status, cap_percent, cp_status)

			-- format in the field enemy_capturing_count
			capture_vehicle_tooltip = capture_vehicle_tooltip:setField("enemy_capturing_count", island.ai_capturing)

			-- format in the field time_until_faction_change
			if capture_vehicle_tooltip:hasField("time_until_faction_change") then
				-- calculate the time until the faction changes.
				local time_till_faction_change = 0

				local capture_rate = 0
				
				if island.players_capturing > 0 and g_savedata.settings.CAPTURE_TIME > island.capture_timer then -- tick player progress if theres one or more players capping
					capture_rate = ((ISLAND_CAPTURE_AMOUNT_PER_SECOND * 5) * capture_speeds[math.min(island.players_capturing, 3)]) * capture_tick_rate * game_ticks
					
					time_till_faction_change = (g_savedata.settings.CAPTURE_TIME-island.capture_timer)/capture_rate*capture_tick_rate/60

				elseif island.ai_capturing > 0 and 0 < island.capture_timer then -- tick AI progress if theres one or more ai capping
					capture_rate = (ISLAND_CAPTURE_AMOUNT_PER_SECOND * capture_speeds[math.min(island.ai_capturing, 3)]) * capture_tick_rate * game_ticks
					
					time_till_faction_change = island.capture_timer/capture_rate*capture_tick_rate/60
				end

				-- format it into time
				local formatted_timer = string.formatTime(time_formats.yMdhms, time_till_faction_change, false)

				-- set the time_until_faction_change field
				capture_vehicle_tooltip = capture_vehicle_tooltip:setField("time_until_faction_change", formatted_timer, true)

				-- add the capture timer debug if the flag show_capture_timer_debug is enabled 
				if g_savedata.flags.show_capture_timer_debug then
					capture_vehicle_tooltip = capture_vehicle_tooltip..(" capture_rate:%s time_till_faction_change:%s formatted_timer:%s"):format(capture_rate, time_till_faction_change, formatted_timer)
				end
			end

			s.setVehicleTooltip(island.flag_vehicle.id, capture_vehicle_tooltip)

			updatePeerIslandMapData(-1, island)

			-- resets amount capping
			island.ai_capturing = 0
			island.players_capturing = 0
			captureIsland(island)
		end
	end


	-- update ai's main base island debug
	if d.getDebug(3) then
		if isTickID(0, 60) then

			local plane_count = 0
			local heli_count = 0
			local army_count = 0
			local land_count = 0
			local boat_count = 0
			local turret_count = 0
		
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET then army_count = army_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then turret_count = turret_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then boat_count = boat_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then plane_count = plane_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then heli_count = heli_count + 1 end
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then land_count = land_count + 1 end
				end
			end

			local ai_islands = 1
			for island_index, island in pairs(g_savedata.islands) do
				if island.faction == ISLAND.FACTION.AI then
					ai_islands = ai_islands + 1
				end
			end

			local t, a = Objective.getIslandToAttack()

			local ai_base_island_turret_count = 0
			if g_savedata.ai_base_island.zones.turrets then
				for _, turret_zone in pairs(g_savedata.ai_base_island.zones.turrets) do
					if turret_zone.is_spawned then ai_base_island_turret_count = ai_base_island_turret_count + 1 end
				end
			end

			local debug_data = ""
			debug_data = debug_data.."--- This Island's Statistics ---\n\n"
			debug_data = debug_data.."Number of Turrets: "..ai_base_island_turret_count.."/"..g_savedata.settings.MAX_TURRET_AMOUNT.."\n"

			-- cargo
			debug_data = debug_data.."\n-- Cargo --\n"

			debug_data = debug_data.."- Cargo Storage -\n"
			debug_data = debug_data..("%s%.1f%s"):format("Oil: ", g_savedata.ai_base_island.cargo.oil, "\n")
			debug_data = debug_data..("%s%.1f%s"):format("Diesel: ", g_savedata.ai_base_island.cargo.diesel, "\n")
			debug_data = debug_data..("%s%.1f%s"):format("Jet Fuel: ", g_savedata.ai_base_island.cargo.jet_fuel, "\n")


			debug_data = debug_data.."\n--- Global Statistics ---\n\n"
			debug_data = debug_data .. "Total AI Vehicles: "..army_count.."/"..(g_savedata.settings.MAX_BOAT_AMOUNT + g_savedata.settings.MAX_HELI_AMOUNT + g_savedata.settings.MAX_PLANE_AMOUNT + g_savedata.settings.MAX_LAND_AMOUNT).."\n"
			debug_data = debug_data .. "Total Sea Vehicles: "..boat_count.."/"..g_savedata.settings.MAX_BOAT_AMOUNT.."\n"
			debug_data = debug_data .. "Total Helicopters: "..heli_count.."/"..g_savedata.settings.MAX_HELI_AMOUNT.."\n"
			debug_data = debug_data .. "Total Planes: "..plane_count.."/"..g_savedata.settings.MAX_PLANE_AMOUNT.."\n"
			debug_data = debug_data .. "Total Land Vehicles: "..land_count.."/"..g_savedata.settings.MAX_LAND_AMOUNT.."\n"
			debug_data = debug_data .. "Total Turrets: "..turret_count.."/"..g_savedata.settings.MAX_TURRET_AMOUNT*ai_islands.."\n"
			debug_data = debug_data .. "\nNumber of Squads: "..g_count_squads.."\n"

			if t then
				debug_data = debug_data .. "Attacking: " .. t.name .. "\n"
			end
			if a then
				debug_data = debug_data .. " Attacking From: " .. a.name
			end
			local player_list = s.getPlayers()
			for peer_index, peer in pairs(player_list) do
				if d.getDebug(3, peer.id) then
					s.removeMapObject(peer.id, g_savedata.ai_base_island.ui_id)
					s.addMapObject(peer.id, g_savedata.ai_base_island.ui_id, 0, 4, g_savedata.ai_base_island.transform[13], g_savedata.ai_base_island.transform[15], 0, 0, 0, 0, g_savedata.ai_base_island.name.."\nAI Base Island\n"..g_savedata.ai_base_island.production_timer.."/"..g_savedata.settings.AI_PRODUCTION_TIME_BASE.."\nIsland Index: "..g_savedata.ai_base_island.index, 1, debug_data, 255, 0, 0, 255)

					s.removeMapObject(peer.id, g_savedata.player_base_island.ui_id)
					s.addMapObject(peer.id, g_savedata.player_base_island.ui_id, 0, 4, g_savedata.player_base_island.transform[13], g_savedata.player_base_island.transform[15], 0, 0, 0, 0, "Player Base Island", 1, debug_data, 0, 255, 0, 255)
				end
			end
		end
	end
	d.stopProfiler("tickGamemode()", true, "onTick()")
end


---@param peer_id integer the id of the player of which you want to update the map data for
---@param island ISLAND the island you want to update
---@param is_reset boolean? if you want it to just reset the map, which will remove the island from the map instead of updating it
function updatePeerIslandMapData(peer_id, island, is_reset)
	if is_dlc_weapons and g_savedata.info.setup then
		s.removeMapObject(peer_id, island.ui_id)
		if not is_reset then
			local cap_percent = math.floor((island.capture_timer/g_savedata.settings.CAPTURE_TIME) * 100)
			local extra_title = ""
			local r = 75
			local g = 75
			local b = 75
			if island.is_contested then
				r = 255
				g = 255
				b = 0
				extra_title = " CONTESTED"
			elseif island.faction == ISLAND.FACTION.AI then
				r = 255
				g = 0
				b = 0
			elseif island.faction == ISLAND.FACTION.PLAYER then
				r = 0
				g = 255
				b = 0
			end
			if not d.getDebug(3, peer_id) then -- checks to see if the player has debug mode disabled
				s.addMapObject(peer_id, island.ui_id, 0, 9, island.transform[13], island.transform[15], 0, 0, 0, 0, island.name.." ("..island.faction..")"..extra_title, 1, cap_percent.."%", r, g, b, 255)
			else
				if island.transform ~= g_savedata.player_base_island.transform and island.transform ~= g_savedata.ai_base_island.transform then -- makes sure its not trying to update the main islands
					local turret_amount = 0
					if island.zones.turrets then
						for _, turret_zone in pairs(island.zones.turrets) do
							if turret_zone.is_spawned then turret_amount = turret_amount + 1 end
						end
					end
					
					local debug_data = ""
					debug_data = debug_data.."\nScout Progress: "..math.floor(g_savedata.ai_knowledge.scout[island.name].scouted/scout_requirement*100).."%"
					debug_data = debug_data.."\n\nNumber of AI Capturing: "..island.ai_capturing
					debug_data = debug_data.."\nNumber of Players Capturing: "..island.players_capturing
					if island.faction == ISLAND.FACTION.AI then 
						debug_data = debug_data.."\n\nNumber of defenders: "..island.defenders.."\n"
						debug_data = debug_data.."Number of Turrets: "..turret_amount.."/"..g_savedata.settings.MAX_TURRET_AMOUNT.."\n"

						debug_data = debug_data.."\nCargo\n"

						debug_data = debug_data.."\nCargo Storage\n"
						debug_data = debug_data..("%s%.1f%s"):format("Oil: ", island.cargo.oil, "\n")
						debug_data = debug_data..("%s%.1f%s"):format("Diesel: ", island.cargo.diesel, "\n")
						debug_data = debug_data..("%s%.1f%s"):format("Jet Fuel: ", island.cargo.jet_fuel, "\n")
					end

					s.addMapObject(peer_id, island.ui_id, 0, 9, island.transform[13], island.transform[15], 0, 0, 0, 0, island.name.." ("..island.faction..")\nisland.index: "..island.index..extra_title, 1, cap_percent.."%"..debug_data, r, g, b, 255)
				end
			end
		end
	end
end

---@param squad squadron the squad to get the leader of.
---@return integer|nil vehicle_id the id of the leader's group, nil upon failure
---@return vehicle_object|nil vehicle_object the squad's leader, nil upon failure
function getSquadLeader(squad)
	for vehicle_id, vehicle_object in pairs(squad.vehicles) do
		return vehicle_id, vehicle_object
	end
	d.print("warning: empty squad "..squad.vehicle_type.." detected", true, 1)
end

function getNearbySquad(transform, override_command)

	local closest_free_squad = nil
	local closest_free_squad_index = -1
	local closest_dist = 999999999

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if squad.command == SQUAD.COMMAND.NONE
		or squad.command == SQUAD.COMMAND.PATROL
		or override_command then

			local _, squad_leader = getSquadLeader(squad)

			-- ensure we got the squad leader
			if not squad_leader then
				-- skip this squad if we failed to get it.
				goto next_squad
			end

			local squad_vehicle_transform = squad_leader.transform
			local distance = m.distance(transform, squad_vehicle_transform)

			if distance < closest_dist then
				closest_free_squad = squad
				closest_free_squad_index = squad_index
				closest_dist = distance
			end
		end

		::next_squad::
	end

	return closest_free_squad, closest_free_squad_index
end

function tickAI(game_ticks)
	d.startProfiler("tickAI()", true)
	-- allocate squads to islands
	for island_index, island in pairs(g_savedata.islands) do
		if isTickID(island_index, 60) then
			if island.faction == ISLAND.FACTION.AI then
				if island.assigned_squad_index == -1 then
					local squad, squad_index = getNearbySquad(island.transform)

					if squad ~= nil then
						setSquadCommandDefend(squad, island)
						island.assigned_squad_index = squad_index
					end
				end
			end
		end
		if isTickID(island_index*15, time.minute/4) then -- every 15 seconds, update the amount of vehicles that are defending the base
			island.defenders = 0
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad.command == SQUAD.COMMAND.DEFEND or squad.command == SQUAD.COMMAND.TURRET then
					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if island.faction == ISLAND.FACTION.AI then
							if m.xzDistance(island.transform, vehicle_object.transform) < 1500 then
								island.defenders = island.defenders + 1
							end
						end
					end
				end
			end
		end 
	end

	-- allocate squads to engage or investigate based on vision
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, 60) then			
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				local squad_vision = squadGetVisionData(squad)
				if squad.command ~= SQUAD.COMMAND.SCOUT then
					if squad.command ~= SQUAD.COMMAND.ENGAGE and squad_vision:is_engage() then
						setSquadCommandEngage(squad)
					elseif squad.command ~= SQUAD.COMMAND.INVESTIGATE and squad_vision:is_investigate() then
						if #squad_vision.investigate_players > 0 then
							local investigate_player = squad_vision:getBestInvestigatePlayer()
							setSquadCommandInvestigate(squad, investigate_player.obj.last_known_pos)
						elseif #squad_vision.investigate_vehicles > 0 then
							local investigate_vehicle = squad_vision:getBestInvestigateVehicle()
							setSquadCommandInvestigate(squad, investigate_vehicle.obj.last_known_pos)
						end
					end
				end
			end
		end
	end

	if isTickID(0, 60) then
		g_count_squads = 0
		g_count_attack = 0
		g_count_patrol = 0

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				if squad.command ~= SQUAD.COMMAND.DEFEND and squad.vehicle_type ~= VEHICLE.TYPE.TURRET then
					g_count_squads = g_count_squads + 1
				end
	
				if squad.command == SQUAD.COMMAND.STAGE or squad.command == SQUAD.COMMAND.ATTACK then
					g_count_attack = g_count_attack + 1
				elseif squad.command == SQUAD.COMMAND.PATROL then
					g_count_patrol = g_count_patrol + 1
				end
			end
		end

		local objective_island, ally_island = Objective.getIslandToAttack()

		if objective_island == nil then
			g_savedata.is_attack = false
		else
			if g_savedata.is_attack == false then
				if g_savedata.constructable_vehicles.attack.mod >= 0.1 then -- if its above the threshold in order to attack
					if g_savedata.ai_knowledge.scout[objective_island.name].scouted >= scout_requirement then
						local boats_ready = 0
						local boats_total = 0
						local air_ready = 0
						local air_total = 0
						local land_ready = 0
						local land_total = 0
						objective_island.is_scouting = false

						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == SQUAD.COMMAND.STAGE then
								local _, squad_leader = getSquadLeader(squad)
								if not squad_leader then
									if squad_index ~= RESUPPLY_SQUAD_INDEX then
										-- delete the squad as its empty
										g_savedata.ai_army.squadrons[squad_index] = nil
										d.print("removed squad: "..tostring(squad_index), true, 0)
									else
										setSquadCommand(squad, SQUAD.COMMAND.RESUPPLY)
									end
									break
								end
								local squad_leader_transform = squad_leader.transform

								if squad.vehicle_type == VEHICLE.TYPE.BOAT then
									boats_total = boats_total + 1

									local air_dist = m.distance(objective_island.transform, ally_island.transform)
									local dist = m.distance(squad_leader_transform, objective_island.transform)
									local air_sea_speed_factor = VEHICLE.SPEED.BOAT/VEHICLE.SPEED.PLANE

									if dist < air_dist * air_sea_speed_factor then
										boats_ready = boats_ready + 1
									else
										-- terrible check to ensure the AI doesn't get stuck trying to attack an island which the boats cannot reach, resulting in them never attacking.
										local any_can_path = false
										
										for _, vehicle_object in pairs(squad.vehicles) do
											if #vehicle_object.path > 1 then
												any_can_path = true
												break
											end
										end

										-- cannot reach destination, just say they're ready to avoid soft locking the AI's ability to attack.
										if not any_can_path then
											boats_ready = boats_ready + 1
										end
									end
								elseif squad.vehicle_type == VEHICLE.TYPE.LAND then
									land_total = land_total + 1

									local air_dist = m.distance(objective_island.transform, ally_island.transform)
									local dist = m.distance(squad_leader_transform, objective_island.transform)
									local air_sea_speed_factor = VEHICLE.SPEED.LAND/VEHICLE.SPEED.PLANE

									if dist < air_dist * air_sea_speed_factor then
										land_ready = land_ready + 1
									end
								else
									air_total = air_total + 1

									local dist = m.distance(squad_leader_transform, ally_island.transform)
									if dist < 2000 then
										air_ready = air_ready + 1
									end
								end
							end
						end
						
						-- add more vehicles if we didn't hit the limit
						if (air_total + boats_total) < MAX_ATTACKING_SQUADS then
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.PATROL or squad.command == SQUAD.COMMAND.DEFEND and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and squad.role ~= "defend" then
									if (air_total + boats_total) < MAX_ATTACKING_SQUADS then
										if squad.vehicle_type == VEHICLE.TYPE.BOAT then
											if not Tags.has(objective_island.tags, "no-access=boat") and not Tags.has(ally_island.tags, "no-access=boat") then
												boats_total = boats_total + 1
												setSquadCommandStage(squad, objective_island)
											end
										else
											air_total = air_total + 1
											setSquadCommandStage(squad, ally_island)
										end
									end
								end
							end
						end
						
			
						g_is_air_ready = air_total == 0 or air_ready / air_total >= 0.5
						g_is_boats_ready = Tags.has(ally_island.tags, "no-access=boat") or Tags.has(objective_island.tags, "no-access=boat") or boats_total == 0 or boats_ready / boats_total >= 0.25
						local is_attack = (g_count_attack / g_count_squads) >= 0.25 and g_count_attack >= MIN_ATTACKING_SQUADS and g_is_boats_ready and g_is_air_ready
						
						if is_attack then
							g_savedata.is_attack = is_attack
			
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.STAGE then
									if not Tags.has(objective_island.tags, "no-access=boat") and squad.vehicle_type == VEHICLE.TYPE.BOAT or squad.vehicle_type ~= VEHICLE.TYPE.BOAT then -- makes sure boats can attack that island
										setSquadCommandAttack(squad, objective_island)
									end
								elseif squad.command == SQUAD.COMMAND.ATTACK then
									if squad.target_island.faction == ISLAND.FACTION.AI then
										-- if they are targeting their own island
										squad.target_island = objective_island
									end
								end
							end
						else
							for _, squad in pairs(g_savedata.ai_army.squadrons) do
								if squad.command == SQUAD.COMMAND.NONE and squad.vehicle_type ~= VEHICLE.TYPE.TURRET and (air_total + boats_total) < MAX_ATTACKING_SQUADS then
									if squad.vehicle_type == VEHICLE.TYPE.BOAT then -- send boats ahead since they are slow
										if not Tags.has(objective_island.tags, "no-access=boat") then -- if boats can attack that island
											setSquadCommandStage(squad, objective_island)
											boats_total = boats_total + 1
										end
									else
										setSquadCommandStage(squad, ally_island)
										air_total = air_total + 1
									end
								elseif squad.command == SQUAD.COMMAND.STAGE and squad.vehicle_type == VEHICLE.TYPE.BOAT and not Tags.has(objective_island.tags, "no-access=boat") and (air_total + boats_total) < MAX_ATTACKING_SQUADS then
									setSquadCommandStage(squad, objective_island)
									squad.target_island = objective_island
								end
							end
						end
					else -- if they've yet to fully scout the base
						local scout_exists = false
						local not_scouting = false
						local squad_to_set = nil
						if not objective_island.is_scouting then
							for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
								for vehicle_index, vehicle in pairs(squad.vehicles) do
									if vehicle.role == "scout" then
										scout_exists = true
										if squad.command ~= SQUAD.COMMAND.SCOUT then not_scouting = true; squad_to_set = squad_index end
									end
								end
							end
							if not scout_exists then -- if a scout vehicle does not exist
								-- then we want to spawn one, unless its been less than 30 minutes since it was killed
								if g_savedata.ai_history.scout_death == -1 or g_savedata.ai_history.scout_death ~= 0 and g_savedata.tick_counter - g_savedata.ai_history.scout_death >= time.hour / 2 then
									d.print("attempting to spawn scout vehicle...", true, 0)
									local spawned, fail_reason = v.spawn("scout", nil, nil, nil, 3)
									if spawned then
										if g_savedata.ai_history.scout_death == -1 then
											g_savedata.ai_history.scout_death = 0
										end
										d.print("scout vehicle spawned!", true, 0)
										objective_island.is_scouting = true
										for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
											if squad.command == SQUAD.COMMAND.SCOUT then
												setSquadCommandScout(squad)
											end
										end
									else
										d.print("Failed to spawn scout vehicle: "..tostring(fail_reason), true, 0)
									end
								end
							elseif not_scouting and squad_to_set then -- if the scout was just set to a different command
								-- then we want to set it back to scouting
								setSquadCommandScout(g_savedata.ai_army.squadrons[squad_to_set])
							end
						end
					end
				else -- if they've not hit the threshold to attack
					if objective_island.is_scouting then -- if theres still a scout plane scouting the island
						for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
							if squad.command == SQUAD.COMMAND.SCOUT then
								squad.target_island = ally_island
								setSquadCommand(squad, SQUAD.COMMAND.DEFEND)
								objective_island.is_scouting = false
							end
						end
					end
				end
			else
				local is_disengage = (g_count_attack / g_count_squads) < 0.25
	
				if is_disengage then
					g_savedata.is_attack = false
	
					for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
						if squad.command == SQUAD.COMMAND.ATTACK then
							if squad.vehicle_type == VEHICLE.TYPE.BOAT and not Tags.has(objective_island.tags, "no-access=boat") and not Tags.has(ally_island.tags, "no-access=boat") or squad.vehicle_type ~= VEHICLE.TYPE.BOAT then
								setSquadCommandStage(squad, ally_island)
							end
						end
					end
				end
			end
		end

		-- assign squads to patrol
		local allied_islands = getAlliedIslands()

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad.command == SQUAD.COMMAND.NONE then
				if #allied_islands > 0 then
					if (g_count_patrol / g_count_squads) < 0.5 then
						g_count_patrol = g_count_patrol + 1
						setSquadCommandPatrol(squad, allied_islands[math.random(1, #allied_islands)])
					else
						setSquadCommandDefend(squad, allied_islands[math.random(1, #allied_islands)])
					end
				else
					setSquadCommandPatrol(squad, g_savedata.ai_base_island)
				end
			end
		end
	end
	d.stopProfiler("tickAI()", true, "onTick()")
end

function getAlliedIslands()
	local alliedIslandIndexes = {}
	for island_index, island in pairs(g_savedata.islands) do
		if island.faction == ISLAND.FACTION.AI then
			table.insert(alliedIslandIndexes, island)
		end
	end
	return alliedIslandIndexes
end

function getResupplyIsland(ai_vehicle_transform)
	local closest = g_savedata.ai_base_island
	local closest_dist = m.distance(ai_vehicle_transform, g_savedata.ai_base_island.transform)

	for island_index, island in pairs(g_savedata.islands) do
		if island.faction == ISLAND.FACTION.AI then
			local distance = m.distance(ai_vehicle_transform, island.transform)

			if distance < closest_dist then
				closest = island
				closest_dist = distance
			end
		end
	end

	return closest
end

---@param vehicle_object vehicle_object the vehicle to transfer
---@param squad_index integer the squad's index that you want to transfer the vehicle to
---@param force ?boolean if you want to force the vehicle over to the squad, bypassing any limits
function transferToSquadron(vehicle_object, squad_index, force) --* moves a vehicle over to another squad
	if not vehicle_object then
		d.print("(transferToSquadron) vehicle_object is nil!", true, 1)
		return
	end

	if not squad_index then
		local debug_data = ""
		if vehicle_object then
			if vehicle_object.group_id then
				debug_data = debug_data.." vehicle_id: "..tostring(vehicle_object.group_id)

				if g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] then
					debug_data = debug_data.." squad_index: "..tostring(g_savedata.ai_army.squad_vehicles[vehicle_object.group_id])
				end
			end
		end

			
		d.print("(transferToSquadron) squad_index is nil! debug_data:"..debug_data, true, 1)
		return
	end

	local old_squad_index, old_squad = Squad.getSquad(vehicle_object.group_id)

	if not old_squad_index then
		d.print("(transferToSquadron) old_squad_index is nil! vehicle_id: "..tostring(vehicle_object.group_id), true, 1)
	end

	vehicle_object.previous_squad = old_squad_index

	--? make sure new squad exists
	if not g_savedata.ai_army.squadrons[squad_index] then
		--* create the squad as it doesn't exist
		squad_index, squad_created = Squad.createSquadron(squad_index, vehicle_object)
		if not squad_created then
			d.print("(transferToSquadron) failed to create squad!", true, 1)
		end
	end

	--* add to new squad
	g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = squad_index
	g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.group_id] = vehicle_object

	--* remove from old squad
	if old_squad_index and g_savedata.ai_army.squadrons[old_squad_index] and g_savedata.ai_army.squadrons[old_squad_index].vehicles then
		g_savedata.ai_army.squadrons[old_squad_index].vehicles[vehicle_object.group_id] = nil
		--? if the squad is now empty then delete the squad and if its not the resupply squad
		if table.length(g_savedata.ai_army.squadrons[old_squad_index].vehicles) == 0 and old_squad_index ~= RESUPPLY_SQUAD_INDEX then
			g_savedata.ai_army.squadrons[old_squad_index] = nil
		end
	end

	--local vehicle_object_test, squad_test, squad_index_test = Squad.getVehicle(vehicle_object.group_id)
	--d.print("(transferToSquadron) vehicle_object existed after? "..tostring(vehicle_object_test ~= nil), true, 0)

	d.print("(transferToSquadron) Transferred "..vehicle_object.name.."("..vehicle_object.group_id..") from squadron "..tostring(old_squad_index).." to "..squad_index, true, 0)
end

function addToSquadron(vehicle_object)
	if vehicle_object then
		if not vehicle_object.is_killed then
			local new_squad = nil

			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then -- do not automatically add to resupply squadron
					if squad.vehicle_type == vehicle_object.vehicle_type then
						local _, squad_leader = getSquadLeader(squad)

						-- ensure we got the squad leader
						if not squad_leader then
							-- skip this squad if we failed to get it.
							goto next_squad
						end
						if squad.vehicle_type ~= VEHICLE.TYPE.TURRET or vehicle_object.home_island.name == squad_leader.home_island.name then
							if vehicle_object.role ~= "scout" and squad.role ~= "scout" and vehicle_object.role ~= "cargo" and squad.role ~= "cargo" then
								if table.length(squad.vehicles) < MAX_SQUAD_SIZE then
									squad.vehicles[vehicle_object.group_id] = vehicle_object
									g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = squad_index
									new_squad = squad
									break
								end
							end
						end
					end
				end

				::next_squad::
			end

			if new_squad == nil then
				local new_squad_index, squad_created = Squad.createSquadron(nil, vehicle_object)

				new_squad = g_savedata.ai_army.squadrons[new_squad_index]

				new_squad.vehicles[vehicle_object.group_id] = vehicle_object
				g_savedata.ai_army.squad_vehicles[vehicle_object.group_id] = new_squad_index
			end

			squadInitVehicleCommand(new_squad, vehicle_object)
			return new_squad
		else
			d.print("(addToSquadron) "..vehicle_object.name.." is killed!", true, 1)
		end
	else
		d.print("(addToSquadron) vehicle_object is nil!", true, 1)
	end
	return nil
end

local squadron_tick_rate = 60

function tickSquadrons(game_ticks)
	d.startProfiler("tickSquadrons()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		if isTickID(squad_index, squadron_tick_rate) then
			-- clean out-of-action vehicles
			for vehicle_id, vehicle_object in pairs(squad.vehicles) do

				if vehicle_object.is_killed and vehicle_object.death_timer ~= nil then
					vehicle_object.death_timer = vehicle_object.death_timer + 1

					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						if vehicle_object.death_timer >= g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER/squadron_tick_rate then
							d.print(("Cargo Vehicle %s has been killed for more than %s minutes, despawning"):format(vehicle_object.name, g_savedata.settings.CARGO_VEHICLE_DESPAWN_TIMER/time.minute), true, 0)
							v.kill(vehicle_object, true, true)
						end
					elseif vehicle_object.role == SQUAD.COMMAND.SCOUT then
						if vehicle_object.death_timer >= (time.minute/4)/squadron_tick_rate then
							v.kill(vehicle_object, true)
						end
					else
						if vehicle_object.death_timer >= math.seededRandom(false, vehicle_id, 8, 90) then -- kill the vehicle after 8 - 90 seconds after dying
							v.kill(vehicle_object, true)
						end
					end
				end

				-- if pilot is incapacitated
				local c = s.getCharacterData(vehicle_object.survivors[1])

				--[[
					if npc exists
					and if the npc is incapacitaed or dead
					and if the vehicle its linked to isnt a cargo vehicle
					then kill the vehicle
				]]
				if c and (c.incapacitated or c.dead) and vehicle_object.role ~= SQUAD.COMMAND.CARGO and not vehicle_object.is_killed then
					v.kill(vehicle_object)
				end
			end

			-- check if a vehicle needs resupply, removing from current squad and adding to the resupply squad
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				for group_id, vehicle_object in pairs(squad.vehicles) do

					-- Get the main vehicle_id.
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

					-- Ensure we got the main vehicle_id
					if not main_vehicle_id then
						-- skip this vehicle if we failed to get it.
						goto next_vehicle
					end

					-- If this vehicle needs resupply.
					if isVehicleNeedsResupply(main_vehicle_id, "Resupply") then
						-- If this is a turret, then reload it.
						if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
							-- Reload the turret.
							reload(main_vehicle_id)

						-- Otherwise, transfer it to the resupply squad.
						else
							-- transfer the vehicle to the resupply squad
							transferToSquadron(g_savedata.ai_army.squadrons[squad_index].vehicles[group_id], RESUPPLY_SQUAD_INDEX, true)

							-- print a debug message saying it's leaving the squad to resupply.
							d.print(tostring(group_id).." leaving squad "..tostring(squad_index).." to resupply", true, 0)

							if g_savedata.ai_army.squadrons[squad_index] and table.length(g_savedata.ai_army.squadrons[squad_index].vehicles) <= 0 then -- squad has no more vehicles
								g_savedata.ai_army.squadrons[squad_index] = nil
	
								for _, island in pairs(g_savedata.islands) do
									if island.assigned_squad_index == squad_index then
										island.assigned_squad_index = -1
									end
								end
							end

							if g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].command ~= SQUAD.COMMAND.RESUPPLY then
								g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].command = SQUAD.COMMAND.RESUPPLY
							end

							squadInitVehicleCommand(squad, vehicle_object)
						end
					elseif isVehicleNeedsResupply(main_vehicle_id, "AI_NO_MORE_MISSILE") then -- if its out of missiles, then kill it
						if not vehicle_object.is_killed then
							v.kill(vehicle_object)
						end
					end

					-- check if the vehicle simply needs to reload from a disconnected ammo belt, barrel or box
					local vehicle_component_data, is_success = server.getVehicleComponents(main_vehicle_id)

					if is_success and vehicle_component_data.components and vehicle_component_data.components.guns then
						for gun_index = 1, #vehicle_component_data.components.guns do
							local gun_data = vehicle_component_data.components.guns[gun_index]

							-- if this is a gun that might need reloading
							if gun_data.ammo == 0 and (gun_data.name:match("^Ammo %d+$") or (gun_data.name:match("^Gunner %d+$"))) then

								-- the target weapons we can reload from
								local ammo_group = tonumber(table.pack(gun_data.name:gsub("[%a ]+", ""))[1])
								local target_pattern = ("Reserve Ammo %i"):format(ammo_group)
								for reserve_ammo_index = 1, #vehicle_component_data.components.guns do
									local reserve_ammo_data = vehicle_component_data.components.guns[reserve_ammo_index]

									-- we can reload from this weapon
									if gun_index ~= reserve_ammo_index and reserve_ammo_data.ammo ~= 0 and reserve_ammo_data.name:match(target_pattern) then
										-- move as much ammo as we can from the reserve ammo to the gun.
										local ammo_to_move = math.min(gun_data.capacity - gun_data.ammo, reserve_ammo_data.ammo)

										-- take that away from the reserve ammo container
										server.setVehicleWeapon(main_vehicle_id, reserve_ammo_data.pos.x, reserve_ammo_data.pos.y, reserve_ammo_data.pos.z, reserve_ammo_data.ammo - ammo_to_move)
										
										-- move that into the gun
										server.setVehicleWeapon(main_vehicle_id, gun_data.pos.x, gun_data.pos.y, gun_data.pos.z, gun_data.ammo + ammo_to_move)

										-- if the gun is not at capcity, continue on
										-- otherwise, break.
										if gun_data.ammo + ammo_to_move == gun_data.capacity then
											break
										end
									end
								end
							end
						end
					end

					-- local guns_to_reload = isVehicleNeedsReload(vehicle_id)
					--[[for i = 1, #guns_to_reload do
						local ammo_group = guns_to_reload[i]

						--local gun_data, is_success = s.getVehicleWeapon(vehicle_id, "Ammo "..gun_id)

						local vehicle_data, _ = s.getVehicleData(vehicle_id)

						for weapon_index = 1, #vehicle_data.components.guns do
							local weapon = vehicle_data.components.guns[weapon_index]

							if weapon.name:match("Ammo "..ammo_group) then

							end
						end 
					end

					if gun_info[1] and gun_info[2] ~= 0 then
						local i = 1
						local successed = false
						local ammo_data = {}
						repeat
							local ammo, success = s.getVehicleWeapon(vehicle_id, "Ammo "..gun_info[2].." - "..i)
							if success then
								if ammo.ammo > 0 then
									successed = success
									ammo_data[i] = ammo
								end
							end
							i = i + 1
						until (not successed)
						if successed then
							s.setVehicleWeapon(vehicle_id, "Ammo "..gun_info[2].." - "..#ammo_data, 0)
							s.setVehicleWeapon(vehicle_id, "Ammo "..gun_info[2], ammo_data[#ammo_data].capacity)
						end
					end]]

					::next_vehicle::
				end
			else
				for group_id, vehicle_object in pairs(squad.vehicles) do

					-- Get the main vehicle_id.
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

					-- Ensure we got the main vehicle_id
					if not main_vehicle_id then
						-- skip this vehicle if we failed to get it.
						goto next_vehicle
					end

					if (vehicle_object.state.is_simulating and isVehicleNeedsResupply(main_vehicle_id, "Resupply") == false) or (not vehicle_object.state.is_simulating and vehicle_object.is_resupply_on_load) then
	
						transferToSquadron(vehicle_object, vehicle_object.previous_squad, true)

						d.print(group_id.." resupplied. joining squad", true, 0)
					end
					::next_vehicle::
				end
			end

			--* tick behaviour and exit conditions
			if squad.command == SQUAD.COMMAND.CARGO and g_savedata.settings.CARGO_MODE then
				local convoy = {}
				for vehicle_index, vehicle_object in pairs(squad.vehicles) do
					if g_savedata.cargo_vehicles[vehicle_object.group_id] then
						local n_vehicle_object, n_squad_index, n_squad = Squad.getVehicle(vehicle_object.group_id)
						g_savedata.cargo_vehicles[vehicle_object.group_id].vehicle_data = n_vehicle_object
						convoy = g_savedata.cargo_vehicles[vehicle_object.group_id]
						convoy.vehicle_data = n_vehicle_object
						break
					end
				end

				--? check to see if we have a valid convoy
				if not convoy then
					d.print("breaking as theres no valid convoy!", true, 1)
					goto break_squadron
				end

				--? check to see if we have any escorts
				if #convoy.convoy <= 1 then
					goto break_squadron
				end

				--? check to see if we're on the move
				if convoy.route_status ~= 1 then
					goto break_squadron
				end

				--* handle and calculate the convoy's paths

				-- get which path the cargo vehicle is currently on
				local old_path = convoy.path_data.current_path

				--? check to see if we have any paths for the cargo vehicle
				if #convoy.vehicle_data.path > 0 then
					for i = convoy.path_data.current_path, #convoy.path_data.path do
						--d.print("i: "..i, true, 0)
						i = math.max(i, 1)
						local cargo_vehicle_node = g_savedata.ai_army.squadrons[squad_index].vehicles[convoy.vehicle_data.group_id].path[1]
						local convoy_node = convoy.path_data.path[i]
						--d.print("c_v_n.x: "..cargo_vehicle_node.x.." c_n.x: "..convoy_node.x.."\nc_v_n.y: "..tostring(cargo_vehicle_node.y).." c_n.y: "..tostring(convoy_node.y).."\nc_v_n.z: "..cargo_vehicle_node.z.." c_n.z: "..convoy_node.z.."\n", true, 0)
						if cargo_vehicle_node.x == convoy_node.x and cargo_vehicle_node.z == convoy_node.z then
							--d.print("current path: "..i, true, 0)
							convoy.path_data.current_path = i
							break
						end
					end
				else
					d.print("there are no convoy paths!", true, 1)
					p.addPath(convoy.vehicle_data, squad.target_island.transform)
				end

				--d.print("old path: "..old_path, true, 0)
				--d.print("new path: "..convoy.path_data.current_path, true, 0)

				--* check and update the convoy's path for all vehicles in the convoy
				--d.print("going through all escorts...", true, 0)
				for convoy_index, vehicle_id in ipairs(convoy.convoy) do
					local vehicle_object, squad_index, squad = Squad.getVehicle(vehicle_id)
					--d.print("convoy_index: "..tostring(convoy_index).." vehicle_id: "..tostring(vehicle_id), true, 0)
					if not vehicle_object then
						d.print("(escort) vehicle_object is nil! vehicle_id: "..tostring(vehicle_id), true, 1)
						goto break_cargo_vehicle
					end

					--? if this is not the cargo vehicle
					if vehicle_object.group_id ~= convoy.vehicle_data.group_id then
						--? if the cargo vehicle is on a new path
						if old_path ~= convoy.path_data.current_path then
							--* reset the path
							p.resetPath(vehicle_object)
						end
					end

					--d.print("convoy_index: "..convoy_index, true, 0)
					if convoy.convoy[convoy_index - 1] then -- if theres a vehicle behind this one

						local behind_vehicle_object, _, _ = Squad.getVehicle(convoy.convoy[convoy_index - 1])

						--? if this vehicle is not waiting and the behind vehicle exists
						if behind_vehicle_object and vehicle_object.state.convoy.status ~= CONVOY.WAITING  then
						
							--? check if the vehicle behind needs to catch up, and the vehicle behind is not a plane
							if RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance and vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE then

								--? if the vehicle behind is too far behind
								local behind_too_far = (m.xzDistance(vehicle_object.transform, behind_vehicle_object.transform) >= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance)

								--? if the vehicle behind is waiting
								local behind_waiting = (behind_vehicle_object.state.convoy.status == CONVOY.WAITING and behind_vehicle_object.state.convoy.waiting_for ~= convoy_index)

								if behind_too_far or behind_waiting then
									--? if this vehicle behind us is not ignored for waiting
									if not behind_vehicle_object.state.convoy.ignore_wait then
										-- set us to waiting
										vehicle_object.state.convoy.status = CONVOY.WAITING
										-- set the time that this occured
										vehicle_object.state.convoy.changed_time = g_savedata.tick_counter
										-- set which vehicle we are waiting for
										vehicle_object.state.convoy.waiting_for = convoy_index - 1
										-- set the vehicle's speed to be 0
										vehicle_object.speed.convoy_modifier = -(v.getSpeed(vehicle_object, nil, nil, nil, nil, true))
										-- set why its waiting
										local status_reason = behind_too_far and "waiting_for_behind" or "behind_is_waiting"
										vehicle_object.state.convoy.status_reason = status_reason
									end
								end
							end

							if vehicle_object.state.convoy.status == CONVOY.MOVING then
								--* make it speed up if its falling behind, and the vehicle behind is catching up

								-- the last path this vehicle has
								local last_path = vehicle_object.path[#vehicle_object.path]

								if last_path then

									--d.print("vehicle_object.name: "..vehicle_object.name.."\nbehind_vehicle_object.name: "..behind_vehicle_object.name, true, 0)

									-- the distance from this vehicle to its last path
									local dist = m.xzDistance(vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									-- the distance from the vehicle behind to this vehicles last path
									local behind_dist = m.xzDistance(behind_vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									--d.print("dist: "..dist.."\nbehind_dist: "..behind_dist, true, 0)

									local dist_speed_modifier = 1/math.clamp((behind_dist - dist)/(RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].min_distance*2), 0.5, 1)
									--d.print("dist_speed_modifier: "..dist_speed_modifier, true, 0)

									local vehicle_speed = v.getSpeed(vehicle_object, nil, nil, nil, nil, true)

									vehicle_object.speed.convoy_modifier = ((vehicle_speed * dist_speed_modifier) - vehicle_speed)/1.5

									--d.print("speed: "..(vehicle_object.speed.convoy_modifier), true, 0)
								end
							end
						end
					end

					if convoy.convoy[convoy_index + 1] then -- if theres a vehicle ahead of this one

						local ahead_vehicle_object, ahead_squad_index, ahead_squad = Squad.getVehicle(convoy.convoy[convoy_index + 1])

						if ahead_vehicle_object and vehicle_object.state.convoy.status ~= CONVOY.WAITING then
						
							--? check if the vehicle ahead is getting too far behind
							if RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].min_distance and vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE then

								--? if the vehicle ahead is getting too far behind

								local next_path = ahead_vehicle_object.path[1]

								--d.print("vehicle_type: "..vehicle_object.vehicle_type, true, 0)

								local ahead_too_far = (m.xzDistance(vehicle_object.transform, ahead_vehicle_object.transform) >= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance) and (next_path and (m.xzDistance(ahead_vehicle_object.transform, m.translation(next_path.x, next_path.y, next_path.z)) > m.xzDistance(vehicle_object.transform, m.translation(next_path.x, next_path.y, next_path.z))))

								--? if the vehicle ahead of us is waiting
								local ahead_waiting = (ahead_vehicle_object.state.convoy.status == CONVOY.WAITING and ahead_vehicle_object.state.convoy.waiting_for ~= convoy_index)

								if ahead_too_far or ahead_waiting then
									--? if this vehicle ahead of us is not ignored for waiting
									if not ahead_vehicle_object.state.convoy.ignore_wait then
										-- set us to waiting
										vehicle_object.state.convoy.status = CONVOY.WAITING
										-- set the time that this occured
										vehicle_object.state.convoy.changed_time = g_savedata.tick_counter
										-- set which vehicle we are waiting for
										vehicle_object.state.convoy.waiting_for = convoy_index + 1
										-- set the vehicle's speed to be 0
										vehicle_object.speed.convoy_modifier = -(v.getSpeed(vehicle_object, nil, nil, nil, nil, true))
										-- set why its waiting
										local status_reason = ahead_too_far and "waiting_for_ahead" or "ahead_is_waiting"
										vehicle_object.state.convoy.status_reason = status_reason
									end
								end
							end

							if vehicle_object.state.convoy.status == CONVOY.MOVING then
								--* make it slow down if the vehicle ahead falling behind, and speed up if its falling behind

								-- the last path this vehicle has
								local last_path = ahead_vehicle_object.path[#ahead_vehicle_object.path]

								if last_path then

									-- the distance from this vehicle to its last path
									local dist = m.xzDistance(vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									-- the distance from the vehicle ahead of this vehicles last path
									local ahead_dist = m.xzDistance(ahead_vehicle_object.transform, m.translation(last_path.x, last_path.y, last_path.z))

									local dist_speed_modifier = 1/math.clamp((ahead_dist - dist)/(RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].max_distance/2), 0.5, 1)

									local vehicle_speed = v.getSpeed(vehicle_object, nil, nil, nil, nil, true)

									vehicle_object.speed.convoy_modifier = ((vehicle_speed * dist_speed_modifier) - vehicle_speed)/1.5

									--d.print("speed: "..(vehicle_object.speed.convoy_modifier), true, 0)
								end
							end
						end
					end

					--? if this vehicle is currently waiting
					if vehicle_object.state.convoy.status == CONVOY.WAITING then
						--d.print("vehicle is waiting", true, 0)
						local max_wait_timer = RULES.LOGISTICS.CONVOY.base_wait_time
						--? if we've waited over the max time, or that this vehicle should not be waited 
						local waiting_vehicle_object, _, _ = Squad.getVehicle(convoy.convoy[vehicle_object.state.convoy.waiting_for])
						--d.print("waiting for "..(ticksSince(vehicle_object.state.convoy.changed_time)).."t...", true, 0)

						-- ensure we got the waiting vehicle object
						if not waiting_vehicle_object then
							-- skip this vehicle if we failed to get it.
							goto break_cargo_vehicle
						end

						--? if we've waited too long for the vehicle
						local waited_too_long = (ticksSince(vehicle_object.state.convoy.changed_time) > max_wait_timer or waiting_vehicle_object.state.convoy.ignore_wait)

						--? if the vehicle behind has caught up
						local behind_vehicle_object = nil
						local behind_squad_index = nil
						local behind_squad = nil

						if convoy.convoy[convoy_index - 1] then
							behind_vehicle_object, behind_squad_index, behind_squad = Squad.getVehicle(convoy.convoy[convoy_index - 1])
						end

						local behind_caught_up = (vehicle_object.state.convoy.status_reason == "waiting_for_behind" and ((vehicle_object.state.convoy.waiting_for + 1) == convoy_index) and (not behind_vehicle_object or m.xzDistance(vehicle_object.transform, behind_vehicle_object.transform) <= RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].target_distance))

						--? if the vehicle behind is no longer waiting
						local behind_no_longer_waiting = (vehicle_object.state.convoy.status_reason == "behind_is_waiting" and (not waiting_vehicle_object or waiting_vehicle_object.state.convoy.status ~= CONVOY.WAITING))

						if waited_too_long or behind_caught_up or behind_no_longer_waiting then
							if waited_too_long then
								-- ignore the vehicle for waiting that we were waiting for
								waiting_vehicle_object.state.convoy.ignore_wait = true
							end
							-- set us to moving
							vehicle_object.state.convoy.status = CONVOY.MOVING
							-- remove the time our status changed
							vehicle_object.state.convoy.changed_time = -1
							-- set that we aren't waiting for anybody
							vehicle_object.state.convoy.waiting_for = 0
							-- remove the speed modifier
							vehicle_object.speed.convoy_modifier = 0
							--? if its not the cargo vehicle
							if vehicle_object.group_id ~= convoy.vehicle_data.group_id then
								-- reset the vehicle's path
								p.resetPath(vehicle_object)
							end
							-- reset the vehicle status reason
							vehicle_object.state.convoy.status_reason = ""
						end

					--? pathfind for the vehicle
					elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.BOAT and #vehicle_object.path <= 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and #vehicle_object.path < 1 then
						--d.print("calculating new path!", true, 0)
						--* this vehicle is currently moving

						--* calculate where the vehicle should path to

						cargo_vehicle_index = 1 + math.floor((#convoy.convoy - 1)/2)

						--? this vehicle is not the cargo vehicle
						if vehicle_object.group_id ~= convoy.vehicle_data.group_id then

							local target_dist = math.abs(cargo_vehicle_index - convoy_index) * RULES.LOGISTICS.CONVOY[vehicle_object.vehicle_type].target_distance

							--d.print("target dist: "..target_dist, true, 0)

							local node_to_check = 1

							--? if this vehicle is behind the cargo vehicle
							if convoy_index <= cargo_vehicle_index then
								node_to_check = -1
							end
							
							--* find which node is the best node to target
							local best_node = math.max(convoy.path_data.current_path - node_to_check, 1)
							local next_node = nil
							local total_dist = 0
							local leftover_dist = target_dist
							--d.print("current_path: "..convoy.path_data.current_path.."\nnumber of paths: "..#convoy.path_data.path, true, 0)
							for node = convoy.path_data.current_path, #convoy.path_data.path * node_to_check, node_to_check do
								local p_node = convoy.path_data.path[node-node_to_check] -- last node
								local n_node = convoy.path_data.path[node] -- next node


								--d.print("node: "..node, true, 0)
								--? makes sure previous node and new nodes exist
								if p_node and n_node then

									if node == convoy.path_data.current_path then -- if this is the first path, calculate the distance from the cargo vehicle to its next path
										total_dist = total_dist + m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), convoy.vehicle_data.transform)
									else -- if tis is not the first path, calculate the distance between the paths
										total_dist = total_dist + m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), m.translation(p_node.x, p_node.y, p_node.z))
									end

									--? break if this is over the target distance
									--d.print("total dist: "..total_dist, true, 0)
									if total_dist >= target_dist then
										next_node = node
										leftover_dist = target_dist - (total_dist - m.xzDistance(m.translation(n_node.x, n_node.y, n_node.z), m.translation(p_node.x, p_node.y, p_node.z)))
										break
									else
										best_node = node
									end

									
								end
							end
							local t_node = convoy.path_data.path[best_node] -- target node
							if not t_node then
								goto break_cargo_vehicle
							end
							local target_pos = m.translation(t_node.x, t_node.y, t_node.z)

							
							if target_pos then
								--d.print("adding path to destination!", true, 0)
								--! pathfind to the new destination
								p.resetPath(vehicle_object)
								p.addPath(vehicle_object, target_pos)

								--* for the leftover distance, go that far into the node
								--d.print("leftover dist: "..leftover_dist, true, 0)
								if leftover_dist ~= 0 and next_node then
									--d.print("current node: "..convoy.path_data.current_path, true, 0)
									--d.print("best_node: "..best_node.." next_node: "..next_node, true, 0)
									local n_node = convoy.path_data.path[next_node] -- the node we couldn't reach
									--d.print("n_node.x: "..n_node.x.." t_node.x: "..t_node.x, true, 0)
									local angle = math.atan(n_node.x - t_node.x, n_node.z - t_node.z)
									local target_x = t_node.x + (leftover_dist * math.sin(angle))
									local target_z = t_node.z + (leftover_dist * math.cos(angle))

									--d.print("target x: "..target_x.."\ntarget z: "..target_z, true, 0)

									table.insert(vehicle_object.path, #vehicle_object.path+1, {
										x = target_x,
										y = target_pos[14],
										z = target_z
									})
								end

								--* clean up the path
								if #vehicle_object.path >= 2 then

									local nodes_to_remove = {}

									for node = 1, #vehicle_object.path - 1 do

										-- if the vehicle is closer to the node after the next one than the next node
										local node_is_junk = m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[node].x, vehicle_object.path[node].y, vehicle_object.path[node].z)) > m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z))

										-- if the vehicle is closer to the node after the next node than the next node is closer to the node after
										local node_goes_backwards = m.xzDistance(m.translation(vehicle_object.path[node].x, vehicle_object.path[node].y, vehicle_object.path[node].z), m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z)) > m.xzDistance(vehicle_object.transform, m.translation(vehicle_object.path[1 + node].x, vehicle_object.path[1 + node].y, vehicle_object.path[1 + node].z))

										if node_is_junk or node_goes_backwards then
											table.insert(nodes_to_remove, node)
										end
									end

									for node = #nodes_to_remove, 1, -1 do
										s.removeMapLine(-1, vehicle_object.path[nodes_to_remove[node]].ui_id)
										table.remove(vehicle_object.path, nodes_to_remove[node])
										--d.print("removed node: "..node, true, 0)
									end
								end
							end
						end
					end
					::break_cargo_vehicle::
				end

				

			elseif squad.command == SQUAD.COMMAND.PATROL then
				local squad_leader_id, squad_leader = getSquadLeader(squad)
				if squad_leader then
					if squad_leader.state.s ~= VEHICLE.STATE.PATHING then -- has finished patrol
						setSquadCommand(squad, SQUAD.COMMAND.NONE)
					end
				else
					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						d.print("patrol squad missing leader", true, 1)
						d.print("deleting squad as its empty", true, 1)
						g_savedata.ai_army.squadrons[squad_index] = nil
						setSquadCommand(squad, SQUAD.COMMAND.NONE)
					else
						setSquadCommand(squad, SQUAD.COMMAND.RESUPPLY)
					end
				end
			elseif squad.command == SQUAD.COMMAND.STAGE then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == SQUAD.COMMAND.ATTACK then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end
			elseif squad.command == SQUAD.COMMAND.DEFEND then
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and vehicle_object.state.s == VEHICLE.STATE.HOLDING then
						squadInitVehicleCommand(squad, vehicle_object)
					end
				end

				if squad.target_island == nil then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				elseif squad.target_island.faction ~= ISLAND.FACTION.AI then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			elseif squad.command == SQUAD.COMMAND.RESUPPLY then

				g_savedata.ai_army.squadrons[RESUPPLY_SQUAD_INDEX].target_island = nil
				for group_id, vehicle_object in pairs(squad.vehicles) do
					local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)
					
					-- Ensure we got the main_vehicle_id
					if not main_vehicle_id then
						d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
						goto continue_resupply_squad_vehicle
					end

					if #vehicle_object.path == 0 then
						d.print("resupply mission recalculating target island for: "..group_id, true, 0)
						local ally_island = getResupplyIsland(vehicle_object.transform)
						p.resetPath(vehicle_object)
						p.addPath(vehicle_object, m.multiply(ally_island.transform, m.translation(math.random(-250, 250), CRUISE_HEIGHT + (vehicle_object.group_id % 10 * 20), math.random(-250, 250))))
					end
					
					if m.distance(g_savedata.ai_base_island.transform, vehicle_object.transform) < RESUPPLY_RADIUS then

						if vehicle_object.state.is_simulating then
							-- resupply ammo
							reload(main_vehicle_id)
						else
							vehicle_object.is_resupply_on_load = true
						end
					end

					for island_index, island in pairs(g_savedata.islands) do
						if island.faction == ISLAND.FACTION.AI then
							if m.distance(island.transform, vehicle_object.transform) < CAPTURE_RADIUS then

								if vehicle_object.state.is_simulating then
									-- resupply ammo
									reload(main_vehicle_id)
								else
									vehicle_object.is_resupply_on_load = true
								end
							end
						end
					end
					::continue_resupply_squad_vehicle::
				end

			elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
				-- head to search area

				if squad.investigate_transform then
					local is_all_vehicles_at_search_area = true

					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						if vehicle_object.state.s ~= VEHICLE.STATE.HOLDING then
							is_all_vehicles_at_search_area = false
						end
					end

					if is_all_vehicles_at_search_area then
						squad.investigate_transform = nil
					end
				else
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			end

			if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then
				local squad_vision = squadGetVisionData(squad)
				local player_counts = {}
				local vehicle_counts = {}
				local function incrementCount(t, index) t[index] = t[index] and t[index] + 1 or 1 end
				local function decrementCount(t, index) t[index] = t[index] and t[index] - 1 or 0 end
				local function getCount(t, index) return t[index] or 0 end

				local function retargetVehicle(vehicle_object, target_player_id, target_vehicle_id)
					-- decrement previous target count
					if pl.isPlayer(vehicle_object.target_player_id) then 
						decrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id then 
						decrementCount(vehicle_counts, vehicle_object.target_vehicle_id) 
					end

					vehicle_object.target_player_id = target_player_id
					vehicle_object.target_vehicle_id = target_vehicle_id

					-- increment new target count
					if pl.isPlayer(vehicle_object.target_player_id) then 
						incrementCount(player_counts, vehicle_object.target_player_id)
					elseif vehicle_object.target_vehicle_id then 
						incrementCount(vehicle_counts, vehicle_object.target_vehicle_id) 
					end
				end


				-- vision checking for vehicles to target
				-- TODO: Read into this and make a few modficiations like making the targeting system more intelligent and possibly improve the performance impact
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- check existing target is still visible

					if pl.isPlayer(vehicle_object.target_player_id) and squad_vision:isPlayerVisible(vehicle_object.target_player_id) == false then
						vehicle_object.target_player_id = nil
					elseif vehicle_object.target_vehicle_id and squad_vision:isVehicleVisible(vehicle_object.target_vehicle_id) == false then
						vehicle_object.target_vehicle_id = nil
					end

					-- find targets if not targeting anything

					if not pl.isPlayer(vehicle_object.target_player_id) and not vehicle_object.target_vehicle_id then
						if #squad_vision.visible_players > 0 then
							vehicle_object.target_player_id = squad_vision:getBestTargetPlayerID()
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif #squad_vision.visible_vehicles > 0 then
							vehicle_object.target_vehicle_id = squad_vision:getBestTargetVehicleID()
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					else
						if pl.isPlayer(vehicle_object.target_player_id) then
							incrementCount(player_counts, vehicle_object.target_player_id)
						elseif vehicle_object.target_vehicle_id then
							incrementCount(vehicle_counts, vehicle_object.target_vehicle_id)
						end
					end
				end

				local squad_vehicle_count = #squad.vehicles
				local visible_target_count = #squad_vision.visible_players + #squad_vision.visible_vehicles
				local vehicles_per_target = math.max(math.floor(squad_vehicle_count / visible_target_count), 1)

				local function isRetarget(target_player_id, target_vehicle_id)
					return (not pl.isPlayer(target_player_id) and not target_vehicle_id) 
						or (pl.isPlayer(target_player_id) and getCount(player_counts, target_player_id) > vehicles_per_target)
						or (target_vehicle_id and getCount(vehicle_counts, target_vehicle_id) > vehicles_per_target)
				end

				-- find vehicles to retarget to visible players

				for visible_player_id, visible_player in pairs(squad_vision.visible_players_map) do
					if getCount(player_counts, visible_player_id) < vehicles_per_target then
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isRetarget(vehicle_object.target_player_id, vehicle_object.target_vehicle_id) then
								retargetVehicle(vehicle_object, visible_player_id, nil)
								break
							end
						end
					end
				end

				-- find vehicles to retarget to visible vehicles

				for visible_vehicle_id, visible_vehicle in pairs(squad_vision.visible_vehicles_map) do
					if getCount(vehicle_counts, visible_vehicle_id) < vehicles_per_target then
						for vehicle_id, vehicle_object in pairs(squad.vehicles) do
							if isRetarget(vehicle_object.target_player_id, vehicle_object.target_vehicle_id) then
								retargetVehicle(vehicle_object, nil, visible_vehicle_id)
								break
							end
						end
					end
				end

				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					-- update waypoint and target data

					-- if its targeting a player or a vehicle

					local player_data = pl.dataBySID(vehicle_object.target_player_id)

					if player_data or vehicle_object.target_vehicle_id then
						local target_pos = nil
						local target_id = nil
						local target_type = ""
						if player_data then -- if its targeting a player
							target_pos = squad_vision.visible_players_map[vehicle_object.target_player_id].obj.last_known_pos
							target_id = pl.objectIDFromSteamID(vehicle_object.target_player_id)
							target_type = "character"
						else -- if its targeting a vehicle
							target_pos = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj.last_known_pos
							target_id = vehicle_object.target_vehicle_id
							target_type = "vehicle"
						end


						-- make sure we have a target position and target id
						if target_pos and target_id then

							if g_air_vehicles_kamikaze and (vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or vehicle_object.vehicle_type == VEHICLE.TYPE.HELI) then

								p.resetPath(vehicle_object)
								p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] - 5, target_pos[15]))
								s.setAITarget(vehicle_object.survivors[1], m.translation(target_pos[13], target_pos[14] - 5, target_pos[15]))

								if m.xzDistance(vehicle_object.transform, m.translation(target_pos[13], target_pos[14], target_pos[15])) < 100 then
									s.setAIState(vehicle_object.survivors[1], 0)
									s.setCharacterData(vehicle_object.survivors[1], 1, true, false)
									--d.print("murder.")
								else
									s.setAIState(vehicle_object.survivors[1], 2)
								end
								

							elseif #vehicle_object.path < 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE and target_pos[14] <= 50 and vehicle_object.state.is_simulating then -- if we dont have any more paths
								
								-- reset its path
								if #vehicle_object.path < 1 then
									p.resetPath(vehicle_object)
								end

								

								if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then -- if this vehicle is a plane
									if vehicle_object.strategy == "strafing" then -- if the plane has a strategy of strafing
										if target_pos[14] <= 50 and vehicle_object.state.is_simulating then -- if the target's y is below the threshold for detecting its a air vehicle
											local dist_in_front = 870
											local engage_dist = 775
											-- distance from <dist_in_front>m in front of the jet to target
											local in_front_dist = m.xzDistance(target_pos, m.multiply(vehicle_object.transform, m.translation(0, 0, dist_in_front)))

											--[[ debug
											if not g_savedata.temp_ui_id then
												g_savedata.temp_ui_id = s.getMapID()
											end

											local in_front = m.multiply(vehicle_object.transform, m.translation(0, 0, dist_in_front))
											s.removeMapObject(-1, g_savedata.temp_ui_id)
											s.addMapObject(-1, g_savedata.temp_ui_id, 1, 11, in_front[13], in_front[15], 0, 0, 0, 0, "in front", 0, "in front", 255, 255, 0, 255)
											]]
											
											-- distance from jet to target
											local jet_dist = m.xzDistance(target_pos, vehicle_object.transform)

											-- if in front of the jet is closer to the target than the jet is, and its within distance to start the strafe
											if in_front_dist < jet_dist and jet_dist <= engage_dist then
												p.resetPath(vehicle_object)
												p.addPath(vehicle_object, m.translation(target_pos[13], math.max(target_pos[14] + 5, 18), target_pos[15]))
												-- d.print("strafing", true, 0)
												vehicle_object.just_strafed = true
											else
												--[[ debug
												local a = " 1" -- 1 =  jet is closer than infront dist
												if in_front_dist < jet_dist then -- 2 = not within engage dist
													a = " 2"
												end
												d.print("normal"..a)
												]]

												--[[ 
												make the jet go further before it starts to try to turn towards the vehicle again
												this ensures the jet will be able to be facing the target when going overhead
												instead of just circling the player
												]]

												if vehicle_object.just_strafed then

													p.resetPath(vehicle_object)
													
													local roll, yaw, pitch = m.getMatrixRotation(vehicle_object.transform)
													p.addPath(vehicle_object, m.translation(
														target_pos[13] + 1000 * math.sin(yaw), -- x
														target_pos[14] + 160, -- y
														target_pos[15] + 1000 * math.cos(yaw) -- z
													))

													--[[ 
													after it goes straight for a bit after strafing, make it circle back around
													to fly towards the target again
													]]

													p.addPath(vehicle_object, m.translation(
														target_pos[13], 
														target_pos[14] + 160, 
														target_pos[15]
													))

													vehicle_object.just_strafed = false
												end
											end
										else -- if we think its an air vehicle
											p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] + 3, target_pos[15]))
										end
									end
									-- to write: dive bombing
								elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
									p.addPath(vehicle_object, m.translation(target_pos[13], target_pos[14] + math.max(target_pos[14] + (vehicle_object.group_id % 5) + 25, 75), target_pos[15]))
								end
							end
								
							for i, object_id in pairs(vehicle_object.survivors) do
								if target_type == "character" then
									s.setAITargetCharacter(object_id, target_id)
								elseif target_type == "vehicle" then
									s.setAITargetVehicle(object_id, target_id)
								end
	
								if i ~= 1 or vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
									if not g_air_vehicles_kamikaze or (vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE and vehicle_object.vehicle_type ~= VEHICLE.TYPE.HELI) then 
										s.setAIState(object_id, 1)
									end
								end
							end
						end
					end
				end

				if squad_vision:is_engage() == false then
					setSquadCommand(squad, SQUAD.COMMAND.NONE)
				end
			end
		end
		::break_squadron::
	end
	d.stopProfiler("tickSquadrons()", true, "onTick()")
end

function tickVision(game_ticks)
	d.startProfiler("tickVision()", true)
	-- get the ai's vision radius
	
	local clock = s.getTime()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(vehicle_id, 240) then
				local weather = s.getWeather(vehicle_object.transform)
				if vehicle_object.vision.is_radar then
					-- has radar
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.2)) * (0.8 + (math.min(clock.daylight_factor*1.8, 1) * 0.2)) * (1 - (weather.rain * 0.2))
				else
					-- no radar
					vehicle_object.vision.radius = vehicle_object.vision.base_radius * (1 - (weather.fog * 0.6)) * (0.4 + (math.min(clock.daylight_factor*1.8, 1) * 0.6)) * (1 - (weather.rain * 0.6))
				end
			end
		end
	end

	-- analyse player vehicles
	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		local player_vehicle_transform = player_vehicle.transform

		for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
			if squad_index ~= RESUPPLY_SQUAD_INDEX then
				--Squads targetting this player can bypass the throttling. That way, the target position keypads for AI vehicles stay updated
				if isTickID(squad_index, 20) or (squad.target_vehicles[player_vehicle_id] ~= nil) then
					-- reset target visibility state to investigate

					if squad.target_vehicles[player_vehicle_id] ~= nil then
						if player_vehicle.death_pos == nil then
							squad.target_vehicles[player_vehicle_id].state = TARGET_VISIBILITY_INVESTIGATE
						else
							squad.target_vehicles[player_vehicle_id] = nil
						end
					end

					-- check if target is visible to any vehicles
					for group_id, vehicle_object in pairs(squad.vehicles) do
						local vehicle_transform = vehicle_object.transform

						if vehicle_transform ~= nil and player_vehicle_transform ~= nil then
							local distance = m.distance(player_vehicle_transform, vehicle_transform)

							local local_vision_radius = vehicle_object.vision.radius

							if not vehicle_object.vision.is_sonar and player_vehicle_transform[14] < -1 then
								-- if the player is in the water, and the player is below y -1, then reduce the player's sight level depending on the player's depth
								local_vision_radius = local_vision_radius * math.min(0.15 / (math.abs(player_vehicle_transform[14]) * 0.2), 0.15)
							end

							if distance < local_vision_radius and player_vehicle.death_pos == nil then
								if squad.target_vehicles[player_vehicle_id] == nil then
									---@class TargetVehicle
									squad.target_vehicles[player_vehicle_id] = {
										state = TARGET_VISIBILITY_VISIBLE,
										last_known_pos = player_vehicle_transform
									}
								else
									local target_vehicle = squad.target_vehicles[player_vehicle_id]
									target_vehicle.state = TARGET_VISIBILITY_VISIBLE
									target_vehicle.last_known_pos = player_vehicle_transform
								end

								break
							end
						end
					end
				end
			end
		end

		if isTickID(player_vehicle_id, 240) then
			if player_vehicle.death_pos ~= nil then
				if m.distance(player_vehicle.death_pos, player_vehicle_transform) > 500 then
					local player_vehicle_data, is_success = s.getVehicleData(player_vehicle_id)
					player_vehicle.death_pos = nil
					if is_success and player_vehicle_data.voxels then
						player_vehicle.damage_threshold = player_vehicle.damage_threshold + player_vehicle_data.voxels / 10
					end
				end
			end
		end
	end

	-- analyse players
	for _, player in ipairs(s.getPlayers()) do
		local player_steam_id = tostring(player.steam_id)
		if player_steam_id then
			local player_transform = s.getPlayerPos(player.id)
			
			for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
				if squad_index ~= RESUPPLY_SQUAD_INDEX then
					-- reset target visibility state to investigate

					if squad.target_players[player_steam_id] ~= nil then
						squad.target_players[player_steam_id].state = TARGET_VISIBILITY_INVESTIGATE
					end

					-- check if target is visible to any vehicles

					for vehicle_id, vehicle_object in pairs(squad.vehicles) do
						local distance = m.distance(player_transform, vehicle_object.transform)

						if distance <= vehicle_object.vision.radius then
							g_savedata.ai_knowledge.last_seen_positions[player_steam_id] = player_transform
							if squad.target_players[player_steam_id] == nil then
								---@class TargetPlayer
								squad.target_players[player_steam_id] = {
									state = TARGET_VISIBILITY_VISIBLE,
									last_known_pos = player_transform,
								}
							else
								local target_player = squad.target_players[player_steam_id]
								target_player.state = TARGET_VISIBILITY_VISIBLE
								target_player.last_known_pos = player_transform
							end
							
							break
						end
					end
				end
			end
		end
	end

	d.startProfiler("updateKeypads", true)
	-- update all of the keypads on the AI vehicles which are loaded
	for _, squad in pairs(g_savedata.ai_army.squadrons) do
		for vehicle_id, vehicle_object in pairs(squad.vehicles) do
			if vehicle_object.state.is_simulating then
				if pl.isPlayer(vehicle_object.target_player_id) or vehicle_object.target_vehicle_id then
					setVehicleKeypads(vehicle_id, vehicle_object, squad)
				end
			end
		end
	end
	d.stopProfiler("updateKeypads", true, "onTick()")
	d.stopProfiler("tickVision()", true, "onTick()")
end

function tickVehicles(game_ticks)
	d.startProfiler("tickVehicles()", true)
	local vehicle_update_tickrate = 30
	if isTickID(60, 60) then
		debug_mode_blinker = not debug_mode_blinker
	end

	-- save vehicle transform, and update vehicle debug
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do

			if not vehicle_object.state.is_simulating then
				goto continue_tickVehicles_updateTransform
			end

			local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

			-- ensure we got the main_vehicle_id
			if not main_vehicle_id then
				d.print("main_vehicle_id is nil", true, 1)
				goto continue_tickVehicles_updateTransform
			end

			vehicle_object.transform = server.getVehiclePos(main_vehicle_id)

			vehicle_object.transform_history[getTickID(group_id, 120)] = vehicle_object.transform

			if d.getDebug(6) then
				local text = ""

				-- name
				text = text..vehicle_object.name
				
				-- Group ID
				text = text..("\nGroup ID: %s"):format(group_id)

				local pos_last = vehicle_object.transform_history[getTickID(group_id - 30, 120)]

				if pos_last then
					-- velocity
					local velocity = m.velocity(vehicle_object.transform, pos_last, 30)

					text = text..("\n\nVel: %0.3f"):format(velocity)

					local pos_second_last = vehicle_object.transform_history[getTickID(group_id - 60, 120)]
					if pos_second_last then
						-- acceleration
						local acceleration = m.acceleration(vehicle_object.transform, pos_last, pos_second_last, 30)

						text = text..("\nAccel: %0.3f"):format(acceleration)
					end
				end

				for peer_index, peer in pairs(s.getPlayers()) do
					if d.getDebug(6, peer.id) then
						if pos_last then
							server.setPopup(peer.id, vehicle_object.ui_id, "", true, text, 0, 0, 0, 2500, group_id)
						end
					end
				end
			end

			::continue_tickVehicles_updateTransform::
		end
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(group_id, vehicle_update_tickrate) then

				-- if air crash mode is enabled
				-- then we want to check if this vehicle is a plane or heli
				-- if it is, we want to see how much its moved
				-- and compare it to the previous time we checked, if its a large difference, then we make it explode.
				if g_savedata.settings.AIR_CRASH_MODE and vehicle_object.state.is_simulating then
					if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then

						-- get its previous positions

						-- position from 30 (vehicle_update_tickrate) ticks ago
						local last_pos = vehicle_object.transform_history[getTickID(group_id - vehicle_update_tickrate, 120)]

						-- position from 60 (vehicle_update_tickrate*2) ticks ago
						local second_last_pos = vehicle_object.transform_history[getTickID(group_id - vehicle_update_tickrate * 2, 120)]

						-- make sure they both exist
						if last_pos and second_last_pos then

							local total_vel_change = math.abs(m.acceleration(vehicle_object.transform, last_pos, second_last_pos, vehicle_update_tickrate))

							--[[
								if its velocity changed too much from the last, then it likely crashed
								as well, if it's position changed too little from previous, then it also likely crashed
							]]

							local total_pos_change = m.distance(second_last_pos, vehicle_object.transform)*(vehicle_update_tickrate*2)/60

							--d.print("Pos change from last: "..(total_pos_change), true, 0)

							if total_vel_change >= 50 or total_pos_change < 0.012 then
								d.print(("Vehicle %s (%i) Crashed! (total_vel_change: %s total_pos_change: %s)"):format(vehicle_object.name, group_id, total_vel_change, total_pos_change), true, 0)
								v.kill(vehicle_object, true)
								goto continue_vehicle
							end
						end
					end
				end

				-- scout vehicles
				if vehicle_object.role == "scout" then
					local target_island, origin_island = Objective.getIslandToAttack(true)
					if target_island then -- makes sure there is a target island
						if g_savedata.ai_knowledge.scout[target_island.name].scouted < scout_requirement then
							if #vehicle_object.path == 0 then -- if its finishing circling the island
								setSquadCommandScout(squad)
							end
							local attack_target_island, attack_origin_island = Objective.getIslandToAttack()
							if m.xzDistance(vehicle_object.transform, target_island.transform) <= vehicle_object.vision.radius then
								if attack_target_island.name == target_island.name then -- if the scout is scouting the island that the ai wants to attack
									-- scout it normally
									if target_island.faction == ISLAND.FACTION.NEUTRAL then
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate * 4, 0, scout_requirement)
									else
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate, 0, scout_requirement)
									end
								else -- if the scout is scouting an island that the ai is not ready to attack
									-- scout it 4x slower
									if target_island.faction == ISLAND.FACTION.NEUTRAL then
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate, 0, scout_requirement)
									else
										g_savedata.ai_knowledge.scout[target_island.name].scouted = math.clamp(g_savedata.ai_knowledge.scout[target_island.name].scouted + vehicle_update_tickrate / 4, 0, scout_requirement)
									end
								end
							end
						end
					else
						setSquadCommandDefend(squad, g_savedata.ai_base_island)
					end
				end

				local modifier = 1
				local tile, got_tile = s.getTile(vehicle_object.transform)
				-- if its not on the ocean tile, make its explosion depth 3x lower, if its a boat
				if got_tile and tile.name ~= "" and vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
					modifier = 6
				end

				-- check if the vehicle has sunk or is under water
				if vehicle_object.transform[14] <= vehicle_object.sink_depth/modifier then --explosion_depths[vehicle_object.vehicle_type]/modifier then
					if vehicle_object.role ~= SQUAD.COMMAND.CARGO then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							vehicle_object.sinking_counter = (vehicle_object.sinking_counter or 0) + 1
							if vehicle_object.sinking_counter > 8 then
								v.kill(vehicle_object, true)
								d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
							end
						else
							v.kill(vehicle_object, true)
							d.print("Killed "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					else

						-- refund the cargo to the island which was sending the cargo
						Cargo.refund(group_id)

						v.kill(vehicle_object)
						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it sank!", true, 0)
						else
							d.print("Killing Cargo Vehicle "..string.upperFirst(vehicle_object.vehicle_type).." as it went into the water! (y = "..vehicle_object.transform[14]..")", true, 0)
						end
					end
					goto continue_vehicle
				else
					vehicle_object.sinking_counter = 0
				end

				local ai_target = nil
				if ai_state ~= 2 then ai_state = 1 end
				local ai_speed_pseudo = (vehicle_object.speed.speed or VEHICLE.SPEED.BOAT) * vehicle_update_tickrate / 60

				if(vehicle_object.vehicle_type ~= VEHICLE.TYPE.TURRET) then

					if vehicle_object.state.s == VEHICLE.STATE.PATHING then

						ai_speed_pseudo = v.getSpeed(vehicle_object)

						if #vehicle_object.path == 0 then
							AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
						else
							if ai_state ~= 2 then ai_state = 1 end

							ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

							if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then ai_target[14] = 0 end
	
							local vehicle_pos = vehicle_object.transform
							local distance = m.xzDistance(ai_target, vehicle_pos)
	
							if vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE and distance < WAYPOINT_CONSUME_DISTANCE * 4 and vehicle_object.role == "scout" or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE or distance < WAYPOINT_CONSUME_DISTANCE and vehicle_object.vehicle_type == VEHICLE.TYPE.HELI or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND and distance < 7 then
								if #vehicle_object.path > 0 then
									p.nextPath(vehicle_object)

									if #vehicle_object.path > 0 then
										ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)
									end

									--[[update the current path the vehicle is on for cargo vehicles
									if vehicle_object.role == SQUAD.COMMAND.CARGO then
										g_savedata.cargo_vehicles[vehicle_id].path_data.current_path = g_savedata.cargo_vehicles[vehicle_id].path_data.current_path + 1
									end
									]]

								elseif vehicle_object.role == "scout" then
									p.resetPath(vehicle_object)
									target_island, origin_island = Objective.getIslandToAttack(true)
									if target_island then
										local holding_route = g_holding_pattern
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[1].x, CRUISE_HEIGHT * 2, holding_route[1].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[2].x, CRUISE_HEIGHT * 2, holding_route[2].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[3].x, CRUISE_HEIGHT * 2, holding_route[3].z)))
										p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[4].x, CRUISE_HEIGHT * 2, holding_route[4].z)))
									end
								elseif vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
									-- if we have reached last waypoint start holding there
									--d.print("set plane "..vehicle_id.." to holding", true, 0)
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT and distance < WAYPOINT_CONSUME_DISTANCE then
								if #vehicle_object.path > 0 then
									p.nextPath(vehicle_object)
								else
									-- if we have reached last waypoint start holding there
									--d.print("set boat "..vehicle_id.." to holding", true, 0)
									AI.setState(vehicle_object, VEHICLE.STATE.HOLDING)
								end
							end

							-- if the target has moved far enough, then we want to add to our path.

							if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND and squad.command == SQUAD.COMMAND.ENGAGE then

								local squad_vision = squadGetVisionData(squad)

								if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
									target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj
								elseif pl.isPlayer(vehicle_object.target_player_id) and vehicle_object.target_player_id and squad_vision.visible_players_map[vehicle_object.target_player_id] then
									target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
								end

								if target and (not target.last_pathfind_pos or m.distance(target.last_known_pos, target.last_pathfind_pos) > 20) then
									target.last_pathfind_pos = target.last_known_pos
									ai_target = target.last_pathfind_pos

									p.resetPath(vehicle_object)

									local distance = m.distance(vehicle_object.transform, ai_target)
									local possiblePaths = s.pathfind(vehicle_object.transform, ai_target, "land_path", "")
									local is_better_pos = false
									for path_index, path in pairs(possiblePaths) do
										if m.distance(m.translation(path.x, path.y, path.z), ai_target) < distance then
											is_better_pos = true
										end
									end
									if is_better_pos then
										p.addPath(vehicle_object, ai_target)
										--? if its target is at least 5 metres above sea level and its target is within 35 metres of its final waypoint.
										if ai_target[14] > 5 and m.xzDistance(ai_target, m.translation(vehicle_object.path[#vehicle_object.path].x, 0, vehicle_object.path[#vehicle_object.path].z)) < 35 then
											--* replace its last path be where the target is.
											vehicle_object.path[#vehicle_object.path] = {
												x = ai_target[13],
												y = ai_target[14],
												z = ai_target[15],
												ui_id = vehicle_object.path[#vehicle_object.path].ui_id
											}
										end
									else
										ai_state = 0
									end
								end
							end
						end

						if squad.command == SQUAD.COMMAND.ENGAGE or squad.command == SQUAD.COMMAND.CARGO then 
							if vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then
								ai_state = 3
							elseif vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then
								target_pos = nil
								if pl.isPlayer(vehicle_object.target_player_id) then
									target_pos = s.getPlayerPos(pl.dataBySID(vehicle_object.target_player_id).peer_id)
								elseif vehicle_object.target_vehicle_id then
									target_pos = s.getVehiclePos(vehicle_object.target_vehicle_id)
								end
								
								if target_pos and target_pos[14] >= 50 then
									ai_state = 2
								else
									ai_state = 1
								end
							end

						end


						refuel(group_id)
					elseif vehicle_object.state.s == VEHICLE.STATE.HOLDING then

						ai_speed_pseudo = (vehicle_object.speed.speed or VEHICLE.SPEED.PLANE) * vehicle_update_tickrate / 60

						if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
							ai_state = 0
						elseif vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
							local target = nil
							if squad_index ~= RESUPPLY_SQUAD_INDEX then -- makes sure its not resupplying
								local squad_vision = squadGetVisionData(squad)
								if vehicle_object.target_vehicle_id and squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id] then
									target = squad_vision.visible_vehicles_map[vehicle_object.target_vehicle_id].obj
								elseif pl.isPlayer(vehicle_object.target_player_id) and vehicle_object.target_player_id and squad_vision.visible_players_map[vehicle_object.target_player_id] then
									target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj
								end
								if target and m.distance(vehicle_object.transform, target.last_known_pos) > 35 then
									ai_target = target.last_known_pos
									local distance = m.distance(vehicle_object.transform, ai_target)
									local possiblePaths = s.pathfind(vehicle_object.transform, ai_target, "land_path", "")
									local is_better_pos = false
									for path_index, path in pairs(possiblePaths) do
										if m.distance(m.translation(path.x, path.y, path.z), ai_target) < distance then
											is_better_pos = true
										end
									end
									if is_better_pos then
										p.addPath(vehicle_object, ai_target)
										--? if its target is at least 5 metres above sea level and its target is within 35 metres of its final waypoint.
										if ai_target[14] > 5 and m.xzDistance(ai_target, m.translation(vehicle_object.path[#vehicle_object.path].x, 0, vehicle_object.path[#vehicle_object.path].z)) < 35 then
											--* replace its last path be where the target is.
											vehicle_object.path[#vehicle_object.path] = {
												x = ai_target[13],
												y = ai_target[14],
												z = ai_target[15],
												ui_id = vehicle_object.path[#vehicle_object.path].ui_id
											}
										end
									else
										ai_state = 0
									end
								else
									ai_state = 0
								end
							end
						else
							ai_target = m.translation(vehicle_object.holding_target[13] + g_holding_pattern[vehicle_object.holding_index].x, vehicle_object.holding_target[14], vehicle_object.holding_target[15] + g_holding_pattern[vehicle_object.holding_index].z)

							vehicle_object.path[1] = {
								x = ai_target[13],
								y = ai_target[14],
								z = ai_target[15],
								ui_id = (vehicle_object.path[1] and vehicle_object.path[1].ui_id) and vehicle_object.path[1].ui_id or s.getMapID()
							}

							ai_state = 1

							local distance = m.distance(ai_target, vehicle_object.transform)

							if distance < WAYPOINT_CONSUME_DISTANCE then
								vehicle_object.holding_index = 1 + ((vehicle_object.holding_index) % 4);
							end
						end
					end

					--set ai behaviour
					if ai_target ~= nil then
						if vehicle_object.state.is_simulating then
							if not g_air_vehicles_kamikaze or (vehicle_object.vehicle_type ~= VEHICLE.TYPE.PLANE and vehicle_object.vehicle_type ~= VEHICLE.TYPE.HELI) then 
								s.setAITarget(vehicle_object.survivors[1], ai_target)
								s.setAIState(vehicle_object.survivors[1], ai_state)
							end
						else
							local exhausted_movement = false
							local pseudo_speed_modifier = 0

							local current_pos = vehicle_object.transform

							while not exhausted_movement do
								local movement_x = ai_target[13] - current_pos[13]
								local movement_y = ai_target[14] - current_pos[14]
								local movement_z = ai_target[15] - current_pos[15]

								local length_xz = math.sqrt((movement_x * movement_x) + (movement_z * movement_z))

								local speed_pseudo = (ai_speed_pseudo * g_debug_speed_multiplier * game_ticks) - pseudo_speed_modifier

								if math.noNil(math.abs(movement_x * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_x)) and math.noNil(math.abs(movement_z * speed_pseudo / length_xz)) <= math.noNil(math.abs(movement_z)) or not vehicle_object.path[2] then
									exhausted_movement = true
								end

								movement_x = math.clamp(movement_x * speed_pseudo / length_xz, -math.abs(movement_x), math.abs(movement_x))
								movement_y = math.clamp(movement_y * speed_pseudo / length_xz, -math.abs(movement_y), math.abs(movement_y))
								movement_z = math.clamp(movement_z * speed_pseudo / length_xz, -math.abs(movement_z), math.abs(movement_z))

								local rotation_matrix = matrix.rotationToFaceXZ(movement_x, movement_z)
								local new_pos = matrix.multiply(matrix.translation(current_pos[13] + movement_x, current_pos[14] + movement_y, current_pos[15] + movement_z), rotation_matrix)

								local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

								-- Ensure we got the main_vehicle_id
								if not main_vehicle_id then
									d.print("main_vehicle_id is nil", true, 1)
									goto continue_vehicle
								end

								if server.getVehicleLocal(main_vehicle_id) == false then
									-- try with main_vehicle_id
									--local set_pos = server.setGroupPos(main_vehicle_id, new_pos)

									-- if it failed
									--if not set_pos then
										--d.print(("Failed to set pseudo group pos via main_vehicle_id for vehicle with group_id: %s"):format(group_id), true, 1)
									--end

									-- try with group_id
									local set_pos = server.moveGroup(group_id, new_pos)

									-- if it failed
									if not set_pos then
										d.print(("Failed to set pseudo group pos via group_id for vehicle with group_id: %s"):format(group_id), true, 1)
									end

									vehicle_object.transform = new_pos

									-- draw their new position on the map
									-- Map.addMapCircle(-1, vehicle_object.path[0].ui_id, new_pos, 5, 1, 255, 25, 25, 255, 20)

									for _, object_id in pairs(vehicle_object.survivors) do
										s.setObjectPos(object_id, new_pos)
									end

									if vehicle_object.fire_id ~= nil then
										s.setObjectPos(vehicle_object.fire_id, new_pos)
									end
								end

								if not exhausted_movement then
									p.nextPath(vehicle_object)

									ai_target = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

									pseudo_speed_modifier = math.abs(movement_x) + math.abs(movement_y) + math.abs(movement_z)

									current_pos = new_pos
								end
							end
						end
					end
				end

				if d.getDebug(3) then
					local debug_data = ""
					debug_data = debug_data.."Movement State: "..vehicle_object.state.s .. "\n"
					debug_data = debug_data.."Waypoints: "..#vehicle_object.path .."\n\n"
					
					debug_data = debug_data.."Squad: "..squad_index .."\n"
					debug_data = debug_data.."Command: "..squad.command .."\n"
					debug_data = debug_data.."AI State: "..ai_state .. "\n"

					-- cargo data
					if vehicle_object.role == SQUAD.COMMAND.CARGO then
						local cargo_data = g_savedata.cargo_vehicles[vehicle_object.group_id]
						debug_data = debug_data.."\nOil: "..tostring(vehicle_object.cargo.current.oil).."\n"
						debug_data = debug_data.."Diesel: "..tostring(vehicle_object.cargo.current.diesel).."\n"
						debug_data = debug_data.."Jet Fuel: "..tostring(vehicle_object.cargo.current.jet_fuel).."\n"
						if cargo_data then
							debug_data = debug_data.."Cargo Route Status: "..cargo_data.route_status.."\n"
						end
					end

					if squad.command == SQUAD.COMMAND.CARGO then
						debug_data = debug_data.."Convoy Status: "..tostring(vehicle_object.state.convoy.status)
						if vehicle_object.state.convoy.status == CONVOY.WAITING then
							debug_data = debug_data.." for: "..tostring(vehicle_object.state.convoy.waiting_for)
							debug_data = debug_data.."\nReason: "..tostring(vehicle_object.state.convoy.status_reason).."\n"
						end
					end

					debug_data = debug_data.."\nHome Island: "..vehicle_object.home_island.name.."\n"
					if squad.target_island then 
						debug_data = debug_data.."Target Island: "..squad.target_island.name.."\n" 
					end
					debug_data = debug_data .. "Target Player: "..(vehicle_object.target_player_id and pl.dataBySID(vehicle_object.target_player_id).name or "nil").."\n"
					debug_data = debug_data .. "Target Vehicle: "..(vehicle_object.target_vehicle_id and vehicle_object.target_vehicle_id or "nil").."\n\n"

					if squad_index ~= RESUPPLY_SQUAD_INDEX then
						local squad_vision = squadGetVisionData(squad)
						debug_data = debug_data .. "squad visible players: " .. #squad_vision.visible_players .."\n"
						debug_data = debug_data .. "squad visible vehicles: " .. #squad_vision.visible_vehicles .."\n"
						debug_data = debug_data .. "squad investigate players: " .. #squad_vision.investigate_players .."\n"
						debug_data = debug_data .. "squad investigate vehicles: " .. #squad_vision.investigate_vehicles .."\n\n"
					end

					local hp = vehicle_object.health * g_savedata.settings.ENEMY_HP_MODIFIER

					if g_savedata.settings.SINKING_MODE then
						if vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET or vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
							hp = hp * 2.5
						else
							hp = hp * 8
							if vehicle_object.vehicle_type == VEHICLE.TYPE.BOAT then
								hp = hp * 10
							end
						end
					end
					
					debug_data = debug_data .. "hp: " .. (hp - vehicle_object.current_damage) .. " / " .. hp .. "\n"

					local damage_dealt = 0
					for victim_vehicle, damage in pairs(vehicle_object.damage_dealt) do
						damage_dealt = damage_dealt + damage
					end
					debug_data = debug_data.."Damage Dealt: "..damage_dealt.."\n\n"

					debug_data = debug_data.."Base Visiblity Range: "..vehicle_object.vision.base_radius.."\n"
					debug_data = debug_data.."Current Visibility Range: "..vehicle_object.vision.radius.."\n"
					debug_data = debug_data.."Has Radar: "..(vehicle_object.vision.is_radar and "true" or "false").."\n"
					debug_data = debug_data.."Has Sonar: "..(vehicle_object.vision.is_sonar and "true" or "false").."\n\n"

					local ai_speed_pseudo = tostring(v.getSpeed(vehicle_object))

					debug_data = debug_data.."Pseudo Speed: "..ai_speed_pseudo.." m/s\n"
					
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						debug_data = debug_data.."Is Agressive: "..tostring(vehicle_object.is_aggressive).."\n"
						debug_data = debug_data.."Terrain Type: "..tostring(vehicle_object.terrain_type).."\n"
					end

					debug_data = debug_data .. "\nPos: [" .. math.floor(vehicle_object.transform[13]) .. " ".. math.floor(vehicle_object.transform[14]) .. " ".. math.floor(vehicle_object.transform[15]) .. "]\n"
					if ai_target then
						debug_data = debug_data .. "Dest: [" .. math.floor(ai_target[13]) .. " ".. math.floor(ai_target[14]) .. " ".. math.floor(ai_target[15]) .. "]\n"

						local dist_to_dest = m.xzDistance(vehicle_object.transform, ai_target)
						debug_data = debug_data .. "Dist: " .. math.floor(dist_to_dest) .. "m\n"
					end

					if vehicle_object.state.is_simulating then
						local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)
						local needsResupply = not main_vehicle_id and "main_vehicle_id not found" or isVehicleNeedsResupply(main_vehicle_id, "Resupply")
						debug_data = debug_data .. "\nSIMULATING\n"
						debug_data = debug_data .. "needs resupply: " .. tostring(needsResupply) .. "\n"
					else
						debug_data = debug_data .. "\nPSEUDO\n"
						debug_data = debug_data .. "resupply on load: " .. tostring(vehicle_object.is_resupply_on_load) .. "\n"
					end

					local state_icons = {
						[SQUAD.COMMAND.ATTACK] = 18,
						[SQUAD.COMMAND.STAGE] = 2,
						[SQUAD.COMMAND.ENGAGE] = 5,
						[SQUAD.COMMAND.DEFEND] = 19,
						[SQUAD.COMMAND.PATROL] = 15,
						[SQUAD.COMMAND.TURRET] = 14,
						[SQUAD.COMMAND.RESUPPLY] = 11,
						[SQUAD.COMMAND.SCOUT] = 4,
						[SQUAD.COMMAND.INVESTIGATE] = 6,
						[SQUAD.COMMAND.CARGO] = 17
					}
					local r = 0
					local g = 0
					local b = 225
					local vehicle_icon = debug_mode_blinker and 16 or state_icons[squad.command]
					if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
						r = 55
						g = 255
						b = 125
						vehicle_icon = debug_mode_blinker and 12 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.HELI then
						r = 255
						b = 200
						vehicle_icon = debug_mode_blinker and 15 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.PLANE then
						r = 55
						g = 200
						vehicle_icon = debug_mode_blinker and 13 or state_icons[squad.command]
					elseif vehicle_object.vehicle_type == VEHICLE.TYPE.TURRET then
						r = 131
						g = 101
						b = 57
						vehicle_icon = debug_mode_blinker and 14 or state_icons[squad.command]
					end
					if vehicle_object.role == "cargo" then
						local cargo_modifier = 35
						r = math.abs(r - cargo_modifier)
						g = math.abs(g - cargo_modifier)
						b = math.abs(b - cargo_modifier)
					elseif squad.command == SQUAD.COMMAND.CARGO then
						local escort_modifier = 35
						r = math.min(r + escort_modifier, 255)
						g = math.min(g + escort_modifier, 255)
						b = math.min(b + escort_modifier, 255)
					end

					-- the marker type, aka, the icon of the vehicle on the map
					local marker_type = vehicle_icon or 3

					--[[
						the name (title) of the marker when hovered over on the map
						Format:
							<Vehicle Name>
							Group ID: <group_id>
							Vehicle Type: <vehicle_type>
					]]
					local vehicle_name = ("%s\nGroup ID: %i\nVehicle Type: %s\nVariation: %s"):format(vehicle_object.name, vehicle_object.group_id, vehicle_object.vehicle_type, vehicle_object.variation or "unknown")

					s.removeMapLine(-1, vehicle_object.ui_id)
					s.removeMapObject(-1, vehicle_object.ui_id)
					s.removeMapLabel(-1, vehicle_object.ui_id)

					for _, peer in pairs(s.getPlayers()) do
						if d.getDebug(3, peer.id) then

							--[[
								parent it to the vehicle if the player we're drawing it for is the host or if the vehicle is simulating
								as if a vehicle is unloaded, clients will not recieve the vehicle's position from the server, causing it
								to instead be drawn at 0, 0
							]]
							if peer.id == 0 or vehicle_object.state.is_simulating then
								local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

								-- Ensure we got the main_vehicle_id
								if not main_vehicle_id then
									d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
									goto continue_vehicle
								end

								server.addMapObject(peer.id, vehicle_object.ui_id, 1, marker_type, 0, 0, 0, 0, main_vehicle_id, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
							else -- draw at direct coordinates instead
								server.addMapObject(peer.id, vehicle_object.ui_id, 0, marker_type, vehicle_object.transform[13], vehicle_object.transform[15], 0, 0, 0, 0, vehicle_name, vehicle_object.vision.radius, debug_data, r, g, b, 255)
							end

							if(#vehicle_object.path >= 1) then

								local waypoint_pos_next = m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)

								-- get colour from angle
								local angle = math.atan(waypoint_pos_next[13] - vehicle_object.transform[13], waypoint_pos_next[15] - vehicle_object.transform[15])/math.tau*math.pi

								local colour_modifier = 25

								local line_r = math.floor(math.clamp(math.clamp(r, 0, 200) + (angle*colour_modifier), 0, 255))
								local line_g = math.floor(math.clamp(math.clamp(g, 0, 200) + (angle*colour_modifier), 0, 255))
								local line_b = math.floor(math.clamp(math.clamp(b, 0, 200) + (angle*colour_modifier), 0, 255))

								s.addMapLine(peer.id, vehicle_object.ui_id, vehicle_object.transform, waypoint_pos_next, 0.5, line_r, line_g, line_b, 200)

								local dest_radius = 5

								-- if this is the only path
								if #vehicle_object.path == 1 then
									--? draw x at the destination
									s.addMapLabel(peer.id, vehicle_object.ui_id, 1, group_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
								end

								for i = 1, #vehicle_object.path - 1 do
									local waypoint = vehicle_object.path[i]
									local waypoint_next = vehicle_object.path[i + 1]

									local waypoint_pos = m.translation(waypoint.x, waypoint.y, waypoint.z)
									local waypoint_pos_next = m.translation(waypoint_next.x, waypoint_next.y, waypoint_next.z)

									local angle = math.atan(waypoint_pos_next[13] - waypoint_pos[13], waypoint_pos_next[15] - waypoint_pos[15])/math.tau*math.pi

									local line_r = math.floor(math.clamp(math.clamp(r, 0, 200) + (angle*colour_modifier), 0, 255))
									local line_g = math.floor(math.clamp(math.clamp(g, 0, 200) + (angle*colour_modifier), 0, 255))
									local line_b = math.floor(math.clamp(math.clamp(b, 0, 200) + (angle*colour_modifier), 0, 255))

									s.removeMapLine(peer.id, waypoint.ui_id)
									s.addMapLine(peer.id, waypoint.ui_id, waypoint_pos, waypoint_pos_next, 0.5, line_r, line_g, line_b, 200)

									-- if this is the last path
									if i == #vehicle_object.path - 1 then
										--? draw x at the destination
										s.addMapLabel(peer.id, vehicle_object.ui_id, 1, group_id.."'s dest\nname: "..vehicle_object.name, waypoint_pos_next[13], waypoint_pos_next[15])
									end
								end
							end
						end
					end
				end
			end
			::continue_vehicle::
		end
	end
	d.stopProfiler("tickVehicles()", true, "onTick()")
end

function tickUpdateVehicleData(game_ticks)
	--d.startProfiler("tickUpdateVehicleData()", true)
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do
			if isTickID(group_id, 30) then
				local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

				-- Ensure we got the main_vehicle_id
				if not main_vehicle_id then
					d.print(("main_vehicle_id is nil! group_id: %s"):format(group_id), true, 1)
					goto continue_vehicle
				end

				vehicle_object.transform = s.getVehiclePos(main_vehicle_id)
			end

			::continue_vehicle::
		end
	end

	for player_vehicle_id, player_vehicle in pairs(g_savedata.player_vehicles) do
		if isTickID(player_vehicle_id, 30) then
			player_vehicle.transform = s.getVehiclePos(player_vehicle_id)
		end
	end
	--d.stopProfiler("tickUpdateVehicleData()", true, "onTick()")
end

function tickModifiers(game_ticks)
	--d.startProfiler("tickModifiers()", true)

	if isTickID(0, time.hour / 2) then -- defence, if the player has attacked within the last 30 minutes, increase defence
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended <= time.hour / 2 and g_savedata.ai_history.has_defended ~= 0 then -- if the last time the player attacked was equal or less than 30 minutes ago
			sm.train(REWARD, "defend", 4)
			sm.train(PUNISH, "attack", 3)
			d.print("players have attacked within the last 30 minutes! increasing defence, decreasing attack!", true, 0)
		end
	end
	if isTickID(0, time.hour) then -- attack, if the player has not attacked in the last one hour, raise attack
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended > time.hour then -- if the last time the player attacked was more than an hour ago
			sm.train(REWARD, "attack", 3)
			d.print("players have not attacked in the past hour! increasing attack!", true, 0)
		end
	end
	if isTickID(0, time.hour * 2) then -- defence, if the player has not attacked in the last two hours, then lower defence
		if g_savedata.game_tick_counter - g_savedata.ai_history.has_defended > time.hour * 2 then -- if the last time the player attacked was more than two hours ago
			sm.train(PUNISH, "defend", 3)
			d.print("players have not attacked in the last two hours! lowering defence!", true, 0)
		end
	end

	-- checks if the player is nearby the ai's controlled islands, works like a capacitor, however the
	-- closer the player is, the faster it will charge up, once it hits its limit, it will then detect that the
	-- player is attacking, and will then use that to tell the ai to increase on defence
	for island_index, island in pairs(g_savedata.islands) do
		if isTickID(island_index * 30, time.minute / 2) then
			if island.faction == ISLAND.FACTION.AI then
				local player_list = s.getPlayers()
				for player_index, player in pairs(player_list) do
					local player_pos = s.getPlayerPos(player.id)
					local player_island_dist = m.xzDistance(player_pos, island.transform)
					if player_island_dist < 1000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 3
					elseif player_island_dist < 2000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 2
					elseif player_island_dist < 3000 then
						g_savedata.ai_history.defended_charge = g_savedata.ai_history.defended_charge + 1
					end
					if g_savedata.ai_history.defended_charge >= 6 then
						g_savedata.ai_history.defended_charge = 0
						g_savedata.ai_history.has_defended = g_savedata.tick_counter
						island.last_defended = g_savedata.tick_counter
						d.print(player.name.." has been detected to be attacking "..island.name..", the ai will be raising their defences!", true, 0)
					end
				end
			end
		end
	end
	--d.stopProfiler("tickModifiers()", true, "onTick()")
end

function tickVehicleCleaner()
	d.startProfiler("tickVehicleCleaner()", true)

	---@param vehicle_object vehicle_object
	---@param squad_index integer
	local function deleteVehicle(vehicle_object, squad_index)
		Vehicle.kill(vehicle_object, true, true)

		cleanVehicle(squad_index, vehicle_object.group_id)

		d.print(("(VehicleCleaner) Automatically Deleted Vehicle %s (%s)."):format(vehicle_object.group_id, vehicle_object.name), true, 1)
		
		--[[
			Add 1 to vehicle cleaner stats
		]]

		-- ensure the table exists
		g_savedata.vehicle_cleaner_cleaned_vehicles = g_savedata.vehicle_cleaner_cleaned_vehicles or 0

		-- add 1 to the stats
		g_savedata.vehicle_cleaner_cleaned_vehicles = g_savedata.vehicle_cleaner_cleaned_vehicles + 1
	end

	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for _, vehicle_object in pairs(squad.vehicles) do

			if isTickID(vehicle_object.group_id, 240) then
				local main_vehicle_id = VehicleGroup.getMainVehicle(vehicle_object.group_id)

				-- Delete the vehicle if we failed to get it's main_vehicle_id, as it likely does not exist anymore.
				if not main_vehicle_id then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (failed to get main_vehicle_id), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				local vehicle_pos, is_success = server.getVehiclePos(main_vehicle_id)

				-- if getting their position failed
				if not is_success then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (is_success failed on server.getVehiclePos), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				-- if their matrix does not contain the position values.
				if not vehicle_pos[13] or not vehicle_pos[14] or not vehicle_pos[15] then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (matrix does not contain positions), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

				-- if their matrix is at 0, 0, 0
				if
					vehicle_pos[13] == 0 and -- x
					vehicle_pos[14] == 0 and -- y
					vehicle_pos[15] == 0 -- z
					then
					d.print(("Vehicle Cleaner found invalid vehicle with group_id: %s (matrix is at 0, 0, 0), Deleting."):format(vehicle_object.group_id), true, 1)
					deleteVehicle(vehicle_object, squad_index)
					goto continue
				end

			end
			::continue::
		end
	end
	d.stopProfiler("tickVehicleCleaner()", true, "onTick()")
end

--[[ no longer has a use, replaced by automatic migration in 0.3.0.78
function tickOther()
	d.startProfiler("tickOther()", true)
	
	d.stopProfiler("tickOther()", true, "onTick()")
end
-]]

function tickCargo(game_ticks)
	d.startProfiler("tickCargo()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled

		-- ticks cargo production and consumption
		for tick = 1, game_ticks do 
			for island_index, island in pairs(g_savedata.islands) do -- at every island
				if isTickID(island.index + tick, time.minute) then -- every minute
					Cargo.produce(island) -- produce cargo
				end
			end

			if isTickID(g_savedata.ai_base_island.index + tick, time.minute) then -- if its the tick for the AI base Island
				Cargo.produce(g_savedata.ai_base_island, RULES.LOGISTICS.CARGO.ISLANDS.ai_base_generation/60)
			end
		end

		-- ticks resupplying islands
		if table.length(g_savedata.cargo_vehicles) ~= 0 then
			g_savedata.tick_extensions.cargo_vehicle_spawn = g_savedata.tick_extensions.cargo_vehicle_spawn + game_ticks
		elseif isTickID(g_savedata.tick_extensions.cargo_vehicle_spawn, RULES.LOGISTICS.CARGO.VEHICLES.spawn_time) then -- attempt to spawn a cargo vehicle
			d.print("attempting to spawn cargo vehicle", true, 0)

			local resupply_island, resupply_weights = Cargo.getBestResupplyIsland()

			if resupply_island then
				d.print("(tickCargo) Island that needs resupply the most: "..resupply_island.name, true, 0)
				local resupplier_island, total_weights = Cargo.getBestResupplierIsland(resupply_weights)
				if resupplier_island then
					d.print("(tickCargo) Island best to resupply the island: "..resupplier_island.name, true, 0)
					local best_route = Cargo.getBestRoute(resupplier_island, resupply_island)
					if not best_route[1] then
						d.print("best route doesnt exist?", true, 1)
					else

						-- parse the route

						d.print("(tickCargo) from island: "..resupplier_island.name, true, 0)
						for route_index, route in ipairs(best_route) do
							d.print("\n(tickCargo) Route Index: "..route_index, true, 0)
							local island, got_island = is.getDataFromIndex(route.island_index)

							-- check if we got the island.
							if not got_island then
								d.print(("(tickCargo) Failed to get the island we're sending the cargo to? island_index: %s"):format(route.island_index), true, 1)
								return
							end

							d.print("(tickCargo) to island: "..island.name, true, 0)
							if route.transport_method then
								d.print("(tickCargo) with vehicle: "..route.transport_method.name.." | "..route.transport_type, true, 0)
							else
								if route.transport_type then
									d.print("(tickCargo) type: "..route.transport_type, true, 0)
								end
								d.print("(tickCargo) transport method is nil?", true, 1)
								return
							end
						end
						d.print("spawning cargo vehicle...", true, 0)
						local was_spawned, vehicle_data = v.spawnRetry(sm.getVehicleListID(best_route[1].transport_method.name), nil, true, resupplier_island, 1, 20)
						if not was_spawned then
							d.print("Was unable to spawn cargo vehicle! Error: "..tostring(vehicle_data), true, 1)
						else
							-- add it to the cargo vehicles list

							local requested_cargo = Cargo.getRequestedCargo(total_weights, vehicle_data)

							-- make sure we dont try to send more than we can transport, recieve or that we have
							for slot, cargo in pairs(requested_cargo) do
								cargo.amount = math.min(cargo.amount, resupplier_island.cargo[cargo.cargo_type], RULES.LOGISTICS.CARGO.ISLANDS.max_capacity - resupply_island.cargo[cargo.cargo_type])
							end


							---@class CARGO_VEHICLE
							g_savedata.cargo_vehicles[vehicle_data.group_id] = {
								vehicle_data = vehicle_data,
								resupplier_island = resupplier_island,
								resupply_island = resupply_island,
								route_data = best_route,
								route_status = 0,
								requested_cargo = requested_cargo,
								path_data = {
									current_path = 1,
									path = {},
									speed = nil,
									can_offroad = true
								},
								convoy = {},
								search_area = {
									ui_id = s.getMapID(),
									x = nil,
									z = nil
								}
							}

							-- get escorts
							Cargo.getEscorts(vehicle_data, resupplier_island)

							-- get the slowest speed of all of them and if we can offroad
							local squad_index, squad = Squad.getSquad(vehicle_data.group_id)
							for vehicle_index, vehicle_object in pairs(squad.vehicles) do

								-- getting slowest speed
								local vehicle_speed = v.getSpeed(vehicle_object, true, true)
								if not g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed > vehicle_speed then
									g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed = vehicle_speed
								end

								-- checking if we can offroad
								if not vehicle_object.can_offroad then
									g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.can_offroad = false
								end
							end
						end
					end
				else
					d.print("(tickCargo) No islands found that can be a resupplier (Potential Error)", true, 0)
				end
			else
				d.print("(tickCargo) No islands found that need resupply (Potential Error)", true, 0)
			end
		end
	end
	d.stopProfiler("tickCargo()", true, "onTick()")
end

function tickIslands(game_ticks)
	d.startProfiler("tickIslands()", true)

	--* go through and set the cargo tanks for each island, to sync the cargo in the script with the cargo on the island
	if g_savedata.settings.CARGO_MODE then
		for island_index, _ in pairs(g_savedata.loaded_islands) do

			if not isTickID(island_index, 15) then
				goto break_island
			end

			local island, got_island = Island.getDataFromIndex(island_index)

			if not got_island then
				d.print("(tickIslands) Island not found! island_index: "..tostring(island_index), true, 1)
				goto break_island
			end

			if island.cargo.oil <= 0 and island.cargo.diesel <= 0 and island.cargo.jet_fuel <= 0 then
				goto break_island
			end

			local fluid_types = {
				oil = 5,
				diesel = 1,
				jet_fuel = 2
			}

			for cargo_type, amount in pairs(island.cargo) do
				local tank_data, got_tank = s.getVehicleTank(island.flag_vehicle.id, cargo_type)
				if got_tank then
					s.setVehicleTank(island.flag_vehicle.id, cargo_type, math.min(tank_data.capacity, island.cargo[cargo_type]), fluid_types[cargo_type])
					island.cargo[cargo_type] = island.cargo[cargo_type] - (math.min(tank_data.capacity, island.cargo[cargo_type]) - tank_data.value)
					s.setVehicleKeypad(island.flag_vehicle.id, cargo_type, island.cargo[cargo_type])
				end
			end

			if g_savedata.islands[island_index] then
				g_savedata.islands[island_index].cargo = island.cargo
			elseif g_savedata.ai_base_island.index == island_index then
				g_savedata.ai_base_island.cargo = island.cargo
			elseif g_savedata.player_base_island.index == island_index then
				g_savedata.player_base_island.cargo = island.cargo
			end

			::break_island::
		end
	end

	d.stopProfiler("tickIslands()", true, "onTick()")
end

local cargo_vehicle_tickrate = time.second/4

function tickCargoVehicles(game_ticks)
	d.startProfiler("tickCargoVehicles()", true)
	if g_savedata.settings.CARGO_MODE then -- if cargo mode is enabled
		for cargo_vehicle_index, cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
			if isTickID(cargo_vehicle_index, cargo_vehicle_tickrate) then

				local vehicle_object, squad_index, squad = Squad.getVehicle(cargo_vehicle.vehicle_data.group_id)

				-- temporary backwards compatibility for testing version
				if not cargo_vehicle.search_area then
					cargo_vehicle.search_area = {
						ui_id = s.getMapID(),
						x = nil,
						z = nil
					}
				end

				--* draw a search radius around the cargo vehicle

				local search_radius = 1850

				if not cargo_vehicle.search_area.x or m.xzDistance(vehicle_object.transform, m.translation(cargo_vehicle.search_area.x, 0, cargo_vehicle.search_area.z)) >= search_radius then
					--* remove previous search area
					s.removeMapID(-1, cargo_vehicle.search_area.ui_id)

					--* add new search area
					local x, z, was_drawn = Map.drawSearchArea(vehicle_object.transform[13], vehicle_object.transform[15], search_radius, cargo_vehicle.search_area.ui_id, -1, "Convoy", "An enemy AI convoy has been detected to be within this area.\nFind and prevent the cargo from arriving to its destination.", 0, 210, 50, 255)

					if not was_drawn then
						d.print("(tickCargoVehicles) failed to draw search area for cargo vehicle "..tostring(vehicle_object.group_id), true, 1)
					else
						cargo_vehicle.search_area.x = x
						cargo_vehicle.search_area.z = z
					end
				end


				--* sync the script's cargo with the true cargo

				--? if the cargo vehicle is simulating and its in the pathing stage
				if cargo_vehicle.vehicle_data.state.is_simulating and cargo_vehicle.route_status == 1 then
					local cargo_data, got_data = Cargo.getTank(cargo_vehicle.vehicle_data.group_id)
					if got_data then
						cargo_vehicle.requested_cargo = cargo_data

						for cargo_type, _ in pairs(cargo_vehicle.vehicle_data.cargo.current) do
							cargo_vehicle.vehicle_data.cargo.current[cargo_type] = 0
						end

						for slot, cargo in pairs(cargo_data) do
							cargo_vehicle.vehicle_data.cargo.current[cargo.cargo_type] = cargo_vehicle.vehicle_data.cargo.current[cargo.cargo_type] + cargo.amount
						end
					end
				end

				--* tick cargo vehicle behaviour

				--? if the vehicle is in the first stage (loading up with cargo)
				cargo_vehicle.vehicle_data = vehicle_object
				if cargo_vehicle.route_status == 0 then
					local transfer_complete, transfer_complete_reason = Cargo.transfer(cargo_vehicle.vehicle_data, cargo_vehicle.resupplier_island, cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
					if transfer_complete then
						d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
						-- start going on its route
						local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)
						if found_island then
							cargo_vehicle.route_status = 1
							local squad_index, squad = Squad.getSquad(cargo_vehicle.vehicle_data.group_id)
							squad.target_island = island
							p.addPath(cargo_vehicle.vehicle_data, island.transform)
							table.insert(cargo_vehicle.vehicle_data.path, 1, {
								x = cargo_vehicle.vehicle_data.transform[13],
								y = cargo_vehicle.vehicle_data.transform[14],
								z = cargo_vehicle.vehicle_data.transform[15]
							})
							cargo_vehicle.path_data.path = cargo_vehicle.vehicle_data.path
							g_savedata.ai_army.squadrons[squad_index].vehicles[vehicle_object.group_id].path = cargo_vehicle.vehicle_data.path
						else
							d.print("(tickCargoVehicles) island not found! Error: "..island, true, 1)
						end
					end
				-- if the cargo vehicle is in the pathing stage
				elseif cargo_vehicle.route_status == 1 then
					local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)

					local distance_thresholds = {
						plane = 1000,
						boat = 850,
						heli = 350,
						land = 150
					}

					if #cargo_vehicle.vehicle_data.path <= 1 or m.xzDistance(island.transform, cargo_vehicle.vehicle_data.transform) < distance_thresholds[(cargo_vehicle.vehicle_data.vehicle_type)] then
						cargo_vehicle.route_status = 2 -- make it unload the cargo
						table.remove(cargo_vehicle.route_data, 1)
						d.print("transferring cargo", true, 0)
					end
				-- if the cargo vehicle is in the transfering stage
				elseif cargo_vehicle.route_status == 2 then
					-- if its transfering to the next vehicle
					if cargo_vehicle.route_data[1] then
						-- spawn it if it doesnt already exist
						local new_cargo_vehicle = nil
						for next_cargo_vehicle_index, next_cargo_vehicle in pairs(g_savedata.cargo_vehicles) do
							if next_cargo_vehicle.vehicle_data.name == cargo_vehicle.route_data[1].transport_method.name then
								new_cargo_vehicle = g_savedata.cargo_vehicles[next_cargo_vehicle.vehicle_data.id]
								break
							end
						end

						if not new_cargo_vehicle then
							-- spawn it as it doesnt exist
							local island, found_island = Island.getDataFromIndex(cargo_vehicle.route_data[1].island_index)
							local was_spawned, vehicle_data = v.spawnRetry(sm.getVehicleListID(cargo_vehicle.route_data[1].transport_method.name), nil, true, island, 1, 20)
							if not was_spawned or not vehicle_data then
								d.print("Was unable to spawn cargo vehicle! Error: "..tostring(vehicle_data), true, 1)
							else
								-- add it to the cargo vehicles list

								---@class CARGO_VEHICLE
								g_savedata.cargo_vehicles[vehicle_data.group_id] = {
									vehicle_data = vehicle_data,
									resupplier_island = cargo_vehicle.resupplier_island,
									resupply_island = cargo_vehicle.resupply_island,
									route_data = cargo_vehicle.route_data,
									route_status = 3, -- do nothing
									requested_cargo = cargo_vehicle.requested_cargo,
									path_data = {
										current_path = 1,
										path = {},
										speed = nil,
										can_offroad = true
									},
									convoy = {},
									search_area = {
										ui_id = s.getMapID(),
										x = nil,
										z = nil
									}
								}

								table.remove(g_savedata.cargo_vehicles[vehicle_data.group_id].route_data, 1)
									

								-- get escorts
								Cargo.getEscorts(vehicle_data, island)

								-- get the slowest speed of all of them and if we can offroad
								local squad_index, squad = Squad.getSquad(vehicle_data.group_id)
								for vehicle_index, vehicle_object in pairs(squad.vehicles) do

									-- getting slowest speed
									local vehicle_speed = v.getSpeed(vehicle_object, true, true)
									if not g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed or g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed > vehicle_speed then
										g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.speed = vehicle_speed
									end

									-- checking if we can offroad
									if not vehicle_object.can_offroad then
										g_savedata.cargo_vehicles[vehicle_data.group_id].path_data.can_offroad = false
									end
								end
							end
						else
							-- if it does exist
							local transfer_complete, transfer_complete_reason = Cargo.transfer(new_cargo_vehicle.vehicle_data, cargo_vehicle.vehicle_data, new_cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
							if transfer_complete and not cargo_vehicle.vehicle_data.is_killed then
								d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
								-- kill old cargo vehicle
								v.kill(cargo_vehicle.vehicle_data, true) -- kills the vehicle thats now empty

								-- tell new cargo vehicle to go on its route

								local island, found_island = Island.getDataFromIndex(new_cargo_vehicle.route_data[1].island_index)
								if found_island then
									new_cargo_vehicle.route_status = 1
									local _, squad = Squad.getSquad(cargo_vehicle.vehicle_data.group_id)
									squad.target_island = island
									p.addPath(new_cargo_vehicle.vehicle_data, island.transform)
									new_cargo_vehicle.path_data.path = new_cargo_vehicle.vehicle_data.path
								else
									d.print("(tickCargoVehicles) island not found! Error: "..island, true, 1)
								end
							end
						end
					-- if its transfering to the island which needed the resupply
					else
						local transfer_complete, transfer_complete_reason = Cargo.transfer(cargo_vehicle.resupply_island, cargo_vehicle.vehicle_data, cargo_vehicle.requested_cargo, RULES.LOGISTICS.CARGO.transfer_time, cargo_vehicle_tickrate)
						
						if transfer_complete and not cargo_vehicle.vehicle_data.is_killed then
							d.print("transfer completed? "..tostring(transfer_complete).."\nreason: "..transfer_complete_reason, true, 0)
							v.kill(cargo_vehicle.vehicle_data, true) -- kills the vehicle thats now empty
						end
					end
				end
			end
		end
	end
	d.stopProfiler("tickCargoVehicles()", true, "onTick()")
end

function tickControls(game_ticks)
	d.startProfiler("tickControls()", true, "onTick()")
	local control_started = s.getTimeMillisec()
	for squad_index, squad in pairs(g_savedata.ai_army.squadrons) do
		for group_id, vehicle_object in pairs(squad.vehicles) do

			--? is this vehicle even one we can handle
			if vehicle_object.vehicle_type ~= VEHICLE.TYPE.LAND then
				goto break_control_vehicle
			end

			--? is the vehicle loaded
			if not vehicle_object.state.is_simulating then
				goto break_control_vehicle
			end

			--? is the vehicle killed
			if vehicle_object.is_killed then
				--d.print("you are dead, no big suprise.")
				goto break_control_vehicle
			end

			local reaction_time = 3 -- ticks
			--? if this is it's tick (reaction time)
			if not isTickID(group_id, reaction_time) then
				--d.print("no react.")
				goto break_control_vehicle
			end

			--? is the driver incapcitated, dead or non existant
			local driver_data = s.getCharacterData(vehicle_object.survivors[1])
			if not driver_data or driver_data.dead or driver_data.incapacitated then
				--d.print("driver not exist, or is dead, or is incapacitated")
				goto break_control_vehicle
			end

			local main_vehicle_id = VehicleGroup.getMainVehicle(group_id)

			--? if the driver is the one who's sitting in the driver seat
			local loaded_data, got_loaded_data = s.getVehicleComponents(main_vehicle_id)
			if not got_loaded_data then
				--d.print("not got loaded")
				goto break_control_vehicle
			end

			for seat_id, seat_data in pairs(loaded_data.components.seats) do
				if seat_data.name == "Driver" and seat_data.seated_id ~= vehicle_object.survivors[1] then

					if d.getDebug(5) then
						if vehicle_object.driving.ui_id then
							s.removeMapLine(-1, vehicle_object.driving.ui_id)
							s.removeMapLabel(-1, vehicle_object.driving.ui_id)
						end
					end

					--d.print("character in driver seat is not the driver.")

					goto break_control_vehicle
				end
			end

			-- force it to constantly just go directly towards the player.
			--[[if vehicle_object.target_player_id then
				local squad_vision = squadGetVisionData(squad)

				local target = squad_vision.visible_players_map[vehicle_object.target_player_id].obj

				for i = 1, #vehicle_object.path do
					table.remove(vehicle_object.path, 1)
				end

				vehicle_object.path[0] = {
					x = vehicle_object.transform[13],
					y = vehicle_object.transform[14],
					z = vehicle_object.transform[15],
					ui_id = 95912311 - vehicle_object.group_id
				}

				vehicle_object.path[1] =  {
					x = target.last_known_pos[13],
					y = target.last_known_pos[14],
					z = target.last_known_pos[15],
					ui_id = 95912312 + vehicle_object.group_id
				}
			end]]

			--? we have at least 1 path
			if not vehicle_object.path[1] or (vehicle_object.path[0].x == vehicle_object.path[#vehicle_object.path].x and vehicle_object.path[0].y == vehicle_object.path[#vehicle_object.path].y and vehicle_object.path[0].z == vehicle_object.path[#vehicle_object.path].z) then

				if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then
					-- resets seat
					AI.setSeat(group_id, "Driver", 0, 0, 0, 0, false, false, false, false, false, false, false)
				end

				-- removes debug
				if d.getDebug(5) then
					if vehicle_object.driving.ui_id then
						s.removeMapLine(-1, vehicle_object.driving.ui_id)
						s.removeMapLabel(-1, vehicle_object.driving.ui_id)
					end
				end

				--d.print("path no.")

				goto break_control_vehicle
			end

			if vehicle_object.vehicle_type == VEHICLE.TYPE.LAND then

				vehicle_object.transform, got_pos = s.getVehiclePos(main_vehicle_id)
				if not got_pos then
					--d.print("no got pos :(")
					goto break_control_vehicle
				end

				local reverse_timer_max = math.floor((time.second*10)/reaction_time)

				-- sets driving data if it doesnt exist
				if not vehicle_object.driving.old_pos then
					vehicle_object.driving = {
						old_pos = m.translation(0, 0, 0),
						reverse_timer = reverse_timer_max/2,
						ui_id = vehicle_object.driving.ui_id
					}
				end

				local vehicle_vector = { -- a
					x = vehicle_object.transform[13] - vehicle_object.path[0].x,
					z = vehicle_object.transform[15] - vehicle_object.path[0].z
				}

				local path_vector = { -- b
					x = vehicle_object.path[1].x - vehicle_object.path[0].x,
					z = vehicle_object.path[1].z - vehicle_object.path[0].z
				}

				local path_vector_length = math.sqrt(path_vector.x^2 + path_vector.z^2)

				--d.print("path_vector_length: "..path_vector_length, true, 0)

				local path_progress = math.max(0, (vehicle_vector.x * path_vector.x + vehicle_vector.z * path_vector.z) / path_vector_length)

				local path_vector_normalized = {
					x = path_vector.x / path_vector_length,
					z = path_vector.z / path_vector_length
				}

				--d.print("path_progress: "..path_progress, true, 0)

				local pos_on_path = {
					x = vehicle_object.path[0].x + path_vector_normalized.x * path_progress,
					z = vehicle_object.path[0].z + path_vector_normalized.z * path_progress
				}

				local projected_dist = 20

				local path_projection = math.min(projected_dist, math.sqrt((vehicle_object.path[1].x-pos_on_path.x)^2+(vehicle_object.path[1].z-pos_on_path.z)^2)) -- metres

				--d.print("path_projection: "..path_projection, true, 0)

				-- close enough to next path, we can go to the next path.
				if path_projection <= projected_dist/2 then
					p.nextPath(vehicle_object)
					goto break_control_vehicle
				end

				local target_pos = {
					x = vehicle_object.path[0].x + path_vector_normalized.x * (path_progress + path_projection),
					z = vehicle_object.path[0].z + path_vector_normalized.z * (path_progress + path_projection)
				}

				-- Angle to the scalar projected target position.
				local target_angle = math.atan(target_pos.x - vehicle_object.transform[13], target_pos.z - vehicle_object.transform[15])

				local speed = v.getSpeed(vehicle_object, true)

				local x_axis, y_axis, z_axis = m.getMatrixRotation(vehicle_object.transform)
				--d.print("y_axis: "..y_axis, true, 0)
				--d.print("target_angle: "..target_angle, true, 0)
				local ad = math.wrap(y_axis - target_angle, -math.pi, math.pi)
				--d.print("ad: "..ad, true, 0)

				-- speed modifier for the upcoming turns (slows down for turns)
				local previous_yaw = math.atan(vehicle_object.path[1].x - vehicle_object.transform[13], vehicle_object.path[1].z - vehicle_object.transform[15])
				local total_dist = m.distance(vehicle_object.transform, m.translation(vehicle_object.path[1].x, vehicle_object.path[1].y, vehicle_object.path[1].z)) -- the total distance checked so far, used for weight

				local max_dist = 200

				local min_speed = 8

				local speed_before = speed

				local next_paths_debug = {}

				for i = 0, #vehicle_object.path-1 do
					local dist = m.distance((i ~= 0 and m.translation(vehicle_object.path[i].x, vehicle_object.path[i].y, vehicle_object.path[i].z) or vehicle_object.transform), m.translation(vehicle_object.path[i + 1].x, vehicle_object.path[i + 1].y, vehicle_object.path[i + 1].z))
					total_dist = total_dist + dist
					--d.print("total_dist: "..total_dist, true, 0)

					local path_yaw = i ~= 0 and math.atan(vehicle_object.path[i+1].x - vehicle_object.path[i].x, vehicle_object.path[i+1].z - vehicle_object.path[i].z) or y_axis
					local yaw_difference = math.wrap(math.abs(previous_yaw - path_yaw), -math.pi, math.pi)

					local yaw_modifier = ((yaw_difference ^ yaw_difference)/4) / (math.max(((total_dist/1.5*(math.max(i, 1)/3))/(max_dist*16))*max_dist/8, 0.3)/3)
					if yaw_difference < 0.21 then
						yaw_modifier = math.max(1, (yaw_modifier - 1) / 12 + 1)
					end

					--d.print("i: "..i.."\nyaw_modifier: "..yaw_modifier, true, 0)

					speed = math.min(speed_before, math.max(speed/yaw_modifier, speed_before/4, min_speed))

					if d.getDebug(5) then
						table.insert(next_paths_debug, {
							origin_x = i ~= 0 and vehicle_object.path[i].x or vehicle_object.transform[13],
							origin_z = i ~= 0 and vehicle_object.path[i].z or vehicle_object.transform[15],
							target_x = vehicle_object.path[i+1].x,
							target_z = vehicle_object.path[i+1].z,
							speed_mult = (math.min(speed_before, math.max(speed/yaw_modifier, speed_before/4, min_speed))-min_speed)/(speed_before-min_speed)
						})
					end

					if total_dist > max_dist or speed/yaw_modifier < speed_before/4 or speed/yaw_modifier < min_speed then
						--d.print("breaking control path loop!", true, 0)
						break
					end

					previous_yaw = path_yaw
				end

				--d.print("speed_result: "..speed, true, 0)

				if m.distance(vehicle_object.driving.old_pos, vehicle_object.transform) < 0.01/(reaction_time/3) and vehicle_object.driving.reverse_timer == 0 then
					vehicle_object.driving.reverse_timer = reverse_timer_max
					--d.print("reversing! distance: "..tostring(m.distance(vehicle_object.driving.old_pos, vehicle_object.transform)), true, 0)
				end

				vehicle_object.driving.reverse_timer = math.max(vehicle_object.driving.reverse_timer - 1, 0)

				-- check if we want to reverse turn
				if math.abs(ad) > math.pi*1.45 then
					ad = -ad * 2
					speed = -speed
				end

				-- we keep this seperate, in case its stuck on a wall behind while reverse turning
				if vehicle_object.driving.reverse_timer >= reverse_timer_max/2 then
					ad = -ad * 2
					speed = -speed
				end

				if speed < 0 then
					speed = speed*0.85
				end

				if v.getTerrainType(vehicle_object.transform) ~= "road" then
					ad = ad * 2 -- double steering sensitivity if we're on a bridge or offroad (attempts to bring us on the road if offroad, and trys to make sure we dont fall off the bridge)
				end

				--d.print("speed: "..speed, true, 0)

				-- set old pos
				vehicle_object.driving.old_pos = vehicle_object.transform

				-- set steering
				--d.print("prev a/d: "..ad, true, 0)
				local ad = math.wrap(-(ad)/3, -math.pi, math.pi)
				--d.print("a/d: "..ad, true, 0)

				local ws = (speed/vehicle_object.speed.speed)/math.clamp(math.abs(ad)+0.6, 1, 2)

				AI.setSeat(main_vehicle_id, "Driver", ws, ad, 0, 0, true, false, false, false, false, false, false)
				--d.print("I do thing :D")

				if d.getDebug(5) then
					-- calculate info for debug
					local length = 10
					local y_axis_x = vehicle_object.transform[13] + length * math.sin(y_axis)
					local y_axis_z = vehicle_object.transform[15] + length * math.cos(y_axis)
					local target_angle_x = vehicle_object.transform[13] + length * math.sin(target_angle)
					local target_angle_z = vehicle_object.transform[15] + length * math.cos(target_angle)
					
					local player_list = s.getPlayers()
					s.removeMapLine(-1, vehicle_object.driving.ui_id)

					-- remove a bunch of labels, cause it only removes 1 at a time, we just do 10 to be safe, as the function has very little performance impact anyways (2-3ms for 10,000 runs)
					for _ = 1, 10 do
						s.removeMapLabel(-1, vehicle_object.driving.ui_id)
					end

					for _, peer in pairs(player_list) do
						if d.getDebug(5, peer.id) then

							if #next_paths_debug > 0 then
								for i=1, #next_paths_debug do
									-- line that shows the next paths, colour depending on how much the vehicle is slowing down for it, red = very slow, green = none
									s.addMapLine(peer.id, vehicle_object.driving.ui_id, m.translation(next_paths_debug[i].origin_x, 0, next_paths_debug[i].origin_z), m.translation(next_paths_debug[i].target_x, 0, next_paths_debug[i].target_z), 1, math.floor(math.clamp(255*(1-next_paths_debug[i].speed_mult), 0, 255)), math.floor(math.clamp(255*next_paths_debug[i].speed_mult, 0, 255)), 0, 200)
									
									local line_distance = math.euclideanDistance(next_paths_debug[i].origin_x, next_paths_debug[i].target_x, next_paths_debug[i].origin_z, next_paths_debug[i].target_z)

									local to_next_yaw, _ = math.angleToFace(next_paths_debug[i].origin_x, next_paths_debug[i].target_x, next_paths_debug[i].origin_z, next_paths_debug[i].target_z)

									to_next_yaw = to_next_yaw - math.half_pi
									local label_x = next_paths_debug[i].origin_x + (line_distance * 0.65) * math.cos(to_next_yaw)
									local label_z = next_paths_debug[i].origin_z + (line_distance * 0.65) * math.sin(to_next_yaw)
									
									s.addMapLabel(peer.id, vehicle_object.driving.ui_id, 4, "Speed Multiplier: "..next_paths_debug[i].speed_mult, label_x, label_z)
									--d.print("speed_mult: "..next_paths_debug[i].speed_mult, true, 0)
								end
							end
							-- blue line where its driving to
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_pos.x, 0, target_pos.z), 2, 0, 0, 255, 200)

							-- cyan line where its pointing
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(y_axis_x, 0, y_axis_z), 0.5, 0, 255, 255, 200)

							-- yellow line at target angle (where its wanting to go)
							server.addMapLine(peer.id, vehicle_object.driving.ui_id, vehicle_object.transform, m.translation(target_angle_x, 0, target_angle_z), 0.5, 255, 255, 0, 200)
						
							-- Label at where the vehicle is, displaying the current throttle
							server.addMapLabel(peer.id, vehicle_object.driving.ui_id, 4, "Throttle: "..ws.."\nSteering: "..ad, vehicle_object.transform[13], vehicle_object.transform[15])
						end
					end
				end
				--d.print("TickID (60): "..((g_savedata.tick_counter + vehicle_id) % 60), true, 0)
			end

			--d.print("Time Taken: "..millisecondsSince(control_started).." | vehicle_id: "..vehicle_id, true, 0)

			::break_control_vehicle::
		end
	end
	d.stopProfiler("tickControls()", true, "onTick()")
end

--[[

	Sanity Ticker

	Will periodically check data for any invalid data (eg: fully_created true for a prefab, when voxels or mass is nil.)

]]

function tickSanity(game_ticks)

	-- Only tick every 5 seconds
	if not isTickID(0, time.second * 5) then
		return
	end

	-- Check all prefabs
	for prefab_id, prefab_data in pairs(g_savedata.prefabs) do

		-- Check if the prefab is fully created
		if prefab_data.fully_created then

			-- Check if the prefab has nil mass
			if not prefab_data.mass then
				d.print("Prefab "..prefab_id.." has nil mass! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has 0 mass
			if prefab_data.mass == 0 then
				d.print("Prefab "..prefab_id.." has 0 mass! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has nil voxels
			if not prefab_data.voxels then
				d.print("Prefab "..prefab_id.." has nil voxels! But prefab_data.fully_created is true!", true, 1)
			end

			-- Check if the prefab has 0 voxels
			if prefab_data.voxels == 0 then
				d.print("Prefab "..prefab_id.." has 0 voxels! But prefab_data.fully_created is true!", true, 1)
			end
		end
	end

end

function onTick(game_ticks)

	game_ticks = game_ticks or 1

	if g_savedata.debug.traceback.enabled then
		ac.sendCommunication("DEBUG.TRACEBACK.ERROR_CHECKER", 0)
	end

	eq.tick()

	if not is_dlc_weapons or not g_savedata.info.setup then
		return
	end

	if g_savedata.settings.PAUSE_WHEN_NONE_ONLINE then
		if #s.getPlayers() <= 0 then
			-- addon paused as nobody is online
			return
		end
	end

	-- if the flag to sync the tick rate with game_ticks is enabled.
	if g_savedata.flags.sync_tick_rate and game_ticks > 1 then
		for _ = 1, game_ticks do
			onTick(1)
		end

		return
	end

	-- if the flag to sync the game speed is enabled, then apply the current tick rate, otherwise, set game ticks to 1.
	game_ticks = g_savedata.flags.sync_game_speed and game_ticks or 1

	g_savedata.tick_counter = g_savedata.tick_counter + 1

	g_savedata.game_tick_counter = g_savedata.game_tick_counter + game_ticks

	d.startProfiler("onTick()", true)

	-- Cleans invalid vehicles, if any vehicles have invalid positions (0, 0, 0) (non existant), they get killed and deleted.
	tickVehicleCleaner()

	tickUpdateVehicleData(game_ticks)
	tickVision(game_ticks)
	tickGamemode(game_ticks)
	tickAI(game_ticks)
	tickSquadrons(game_ticks)
	tickVehicles(game_ticks)
	tickControls(game_ticks) -- ticks custom ai driving
	tickCargoVehicles(game_ticks)
	tickCargo(game_ticks)
	tickIslands(game_ticks)
	tickModifiers(game_ticks)
	CapturePointPayments.tick(game_ticks)
	--VehicleFires.tick(game_ticks)
	-- tickOther()

	-- Check if sanity ticker is enabled
	if g_savedata.flags.sanity_checker then
		-- tick sanity check.
		tickSanity(game_ticks)
	end


	d.stopProfiler("onTick()", true, "onTick()")
	d.showProfilers()
end

function refuel(vehicle_id)
	-- jet fuel
	local i = 1
	repeat
		local tank_data, success = s.getVehicleTank(vehicle_id, "Jet "..i) -- checks if the next jet fuel container exists
		if success then
			s.setVehicleTank(vehicle_id, "Jet "..i, tank_data.capacity, 2) -- refuel the jet fuel container
		end
		i = i + 1
	until (not success)
	-- diesel
	local i = 1
	repeat
		local tank_data, success = s.getVehicleTank(vehicle_id, "Diesel "..i) -- checks if the next diesel container exists
		if success then
			s.setVehicleTank(vehicle_id, "Diesel "..i, tank_data.capacity, 1) -- refuel the diesel container
		end
		i = i + 1
	until (not success)
	-- batteries
	local i = 1
	repeat
		local batt_data, success = s.getVehicleBattery(vehicle_id, "Battery "..i) -- check if the next battery exists
		if success then
			s.setVehicleBattery(vehicle_id, "Battery "..i, 1) -- charge the battery
		end
		i = i + 1
	until (not success)
end

-- Reloads all ammo containers on a vehicle, by just refilling them. Set the vehicle_id to the id of vehicle you want to reload.
---@param vehicle_id integer the vehicle you want to reload
function reload(vehicle_id)
	--Reload the main ammo containers
	local i = 1
	repeat
		local ammo, success = server.getVehicleWeapon(vehicle_id, "Ammo "..i) -- get the number of ammo containers to reload
		if success then
			server.setVehicleWeapon(vehicle_id, "Ammo "..i, ammo.capacity) -- reload the ammo container
		end
		i = i + 1
	until (not success)

	--Reload any reserve ammo
	local vehicle_component_data, components_is_success = server.getVehicleComponents(vehicle_id)
	local target_pattern = ("^Reserve Ammo %d+$") --Must start with "Reserve Ammo ", then any amount of digits and must end with those digits
	if components_is_success and vehicle_component_data.components and vehicle_component_data.components.guns then
		--If the gun data exists
		for reserve_ammo_index = 1, #vehicle_component_data.components.guns do
			--Loops through all the guns on the vehicle
			local reserve_ammo_data = vehicle_component_data.components.guns[reserve_ammo_index]
			if reserve_ammo_data.ammo == 0 and reserve_ammo_data.name:match(target_pattern) then
				--This is a reserve ammo and its out of ammo. Reload it to capacity
				server.setVehicleWeapon(vehicle_id, reserve_ammo_data.pos.x, reserve_ammo_data.pos.y, reserve_ammo_data.pos.z, reserve_ammo_data.capacity)
			end
		end
	end
end

--------------------------------------------------------------------------------
--
-- VEHICLE HELPERS
--
--------------------------------------------------------------------------------

function isVehicleNeedsResupply(vehicle_id, button_name)
	local button_data, success = s.getVehicleButton(vehicle_id, button_name)
	return success and button_data.on
end

function isVehicleNeedsReload(vehicle_id)

	local guns_to_reload = {}

	local vehicle_component_data, is_success = server.getVehicleComponents(vehicle_id)
	if is_success then
		if vehicle_component_data.components and vehicle_component_data.components.buttons then
			for i = 1, #vehicle_component_data.components.buttons do
				local button = vehicle_component_data.components.buttons[i]
				if button.on and button.name:match("AI_RELOAD_AMMO_") then
					table.insert(guns_to_reload, tonumber(button.name:gsub("AI_RELOAD_AMMO_", "")))
				end
			end
		end
	else
		d.print(("(isVehicleNeedsReload) Failed to get vehicle_data! vehicle_id: %s"):format(vehicle_id))
	end

	return guns_to_reload
end

--------------------------------------------------------------------------------
--
-- SQUAD HELPERS
--
--------------------------------------------------------------------------------

function resetSquadTarget(squad)
	squad.target_island = nil
end

function setSquadCommandPatrol(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.PATROL)
end

function setSquadCommandStage(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.STAGE)
end

function setSquadCommandAttack(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.ATTACK)
end

function setSquadCommandDefend(squad, target_island)
	squad.target_island = target_island
	setSquadCommand(squad, SQUAD.COMMAND.DEFEND)
end

function setSquadCommandEngage(squad)
	setSquadCommand(squad, SQUAD.COMMAND.ENGAGE)
end

function setSquadCommandInvestigate(squad, investigate_transform)
	squad.investigate_transform = investigate_transform
	setSquadCommand(squad, SQUAD.COMMAND.INVESTIGATE)
end

function setSquadCommandScout(squad)
	setSquadCommand(squad, SQUAD.COMMAND.SCOUT)
end

function setSquadCommand(squad, command)
	if squad.command ~= command then
		if squad.command ~= SQUAD.COMMAND.SCOUT or squad.command == SQUAD.COMMAND.SCOUT and command == SQUAD.COMMAND.DEFEND then
			if squad.command ~= SQUAD.COMMAND.CARGO then -- never change cargo vehicles being cargo vehicles
				squad.command = command
			
				for vehicle_id, vehicle_object in pairs(squad.vehicles) do
					squadInitVehicleCommand(squad, vehicle_object)
				end

				if squad.command == SQUAD.COMMAND.NONE then
					resetSquadTarget(squad)
				elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
					squad.target_players = {}
					squad.target_vehicles = {}
				end

				return true
			end
		end
	end

	return false
end

function squadInitVehicleCommand(squad, vehicle_object)
	vehicle_object.target_vehicle_id = nil
	vehicle_object.target_player_id = nil

	local cruise_altitude = CRUISE_HEIGHT + (vehicle_object.group_id % 10 * 20)

	if squad.command == SQUAD.COMMAND.PATROL then
		p.resetPath(vehicle_object)

		local patrol_route = {
			{ x=0, z=1000 },
			{ x=1000, z=0 },
			{ x=-0, z=-1000 },
			{ x=-1000, z=0 },
			{ x=0, z=1000}
		}
		local patrol_route_size = math.random(100, 600)/100
		for route_index, route in pairs(patrol_route) do
			patrol_route[route_index].x = patrol_route[route_index].x * patrol_route_size
			patrol_route[route_index].z = patrol_route[route_index].z * patrol_route_size
		end

		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[1].x, cruise_altitude, patrol_route[1].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[2].x, cruise_altitude, patrol_route[2].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[3].x, cruise_altitude, patrol_route[3].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[4].x, cruise_altitude, patrol_route[4].z)))
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(patrol_route[5].x, cruise_altitude, patrol_route[5].z)))
	elseif squad.command == SQUAD.COMMAND.ATTACK then
		-- go to island, once island is captured the command will be cleared
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-100, 100), cruise_altitude, math.random(-100, 100))))
	elseif squad.command == SQUAD.COMMAND.STAGE then
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.DEFEND then
		-- defend island
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.target_island.transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.INVESTIGATE then
		-- go to investigate location
		p.resetPath(vehicle_object)
		p.addPath(vehicle_object, m.multiply(squad.investigate_transform, m.translation(math.random(-500, 500), cruise_altitude, math.random(-500, 500))))
	elseif squad.command == SQUAD.COMMAND.ENGAGE then
		p.resetPath(vehicle_object)
	elseif squad.command == SQUAD.COMMAND.SCOUT then
		p.resetPath(vehicle_object)
		target_island, origin_island = Objective.getIslandToAttack()
		if target_island then
			d.print("Scout found a target island!", true, 0)
			local holding_route = g_holding_pattern
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[1].x, CRUISE_HEIGHT * 2, holding_route[1].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[2].x, CRUISE_HEIGHT * 2, holding_route[2].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[3].x, CRUISE_HEIGHT * 2, holding_route[3].z)))
			p.addPath(vehicle_object, m.multiply(target_island.transform, m.translation(holding_route[4].x, CRUISE_HEIGHT * 2, holding_route[4].z)))
		else
			d.print("Scout was unable to find a island to target!", true, 1)
		end
	elseif squad.command == SQUAD.COMMAND.RETREAT then
	elseif squad.command == SQUAD.COMMAND.NONE then
	elseif squad.command == SQUAD.COMMAND.TURRET then
		p.resetPath(vehicle_object)
	elseif squad.command == SQUAD.COMMAND.RESUPPLY then
		p.resetPath(vehicle_object)
	end
end

function squadGetVisionData(squad)
	local vision_data = {
		visible_players_map = {},
		visible_players = {},
		visible_vehicles_map = {},
		visible_vehicles = {},
		investigate_players = {},
		investigate_vehicles = {},

		isPlayerVisible = function(self, id)
			return self.visible_players_map[id] ~= nil
		end,

		isVehicleVisible = function(self, id)
			return self.visible_vehicles_map[id] ~= nil
		end,

		getBestTargetPlayerID = function(self)
			return self.visible_players[math.random(1, #self.visible_players)].id
		end,

		getBestTargetVehicleID = function(self)
			return self.visible_vehicles[math.random(1, #self.visible_vehicles)].id
		end,

		getBestInvestigatePlayer = function(self)
			return self.investigate_players[math.random(1, #self.investigate_players)]
		end,

		getBestInvestigateVehicle = function(self)
			return self.investigate_vehicles[math.random(1, #self.investigate_vehicles)]
		end,

		is_engage = function(self)
			return #self.visible_players > 0 or #self.visible_vehicles > 0
		end,

		is_investigate = function(self)
			return #self.investigate_players > 0 or #self.investigate_vehicles > 0
		end,
	}

	for steam_id, player_object in pairs(squad.target_players) do
		local player_data = { id = steam_id, obj = player_object }

		if player_object.state == TARGET_VISIBILITY_VISIBLE then
			vision_data.visible_players_map[steam_id] = player_data
			table.insert(vision_data.visible_players, player_data)
		elseif player_object.state == TARGET_VISIBILITY_INVESTIGATE then
			table.insert(vision_data.investigate_players, player_data)
		end
	end

	for vehicle_id, vehicle_object in pairs(squad.target_vehicles) do
		local vehicle_data = { id = vehicle_id, obj = vehicle_object }

		if vehicle_object.state == TARGET_VISIBILITY_VISIBLE then
			vision_data.visible_vehicles_map[vehicle_id] = vehicle_data
			table.insert(vision_data.visible_vehicles, vehicle_data)
		elseif vehicle_object.state == TARGET_VISIBILITY_INVESTIGATE then
			table.insert(vision_data.investigate_vehicles, vehicle_data)
		end
	end

	return vision_data
end


--------------------------------------------------------------------------------
--
-- UTILITIES
--
--------------------------------------------------------------------------------

---@param id integer the tick you want to check that it is
---@param rate integer the total amount of ticks, for example, a rate of 60 means it returns true once every second* (if the tps is not low)
---@return boolean isTick if its the current tick that you requested
function isTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate == 0
end

---@param id integer the tick offset you want to get the id of
---@param rate integer the rate of the tick_id, for example, 60 will result in it going from 1 to 60
---@return integer tick_id The tick ID
function getTickID(id, rate)
	return (g_savedata.tick_counter + id) % rate
end

--------------------------------------------------------------------------------
--
-- Other
--
--------------------------------------------------------------------------------

---@param start_tick number the time you want to see how long its been since (in ticks)
---@return number ticks_since how many ticks its been since <start_tick>
function ticksSince(start_tick)
	return g_savedata.tick_counter - start_tick
end

---@param start_ms number the time you want to see how long its been since (in ms)
---@return number ms_since how many ms its been since <start_ms>
function millisecondsSince(start_ms)
	return s.getTimeMillisec() - start_ms
end

--[[


Flag Registers


]]

--[[
Boolean Flags
]]

-- sync_game_speed flag, if enabled, 
Flag.registerBooleanFlag(
	"sync_game_speed",
	true,
	{
		"balance",
		"low performance impact"
	},
	"normal",
	"admin",
	nil,
	"Makes it so while sleeping, the AI will move, produce, etc, 400x faster to be inline with how fast time is moving while the player sleeps."
)

-- sync_tick_rate flag, if enabled, executes onTick for the number of times game_tick was specified.
Flag.registerBooleanFlag(
	"sync_tick_rate",
	false,
	{
		"debug",
		"balance",
		"experimental",
		"heavy performance impact"
	},
	"admin",
	"admin",
	nil,
	"Sets if the tick rate of the addon will be synced with the in game ticks, meaning that while sleeping, the addon will execute 400 ticks per tick call, to makeup for the game's speed being x400, Causes massive performance impacts while sleeping, which makes sleeping very slow. Not recommended to use."
)

-- show_capture_timer, if enabled, shows the capture timer on the tooltips for capture vehicles, for debug purposes.
Flag.registerBooleanFlag(
	"show_capture_timer_debug",
	false,
	{
		"debug",
		"internal",
		"capture points"
	},
	"admin",
	"admin",
	nil,
	"If enabled, shows the capture timer on the tooltips for capture vehicles, for debug purposes."
)

--[[
	sanity_checker, 
	when enabled, will periodically check for potential issues with the stored data, eg: prefab marked as fully_created, 
	but does not have voxels or mass filled out.
]]
Flag.registerBooleanFlag(
	"sanity_checker",
	true,
	{
		"debug",
		"internal",
		"medium performance impact"
	},
	"admin",
	"admin",
	nil,
	"When enabled, will periodically check for potential issues with the stored data, eg: prefab marked as fully_created, but does not have voxels or mass filled out."
)

--[[
Integer Flags
]]

-- profiler_tick_smoothing flag, specifies how many ticks to average an track the results for in the profiler.
Flag.registerIntegerFlag(
	"profiler_tick_smoothing",
	60,
	{
		"debug",
		"profiler",
		"low performance impact"
	},
	"admin",
	"admin",
	nil,
	"Controls how many ticks to track for the maximum and average result in the profiler.",
	1,
	nil
)