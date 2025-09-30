# HiveMind: Automated Bee Breeding System

An OpenComputers program for automating bee breeding using Forestry, Gendustry, and related mods. The system calculates optimal breeding paths and executes them automatically using Advanced Mutatron and Industrial Apiary setups.

## Quick Start

1. **Installation**: Copy `main.lua` to your OpenComputers computer
2. **Testing Setup**: Run `./setup-precommit.sh` (Linux/Mac) or `setup-precommit.bat` (Windows)
3. **Usage**: Execute with `lua main.lua` and follow the interactive menu

📖 See [TESTING.md](TESTING.md) for the full test guide and developer workflow.

## Features

- Automated breeding path calculation with golden path strategy
- Support for hundreds of bee species across multiple mods (Forestry, MagicBees, ExtraBees, Career Bees, MeatballCraft)
- Drone accumulation and resource management
- Automatic item movement between machines
- Gendustry API integration with redstone fallback
- Comprehensive inventory scanning and management
- Optional status lamp and chat notifications
- Complete test suite with breeding path analysis and execution validation

## Hardware Requirements

### Essential Components
- OpenComputers computer with Inventory Controller upgrade
- Advanced Mutatron (Gendustry)
- Industrial Apiary (Gendustry)
- Mechanical User (Extra Utilities or similar)
- Beebee gun with Assassin Queen (for Mechanical User)
- Input inventory (for starting materials)
- Output inventory (for products)
- Redstone connection to Mechanical User

### Optional Components
- OpenComputers Adapter blocks (for Gendustry API access)
- Additional storage chests
- Power supply for machines
- Colored Lamp (OpenLights mod recommended, or similar programmable lighting)
- Notification Interface from Random Things (for chat notifications)

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
    enabled_mods = {"Forestry", "MagicBees", "ExtraBees", "Career Bees", "MeatballCraft"}, -- Limit included mods
}
```

Tip: Use enabled_mods to restrict which mods’ species are considered when planning.

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

### Status Indicators

#### Colored Lamp Status
When a programmable colored lamp is connected, it displays the current system status:

Compatible Mods:
- OpenLights (recommended - has `coloredlamp` component)
- Any mod exposing a `setLampColor()`-like API

Status Colors:
- White - Idle/Ready for commands
- Green - Working normally (breeding, processing)
- Yellow - Waiting for resources (beebee gun, materials)
- Red - Error state (requires user intervention)
- Orange - Manually paused
- Blue - Task completed successfully
- Purple - Operation aborted by user

#### Chat Notifications
When a Notification Interface is connected, the system sends important status updates:
- System startup and breeding sequence start
- Error messages with details
- Major completion notifications
- User action confirmations (resume, abort)

Configure in main.lua:
```lua
config.use_status_lamp = true
config.use_chat_notifications = true
config.chat_player_name = nil -- Broadcast to all (or set specific player)
```

## Testing and Analysis

For developer tests, run the planning and execution test suite and view analysis artifacts. See TESTING.md for commands and details.

### Analysis Artifacts
Tests generate detailed analysis files in the `Artifacts/` folder (auto-created on first test run):

- `BeeSpecies_analysis.txt` — Complete breeding tree analysis
  - Visual breeding tree with dependency hints
  - Required starting princesses and drone counts
  - Missing species identification
  - Optimization recommendations and sanity checks

- `BeeSpecies_execution_*.txt` — Execution testing results
  - Detailed execution logs with GUI interactions
  - Breeding step validation and failure analysis
  - Mock function call traces for debugging
  - Performance metrics and timing information

## Supported Mods

- Forestry (base bees and mutations)
- MagicBees (mystical and thaumic species)
- ExtraBees/Binnie's Mods (industrial, stone, color variants)
- Career Bees (job-themed species)
- MeatballCraft (custom chains and late-game species)
- Gendustry (automation and genetic manipulation)

The bee database is defined in `loadBeeDatabase()` in `main.lua` and can be extended.

## Troubleshooting

### Common Issues
- "Inventory Controller upgrade required": Install the upgrade in the computer
- "No inventories found": Check that chests are adjacent to computer
- "Could not find X bee": Ensure required parent species are available in input/output chests
- "Waiting for beebee gun": Gun is missing or being recharged — program will wait automatically
- API failures: Verify Adapter blocks are connected to Gendustry machines

### Machine Problems
- Mutatron not producing queens: Check power, materials, and activation
- Apiary not processing: Verify environment, power, and queen placement
- Items not moving: Confirm inventory controller has access to all sides

### Performance
- Large breeding trees may take some time to complete
- Adjust `apiary_wait_time` based on your apiary's speed
- Consider running accumulation cycles during off-peak times

## Technical Details

### Breeding Algorithm
The system builds a complete parent tree for the target, then applies stock-aware pruning and reuse optimizations to minimize steps while keeping execution feasible.

### Resource Management
Produced queens and drones are tracked and reused. Materials can be sourced from input/output chests and adjacent storage. The program automatically waits for the beebee gun before activating the Mechanical User.

### API Integration
If Gendustry API is available via Adapter blocks, the program uses it for machine control; otherwise it falls back to redstone activation through the Mechanical User.

## Limitations

- Requires manual setup of physical machine layout
- Processing time depends on apiary efficiency and power supply
- Some advanced bee species may require specific environmental conditions
- Cross-mod compatibility depends on installed mods and versions
