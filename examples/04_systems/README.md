# Simple Systems Example

Systems as plain procedures - the simplest approach to organizing ECS logic.

## What This Showcases

- **Systems as procedures**: No abstraction, just functions that operate on the world
- **Explicit control**: You decide exactly when each system runs
- **Parameterized systems**: Pass any data systems need as arguments


## Key Concept

A "system" is just a procedure that takes the world (and whatever else it needs):

```odin
system_movement :: proc(world: ^ash.World) {
    movement_query := ash.world_query(&world, movement_filter)

    it := ash.query_iter(query)
    for entry in ash.query_next(&it) {
        pos := ash.entry_get(entry, Position)
        vel := ash.entry_get(entry, Velocity)
        pos.x += vel.vx
        pos.y += vel.vy
    }
}
```

## Usage Pattern

```odin
// Game loop: Call systems in order
for tick in 1..=100 {
    system_movement(&world)
    system_bounds(&world, width, height)
    system_stats(&world, tick)
}
```

## Running

```bash
cd examples/04_systems
odin run .
```

## See Also

- `examples/05_scheduler` - for a more structured approach with stages
