# Basic Example

This example demonstrates the core features of Ash ECS through a simple RPG-like scenario.

## What This Showcases

- **Entity spawning**: Creating entities with multiple components
- **Tag components**: Zero-size components as markers (Player, Enemy, Poisoned)
- **Query filtering**: Finding entities by component combinations
- **Exclude filters**: Finding entities that DON'T have certain components
- **Component manipulation**: Adding, reading, and modifying components
- **Entity removal**: Despawning entities based on game logic

## Key Concepts

### Normal Components

```odin
Name :: struct {
    value: string
}

Health :: struct {
    current: int,
    max:	 int,
}

Position :: struct {
    x, y: f32
}
```

### Tag Components
Zero-size structs act as markers/flags:
```odin
Player :: struct {}   // Marks the player entity
Enemy :: struct {}    // Marks enemy entities
Poisoned :: struct {} // Status effect marker
```

### Entity Creation with Components
```odin
player := ash.world_spawn(&world,
    Name{"Hero"},
    Health{current = 100, max = 100},
    Position{0, 0},
    Player{},  // Tag component
)
```

### Query Patterns

**Find all entities with Health:**
```odin
filter := ash.filter_contains(&world, {Health})
```

**Find enemies only:**
```odin
filter := ash.filter_contains(&world, {Enemy, Name})
```

**Find entities WITHOUT a component:**
```odin
filter := ash.filter_create(&world, 
    requires = {Enemy}, 
    excludes = {Poisoned},
)
```

### Safe Entity Removal
Can't remove during iteration (world locked), so queue removal instead.
```odin
it := ash.query_iter(query)
for entry in ash.query_next(&it) {
    if should_remove(entry) {
        // Queue for removal
        ash.entry_queue_despawn(entry)
    }
}

// After iteration, remove safely
ash.world_flush_queue(&world)
```

## Running

```bash
cd examples/01_basic
odin run .
```