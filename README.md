# Ash ECS

Ash is a fast, type-safe, archetype-based Entity Component System written in Odin.

## Features

- **Archetype-based storage** for cache-efficient iteration
- **Type-safe API** with compile-time component type checking
- **O(1) entity spawning and despawning** with entity recycling and generational IDs
- **Flexible queries** with requires, excludes, and anyof filters
- **Bulk iteration** for maximum performance
- **Command queue** for safe deferred operations during iteration
- **Observers** for reacting to entity/component lifecycle events
- **Resources** for storing global singleton data
- **Custom allocator support** throughout

## Installation

Clone into your project:
```bash
git subtree add --prefix=libs/ash --squash https://github.com/hosein1984/ash.git main
```

Then import:
```odin
import "libs:ash"
```

## Quick Start
```odin
import "ash"

// Define components
Position :: struct { x, y: f32 }
Velocity :: struct { x, y: f32 }

main :: proc() {
    // Create world
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    // Spawn entities with components
    ash.world_spawn(&world, Position{0, 0}, Velocity{1, 0})
    ash.world_spawn(&world, Position{10, 5}, Velocity{0, 1})
    ash.world_spawn(&world, Position{-5, 3}) // No velocity

    // Query and iterate
    filter := ash.filter_contains(&world, {Position, Velocity})
    query := ash.world_query(&world, filter)

    it := ash.query_iter(query)
    for entry in ash.query_next(&it) {
        pos := ash.entry_get(entry, Position)
        vel := ash.entry_get(entry, Velocity)
        pos.x += vel.x
        pos.y += vel.y
    }
}
```

## Core Concepts

### Entity

An entity is a unique 64-bit identifier (32-bit ID + 32-bit generation). The generation increments when an entity is destroyed/recycled, ensuring stale references are detected:

```odin
entity := ash.world_spawn(&world)
ash.world_despawn(&world, entity)

// Entity ID is recycled but generation changes
new_entity := ash.world_spawn(&world)
assert(entity != new_entity) // Different generation
```

Here's the corrected section:

### Components

Components are plain Odin structs:

```odin
Position :: struct { x, y: f32 }
Health   :: struct { current, max: i32 }
Tag      :: struct {}                     // Zero-size tags supported
```

Components can be registered manually or auto-registered when first used:

```odin
// Manual registration (optional)
pos_id := ash.world_register(&world, Position)
vel_id := ash.world_register(&world, Velocity)

// Or just use them - auto-registered on first use
entity := ash.world_spawn(&world, Position{0, 0}, Health{100, 100}, Tag{})
```

Manual registration is useful when you need component IDs upfront for bulk iteration:

```odin
// Cache IDs before the loop
pos_id := ash.world_register(&world, Position)
vel_id := ash.world_register(&world, Velocity)

// Or query IDs
pos_id := ash.world_get_component_id(&world, Position)
vel_id := ash.world_get_component_id(&world, Velocity)

it := ash.query_iter_archs(query)
for arch in ash.query_next_arch(&it) {
    positions  := ash.archetype_slice(arch, Position, pos_id)
    velocities := ash.archetype_slice(arch, Velocity, vel_id)
    // ...
}
```

### World Entry

An entry is a lightweight handle for accessing an entity's components. It caches the entity's location internally, making multiple component operations efficient without repeated lookups.

```odin
entry := ash.world_entry(&world, entity)

// Check if entity has component
if ash.entry_has(entry, Position) {
    pos := ash.entry_get(entry, Position)
    pos.x += 10
}

// Add component
ash.entry_set(&entry, Velocity{1, 0})

// Remove component
ash.entry_remove(&entry, Velocity)
```

### Queries

Query entities matching component filters:

```odin
// Entities with Position AND Velocity
filter := ash.filter_contains(&world, {Position, Velocity})

// Entities with Position but NOT Poison
filter := ash.filter_create(&world, requires = {Position}, excludes = {Poison})

// Entities with Position and at least one of Sprite, Text, or Shape
filter := ash.filter_create(&world, requires = {Position}, anyof = {Sprite, Text, Shape})

// Exact match - only entities with exactly these components
filter := ash.filter_create(&world, requires = {Position, Velocity}, exact = true)

// OR filters
filter := ash.filter_or(&world, {
    {requires = {A, B}},
    {requires = {C, D}},
})

query := ash.world_query(&world, filter)
```

### Iteration

**Entry-based iteration** (convenient):

```odin
it := ash.query_iter(query)
for entry in ash.query_next(&it) {
    pos := ash.entry_get(entry, Position)
    vel := ash.entry_get(entry, Velocity)
    pos.x += vel.x
    pos.y += vel.y
}
```

**Bulk iteration** (fastest):

```odin
pos_id := ash.world_get_component_id(&world, Position)
vel_id := ash.world_get_component_id(&world, Velocity)

it := ash.query_iter_archs(query)
for arch in ash.query_next_arch(&it) {
    positions := ash.archetype_slice(arch, Position, pos_id)
    velocities := ash.archetype_slice(arch, Velocity, vel_id)

    for i in 0..<len(positions) {
        positions[i].x += velocities[i].x
        positions[i].y += velocities[i].y
    }
}
```

### Command Queue

Defer structural changes during iteration:

```odin
it := ash.query_iter(query)
for entry in ash.query_next(&it) {
    health := ash.entry_get(entry, Health)
    if health.current <= 0 {
        ash.entry_queue_despawn(&entry)
    }
}

ash.world_flush(&world) // Execute queued commands
```

Available commands:
- `world_queue_spawn`  / `entry_queue_despawn`
- `world_queue_set`    / `entry_queue_set`
- `world_queue_remove` / `entry_queue_remove`

### Observers

React to entity and component lifecycle events:

```odin
// Called when any entity is spawned
ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
    fmt.println("Spawned:", e)
}, nil)

// Called when Position component is added
ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
    fmt.println("Position added to:", e)
}, nil)

// Called before entity is despawned (components still accessible)
ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
    fmt.println("Despawning:", e)
}, nil)

// Called before component is removed
ash.world_on_remove(&world, Position, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
    entry := ash.world_entry(w, e)
    pos := ash.entry_get(entry, Position)
    fmt.println("Removing position:", pos)
}, nil)
```

Unregister observers:
```odin
handle := ash.world_on_spawn(&world, my_callback, nil)
ash.world_unobserve(&world, handle)
```

### Resources

Store global singleton data:
```odin
Time :: struct {
    delta: f32,
    elapsed: f32,
}

time := Time{delta = 0.016, elapsed = 0}
ash.world_set_resource(&world, &time)

// Access anywhere
t := ash.world_get_resource(&world, Time)
t.elapsed += t.delta

// Check and remove
if ash.world_has_resource(&world, Time) {
    ash.world_remove_resource(&world, Time)
}
```

## API Reference

### World

| Procedure | Description |
|-----------|-------------|
| `world_init(&world, allocator)` | Initialize world |
| `world_destroy(&world)` | Destroy world and free resources |
| `world_spawn(&world, ..components)` | Spawn entity with components |
| `world_despawn(&world, entity)` | Destroy entity |
| `world_is_alive(&world, entity)` | Check if entity exists |
| `world_entity_count(&world)` | Number of living entities |
| `world_query(&world, filter)` | Get/create cached query |
| `world_entry(&world, entity)` | Get entry for entity access |

### Entry

| Procedure | Description |
|-----------|-------------|
| `entry_get(entry, T)` | Get component pointer (nil if missing) |
| `entry_has(entry, T)` | Check if entity has component |
| `entry_set(&entry, value)` | Add or update component |
| `entry_remove(&entry, T)` | Remove component |

### Query

| Procedure | Description |
|-----------|-------------|
| `query_iter(query)` | Create entry iterator |
| `query_iter_archs(query)` | Create archetype iterator (bulk) |
| `query_count(query)` | Count matching entities |
| `query_first(query)` | Get first matching entry |

### Filters

| Procedure | Description |
|-----------|-------------|
| `filter_contains(&world, types)` | Match entities with all types |
| `filter_create(&world, requires, excludes, anyof, exact)` | Complex filter |
| `filter_or(&world, clauses)` | OR between multiple clauses |
| `FILTER_ALL` | Match all entities |

## Thread Safety

Ash is **not** thread-safe. All operations must occur on a single thread, or external synchronization must be used.

## Benchmark

*Benchmark suite inspired by [go-ecs-benchmarks](https://github.com/mlange-42/go-ecs-benchmarks).*

## System Information

| Property | Value |
|----------|-------|
| CPU | Intel(R) Core(TM) i7-8750H CPU @ 2.20GHz |
| RAM | 15.9 GB |
| OS | Windows |
| Arch | amd64 |
| Odin | dev-2026-01 |
| Optimization | Speed |

## Results

### Query - 2 Components (1 archetype)

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| entry iteration | 100 | 21.50 ns | 46.51M |
| bulk iteration | 100 | 0.58 ns | 1724.14M |
| entry iteration | 1000 | 21.82 ns | 45.84M |
| bulk iteration | 1000 | 0.45 ns | 2222.22M |
| entry iteration | 10000 | 21.91 ns | 45.65M |
| bulk iteration | 10000 | 0.69 ns | 1439.88M |

### Query - 32 Archetypes

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| bulk iteration | 100 | 3.85 ns | 259.74M |
| bulk iteration | 1000 | 1.03 ns | 966.18M |
| bulk iteration | 10000 | 0.81 ns | 1242.24M |

### Query - 256 Archetypes

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| bulk iteration | 100 | 0.69 ns | 1449.28M |
| bulk iteration | 1000 | 0.46 ns | 2173.91M |
| bulk iteration | 10000 | 0.63 ns | 1592.61M |

### Entity Creation

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| spawn (2 components) | 100 | 225.48 ns | 4.43M |
| spawn (10 components) | 100 | 657.08 ns | 1.52M |
| spawn (2 components) | 1000 | 225.09 ns | 4.44M |
| spawn (10 components) | 1000 | 656.08 ns | 1.52M |
| spawn (2 components) | 10000 | 228.35 ns | 4.38M |
| spawn (10 components) | 10000 | 649.65 ns | 1.54M |

### Entity Deletion

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| despawn (2 components) | 100 | 35.69 ns | 28.02M |
| despawn (10 components) | 100 | 692.94 ns | 1.44M |
| despawn (2 components) | 1000 | 44.90 ns | 22.27M |
| despawn (10 components) | 1000 | 657.30 ns | 1.52M |
| despawn (2 components) | 10000 | 38.64 ns | 25.88M |
| despawn (10 components) | 10000 | 689.77 ns | 1.45M |

### Component Add/Remove

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| add+remove (2 comp entity) | 100 | 67.19 ns | 14.88M |
| add+remove (11 comp entity) | 100 | 247.76 ns | 4.04M |
| add+remove (2 comp entity) | 1000 | 78.96 ns | 12.66M |
| add+remove (11 comp entity) | 1000 | 218.43 ns | 4.58M |
| add+remove (2 comp entity) | 10000 | 65.42 ns | 15.29M |
| add+remove (11 comp entity) | 10000 | 214.15 ns | 4.67M |

### Random Entity Access

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| get component | 100 | 9.68 ns | 103.31M |
| get component | 1000 | 9.86 ns | 101.41M |
| get component | 10000 | 12.09 ns | 82.70M |

### World Lifecycle

| Benchmark | N | Time/Op | Ops/Sec |
|-----------|--:|--------:|--------:|
| init + destroy | 1 | 145.80 ns | 6.86M |

## License

MIT License