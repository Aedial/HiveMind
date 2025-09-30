-- Simple example of testing a specific bee breeding path
-- This demonstrates how to use the HiveMind test suite to analyze breeding chains

-- Import the test planning module
local test_planning = require("test_planning")

-- Example 1: Test a simple bee (Modest)
print("=== Example 1: Testing Modest Bee ===")
local success = test_planning.testSpecificTarget("Modest")
if success then
    print("✅ Modest breeding path is viable")
else
    print("❌ Modest breeding path has issues")
end
print()

-- Example 2: Test a complex bee (Imperial)
print("=== Example 2: Testing Imperial Bee ===")
success = test_planning.testSpecificTarget("Imperial")
if success then
    print("✅ Imperial breeding path is viable")
else
    print("❌ Imperial breeding path has issues")
end
print()

-- Example 3: Test a cross-mod bee (Mystical from MagicBees)
print("=== Example 3: Testing Mystical Bee (MagicBees) ===")
success = test_planning.testSpecificTarget("Mystical")
if success then
    print("✅ Mystical breeding path is viable")
else
    print("❌ Mystical breeding path has issues - check Artifacts/Mystical_analysis.txt")
end
print()

-- Example 4: Test a very complex custom bee
print("=== Example 4: Testing ChaosStrikez (Custom) ===")
success = test_planning.testSpecificTarget("ChaosStrikez")
if success then
    print("✅ ChaosStrikez breeding path is viable")
else
    print("❌ ChaosStrikez breeding path has issues - check Artifacts/ChaosStrikez_analysis.txt")
end
print()

print("📁 Analysis Results:")
print("   - Check the Artifacts/ folder for detailed breeding analysis files")
print("   - Each bee gets a *_analysis.txt file with:")
print("     • Complete breeding tree visualization")
print("     • Required starting princesses and drones")
print("     • Step-by-step breeding sequence")
print("     • Missing species identification")
print("     • Optimization recommendations")
print()

print("🔧 Advanced Testing:")
print("   - Use test_planning.runAllTests() to run the full test suite")
print("   - Use test_planning.testExecuteBreedingTree() to test actual execution")
print("   - Use test_planning.complexityStressTest() for extreme breeding chains")
print()

-- Show how to access other test functions
print("💡 Available Test Functions:")
print("   test_planning.testSpecificTarget(bee_name)     - Test single bee breeding path")
print("   test_planning.runAllTests()                    - Run all planning tests")
print("   test_planning.runAllTestsComplete()            - Run planning + execution tests")
print("   test_planning.performanceTest()                - Test calculation performance")
print("   test_planning.complexityStressTest()           - Test complex multi-mod chains")
print("   test_planning.testExecuteBreedingTree()        - Test breeding execution")
print()
