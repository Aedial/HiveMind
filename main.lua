-- Beesness: ComputerCraft Bee Breeding Automation
-- Requires: Advanced Mutatron, Mechanical User, Assassin Queen in Beebee gun

local component = require("component")
local computer = require("computer")
local term = require("term")
local sides = require("sides")
local gpu = component.gpu
local redstone = component.redstone

-- Check for required components
if not component.isAvailable("inventory_controller") then
    error("Inventory Controller upgrade required!")
end

local inv_controller = component.inventory_controller

-- Try to find Gendustry APIs through adapter blocks
local gendustry = {}
local adapters = {}

-- Scan for Gendustry components via adapters
local function scanGendustryComponents()
    print("Scanning for Gendustry components...")
    
    -- Check for direct component names (if Gendustry provides them)
    local possible_names = {
        "gendustry_mutatron", "mutatron", "advanced_mutatron",
        "gendustry_imprinter", "imprinter", "genetic_imprinter",
        "gendustry_sampler", "sampler", "genetic_sampler",
        "gendustry_transposer", "transposer", "genetic_transposer"
    }
    
    for _, name in ipairs(possible_names) do
        if component.isAvailable(name) then
            gendustry[name] = component.getPrimary(name)
            print("Found Gendustry component: " .. name)
        end
    end
    
    -- Scan all available components for potential Gendustry machines
    for address, componentType in component.list() do
        if componentType:find("gendustry") or componentType:find("mutatron") or componentType:find("imprinter") then
            print("Found potential Gendustry component: " .. componentType .. " at " .. address:sub(1,8))
            gendustry[componentType] = component.proxy(address)
        end
    end
    
    return next(gendustry) ~= nil
end

-- Get component methods for debugging
local function getComponentMethods(comp)
    local methods = {}
    if comp then
        for k, v in pairs(comp) do
            if type(v) == "function" then
                table.insert(methods, k)
            end
        end
    end
    return methods
end

-- Comprehensive bee mutation database
local function loadBeeDatabase()
    local mutations = {}
    
    -- Forestry Base Bees
    mutations["Modest"] = {parents = {"Forest", "Meadows"}, mod = "Forestry"}
    mutations["Tropical"] = {parents = {"Forest", "Meadows"}, mod = "Forestry"}
    mutations["Wintry"] = {parents = {"Forest", "Modest"}, mod = "Forestry"}
    mutations["Marshy"] = {parents = {"Forest", "Meadows"}, mod = "Forestry"}
    mutations["Common"] = {parents = {"Forest", "Meadows"}, mod = "Forestry"}
    mutations["Cultivated"] = {parents = {"Common", "Modest"}, mod = "Forestry"}
    mutations["Noble"] = {parents = {"Common", "Cultivated"}, mod = "Forestry"}
    mutations["Majestic"] = {parents = {"Noble", "Cultivated"}, mod = "Forestry"}
    mutations["Imperial"] = {parents = {"Noble", "Majestic"}, mod = "Forestry"}
    mutations["Diligent"] = {parents = {"Common", "Cultivated"}, mod = "Forestry"}
    mutations["Unweary"] = {parents = {"Diligent", "Cultivated"}, mod = "Forestry"}
    mutations["Industrious"] = {parents = {"Diligent", "Unweary"}, mod = "Forestry"}
    mutations["Steadfast"] = {parents = {"Cultivated", "Unweary"}, mod = "Forestry"}
    mutations["Valiant"] = {parents = {"Cultivated", "Steadfast"}, mod = "Forestry"}
    mutations["Heroic"] = {parents = {"Steadfast", "Valiant"}, mod = "Forestry"}
    mutations["Sinister"] = {parents = {"Cultivated", "Modest"}, mod = "Forestry"}
    mutations["Fiendish"] = {parents = {"Sinister", "Cultivated"}, mod = "Forestry"}
    mutations["Demonic"] = {parents = {"Sinister", "Fiendish"}, mod = "Forestry"}
    mutations["Frugal"] = {parents = {"Modest", "Sinister"}, mod = "Forestry"}
    mutations["Austere"] = {parents = {"Modest", "Frugal"}, mod = "Forestry"}
    mutations["Exotic"] = {parents = {"Austere", "Tropical"}, mod = "Forestry"}
    mutations["Edenic"] = {parents = {"Exotic", "Tropical"}, mod = "Forestry"}
    mutations["Ended"] = {parents = {"Imperial", "Heroic"}, mod = "Forestry"}
    mutations["Spectral"] = {parents = {"Hermitic", "Ended"}, mod = "Forestry"}
    mutations["Phantasmal"] = {parents = {"Spectral", "Ended"}, mod = "Forestry"}
    mutations["Icy"] = {parents = {"Industrious", "Wintry"}, mod = "Forestry"}
    mutations["Glacial"] = {parents = {"Icy", "Wintry"}, mod = "Forestry"}
    mutations["Vindictive"] = {parents = {"Demonic", "Monastic"}, mod = "Forestry"}
    mutations["Vengeful"] = {parents = {"Vindictive", "Demonic"}, mod = "Forestry"}
    mutations["Avenging"] = {parents = {"Vengeful", "Vindictive"}, mod = "Forestry"}
    mutations["Leporine"] = {parents = {"Meadows", "Forest"}, mod = "Forestry"}
    mutations["Merry"] = {parents = {"Leporine", "Common"}, mod = "Forestry"}
    mutations["Tipsy"] = {parents = {"Merry", "Valiant"}, mod = "Forestry"}
    
    -- MagicBees (100+ species)
    mutations["Mystical"] = {parents = {"Noble", "Mysterious"}, mod = "MagicBees"}
    mutations["Sorcerous"] = {parents = {"Mystical", "Cultivated"}, mod = "MagicBees"}
    mutations["Unusual"] = {parents = {"Mystical", "Noble"}, mod = "MagicBees"}
    mutations["Attuned"] = {parents = {"Unusual", "Mystical"}, mod = "MagicBees"}
    mutations["Eldritch"] = {parents = {"Unusual", "Mystical"}, mod = "MagicBees"}
    mutations["Esoteric"] = {parents = {"Mystical", "Unusual"}, mod = "MagicBees"}
    mutations["Mysterious"] = {parents = {"Forest", "Common"}, mod = "MagicBees"}
    mutations["Arcane"] = {parents = {"Esoteric", "Unusual"}, mod = "MagicBees"}
    mutations["Charmed"] = {parents = {"Cultivated", "Mystical"}, mod = "MagicBees"}
    mutations["Enchanted"] = {parents = {"Common", "Mystical"}, mod = "MagicBees"}
    mutations["Supernatural"] = {parents = {"Mystical", "Charmed"}, mod = "MagicBees"}
    mutations["Ethereal"] = {parents = {"Supernatural", "Mystical"}, mod = "MagicBees"}
    mutations["Watery"] = {parents = {"Mystical", "Marshy"}, mod = "MagicBees"}
    mutations["Earthy"] = {parents = {"Mystical", "Common"}, mod = "MagicBees"}
    mutations["Firey"] = {parents = {"Mystical", "Tropical"}, mod = "MagicBees"}
    mutations["Windy"] = {parents = {"Mystical", "Wintry"}, mod = "MagicBees"}
    mutations["Pupil"] = {parents = {"Mystical", "Diligent"}, mod = "MagicBees"}
    mutations["Scholarly"] = {parents = {"Pupil", "Cultivated"}, mod = "MagicBees"}
    mutations["Savant"] = {parents = {"Scholarly", "Mystical"}, mod = "MagicBees"}
    mutations["Aware"] = {parents = {"Mystical", "Eldritch"}, mod = "MagicBees"}
    mutations["Spirit"] = {parents = {"Supernatural", "Ethereal"}, mod = "MagicBees"}
    mutations["Soul"] = {parents = {"Spirit", "Aware"}, mod = "MagicBees"}
    mutations["Ghastly"] = {parents = {"Soul", "Spiteful"}, mod = "MagicBees"}
    mutations["Spiteful"] = {parents = {"Ghastly", "Vengeful"}, mod = "MagicBees"}
    mutations["Hateful"] = {parents = {"Spiteful", "Vindictive"}, mod = "MagicBees"}
    mutations["Eldrich"] = {parents = {"Unusual", "Mystical"}, mod = "MagicBees"}
    mutations["Oblivion"] = {parents = {"Hateful", "Eldrich"}, mod = "MagicBees"}
    mutations["Nameless"] = {parents = {"Oblivion", "Eldritch"}, mod = "MagicBees"}
    mutations["Abandoned"] = {parents = {"Nameless", "Oblivion"}, mod = "MagicBees"}
    mutations["Forlorn"] = {parents = {"Abandoned", "Hateful"}, mod = "MagicBees"}
    mutations["Draconic"] = {parents = {"Abandoned", "Forlorn"}, mod = "MagicBees"}
    mutations["Chaos"] = {parents = {"Draconic", "Oblivion"}, mod = "MagicBees"}
    
    -- Binnie's ExtraBees (150+ species)
    mutations["Rocky"] = {parents = {"Common", "Stone"}, mod = "ExtraBees"}
    mutations["Stone"] = {parents = {"Common", "Diligent"}, mod = "ExtraBees"}
    mutations["Granite"] = {parents = {"Rocky", "Diligent"}, mod = "ExtraBees"}
    mutations["Marble"] = {parents = {"Rocky", "Noble"}, mod = "ExtraBees"}
    mutations["Basalt"] = {parents = {"Rocky", "Industrious"}, mod = "ExtraBees"}
    mutations["Slate"] = {parents = {"Stone", "Wintry"}, mod = "ExtraBees"}
    mutations["Clay"] = {parents = {"Stone", "Marshy"}, mod = "ExtraBees"}
    mutations["Sandstone"] = {parents = {"Stone", "Tropical"}, mod = "ExtraBees"}
    mutations["Concrete"] = {parents = {"Stone", "Clay"}, mod = "ExtraBees"}
    mutations["Cobblestone"] = {parents = {"Stone", "Rocky"}, mod = "ExtraBees"}
    mutations["Hardened"] = {parents = {"Granite", "Basalt"}, mod = "ExtraBees"}
    mutations["Smooth"] = {parents = {"Marble", "Sandstone"}, mod = "ExtraBees"}
    mutations["Decomposed"] = {parents = {"Clay", "Slate"}, mod = "ExtraBees"}
    mutations["Tempered"] = {parents = {"Hardened", "Smooth"}, mod = "ExtraBees"}
    mutations["Refined"] = {parents = {"Tempered", "Decomposed"}, mod = "ExtraBees"}
    mutations["Rich"] = {parents = {"Refined", "Heroic"}, mod = "ExtraBees"}
    mutations["Majestic"] = {parents = {"Rich", "Imperial"}, mod = "ExtraBees"}
    mutations["Oily"] = {parents = {"Industrious", "Primeval"}, mod = "ExtraBees"}
    mutations["Primeval"] = {parents = {"Forest", "Noble"}, mod = "ExtraBees"}
    mutations["Distilled"] = {parents = {"Oily", "Industrious"}, mod = "ExtraBees"}
    mutations["Fossilised"] = {parents = {"Primeval", "Steadfast"}, mod = "ExtraBees"}
    mutations["Resinous"] = {parents = {"Primeval", "Diligent"}, mod = "ExtraBees"}
    mutations["Tar"] = {parents = {"Oily", "Fossilised"}, mod = "ExtraBees"}
    mutations["Creosote"] = {parents = {"Oily", "Distilled"}, mod = "ExtraBees"}
    mutations["Latex"] = {parents = {"Resinous", "Primeval"}, mod = "ExtraBees"}
    mutations["Petroleum"] = {parents = {"Oily", "Tar"}, mod = "ExtraBees"}
    mutations["Plastic"] = {parents = {"Petroleum", "Industrious"}, mod = "ExtraBees"}
    mutations["Radioactive"] = {parents = {"Industrious", "Nuclear"}, mod = "ExtraBees"}
    mutations["Nuclear"] = {parents = {"Primeval", "Unstable"}, mod = "ExtraBees"}
    mutations["Unstable"] = {parents = {"Radioactive", "Fossilised"}, mod = "ExtraBees"}
    mutations["Yellorium"] = {parents = {"Nuclear", "Primeval"}, mod = "ExtraBees"}
    mutations["Blutonium"] = {parents = {"Yellorium", "Nuclear"}, mod = "ExtraBees"}
    mutations["Cyanite"] = {parents = {"Yellorium", "Blutonium"}, mod = "ExtraBees"}
    mutations["Ludicrite"] = {parents = {"Blutonium", "Cyanite"}, mod = "ExtraBees"}
    mutations["Quantum"] = {parents = {"Nuclear", "Unstable"}, mod = "ExtraBees"}
    
    -- More ExtraBees branches...
    mutations["Red"] = {parents = {"Forest", "Tropical"}, mod = "ExtraBees"}
    mutations["Yellow"] = {parents = {"Forest", "Modest"}, mod = "ExtraBees"}
    mutations["Blue"] = {parents = {"Forest", "Wintry"}, mod = "ExtraBees"}
    mutations["Green"] = {parents = {"Forest", "Common"}, mod = "ExtraBees"}
    mutations["Black"] = {parents = {"Forest", "Sinister"}, mod = "ExtraBees"}
    mutations["White"] = {parents = {"Forest", "Modest"}, mod = "ExtraBees"}
    mutations["Brown"] = {parents = {"Forest", "Marshy"}, mod = "ExtraBees"}
    mutations["Orange"] = {parents = {"Red", "Yellow"}, mod = "ExtraBees"}
    mutations["Cyan"] = {parents = {"Blue", "Green"}, mod = "ExtraBees"}
    mutations["Purple"] = {parents = {"Red", "Blue"}, mod = "ExtraBees"}
    mutations["Gray"] = {parents = {"Black", "White"}, mod = "ExtraBees"}
    mutations["Pink"] = {parents = {"Red", "White"}, mod = "ExtraBees"}
    mutations["Lime"] = {parents = {"Green", "White"}, mod = "ExtraBees"}
    mutations["Magenta"] = {parents = {"Purple", "Pink"}, mod = "ExtraBees"}
    mutations["LightBlue"] = {parents = {"Blue", "White"}, mod = "ExtraBees"}
    mutations["LightGray"] = {parents = {"Gray", "White"}, mod = "ExtraBees"}
    
    return mutations
end

local mutations = loadBeeDatabase()

-- System configuration
local config = {
    mech_user_side = sides.right,     -- Side where Mechanical User is connected
    pulse_duration = 1,               -- Duration of redstone pulse in seconds
    apiary_wait_time = 30,            -- Time to wait for apiary to process queen (seconds)
    collection_wait_time = 5,         -- Time between collection attempts
    
    -- Machine positions (sides relative to computer/robot)
    mutatron_side = sides.front,      -- Advanced Mutatron location
    apiary_side = sides.back,         -- Industrial Apiary location
    input_chest_side = sides.left,    -- Princess/drone input chest
    output_chest_side = sides.down,   -- Product output chest
    mech_user_inventory_side = sides.right, -- Mechanical User's inventory (same as redstone side)
    
    -- Slot configurations
    mutatron_input_slots = {1, 2},    -- Princess, drone slots in mutatron
    mutatron_output_slot = 3,         -- Queen output slot
    apiary_input_slot = 1,            -- Queen input slot in apiary
    apiary_output_slots = {2, 3, 4, 5, 6},  -- Product output slots
    beebee_gun_slot = 1               -- Slot where beebee gun should be in Mechanical User
}

-- Generate dynamic bee list from mutations database
local function generateBeeList()
    local bees = {"Forest", "Meadows"} -- Starting bees
    
    -- Add all bees from mutations
    for species, data in pairs(mutations) do
        table.insert(bees, species)
    end
    
    -- Sort alphabetically for easier browsing
    table.sort(bees)
    return bees
end

local available_bees = generateBeeList()

-- Filter bees by mod
local function getBeesByMod(mod_name)
    local filtered = {"Forest", "Meadows"} -- Always include starters
    for species, data in pairs(mutations) do
        if data.mod == mod_name then
            table.insert(filtered, species)
        end
    end
    table.sort(filtered)
    return filtered
end

-- Detect available mods
local function detectMods()
    local detected_mods = {"Forestry"} -- Always present
    local mod_counts = {}
    
    for species, data in pairs(mutations) do
        local mod = data.mod
        mod_counts[mod] = (mod_counts[mod] or 0) + 1
    end
    
    for mod, count in pairs(mod_counts) do
        if mod ~= "Forestry" then
            table.insert(detected_mods, mod)
        end
    end
    
    return detected_mods, mod_counts
end

-- Current inventory
local inventory = {
    princesses = {},
    drones = {}
}

-- Clear screen and set up display
function setupDisplay()
    term.clear()
    gpu.setResolution(80, 25)
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    print("=== BEESNESS: Bee Breeding Automation ===")
    print()
end

-- Scan inventories for princesses and drones (including input/output chests)
function scanInventory()
    print("Scanning inventories for bees...")
    inventory.princesses = {}
    inventory.drones = {}
    
    local total_inventories = 0
    
    -- Priority scan: Input and output chests first
    local priority_sides = {
        {side = config.input_chest_side, name = "input chest"},
        {side = config.output_chest_side, name = "output chest"}
    }
    
    for _, priority in ipairs(priority_sides) do
        local side = priority.side
        local name = priority.name
        local inv_size = inv_controller.getInventorySize(side)
        
        if inv_size then
            total_inventories = total_inventories + 1
            print("Scanning " .. name .. " (" .. inv_size .. " slots)")
            
            for slot = 1, inv_size do
                local stack = inv_controller.getStackInSlot(side, slot)
                if stack then
                    local item_name = stack.name or stack.label or ""
                    if item_name:lower():find("princess") or item_name:lower():find("queen") then
                        local species = extractSpecies(item_name)
                        if species then
                            table.insert(inventory.princesses, species)
                        end
                    elseif item_name:lower():find("drone") then
                        local species = extractSpecies(item_name)
                        if species then
                            table.insert(inventory.drones, species)
                        end
                    end
                end
            end
        end
    end
    
    -- Check all other adjacent inventories (10+ slots)
    local all_sides = {sides.up, sides.down, sides.north, sides.south, sides.east, sides.west}
    
    for _, side in ipairs(all_sides) do
        -- Skip if this is already scanned as input/output chest
        local skip = false
        for _, priority in ipairs(priority_sides) do
            if side == priority.side then
                skip = true
                break
            end
        end
        
        if not skip then
            local inv_size = inv_controller.getInventorySize(side)
            
            if inv_size and inv_size >= 10 then
                total_inventories = total_inventories + 1
                print("Found inventory on " .. getSideName(side) .. " side with " .. inv_size .. " slots")
                
                -- Scan this inventory
                for slot = 1, inv_size do
                    local stack = inv_controller.getStackInSlot(side, slot)
                    if stack then
                        local item_name = stack.name or stack.label or ""
                        if item_name:lower():find("princess") or item_name:lower():find("queen") then
                            local species = extractSpecies(item_name)
                            if species then
                                table.insert(inventory.princesses, species)
                            end
                        elseif item_name:lower():find("drone") then
                            local species = extractSpecies(item_name)
                            if species then
                                table.insert(inventory.drones, species)
                            end
                        end
                    end
                end
            end
        end
    end
    
    if total_inventories == 0 then
        print("No inventories found!")
        print("Make sure input/output chests and storage are properly connected.")
    else
        print("Scanned " .. total_inventories .. " inventories")
        print("Found " .. #inventory.princesses .. " princesses/queens, " .. #inventory.drones .. " drones")
    end
end

-- Helper function to get side name for display
function getSideName(side)
    local side_names = {
        [sides.up] = "top",
        [sides.down] = "bottom", 
        [sides.north] = "north",
        [sides.south] = "south",
        [sides.east] = "east",
        [sides.west] = "west"
    }
    return side_names[side] or "unknown"
end

-- Extract species name from item name
function extractSpecies(itemName)
    for _, species in ipairs(available_bees) do
        if itemName:lower():find(species:lower()) then
            return species
        end
    end
    return nil
end

-- Advanced breeding path calculation with golden path + drone accumulation
function calculateBreedingPath(target)
    print("Calculating breeding strategy for " .. target .. "...")
    
    -- Check if we already have the target
    if hasSpecies(target) then
        return {
            golden_path = {},
            drone_paths = {},
            accumulation_cycles = {},
            total_steps = 0
        }
    end
    
    -- Find the golden path (princess lineage)
    local golden_path = findGoldenPath(target)
    if not golden_path or #golden_path == 0 then
        print("ERROR: Cannot find path to " .. target)
        return nil
    end
    
    -- Calculate required drones for each step
    local drone_requirements = calculateDroneRequirements(golden_path)
    
    -- Find paths for missing drones
    local drone_paths = findDronePaths(drone_requirements)
    
    -- Calculate accumulation cycles needed
    local accumulation_cycles = calculateAccumulationCycles(drone_requirements)
    
    local total_steps = #golden_path + countDronePathSteps(drone_paths) + countAccumulationCycles(accumulation_cycles)
    
    return {
        golden_path = golden_path,
        drone_paths = drone_paths,
        accumulation_cycles = accumulation_cycles,
        total_steps = total_steps,
        target = target
    }
end

-- Find the golden path (main princess lineage to target)
function findGoldenPath(target)
    local path = {}
    local current = target
    
    -- Trace backwards from target to find the lineage
    while current and mutations[current] do
        table.insert(path, 1, current) -- Insert at beginning
        
        local parents = mutations[current].parents
        -- Choose the parent that can carry the lineage (usually the first parent)
        current = parents[1]
        
        -- If we have this species as a princess, stop here
        if hasSpeciesPrincess(current) then
            break
        end
    end
    
    return path
end

-- Check if we have a specific species as princess
function hasSpeciesPrincess(species)
    for _, princess in ipairs(inventory.princesses) do
        if princess == species then
            return true
        end
    end
    return false
end

-- Check if we have a specific species as drone
function hasSpeciesDrone(species)
    for _, drone in ipairs(inventory.drones) do
        if drone == species then
            return true
        end
    end
    return false
end

-- Calculate drone requirements for each step in golden path
function calculateDroneRequirements(golden_path)
    local requirements = {}
    
    for i, species in ipairs(golden_path) do
        if mutations[species] then
            local parents = mutations[species].parents
            local drone_needed = parents[2] -- Usually the second parent is the drone
            
            requirements[i] = {
                step = i,
                target_species = species,
                drone_species = drone_needed,
                have_drone = hasSpeciesDrone(drone_needed),
                cycles_needed = 1 -- Minimum cycles needed to accumulate drones
            }
        end
    end
    
    return requirements
end

-- Find breeding paths for missing drones
function findDronePaths(drone_requirements)
    local drone_paths = {}
    
    for i, req in ipairs(drone_requirements) do
        if not req.have_drone then
            local drone_path = findGoldenPath(req.drone_species)
            if drone_path and #drone_path > 0 then
                drone_paths[req.drone_species] = drone_path
            end
        end
    end
    
    return drone_paths
end

-- Calculate accumulation cycles (multiple apiary runs to get enough drones)
function calculateAccumulationCycles(drone_requirements)
    local cycles = {}
    
    for i, req in ipairs(drone_requirements) do
        -- Estimate cycles needed based on drone productivity
        -- Most species produce 1-3 drones per cycle, so plan for extra cycles
        local cycles_needed = req.cycles_needed
        if not req.have_drone then
            cycles_needed = cycles_needed + 2 -- Extra cycles for new species
        end
        
        cycles[req.target_species] = cycles_needed
    end
    
    return cycles
end

-- Count steps needed for all drone paths
function countDronePathSteps(drone_paths)
    local total = 0
    for species, path in pairs(drone_paths) do
        total = total + #path
    end
    return total
end

-- Count total accumulation cycles
function countAccumulationCycles(accumulation_cycles)
    local total = 0
    for species, cycles in pairs(accumulation_cycles) do
        total = total + (cycles - 1) -- Subtract 1 since first cycle is part of main path
    end
    return total
end

-- Check if we have a specific species
function hasSpecies(species)
    for _, p in ipairs(inventory.princesses) do
        if p == species then
            for _, d in ipairs(inventory.drones) do
                if d == species then
                    return true
                end
            end
        end
    end
    return false
end

-- Check if Mechanical User has beebee gun equipped
function checkBeebeeGun()
    local stack = inv_controller.getStackInSlot(config.mech_user_inventory_side, config.beebee_gun_slot)
    if stack and stack.name then
        local name = stack.name:lower()
        if name:find("beebee") or name:find("bee.*gun") then
            return true, stack.name
        end
    end
    return false, nil
end

-- Wait for beebee gun to be available in Mechanical User
function waitForBeebeeGun()
    local hasGun, gunName = checkBeebeeGun()
    
    if hasGun then
        return true
    end
    
    print("Waiting for beebee gun in Mechanical User (slot " .. config.beebee_gun_slot .. ")...")
    
    local check_count = 0
    while not hasGun do
        os.sleep(5) -- Check every 5 seconds
        hasGun, gunName = checkBeebeeGun()
        check_count = check_count + 1
        
        -- Only show status every 30 seconds to avoid spam
        if check_count % 6 == 0 then
            print("Still waiting for beebee gun...")
        end
    end
    
    print("Beebee gun ready: " .. gunName)
    return true
end

-- Activate Mechanical User via redstone pulse (with beebee gun check)
function activateMechanicalUser()
    waitForBeebeeGun()
    
    redstone.setOutput(config.mech_user_side, 15)
    os.sleep(config.pulse_duration)
    redstone.setOutput(config.mech_user_side, 0)
end

-- Move items between inventories
function moveItem(from_side, from_slot, to_side, to_slot, count)
    count = count or 64
    local moved = inv_controller.transferItem(from_side, to_side, count, from_slot, to_slot)
    if moved > 0 then
        print("Moved " .. moved .. " items from slot " .. from_slot .. " to slot " .. to_slot)
        return true
    else
        print("Failed to move items from slot " .. from_slot .. " to slot " .. to_slot)
        return false
    end
end

-- Find item in inventory by name pattern (searches multiple inventories)
function findItem(side, pattern)
    local inv_size = inv_controller.getInventorySize(side)
    if not inv_size then return nil end
    
    for slot = 1, inv_size do
        local stack = inv_controller.getStackInSlot(side, slot)
        if stack and stack.name then
            local name = stack.name:lower()
            if name:find(pattern:lower()) then
                return slot, stack
            end
        end
    end
    return nil
end

-- Find item across all available inventories (input, output, and storage)
function findItemAnyInventory(pattern)
    -- Priority search: output chest first (for produced bees), then input chest
    local search_order = {
        {side = config.output_chest_side, name = "output chest"},
        {side = config.input_chest_side, name = "input chest"}
    }
    
    for _, location in ipairs(search_order) do
        local slot, stack = findItem(location.side, pattern)
        if slot then
            return location.side, slot, stack
        end
    end
    
    -- Search other inventories
    local all_sides = {sides.up, sides.down, sides.north, sides.south, sides.east, sides.west}
    
    for _, side in ipairs(all_sides) do
        -- Skip already searched sides
        local already_searched = false
        for _, location in ipairs(search_order) do
            if side == location.side then
                already_searched = true
                break
            end
        end
        
        if not already_searched then
            local inv_size = inv_controller.getInventorySize(side)
            if inv_size and inv_size >= 10 then
                local slot, stack = findItem(side, pattern)
                if slot then
                    return side, slot, stack
                end
            end
        end
    end
    
    return nil
end

-- Insert princess and drone into mutatron
function loadMutatron(parent1, parent2)
    print("Loading mutatron with " .. parent1 .. " princess and " .. parent2 .. " drone...")
    
    -- Find princess and drone across all inventories
    local princess_side, princess_slot, princess_stack = findItemAnyInventory(parent1 .. ".*(princess|queen)")
    local drone_side, drone_slot, drone_stack = findItemAnyInventory(parent2 .. ".*drone")
    
    if not princess_slot then
        print("ERROR: Could not find " .. parent1 .. " princess/queen in any inventory!")
        return false
    end
    
    if not drone_slot then
        print("ERROR: Could not find " .. parent2 .. " drone in any inventory!")
        return false
    end
    
    print("Found " .. parent1 .. " princess in " .. getSideName(princess_side))
    print("Found " .. parent2 .. " drone in " .. getSideName(drone_side))
    
    -- Move items to mutatron
    local success1 = moveItem(princess_side, princess_slot, config.mutatron_side, config.mutatron_input_slots[1], 1)
    local success2 = moveItem(drone_side, drone_slot, config.mutatron_side, config.mutatron_input_slots[2], 1)
    
    if success1 and success2 then
        print("Successfully loaded mutatron!")
        return true
    else
        print("Failed to load mutatron properly!")
        return false
    end
end

-- Extract queen from mutatron and move to apiary
function moveQueenToApiary()
    print("Moving queen from mutatron to apiary...")
    
    -- Wait a moment for mutatron to finish
    os.sleep(2)
    
    -- Check if queen is ready
    local queen_stack = inv_controller.getStackInSlot(config.mutatron_side, config.mutatron_output_slot)
    if not queen_stack then
        print("Waiting for mutatron to produce queen...")
        for i = 1, 10 do
            os.sleep(1)
            queen_stack = inv_controller.getStackInSlot(config.mutatron_side, config.mutatron_output_slot)
            if queen_stack then break end
        end
        
        if not queen_stack then
            print("ERROR: No queen produced by mutatron!")
            return false
        end
    end
    
    print("Queen ready! Moving to apiary...")
    
    -- Move queen to apiary
    local success = moveItem(config.mutatron_side, config.mutatron_output_slot, config.apiary_side, config.apiary_input_slot, 1)
    
    if success then
        print("Queen successfully placed in apiary!")
        return true
    else
        print("Failed to move queen to apiary!")
        return false
    end
end

-- Collect all products from apiary
function collectApiaryProducts()
    print("Collecting products from apiary...")
    
    local collected_items = {}
    local total_collected = 0
    
    for _, slot in ipairs(config.apiary_output_slots) do
        local stack = inv_controller.getStackInSlot(config.apiary_side, slot)
        if stack and stack.size > 0 then
            -- Try to move to output chest
            local moved = inv_controller.transferItem(config.apiary_side, config.output_chest_side, stack.size, slot)
            if moved > 0 then
                total_collected = total_collected + moved
                local item_name = stack.name or "unknown"
                collected_items[item_name] = (collected_items[item_name] or 0) + moved
                print("  Collected " .. moved .. "x " .. item_name)
            end
        end
    end
    
    if total_collected > 0 then
        print("Total items collected: " .. total_collected)
        
        -- Update inventory tracking for queens and drones
        for item_name, count in pairs(collected_items) do
            if item_name:find("queen") then
                local species = extractSpecies(item_name)
                if species then
                    for i = 1, count do
                        table.insert(inventory.princesses, species)
                    end
                end
            elseif item_name:find("drone") then
                local species = extractSpecies(item_name)
                if species then
                    for i = 1, count do
                        table.insert(inventory.drones, species)
                    end
                end
            end
        end
        
        return true
    else
        print("No items collected from apiary!")
        return false
    end
end

-- Check if Gendustry APIs are available
function checkGendustryAPI()
    local hasGendustry = scanGendustryComponents()
    
    if hasGendustry then
        print("Gendustry components detected:")
        for name, comp in pairs(gendustry) do
            print("  " .. name)
            local methods = getComponentMethods(comp)
            if #methods > 0 then
                print("    Available methods: " .. table.concat(methods, ", "))
            end
        end
        return true
    else
        print("No Gendustry components found")
        print("Make sure Gendustry machines are connected via adapter blocks")
        print("Using manual redstone control for Mechanical User")
        return false
    end
end

-- Try to use Gendustry API for breeding
function useGendustryAPI(parent1, parent2, target)
    for name, comp in pairs(gendustry) do
        if name:find("mutatron") then
            print("Attempting to use " .. name .. " for breeding...")
            
            -- Try common method names that might exist
            local methods = getComponentMethods(comp)
            
            -- Look for likely method names
            for _, method in ipairs(methods) do
                if method:find("breed") or method:find("mutate") or method:find("process") then
                    print("Found potential breeding method: " .. method)
                end
            end
            
            -- Attempt basic operations (these would need to be adjusted based on actual API)
            if comp.getWorkProgress then
                local progress = comp.getWorkProgress()
                print("Mutatron work progress: " .. progress .. "%")
            end
            
            if comp.isWorking then
                local working = comp.isWorking()
                print("Mutatron working: " .. tostring(working))
            end
            
            return true
        end
    end
    
    return false
end

-- Display comprehensive breeding plan
function displayBreedingPlan(target, breeding_plan)
    print()
    print("=== BREEDING STRATEGY FOR " .. target:upper() .. " ===")
    print()
    
    if not breeding_plan then
        print("ERROR: Cannot find breeding strategy for " .. target)
        return false
    end
    
    if breeding_plan.total_steps == 0 then
        print("Target bee already available!")
        return true
    end
    
    print("Total estimated steps: " .. breeding_plan.total_steps)
    print()
    
    -- Display golden path (main princess lineage)
    if #breeding_plan.golden_path > 0 then
        print("=== GOLDEN PATH (Princess Lineage) ===")
        for i, species in ipairs(breeding_plan.golden_path) do
            local parents = mutations[species].parents
            local princess_parent = parents[1]
            local drone_parent = parents[2]
            
            local princess_status = hasSpeciesPrincess(princess_parent) and " ✓" or " ✗"
            local drone_status = hasSpeciesDrone(drone_parent) and " ✓" or " ✗"
            
            print(string.format("%d. %s%s + %s%s -> %s", 
                  i, princess_parent, princess_status, drone_parent, drone_status, species))
        end
        print()
    end
    
    -- Display required drone paths
    if next(breeding_plan.drone_paths) then
        print("=== REQUIRED DRONE PATHS ===")
        for drone_species, path in pairs(breeding_plan.drone_paths) do
            print("Need " .. drone_species .. " drones:")
            for i, species in ipairs(path) do
                local parents = mutations[species].parents
                print(string.format("  %d. %s + %s -> %s", 
                      i, parents[1], parents[2], species))
            end
            print()
        end
    end
    
    -- Display accumulation cycles
    if next(breeding_plan.accumulation_cycles) then
        print("=== ACCUMULATION CYCLES ===")
        print("Additional apiary cycles needed to accumulate drones:")
        for species, cycles in pairs(breeding_plan.accumulation_cycles) do
            if cycles > 1 then
                print(string.format("  %s: %d extra cycles", species, cycles - 1))
            end
        end
        print()
    end
    
    -- Display execution summary
    print("=== EXECUTION SUMMARY ===")
    print("1. Complete all drone paths first")
    print("2. Accumulate required drones through apiary cycles")
    print("3. Execute golden path with accumulated drones")
    print("4. Each step: Princess + Drone -> Queen -> Apiary -> New Queen + Drones")
    
    return true
end

-- Get user confirmation
function getConfirmation()
    print()
    print("Options:")
    print("1. Start breeding process")
    print("2. Refresh inventory")
    print("3. Choose different target")
    print("4. Exit")
    print()
    io.write("Choice (1-4): ")
    
    local choice = io.read()
    return tonumber(choice) or 0
end

-- Enhanced target selection with mod filtering
function selectTarget()
    local mods, mod_counts = detectMods()
    local current_filter = nil
    local filtered_bees = available_bees
    
    while true do
        setupDisplay()
        
        print("=== BEE SELECTION MENU ===")
        print("Database contains " .. #available_bees .. " bee species")
        print()
        
        -- Show mod filter options
        print("Mod Filters:")
        print("0. All Mods (" .. #available_bees .. " bees)")
        for i, mod in ipairs(mods) do
            local count = mod_counts[mod] or 0
            local active = (current_filter == mod) and " [ACTIVE]" or ""
            print(string.format("%d. %s (%d bees)%s", i, mod, count, active))
        end
        print()
        
        if current_filter then
            filtered_bees = getBeesByMod(current_filter)
            print("Showing " .. current_filter .. " bees:")
        else
            filtered_bees = available_bees
            print("Showing all bees:")
        end
        
        -- Show bees with pagination
        local page_size = 15
        local total_pages = math.ceil(#filtered_bees / page_size)
        local current_page = 1
        
        local function showPage(page)
            local start_idx = (page - 1) * page_size + 1
            local end_idx = math.min(page * page_size, #filtered_bees)
            
            for i = start_idx, end_idx do
                local species = filtered_bees[i]
                local status = hasSpecies(species) and " [HAVE]" or ""
                local mod_info = mutations[species] and (" [" .. mutations[species].mod .. "]") or ""
                print(string.format("%2d. %s%s%s", i, species, status, mod_info))
            end
            
            if total_pages > 1 then
                print()
                print("Page " .. page .. " of " .. total_pages)
                print("Commands: n=next page, p=prev page, f=filter, s=search")
            end
        end
        
        showPage(current_page)
        
        print()
        io.write("Choice (number/command): ")
        local input = io.read()
        
        if input == "n" and current_page < total_pages then
            current_page = current_page + 1
        elseif input == "p" and current_page > 1 then
            current_page = current_page - 1
        elseif input == "f" then
            print("Select mod filter (0-" .. #mods .. "): ")
            local filter_choice = tonumber(io.read())
            if filter_choice == 0 then
                current_filter = nil
            elseif filter_choice and filter_choice >= 1 and filter_choice <= #mods then
                current_filter = mods[filter_choice]
            end
            current_page = 1
        elseif input == "s" then
            print("Enter search term: ")
            local search = io.read():lower()
            local search_results = {}
            for _, species in ipairs(available_bees) do
                if species:lower():find(search) then
                    table.insert(search_results, species)
                end
            end
            if #search_results > 0 then
                filtered_bees = search_results
                current_filter = "Search: " .. search
                current_page = 1
            else
                print("No matches found. Press Enter...")
                io.read()
            end
        else
            local choice = tonumber(input)
            if choice == 0 then
                return nil
            elseif choice and choice >= 1 and choice <= #filtered_bees then
                return filtered_bees[choice]
            else
                print("Invalid choice. Press Enter to continue...")
                io.read()
            end
        end
    end
end

-- Execute breeding process
function executeBreeding(target, breeding_plan)
    print()
    print("=== STARTING ADVANCED BREEDING STRATEGY ===")
    print("Target: " .. target)
    print("Setup: Input chest (left) -> Mutatron (front) -> Apiary (back) -> Output chest (down)")
    print()
    
    if not breeding_plan or breeding_plan.total_steps == 0 then
        print("No breeding required - target already available!")
        return true
    end
    
    local hasAPI = checkGendustryAPI()
    local total_steps = 0
    
    -- Phase 1: Execute drone paths first
    if next(breeding_plan.drone_paths) then
        print("=== PHASE 1: BREEDING REQUIRED DRONES ===")
        for drone_species, drone_path in pairs(breeding_plan.drone_paths) do
            print("Breeding " .. drone_species .. " drones...")
            
            for i, species in ipairs(drone_path) do
                total_steps = total_steps + 1
                local parents = mutations[species].parents
                
                print("=== DRONE STEP " .. i .. ": " .. parents[1] .. " + " .. parents[2] .. " -> " .. species .. " ===")
                
                local success = executeSingleBreedingStep(parents[1], parents[2], species, hasAPI)
                if not success then
                    print("FAILED: Could not complete drone breeding step!")
                    return false
                end
            end
            print("Drone path for " .. drone_species .. " complete!")
        end
        print()
    end
    
    -- Phase 2: Accumulation cycles
    if next(breeding_plan.accumulation_cycles) then
        print("=== PHASE 2: ACCUMULATING DRONES ===")
        for species, cycles in pairs(breeding_plan.accumulation_cycles) do
            if cycles > 1 then
                print("Running " .. (cycles - 1) .. " additional cycles for " .. species .. " drones...")
                
                for cycle = 2, cycles do
                    total_steps = total_steps + 1
                    print("=== ACCUMULATION CYCLE " .. (cycle - 1) .. " for " .. species .. " ===")
                    
                    -- Run apiary cycle to get more drones
                    local success = executeAccumulationCycle(species)
                    if not success then
                        print("WARNING: Accumulation cycle failed!")
                    end
                end
            end
        end
        print()
    end
    
    -- Phase 3: Execute golden path
    if #breeding_plan.golden_path > 0 then
        print("=== PHASE 3: GOLDEN PATH EXECUTION ===")
        print("Main princess lineage breeding:")
        
        for i, species in ipairs(breeding_plan.golden_path) do
            total_steps = total_steps + 1
            local parents = mutations[species].parents
            local step_num = i
            
            print("=== GOLDEN STEP " .. step_num .. "/" .. #breeding_plan.golden_path .. ": " .. parents[1] .. " + " .. parents[2] .. " -> " .. species .. " ===")
            
            local success = executeSingleBreedingStep(parents[1], parents[2], species, hasAPI)
            if not success then
                print("FAILED: Could not complete golden path step!")
                return false
            end
            
            print("Golden path step " .. step_num .. " complete!")
            
            if i < #breeding_plan.golden_path then
                print("Preparing for next golden path step...")
                os.sleep(2)
            end
        end
    end
    
    print()
    print("=== BREEDING STRATEGY COMPLETE ===")
    print("Target bee " .. target .. " has been successfully bred!")
    print("Total steps executed: " .. total_steps)
    print("All products stored in output chest.")
    computer.beep(1000, 0.5)
    
    -- Final inventory scan
    print()
    print("Rescanning inventory...")
    scanInventory()
    
    return true
end

-- Execute a single breeding step (mutatron + apiary cycle)
function executeSingleBreedingStep(princess_species, drone_species, target_species, hasAPI)
    -- Phase 1: Load Mutatron
    print("Loading mutatron: " .. princess_species .. " + " .. drone_species .. " -> " .. target_species)
    local load_success = loadMutatron(princess_species, drone_species)
    if not load_success then
        print("FAILED: Could not load bees into mutatron!")
        return false
    end
    
    -- Phase 2: Activate Mutatron
    print("Activating mutatron...")
    if hasAPI then
        local api_success = useGendustryAPI(princess_species, drone_species, target_species)
        if not api_success then
            activateMechanicalUser()
        end
    else
        activateMechanicalUser()
    end
    
    -- Phase 3: Move Queen to Apiary
    print("Moving queen to apiary...")
    local queen_success = moveQueenToApiary()
    if not queen_success then
        print("FAILED: Could not move queen to apiary!")
        return false
    end
    
    -- Phase 4: Process in Apiary
    print("Processing in apiary...")
    activateMechanicalUser()
    
    print("Waiting " .. config.apiary_wait_time .. " seconds for apiary...")
    for t = 1, config.apiary_wait_time do
        if t % 10 == 0 then
            print("  " .. (config.apiary_wait_time - t) .. " seconds remaining...")
        end
        os.sleep(1)
    end
    
    -- Phase 5: Collect Products
    print("Collecting products...")
    local collect_success = collectApiaryProducts()
    if not collect_success then
        print("WARNING: No products collected!")
    end
    
    print("Breeding step complete: " .. target_species)
    computer.beep(800, 0.2)
    return true
end

-- Execute accumulation cycle (apiary-only to get more drones)
function executeAccumulationCycle(species)
    print("Running accumulation cycle for " .. species)
    
    -- Find existing queen of this species across all inventories
    local queen_side, queen_slot, queen_stack = findItemAnyInventory(species .. ".*queen")
    if not queen_slot then
        print("ERROR: No " .. species .. " queen found for accumulation!")
        return false
    end
    
    print("Found " .. species .. " queen in " .. getSideName(queen_side))
    
    -- Move queen to apiary
    local success = moveItem(queen_side, queen_slot, config.apiary_side, config.apiary_input_slot, 1)
    if not success then
        print("Failed to move queen to apiary!")
        return false
    end
    
    -- Activate apiary
    activateMechanicalUser()
    
    -- Wait for processing
    print("Processing queen for " .. config.apiary_wait_time .. " seconds...")
    os.sleep(config.apiary_wait_time)
    
    -- Collect products
    collectApiaryProducts()
    
    print("Accumulation cycle complete!")
    return true
end

-- Main program loop
function main()
    setupDisplay()
    
    while true do
        scanInventory()
        
        local target = selectTarget()
        if not target then
            print("Goodbye!")
            break
        end
        
        local breeding_plan = calculateBreedingPath(target)
        
        while true do
            setupDisplay()
            local success = displayBreedingPlan(target, breeding_plan)
            
            if not success then
                print("Press Enter to continue...")
                io.read()
                break
            end
            
            local choice = getConfirmation()
            
            if choice == 1 then
                executeBreeding(target, breeding_plan)
                print("Press Enter to continue...")
                io.read()
                break
            elseif choice == 2 then
                scanInventory()
                breeding_plan = calculateBreedingPath(target)
            elseif choice == 3 then
                break
            elseif choice == 4 then
                print("Goodbye!")
                return
            else
                print("Invalid choice. Press Enter to continue...")
                io.read()
            end
        end
    end
end

-- Start the program
main()