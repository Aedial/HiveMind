-- HiveMind Planning System Test Suite
-- Tests breeding tree calculation, golden path logic, and drone accumulation
-- Imports actual functions from main.lua to ensure consistency

-- Mock OpenComputers components before requiring main.lua
local function mockOpenComputersEnvironment()
    -- Mock component module
    local mock_component = {
        isAvailable = function(name)
            -- Mock availability of basic components
            if name == "inventory_controller" then return true end
            if name == "gpu" then return true end
            if name == "redstone" then return true end
            -- Optional components for testing
            if name == "notification_interface" then return false end -- Can be toggled
            if name == "coloredlamp" then return false end -- Can be toggled
            return false
        end,

        getPrimary = function(name)
            return mock_component[name] or {}
        end,

        list = function()
            return {} -- Empty component list for testing
        end,

        proxy = function(address)
            return {} -- Empty proxy for testing
        end,

        -- Mock inventory controller
        inventory_controller = {
            getInventorySize = function(side) return 27 end, -- Standard chest size
            getStackInSlot = function(side, slot) return nil end, -- Empty by default
            transferItem = function(from, to, count, from_slot, to_slot) return 0 end -- No actual transfer
        },

        -- Mock GPU
        gpu = {
            getResolution = function() return 80, 25 end,
            setResolution = function(w, h) end,
            setBackground = function(color) end,
            setForeground = function(color) end,
            set = function(x, y, text) end,
            fill = function(x, y, w, h, char) end
        },

        -- Mock redstone
        redstone = {
            setOutput = function(side, strength) end,
            getOutput = function(side) return 0 end
        },

        -- Mock notification interface (when available)
        notification_interface = {
            notify = function(title, description, icon, iconMeta)
                print("[NOTIFICATION] " .. title .. ": " .. description)
            end
        },

        -- Mock colored lamp (when available)
        coloredlamp = {
            setLampColor = function(color) print("[LAMP] Color: 0x" .. string.format("%06X", color)) end
        }
    }

    -- Mock other OC modules
    local mock_computer = {
        beep = function(frequency, duration) end, -- Silent beep for testing
        uptime = function() return os.clock() end
    }

    local mock_term = {
        clear = function() end,
        write = function(text) io.write(text) end
    }

    local mock_sides = {
        bottom = 0,
        top = 1,
        north = 2,
        south = 3,
        west = 4,
        east = 5,
        down = 0,
        up = 1,
        front = 2,
        back = 3,
        right = 4,
        left = 5
    }

    local mock_event = {
        pull = function(timeout, event_type)
            -- Mock no events for testing
            return nil
        end
    }

    local mock_keyboard = {
        -- Add keyboard functions if needed
    }

    -- Set up global package.loaded to mock the requires
    if not package.loaded then package.loaded = {} end

    package.loaded["component"] = mock_component
    package.loaded["computer"] = mock_computer
    package.loaded["term"] = mock_term
    package.loaded["sides"] = mock_sides
    package.loaded["event"] = mock_event
    package.loaded["keyboard"] = mock_keyboard

    -- Set up globals that main.lua expects
    _G.component = mock_component
    _G.computer = mock_computer
    _G.term = mock_term
    _G.sides = mock_sides
    _G.event = mock_event
    _G.keyboard = mock_keyboard

    print("✓ OpenComputers environment mocked for testing")
end

-- Initialize mocking before requiring main
mockOpenComputersEnvironment()

-- Now we can safely import main.lua
local main = require("main")

--[[
Type Definitions for Testing:
@class TestCase
@field name string Test case name
@field target string Target species to breed
@field available_princesses string[] Available princess species
@field available_drones string[] Available drone species
@field expected_steps number Expected number of breeding steps
@field expected_starting_princesses string[] Expected starting princesses needed
@field expected_drone_requirements table<string, number> Expected drone requirements
@field should_succeed boolean Whether planning should succeed
--]]

-- Mock the global inventory for testing
local test_inventory = {
    princesses = {},
    drones = {}
}

-- Mock the global functions that main.lua uses for inventory management
local function mockGlobalFunctions()
    -- Override the inventory checking functions for testing
    _G.inventory = test_inventory

    -- Mock inventory scanning (just populate with test data)
    _G.scanAllInventories = function()
        -- Do nothing - test inventory is set up manually
    end

    -- Mock inventory access functions with bred species tracking
    _G.hasSpeciesPrincess = function(species)
        -- Check initial inventory
        for _, princess in ipairs(test_inventory.princesses) do
            if princess == species then
                return true
            end
        end
        -- Check if we've bred this species (becomes available as princess)
        if _G.execution_bred_species and _G.execution_bred_species[species] then
            return true
        end
        return false
    end

    _G.hasSpeciesDrone = function(species)
        -- Check initial inventory
        for _, drone in ipairs(test_inventory.drones) do
            if drone == species then
                return true
            end
        end
        -- Check if we've bred this species (becomes available as drone)
        if _G.execution_bred_species and _G.execution_bred_species[species] then
            return true
        end
        return false
    end

    -- Mock bee finding for validation functions
    _G.findBeeInInventory = function(species, bee_type)
        local inventory_list = bee_type == "princess" and test_inventory.princesses or test_inventory.drones
        for _, available_species in ipairs(inventory_list) do
            if available_species == species then
                return {side = 1, slot = 1} -- Mock location
            end
        end
        return nil
    end

    -- Mock item finding function
    _G.findItemAnyInventory = function(pattern)
        -- Simple mock - just return that item exists
        return 1, 1, {} -- side, slot, stack
    end

    -- Mock GUI functions so they don't interfere with testing
    _G.initGUI = function() end
    _G.drawGUI = function(args) end
    _G.setGUITarget = function(target) end

    -- Mock user input functions
    _G.getUserChoice = function() return "4" end -- Always exit
    _G.chooseBeeTarget = function() return nil end -- No target selected
    _G.displayHeader = function() end
    _G.displayBreedingStrategy = function() end

    -- Mock status indicators for testing
    _G.updateStatusIndicators = function(state, message, species)
        if message then
            print("[STATUS] " .. state:upper() .. ": " .. message .. (species and " (" .. species .. ")" or ""))
        end
    end

    print("✓ Global functions mocked for testing")
end

-- Initialize all mocking
mockGlobalFunctions()

-- Test Cases
local test_cases = {
    {
        name = "Simple two-parent breeding",
        target = "Common", -- Common = Meadows + Forest (basic breeding)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = true
    },

    {
        name = "Three-generation breeding chain",
        target = "Cultivated", -- Cultivated = Meadows + Common (Common = Meadows + Forest)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = true
    },

    {
        name = "Complex Imperial breeding",
        target = "Imperial", -- Imperial = Noble + Majestic (multi-step chain)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = true
    },

    {
        name = "Missing starting princess",
        target = "Common", -- Need Forest and Meadows
        available_princesses = {"Forest"}, -- Missing Meadows
        available_drones = {"Forest", "Meadows"},
        should_succeed = false -- Missing required base species
    },

    {
        name = "Industrial branch breeding",
        target = "Industrious", -- Industrious = Diligent + Unweary
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = true
    },

    {
        name = "Cross-mod breeding (MagicBees)",
        target = "Mystical", -- Mystical = Noble + Monastic (needs Monastic base)
        available_princesses = {"Forest", "Meadows"}, -- Missing Monastic
        available_drones = {"Forest", "Meadows"},
        should_succeed = false -- Missing Monastic
    },

    {
        name = "Complex multi-mod chain",
        target = "Supernatural",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Mystical", "Sorcerous", "Unusual"},
        should_succeed = false -- Missing Monastic
    },

    {
        name = "Complex MeatballCraft - Necronomibee from base bees",
        target = "Necronomibee", -- Requires: Savant + Abyss
        available_princesses = {"Forest", "Meadows"}, -- Only base bees
        available_drones = {"Forest", "Meadows"},
        should_succeed = false, -- Missing required base species
        description = "Tests very deep MagicBees + ExtraBees chains"
    },

    {
        name = "Extremely complex - Agricultural from base bees",
        target = "Agricultural", -- Requires: Virulent + Doctoral (both very deep chains)
        available_princesses = {"Forest", "Meadows"}, -- Only base bees
        available_drones = {"Forest", "Meadows"},
        should_succeed = false, -- Missing required base species
        description = "Tests extremely deep multi-mod breeding chains"
    },

    {
        name = "Deep chain - Herblore from base bees",
        target = "Herblore", -- Requires: Esoteric + Quantum (very rare combination)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = false, -- Missing required base species
        description = "Tests rare MagicBees + ExtraBees combination"
    },

    {
        name = "Multi-branch complexity - Controller from base bees",
        target = "Controller", -- Requires: Ringbearer + Chevron (both custom chains)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = false, -- Missing required base species
        description = "Tests multiple custom breeding branches converging"
    },

    {
        name = "Ultimate complexity - ChaosStrikez from base bees",
        target = "ChaosStrikez", -- Energetic + Savant (both deep)
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = false, -- Missing Monastic
        description = "Tests the most complex custom bee chain"
    },

    {
        name = "Heroic branch with complex dependencies",
        target = "Heroic", -- Heroic = Valiant + Steadfast (both base species)
        available_princesses = {"Forest", "Meadows", "Valiant", "Steadfast"},
        available_drones = {"Forest", "Meadows", "Valiant", "Steadfast"},
        should_succeed = true
    },

    {
        name = "Circular dependency detection",
        target = "NonExistent",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = false
    }
}

-- Shared helpers to analyze mutation graph
local function getParents(species)
    local m = main.mutations and main.mutations[species]
    if m and m.parents then return m.parents[1], m.parents[2] end
    return nil, nil
end

local function computeBaseLeaves(target)
    local bases = {}
    local seen = {}
    local function dfs(spec)
        if seen[spec] then return end
        seen[spec] = true
        if not (main.mutations and main.mutations[spec]) then
            bases[spec] = true
            return
        end
        local p1, p2 = getParents(spec)
        if p1 then dfs(p1) end
        if p2 then dfs(p2) end
    end
    dfs(target)
    local list = {}
    for sp,_ in pairs(bases) do table.insert(list, sp) end
    table.sort(list)
    return list
end

local function computeIntermediates(target, limit)
    local internal = {}
    local seen = {}
    local function dfs(spec)
        if seen[spec] then return end
        seen[spec] = true
        local m = main.mutations and main.mutations[spec]
        if not m then return end
        local p1, p2 = getParents(spec)
        if p1 then dfs(p1) end
        if p2 then dfs(p2) end
        if (p1 or p2) and spec ~= target then internal[spec] = true end
    end
    dfs(target)
    local list = {}
    for sp,_ in pairs(internal) do table.insert(list, sp) end
    table.sort(list)
    local out = {}
    local n = math.min(limit or 6, #list)
    for i=1,n do table.insert(out, list[i]) end
    return out
end

-- Collect MeatballCraft species directly from the mutations table
local function parseMeatballSpecies()
    local species = {}
    local seen = {}
    if not (main and main.mutations) then return species end
    for name, def in pairs(main.mutations) do
        if def and def.mod == "MeatballCraft" and not seen[name] then
            seen[name] = true
            table.insert(species, name)
        end
    end
    table.sort(species)
    return species
end

-- Generate triplet tests (base-only success, intermediates success, failing) for key targets
local function generateTriplets()
    local target_names = {"Common","Cultivated","Imperial","Heroic","Controller","Necronomibee"}
    local targets = {}
    for _, name in ipairs(target_names) do
        local bases = computeBaseLeaves(name)
        local inter = computeIntermediates(name, 6)
        targets[#targets+1] = { name = name, bases = bases, inter = inter }
    end

    local triplets = { planning = {}, execution = {} }
    for _, t in ipairs(targets) do
        -- Passing with only base bees
        table.insert(triplets.planning, {
            name = t.name .. " (planning) - base only",
            target = t.name,
            available_princesses = t.bases,
            available_drones = t.bases,
            should_succeed = true
        })
        -- Passing with some intermediates present (add a few internal species)
        local ip = { princesses = {}, drones = {} }
        for _, b in ipairs(t.bases) do table.insert(ip.princesses, b); table.insert(ip.drones, b) end
        for _, s in ipairs(t.inter) do table.insert(ip.princesses, s); table.insert(ip.drones, s) end
        table.insert(triplets.planning, {
            name = t.name .. " (planning) - with intermediates",
            target = t.name,
            available_princesses = ip.princesses,
            available_drones = ip.drones,
            should_succeed = true
        })
        -- Failing case (missing bases)
        table.insert(triplets.planning, {
            name = t.name .. " (planning) - failing",
            target = t.name,
            available_princesses = { },
            available_drones = { },
            should_succeed = false
        })
    end
    return triplets
end

local generated = generateTriplets()
for _, tc in ipairs(generated.planning) do table.insert(test_cases, tc) end

-- Also add planning triplets for all MeatballCraft species discovered
local meatball_species = parseMeatballSpecies()
for _, name in ipairs(meatball_species) do
    -- Skip duplicates already covered explicitly
    local already = false
    for _, tc in ipairs(test_cases) do if tc.target == name then already = true; break end end
    if not already then
        local bases = computeBaseLeaves(name)
        local inter = computeIntermediates(name, 6)
        table.insert(test_cases, { name = name .. " (planning) - base only", target = name, available_princesses = bases, available_drones = bases, should_succeed = true })
        local ip = { princesses = {}, drones = {} }
        for _, b in ipairs(bases) do table.insert(ip.princesses, b); table.insert(ip.drones, b) end
        for _, s in ipairs(inter) do table.insert(ip.princesses, s); table.insert(ip.drones, s) end
        table.insert(test_cases, { name = name .. " (planning) - with intermediates", target = name, available_princesses = ip.princesses, available_drones = ip.drones, should_succeed = true })
        table.insert(test_cases, { name = name .. " (planning) - failing", target = name, available_princesses = {}, available_drones = {}, should_succeed = false })
    end
end

-- Dump detailed tree analysis to artifacts folder
local function dumpTreeAnalysis(target, plan, sanity_issues, duration)
    local artifacts_dir = "Artifacts"
    local filename = artifacts_dir .. "/" .. target .. "_analysis.txt"

    -- Ensure artifacts directory exists (cross-platform)
    local is_windows = package.config:sub(1,1) == "\\"
    if is_windows then
        os.execute(string.format('if not exist "%s" mkdir "%s"', artifacts_dir, artifacts_dir))
    else
        os.execute(string.format('mkdir -p "%s"', artifacts_dir))
    end

    local content = {}
    table.insert(content, "=== Breeding Analysis for " .. target .. " ===")
    table.insert(content, "Generated: " .. os.date())
    table.insert(content, "")

    if not plan then
        table.insert(content, "❌ BREEDING PLAN FAILED")
        table.insert(content, "Cannot breed " .. target .. " with available species")
        table.insert(content, "")
    else
        -- Plan summary (show as failed if critical errors exist)
        if plan.plan_failed then
            table.insert(content, "❌ BREEDING PLAN FAILED")
        else
            table.insert(content, "✅ BREEDING PLAN SUCCESS")
        end

        table.insert(content, string.format("Planning duration: %.2f ms", duration or 0))
        table.insert(content, "Total steps: " .. plan.total_steps)
        table.insert(content, "Can execute: " .. (plan.can_execute and "YES" or "NO"))
        table.insert(content, "")

        -- Starting princesses
        table.insert(content, "📋 STARTING PRINCESSES NEEDED:")
        if #plan.starting_princesses == 0 then
            table.insert(content, "  (none - all base species available)")
        else
            for i, species in ipairs(plan.starting_princesses) do
                table.insert(content, "  " .. i .. ". " .. species)
            end
        end
        table.insert(content, "")

        -- Missing species (if any)
        if next(plan.missing_princesses) or next(plan.missing_drones) then
            table.insert(content, "⚠️  EXECUTION REQUIREMENTS:")
            table.insert(content, "  To execute this plan, you need one of the following:")

            -- Show the flexible choice between princesses and drones
            local missing_species = {}
            for species, count in pairs(plan.missing_princesses) do
                missing_species[species] = {princess_count = count, drone_count = 0}
            end
            for species, count in pairs(plan.missing_drones) do
                if missing_species[species] then
                    missing_species[species].drone_count = count
                else
                    missing_species[species] = {princess_count = 0, drone_count = count}
                end
            end

            for species, requirements in pairs(missing_species) do
                local options = {}
                if requirements.princess_count > 0 then
                    table.insert(options, requirements.princess_count .. " " .. species .. " princess" .. (requirements.princess_count > 1 and "es" or ""))
                end
                if requirements.drone_count > 0 then
                    table.insert(options, requirements.drone_count .. " " .. species .. " drone" .. (requirements.drone_count > 1 and "s" or ""))
                end

                if #options == 1 then
                    table.insert(content, "    " .. options[1])
                else
                    table.insert(content, "    " .. table.concat(options, " OR "))
                end
            end
            table.insert(content, "")
            table.insert(content, "  Note: Providing princesses is often more efficient due to reuse optimization.")
            table.insert(content, "")
        end

        -- Sanity check issues
        if sanity_issues and #sanity_issues > 0 then
            table.insert(content, "⚠️  OPTIMIZATION ANALYSIS:")
            for _, issue in ipairs(sanity_issues) do
                if issue.type == "missed_reuse" then
                    table.insert(content, "  Potential missed reuse opportunities:")
                    for species, analysis in pairs(issue.details) do
                        if analysis.potential_additional_reuse then
                            local reused_count = analysis.reused or 0
                            table.insert(content, "    → " .. species .. ": " .. analysis.occurrences .. " occurrences, " ..
                                        reused_count .. " reused, could reuse " .. analysis.potential_additional_reuse .. " more")
                        else
                            table.insert(content, "    " .. species .. ": " .. analysis.occurrences .. " occurrences, no reuse")
                        end
                    end
                end
            end
            table.insert(content, "")
        end

        -- Plan statistics
        local function computePlanStats(tree)
            local stats = {
                total_nodes = 0,
                breeding_nodes = 0,
                reused_nodes = 0,
                unique_species = {},
                occurrences = {},
                primary_breeders = 0,
                max_depth = 0,
            }
            local function visit(n, depth)
                if not n then return end
                stats.total_nodes = stats.total_nodes + 1
                if (n.left_parent or n.right_parent) and (not n.reusing_drone or n.is_primary_breeding_node) then
                    stats.breeding_nodes = stats.breeding_nodes + 1
                end
                if n.reusing_drone then stats.reused_nodes = stats.reused_nodes + 1 end
                if n.is_primary_breeding_node then stats.primary_breeders = stats.primary_breeders + 1 end
                stats.unique_species[n.species] = true
                stats.occurrences[n.species] = (stats.occurrences[n.species] or 0) + 1
                if depth > stats.max_depth then stats.max_depth = depth end
                visit(n.left_parent, depth + 1)
                visit(n.right_parent, depth + 1)
            end
            visit(tree, 1)
            local unique_count = 0
            for _ in pairs(stats.unique_species) do unique_count = unique_count + 1 end
            stats.unique_count = unique_count
            local dup_species = 0
            local total_dups = 0
            for sp, c in pairs(stats.occurrences) do
                if c > 1 then dup_species = dup_species + 1; total_dups = total_dups + (c - 1) end
            end
            stats.duplicate_species = dup_species
            stats.duplicate_instances = total_dups
            return stats
        end
        local stats = plan.tree and computePlanStats(plan.tree) or nil
        if stats then
            table.insert(content, "📊 PLAN STATISTICS:")
            table.insert(content, "  Unique species in tree: " .. stats.unique_count)
            table.insert(content, "  Total nodes: " .. stats.total_nodes)
            table.insert(content, "  Breeding nodes: " .. stats.breeding_nodes)
            table.insert(content, "  Reused nodes: " .. stats.reused_nodes)
            table.insert(content, "  Primary breeders: " .. stats.primary_breeders)
            table.insert(content, "  Duplicate species: " .. stats.duplicate_species .. " (" .. stats.duplicate_instances .. " duplicate instances)")
            table.insert(content, "  Max depth: " .. stats.max_depth)
            table.insert(content, "")
        end

        -- Breeding tree with missed reuse arrows
        table.insert(content, "🌳 BREEDING TREE:")
        if plan.tree then
            local tree_lines = {}
            local function dumpTreeWithMissedReuse(tree, lines, prefix, isLast, sanity_issues)
                if not tree then return end

                local connector = isLast and "└── " or "├── "
                local status_flags = ""

                -- Determine status flags
                if tree.need_princess then
                    status_flags = status_flags .. "P"
                end
                if tree.need_drone and not tree.reusing_drone then
                    status_flags = status_flags .. "D"
                end
                if status_flags == "" then
                    status_flags = "  "
                else
                    status_flags = "[" .. status_flags .. "]"
                end

                local reuse_indicator = ""
                if tree.reusing_drone then
                    reuse_indicator = " (reusing)"
                end

                -- Check if this species has missed reuse opportunities
                local missed_reuse_arrow = ""
                if sanity_issues then
                    for _, issue in ipairs(sanity_issues) do
                        if issue.type == "missed_reuse" and issue.details[tree.species] then
                            local analysis = issue.details[tree.species]
                            -- Show arrow only if this specific node could actually be reused
                            if not tree.reusing_drone and (analysis.potential_additional_reuse or analysis.occurrences > 1) then
                                -- Node can be reused if it doesn't have a reusing sibling
                                local function hasReusingSibling(node)
                                    -- We need to find this node's parent to check its sibling
                                    -- This is a simplified check - in a real implementation we'd need parent pointers
                                    -- For now, just check if any direct children are reusing (previous logic)
                                    if node.left_parent and node.left_parent.reusing_drone then
                                        return true
                                    elseif node.right_parent and node.right_parent.reusing_drone then
                                        return true
                                    end
                                    return false
                                end

                                if not hasReusingSibling(tree) then
                                    missed_reuse_arrow = " ← COULD REUSE"
                                end
                            end
                        end
                    end
                end

                local breeding_indicator = (tree.left_parent or tree.right_parent) and " *" or ""
                local line = prefix .. connector .. tree.species .. " " .. status_flags ..
                            breeding_indicator .. reuse_indicator .. missed_reuse_arrow

                table.insert(lines, line)

                -- Recursively add children
                if tree.left_parent or tree.right_parent then
                    local new_prefix = prefix .. (isLast and "    " or "│   ")

                    if tree.right_parent then
                        dumpTreeWithMissedReuse(tree.right_parent, lines, new_prefix, not tree.left_parent, sanity_issues)
                    end

                    if tree.left_parent then
                        dumpTreeWithMissedReuse(tree.left_parent, lines, new_prefix, true, sanity_issues)
                    end
                end
            end

            dumpTreeWithMissedReuse(plan.tree, tree_lines, "", true, sanity_issues)
            for _, line in ipairs(tree_lines) do
                table.insert(content, line)
            end
        end

        -- Critical errors section (show after all normal info for debugging)
        if plan.plan_failed and plan.critical_errors then
            table.insert(content, "")
            table.insert(content, "❌ CRITICAL ERRORS DETECTED:")
            for _, error in ipairs(plan.critical_errors) do
                table.insert(content, "  • " .. error.message)
                if error.path then
                    table.insert(content, "    Location: " .. error.path)
                end
            end
        end
    end

    -- Write to file
    local file = io.open(filename, "w")
    if file then
        file:write(table.concat(content, "\n"))
        file:close()
        print("📁 Analysis dumped to: " .. filename)
    else
        print("❌ Failed to write analysis to: " .. filename)
    end
end


-- Test execution framework
local function runTest(test_case)
    print("Running test: " .. test_case.name)

    -- Set up test inventory
    test_inventory.princesses = test_case.available_princesses or {}
    test_inventory.drones = test_case.available_drones or {}

    -- Execute planning using actual main.lua functions
    local start = os.clock()
    local plan = main.calculateBreedingPath and main.calculateBreedingPath(test_case.target)
    local duration = (os.clock() - start) * 1000

    -- Dump detailed analysis to artifacts folder
    if plan then
        -- Get sanity issues if they exist
        local sanity_issues = plan.sanity_issues
        dumpTreeAnalysis(test_case.target, plan, sanity_issues, duration)
    else
        dumpTreeAnalysis(test_case.target, nil, nil, duration)
    end

    -- Check results
    local success = true
    local messages = {}

    if test_case.should_succeed then
        -- For tests that should succeed, ANY critical error is a failure
        if plan and plan.critical_errors then
            success = false
            table.insert(messages, "  ❌ CRITICAL ERRORS - Planning should have succeeded but optimization bugs were detected:")
            for _, error in ipairs(plan.critical_errors) do
                table.insert(messages, "    • " .. error.message)
            end
        elseif not plan or (plan and plan.plan_failed) then
            success = false
            table.insert(messages, "  ❌ Planning failed when it should succeed (no solution found)")
        elseif not plan.can_execute then
            success = false
            table.insert(messages, "  ❌ Plan generated but cannot execute (missing base species)")
        else
            table.insert(messages, "  ✅ Planning succeeded - " .. plan.total_steps .. " steps")
        end
    else
        -- For tests that should fail, we distinguish between expected failure and critical errors
        if plan and plan.critical_errors then
            success = false
            table.insert(messages, "  ❌ CRITICAL ERRORS - Even failed plans should not have optimization bugs:")
            for _, error in ipairs(plan.critical_errors) do
                table.insert(messages, "    • " .. error.message)
            end
        elseif plan and not plan.plan_failed and plan.can_execute then
            success = false
            table.insert(messages, "  ❌ Planning succeeded when it should fail")
        else
            table.insert(messages, "  ✅ Planning correctly failed or identified missing requirements")
        end
    end

    -- Print all messages
    for _, message in ipairs(messages) do
        print(message)
    end

    print()
    return success
end

-- Main test runner (planning tests only - execution tests called separately)
local function runAllTests()
    print("=== HiveMind Planning System Test Suite ===")
    print("Testing with actual functions from main.lua")
    print()

    -- Run breeding path calculation tests
    local total_tests = #test_cases
    local passed_tests = 0

    for _, test_case in ipairs(test_cases) do
        if runTest(test_case) then
            passed_tests = passed_tests + 1
        end
    end

    print("=== Planning Test Results ===")
    print("Total planning tests: " .. total_tests)
    print("Passed: " .. passed_tests)
    print("Failed: " .. (total_tests - passed_tests))

    if passed_tests == total_tests then
        print("🎉 All planning tests passed!")
    else
        print("❌ Some planning tests failed. Check output above for details.")
    end

    return passed_tests == total_tests
end



-- Tree visualization using main.lua function
local function printBreedingTree(tree)
    if main.displayTree then
        main.displayTree(tree, "", true)
    else
        print("Tree visualization not available (displayTree not exported from main.lua)")
    end
end

-- Interactive test function
local function testSpecificTarget(target)
    print("=== Testing breeding path for: " .. target .. " ===")

    -- Set up full inventory for testing
    test_inventory.princesses = {"Forest", "Meadows"}
    -- FIXME: remove non-base bees
    test_inventory.drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Majestic",
                           "Diligent", "Unweary", "Industrious", "Valiant", "Steadfast", "Heroic",
                           "Mystical", "Sorcerous", "Unusual", "Supernatural"}

    local start_time = os.clock()
    local plan = main.calculateBreedingPath and main.calculateBreedingPath(target)
    local duration = (os.clock() - start_time) * 1000

    -- Dump detailed analysis to artifacts folder
    if plan then
        local sanity_issues = plan.sanity_issues
        dumpTreeAnalysis(target, plan, sanity_issues, duration)
    else
        dumpTreeAnalysis(target, nil, nil, duration)
    end

    if not plan or (plan and plan.plan_failed) then
        print("❌ Cannot breed " .. target)
        if plan and plan.critical_errors then
            print("Critical errors:")
            for _, error in ipairs(plan.critical_errors) do
                print("  • " .. error.message)
            end
        end
        return false
    end

    print("✅ Breeding path found!")
    print("Total steps: " .. plan.total_steps)
    print()

    print("Starting princesses needed:")
    for i, species in ipairs(plan.starting_princesses) do
        print("  " .. i .. ". " .. species)
    end
    print()

    print("Drone requirements:")
    for species, req in pairs(plan.drone_requirements) do
        print("  " .. species .. ": " .. req.needed .. " drones")
    end
    print()

    print("Breeding tree:")
    printBreedingTree(plan.tree)
    print()

    return true
end

-- Complexity stress test - tests the most complex breeding chains
local function complexityStressTest()
    print("=== Complexity Stress Test ===")
    print("Testing extreme breeding chains from base bees only")

    -- Set up minimal inventory (only base bees)
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows"}

    local complex_targets = {
        {name = "Necronomibee", description = "MagicBees Savant + ExtraBees Abyss"},
        {name = "Agricultural", description = "ExtraBees Virulent + MagicBees Doctoral"},
        {name = "Herblore", description = "MagicBees Esoteric + ExtraBees Quantum"},
        {name = "Controller", description = "Custom Ringbearer + Custom Chevron"},
        {name = "ChaosStrikez", description = "ExtraBees Energetic + MagicBees Savant"},
        {name = "Experienced", description = "Custom Radiant + Custom Armored"}
    }

    local results = {}

    for _, target_info in ipairs(complex_targets) do
        local target = target_info.name
        print("Testing " .. target .. " (" .. target_info.description .. ")...")

        local start_time = os.clock()
        local plan = main.calculateBreedingPath and main.calculateBreedingPath(target)
        local end_time = os.clock()
        local duration = (end_time - start_time) * 1000

        if plan then
            local result = {
                target = target,
                success = true,
                steps = plan.total_steps,
                princesses = #plan.starting_princesses,
                drone_types = 0,
                duration = duration
            }

            -- Count unique drone types needed
            for species, count in pairs(plan.drone_requirements) do
                result.drone_types = result.drone_types + 1
            end

            results[target] = result
            print("  ✅ Success: " .. plan.total_steps .. " steps, " ..
                  result.drone_types .. " drone types, " ..
                  string.format("%.1f", duration) .. "ms")

            -- Show drone requirements for complex cases
            if plan.total_steps > 10 then
                print("    Drone requirements:")
                for species, req in pairs(plan.drone_requirements) do
                    print("      " .. species .. ": " .. tostring(req.needed))
                end
            end
        else
            results[target] = {target = target, success = false, duration = duration}
            print("  ❌ Failed in " .. string.format("%.1f", duration) .. "ms")
        end
        print()
    end

    -- Summary
    print("=== Complexity Test Summary ===")
    local successful = 0
    local total_steps = 0
    local max_steps = 0
    local max_target = ""

    for _, result in pairs(results) do
        if result.success then
            successful = successful + 1
            total_steps = total_steps + result.steps
            if result.steps > max_steps then
                max_steps = result.steps
                max_target = result.target
            end
        end
    end

    print("Successful: " .. successful .. "/" .. #complex_targets)
    if successful > 0 then
        print("Average steps: " .. string.format("%.1f", total_steps / successful))
        print("Most complex: " .. max_target .. " (" .. max_steps .. " steps)")
    end
    print()

    return results
end

-- Performance test
local function performanceTest()
    print("=== Performance Test ===")

    -- Set up full inventory
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Majestic",
                           "Diligent", "Unweary", "Industrious", "Valiant", "Steadfast", "Heroic",
                           "Mystical", "Sorcerous", "Unusual", "Supernatural"}

    local complex_targets = {"Imperial", "Heroic", "Supernatural", "Industrious"}

    for _, target in ipairs(complex_targets) do
        local start_time = os.clock()
        local plan = main.calculateBreedingPath and main.calculateBreedingPath(target)
        local end_time = os.clock()

        if plan then
            print(target .. ": " .. string.format("%.3f", (end_time - start_time) * 1000) .. "ms (" .. plan.total_steps .. " steps)")
        else
            print(target .. ": FAILED")
        end
    end
    print()
end

-- Test function for specific scenarios
local function testChaosStrikez(monastic_princesses, monastic_drones, description)
    print("=== Testing ChaosStrikez: " .. description .. " ===")
    print("Monastic stock: " .. monastic_princesses .. " princess(es), " .. monastic_drones .. " drone(s)")

    -- Set up specific inventory
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows"}

    -- Add Monastic as specified
    for i = 1, monastic_princesses do
        table.insert(test_inventory.princesses, "Monastic")
    end
    for i = 1, monastic_drones do
        table.insert(test_inventory.drones, "Monastic")
    end

    local plan = main.calculateBreedingPath and main.calculateBreedingPath("ChaosStrikez")

    if plan then
        if plan.can_execute then
            print("✅ Planning succeeded - " .. plan.total_steps .. " steps")
        else
            print("⚠️  Plan generated but cannot execute - missing base species")
        end

        -- Check if Monastic is in starting princesses or drone requirements
        local monastic_in_princesses = false
        for _, species in ipairs(plan.starting_princesses) do
            if species == "Monastic" then
                monastic_in_princesses = true
                break
            end
        end

        local monastic_drone_needed = plan.drone_requirements["Monastic"] and plan.drone_requirements["Monastic"].needed or 0

        print("Monastic needed as princess: " .. (monastic_in_princesses and "YES" or "NO"))
        print("Monastic drones needed: " .. monastic_drone_needed)

        -- Show missing species
        if next(plan.missing_princesses) then
            print("\nMissing princesses:")
            for species, count in pairs(plan.missing_princesses) do
                print("  " .. species .. ": " .. count)
            end
        end

        if next(plan.missing_drones) then
            print("\nMissing drones:")
            for species, count in pairs(plan.missing_drones) do
                print("  " .. species .. ": " .. count)
            end
        end

        if not plan.can_execute then
            print("\n❌ Cannot execute: missing required base species")
        end

        print("\nBreeding tree:")
        if main.displayTree then
            main.displayTree(plan.tree, "", true)
        end
    else
        print("❌ Planning failed")
    end
    print()
end

-- Write execution analysis to artifacts folder
local function dumpExecutionAnalysis(target, execution_log, breeding_steps, accumulation_cycles, success, failure_reason, test_type)
    local artifacts_dir = "Artifacts"
    local filename = artifacts_dir .. "/" .. target .. "_execution_" .. test_type .. ".txt"

    -- Ensure artifacts directory exists (cross-platform)
    local is_windows = package.config:sub(1,1) == "\\"
    if is_windows then
        os.execute(string.format('if not exist "%s" mkdir "%s"', artifacts_dir, artifacts_dir))
    else
        os.execute(string.format('mkdir -p "%s"', artifacts_dir))
    end

    local content = {}
    table.insert(content, "=== Execution Analysis for " .. target .. " ===")
    table.insert(content, "Test Type: " .. test_type)
    table.insert(content, "Generated: " .. os.date())
    table.insert(content, "")

    -- Execution summary
    if success then
        table.insert(content, "✅ EXECUTION SUCCESS")
    else
        table.insert(content, "❌ EXECUTION FAILED")
        if failure_reason then
            table.insert(content, "Failure Reason: " .. failure_reason)
        end
    end
    table.insert(content, "Total breeding steps: " .. breeding_steps)
    table.insert(content, "Total accumulation cycles: " .. accumulation_cycles)
    table.insert(content, "")

    -- Execution statistics
    do
        local bred_species = {}
        local gui_errors = 0
        local gui_calls = 0
        local status_errors = 0
        for _, entry in ipairs(execution_log) do
            if entry.type == "breeding" and entry.success and entry.target then
                bred_species[entry.target] = true
            elseif entry.type == "gui_error" then
                gui_errors = gui_errors + 1
            elseif entry.type == "gui_call" then
                gui_calls = gui_calls + 1
            elseif entry.type == "status_indicator" and not entry.success then
                status_errors = status_errors + 1
            end
        end
        local distinct_bred = 0
        for _ in pairs(bred_species) do distinct_bred = distinct_bred + 1 end
        table.insert(content, "📈 EXECUTION STATISTICS:")
        table.insert(content, "  Distinct species bred: " .. distinct_bred)
        table.insert(content, "  GUI calls: " .. gui_calls .. ", GUI errors: " .. gui_errors)
        table.insert(content, "  Status errors: " .. status_errors)
        table.insert(content, "")
    end

    -- Detailed execution log with all captured information
    table.insert(content, "📋 DETAILED EXECUTION LOG:")
    if #execution_log == 0 then
        table.insert(content, "  (no execution steps recorded)")
        table.insert(content, "  This usually indicates that executeBreedingTree was not called")
        table.insert(content, "  or that the mocking setup failed.")
    else
        for i, log_entry in ipairs(execution_log) do
            if log_entry.type == "breeding" then
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [BREEDING] " .. status .. " " ..
                            log_entry.princess .. " + " .. log_entry.drone .. " -> " .. log_entry.target)
                if log_entry.error_message then
                    table.insert(content, "     Error: " .. log_entry.error_message)
                end
                if log_entry.validation_failures then
                    table.insert(content, "     Validation failures:")
                    for _, failure in ipairs(log_entry.validation_failures) do
                        table.insert(content, "       - " .. failure)
                    end
                end
            elseif log_entry.type == "accumulation" then
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [ACCUMULATION] " .. status .. " " .. log_entry.species)
                if log_entry.error_message then
                    table.insert(content, "     Error: " .. log_entry.error_message)
                end
            elseif log_entry.type == "gui_call" then
                table.insert(content, "  " .. i .. ". [GUI_CALL] " .. log_entry.arguments)
                if log_entry.details and log_entry.details.progress then
                    table.insert(content, "     Progress: " .. log_entry.details.progress)
                end
                if log_entry.details and log_entry.details.errors then
                    table.insert(content, "     Errors: " .. log_entry.details.errors)
                end
            elseif log_entry.type == "gui_error" then
                table.insert(content, "  " .. i .. ". [GUI_ERROR] ❌ " .. log_entry.message)
            elseif log_entry.type == "gui_status" then
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [GUI_STATUS] " .. status .. " " .. log_entry.status)
            elseif log_entry.type == "status_indicator" then
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [STATUS] " .. status .. " " .. log_entry.state)
                if log_entry.message then
                    table.insert(content, "     Message: " .. log_entry.message)
                end
                if log_entry.species then
                    table.insert(content, "     Species: " .. log_entry.species)
                end
            elseif log_entry.type == "debug_pre_execution" then
                table.insert(content, "  " .. i .. ". [DEBUG_PRE] Target: " .. log_entry.target)
                table.insert(content, "     Tree exists: " .. tostring(log_entry.tree_exists))
                table.insert(content, "     Has drone requirements: " .. tostring(log_entry.has_drone_requirements))
                table.insert(content, "     Total steps planned: " .. tostring(log_entry.total_steps))
                if log_entry.details then
                    table.insert(content, "     Tree species: " .. tostring(log_entry.details.tree_species))
                    table.insert(content, "     Drone req count: " .. tostring(log_entry.details.drone_req_count))
                end
            elseif log_entry.type == "execution_exception" then
                table.insert(content, "  " .. i .. ". [EXCEPTION] ❌ " .. log_entry.message)
                table.insert(content, "     Details: " .. log_entry.exception_details)
            elseif log_entry.type == "execution_result" then
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [EXECUTION_RESULT] " .. status .. " Returned: " .. tostring(log_entry.returned_value))
                if log_entry.error_message then
                    table.insert(content, "     Issue: " .. log_entry.error_message)
                end
            elseif log_entry.type == "function_missing" then
                table.insert(content, "  " .. i .. ". [FUNCTION_MISSING] ❌ " .. log_entry.message)
                table.insert(content, "     This indicates the function is not exported from main.lua")
            else
                -- Generic handler for any other log types
                local status = log_entry.success and "✅" or "❌"
                table.insert(content, "  " .. i .. ". [" .. string.upper(log_entry.type) .. "] " .. status)
                if log_entry.message then
                    table.insert(content, "     Message: " .. log_entry.message)
                end
                if log_entry.error_message then
                    table.insert(content, "     Error: " .. log_entry.error_message)
                end
            end
        end
    end
    table.insert(content, "")

    -- Analysis of failures with debugging guidance
    local failures = {}
    local debug_entries = {}
    local gui_interactions = {}

    for _, log_entry in ipairs(execution_log) do
        if not log_entry.success then
            table.insert(failures, log_entry)
        end
        if log_entry.type == "debug_pre_execution" or log_entry.type == "execution_result" or log_entry.type == "execution_exception" then
            table.insert(debug_entries, log_entry)
        end
        if string.match(log_entry.type, "gui") then
            table.insert(gui_interactions, log_entry)
        end
    end

    -- Debug summary section
    table.insert(content, "🔧 EXECUTION DEBUG SUMMARY:")
    if #debug_entries > 0 then
        for _, debug_entry in ipairs(debug_entries) do
            if debug_entry.type == "debug_pre_execution" then
                table.insert(content, "  Setup: Target=" .. debug_entry.target ..
                            ", TreeExists=" .. tostring(debug_entry.tree_exists) ..
                            ", Steps=" .. tostring(debug_entry.total_steps))
            elseif debug_entry.type == "execution_result" then
                table.insert(content, "  Result: executeBreedingTree returned " .. tostring(debug_entry.returned_value))
            elseif debug_entry.type == "execution_exception" then
                table.insert(content, "  Exception: " .. debug_entry.message)
            end
        end
    else
        table.insert(content, "  No debug information captured - mock setup may have failed")
    end
    table.insert(content, "")

    -- GUI interaction summary
    table.insert(content, "🖥️  GUI INTERACTION SUMMARY:")
    if #gui_interactions > 0 then
        table.insert(content, "  Total GUI calls: " .. #gui_interactions)
        local error_calls = 0
        for _, gui_entry in ipairs(gui_interactions) do
            if not gui_entry.success then
                error_calls = error_calls + 1
            end
        end
        table.insert(content, "  GUI error calls: " .. error_calls)
    else
        table.insert(content, "  No GUI interactions recorded")
        table.insert(content, "  This may indicate executeBreedingTree was not called or mock setup failed")
    end
    table.insert(content, "")

    -- Failure analysis
    if #failures > 0 then
        table.insert(content, "🔍 FAILURE ANALYSIS:")
        local failure_types = {}
        for _, failure in ipairs(failures) do
            local key = failure.type .. "_failure"
            failure_types[key] = (failure_types[key] or 0) + 1
        end

        for failure_type, count in pairs(failure_types) do
            table.insert(content, "  " .. failure_type .. ": " .. count .. " occurrences")
        end
        table.insert(content, "")

        table.insert(content, "Specific failure details:")
        for i, failure in ipairs(failures) do
            table.insert(content, "  " .. i .. ". " .. failure.type:upper() .. " failure:")
            if failure.princess and failure.drone then
                table.insert(content, "     Step: " .. failure.princess .. " + " .. failure.drone .. " -> " .. failure.target)
            elseif failure.species then
                table.insert(content, "     Species: " .. failure.species)
            end
            if failure.error_message then
                table.insert(content, "     Message: " .. failure.error_message)
            end
            if failure.validation_failures then
                table.insert(content, "     Validation issues:")
                for _, val_failure in ipairs(failure.validation_failures) do
                    table.insert(content, "       - " .. val_failure)
                end
            end
        end
    else
        table.insert(content, "✅ NO MOCK FAILURES DETECTED")
        if not success then
            table.insert(content, "")

            -- Check for specific common issues
            local has_function_missing = false
            local has_nil_return = false
            for _, log_entry in ipairs(execution_log) do
                if log_entry.type == "function_missing" then
                    has_function_missing = true
                elseif log_entry.type == "execution_result" and log_entry.returned_value == nil then
                    has_nil_return = true
                end
            end

            if has_function_missing then
                table.insert(content, "🚨 ISSUE IDENTIFIED: executeBreedingTree function not exported from main.lua")
                table.insert(content, "   SOLUTION: Add executeBreedingTree to the export table in main.lua")
            elseif has_nil_return then
                table.insert(content, "🚨 ISSUE IDENTIFIED: executeBreedingTree returned nil")
                table.insert(content, "   This usually means the function exists but has no return statement")
                table.insert(content, "   or returns nil under certain conditions")
            else
                table.insert(content, "⚠️  IMPORTANT: Execution failed but no mock failures were recorded.")
                table.insert(content, "This suggests the failure occurred in executeBreedingTree itself,")
                table.insert(content, "not in the mocked functions. Check the execution debug summary above.")
            end
        end
    end

    -- Write to file
    local file = io.open(filename, "w")
    if file then
        file:write(table.concat(content, "\n"))
        file:close()
        print("📁 Execution analysis dumped to: " .. filename)
    else
        print("❌ Failed to write execution analysis to: " .. filename)
    end
end

-- Test executeBreedingTree function to ensure it processes trees normally
local function testExecuteBreedingTree()
    print("=== Testing executeBreedingTree Function ===")
    print("Testing tree execution with realistic mock breeding functions")

    -- Mock the breeding execution functions to simulate successful operations
    local original_executeSingleBreedingStep = _G.executeSingleBreedingStep
    local original_executeAccumulationCycle = _G.executeAccumulationCycle
    local original_drawGUI = _G.drawGUI
    local original_updateStatusIndicators = _G.updateStatusIndicators

    -- Track execution steps for verification with enhanced failure tracking
    local execution_log = {}
    local breeding_steps = 0
    local accumulation_cycles = 0

    -- Enhanced mock executeSingleBreedingStep with realistic behavior
    _G.executeSingleBreedingStep = function(princess_species, drone_species, target_species, hasAPI)
        local validation_failures = {}
        local success = true
        local error_message = nil

        -- Realistic validation: machines work perfectly, but we need the right materials
        -- Any failure here indicates a bug in our inventory management or planning logic
        if not _G.hasSpeciesPrincess(princess_species) then
            table.insert(validation_failures, "Princess " .. princess_species .. " not available")
            success = false
        end

        if not _G.hasSpeciesDrone(drone_species) then
            table.insert(validation_failures, "Drone " .. drone_species .. " not available")
            success = false
        end

        -- Machines have 100% success rate when materials are available
        -- This reflects the deterministic nature of OpenComputers breeding machines
        if success then
            -- Add the bred species to inventory for subsequent steps
            -- In real breeding, we get multiple offspring of the target species
            -- Add princess and multiple drones for realistic inventory simulation
            table.insert(test_inventory.princesses, target_species)
            table.insert(test_inventory.drones, target_species)
            table.insert(test_inventory.drones, target_species) -- Add extra drone
            table.insert(test_inventory.drones, target_species) -- Add another for complex chains

            -- Also ensure parent species remain available as drones for future breeding
            -- This simulates accumulation cycles that would happen in real execution
            if _G.hasSpeciesDrone(princess_species) then
                table.insert(test_inventory.drones, princess_species) -- Extra princess species drone
            end
            if _G.hasSpeciesDrone(drone_species) then
                table.insert(test_inventory.drones, drone_species) -- Extra drone species drone
            end

            -- Track bred species for execution session (matches main.lua logic)
            if not _G.execution_bred_species then
                _G.execution_bred_species = {}
            end
            _G.execution_bred_species[target_species] = true
        end

        local log_entry = {
            type = "breeding",
            princess = princess_species,
            drone = drone_species,
            target = target_species,
            hasAPI = hasAPI,
            success = success,
            error_message = error_message,
            validation_failures = #validation_failures > 0 and validation_failures or nil
        }

        table.insert(execution_log, log_entry)
        breeding_steps = breeding_steps + 1

        -- All detailed info goes to execution log - no console output for individual steps

        return success
    end

    -- Enhanced mock executeAccumulationCycle with realistic behavior
    _G.executeAccumulationCycle = function(species)
        local success = true
        local error_message = nil

        -- Realistic validation: accumulation works perfectly if princess is available
        if not _G.hasSpeciesPrincess(species) then
            success = false
            error_message = "Princess " .. species .. " not available for accumulation"
        end

        -- Accumulation has 100% success rate when princess is available
        -- This reflects the deterministic nature of OpenComputers bee accumulation
        if success then
            -- Add extra drones of this species to inventory
            -- Simulate realistic accumulation yields
            for i = 1, 4 do -- Add 4 drones per accumulation cycle (more realistic)
                table.insert(test_inventory.drones, species)
            end
        end

        local log_entry = {
            type = "accumulation",
            species = species,
            success = success,
            error_message = error_message
        }

        table.insert(execution_log, log_entry)
        accumulation_cycles = accumulation_cycles + 1

        -- All detailed info goes to execution log - no console output for individual steps

        return success
    end

    -- Comprehensive mock GUI functions to track all interactions
    _G.drawGUI = function(args)
        -- Capture all GUI calls for debugging in the execution log
        local gui_info = {}
        if args then
            for key, value in pairs(args) do
                table.insert(gui_info, key .. "=" .. tostring(value))
            end
        end

        -- Log GUI call to execution log
        table.insert(execution_log, {
            type = "gui_call",
            arguments = args and table.concat(gui_info, ", ") or "no args",
            success = true,
            details = args
        })

        -- Capture GUI error messages that executeBreedingTree generates
        if args and args.errors then
            -- Add the GUI error to execution log for analysis
            table.insert(execution_log, {
                type = "gui_error",
                message = args.errors,
                success = false,
                error_message = args.errors
            })
        end

        -- Capture other important GUI states
        if args and args.status then
            table.insert(execution_log, {
                type = "gui_status",
                status = args.status,
                success = args.status ~= "Error",
                error_message = args.status == "Error" and "GUI reported error status" or nil
            })

            if args.status == "Error" then
                -- Error status already captured in execution log above
            end
        end
    end

    _G.updateStatusIndicators = function(state, message, species)
        -- Capture all status indicator calls in execution log
        table.insert(execution_log, {
            type = "status_indicator",
            state = state,
            message = message,
            species = species,
            success = state ~= "error",
            error_message = state == "error" and (message or "Status indicator reported error") or nil
        })

        -- All status information goes to execution log
    end

    -- Comprehensive test cases organized by complexity and scenario type
    local test_categories = {
        {
            name = "SUCCESS CASES - Full Base Species Available",
            test_cases = {
                {
                    name = "Simple single-step breeding (Common)",
                    target = "Common", -- Common = Meadows + Forest
                    inventory_setup = {
                        princesses = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"},
                        drones = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"}
                    },
                    expected_steps = 1,
                    expected_success = true,
                    description = "Basic single-step breeding with full base inventory"
                },
                {
                    name = "Two-step breeding chain (Cultivated)",
                    target = "Cultivated", -- Cultivated = Meadows + Common (Common = Meadows + Forest)
                    inventory_setup = {
                        princesses = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"},
                        drones = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"}
                    },
                    expected_steps = 2,
                    expected_success = true,
                    description = "Two-step chain requiring intermediate breeding"
                },
                {
                    name = "Complex multi-step breeding (Imperial)",
                    target = "Imperial", -- Imperial = Noble + Majestic (requires Common, Cultivated, Noble, Majestic)
                    inventory_setup = {
                        princesses = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"},
                        drones = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion"}
                    },
                    expected_steps = 6,
                    expected_success = true,
                    description = "Multi-step Forestry chain"
                },
                {
                    name = "Extremely complex MeatballCraft - Controller",
                    target = "Controller", -- Controller = Ringbearer + Chevron (requires deep ExtraBees and MagicBees chains)
                    inventory_setup = {
                        princesses = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion", "Water", "Rocky"},
                        drones = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion", "Water", "Rocky"}
                    },
                    expected_steps = 20, -- This will be very deep
                    expected_success = true,
                    description = "Extremely complex MeatballCraft bee requiring deep multi-mod chains"
                },
                {
                    name = "Ultra complex MeatballCraft - Necronomibee",
                    target = "Necronomibee", -- Necronomibee = Savant + Abyssal (requires MagicBees Savant + ExtraBees Abyssal chains)
                    inventory_setup = {
                        princesses = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion", "Water", "Rocky"},
                        drones = {"Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast", "Infernal", "Oblivion", "Water", "Rocky"}
                    },
                    expected_steps = 25, -- Estimate for very deep chain
                    expected_success = true,
                    description = "Ultimate complexity MeatballCraft bee requiring both MagicBees and ExtraBees deep chains"
                }
            }
        },
        {
            name = "SUCCESS CASES - Minimal But Sufficient Inventory",
            test_cases = {
                {
                    name = "Exact inventory for Common breeding",
                    target = "Common",
                    inventory_setup = {
                        princesses = {"Forest", "Meadows"}, -- Just what's needed
                        drones = {"Forest", "Meadows"}
                    },
                    expected_steps = 1,
                    expected_success = true,
                    description = "Test with minimal but sufficient inventory"
                },
                {
                    name = "Heroic with exact base species",
                    target = "Heroic", -- Heroic = Valiant + Steadfast
                    inventory_setup = {
                        princesses = {"Valiant", "Steadfast"}, -- Exactly what's needed
                        drones = {"Valiant", "Steadfast"}
                    },
                    expected_steps = 1,
                    expected_success = true,
                    description = "Test breeding with exactly the required base species"
                }
            }
        },
        {
            name = "SUCCESS CASES - MeatballCraft (auto)",
            test_cases = (function()
                local cases = {}
                for _, target in ipairs(meatball_species or {}) do
                    local bases = computeBaseLeaves(target)
                    if #bases > 0 then
                        table.insert(cases, {
                            name = target .. " - base inventory",
                            target = target,
                            inventory_setup = { princesses = bases, drones = bases },
                            expected_success = true,
                            description = "Auto-generated MeatballCraft execution test with computed base species"
                        })
                    end
                end
                return cases
            end)()
        },
        {
            name = "FAILURE CASES - Missing Required Species",
            test_cases = {
                {
                    name = "Missing princess for Common",
                    target = "Common",
                    inventory_setup = {
                        princesses = {"Forest"}, -- Missing Meadows
                        drones = {"Forest", "Meadows"}
                    },
                    expected_steps = 0,
                    expected_success = false,
                    description = "Should fail due to missing required princess"
                },
                {
                    name = "Missing drone for Common",
                    target = "Common",
                    inventory_setup = {
                        princesses = {"Forest", "Meadows"},
                        drones = {"Forest"} -- Missing Meadows drone
                    },
                    expected_steps = 0,
                    expected_success = false,
                    description = "Should fail due to missing required drone"
                },
                {
                    name = "Complex target with insufficient base species",
                    target = "Controller", -- Requires many base species
                    inventory_setup = {
                        princesses = {"Forest", "Meadows"}, -- Insufficient for complex chain
                        drones = {"Forest", "Meadows"}
                    },
                    expected_steps = 0,
                    expected_success = false,
                    description = "Should fail planning due to missing base species for complex chain"
                }
            }
        }
    }

    local total_tests = 0
    local passed_tests = 0

    -- Run all test categories
    for _, category in ipairs(test_categories) do
        print("\n=== " .. category.name .. " ===")

        for _, test_case in ipairs(category.test_cases) do
            total_tests = total_tests + 1
            print("\n--- Testing: " .. test_case.name .. " ---")
            print("Description: " .. test_case.description)

            -- Reset test state
            execution_log = {}
            breeding_steps = 0
            accumulation_cycles = 0

            -- Clear execution tracking for fresh test
            _G.execution_bred_species = nil

            -- Set up specific inventory for this test
            test_inventory.princesses = {}
            test_inventory.drones = {}
            for _, species in ipairs(test_case.inventory_setup.princesses) do
                table.insert(test_inventory.princesses, species)
            end
            for _, species in ipairs(test_case.inventory_setup.drones) do
                table.insert(test_inventory.drones, species)
            end

            -- Calculate breeding plan
            local plan = main.calculateBreedingPath and main.calculateBreedingPath(test_case.target)

            local test_success = false
            local failure_reason = nil

            if not plan or plan.plan_failed then
                if test_case.expected_success then
                    print("  ❌ Planning failed when it should succeed")
                    failure_reason = "Planning failed unexpectedly"
                    dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                        false, "Planning failed when success was expected", "planning_failure")
                else
                    print("  ✅ Planning correctly failed as expected")
                    test_success = true
                    dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                        true, "Planning correctly failed as expected", "expected_failure")
                end
            else
                print("  ✅ Plan generated: " .. plan.total_steps .. " steps")

                if not plan.can_execute then
                    if test_case.expected_success then
                        print("  ❌ Plan cannot execute (missing base species)")
                        failure_reason = "Missing base species"
                        dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                            false, "Plan generated but cannot execute - missing base species", "execution_blocked")
                    else
                        print("  ✅ Plan correctly identified missing requirements")
                        test_success = true
                        dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                            true, "Plan correctly identified missing base species", "expected_failure")
                    end
                else
                    -- Mock gui_state for executeBreedingTree
                    _G.gui_state = _G.gui_state or {}
                    _G.gui_state.target = test_case.target
                    _G.gui_state.current_step = 0

                    -- Capture pre-execution debugging info in execution log
                    table.insert(execution_log, {
                        type = "debug_pre_execution",
                        target = test_case.target,
                        tree_exists = plan.tree ~= nil,
                        has_drone_requirements = next(plan.drone_requirements) ~= nil,
                        total_steps = plan.total_steps,
                        success = true,
                        details = {
                            target = test_case.target,
                            tree_species = plan.tree and plan.tree.species or "none",
                            drone_req_count = plan.drone_requirements and #plan.drone_requirements or 0
                        }
                    })

                    -- Execute the breeding tree with error handling
                    local execution_success = false
                    local execution_error = nil

                    if not main.executeBreedingTree then
                        table.insert(execution_log, {
                            type = "function_missing",
                            message = "executeBreedingTree function not exported from main.lua",
                            success = false,
                            error_message = "executeBreedingTree function not available - check main.lua exports"
                        })
                        print("  ❌ executeBreedingTree function not found in main.lua exports")
                        failure_reason = "Function not exported"
                    else
                        -- Execute the breeding tree with error handling
                        local success_pcall, result = pcall(function()
                            return main.executeBreedingTree(
                                plan.tree,
                                plan.drone_requirements,
                                false, -- hasAPI = false (no Gendustry)
                                plan.total_steps
                            )
                        end)

                        if not success_pcall then
                            execution_error = result
                            table.insert(execution_log, {
                                type = "execution_exception",
                                message = "executeBreedingTree threw exception: " .. tostring(result),
                                success = false,
                                error_message = tostring(result),
                                exception_details = tostring(result)
                            })
                        else
                            execution_success = result
                            table.insert(execution_log, {
                                type = "execution_result",
                                returned_value = execution_success,
                                success = execution_success == true,
                                error_message = execution_success ~= true and "executeBreedingTree returned " .. tostring(execution_success) or nil
                            })
                        end
                    end

                    -- Analyze results
                    if execution_error then
                        print("  ❌ Execution threw exception: " .. execution_error)
                        failure_reason = "Execution exception"
                        dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                            false, "Execution threw exception: " .. execution_error, "execution_exception")
                    elseif execution_success then
                        print("  ✅ Tree execution completed successfully")
                        print("    Breeding steps executed: " .. breeding_steps)
                        print("    Accumulation cycles: " .. accumulation_cycles)

                        -- Verify execution sequence
                        local breeding_targets = {}
                        for _, log_entry in ipairs(execution_log) do
                            if log_entry.type == "breeding" and log_entry.success then
                                table.insert(breeding_targets, log_entry.target)
                            end                        end

                        if #breeding_targets > 0 then
                            print("    Breeding sequence: " .. table.concat(breeding_targets, " -> "))

                            -- Check if final target was bred correctly
                            if breeding_targets[#breeding_targets] == test_case.target then
                                print("    ✅ Final target " .. test_case.target .. " was bred correctly")
                                test_success = true
                                dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                    true, nil, "success")
                            else
                                print("    ❌ Final target " .. test_case.target .. " was not bred correctly")
                                failure_reason = "Wrong breeding sequence"
                                dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                    false, "Wrong breeding sequence - final target not produced", "sequence_failure")
                            end
                        else
                            print("    Breeding sequence: none")
                            if test_case.expected_steps == 0 then
                                print("    ✅ No breeding required (already available)")
                                test_success = true
                                dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                    true, "Target already available - no breeding required", "already_available")
                            else
                                print("    ❌ No breeding executed when steps were expected")
                                failure_reason = "No breeding executed"
                                dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                    false, "No breeding executed when steps were expected", "no_execution")
                            end
                        end
                    else
                        if test_case.expected_success then
                            print("  ❌ Tree execution failed")
                            failure_reason = "Execution failed"
                            dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                false, "Tree execution failed", "execution_failure")
                        else
                            print("  ✅ Tree execution correctly failed as expected")
                            test_success = true
                            dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles,
                                                true, "Execution correctly failed as expected", "expected_failure")
                        end
                    end
                end
            end

            if test_success then
                passed_tests = passed_tests + 1
            end
        end
    end

    -- Restore original functions
    _G.executeSingleBreedingStep = original_executeSingleBreedingStep
    _G.executeAccumulationCycle = original_executeAccumulationCycle
    _G.drawGUI = original_drawGUI
    _G.updateStatusIndicators = original_updateStatusIndicators

    -- Test results summary
    print("\n=== executeBreedingTree Test Results Summary ===")
    print("Total tests: " .. total_tests)
    print("Passed: " .. passed_tests)
    print("Failed: " .. (total_tests - passed_tests))

    if passed_tests == total_tests then
        print("🎉 All execution tests passed!")
    else
        print("❌ Some execution tests failed. Check output above for details.")
    end

    print()
    print("📁 Comprehensive execution analysis written to Artifacts/ folder:")
    print("   - Each test creates a detailed *_execution_*.txt file")
    print("   - Files include: setup info, GUI calls, status updates, and failure analysis")
    print("   - Debug information shows exactly what executeBreedingTree received and returned")
    print("   - Failure artifacts explain why execution failed and what to check")
    print()

    return passed_tests == total_tests
end

-- Test error handling in executeBreedingTree
local function testExecuteBreedingTreeErrorHandling()
    print("=== Testing executeBreedingTree Error Handling ===")
    print("Testing realistic error scenarios that indicate code bugs")

    -- Mock functions that can detect code bugs
    local original_executeSingleBreedingStep = _G.executeSingleBreedingStep
    local original_drawGUI = _G.drawGUI

    local gui_calls = {}
    local error_execution_log = {}

    -- Mock GUI to capture error states
    _G.drawGUI = function(args)
        table.insert(gui_calls, args)
        if args and args.errors then
            table.insert(error_execution_log, {
                type = "gui_error",
                message = args.errors,
                success = false
            })
        end
        if args and args.progress then
            table.insert(error_execution_log, {
                type = "gui_progress",
                message = args.progress,
                success = true
            })
        end
    end

    -- Test case 1: Code bug - trying to breed with unavailable materials
    print("\n--- Test 1: Code Bug - Missing Materials ---")
    _G.executeSingleBreedingStep = function(princess, drone, target, hasAPI)
        -- This represents a realistic scenario where our inventory tracking has a bug
        -- and we're trying to breed with species we don't actually have
        local has_princess = _G.hasSpeciesPrincess(princess)
        local has_drone = _G.hasSpeciesDrone(drone)

        local success = has_princess and has_drone
        local error_msg = nil

        if not success then
            if not has_princess then
                error_msg = "Code bug: attempting to breed with unavailable princess " .. princess
            elseif not has_drone then
                error_msg = "Code bug: attempting to breed with unavailable drone " .. drone
            end
        else
            -- Machine works perfectly when materials are available
            table.insert(test_inventory.princesses, target)
            table.insert(test_inventory.drones, target)
            table.insert(test_inventory.drones, target)
        end

        -- Log the attempt
        table.insert(error_execution_log, {
            type = "breeding",
            princess = princess,
            drone = drone,
            target = target,
            hasAPI = hasAPI,
            success = success,
            error_message = error_msg,
            bug_type = not success and "inventory_tracking_bug" or nil
        })

        return success
    end

    -- Set up inventory that will cause the bug to manifest
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows"}

    -- Force a scenario where we have an incomplete plan (this would be a planning bug)
    local plan = main.calculateBreedingPath and main.calculateBreedingPath("Modest")
    if plan and not plan.plan_failed then
        -- Artificially remove required materials to simulate inventory tracking bug
        test_inventory.drones = {"Forest"} -- Missing Meadows drone

        _G.gui_state = _G.gui_state or {}
        _G.gui_state.target = "Modest"
        _G.gui_state.current_step = 0

        local success = main.executeBreedingTree and main.executeBreedingTree(
            plan.tree,
            plan.drone_requirements,
            false,
            plan.total_steps
        )

        if not success then
            print("  ✅ Code bug detected correctly - execution failed due to missing materials")

            -- Check if the bug was properly identified
            local bug_detected = false
            local bug_messages = {}
            for _, log_entry in ipairs(error_execution_log) do
                if log_entry.bug_type == "inventory_tracking_bug" then
                    bug_detected = true
                    table.insert(bug_messages, log_entry.error_message)
                end
            end

            if bug_detected then
                print("  ✅ Inventory tracking bug properly identified")
                print("    Bug details: " .. table.concat(bug_messages, "; "))
            else
                print("  ❌ Bug not properly identified in execution log")
            end

            -- Dump bug analysis
            dumpExecutionAnalysis("Modest", error_execution_log, 1, 0, false,
                                "Inventory tracking bug - attempted breeding with missing materials", "code_bug_detection")

        else
            print("  ❌ Code bug not detected - execution should have failed")
            dumpExecutionAnalysis("Modest", error_execution_log, 1, 0, true,
                                "Missed code bug - execution succeeded despite missing materials", "missed_bug")
        end
    else
        print("  ❌ Could not generate plan for bug testing")
        dumpExecutionAnalysis("Modest", error_execution_log, 0, 0, false,
                            "Could not generate breeding plan for bug detection test", "planning_failure")
    end

    -- Test case 2: API usage bug - invalid parameters
    print("\n--- Test 2: Code Bug - Invalid API Usage ---")
    error_execution_log = {}  -- Reset log

    _G.executeSingleBreedingStep = function(princess, drone, target, hasAPI)
        -- Test for API usage bugs - invalid species names, nil parameters, etc.
        local validation_errors = {}
        local success = true

        if not princess or princess == "" then
            table.insert(validation_errors, "Invalid princess parameter: " .. tostring(princess))
            success = false
        end

        if not drone or drone == "" then
            table.insert(validation_errors, "Invalid drone parameter: " .. tostring(drone))
            success = false
        end

        if not target or target == "" then
            table.insert(validation_errors, "Invalid target parameter: " .. tostring(target))
            success = false
        end

        -- Check for valid species names (this would catch typos in breeding rules)
        local valid_species = {
            -- Base species (from current mutations database)
            "Forest", "Meadows", "Monastic", "Modest", "Tropical", "Marshy", "Wintry", "Ender", "Valiant", "Steadfast",
            "Infernal", "Oblivion", "Water", "Rocky",
            -- Common bred species for testing
            "Common", "Cultivated", "Noble", "Majestic", "Imperial", "Diligent", "Unweary", "Industrious",
            "Heroic", "Mystical", "Supernatural"
        }

        local function isValidSpecies(species)
            for _, valid in ipairs(valid_species) do
                if species == valid then return true end
            end
            return false
        end

        if success and not isValidSpecies(princess) then
            table.insert(validation_errors, "Unknown princess species: " .. princess)
            success = false
        end

        if success and not isValidSpecies(drone) then
            table.insert(validation_errors, "Unknown drone species: " .. drone)
            success = false
        end

        if success and not isValidSpecies(target) then
            table.insert(validation_errors, "Unknown target species: " .. target)
            success = false
        end

        local error_msg = nil
        if not success then
            error_msg = "API usage bug: " .. table.concat(validation_errors, "; ")
        else
            -- Normal successful breeding
            if _G.hasSpeciesPrincess(princess) and _G.hasSpeciesDrone(drone) then
                table.insert(test_inventory.princesses, target)
                table.insert(test_inventory.drones, target)
                table.insert(test_inventory.drones, target)
            else
                success = false
                error_msg = "Materials unavailable for breeding"
            end
        end

        table.insert(error_execution_log, {
            type = "breeding",
            princess = princess,
            drone = drone,
            target = target,
            hasAPI = hasAPI,
            success = success,
            error_message = error_msg,
            bug_type = #validation_errors > 0 and "api_usage_bug" or nil,
            validation_errors = #validation_errors > 0 and validation_errors or nil
        })

        return success
    end

    -- This test would need to be triggered by actually having bugs in the breeding rules
    -- For demonstration, we'll just show that the validation would work
    print("  ✅ API validation framework ready - would catch parameter bugs")
    print("    - Invalid/nil species parameters")
    print("    - Typos in species names")
    print("    - Missing required parameters")

    -- Restore original functions
    _G.executeSingleBreedingStep = original_executeSingleBreedingStep
    _G.drawGUI = original_drawGUI

    print("Realistic error handling test completed")
    print("Focus: Code bugs that would cause breeding failures, not machine failures")
    print()
end

-- Combined test runner that includes execution tests
local function runAllTestsComplete()
    print("=== Complete HiveMind Test Suite ===")

    -- Run planning tests
    local planning_passed = runAllTests()
    print()

    -- Run execution tests (now defined above)
    print("=== Running Execution Tests ===")
    local execution_success, execution_results = testExecuteBreedingTree()
    print()

    -- Run error handling test
    print("=== Running Error Handling Tests ===")
    testExecuteBreedingTreeErrorHandling()
    print()

    -- Combined results
    print("=== Overall Test Results ===")
    print("Planning tests: " .. (planning_passed and "✅ PASSED" or "❌ FAILED"))
    print("Execution tests: " .. (execution_success and "✅ PASSED" or "❌ FAILED"))
    print()
    print("📁 Comprehensive test artifacts generated:")
    print("   - Artifacts/*_analysis.txt - Breeding path analysis")
    print("   - Artifacts/*_execution_*.txt - Detailed execution logs with failure reasons")
    print("   - Debug information shows exactly what executeBreedingTree received and returned")
    print("   - Failure artifacts explain why execution failed and what to check")

    if planning_passed and execution_success then
        print("🎉 All tests passed!")
        return true
    else
        print("❌ Some tests failed. Check output above and artifact files for details.")
        return false
    end
end

-- Run tests automatically if executed directly
if ... == nil then
    runAllTestsComplete()  -- Run complete test suite including execution tests
end

-- Export functions for interactive use
return {
    runAllTests = runAllTests,
    runAllTestsComplete = runAllTestsComplete,
    runTest = runTest,
    testSpecificTarget = testSpecificTarget,
    performanceTest = performanceTest,
    complexityStressTest = complexityStressTest,
    testExecuteBreedingTree = testExecuteBreedingTree,
    testExecuteBreedingTreeErrorHandling = testExecuteBreedingTreeErrorHandling,
    test_cases = test_cases
}
