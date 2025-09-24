-- HiveMind Planning System Test Suite
-- Tests breeding tree calculation, golden path logic, and drone accumulation
-- Imports actual functions from main.lua to ensure consistency

-- Import the main module
-- FIXME: main uses OC component, which isn't available in test environment
-- So we need to mock component and inventory functions it uses
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

-- Mock the inventory functions that main.lua uses
local function mockInventoryFunctions()
    -- Override the inventory checking functions for testing
    _G.inventory = test_inventory
    
    -- Mock hasSpeciesPrincess function
    _G.hasSpeciesPrincess = function(species)
        for _, princess in ipairs(test_inventory.princesses) do
            if princess == species then
                return true
            end
        end
        return false
    end
    
    -- Mock hasSpeciesDrone function  
    _G.hasSpeciesDrone = function(species)
        for _, drone in ipairs(test_inventory.drones) do
            if drone == species then
                return true
            end
        end
        return false
    end
    
    -- Mock findBeeInInventory for validation functions
    _G.findBeeInInventory = function(species, bee_type)
        local inventory_list = bee_type == "princess" and test_inventory.princesses or test_inventory.drones
        for _, available_species in ipairs(inventory_list) do
            if available_species == species then
                return {side = 1, slot = 1} -- Mock location
            end
        end
        return nil
    end
end

-- Initialize mocking
mockInventoryFunctions()

-- Test Cases
local test_cases = {
    {
        name = "Simple two-parent breeding",
        target = "Modest", 
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows"},
        expected_steps = 1,
        expected_starting_princesses = {"Forest"},
        expected_drone_requirements = {["Meadows"] = 1},
        should_succeed = true
    },
    
    {
        name = "Three-generation breeding chain",
        target = "Cultivated",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest"},
        expected_steps = 3, -- Forest+Meadows->Common, Forest+Meadows->Modest, Common+Modest->Cultivated
        expected_starting_princesses = {"Forest"},
        expected_drone_requirements = {["Meadows"] = 2, ["Modest"] = 1}, -- Need Meadows for both Common and Modest, then Modest for Cultivated
        should_succeed = true
    },
    
    {
        name = "Complex Imperial breeding",
        target = "Imperial",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Majestic"},
        expected_steps = 6, -- Long chain: Forest->...->Imperial
        expected_starting_princesses = {"Forest"},
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
        expected_steps = 5, -- Build Common, Cultivated, Diligent, Unweary, then Industrious
        expected_starting_princesses = {"Forest"},
        should_succeed = true
    },
    
    {
        name = "Cross-mod breeding (MagicBees)",
        target = "Mystical",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble"},
        expected_steps = 4, -- Build path to Noble, then Noble+Modest->Mystical
        expected_starting_princesses = {"Forest"},
        should_succeed = true
    },
    
    {
        name = "Complex multi-mod chain",
        target = "Supernatural",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Noble", "Mystical", "Sorcerous", "Unusual"},
        expected_steps = 7, -- Very long chain crossing multiple mods
        expected_starting_princesses = {"Forest"},
        should_succeed = true
    },
    
    -- TODO: add more case with complex chains (the ones from MeatballCraft)

    {
        name = "Heroic branch with complex dependencies",
        target = "Heroic",
        available_princesses = {"Forest", "Meadows"},
        available_drones = {"Forest", "Meadows", "Common", "Modest", "Cultivated", "Diligent", "Valiant", "Steadfast"},
        expected_steps = 6, -- Complex tree with multiple branches
        expected_starting_princesses = {"Forest"},
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

-- Test execution framework
local function runTest(test_case)
    print("Running test: " .. test_case.name)
    
    -- Set up test inventory
    test_inventory.princesses = test_case.available_princesses or {}
    test_inventory.drones = test_case.available_drones or {}
    
    -- Execute planning using actual main.lua functions
    local plan = main.calculateBreedingPath and main.calculateBreedingPath(test_case.target)
    
    -- Check results
    local success = true
    local messages = {}
    
    if test_case.should_succeed then
        if not plan then
            success = false
            table.insert(messages, "  ❌ Planning failed when it should succeed")
        else
            print("  ✅ Planning succeeded")
            
            -- Check expected steps
            if test_case.expected_steps and plan.total_steps ~= test_case.expected_steps then
                success = false
                table.insert(messages, "  ❌ Expected " .. test_case.expected_steps .. " steps, got " .. plan.total_steps)
            else
                table.insert(messages, "  ✅ Step count correct: " .. plan.total_steps)
            end
            
            -- Check starting princesses
            if test_case.expected_starting_princesses then
                local expected_set = {}
                for _, species in ipairs(test_case.expected_starting_princesses) do
                    expected_set[species] = true
                end
                
                local actual_set = {}
                for _, species in ipairs(plan.starting_princesses) do
                    actual_set[species] = true
                end
                
                local princesses_match = true
                for species, _ in pairs(expected_set) do
                    if not actual_set[species] then
                        princesses_match = false
                        break
                    end
                end
                for species, _ in pairs(actual_set) do
                    if not expected_set[species] then
                        princesses_match = false
                        break
                    end
                end
                
                if princesses_match then
                    table.insert(messages, "  ✅ Starting princesses correct: " .. table.concat(plan.starting_princesses, ", "))
                else
                    success = false
                    table.insert(messages, "  ❌ Starting princesses mismatch")
                    table.insert(messages, "    Expected: " .. table.concat(test_case.expected_starting_princesses, ", "))
                    table.insert(messages, "    Got: " .. table.concat(plan.starting_princesses, ", "))
                end
            end
            
            -- Check drone requirements  
            if test_case.expected_drone_requirements then
                local requirements_match = true
                for species, expected_count in pairs(test_case.expected_drone_requirements) do
                    local actual_count = plan.drone_requirements[species] or 0
                    if actual_count ~= expected_count then
                        requirements_match = false
                        success = false
                        table.insert(messages, "  ❌ Drone requirement mismatch for " .. species .. ": expected " .. expected_count .. ", got " .. actual_count)
                    end
                end
                
                if requirements_match then
                    table.insert(messages, "  ✅ Drone requirements correct")
                end
            end
        end
    else
        if plan then
            success = false
            table.insert(messages, "  ❌ Planning succeeded when it should fail")
        else
            table.insert(messages, "  ✅ Planning correctly failed")
        end
    end
    
    -- Print all messages
    for _, message in ipairs(messages) do
        print(message)
    end
    
    print()
    return success
end

-- Main test runner
local function runAllTests()
    print("=== HiveMind Planning System Test Suite ===")
    print("Testing with actual functions from main.lua")
    print()
    
    local total_tests = #test_cases
    local passed_tests = 0
    
    for _, test_case in ipairs(test_cases) do
        if runTest(test_case) then
            passed_tests = passed_tests + 1
        end
    end
    
    print("=== Test Results ===")
    print("Total tests: " .. total_tests)
    print("Passed: " .. passed_tests)
    print("Failed: " .. (total_tests - passed_tests))
    
    if passed_tests == total_tests then
        print("🎉 All tests passed!")
    else
        print("❌ Some tests failed. Check output above for details.")
    end
    
    return passed_tests == total_tests
end

-- Tree visualization using main.lua function
local function printBreedingTree(tree)
    if main.printBreedingTree then
        main.printBreedingTree(tree)
    else
        print("Tree visualization not available (printBreedingTree not exported from main.lua)")
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
    
    if not plan then
        print("❌ Cannot breed " .. target)
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
    for species, count in pairs(plan.drone_requirements) do
        print("  " .. species .. ": " .. count .. " drones")
    end
    print()
    
    print("Breeding tree:")
    printBreedingTree(plan.tree)
    print()
    
    return true
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

-- Run tests automatically if executed directly
if ... == nil then
    print("Running planning tests automatically...")
    print()
    runAllTests()
    print()
    performanceTest()
    
    print()
    print("=== Example Usage ===")
    print("To test a specific target: testSpecificTarget('Imperial')")
    print("To run performance tests: performanceTest()")
    print("To run individual test: runTest(test_cases[1])")
end

-- Export functions for interactive use
return {
    runAllTests = runAllTests,
    runTest = runTest,
    testSpecificTarget = testSpecificTarget,
    performanceTest = performanceTest,
    test_cases = test_cases
}
