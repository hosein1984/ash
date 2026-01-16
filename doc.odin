/*
Package ash implements an archetype-based Entity Component System (ECS).

Core Concepts:
- Entity: A unique identifier (64-bit: 32-bit ID + 32-bit generation)
- Component: Plain data structs registered with the world
- Archetype: A unique combination of component types; entities with 
  identical component sets share an archetype
- World: The container managing all entities, components, and archetypes
- Query: Efficient iteration over entities matching a component filter

Usage Pattern:
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    // Spawn entities with components
    e := ash.world_spawn(&world, Position{0, 0}, Velocity{1, 0})
    
    // Query and iterate
    q := ash.world_query(&world, ash.filter_contains(&world, {Position, Velocity}))
    it := ash.query_iter(q)
    for entry in ash.query_next(&it) {
        pos := ash.entry_get(entry, Position)
        vel := ash.entry_get(entry, Velocity)
        pos.x += vel.vx
    }

Thread Safety:
    This ECS is NOT thread-safe. All operations must occur on a single thread,
    or external synchronization must be used.
*/
package ash