package tests

import "core:testing"

import ".."

@(test)
test_world_register_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)

	testing.expect(t, pos_id != vel_id, "IDs should be unique")

	// Re-register the same component type
	pos_id2 := ash.world_register(&world, Position)
	testing.expect_value(t, pos_id, pos_id2)

	// Can retrieve ID
	got_id, ok := ash.world_get_component_id(&world, Position)
	testing.expect(t, ok, "Should find registerd component")
	testing.expect_value(t, got_id, pos_id)
}

@(test)
test_world_spawn_despawn :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e1 := ash.world_spawn(&world)
	e2 := ash.world_spawn(&world)

	testing.expect(t, e1 != e2, "Entities should be unique")
	testing.expect(t, ash.world_is_alive(&world, e1), "e1 should be alive")
	testing.expect(t, ash.world_is_alive(&world, e2), "e2 should be alive")
	testing.expect_value(t, ash.world_entity_count(&world), 2)

	ash.world_despawn(&world, e1)

	testing.expect(t, !ash.world_is_alive(&world, e1), "e1 should be dead")
	testing.expect(t, ash.world_is_alive(&world, e2), "e2 should be alive")
	testing.expect_value(t, ash.world_entity_count(&world), 1)
}

@(test)
test_world_spawn_with :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// Single component
	e1 := ash.world_spawn(&world, Position{10, 20})
	entry1 := ash.world_entry(&world, e1)
	testing.expect(t, ash.entry_has(entry1, Position))
	testing.expect_value(t, ash.entry_get(entry1, Position)^, Position{10, 20})

	// Multiple components
	e2 := ash.world_spawn(&world, Position{1, 2}, Velocity{3, 4}, Health{100})
	entry2 := ash.world_entry(&world, e2)
	testing.expect_value(t, ash.entry_get(entry2, Position)^, Position{1, 2})
	testing.expect_value(t, ash.entry_get(entry2, Velocity)^, Velocity{3, 4})
	testing.expect_value(t, ash.entry_get(entry2, Health)^, Health{100})

	// Zero-size tag
	e3 := ash.world_spawn(&world, Position{5, 5}, Tag{})
	entry3 := ash.world_entry(&world, e3)
	testing.expect(t, ash.entry_has(entry3, Tag))
}

@(test)
test_spawn_with_single_archetype :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	testing.expect_value(t, len(world.archetypes), 0)

	ash.world_spawn(&world, Position{1, 1}, Velocity{2, 2}, Health{100}, Size{}, Sprite{})

	testing.expect_value(t, len(world.archetypes), 1)
}

@(test)
test_spawn_with_archetype_reuse :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e1 := ash.world_spawn(&world, Position{1, 1}, Velocity{1, 1})
	entry1 := ash.world_entry(&world, e1)
	testing.expect_value(t, len(world.archetypes), 1)

	// Same components, different order - should reuse archetype
	e2 := ash.world_spawn(&world, Velocity{2, 2}, Position{2, 2})
	entry2 := ash.world_entry(&world, e2)
	testing.expect_value(t, len(world.archetypes), 1)

	arch1 := entry1.loc.archetype
	arch2 := entry2.loc.archetype
	testing.expect(t, arch1 == arch2)
}

@(test)
test_spawn_with_equivalence :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// spawn_with vs spawn + entry_add should be equivalent
	e1 := ash.world_spawn(&world, Position{1, 2}, Velocity{3, 4})
	entry1 := ash.world_entry(&world, e1)

	e2 := ash.world_spawn(&world)
	entry2 := ash.world_entry(&world, e2)
	ash.entry_set(&entry2, Position{1, 2})
	ash.entry_set(&entry2, Velocity{3, 4})

	testing.expect_value(t, entry1.loc.archetype, entry2.loc.archetype)
}

@(test)
test_world_entity_recycling :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e1 := ash.world_spawn(&world)
	old_id := ash.entity_id(e1)
	old_version := ash.entity_version(e1)

	ash.world_despawn(&world, e1)

	// Next spawn should recycle the ID with the incremented version
	e2 := ash.world_spawn(&world)
	new_id := ash.entity_id(e2)
	new_version := ash.entity_version(e2)

	testing.expect_value(t, new_id, old_id)
	testing.expect_value(t, new_version, old_version + 1)

	// Old handle is invalid and new handle is valid
	testing.expect(t, !ash.world_is_alive(&world, e1), "Old entity should be invalid")
	testing.expect(t, ash.world_is_alive(&world, e2), "New entity should be valid")
}

@(test)
test_world_despawn_invalid :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e1 := ash.world_spawn(&world)
	ash.world_despawn(&world, e1)

	// Double despawn should be safe
	ash.world_despawn(&world, e1)
	testing.expect_value(t, ash.world_entity_count(&world), 0)

	// Despawn null entity should be safe
	ash.world_despawn(&world, ash.ENTITY_NULL)
	testing.expect_value(t, ash.world_entity_count(&world), 0)

	// Despawn never-existed entity should be safe
	fake := ash.entity_make(9999, 0)
	ash.world_despawn(&world, fake)
	testing.expect_value(t, ash.world_entity_count(&world), 0)
}

@(test)
test_world_spawn_many :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	entities: [100]ash.Entity
	for i in 0 ..< 100 {
		entities[i] = ash.world_spawn(&world)
	}
	testing.expect_value(t, ash.world_entity_count(&world), 100)

	// Despawn half
	for i in 0 ..< 50 {
		ash.world_despawn(&world, entities[i])
	}
	testing.expect_value(t, ash.world_entity_count(&world), 50)

	// Spawn 25 move (should recycle)
	for _ in 0 ..< 25 {
		ash.world_spawn(&world)
	}
	testing.expect_value(t, ash.world_entity_count(&world), 75)
}

@(test)
test_lock_basic :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	testing.expect(t, !ash.world_is_locked(&world))

	ash.world_lock(&world)
	testing.expect(t, ash.world_is_locked(&world))

	ash.world_unlock(&world)
	testing.expect(t, !ash.world_is_locked(&world))
}

@(test)
test_lock_nested :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_lock(&world)
	ash.world_lock(&world) // Nested
	testing.expect(t, ash.world_is_locked(&world))

	ash.world_unlock(&world)
	testing.expect(t, ash.world_is_locked(&world))

	ash.world_unlock(&world)
	testing.expect(t, !ash.world_is_locked(&world))
}

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
	testing.expect(t, ash.world_has_pending(&world))

	ash.world_flush(&world)

	// Now dead
	testing.expect_value(t, ash.world_entity_count(&world), 2)
	testing.expect(t, !ash.world_has_pending(&world))
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
	for entry in ash.query_next(&it) {
		health := ash.entry_get(entry, Health)
		if health.hp <= 0 {
			ash.entry_queue_despawn(entry)
		}
	}

	testing.expect_value(t, ash.world_entity_count(&world), 10)

	ash.world_flush(&world)

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

	ash.world_flush(&world)

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

	ash.world_flush(&world)

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

	ash.world_flush(&world)

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

	ash.world_flush(&world)

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

	ash.world_flush(&world)

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
	for entry in ash.query_next(&it) {
		ash.entry_queue_despawn(entry)
	}

	testing.expect(t, ash.world_has_pending(&world))

	// Changed our mind
	ash.world_clear_queue(&world)

	testing.expect(t, !ash.world_has_pending(&world))

	ash.world_flush(&world) // No-op

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
	testing.expect_value(t, ash.world_pending_count(&world), 2)

	ash.world_flush(&world)

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

	ash.world_flush(&world)

	// Both should exists
	testing.expect(t, ash.world_is_alive(&world, new_entity))
	testing.expect(t, ash.world_is_alive(&world, other))

	// Reference should be valid
	entry := ash.world_entry(&world, other)
	target := ash.entry_get(entry, Target)
	testing.expect_value(t, target.entity, new_entity)
}


Time_Resource :: struct {
	delta:   f32,
	elapsed: f32,
	frame:   u64,
}

Input_Resource :: struct {
	mouse_x, mouse_y: i32,
	mouse_buttons:    bit_set[0 ..< 8],
}

@(test)
test_resource_get_set :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	time := Time_Resource {
		delta   = 0.016,
		elapsed = 100.0,
		frame   = 6000,
	}
	ash.world_set_resource(&world, &time)

	fetched := ash.world_get_resource(&world, Time_Resource)

	testing.expect(t, fetched != nil)
	testing.expect_value(t, fetched.delta, 0.016)
	testing.expect_value(t, fetched.elapsed, 100.0)
}


@(test)
test_resource_multiple_types :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	time := Time_Resource {
		delta = 0.016,
	}
	input := Input_Resource {
		mouse_x = 100,
		mouse_y = 200,
	}

	ash.world_set_resource(&world, &time)
	ash.world_set_resource(&world, &input)

	testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.016)
	testing.expect_value(t, ash.world_get_resource(&world, Input_Resource).mouse_x, 100)
}

@(test)
test_resource_not_found :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	fetched := ash.world_get_resource(&world, Time_Resource)
	testing.expect(t, fetched == nil)
}

@(test)
test_resource_modification :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	time := Time_Resource {
		delta = 0.016,
	}
	ash.world_set_resource(&world, &time)

	// Modify via fetched pointer
	fetched := ash.world_get_resource(&world, Time_Resource)
	fetched.delta = 0.033

	// Original should be modified (same memory)
	testing.expect_value(t, time.delta, 0.033)
}

@(test)
test_resource_remove :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	time := Time_Resource{}
	ash.world_set_resource(&world, &time)

	testing.expect(t, ash.world_has_resource(&world, Time_Resource))

	ash.world_remove_resource(&world, Time_Resource)

	testing.expect(t, !ash.world_has_resource(&world, Time_Resource))
}

@(test)
test_resource_replace :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	time1 := Time_Resource {
		delta = 0.016,
	}
	time2 := Time_Resource {
		delta = 0.033,
	}

	ash.world_set_resource(&world, &time1)
	testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.016)

	ash.world_set_resource(&world, &time2)
	testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.033)
}
