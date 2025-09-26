-- HiveMind: OpenComputers Bee Breeding Automation
-- Requires: Advanced Mutatron, Mechanical User, Assassin Queen in Beebee gun

--[[
Type Definitions:
@alias BeeSpecies string
@alias SideName number

@class MutationData
@field parent1 string First parent species name
@field parent2 string Second parent species name  
@field mod string Mod name that adds this species

@class GUIState
@field target string Target species name
@field current_species string Current species being processed
@field step_type string Current step type (Loading, Breeding, etc.)
@field current_step number Current step number
@field total_steps number Total number of steps
@field inventory_status string Inventory status text
@field errors string Error message text
@field status string Overall status (Running, Paused, Error, etc.)
@field progress string Progress description text

@class ControlState
@field paused boolean Whether operation is manually paused
@field error_state boolean Whether system is in error state
@field last_error string Last error message
@field abort_requested boolean Whether user requested abort
@field validation_required boolean Whether error requires validation before resume
--]]

local component = require("component")
local computer = require("computer")
local term = require("term")
local sides = require("sides")
local event = require("event")
local gpu = component.gpu
local redstone = component.redstone

-- Optional components for status indicators
local chat_box = component.isAvailable("chat_box") and component.chat_box or nil
local coloredlamp = component.isAvailable("coloredlamp") and component.coloredlamp or nil

-- Check for required components
if not component.isAvailable("inventory_controller") then
    error("Inventory Controller upgrade required!")
end

local inv_controller = component.inventory_controller

-- Try to find Gendustry APIs through adapter blocks
local gendustry = {}
local adapters = {}

--- Scan for Gendustry components via adapters
--- @return boolean hasComponents True if any Gendustry components were found
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

--- Comprehensive bee mutation database
--- @return table<string, {parent1: string, parent2: string, mod: string}> mutations Map of species to their parent combinations
local function loadBeeDatabase()
    local mutations = {}
    
    -- Forestry Base Bees (https://github.com/ForestryMC/ForestryMC/blob/mc-1.12/src/main/java/forestry/apiculture/genetics/BeeBranchDefinition.java)
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
    
    -- MagicBees (https://github.com/ForestryMC/MagicBees/blob/1.12/src/main/java/magicbees/bees/EnumBeeSpecies.java)
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
    
    -- ExtraBees (https://github.com/ForestryMC/Binnie/blob/master-MC1.12/extrabees/src/main/java/binnie/extrabees/genetics/ExtraBeeDefinition.java)
    mutations["Arid"] = {parents = {"Meadows", "Frugal"}, mod = "ExtraBees"}
    mutations["Barren"] = {parents = {"Common", "Arid"}, mod = "ExtraBees"}
    mutations["Desolate"] = {parents = {"Arid", "Barren"}, mod = "ExtraBees"}
    mutations["Decomposing"] = {parents = {"Marshy", "Barren"}, mod = "ExtraBees"}
    mutations["Gnawing"] = {parents = {"Forest", "Barren"}, mod = "ExtraBees"}
    mutations["Rotten"] = {parents = {"Meadows", "Desolate"}, mod = "ExtraBees"}
    mutations["Skeletal"] = {parents = {"Forest", "Desolate"}, mod = "ExtraBees"}
    mutations["Creeper"] = {parents = {"Modest", "Desolate"}, mod = "ExtraBees"}
    mutations["Rock"] = {parents = {"Forest", "Common"}, mod = "ExtraBees"}
    mutations["Stone"] = {parents = {"Diligent", "Rock"}, mod = "ExtraBees"}
    mutations["Granite"] = {parents = {"Unweary", "Stone"}, mod = "ExtraBees"}
    mutations["Mineral"] = {parents = {"Industrious", "Granite"}, mod = "ExtraBees"}
    mutations["Copper"] = {parents = {"Wintry", "Mineral"}, mod = "ExtraBees"}
    mutations["Tin"] = {parents = {"Marshy", "Mineral"}, mod = "ExtraBees"}
    mutations["Iron"] = {parents = {"Meadows", "Mineral"}, mod = "ExtraBees"}
    mutations["Lead"] = {parents = {"Meadows", "Mineral"}, mod = "ExtraBees"}
    mutations["Zinc"] = {parents = {"Wintry", "Mineral"}, mod = "ExtraBees"}
    mutations["Titanium"] = {parents = {"Cultivated", "Mineral"}, mod = "ExtraBees"}
    mutations["Tungstate"] = {parents = {"Common", "Mineral"}, mod = "ExtraBees"}
    mutations["Nickel"] = {parents = {"Forest", "Mineral"}, mod = "ExtraBees"}
    mutations["Gold"] = {parents = {"Majestic", "Iron"}, mod = "ExtraBees"}
    mutations["Silver"] = {parents = {"Majestic", "Zinc"}, mod = "ExtraBees"}
    mutations["Platinum"] = {parents = {"Gold", "Silver"}, mod = "ExtraBees"}
    mutations["Lapis"] = {parents = {"Water", "Mineral"}, mod = "ExtraBees"}
    mutations["Sodalite"] = {parents = {"Lapis", "Diligent"}, mod = "ExtraBees"}
    mutations["Pyrite"] = {parents = {"Iron", "Sinister"}, mod = "ExtraBees"}
    mutations["Bauxite"] = {parents = {"Mineral", "Diligent"}, mod = "ExtraBees"}
    mutations["Cinnabar"] = {parents = {"Mineral", "Sinister"}, mod = "ExtraBees"}
    mutations["Sphalerite"] = {parents = {"Tin", "Sinister"}, mod = "ExtraBees"}
    mutations["Emerald"] = {parents = {"Forest", "Lapis"}, mod = "ExtraBees"}
    mutations["Ruby"] = {parents = {"Modest", "Lapis"}, mod = "ExtraBees"}
    mutations["Sapphire"] = {parents = {"Water", "Lapis"}, mod = "ExtraBees"}
    mutations["Diamond"] = {parents = {"Cultivated", "Lapis"}, mod = "ExtraBees"}
    mutations["Unstable"] = {parents = {"Prehistoric", "Mineral"}, mod = "ExtraBees"}
    mutations["Nuclear"] = {parents = {"Unstable", "Iron"}, mod = "ExtraBees"}
    mutations["Radioactive"] = {parents = {"Nuclear", "Gold"}, mod = "ExtraBees"}
    mutations["Yellorium"] = {parents = {"Frugal", "Nuclear"}, mod = "ExtraBees"}
    mutations["Cyanite"] = {parents = {"Nuclear", "Yellorium"}, mod = "ExtraBees"}
    mutations["Blutonium"] = {parents = {"Cyanite", "Yellorium"}, mod = "ExtraBees"}
    mutations["Ancient"] = {parents = {"Noble", "Diligent"}, mod = "ExtraBees"}
    mutations["Primeval"] = {parents = {"Secluded", "Ancient"}, mod = "ExtraBees"}
    mutations["Prehistoric"] = {parents = {"Primeval", "Ancient"}, mod = "ExtraBees"}
    mutations["Relic"] = {parents = {"Imperial", "Prehistoric"}, mod = "ExtraBees"}
    mutations["Coal"] = {parents = {"Primeval", "Growing"}, mod = "ExtraBees"}
    mutations["Resin"] = {parents = {"Miry", "Primeval"}, mod = "ExtraBees"}
    mutations["Oil"] = {parents = {"Ocean", "Primeval"}, mod = "ExtraBees"}
    mutations["Distilled"] = {parents = {"Industrious", "Oil"}, mod = "ExtraBees"}
    mutations["Fuel"] = {parents = {"Distilled", "Oil"}, mod = "ExtraBees"}
    mutations["Creosote"] = {parents = {"Distilled", "Coal"}, mod = "ExtraBees"}
    mutations["Latex"] = {parents = {"Distilled", "Resin"}, mod = "ExtraBees"}
    mutations["Water"] = {parents = {"Forest", "Common"}, mod = "ExtraBees"}
    mutations["River"] = {parents = {"Diligent", "Water"}, mod = "ExtraBees"}
    mutations["Ocean"] = {parents = {"Diligent", "Water"}, mod = "ExtraBees"}
    mutations["Ink"] = {parents = {"Black", "Ocean"}, mod = "ExtraBees"}
    mutations["Growing"] = {parents = {"Forest", "Diligent"}, mod = "ExtraBees"}
    mutations["Farm"] = {parents = {"Farmerly", "Meadows"}, mod = "ExtraBees"}
    mutations["Thriving"] = {parents = {"Unweary", "Growing"}, mod = "ExtraBees"}
    mutations["Blooming"] = {parents = {"Industrious", "Thriving"}, mod = "ExtraBees"}
    mutations["Sweet"] = {parents = {"Valiant", "Diligent"}, mod = "ExtraBees"}
    mutations["Sugar"] = {parents = {"Rural", "Sweet"}, mod = "ExtraBees"}
    mutations["Ripening"] = {parents = {"Sweet", "Growing"}, mod = "ExtraBees"}
    mutations["Fruit"] = {parents = {"Sweet", "Thriving"}, mod = "ExtraBees"}
    mutations["Alcohol"] = {parents = {"Farmerly", "Meadows"}, mod = "ExtraBees"}
    mutations["Milk"] = {parents = {"Farmerly", "Water"}, mod = "ExtraBees"}
    mutations["Coffee"] = {parents = {"Farmerly", "Tropical"}, mod = "ExtraBees"}
    mutations["Swamp"] = {parents = {"Miry", "Water"}, mod = "ExtraBees"}
    mutations["Boggy"] = {parents = {"Miry", "Swamp"}, mod = "ExtraBees"}
    mutations["Fungal"] = {parents = {"Boggy", "Miry"}, mod = "ExtraBees"}
    mutations["Marble"] = {parents = {"Forest", "Common"}, mod = "ExtraBees"}
    mutations["Roman"] = {parents = {"Marble", "Heroic"}, mod = "ExtraBees"}
    mutations["Greek"] = {parents = {"Roman", "Marble"}, mod = "ExtraBees"}
    mutations["Classical"] = {parents = {"Greek", "Roman"}, mod = "ExtraBees"}
    mutations["Basalt"] = {parents = {"Forest", "Common"}, mod = "ExtraBees"}
    mutations["Tempered"] = {parents = {"Fiendish", "Basalt"}, mod = "ExtraBees"}
    mutations["Volcanic"] = {parents = {"Demonic", "Tempered"}, mod = "ExtraBees"}
    mutations["Glowstone"] = {parents = {"Tempered", "Excited"}, mod = "ExtraBees"}
    mutations["Malicious"] = {parents = {"Sinister", "Tropical"}, mod = "ExtraBees"}
    mutations["Infectious"] = {parents = {"Tropical", "Malicious"}, mod = "ExtraBees"}
    mutations["Virulent"] = {parents = {"Malicious", "Infectious"}, mod = "ExtraBees"}
    mutations["Viscous"] = {parents = {"Exotic", "Water"}, mod = "ExtraBees"}
    mutations["Glutinous"] = {parents = {"Exotic", "Viscous"}, mod = "ExtraBees"}
    mutations["Sticky"] = {parents = {"Viscous", "Glutinous"}, mod = "ExtraBees"}
    mutations["Corrosive"] = {parents = {"Malicious", "Viscous"}, mod = "ExtraBees"}
    mutations["Caustic"] = {parents = {"Fiendish", "Corrosive"}, mod = "ExtraBees"}
    mutations["Acidic"] = {parents = {"Corrosive", "Caustic"}, mod = "ExtraBees"}
    mutations["Excited"] = {parents = {"Valiant", "Cultivated"}, mod = "ExtraBees"}
    mutations["Energetic"] = {parents = {"Diligent", "Excited"}, mod = "ExtraBees"}
    mutations["Ecstatic"] = {parents = {"Excited", "Energetic"}, mod = "ExtraBees"}
    mutations["Artic"] = {parents = {"Wintry", "Diligent"}, mod = "ExtraBees"}
    mutations["Freezing"] = {parents = {"Ocean", "Artic"}, mod = "ExtraBees"}
    mutations["Shadow"] = {parents = {"Sinister", "Rock"}, mod = "ExtraBees"}
    mutations["Darkened"] = {parents = {"Shadow", "Rock"}, mod = "ExtraBees"}
    mutations["Abyssal"] = {parents = {"Shadow", "Darkened"}, mod = "ExtraBees"}
    mutations["Red"] = {parents = {"Forest", "Valiant"}, mod = "ExtraBees"}
    mutations["Yellow"] = {parents = {"Meadows", "Valiant"}, mod = "ExtraBees"}
    mutations["Blue"] = {parents = {"Valiant", "Water"}, mod = "ExtraBees"}
    mutations["Green"] = {parents = {"Tropical", "Valiant"}, mod = "ExtraBees"}
    mutations["Black"] = {parents = {"Valiant", "Rock"}, mod = "ExtraBees"}
    mutations["White"] = {parents = {"Wintry", "Valiant"}, mod = "ExtraBees"}
    mutations["Brown"] = {parents = {"Marshy", "Valiant"}, mod = "ExtraBees"}
    mutations["Orange"] = {parents = {"Red", "Yellow"}, mod = "ExtraBees"}
    mutations["Cyan"] = {parents = {"Green", "Blue"}, mod = "ExtraBees"}
    mutations["Purple"] = {parents = {"Red", "Blue"}, mod = "ExtraBees"}
    mutations["Gray"] = {parents = {"Black", "White"}, mod = "ExtraBees"}
    mutations["LightBlue"] = {parents = {"Blue", "White"}, mod = "ExtraBees"}
    mutations["Pink"] = {parents = {"Red", "White"}, mod = "ExtraBees"}
    mutations["LimeGreen"] = {parents = {"Green", "White"}, mod = "ExtraBees"}
    mutations["Magenta"] = {parents = {"Purple", "Pink"}, mod = "ExtraBees"}
    mutations["LightGray"] = {parents = {"Gray", "White"}, mod = "ExtraBees"}
    mutations["Celebratory"] = {parents = {"Austere", "Excited"}, mod = "ExtraBees"}
    mutations["Quantum"] = {parents = {"Spectral", "Spatial"}, mod = "ExtraBees"}
    mutations["Unusual"] = {parents = {"Secluded", "Ended"}, mod = "ExtraBees"}
    mutations["Spatial"] = {parents = {"Hermitic", "Unusual"}, mod = "ExtraBees"}
    mutations["Mystical"] = {parents = {"Noble", "Monastic"}, mod = "ExtraBees"}
    mutations["Hazardous"] = {parents = {"Austere", "Desolate"}, mod = "ExtraBees"}
    
    -- Career Bees mod (https://github.com/rwtema/Careerbees/blob/master/src/main/java/com/rwtema/careerbees/bees/CareerBeeSpecies.java)
    mutations["Student"] = {parents = {"Common", "Cultivated"}, mod = "Career Bees"}
    mutations["Vocational"] = {parents = {"Student", "Common"}, mod = "Career Bees"}
    mutations["Police"] = {parents = {"Vocational", "Valiant"}, mod = "Career Bees"}
    mutations["Thief"] = {parents = {"Sinister", "Police"}, mod = "Career Bees"}
    mutations["Engineer"] = {parents = {"Vocational", "Industrious"}, mod = "Career Bees"}
    mutations["Armorer"] = {parents = {"Vocational", "Steadfast"}, mod = "Career Bees"}
    mutations["Lumber"] = {parents = {"Vocational", "Common"}, mod = "Career Bees"}
    mutations["Husbandry"] = {parents = {"Vocational", "Meadows"}, mod = "Career Bees"}
    mutations["Smelter"] = {parents = {"Vocational", "Industrious"}, mod = "Career Bees"}
    mutations["MadScientist"] = {parents = {"Vocational", "Unusual"}, mod = "Career Bees"}
    mutations["QuantumCharm"] = {parents = {"MadScientist", "Phantasmal"}, mod = "Career Bees"}
    mutations["QuantumStrange"] = {parents = {"MadScientist", "Phantasmal"}, mod = "Career Bees"}
    mutations["Temporal"] = {parents = {"QuantumCharm", "QuantumStrange"}, mod = "Career Bees"}
    mutations["Rainbow"] = {parents = {"Student", "Cultivated"}, mod = "Career Bees"}
    mutations["Temporal"] = {parents = {"Engineer", "Temporal"}, mod = "Career Bees"}
    mutations["TaxCollector"] = {parents = {"Thief", "Imperial"}, mod = "Career Bees"}
    mutations["PHD"] = {parents = {"MadScientist", "Scholarly"}, mod = "Career Bees"}
    mutations["Robot"] = {parents = {"Engineer", "PHD"}, mod = "Career Bees"}
    mutations["Devil"] = {parents = {"Thief", "Demonic"}, mod = "Career Bees"}
    
    -- MeatballCraft Custom Bees (https://github.com/sainagh/meatballcraft/blob/main/config/gendustry/meatball_bees.cfg)
    mutations["Meatball"] = {parents = {"Industrious", "Diligent"}, mod = "MeatballCraft"}
    mutations["Balanced"] = {parents = {"Temporal", "Forlorn"}, mod = "MeatballCraft"}
    mutations["Formic"] = {parents = {"Acidic", "Meadows"}, mod = "MeatballCraft"}
    mutations["Oxygen"] = {parents = {"Student", "Imperial"}, mod = "MeatballCraft"}
    mutations["EMBee"] = {parents = {"Ethereal", "Arcane"}, mod = "MeatballCraft"}
    mutations["Fiotic"] = {parents = {"LightBlue", "Classical"}, mod = "MeatballCraft"}
    mutations["Feesh"] = {parents = {"Water", "Prehistoric"}, mod = "MeatballCraft"}
    mutations["Luctor"] = {parents = {"Rainbow", "Abyssal"}, mod = "MeatballCraft"}
    mutations["Necronomibee"] = {parents = {"Savant", "Abyssal"}, mod = "MeatballCraft"}
    mutations["Herblore"] = {parents = {"Esoteric", "Quantum"}, mod = "MeatballCraft"}
    mutations["Experienced"] = {parents = {"Radiant", "Armored"}, mod = "MeatballCraft"}
    mutations["Uselessforce"] = {parents = {"Red", "Fiendish"}, mod = "MeatballCraft"}
    mutations["RestlessClam"] = {parents = {"White", "Shocking"}, mod = "MeatballCraft"}
    mutations["Sandman"] = {parents = {"Black", "Firey"}, mod = "MeatballCraft"}
    mutations["Shadow"] = {parents = {"Alcohol", "Transmuting"}, mod = "MeatballCraft"}
    mutations["Baguette"] = {parents = {"Thief", "Pupil"}, mod = "MeatballCraft"}
    mutations["Agricultural"] = {parents = {"Virulent", "Doctoral"}, mod = "MeatballCraft"}
    mutations["Heraldry"] = {parents = {"Spectral", "Endearing"}, mod = "MeatballCraft"}
    mutations["Pyromaniacal"] = {parents = {"Devil", "Rainbow"}, mod = "MeatballCraft"}
    mutations["NerdySpider"] = {parents = {"Phantasmal", "Emerald"}, mod = "MeatballCraft"}
    mutations["Isekai"] = {parents = {"Crepuscular", "Deeplearner"}, mod = "MeatballCraft"}
    mutations["Pyramid"] = {parents = {"Lordly", "Temporal"}, mod = "MeatballCraft"}
    mutations["Buried"] = {parents = {"AESkystone", "Platinum"}, mod = "MeatballCraft"}
    mutations["Stargazer"] = {parents = {"Quantum", "Classical"}, mod = "MeatballCraft"}
    mutations["Chevron"] = {parents = {"Robot", "LightBlue"}, mod = "MeatballCraft"}
    mutations["Ringbearer"] = {parents = {"Gold", "Endearing"}, mod = "MeatballCraft"}
    mutations["Controller"] = {parents = {"Ringbearer", "Chevron"}, mod = "MeatballCraft"}
    mutations["Tinkerest"] = {parents = {"Blutonium", "PHD"}, mod = "MeatballCraft"}
    mutations["Serenading"] = {parents = {"Radiant", "Arcane"}, mod = "MeatballCraft"}
    mutations["Nuclear Technician"] = {parents = {"Bomber", "PHD"}, mod = "MeatballCraft"}
    mutations["Thermally Expanded"] = {parents = {"Pyro", "PHD"}, mod = "MeatballCraft"}
    mutations["Helium"] = {parents = {"Oxygen", "Deeplearner"}, mod = "MeatballCraft"}
    mutations["Fluorine"] = {parents = {"Oxygen", "Helium"}, mod = "MeatballCraft"}
    mutations["Connor"] = {parents = {"Radioactive", "Draconic"}, mod = "MeatballCraft"}
    mutations["Freeky"] = {parents = {"EMBee", "Sweet"}, mod = "MeatballCraft"}
    mutations["Kurrycat"] = {parents = {"Scholarly", "PHD"}, mod = "MeatballCraft"}
    mutations["SpoonyPanda"] = {parents = {"Supernatural", "Mineral"}, mod = "MeatballCraft"}
    mutations["LordRaine"] = {parents = {"Sorcerous", "Temporal"}, mod = "MeatballCraft"}
    mutations["Aedial"] = {parents = {"Skeletal", "Scholarly"}, mod = "MeatballCraft"}
    mutations["Mathias"] = {parents = {"Ringbearer", "Granite"}, mod = "MeatballCraft"}
    mutations["ChaosStrikez"] = {parents = {"Energetic", "Savant"}, mod = "MeatballCraft"}
    
    return mutations
end

local mutations = loadBeeDatabase()

-- System configuration
local config = {
    -- General settings
    mech_user_side = sides.right,     -- Side where Mechanical User is connected
    pulse_duration = 1,               -- Duration of redstone pulse in seconds
    apiary_wait_time = 30,            -- Time to wait for apiary to process queen (seconds)
    collection_wait_time = 5,         -- Time between collection attempts
    add_drone_count = 0,              -- Number of additional drones to produce during accumulation
    enabled_mods = {"Forestry", "MagicBees", "ExtraBees", "Career Bees", "MeatballCraft"},  -- Mods to include in bee list (nil for all)

    -- Status indicators
    use_status_lamp = true,           -- Enable colored lamp status indicator
    use_chat_notifications = true,    -- Enable chat box notifications
    chat_player_name = nil,           -- Player name for chat messages (nil for broadcast)

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
local function generateBeeList(modlist)
    local bees = {}

    -- Add all bees from mutations
    for species, data in pairs(mutations) do
        if not modlist or (modlist and modlist[data.mod]) then
            table.insert(bees, species)
        end
    end
    
    -- Sort alphabetically for easier browsing
    table.sort(bees)
    return bees
end

local available_bees = generateBeeList()

-- Filter bees by mod
local function getBeesByMod(mod_name)
    local filtered = {}

    for species, data in pairs(mutations) do
        if data.mod == mod_name then
            table.insert(filtered, species)
        end
    end

    table.sort(filtered)

    return filtered
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
    gpu.setBackground(0x000000)  -- TODO: better color (slate gray instead of black?)
    gpu.setForeground(0xFFFFFF)  -- TODO: better color (light gray instead of white?)

    print("=== HiveMind: Bee Breeding Automation ===")
    print()
    
    -- Set initial status
    updateStatusIndicators("idle", "System started - Ready for commands")
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
        
        -- TODO: refactor to avoid code duplication
        if inv_size then
            total_inventories = total_inventories + 1
            print("Scanning " .. name .. " (" .. inv_size .. " slots)")
            
            for slot = 1, inv_size do
                local stack = inv_controller.getStackInSlot(side, slot)
                if stack then
                    local item_name = stack.name or stack.label or ""

                    -- TODO: if we find any queen, we should kill them to get princess + drone back and rescan
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

--- Helper function to get side name for display
--- @param side number Side constant from sides enum
--- @return string sideName Human-readable side name
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

-- New tree-based breeding path calculation
function calculateBreedingPath(target)
    print("Calculating breeding strategy for " .. target .. "...")
    
    -- Check if we already have the target
    if hasSpecies(target) then
        return {
            tree = nil,
            starting_princesses = {},
            drone_requirements = {},
            total_steps = 0,
            target = target
        }
    end
    
    -- Build the breeding tree
    local tree = buildBreedingTree(target)
    if not tree then
        print("ERROR: Cannot find path to " .. target)
        return nil
    end
    
    -- Clean the tree (remove duplicate drone requirements)
    cleanBreedingTree(tree)
    
    -- Extract drone requirements and calculate steps
    local drone_requirements = calculateDroneRequirements(tree)
    local total_steps = countTreeSteps(tree)
    
    -- Calculate base species requirements (this gives us the actual starting princesses needed)
    local missing_princesses, missing_drones = calculateMissingBaseSpecies(tree, drone_requirements)
    
    -- The starting princesses are just the base species that we need as princesses
    local starting_princesses = {}
    local base_princesses_needed = {}
    local base_drones_needed = {}
    
    findBaseSpeciesNeeded(tree, base_princesses_needed, base_drones_needed)
    
    for species, count in pairs(base_princesses_needed) do
        table.insert(starting_princesses, species)
    end
    
    -- Check if plan can be executed (no missing base species)
    local can_execute = true
    for _, _ in pairs(missing_princesses) do
        can_execute = false
        break
    end
    if can_execute then
        for _, _ in pairs(missing_drones) do
            can_execute = false
            break
        end
    end
    
    -- Perform sanity checks on the optimized tree
    local sanity_results = performTreeSanityChecks(tree, target)
    
    -- Handle critical errors (plan is invalid)
    if sanity_results.has_errors then
        print("❌ CRITICAL ERRORS detected in breeding plan:")
        for _, error in ipairs(sanity_results.errors) do
            print("  " .. error.message)
            if error.path then
                print("    Location: " .. error.path)
            end
        end
        -- Return error details for debugging instead of nil
        return {
            tree = tree,
            starting_princesses = starting_princesses,
            drone_requirements = drone_requirements,
            total_steps = total_steps,
            target = target,
            missing_princesses = missing_princesses,
            missing_drones = missing_drones,
            can_execute = false,
            critical_errors = sanity_results.errors,
            plan_failed = true,
            sanity_issues = sanity_results.warnings
        }
    end
    
    -- Handle warnings (plan is valid but suboptimal)
    if sanity_results.has_warnings then
        print("⚠️  Optimization warnings:")
        for _, warning in ipairs(sanity_results.warnings) do
            print("  " .. warning.message)
            if warning.type == "missed_reuse" then
                for species, details in pairs(warning.details) do
                    if details.potential_additional_reuse then
                        print("    " .. species .. ": " .. details.occurrences .. " occurrences, " .. details.reused .. " reused, could reuse " .. details.potential_additional_reuse .. " more")
                    else
                        print("    " .. species .. ": " .. details.occurrences .. " occurrences, no reuse")
                    end
                end
            end
        end
    end
    
    return {
        tree = tree,
        starting_princesses = starting_princesses,
        drone_requirements = drone_requirements,
        total_steps = total_steps,
        target = target,
        missing_princesses = missing_princesses,
        missing_drones = missing_drones,
        can_execute = can_execute,
        sanity_issues = sanity_results.warnings -- Only pass warnings to artifacts (errors already failed the plan)
    }
end

-- Build breeding tree with left (princess) and right (drone) branches
function buildBreedingTree(species)
    -- Base case: if no mutation exists, this is a base species
    if not mutations[species] then
        return {
            species = species,
            left_parent = nil,
            right_parent = nil,
            need_princess = not hasSpeciesPrincess(species),
            need_drone = not hasSpeciesDrone(species),
            drone_count = 0
        }
    end
    
    local parents = mutations[species].parents
    local left_parent = parents[1]  -- Princess parent (golden path)
    local right_parent = parents[2] -- Drone parent
    
    local tree = {
        species = species,
        left_parent = nil,
        right_parent = nil,
        need_princess = not hasSpeciesPrincess(species),
        need_drone = not hasSpeciesDrone(species),
        drone_count = 0
    }
    
    -- ALWAYS build complete tree - build both parent branches
    tree.left_parent = buildBreedingTree(left_parent)
    tree.right_parent = buildBreedingTree(right_parent)
    
    return tree
end

-- Clean breeding tree using breadth-first stock optimization + climbing optimization
function cleanBreedingTree(tree)
    if not tree then return end
    
    -- Step 1: Complete tree is already built by buildBreedingTree
    
    -- Step 2: Breadth-first stock optimization - remove sub-trees for species we have in stock
    optimizeTreeByStock(tree)
    
    -- Step 3: Pre-exploration to analyze species occurrences and complexities
    local species_info = {}
    preExploreTree(tree, species_info)
    
    -- Step 4: Climbing optimization for drone accumulation with smart branch selection
    local accumulated_drones = {}
    climbingOptimizeForAccumulation(tree, accumulated_drones, species_info, nil)
    
    -- Step 5: Second optimization pass - smarter reuse based on princess vs drone analysis
    smarterReuseOptimization(tree, species_info)
end

-- Count how many times each species is needed as a drone in the tree
function countDroneOccurrences(tree, counts)
    if not tree then return end
    
    -- Count this species if it's needed as a drone
    if tree.need_drone then
        counts[tree.species] = (counts[tree.species] or 0) + 1
    end
    
    -- Recursively count in subtrees
    countDroneOccurrences(tree.left_parent, counts)
    countDroneOccurrences(tree.right_parent, counts)
end

-- Breadth-first stock optimization - remove sub-trees for species we have in stock
function optimizeTreeByStock(tree)
    if not tree then return end
    
    -- Process tree level by level (breadth-first)
    local current_level = {tree}
    
    while #current_level > 0 do
        local next_level = {}
        
        for _, node in ipairs(current_level) do
            -- Check if we have stock of this species (accounting for breeding needs)
            local available_princesses = countAvailablePrincesses(node.species) 
            local available_drones = countAvailableDrones(node.species)
            
            -- If we have stock, we can simplify this node
            if available_princesses > 0 or available_drones > 0 then
                -- Remove breeding sub-tree but keep as leaf node for breeding
                node.left_parent = nil
                node.right_parent = nil
                node.reusing_stock = true
                -- Don't process children of this node (they're removed)
            else
                -- Add children to next level for processing
                if node.left_parent then
                    table.insert(next_level, node.left_parent)
                end
                if node.right_parent then
                    table.insert(next_level, node.right_parent)
                end
            end
        end
        
        current_level = next_level
    end
end

-- Count available princesses for a species
function countAvailablePrincesses(species)
    local count = 0
    for _, princess in ipairs(inventory.princesses) do
        if princess == species then
            count = count + 1
        end
    end
    return count
end

-- Find the deepest node in the tree (furthest from root)
function findDeepestNode(tree)
    local deepest = tree
    local max_depth = 0
    
    local function findDepth(node, depth)
        if not node then return end
        
        if depth > max_depth then
            max_depth = depth
            deepest = node
        end
        
        if node.left_parent then
            findDepth(node.left_parent, depth + 1)
        end
        if node.right_parent then
            findDepth(node.right_parent, depth + 1)
        end
    end
    
    findDepth(tree, 0)
    return deepest
end


-- Calculate depth of a tree (for optimization decisions)
function calculateTreeDepth(tree)
    if not tree then return 0 end
    if not tree.left_parent and not tree.right_parent then return 1 end
    
    local left_depth = calculateTreeDepth(tree.left_parent)
    local right_depth = calculateTreeDepth(tree.right_parent)
    
    return 1 + math.max(left_depth, right_depth)
end

-- Pre-exploration to find all species and their breeding complexities
function preExploreTree(tree, species_info, distance_from_root)
    if not tree then return end
    
    distance_from_root = distance_from_root or 0
    
    -- Calculate depth of this subtree and distance from root
    local subtree_depth = calculateTreeDepth(tree)
    tree._original_depth = subtree_depth  -- Store original subtree depth
    tree._distance_from_root = distance_from_root  -- Store distance from root
    
    -- Store or update species info
    if not species_info[tree.species] then
        species_info[tree.species] = {
            min_subtree_depth = subtree_depth,
            min_distance_from_root = distance_from_root,
            occurrences = 0,
            nodes = {}
        }
    else
        -- Keep track of minimum values
        species_info[tree.species].min_subtree_depth = math.min(species_info[tree.species].min_subtree_depth, subtree_depth)
        species_info[tree.species].min_distance_from_root = math.min(species_info[tree.species].min_distance_from_root, distance_from_root)
    end
    
    species_info[tree.species].occurrences = species_info[tree.species].occurrences + 1
    table.insert(species_info[tree.species].nodes, tree)
    
    -- Recursively explore children
    preExploreTree(tree.left_parent, species_info, distance_from_root + 1)
    preExploreTree(tree.right_parent, species_info, distance_from_root + 1)
end

-- Climbing optimization for drone accumulation (with smart branch selection)
function climbingOptimizeForAccumulation(tree, accumulated_drones, species_info, parent)
    if not tree then return end
    
    if tree.left_parent then
        climbingOptimizeForAccumulation(tree.left_parent, accumulated_drones, species_info, tree)
    end
    if tree.right_parent then
        climbingOptimizeForAccumulation(tree.right_parent, accumulated_drones, species_info, tree)
    end
    
    -- Skip if this node is already marked for reuse
    if tree.reusing_drone then
        return
    end
    
    -- Check if we've already encountered this species and can reuse
    local species_data = species_info[tree.species]
    if species_data and species_data.occurrences > 1 and accumulated_drones[tree.species] and accumulated_drones[tree.species] > 0 then
        local current_distance = tree._distance_from_root or 0
        local min_distance = species_data.min_distance_from_root
        
        if current_distance >= min_distance then
            if parent and parent.left_parent and parent.right_parent then
                local sibling = parent.left_parent == tree and parent.right_parent or parent.left_parent
                if sibling and sibling.reusing_drone then
                    return
                end
            end
            tree.reusing_drone = true
            accumulated_drones[tree.species] = accumulated_drones[tree.species] - 1
            tree.left_parent = nil
            tree.right_parent = nil
            return
        end
    end
    
    -- If we're breeding this species (has parents), add it to accumulation
    if tree.left_parent or tree.right_parent then
        accumulated_drones[tree.species] = (accumulated_drones[tree.species] or 0) + 1
    end
end

-- Second optimization pass: breadth-first analysis + climbing optimization
function smarterReuseOptimization(tree, species_info)
    if not tree then return end
    
    -- Step 1: Breadth-first pass to identify nodes with both parents unreused (potential for optimization)
    local optimization_candidates = {}
    identifyOptimizationCandidates(tree, optimization_candidates, 0)
    
    -- Sort candidates by distance from root (process closer to root first)
    table.sort(optimization_candidates, function(a, b) return a.distance < b.distance end)
    
    -- Step 2: Climbing pass - for each candidate, try to reuse one parent without killing ancestors
    for _, candidate in ipairs(optimization_candidates) do
        optimizeNodeParents(candidate.node, tree, species_info)
    end
end

-- Breadth-first identification of nodes that have both parents unreused (optimization candidates)
function identifyOptimizationCandidates(tree, candidates, distance)
    if not tree then return end
    
    -- Check if this node has both parents unreused (potential for optimization)
    if tree.left_parent and tree.right_parent then
        local left_reused = tree.left_parent.reusing_drone or false
        local right_reused = tree.right_parent.reusing_drone or false
        
        if not left_reused and not right_reused then
            -- This node has both parents unreused - it's a candidate for optimization
            table.insert(candidates, {node = tree, distance = distance})
        end
    end
    
    -- Continue breadth-first traversal
    identifyOptimizationCandidates(tree.left_parent, candidates, distance + 1)
    identifyOptimizationCandidates(tree.right_parent, candidates, distance + 1)
end

-- Try to optimize a node's parents by reusing one of them (climbing approach)
function optimizeNodeParents(node, root_tree, species_info)
    if not node or not node.left_parent or not node.right_parent then
        return
    end
    
    local left_parent = node.left_parent
    local right_parent = node.right_parent
    local left_reused = left_parent.reusing_drone
    local right_reused = right_parent.reusing_drone

    -- Ensure at least one parent remains available for breeding
    if left_reused or right_reused then
        return
    end
    
    if canReuseParentSafely(left_parent, root_tree, species_info) then
        left_parent.reusing_drone = true
        left_parent.left_parent = nil
        left_parent.right_parent = nil
        return
    end
    
    if canReuseParentSafely(right_parent, root_tree, species_info) then
        right_parent.reusing_drone = true
        right_parent.left_parent = nil
        right_parent.right_parent = nil
        return
    end
end

-- Check if a parent can be safely reused without "killing ancestors"
function canReuseParentSafely(parent, root_tree, species_info)
    if not parent or parent.reusing_drone then
        return false -- Already reused or invalid
    end
    
    -- Check if this parent species is available elsewhere in the tree
    local parent_species = parent.species
    local available_sources = countAvailableSourcesForSpecies(parent_species, root_tree, parent)
    
    -- We need at least one other source for this species (excluding this one)
    if available_sources < 1 then
        return false -- Would kill our only source for this species
    end
    
    -- Check if we have this species in stock
    if hasSpeciesDrone(parent_species) then
        return true -- We have it in stock, safe to reuse
    end
    
    return available_sources > 0 -- Safe if there are other sources
end

-- Count how many other sources exist for a species (excluding the given node)
function countAvailableSourcesForSpecies(species, tree, exclude_node)
    if not tree or tree == exclude_node then
        return 0
    end
    
    local count = 0
    
    -- If this node produces the species and is not reused, count it
    if tree.species == species and not tree.reusing_drone and (tree.left_parent or tree.right_parent) then
        count = count + 1
    end
    
    -- Recursively count in subtrees
    count = count + countAvailableSourcesForSpecies(species, tree.left_parent, exclude_node)
    count = count + countAvailableSourcesForSpecies(species, tree.right_parent, exclude_node)
    
    return count
end

-- Find the best node to keep as the producer (closest to root, most efficient)
function findBestProducer(nodes)
    local best = nodes[1]
    local best_distance = best._distance_from_root or 0
    
    for i = 2, #nodes do
        local node = nodes[i]
        local distance = node._distance_from_root or 0
        
        -- Prefer nodes closer to root (lower distance)
        if distance < best_distance then
            best = node
            best_distance = distance
        end
    end
    
    return best
end

-- Check if a node can be safely reused without creating dependency issues
function canSafelyReuseNode(node, species, species_info)
    if not node.left_parent or not node.right_parent then
        return true -- Leaf nodes can always be reused safely
    end
    
    -- Check if reusing this node would create a dependency on base species that we can't fulfill
    local required_princesses = {}
    findPrincessRequirementsForNode(node, required_princesses)
    
    -- For each required princess species, check if we have other ways to obtain it
    for req_species, count in pairs(required_princesses) do
        if not canFulfillPrincessRequirement(req_species, count, species_info) then
            return false
        end
    end
    
    return true
end

-- Find princess requirements that would be lost if we reuse this node
function findPrincessRequirementsForNode(node, requirements)
    if not node then return end
    
    -- If this is a leaf node that needs a princess, count it
    if not node.left_parent and not node.right_parent then
        if node.need_princess then
            requirements[node.species] = (requirements[node.species] or 0) + 1
        end
        return
    end
    
    -- Recursively check children
    findPrincessRequirementsForNode(node.left_parent, requirements)
    findPrincessRequirementsForNode(node.right_parent, requirements)
end

-- Check if a princess requirement can be fulfilled by other nodes in the tree
function canFulfillPrincessRequirement(species, count, species_info)
    -- If we have the species in stock, we can fulfill it
    if hasSpeciesPrincess(species) then
        return true
    end
    
    -- If there are other non-reused occurrences of this species that can produce it, we're good
    local species_data = species_info[species]
    if species_data then
        local available_producers = 0
        for _, node in ipairs(species_data.nodes) do
            if not node.reusing_drone and (node.left_parent or node.right_parent) then
                available_producers = available_producers + 1
            end
        end
        
        if available_producers >= count then
            return true
        end
    end
    
    return false
end

-- Check if the current tree has any impossible parents (both children reused)
function treeHasImpossibleParents(species_info)
    -- Check all species nodes to see if any parent has both children reused
    for species, data in pairs(species_info) do
        for _, node in ipairs(data.nodes) do
            if node.left_parent and node.right_parent then
                local left_reused = node.left_parent.reusing_drone or false
                local right_reused = node.right_parent.reusing_drone or false
                
                if left_reused and right_reused then
                    return true -- Found an impossible parent
                end
            end
        end
    end
    
    return false -- No impossible parents found
end

-- Validate tree after optimization to ensure no impossible parent-child relationships
function validateTreeAfterOptimization(tree)
    if not tree then return end
    
    -- Check this node
    if tree.left_parent and tree.right_parent then
        -- If both children exist, at least one must not be reused
        local left_reused = tree.left_parent.reusing_drone or false
        local right_reused = tree.right_parent.reusing_drone or false
        
        if left_reused and right_reused then
            -- CRITICAL ERROR: Both children are reused, this parent cannot be bred
            -- Fix by un-reusing one of the children (prefer the deeper/more complex one)
            fixImpossibleParent(tree)
        end
    end
    
    -- Recursively validate children
    validateTreeAfterOptimization(tree.left_parent)
    validateTreeAfterOptimization(tree.right_parent)
end

-- Fix a parent node that has both children reused (impossible situation)
function fixImpossibleParent(parent)
    if not parent.left_parent or not parent.right_parent then
        return -- Nothing to fix
    end
    
    local left_child = parent.left_parent
    local right_child = parent.right_parent
    
    -- Choose which child to un-reuse (prefer keeping the simpler one reused)
    local left_depth = left_child._original_depth or 0
    local right_depth = right_child._original_depth or 0
    
    if left_depth >= right_depth then
        -- Left is deeper/more complex, un-reuse it and restore its breeding tree
        unreuseNode(left_child)
    else
        -- Right is deeper/more complex, un-reuse it and restore its breeding tree
        unreuseNode(right_child)
    end
end

-- Un-reuse a node by restoring its breeding capability (preserving optimizations where possible)
function unreuseNode(node)
    if not node or not node.reusing_drone then
        return -- Nothing to do
    end
    
    -- Clear the reuse flag
    node.reusing_drone = false
    
    -- Restore the breeding tree (we need to rebuild it)
    if mutations[node.species] then
        local parents = mutations[node.species].parents
        node.left_parent = buildBreedingTree(parents[1])
        node.right_parent = buildBreedingTree(parents[2])
        
        -- Apply optimizations to the restored subtree
        optimizeTreeByStock(node)
        
        -- Re-apply reuse optimizations to the subtree (but avoid the validation loop)
        local species_info = {}
        preExploreTree(node, species_info)
        local accumulated_drones = {}
        climbingOptimizeForAccumulation(node, accumulated_drones, species_info)
    end
end

-- Apply the climbing optimization results to the tree
function applyClimbingOptimization(tree, available_drones)
    if not tree then return end
    
    -- Apply reusing_drone markers that were set during climbing
    applyClimbingOptimization(tree.left_parent, available_drones)
    applyClimbingOptimization(tree.right_parent, available_drones)
end

-- Find all starting princesses needed for the tree
function findStartingPrincesses(tree)
    if not tree then return {} end
    
    local princesses = {}
    
    -- If this is a leaf node and we need a princess, it's a starting princess
    if not tree.left_parent and not tree.right_parent and tree.need_princess then
        table.insert(princesses, tree.species)
    end
    
    -- Recursively find starting princesses in subtrees
    local left_princesses = findStartingPrincesses(tree.left_parent)
    local right_princesses = findStartingPrincesses(tree.right_parent)
    
    for _, princess in ipairs(left_princesses) do
        table.insert(princesses, princess)
    end
    for _, princess in ipairs(right_princesses) do
        table.insert(princesses, princess)
    end
    
    return princesses
end

-- Recursively find all base species needed for a tree node
function findBaseSpeciesNeeded(tree, base_princesses, base_drones)
    if not tree then return end
    
    -- If this is a base species (no mutation), count it
    if not mutations[tree.species] then
        if tree.need_princess then
            base_princesses[tree.species] = (base_princesses[tree.species] or 0) + 1
        end
        if tree.need_drone and not tree.reusing_drone then
            base_drones[tree.species] = (base_drones[tree.species] or 0) + 1
        end
        return
    end
    
    -- If this is an intermediate species, recurse to its components
    findBaseSpeciesNeeded(tree.left_parent, base_princesses, base_drones)
    findBaseSpeciesNeeded(tree.right_parent, base_princesses, base_drones)
end

-- Calculate missing base species needed for the breeding plan
function calculateMissingBaseSpecies(tree, drone_requirements)
    local base_princesses_needed = {}
    local base_drones_needed = {}
    
    -- Find all base species needed by traversing the complete tree
    findBaseSpeciesNeeded(tree, base_princesses_needed, base_drones_needed)
    
    -- Calculate missing princesses (base species only)
    local missing_princesses = {}
    for species, needed in pairs(base_princesses_needed) do
        local available = 0
        if hasSpeciesPrincess(species) then
            available = 1 -- Simple count - could be enhanced to track actual quantities
        end
        if needed > available then
            missing_princesses[species] = needed - available
        end
    end
    
    -- Calculate missing drones (base species only)
    local missing_drones = {}
    for species, needed in pairs(base_drones_needed) do
        local available = 0
        if hasSpeciesDrone(species) then
            available = 1 -- Simple count - could be enhanced to track actual quantities  
        end
        if needed > available then
            missing_drones[species] = needed - available
        end
    end
    
    return missing_princesses, missing_drones
end

-- Sanity check: detect species that appear multiple times but weren't reused
function detectMissedReuseOpportunities(tree)
    local species_occurrences = {}
    local missed_opportunities = {}
    
    -- Check if a node can be reused based on sibling constraints
    local function canNodeBeReused(node, parent_context)
        if not parent_context or not parent_context.parent then
            return true -- Root or orphaned nodes can be reused
        end
        
        local parent = parent_context.parent
        local sibling = parent_context.side == "left" and parent.right_parent or parent.left_parent
        
        -- If sibling is reused, this node cannot be reused (would create impossible parent)
        if sibling and sibling.reusing_drone then
            return false
        end
        
        return true
    end
    
    -- Count all occurrences of each species in the tree, tracking sibling relationships
    local function countSpeciesOccurrences(node, parent_context)
        if not node then return end
        
        if not species_occurrences[node.species] then
            species_occurrences[node.species] = {
                total = 0,
                reused = 0,
                nodes = {},
                reusable_nodes = {}
            }
        end
        
        species_occurrences[node.species].total = species_occurrences[node.species].total + 1
        table.insert(species_occurrences[node.species].nodes, node)
        
        if node.reusing_drone then
            species_occurrences[node.species].reused = species_occurrences[node.species].reused + 1
        else
            -- Check if this node can actually be reused (no reusing siblings)
            if canNodeBeReused(node, parent_context) then
                table.insert(species_occurrences[node.species].reusable_nodes, node)
            end
        end
        
        countSpeciesOccurrences(node.left_parent, {parent = node, side = "left"})
        countSpeciesOccurrences(node.right_parent, {parent = node, side = "right"})
    end
    
    countSpeciesOccurrences(tree, nil)
    
    -- Identify missed opportunities (only for intermediate species, considering sibling constraints)
    for species, data in pairs(species_occurrences) do
        -- Skip base species (species without mutations) - their multiple occurrences are expected
        if mutations[species] then
            local total_reusable = #data.reusable_nodes
            
            if data.total > 1 and data.reused == 0 and total_reusable > 0 then
                -- Multiple occurrences but no reuse, and some could be reused
                missed_opportunities[species] = {
                    occurrences = data.total,
                    nodes = data.nodes,
                    potential_additional_reuse = total_reusable - 1 -- Keep at least one
                }
            elseif total_reusable > 1 and data.reused < total_reusable - 1 then
                -- More reusable nodes than we're currently reusing
                missed_opportunities[species] = {
                    occurrences = data.total,
                    reused = data.reused,
                    potential_additional_reuse = (total_reusable - 1) - data.reused,
                    nodes = data.nodes
                }
            end
        end
    end
    
    return missed_opportunities
end

-- Sanity check: verify tree consistency
function performTreeSanityChecks(tree, target)
    local warnings = {}
    local errors = {}
    
    -- Check for missed reuse opportunities (WARNING - not fatal)
    local missed_reuse = detectMissedReuseOpportunities(tree)
    if next(missed_reuse) then
        table.insert(warnings, {
            type = "missed_reuse",
            severity = "warning",
            details = missed_reuse,
            message = "Potential missed reuse opportunities detected"
        })
    end
    
    -- Check for reused nodes that still have children (ERROR - fatal)
    local function checkReuseConsistency(node, path)
        if not node then return end
        
        if node.reusing_drone and (node.left_parent or node.right_parent) then
            table.insert(errors, {
                type = "reuse_inconsistency",
                severity = "error", 
                species = node.species,
                path = path,
                message = "CRITICAL: Reused node " .. node.species .. " still has breeding children"
            })
        end
        
        if node.left_parent then
            checkReuseConsistency(node.left_parent, path .. "->" .. node.left_parent.species)
        end
        if node.right_parent then
            checkReuseConsistency(node.right_parent, path .. "->" .. node.right_parent.species)
        end
    end
    
    checkReuseConsistency(tree, target)
    
    -- Check for impossible parents (ERROR - fatal)
    local function checkImpossibleParents(node, path)
        if not node then return end
        
        if node.left_parent and node.right_parent then
            local left_reused = node.left_parent.reusing_drone or false
            local right_reused = node.right_parent.reusing_drone or false
            
            if left_reused and right_reused then
                table.insert(errors, {
                    type = "impossible_parent",
                    severity = "error",
                    species = node.species, 
                    path = path,
                    message = "CRITICAL: " .. node.species .. " has both children reused (impossible to breed)"
                })
            end
        end
        
        if node.left_parent then
            checkImpossibleParents(node.left_parent, path .. "->" .. node.left_parent.species)
        end
        if node.right_parent then
            checkImpossibleParents(node.right_parent, path .. "->" .. node.right_parent.species)
        end
    end
    
    checkImpossibleParents(tree, target)
    
    return {
        warnings = warnings,
        errors = errors,
        has_errors = #errors > 0,
        has_warnings = #warnings > 0
    }
end

-- Calculate drone requirements with accumulation counts (base species only)
function calculateDroneRequirements(tree)
    if not tree then return {} end
    
    local requirements = {}
    
    -- Calculate base species drone requirements by accumulating all intermediate needs
    local base_drones_needed = {}
    calculateBaseDroneRequirements(tree, base_drones_needed)
    
    -- Convert to the expected format
    for species, count in pairs(base_drones_needed) do
        requirements[species] = {
            available = countAvailableDrones(species),
            needed = count
        }
    end
    
    return requirements
end

-- Calculate base species drone requirements by traversing and accumulating
function calculateBaseDroneRequirements(tree, base_drones_needed)
    if not tree then return end
    
    -- If this is a base species (no mutation) that needs a drone and is not reusing, count it
    if not mutations[tree.species] then
        if tree.need_drone and not tree.reusing_drone then
            base_drones_needed[tree.species] = (base_drones_needed[tree.species] or 0) + 1
        end
        return
    end
    
    -- For intermediate species, recurse to their components
    calculateBaseDroneRequirements(tree.left_parent, base_drones_needed)
    calculateBaseDroneRequirements(tree.right_parent, base_drones_needed)
end

-- Count available drones for a species
function countAvailableDrones(species)
    local count = 0
    for _, drone in ipairs(inventory.drones) do
        if drone == species then
            count = count + 1
        end
    end
    return count
end

-- Count total breeding steps in the tree
function countTreeSteps(tree)
    if not tree then return 0 end
    
    local steps = 0
    
    -- If this node requires breeding (has parents), count it
    if tree.left_parent or tree.right_parent then
        steps = steps + 1
    end
    
    -- Add steps from subtrees
    steps = steps + countTreeSteps(tree.left_parent)
    steps = steps + countTreeSteps(tree.right_parent)
    
    return steps
end

--- Check if we have a specific species as princess
--- @param species string The bee species to check for
--- @return boolean hasPrincess True if we have this species as princess/queen
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

--- Check if Mechanical User has beebee gun equipped
--- @return boolean hasGun True if beebee gun is found
--- @return string|nil gunName Name of the gun item if found
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
    
    if not hasGun then
        updateStatusIndicators("waiting", "Waiting for beebee gun", gui_state.current_species)
        handleError("Beebee gun not found in Mechanical User slot " .. config.beebee_gun_slot, validateBeebeeGun)
    end
    
    if control_state.abort_requested then
        return false
    end
    
    drawGUI({progress = "Beebee gun ready: " .. gunName, status = "Ready"})
    return true
end

-- Activate Mechanical User via redstone pulse (with beebee gun check)
function activateMechanicalUser()
    waitForBeebeeGun()
    
    redstone.setOutput(config.mech_user_side, 15)
    os.sleep(config.pulse_duration)
    redstone.setOutput(config.mech_user_side, 0)
end

--- Move items between inventories
--- @param from_side number Source inventory side
--- @param from_slot number Source slot number
--- @param to_side number Destination inventory side  
--- @param to_slot number|nil Destination slot number (nil for any slot)
--- @param count number|nil Number of items to move (default 64)
--- @return boolean success True if items were moved
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

--- Insert princess and drone into mutatron
--- @param parent1 string Species name for princess/queen
--- @param parent2 string Species name for drone
--- @return boolean success True if mutatron was loaded successfully
--- @return string message Status message
function loadMutatron(parent1, parent2)
    -- Check continue state
    local should_continue, abort_msg = checkContinue()
    if not should_continue then
        return false, abort_msg
    end
    
    -- Find princess and drone across all inventories
    local princess_side, princess_slot, princess_stack = findItemAnyInventory(parent1 .. ".*(princess|queen)")
    local drone_side, drone_slot, drone_stack = findItemAnyInventory(parent2 .. ".*drone")
    
    if not princess_slot then
        handleError("Could not find " .. parent1 .. " princess/queen in any inventory!", 
                   function() return validateBeeAvailability(parent1, "princess") end)
        if control_state.abort_requested then return false, "Aborted" end
    end
    
    if not drone_slot then
        handleError("Could not find " .. parent2 .. " drone in any inventory!", 
                   function() return validateBeeAvailability(parent2, "drone") end)
        if control_state.abort_requested then return false, "Aborted" end
    end
    
    -- Move items to mutatron
    local success1 = moveItem(princess_side, princess_slot, config.mutatron_side, config.mutatron_input_slots[1], 1)
    local success2 = moveItem(drone_side, drone_slot, config.mutatron_side, config.mutatron_input_slots[2], 1)
    
    if not (success1 and success2) then
        handleError("Failed to load mutatron properly - check mutatron inventory space", nil)
        if control_state.abort_requested then return false, "Aborted" end
    end
    
    return true, "Successfully loaded mutatron"
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
        drawGUI({progress = "Move failed", errors = "Failed to move queen to apiary", status = "Error"})
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

-- Display comprehensive breeding plan with tree structure
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
    
    -- Display starting princesses required
    if #breeding_plan.starting_princesses > 0 then
        print("=== STARTING PRINCESSES REQUIRED ===")
        for i, princess in ipairs(breeding_plan.starting_princesses) do
            local status = hasSpeciesPrincess(princess) and " ✓" or " ✗"
            print(string.format("%d. %s%s", i, princess, status))
        end
        print()
    end
    
    -- Display drone requirements
    if next(breeding_plan.drone_requirements) then
        print("=== DRONE REQUIREMENTS ===")
        for species, req in pairs(breeding_plan.drone_requirements) do
            local shortage = math.max(0, req.needed - req.available)
            local accumulation = shortage + config.add_drone_count
            print(string.format("%s: %d available / %d needed (+%d accumulation = %d total)", 
                  species, req.available, req.needed, config.add_drone_count, accumulation))
        end
        print()
    end
    
    -- Display breeding tree structure
    if breeding_plan.tree then
        print("=== BREEDING TREE ===")
        print("Golden path (left branch) and drone branches (right):")
        displayTree(breeding_plan.tree, "", true)
        print()
    end
    
    -- Display execution summary
    print("=== EXECUTION SUMMARY ===")
    print("1. Build the tree from bottom to top (depth-first)")
    print("2. Follow golden path (left branches)")
    print("3. When missing drones, execute accumulation cycles")
    print("4. Resume golden path when drones are available")
    print("5. Each step: Princess + Drone -> Queen -> Apiary -> New Queen + Drones")
    
    return true
end

-- Display breeding tree structure
function displayTree(tree, prefix, isLast)
    if not tree then return end
    
    local connector = isLast and "└── " or "├── "
    local status_princess = hasSpeciesPrincess(tree.species) and "P" or " "
    local status_drone = hasSpeciesDrone(tree.species) and "D" or " "
    local breeding_marker = (tree.left_parent or tree.right_parent) and " *" or ""
    
    -- Add optimization marker for nodes that reuse drones from elsewhere
    local optimization_marker = ""
    if tree.reusing_stock then
        optimization_marker = " (from stock)"
    elseif tree.reusing_drone then
        optimization_marker = " (reusing)"
    end
    
    print(prefix .. connector .. tree.species .. " [" .. status_princess .. status_drone .. "]" .. breeding_marker .. optimization_marker)
    
    local newPrefix = prefix .. (isLast and "    " or "│   ")
    
    -- Display all children to show complete breeding structure
    if tree.left_parent and tree.right_parent then
        -- Both parents exist
        displayTree(tree.left_parent, newPrefix, false)
        displayTree(tree.right_parent, newPrefix, true)
    elseif tree.left_parent then
        -- Only princess parent (left)
        displayTree(tree.left_parent, newPrefix, true)
    elseif tree.right_parent then
        -- Only drone parent (right) 
        displayTree(tree.right_parent, newPrefix, true)
    end
end

-- Helper function to determine if a node should be displayed
function shouldDisplayNode(tree)
    if not tree then return false end
    
    -- Always show nodes that need breeding (have parents)
    if tree.left_parent or tree.right_parent then
        return true
    end
    
    -- Always show leaf nodes - they represent essential breeding components
    -- Even if they don't need drones, they might be needed as princesses
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
    local mods = config.mod_list or {}
    local current_filter = nil
    local filtered_bees = available_bees

    mod_counts = {}
    for _, mod in ipairs(mods) do
        mod_counts[mod] = 0
    end

    for _, species in ipairs(available_bees) do
        local mod = mutations[species] and mutations[species].mod
        if mod and mod_counts[mod] then
            mod_counts[mod] = mod_counts[mod] + 1
        end
    end

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
                print("No matches found. Press anything...")
                io.read()
            end
        else
            local choice = tonumber(input)

            if choice == 0 then
                return nil
            elseif choice and choice >= 1 and choice <= #filtered_bees then
                return filtered_bees[choice]
            else
                print("Invalid choice. Press anything to continue...")
                io.read()
            end
        end
    end
end

-- GUI state variables
local gui_state = {
    target = "",
    current_species = "",
    step_type = "", -- "breeding", "accumulation", "complete"
    current_step = 0,
    total_steps = 0,
    inventory_status = "",
    errors = "",
    status = "Running", -- "Running", "Paused", "Error", "Complete"
    progress = ""
}

-- Error handling and control state
local control_state = {
    paused = false,
    error_state = false,
    last_error = "",
    abort_requested = false,
    validation_required = false
}

--- Helper function for concise GUI updates
--- @param progress string|nil Progress description text
--- @param step_type string|nil Current step type
--- @param status string|nil Overall status
--- @param errors string|nil Error message text
--- @param current_species string|nil Current species being processed
local function updateGUI(progress, step_type, status, errors, current_species)
    local args = {}
    if progress then args.progress = progress end
    if step_type then args.step_type = step_type end
    if status then args.status = status end
    if errors then args.errors = errors end
    if current_species then args.current_species = current_species end
    drawGUI(args)
end

--- Handle error with user intervention
--- @param error_message string The error message to display
--- @param validation_func function|nil Function to validate fix (returns boolean, string)
function handleError(error_message, validation_func)
    control_state.error_state = true
    control_state.last_error = error_message
    control_state.validation_required = validation_func ~= nil
    
    gui_state.errors = error_message
    gui_state.status = "Error"
    drawGUI({errors = error_message, status = "Error"})
    
    -- Update status indicators
    updateStatusIndicators("error", "ERROR: " .. error_message, gui_state.current_species)
    
    computer.beep(1000, 0.5) -- Error beep
    computer.beep(800, 0.3)
    
    -- Wait for user intervention
    waitForUserAction(validation_func)
end

--- Wait for user to resume or abort after error/pause
--- @param validation_func function|nil Function to validate fix before resuming
function waitForUserAction(validation_func)
    drawGUI({progress = "PAUSED - Press [R]esume, [A]bort, or [Q]uit", status = "Paused"})
    
    while control_state.error_state or control_state.paused do
        -- Check for keyboard input (non-blocking)
        local eventType, address, char, code = event.pull(0.1, "key_down")
        
        if eventType then
            local key = string.char(char):lower()
            
            if key == 'r' then
                -- Resume request
                if control_state.error_state and validation_func then
                    -- Validate that the issue is fixed
                    drawGUI({progress = "Validating fix...", status = "Validating"})
                    local success, error_msg = validation_func()
                    
                    if success then
                        -- Issue fixed, can resume
                        control_state.error_state = false
                        control_state.paused = false
                        gui_state.errors = ""
                        gui_state.status = "Running"
                        drawGUI({progress = "Resuming...", errors = "", status = "Running"})
                        updateStatusIndicators("working", "Resumed: Issue fixed", gui_state.current_species)
                        computer.beep(600, 0.2) -- Success beep
                        os.sleep(1)
                        break
                    else
                        -- Issue not fixed, stay paused
                        handleError(error_msg or control_state.last_error, validation_func)
                    end
                else
                    -- Simple resume (no validation required)
                    control_state.error_state = false
                    control_state.paused = false
                    gui_state.errors = ""
                    gui_state.status = "Running"
                    drawGUI({progress = "Resuming...", errors = "", status = "Running"})
                    computer.beep(600, 0.2)
                    os.sleep(1)
                    break
                end
                
            elseif key == 'a' or key == 'q' then
                -- Abort request
                control_state.abort_requested = true
                control_state.error_state = false
                control_state.paused = false
                gui_state.status = "Aborted"
                drawGUI({progress = "Operation aborted by user", status = "Aborted"})
                updateStatusIndicators("aborted", "Operation aborted by user", gui_state.current_species)
                computer.beep(400, 0.8) -- Abort beep
                break
                
            elseif key == 'p' and not control_state.error_state then
                -- Manual pause toggle
                control_state.paused = not control_state.paused
                if control_state.paused then
                    gui_state.status = "Paused"
                    drawGUI({progress = "Manually paused", status = "Paused"})
                else
                    gui_state.status = "Running"
                    drawGUI({progress = "Resuming...", status = "Running"})
                    break
                end
            end
        end
        
        os.sleep(0.1) -- Small delay to prevent CPU spinning
    end
end

--- Check if operation should continue (handles pause/abort)
--- @return boolean shouldContinue True if operation should continue
--- @return string|nil errorMessage Error message if operation should stop
function checkContinue()
    if control_state.abort_requested then
        return false, "Operation aborted by user"
    end
    
    -- Check for manual pause/abort keypress (non-blocking)
    local eventType, address, char, code = event.pull(0, "key_down")
    if eventType then
        local key = string.char(char):lower()
        if key == 'p' then
            control_state.paused = true
            waitForUserAction()
        elseif key == 'a' or key == 'q' then
            control_state.abort_requested = true
            return false, "Operation aborted by user"
        end
    end
    
    if control_state.paused and not control_state.error_state then
        waitForUserAction()
    end
    
    return not control_state.abort_requested, nil
end

--- Validate that beebee gun is available
--- @return boolean success True if beebee gun is found
--- @return string|nil errorMessage Error message if validation failed
function validateBeebeeGun()
    local hasGun, gunName = checkBeebeeGun()
    if hasGun then
        return true, nil
    else
        return false, "Beebee gun still not found in Mechanical User slot " .. config.beebee_gun_slot
    end
end

--- Validate that a specific bee type is available
--- @param species string The bee species name
--- @param bee_type string Type of bee ("princess" or "drone")
--- @return boolean success True if bee is found
--- @return string|nil errorMessage Error message if validation failed
function validateBeeAvailability(species, bee_type)
    local location = findBeeInInventory(species, bee_type)
    if location then
        return true, nil
    else
        return false, "Could not find " .. species .. " " .. bee_type .. " in any inventory"
    end
end

function validateMutatronOutput()
    local stack = inventory_controller.getStackInSlot(config.mutatron_side, config.mutatron_output_slot)
    if stack then
        return true, nil
    else
        return false, "No queen produced by mutatron - check power and materials"
    end
end

function validateApiarySpace()
    local stack = inventory_controller.getStackInSlot(config.apiary_side, config.apiary_input_slot)
    if not stack then
        return true, nil
    else
        return false, "Apiary input slot is blocked - clear slot " .. config.apiary_input_slot
    end
end

--- Set colored lamp status
--- @param color number RGB color value (0x000000 to 0xFFFFFF)
function setStatusLamp(color)
    if config.use_status_lamp and coloredlamp then
        coloredlamp.setLampColor(color)
    end
end

--- Send chat notification message
--- @param message string The message to send
--- @param player string|nil Specific player to send to (nil for broadcast)
function sendChatNotification(message, player)
    if config.use_chat_notifications and chat_box then
        player = player or config.chat_player_name
        if player then
            chat_box.tell(player, "[HiveMind] " .. message)
        else
            chat_box.say("[HiveMind] " .. message)
        end
    end
end

-- Status indicator color scheme
local status_colors = {
    idle = 0xFFFFFF,      -- White - idle/ready
    working = 0x00FF00,   -- Green - working normally
    waiting = 0xFFFF00,   -- Yellow - waiting for resources
    error = 0xFF0000,     -- Red - error state
    paused = 0xFF8800,    -- Orange - paused
    complete = 0x0000FF,  -- Blue - task complete
    aborted = 0x800080    -- Purple - aborted
}

--- Update status indicators based on current state
--- @param state string Status state key (idle, working, waiting, error, paused, complete, aborted)
--- @param message string|nil Chat message to send (nil for lamp-only update)
--- @param species string|nil Current species being processed
function updateStatusIndicators(state, message, species)
    local color = status_colors[state] or status_colors.idle
    setStatusLamp(color)
    
    if message then
        local chat_message = message
        if species then
            chat_message = chat_message .. " (" .. species .. ")"
        end
        sendChatNotification(chat_message)
    end
end

--- Initialize the GUI display
function initGUI()
    local width, height = gpu.getResolution()
    
    -- Clear screen and set up GUI layout
    term.clear()
    gpu.setResolution(80, 25)
    gpu.setBackground(0x000000)
    gpu.setForeground(0xFFFFFF)
    
    -- Draw static GUI frame
    drawGUIFrame()
end

function drawGUIFrame()
    -- Draw top border
    gpu.set(1, 1, "╔" .. string.rep("═", 78) .. "╗")
    
    -- Draw section separators
    gpu.set(1, 3, "╠" .. string.rep("═", 78) .. "╣")
    gpu.set(1, 6, "╠" .. string.rep("═", 78) .. "╣")
    gpu.set(1, 9, "╠" .. string.rep("═", 78) .. "╣")
    gpu.set(1, 12, "╠" .. string.rep("═", 78) .. "╣")
    gpu.set(1, 15, "╠" .. string.rep("═", 78) .. "╣")
    gpu.set(1, 18, "╠" .. string.rep("═", 78) .. "╣")
    
    -- Draw bottom border
    gpu.set(1, 25, "╚" .. string.rep("═", 78) .. "╝")
    
    -- Draw side borders
    for i = 2, 24 do
        gpu.set(1, i, "║")
        gpu.set(80, i, "║")
    end
    
    -- Draw section labels
    gpu.set(3, 2, "Target:")
    gpu.set(3, 4, "Current Step:")
    gpu.set(3, 7, "Progress:")
    gpu.set(3, 10, "Inventory:")
    gpu.set(3, 13, "Status:")
    gpu.set(3, 16, "Errors/Warnings:")
    gpu.set(3, 19, "Controls: [P]ause [R]esume [A]bort [Q]uit")
end

--- Draw GUI elements with current status
--- @param args table<string, any> GUI arguments table
--- @param args.current_species string|nil Current bee species being processed
--- @param args.step_type string|nil Current step type (Loading, Breeding, Processing, etc.)
--- @param args.progress string|nil Progress description text
--- @param args.current_step number|nil Current step number
--- @param args.total_steps number|nil Total number of steps
--- @param args.inventory_status string|nil Inventory status text
--- @param args.errors string|nil Error message text
--- @param args.status string|nil Overall status (Working, Error, Paused, etc.)
function drawGUI(args)
    -- Update GUI state
    if args.current_species then gui_state.current_species = args.current_species end
    if args.step_type then gui_state.step_type = args.step_type end
    if args.progress then gui_state.progress = args.progress end
    if args.current_step then gui_state.current_step = args.current_step end
    if args.total_steps then gui_state.total_steps = args.total_steps end
    if args.inventory_status then gui_state.inventory_status = args.inventory_status end
    if args.errors then gui_state.errors = args.errors end
    if args.status then gui_state.status = args.status end
    
    -- Clear content areas (keep borders)
    for i = 2, 24 do
        if i ~= 3 and i ~= 6 and i ~= 9 and i ~= 12 and i ~= 15 and i ~= 18 then
            gpu.set(2, i, string.rep(" ", 78))
        end
    end
    
    -- Draw target
    gpu.set(12, 2, gui_state.current_species or "")
    
    -- Draw current step info
    local step_info = ""
    if gui_state.step_type then
        if gui_state.step_type:lower() == "breeding" then
            step_info = "Breeding " .. (gui_state.current_species or "")
        elseif gui_state.step_type:lower() == "accumulation" then
            step_info = "Accumulating " .. (gui_state.current_species or "") .. " drones"
        elseif gui_state.step_type:lower() == "complete" then
            step_info = "Breeding Complete!"
        else
            step_info = gui_state.step_type .. ": " .. (gui_state.current_species or "")
        end
    else
        step_info = gui_state.current_species or ""
    end
    gpu.set(16, 4, step_info)
    
    -- Draw sub-step progress
    gpu.set(3, 5, gui_state.progress)
    
    -- Draw progress bar
    local progress_width = 70
    local filled = 0
    if gui_state.total_steps > 0 then
        filled = math.floor((gui_state.current_step / gui_state.total_steps) * progress_width)
    end
    
    local progress_bar = "[" .. string.rep("█", filled) .. string.rep("░", progress_width - filled) .. "]"
    gpu.set(3, 8, progress_bar)
    
    -- Draw step counter
    local step_text = string.format("Step %d/%d", gui_state.current_step, gui_state.total_steps)
    gpu.set(76 - string.len(step_text), 8, step_text)
    
    -- Draw inventory status
    gpu.set(3, 11, gui_state.inventory_status)
    
    -- Draw status with color
    local status_color = 0xFFFFFF -- White
    if gui_state.status == "Running" then
        status_color = 0x00FF00 -- Green
    elseif gui_state.status == "Paused" then
        status_color = 0xFFFF00 -- Yellow
    elseif gui_state.status == "Error" then
        status_color = 0xFF0000 -- Red
    elseif gui_state.status == "Complete" then
        status_color = 0x00FFFF -- Cyan
    end
    
    gpu.setForeground(status_color)
    gpu.set(11, 13, gui_state.status)
    gpu.setForeground(0xFFFFFF)
    
    -- Draw errors/warnings
    if gui_state.errors and gui_state.errors ~= "" then
        gpu.setForeground(0xFF0000) -- Red for errors
        -- Word wrap errors to fit in the area
        local error_lines = wrapText(gui_state.errors, 76)
        for i, line in ipairs(error_lines) do
            if i <= 2 then -- Only show first 2 lines
                gpu.set(3, 16 + i, line)
            end
        end
        gpu.setForeground(0xFFFFFF)
    end
end

-- Helper function to wrap text to specified width
function wrapText(text, width)
    local lines = {}
    local current_line = ""
    
    for word in text:gmatch("%S+") do
        if string.len(current_line .. " " .. word) <= width then
            if current_line == "" then
                current_line = word
            else
                current_line = current_line .. " " .. word
            end
        else
            if current_line ~= "" then
                table.insert(lines, current_line)
            end
            current_line = word
        end
    end
    
    if current_line ~= "" then
        table.insert(lines, current_line)
    end
    
    return lines
end

-- Set target for GUI display
function setGUITarget(target)
    gui_state.target = target
end

-- Execute breeding process with new tree-based approach
function executeBreeding(target, breeding_plan)
    if not breeding_plan or breeding_plan.total_steps == 0 then
        print("No breeding required - target already available!")
        return true
    end
    
    -- Initialize GUI and status indicators
    initGUI()
    setGUITarget(target)
    updateStatusIndicators("working", "Starting breeding sequence", target)
    
    -- Initial GUI state
    drawGUI({
        step_type = "breeding",
        current_species = "Initializing...",
        progress = "Starting breeding process",
        current_step = 0,
        total_steps = breeding_plan.total_steps,
        inventory_status = "Checking inventory...",
        status = "Running"
    })
    
    local hasAPI = checkGendustryAPI()
    
    -- Execute the breeding tree
    gui_state.current_step = 0
    local success = executeBreedingTree(breeding_plan.tree, breeding_plan.drone_requirements, hasAPI, breeding_plan.total_steps)
    
    if success then
        drawGUI({
            step_type = "complete",
            current_species = target,
            progress = "Breeding completed successfully!",
            current_step = breeding_plan.total_steps,
            status = "Complete"
        })
        computer.beep(1000, 0.5)
        
        -- Final inventory scan
        scanInventory()
    else
        drawGUI({
            step_type = "complete",
            current_species = target,
            progress = "Breeding failed!",
            errors = "Could not complete breeding strategy",
            status = "Error"
        })
    end
    
    return success
end

-- Execute breeding tree recursively (depth-first, post-order)
function executeBreedingTree(tree, drone_requirements, hasAPI, total_steps)
    if not tree then return true end
    
    -- Post-order: execute children first, then current node
    
    -- Execute left subtree (princess lineage)
    if tree.left_parent then
        local success = executeBreedingTree(tree.left_parent, drone_requirements, hasAPI, total_steps)
        if not success then return false end
    end
    
    -- Execute right subtree (drone lineage)
    if tree.right_parent then
        local success = executeBreedingTree(tree.right_parent, drone_requirements, hasAPI, total_steps)
        if not success then return false end
    end
    
    -- Execute current node if breeding is required
    if tree.left_parent or tree.right_parent then
        local parents = mutations[tree.species].parents
        local princess_parent = parents[1]
        local drone_parent = parents[2]
        
        drawGUI({
            current_species = tree.species,
            step_type = "breeding",
            progress = "Breeding: " .. princess_parent .. " + " .. drone_parent .. " -> " .. tree.species
        })
        
        -- Check if we need accumulation for the drone
        local drone_req = drone_requirements[drone_parent]
        if drone_req and drone_req.needed and drone_req.available and drone_req.needed > drone_req.available then
            local shortage = drone_req.needed - drone_req.available
            local total_needed = shortage + (config.add_drone_count or 1)

            for cycle = 1, total_needed do
                drawGUI({
                    current_species = drone_parent,
                    step_type = "accumulation",
                    progress = "Accumulation cycle " .. cycle .. "/" .. total_needed .. " for " .. drone_parent
                })
                
                local success = executeAccumulationCycle(drone_parent)
                if not success then
                    drawGUI({
                        errors = "Accumulation cycle failed for " .. drone_parent
                    })
                end
                
                -- TODO: if we get multiple drones per cycle, we should update available count accordingly
                -- Update available count
                if drone_req.available then
                    drone_req.available = drone_req.available + 1
                end
            end
        end
        
        -- Execute the actual breeding step
        local success = executeSingleBreedingStep(princess_parent, drone_parent, tree.species, hasAPI)
        if not success then
            drawGUI({
                current_species = tree.species,
                step_type = "breeding",
                progress = "FAILED: " .. tree.species,
                errors = "Could not complete breeding step for " .. tree.species,
                status = "Error"
            })
            return false
        end
        
        -- Update step counter and GUI status
        gui_state.current_step = gui_state.current_step + 1
        drawGUI({
            current_species = tree.species,
            step_type = "breeding",
            progress = "Completed " .. tree.species,
            current_step = gui_state.current_step,
            total_steps = total_steps
        })
    end
    
    -- Final completion status if this is the top-level call
    if tree and tree.species == gui_state.target then
        updateStatusIndicators("complete", "All breeding completed successfully!", tree.species)
    end
    
    return true
end

--- Execute a single breeding step (mutatron + apiary cycle)
--- @param princess_species string Species name for princess/queen
--- @param drone_species string Species name for drone
--- @param target_species string Expected output species name
--- @param hasAPI boolean Whether Gendustry API is available
--- @return boolean success True if breeding step completed successfully
--- @return string|nil errorMessage Error message if step failed
function executeSingleBreedingStep(princess_species, drone_species, target_species, hasAPI)
    -- Check if we should continue
    local should_continue, abort_msg = checkContinue()
    if not should_continue then
        return false, abort_msg
    end
    
    -- Phase 1: Load Mutatron
    drawGUI({current_species = target_species, step_type = "Loading", progress = "Loading: " .. princess_species .. " + " .. drone_species, status = "Working"})
    -- Only update lamp status, no chat spam
    setStatusLamp(status_colors.working)
    local load_success, load_msg = loadMutatron(princess_species, drone_species)
    if not load_success then
        return false, load_msg
    end
    
    -- Phase 2: Activate Mutatron
    if hasAPI then
        local api_success = useGendustryAPI(princess_species, drone_species, target_species)
        if not api_success then
            activateMechanicalUser()
        end
    else
        activateMechanicalUser()
    end
    
    -- Phase 3: Move Queen to Apiary
    local queen_success = moveQueenToApiary()
    if not queen_success then
        drawGUI({step_type = "Breeding", progress = "Moving queen failed", errors = "Could not move queen to apiary", status = "Error"})
        return false
    end
    
    -- Phase 4: Process in Apiary
    activateMechanicalUser()
    for t = 1, config.apiary_wait_time do
        -- Check for user input every 10 seconds
        if t % 10 == 0 then
            drawGUI({step_type = "Processing", progress = (config.apiary_wait_time - t) .. " seconds remaining", status = "Working"})
            local should_continue, abort_msg = checkContinue()
            if not should_continue then
                return false, abort_msg
            end
        end
        os.sleep(1)
    end
    
    -- Phase 5: Collect Products
    local collect_success = collectApiaryProducts()
    if not collect_success then
        drawGUI({step_type = "Collecting", progress = "Collection warning", errors = "No products collected", status = "Warning"})
    end
    
    drawGUI({step_type = "Complete", progress = "Breeding step complete", status = "Completed"})
    -- Only update lamp status, no chat spam
    setStatusLamp(status_colors.working)
    computer.beep(800, 0.2)

    return true
end

--- Execute accumulation cycle (apiary-only to get more drones)
--- @param species string The species to accumulate drones for
--- @return boolean success True if accumulation cycle completed successfully
--- @return string|nil errorMessage Error message if cycle failed
function executeAccumulationCycle(species)
    drawGUI({current_species = species, step_type = "Accumulation", progress = "Running accumulation cycle", status = "Working"})
    
    -- Find existing queen of this species across all inventories
    local queen_side, queen_slot, queen_stack = findItemAnyInventory(species .. ".*queen")
    if not queen_slot then
        drawGUI({progress = "Accumulation failed", errors = "No " .. species .. " queen found", status = "Error"})
        return false
    end
    
    -- Move queen to apiary
    local success = moveItem(queen_side, queen_slot, config.apiary_side, config.apiary_input_slot, 1)
    if not success then
        drawGUI({progress = "Move failed", errors = "Failed to move queen to apiary", status = "Error"})
        return false
    end
    
    -- Activate apiary
    activateMechanicalUser()
    
    -- Wait for processing
    os.sleep(config.apiary_wait_time)
    
    -- Collect products
    collectApiaryProducts()
    
    drawGUI({progress = "Accumulation cycle complete", status = "Completed"})

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
        
        -- Check if plan failed due to critical errors
        if breeding_plan and breeding_plan.plan_failed then
            print("Press anything to continue...")
            io.read()
        else
            while true do
                setupDisplay()
                local success = displayBreedingPlan(target, breeding_plan)
                
                if not success then
                    print("Press anything to continue...")
                    io.read()
                    break
                end
                
                local choice = getConfirmation()
                
                if choice == 1 then
                    executeBreeding(target, breeding_plan)
                    print("Press anything to continue...")
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
                    print("Invalid choice. Press anything to continue...")
                    io.read()
                end
            end
        end
    end
end

-- Export functions for testing or run main program
if ... then
    -- Module is being required, export functions for testing
    return {
        -- Planning functions
        calculateBreedingPath = calculateBreedingPath,
        buildBreedingTree = buildBreedingTree,
        findStartingPrincesses = findStartingPrincesses, 
        calculateDroneRequirements = calculateDroneRequirements,
        displayTree = displayTree,
        
        -- Execution functions
        executeBreedingTree = executeBreedingTree,
        executeSingleBreedingStep = executeSingleBreedingStep,
        executeAccumulationCycle = executeAccumulationCycle,
        
        -- Utility functions
        getSideName = getSideName,
        hasSpeciesPrincess = hasSpeciesPrincess,
        hasSpeciesDrone = hasSpeciesDrone,
        
        -- Status functions (for integration tests)
        updateStatusIndicators = updateStatusIndicators,
        checkBeebeeGun = checkBeebeeGun,
        
        -- Data
        mutations = mutations,
        config = config
    }
else
    -- Module is being executed directly, run the main program
    main()
end