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
            if name == "chat_box" then return false end -- Can be toggled
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
        
        -- Mock chat box (when available)
        chat_box = {
            say = function(message) print("[CHAT] " .. message) end,
            tell = function(player, message) print("[CHAT -> " .. player .. "] " .. message) end
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
    
    -- Mock inventory access functions
    _G.hasSpeciesPrincess = function(species)
        for _, princess in ipairs(test_inventory.princesses) do
            if princess == species then
                return true
            end
        end
        return false
    end
    
    _G.hasSpeciesDrone = function(species)
        for _, drone in ipairs(test_inventory.drones) do
            if drone == species then
                return true
            end
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
        target = "Modest", 
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        should_succeed = true
    },
    
    {
        name = "Three-generation breeding chain",
        target = "Cultivated",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest"},
        should_succeed = true
    },
    
    {
        name = "Complex Imperial breeding",
        target = "Imperial",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Majestic"},
        should_succeed = true
    },
    
    {
        name = "Missing starting princess",
        target = "Modest",
        available_princesses = {"Common"}, -- Missing Forest
        available_drones = {"Forest", "Meadows"},
        should_succeed = false
    },
    
    {
        name = "Industrial branch breeding",
        target = "Industrious", 
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Diligent", "Unweary"},
        should_succeed = true
    },
    
    {
        name = "Cross-mod breeding (MagicBees)",
        target = "Mystical",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble"},
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
        target = "Heroic",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Diligent", "Valiant", "Steadfast"},
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

-- Dump detailed tree analysis to artifacts folder
local function dumpTreeAnalysis(target, plan, sanity_issues)
    local artifacts_dir = "Artifacts"
    local filename = artifacts_dir .. "/" .. target .. "_analysis.txt"
    
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
                            table.insert(content, "    → " .. species .. ": " .. analysis.occurrences .. " occurrences, " .. 
                                        analysis.reused .. " reused, could reuse " .. analysis.potential_additional_reuse .. " more")
                        else
                            table.insert(content, "    " .. species .. ": " .. analysis.occurrences .. " occurrences, no reuse")
                        end
                    end
                end
            end
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
    local plan = main.calculateBreedingPath and main.calculateBreedingPath(test_case.target)
    
    -- Dump detailed analysis to artifacts folder
    if plan then
        -- Get sanity issues if they exist
        local sanity_issues = plan.sanity_issues
        dumpTreeAnalysis(test_case.target, plan, sanity_issues)
    else
        dumpTreeAnalysis(test_case.target, nil, nil)
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
    test_inventory.drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Majestic", 
                           "Diligent", "Unweary", "Industrious", "Valiant", "Steadfast", "Heroic",
                           "Mystical", "Sorcerous", "Unusual", "Supernatural"}
    
    local plan = main.calculateBreedingPath and main.calculateBreedingPath(target)
    
    -- Dump detailed analysis to artifacts folder
    if plan then
        local sanity_issues = plan.sanity_issues
        dumpTreeAnalysis(target, plan, sanity_issues)
    else
        dumpTreeAnalysis(target, nil, nil)
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
    print("Testing tree execution with mock breeding functions")
    
    -- Mock the breeding execution functions to simulate successful operations
    local original_executeSingleBreedingStep = _G.executeSingleBreedingStep
    local original_executeAccumulationCycle = _G.executeAccumulationCycle
    local original_drawGUI = _G.drawGUI
    local original_updateStatusIndicators = _G.updateStatusIndicators
    
    -- Track execution steps for verification with enhanced failure tracking
    local execution_log = {}
    local breeding_steps = 0
    local accumulation_cycles = 0
    
    -- Enhanced mock executeSingleBreedingStep with validation
    _G.executeSingleBreedingStep = function(princess_species, drone_species, target_species, hasAPI)
        local validation_failures = {}
        local success = true
        local error_message = nil
        
        -- Simulate validation checks
        if not _G.hasSpeciesPrincess(princess_species) then
            table.insert(validation_failures, "Princess " .. princess_species .. " not available")
            success = false
        end
        
        if not _G.hasSpeciesDrone(drone_species) then
            table.insert(validation_failures, "Drone " .. drone_species .. " not available")
            success = false
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
    
    -- Enhanced mock executeAccumulationCycle with validation
    _G.executeAccumulationCycle = function(species)
        local success = true
        local error_message = nil
        
        -- Simulate validation checks
        if not _G.hasSpeciesPrincess(species) then
            success = false
            error_message = "Princess " .. species .. " not available for accumulation"
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
    
    -- Test cases for executeBreedingTree
    local tree_test_cases = {
        {
            name = "Simple single-step breeding (Modest)",
            target = "Modest",
            expected_steps = 1,
            expected_accumulation = 0
        },
        {
            name = "Two-step breeding chain (Cultivated)",
            target = "Cultivated", 
            expected_steps = 2,
            expected_accumulation = 0 -- Assuming we have enough drones
        },
        {
            name = "Complex multi-step breeding (Imperial)",
            target = "Imperial",
            expected_steps = 4, -- Common, Cultivated, Noble, Majestic, Imperial
            expected_accumulation = 0 -- Assuming adequate drone supply
        }
    }
    
    local test_results = {}
    
    for _, test_case in ipairs(tree_test_cases) do
        print("\n--- Testing: " .. test_case.name .. " ---")
        
        -- Reset test state
        execution_log = {}
        breeding_steps = 0
        accumulation_cycles = 0
        
        -- Set up inventory with base bees and some intermediates
        test_inventory.princesses = {"Forest", "Meadows", "Common", "Modest"}
        test_inventory.drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble"}
        
        -- Calculate breeding plan
        local plan = main.calculateBreedingPath and main.calculateBreedingPath(test_case.target)
        
        if not plan or plan.plan_failed then
            print("  ❌ Planning failed for " .. test_case.target)
            test_results[test_case.name] = {success = false, reason = "Planning failed"}
            
            -- Dump planning failure analysis
            dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles, 
                                false, "Planning failed - no breeding path found", "planning_failure")
        else
            print("  ✅ Plan generated: " .. plan.total_steps .. " steps")
            
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
            
            -- Check if executeBreedingTree function exists
            if not main.executeBreedingTree then
                table.insert(execution_log, {
                    type = "function_missing",
                    message = "executeBreedingTree function not exported from main.lua",
                    success = false,
                    error_message = "executeBreedingTree function not available - check main.lua exports"
                })
                print("  ❌ executeBreedingTree function not found in main.lua exports")
                success = false
                error_msg = nil
            else
                -- Execute the breeding tree with error handling
                local success_pcall, error_msg = pcall(function()
                    return main.executeBreedingTree(
                        plan.tree, 
                        plan.drone_requirements, 
                        false, -- hasAPI = false (no Gendustry)
                        plan.total_steps
                    )
                end)
                
                if not success_pcall then
                    success = false
                    error_msg = error_msg
                else
                    success = error_msg  -- pcall returns (true, result)
                    error_msg = nil
                end
            end
            
            if error_msg then
                -- Capture exception in execution log
                table.insert(execution_log, {
                    type = "execution_exception",
                    message = "executeBreedingTree threw exception: " .. tostring(error_msg),
                    success = false,
                    error_message = tostring(error_msg),
                    exception_details = tostring(error_msg)
                })
                print("  ❌ executeBreedingTree threw exception")
            elseif main.executeBreedingTree then
                -- Capture execution result in log
                table.insert(execution_log, {
                    type = "execution_result",
                    returned_value = success,
                    success = success == true,
                    error_message = success ~= true and "executeBreedingTree returned " .. tostring(success) or nil
                })
            end
            
            -- Analyze execution results
            local failed_steps = 0
            local failure_reasons = {}
            local gui_errors = {}
            
            for _, log_entry in ipairs(execution_log) do
                if not log_entry.success then
                    failed_steps = failed_steps + 1
                    if log_entry.error_message then
                        table.insert(failure_reasons, log_entry.error_message)
                    end
                    if log_entry.type == "gui_error" then
                        table.insert(gui_errors, log_entry.message)
                    end
                end
            end
            
            -- If no specific failure reasons but we have GUI errors, use those
            if #failure_reasons == 0 and #gui_errors > 0 then
                failure_reasons = gui_errors
            end
            
            -- If we still have no failure reasons but execution failed, check the execution result
            if #failure_reasons == 0 and not success then
                table.insert(failure_reasons, "executeBreedingTree returned false without specific error details")
            end
            
            if success then
                print("  ✅ Tree execution completed successfully")
                print("    Breeding steps executed: " .. breeding_steps)
                print("    Accumulation cycles: " .. accumulation_cycles)
                if failed_steps > 0 then
                    print("    ⚠️  " .. failed_steps .. " steps had issues but execution continued")
                    print("    Issues: " .. (#failure_reasons > 0 and table.concat(failure_reasons, "; ") or "unspecified"))
                end
                
                -- Verify execution order (should be post-order traversal)
                local breeding_targets = {}
                for _, log_entry in ipairs(execution_log) do
                    if log_entry.type == "breeding" and log_entry.success then
                        table.insert(breeding_targets, log_entry.target)
                    end
                end
                
                print("    Breeding sequence: " .. (#breeding_targets > 0 and table.concat(breeding_targets, " -> ") or "none"))
                
                -- Check if final target was bred
                if #breeding_targets > 0 and breeding_targets[#breeding_targets] == test_case.target then
                    print("    ✅ Final target " .. test_case.target .. " was bred correctly")
                    test_results[test_case.name] = {
                        success = true, 
                        steps = breeding_steps,
                        accumulation = accumulation_cycles,
                        sequence = breeding_targets,
                        failed_steps = failed_steps
                    }
                    
                    -- Dump successful execution analysis
                    dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles, 
                                        true, nil, "success")
                else
                    print("    ❌ Final target " .. test_case.target .. " was not bred correctly")
                    test_results[test_case.name] = {success = false, reason = "Wrong breeding sequence", failed_steps = failed_steps}
                    
                    -- Dump sequence failure analysis
                    dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles, 
                                        false, "Wrong breeding sequence - final target not produced", "sequence_failure")
                end
            else
                print("  ❌ Tree execution failed")
                print("    Failed steps: " .. failed_steps .. "/" .. (breeding_steps + accumulation_cycles))
                print("    Execution log entries: " .. #execution_log)
                
                if #failure_reasons > 0 then
                    print("    Primary failure: " .. failure_reasons[1])
                else
                    print("    ⚠️  No specific failure reasons captured in mocks")
                    print("    📁 Check execution artifact for detailed debugging information")
                end
                
                test_results[test_case.name] = {
                    success = false, 
                    reason = "Execution failed", 
                    failed_steps = failed_steps,
                    total_attempts = breeding_steps + accumulation_cycles
                }
                
                -- Determine primary failure reason for artifact
                local primary_failure
                if #failure_reasons > 0 then
                    primary_failure = failure_reasons[1]
                else
                    primary_failure = "executeBreedingTree returned false - see detailed execution log for debugging information"
                end
                
                dumpExecutionAnalysis(test_case.target, execution_log, breeding_steps, accumulation_cycles, 
                                    false, primary_failure, "execution_failure")
            end
        end
    end
    
    -- Restore original functions
    _G.executeSingleBreedingStep = original_executeSingleBreedingStep
    _G.executeAccumulationCycle = original_executeAccumulationCycle
    _G.drawGUI = original_drawGUI
    _G.updateStatusIndicators = original_updateStatusIndicators
    
    -- Test results summary
    print("\n=== executeBreedingTree Test Results ===")
    local passed = 0
    local total = #tree_test_cases
    
    for _, test_case in ipairs(tree_test_cases) do
        local result = test_results[test_case.name]
        if result and result.success then
            passed = passed + 1
            local details = " - " .. result.steps .. " steps"
            if result.failed_steps and result.failed_steps > 0 then
                details = details .. " (" .. result.failed_steps .. " issues resolved)"
            end
            print("✅ " .. test_case.name .. details)
        else
            local reason = result and result.reason or "Unknown error"
            local details = ""
            if result and result.failed_steps then
                details = " (" .. result.failed_steps .. "/" .. (result.total_attempts or "?") .. " steps failed)"
            end
            print("❌ " .. test_case.name .. " - " .. reason .. details)
        end
    end
    
    print("Results: " .. passed .. "/" .. total .. " tests passed")
    print()
    print("📁 Comprehensive execution analysis written to Artifacts/ folder:")
    print("   - Each test creates a detailed *_execution_*.txt file")
    print("   - Files include: setup info, GUI calls, status updates, and failure analysis")
    print("   - Debug information shows exactly what executeBreedingTree received and returned")
    print("   - Failure artifacts explain why execution failed and what to check")
    print()
    
    return passed == total, test_results
end

-- Test error handling in executeBreedingTree
local function testExecuteBreedingTreeErrorHandling()
    print("=== Testing executeBreedingTree Error Handling ===")
    
    -- Mock functions that can fail
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
    
    -- Test case 1: Breeding step failure
    print("\n--- Test 1: Breeding Step Failure ---")
    _G.executeSingleBreedingStep = function(princess, drone, target, hasAPI)
        local error_msg = "Mock breeding failure: insufficient materials for " .. target
        
        -- Log the failure attempt
        table.insert(error_execution_log, {
            type = "breeding",
            princess = princess,
            drone = drone,
            target = target,
            hasAPI = hasAPI,
            success = false,
            error_message = error_msg,
            validation_failures = {"Insufficient materials", "Mutatron unavailable"}
        })
        
        return false -- Simulate failure
    end
    
    -- Set up simple test case
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows"}
    
    local plan = main.calculateBreedingPath and main.calculateBreedingPath("Modest")
    if plan and not plan.plan_failed then
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
            print("  ✅ Error handling worked - breeding tree execution failed as expected")
            
            -- Check if error was displayed in GUI
            local error_displayed = false
            local error_messages = {}
            for _, call in ipairs(gui_calls) do
                if call.errors then
                    table.insert(error_messages, call.errors)
                    if string.find(call.errors, "Could not complete breeding step") then
                        error_displayed = true
                    end
                end
            end
            
            if error_displayed then
                print("  ✅ Error message was properly displayed in GUI")
            else
                print("  ❌ Error message was not displayed in GUI")
                print("    Available error messages: " .. (#error_messages > 0 and table.concat(error_messages, "; ") or "none"))
            end
            
            -- Dump error handling analysis
            dumpExecutionAnalysis("Modest", error_execution_log, 1, 0, false, 
                                "Intentional breeding step failure for error handling test", "error_handling")
            
        else
            print("  ❌ Error handling failed - execution should have failed")
            
            -- Dump unexpected success analysis
            dumpExecutionAnalysis("Modest", error_execution_log, 1, 0, true, 
                                "Unexpected success - error handling test should have failed", "error_handling_unexpected")
        end
    else
        print("  ❌ Could not generate plan for error testing")
        
        -- Dump planning failure for error test
        dumpExecutionAnalysis("Modest", error_execution_log, 0, 0, false, 
                            "Could not generate breeding plan for error handling test", "error_test_planning_failure")
    end
    
    -- Test case 2: Multiple failure scenarios
    print("\n--- Test 2: Multiple Failure Types ---")
    error_execution_log = {}  -- Reset log
    
    -- Test with a more complex target that would have multiple steps
    test_inventory.princesses = {"Forest", "Meadows"}
    test_inventory.drones = {"Forest", "Meadows"}
    
    local failure_count = 0
    _G.executeSingleBreedingStep = function(princess, drone, target, hasAPI)
        failure_count = failure_count + 1
        local failure_types = {
            "Mutatron jammed",
            "Insufficient bee lifespan", 
            "Wrong mutation result",
            "Apiary contamination",
            "Power failure"
        }
        
        local error_msg = failure_types[((failure_count - 1) % #failure_types) + 1]
        
        table.insert(error_execution_log, {
            type = "breeding",
            princess = princess,
            drone = drone,
            target = target,
            hasAPI = hasAPI,
            success = false,
            error_message = error_msg,
            step_number = failure_count
        })
        
        return false
    end
    
    local complex_plan = main.calculateBreedingPath and main.calculateBreedingPath("Cultivated")
    if complex_plan and not complex_plan.plan_failed then
        _G.gui_state.target = "Cultivated"
        _G.gui_state.current_step = 0
        
        local complex_success = main.executeBreedingTree and main.executeBreedingTree(
            complex_plan.tree,
            complex_plan.drone_requirements,
            false,
            complex_plan.total_steps
        )
        
        if not complex_success then
            print("  ✅ Complex execution properly failed after " .. failure_count .. " attempts")
            
            -- Dump complex failure analysis
            dumpExecutionAnalysis("Cultivated", error_execution_log, failure_count, 0, false, 
                                "Multiple consecutive breeding failures with different error types", "complex_failures")
        else
            print("  ❌ Complex execution should have failed")
            
            dumpExecutionAnalysis("Cultivated", error_execution_log, failure_count, 0, true, 
                                "Unexpected success in complex failure test", "complex_failures_unexpected")
        end
    else
        print("  ❌ Could not generate complex plan for multi-failure testing")
    end
    
    -- Restore original functions
    _G.executeSingleBreedingStep = original_executeSingleBreedingStep
    _G.drawGUI = original_drawGUI
    
    print("Error handling test completed")
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
    print("   - All failure scenarios include specific error messages and validation details")
    
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
