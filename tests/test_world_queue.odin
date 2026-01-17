package tests

import "core:testing"

import ".."

@(test)
test_queue_despawn_basic :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    e1 := ash.world_spawn(&world, Position{})
    e2 := ash.world_spawn(&world, Position{})
    e3 := ash.world_spawn(&world, Position{})

    // Queue despawn
    ash.world_queue_despawn(&world, e2)

    // Still alive before flush
    testing.expect_value(t, ash.world_entity_count(&world), 3)
    testing.expect(t, ash.world_has_pending_commands(&world))

    ash.world_flush_queue(&world)

    // Now dead
    testing.expect_value(t, ash.world_entity_count(&world), 2)
    testing.expect(t, !ash.world_has_pending_commands(&world))
    testing.expect(t, ash.world_is_alive(&world, e1))
    testing.expect(t, !ash.world_is_alive(&world, e2))
    testing.expect(t, ash.world_is_alive(&world, e3))
}

@(test)
test_queue_despawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Health)

    // Spawn 10 entites, some with 0 health
    for i in 0 ..< 10 {
        hp := i < 5 ? 0 : 100 // First 5 are effectively dead
        ash.world_spawn(&world, Position{}, Health{i32(hp)})
    }

    f := ash.filter_create(&world, {Health})
    q := ash.world_query(&world, f)

    it := ash.query_iter(q)
    for {
        entry, ok := ash.query_next(&it)
        if !ok {
            break
        }

        health := ash.entry_get(entry, Health)
        if health.hp <= 0 {
            ash.entry_queue_despawn(&entry)
        }
    }

    testing.expect_value(t, ash.world_entity_count(&world), 10)

    ash.world_flush_queue(&world)

    testing.expect_value(t, ash.world_entity_count(&world), 5)
}


@(test)
test_queue_spawn :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)

    e := ash.world_queue_spawn(&world, Position{1, 1}, Velocity{2, 2})

    // Not yet spawned
    testing.expect_value(t, ash.world_entity_count(&world), 0)
    testing.expect(t, !ash.world_is_alive(&world, e))

    ash.world_flush_queue(&world)

    // Now exists
    testing.expect_value(t, ash.world_entity_count(&world), 1)
    testing.expect(t, ash.world_is_alive(&world, e))

    entry := ash.world_entry(&world, e)
    pos := ash.entry_get(entry, Position)
    vel := ash.entry_get(entry, Velocity)
    testing.expect_value(t, pos^, Position{1, 1})
    testing.expect_value(t, vel^, Velocity{2, 2})
}

@(test)
test_queue_spawn_during_iteration :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Child_Of)

    p1 := ash.world_spawn(&world, Position{1, 1})
    p2 := ash.world_spawn(&world, Position{2, 2})

    q := ash.world_query(&world, ash.FILTER_ALL)

    spawned := make([dynamic]ash.Entity)
    defer delete(spawned)

    it := ash.query_iter(q)
    for entry in ash.query_next(&it) {
        pos := ash.entry_get(entry, Position)
        child_entity := ash.world_queue_spawn(
            &world,
            Position{pos.x + 10, pos.y + 5},
            Child_Of{entry.entity},
        )
        append(&spawned, child_entity)
    }

    // Original 2 still there
    testing.expect_value(t, ash.world_entity_count(&world), 2)

    ash.world_flush_queue(&world)

    testing.expect_value(t, ash.world_entity_count(&world), 4)

    entry := ash.world_entry(&world, spawned[0])
    pos := ash.entry_get(entry, Position)
    child_of := ash.entry_get(entry, Child_Of)
    testing.expect_value(t, pos^, Position{11, 6})
    testing.expect_value(t, child_of.parent, p1)
}


@(test)
test_entry_queue_set :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)

    e := ash.world_spawn(&world, Position{})

    f := ash.filter_create(&world, {Position})
    q := ash.world_query(&world, f)

    it := ash.query_iter(q)
    for {
        entry, ok := ash.query_next(&it)
        if !ok {
            break
        }
        ash.entry_queue_set(&entry, Velocity{1, 2})
    }

    // Not added yet
    entry := ash.world_entry(&world, e)
    testing.expect(t, !ash.entry_has(entry, Velocity))

    ash.world_flush_queue(&world)

    // Now has it
    entry = ash.world_entry(&world, e)
    testing.expect(t, ash.entry_has(entry, Velocity))
    vel := ash.entry_get(entry, Velocity)
    testing.expect_value(t, vel^, Velocity{1, 2})
}

@(test)
test_entry_queue_remove :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)

    e := ash.world_spawn(&world, Position{}, Velocity{})

    f := ash.filter_create(&world, {Velocity})
    q := ash.world_query(&world, f)

    it := ash.query_iter(q)
    for {
        entry, ok := ash.query_next(&it)
        if !ok {
            break
        }
        ash.entry_queue_remove(&entry, Velocity)
    }

    ash.world_flush_queue(&world)

    entry := ash.world_entry(&world, e)
    testing.expect(t, ash.entry_has(entry, Position))
    testing.expect(t, !ash.entry_has(entry, Velocity))
}

@(test)
test_queue_order_preserved :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)

    // Spawn then modify in queue
    e := ash.world_queue_spawn(&world, Position{1, 0})
    ash.world_queue_set(&world, e, Position{2, 0}) // Override
    ash.world_queue_set(&world, e, Velocity{3, 0}) // Add

    ash.world_flush_queue(&world)

    entry := ash.world_entry(&world, e)
    pos := ash.entry_get(entry, Position)
    vel := ash.entry_get(entry, Velocity)

    testing.expect_value(t, pos^, Position{2, 0}) // Second set wins
    testing.expect_value(t, vel^, Velocity{3, 0})
}

@(test)
test_clear_queue :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)

    ash.world_spawn(&world, Position{})

    q := ash.world_query(&world, ash.FILTER_ALL)

    it := ash.query_iter(q)
    for {
        entry, ok := ash.query_next(&it)
        if !ok {
            break
        }
        ash.entry_queue_despawn(&entry)
    }

    testing.expect(t, ash.world_has_pending_commands(&world))

    // Changed our mind
    ash.world_clear_queue(&world)

    testing.expect(t, !ash.world_has_pending_commands(&world))

    ash.world_flush_queue(&world) // No-op

    testing.expect_value(t, ash.world_entity_count(&world), 1) // Still there
}

@(test)
test_nested_iteration_single_flush :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)

    ash.world_spawn(&world, Position{})
    ash.world_spawn(&world, Velocity{})

    f1 := ash.filter_contains(&world, {Position})
    q1 := ash.world_query(&world, f1)

    f2 := ash.filter_contains(&world, {Velocity})
    q2 := ash.world_query(&world, f2)

    it1 := ash.query_iter(q1)
    it2 := ash.query_iter(q2)

    for _ in ash.query_next(&it1) {
        ash.world_queue_spawn(&world, Position{})

        for _ in ash.query_next(&it2) {
            ash.world_queue_spawn(&world, Velocity{})
        }
    }

    // Both loops done, need manual flush
    testing.expect_value(t, ash.world_entity_count(&world), 2)
    testing.expect_value(t, ash.world_pending_commands_count(&world), 2)

    ash.world_flush_queue(&world)

    testing.expect_value(t, ash.world_entity_count(&world), 4)
}


@(test)
test_queue_spawn_reference_before_flush :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    ash.world_register(&world, Position)
    ash.world_register(&world, Target)

    // Spawn entity and immediately reference it in another spawn
    new_entity := ash.world_queue_spawn(&world, Position{})
    other := ash.world_queue_spawn(&world, Target{new_entity})

    ash.world_flush_queue(&world)

    // Both should exists
    testing.expect(t, ash.world_is_alive(&world, new_entity))
    testing.expect(t, ash.world_is_alive(&world, other))

    // Reference should be valid
    entry := ash.world_entry(&world, other)
    target := ash.entry_get(entry, Target)
    testing.expect_value(t, target.entity, new_entity)
}