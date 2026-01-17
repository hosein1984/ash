package tests

import "core:testing"

import ".."

// ============================================================================
// SPAWN OBSERVERS
// ============================================================================

@(test)
test_on_spawn_fires :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
        (^int)(user_data)^ += 1
    }, &count)
    
    ash.world_spawn(&world, Position{})
    ash.world_spawn(&world, Position{})
    ash.world_spawn(&world, Position{})
    
    testing.expect_value(t, count, 3)
}

@(test)
test_on_spawn_entity_is_alive :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    was_alive := false
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, user_data: rawptr) {
        (^bool)(user_data)^ = ash.world_is_alive(w, e)
    }, &was_alive)
    
    ash.world_spawn(&world, Position{})
    
    testing.expect(t, was_alive, "Entity should be alive during On_Spawn callback")
}

@(test)
test_on_spawn_components_accessible :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    captured_pos: Position
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        entry := ash.world_entry(w, e)
        pos := ash.entry_get(entry, Position)
        (^Position)(ctx)^ = pos^
    }, &captured_pos)
    
    ash.world_spawn(&world, Position{42, 0})
    
    testing.expect_value(t, captured_pos, Position{42, 0})
}

@(test)
test_on_spawn_multiple_observers :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count1 := 0
    count2 := 0
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count1)
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 10
    }, &count2)
    
    ash.world_spawn(&world, Position{})
    
    testing.expect_value(t, count1, 1)
    testing.expect_value(t, count2, 10)
}

// ============================================================================
// DESPAWN OBSERVERS
// ============================================================================

@(test)
test_on_despawn_fires :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    e1 := ash.world_spawn(&world, Position{})
    e2 := ash.world_spawn(&world, Position{})
    
    ash.world_despawn(&world, e1)
    testing.expect_value(t, count, 1)
    
    ash.world_despawn(&world, e2)
    testing.expect_value(t, count, 2)
}

@(test)
test_on_despawn_entity_still_alive :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    was_alive := false
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^bool)(ctx)^ = ash.world_is_alive(w, e)
    }, &was_alive)
    
    e := ash.world_spawn(&world, Position{})
    ash.world_despawn(&world, e)
    
    testing.expect(t, was_alive, "Entity should still be alive during On_Despawn callback")
    testing.expect(t, !ash.world_is_alive(&world, e), "Entity should be dead after despawn completes")
}

@(test)
test_on_despawn_components_accessible :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    captured_pos: Position
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        entry := ash.world_entry(w, e)
        pos := ash.entry_get(entry, Position)
        (^Position)(ctx)^ = pos^
    }, &captured_pos)
    
    e := ash.world_spawn(&world, Position{99, 0})
    ash.world_despawn(&world, e)
    
    testing.expect_value(t, captured_pos, Position{99, 0})
}

// ============================================================================
// ADD OBSERVERS
// ============================================================================

@(test)
test_on_add_fires_on_spawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    
    pos_count := 0
    vel_count := 0
    
    ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &pos_count)
    
    ash.world_on_add(&world, Velocity, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &vel_count)
    
    // Spawn with Position only
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, pos_count, 1)
    testing.expect_value(t, vel_count, 0)
    
    // Spawn with both
    ash.world_spawn(&world, Position{}, Velocity{})
    testing.expect_value(t, pos_count, 2)
    testing.expect_value(t, vel_count, 1)
}

@(test)
test_on_add_fires_on_entry_set :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    
    count := 0
    ash.world_on_add(&world, Velocity, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    e := ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 0)
    
    entry := ash.world_entry(&world, e)
    ash.entry_set(&entry, Velocity{1, 2})
    
    testing.expect_value(t, count, 1)
}

@(test)
test_on_add_not_fired_on_update :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    e := ash.world_spawn(&world, Position{1, 0})
    testing.expect_value(t, count, 1)
    
    // Update existing component - should NOT fire insert
    entry := ash.world_entry(&world, e)
    ash.entry_set(&entry, Position{2, 0})
    
    testing.expect_value(t, count, 1)  // No change
}

@(test)
test_on_add_data_accessible :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    captured_pos: Position
    ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        entry := ash.world_entry(w, e)
        pos := ash.entry_get(entry, Position)
        (^Position)(ctx)^ = pos^
    }, &captured_pos)
    
    ash.world_spawn(&world, Position{77, 0})
    
    testing.expect_value(t, captured_pos, Position{77, 0})
}

// ============================================================================
// REMOVE OBSERVERS
// ============================================================================

@(test)
test_on_remove_fires_on_entry_remove :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    
    count := 0
    ash.world_on_remove(&world, Velocity, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    e := ash.world_spawn(&world, Position{}, Velocity{})
    testing.expect_value(t, count, 0)
    
    entry := ash.world_entry(&world, e)
    ash.entry_remove(&entry, Velocity)
    
    testing.expect_value(t, count, 1)
}

@(test)
test_on_remove_fires_on_despawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    
    pos_remove_count := 0
    vel_remove_count := 0
    
    ash.world_on_remove(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &pos_remove_count)
    
    ash.world_on_remove(&world, Velocity, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &vel_remove_count)
    
    e := ash.world_spawn(&world, Position{}, Velocity{})
    ash.world_despawn(&world, e)
    
    testing.expect_value(t, pos_remove_count, 1)
    testing.expect_value(t, vel_remove_count, 1)
}

@(test)
test_on_remove_data_still_accessible :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    
    captured_vel: Velocity
    ash.world_on_remove(&world, Velocity, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        entry := ash.world_entry(w, e)
        vel := ash.entry_get(entry, Velocity)
        (^Velocity)(ctx)^ = vel^
    }, &captured_vel)
    
    e := ash.world_spawn(&world, Position{}, Velocity{88, 0})
    
    entry := ash.world_entry(&world, e)
    ash.entry_remove(&entry, Velocity)
    
    testing.expect_value(t, captured_vel, Velocity{88, 0})
}

// ============================================================================
// UNREGISTER
// ============================================================================

@(test)
test_unobserve_spawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    handle := ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 1)
    
    ash.world_unobserve(&world, handle)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 1)  // No change
}

@(test)
test_unobserve_insert :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    handle := ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 1)
    
    ash.world_unobserve(&world, handle)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 1)  // No change
}

@(test)
test_unobserve_middle_of_list :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count1, count2, count3 := 0, 0, 0
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count1)
    
    handle2 := ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 10
    }, &count2)
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 100
    }, &count3)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count1, 1)
    testing.expect_value(t, count2, 10)
    testing.expect_value(t, count3, 100)
    
    // Unregister middle one
    ash.world_unobserve(&world, handle2)
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count1, 2)
    testing.expect_value(t, count2, 10)  // No change
    testing.expect_value(t, count3, 200)
}

@(test)
test_unobserve_invalid_handle :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    // Should not crash
    ash.world_unobserve(&world, 9999)
    ash.world_unobserve(&world, 0)
}

@(test)
test_unobserve_twice :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    count := 0
    handle := ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &count)
    
    ash.world_unobserve(&world, handle)
    ash.world_unobserve(&world, handle)  // Should not crash
    
    ash.world_spawn(&world, Position{})
    testing.expect_value(t, count, 0)
}

// ============================================================================
// QUEUED COMMANDS
// ============================================================================

@(test)
test_observers_fire_on_flush :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    spawn_count := 0
    despawn_count := 0
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &spawn_count)
    
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &despawn_count)
    
    e := ash.world_queue_spawn(&world, Position{})
    
    testing.expect_value(t, spawn_count, 0)  // Not yet
    
    ash.world_flush_queue(&world)
    
    testing.expect_value(t, spawn_count, 1)  // Now fired
    
    ash.world_queue_despawn(&world, e)
    testing.expect_value(t, despawn_count, 0)
    
    ash.world_flush_queue(&world)
    testing.expect_value(t, despawn_count, 1)
}

// ============================================================================
// ORDER VERIFICATION
// ============================================================================

@(test)
test_spawn_order_insert_then_spawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    order := make([dynamic]string, context.temp_allocator)
    
    ash.world_on_add(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        append((^[dynamic]string)(ctx), "insert")
    }, &order)
    
    ash.world_on_spawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        append((^[dynamic]string)(ctx), "spawn")
    }, &order)
    
    ash.world_spawn(&world, Position{})
    
    testing.expect_value(t, len(order), 2)
    testing.expect_value(t, order[0], "spawn")
    testing.expect_value(t, order[1], "insert")
}

@(test)
test_despawn_order_despawn_then_remove :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    
    order := make([dynamic]string, context.temp_allocator)
    
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        append((^[dynamic]string)(ctx), "despawn")
    }, &order)
    
    ash.world_on_remove(&world, Position, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        append((^[dynamic]string)(ctx), "remove")
    }, &order)
    
    e := ash.world_spawn(&world, Position{})
    ash.world_despawn(&world, e)
    
    testing.expect_value(t, len(order), 2)
    testing.expect_value(t, order[0], "remove")
    testing.expect_value(t, order[1], "despawn")
}

@(test)
test_world_clear_fires_observers :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)
    
    ash.world_register(&world, Position)
    ash.world_register(&world, Sprite)
    
    despawn_count := 0
    remove_count := 0
    
    ash.world_on_despawn(&world, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &despawn_count)
    
    ash.world_on_remove(&world, Sprite, proc(w: ^ash.World, e: ash.Entity, ctx: rawptr) {
        (^int)(ctx)^ += 1
    }, &remove_count)
    
    // Spawn 5 entities with Sprite
    for _ in 0..<5 {
        ash.world_spawn(&world, Position{}, Sprite{})
    }
    
    testing.expect_value(t, ash.world_entity_count(&world), 5)
    
    ash.world_clear(&world)
    
    testing.expect_value(t, ash.world_entity_count(&world), 0)
    testing.expect_value(t, despawn_count, 5)
    testing.expect_value(t, remove_count, 5)
}