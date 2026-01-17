package observers

import "core:fmt"

import "../.."

// ============================================================================
// COMPONENTS
// ============================================================================

Position :: struct {
    x, y: f32
}

Velocity :: struct {
    vx, vy: f32
}

Health :: struct {
    hp: f32
}


// ============================================================================
// STATISTIC TRACKING
// ============================================================================

Stats :: struct {
    spawned:        int,
    despawned:      int,
    health_added:   int,
    health_removed: int,
}

// ============================================================================
// OBSERVER CALLBACKS
// ============================================================================

on_entity_spawned :: proc(world: ^ash.World, entity: ash.Entity, user_data: rawptr) {
    stats := cast(^Stats)user_data
    stats.spawned += 1
    fmt.printfln("  [SPAWN] Entity %d created", ash.entity_id(entity))
}

on_entity_despawned :: proc(world: ^ash.World, entity: ash.Entity, user_data: rawptr) {
    stats := cast(^Stats)user_data
    stats.despawned += 1
    fmt.printfln("  [DESPAWN] Entity %d removed", ash.entity_id(entity))
}

on_health_added :: proc(world: ^ash.World, entity: ash.Entity, user_data: rawptr) {
    stats := cast(^Stats)user_data
    stats.health_added += 1

    entry  := ash.world_entry(world, entity)
    health := ash.entry_get(entry, Health)
    fmt.printfln("  [ADD HEALTH] Entity %d now has %.1f HP", ash.entity_id(entity), health.hp)
}

on_health_removed :: proc(world: ^ash.World, entity: ash.Entity, user_data: rawptr) {
    stats := cast(^Stats)user_data
    stats.health_removed += 1

    entry  := ash.world_entry(world, entity)
    health := ash.entry_get(entry, Health)
    fmt.printfln("  [REMOVE HEALTH] Entity %d losing %.1f HP component", ash.entity_id(entity), health.hp)
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    stats: Stats

    // Register observers
    ash.world_on_spawn(&world, on_entity_spawned, &stats)
    ash.world_on_despawn(&world, on_entity_despawned, &stats)
    ash.world_on_add(&world, Health, on_health_added, &stats)
    ash.world_on_remove(&world, Health, on_health_removed, &stats)

    fmt.println("=== Creating entities ===")

    // Create entities will trigger spawn and add observers
    e1 := ash.world_spawn(&world, Position{1, 2}, Velocity{0.1, 0.2})
    e2 := ash.world_spawn(&world, Position{3, 4})
    e3 := ash.world_spawn(&world, Position{5, 6}, Health{100})

    fmt.println("\n=== Adding Health to entity 1")
    entry1 := ash.world_entry(&world, e1)
    ash.entry_set(&entry1, Health{50})

    fmt.println("\n=== Removing Hleath from entity 3")
    entry3 := ash.world_entry(&world, e3)
    ash.entry_remove(&entry3, Health)

    fmt.println("\n=== Despawning entity 2 ===")
    ash.world_despawn(&world, e2)

    fmt.println("\n=== Despawning entity 1 (has Health) ===")
    ash.world_despawn(&world, e1)

    fmt.println("\n=== Statistics ===")
	fmt.printfln("Entities spawned:     %d", stats.spawned)
	fmt.printfln("Entities despawned:   %d", stats.despawned)
	fmt.printfln("Health added:         %d", stats.health_added)
	fmt.printfln("Health removed:       %d", stats.health_removed)
}