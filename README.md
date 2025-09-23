# Beesness: Automated Bee Breeding System

An OpenComputers program for automating bee breeding using Forestry, Gendustry, and related mods. The system calculates optimal breeding paths and executes them automatically using Advanced Mutatron and Industrial Apiary setups.

## Features

- Automated breeding path calculation with golden path strategy
- Support for hundreds of bee species across multiple mods (Forestry, MagicBees, ExtraBees)
- Drone accumulation and resource management
- Automatic item movement between machines
- Gendustry API integration with redstone fallback
- Comprehensive inventory scanning and management

## Hardware Requirements

### Essential Components
- OpenComputers computer with Inventory Controller upgrade
- Advanced Mutatron (Gendustry)
- Industrial Apiary (Forestry)
- Mechanical User (Extra Utilities or similar)
- Beebee gun with Assassin Queen (for Mechanical User)
- Input chest (for starting materials)
- Output chest (for products)
- Redstone connection to Mechanical User

### Optional Components
- OpenComputers Adapter blocks (for Gendustry API access)
- Additional storage chests
- Power supply for machines

## Physical Setup

### Machine Layout
Place blocks adjacent to the computer according to this configuration:

```
    [Storage]
        |
[Input] - [Computer] - [Mechanical User]
        |
   [Advanced Mutatron]
        |
  [Industrial Apiary]
        |
    [Output]
```

### Side Configuration
Default sides (configurable in code):
- Left: Input chest
- Front: Advanced Mutatron
- Back: Industrial Apiary
- Bottom: Output chest
- Right: Mechanical User (redstone connection)

### Wiring
1. Connect Mechanical User to computer with redstone
2. Position Mechanical User to activate the Industrial Apiary
3. Place beebee gun with Assassin Queen in Mechanical User's inventory slot 1
4. Ensure all machines have adequate power
5. Connect Adapter blocks to Gendustry machines for API access (optional)

## Software Installation

1. Place the main.lua file on the computer's filesystem
2. Ensure the computer has an Inventory Controller upgrade installed
3. Run the program with: `lua main.lua`

## Configuration

Edit the config table in main.lua to match your setup:

```lua
local config = {
    mech_user_side = sides.right,     -- Mechanical User redstone side
    mutatron_side = sides.front,      -- Advanced Mutatron location
    apiary_side = sides.back,         -- Industrial Apiary location
    input_chest_side = sides.left,    -- Input chest location
    output_chest_side = sides.down,   -- Output chest location
    apiary_wait_time = 30,            -- Apiary processing time (seconds)
    beebee_gun_slot = 1,              -- Beebee gun slot in Mechanical User
    -- Additional slot configurations available
}
```

## Usage

### Initial Setup
1. Place starting bee species (Forest, Meadows princesses and drones) in input chest
2. Ensure beebee gun with Assassin Queen is in Mechanical User slot 1
3. Ensure machines are powered and properly configured
4. Run the program

### Operation
1. The program scans all connected inventories for available bees
2. Select target bee species from the menu (supports filtering by mod)
3. Review the generated breeding strategy showing:
   - Golden path (main princess lineage)
   - Required drone paths
   - Accumulation cycles needed
4. Confirm execution to start automated breeding

### Breeding Strategy
The program uses a three-phase approach:
1. Breed required drone species first
2. Run accumulation cycles to build drone reserves
3. Execute golden path using accumulated resources

## Supported Mods

- Forestry (base bees and mutations)
- MagicBees (mystical and thaumic species)
- ExtraBees/Binnie's Mods (industrial, stone, color variants)
- Gendustry (automation and genetic manipulation)

The bee database contains mutation data for 80+ species and can be extended by modifying the loadBeeDatabase() function.

## Troubleshooting

### Common Issues
- "Inventory Controller upgrade required": Install the upgrade in the computer
- "No inventories found": Check that chests are adjacent to computer
- "Could not find X bee": Ensure required parent species are available in input/output chests
- "Waiting for beebee gun": Gun is missing or being recharged - program will wait automatically
- API failures: Verify Adapter blocks are connected to Gendustry machines

### Machine Problems
- Mutatron not producing queens: Check power, materials, and activation
- Apiary not processing: Verify environment, power, and queen placement
- Items not moving: Confirm inventory controller has access to all sides

### Performance
- Large breeding trees may take significant time to complete
- Adjust apiary_wait_time based on your apiary's speed
- Consider running accumulation cycles during off-peak times

## Technical Details

### Breeding Algorithm
The system traces back from target species to find the shortest mutation path, then plans drone acquisition separately. This prevents resource conflicts and ensures all required materials are available before starting the golden path.

### Resource Management
All produced queens and drones are automatically tracked and made available for future breeding steps. The system can pull materials from input chest, output chest, and any connected storage. The program automatically waits for the beebee gun to be available before activating the Mechanical User, handling charging cycles seamlessly.

### API Integration
If Gendustry API is available through Adapter blocks, the program will attempt to use it for enhanced machine control. Otherwise, it falls back to redstone activation via Mechanical User.

## Limitations

- Requires manual setup of physical machine layout
- Processing time depends on apiary efficiency and power supply
- Some advanced bee species may require specific environmental conditions
- Cross-mod compatibility depends on installed mods and versions