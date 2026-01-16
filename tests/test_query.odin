package tests

import "core:testing"

import ".."

@(test)
test_query_matches_archetypes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Position{1, 1})
	ash.world_spawn(&world, Position{2, 2}, Velocity{1, 0})
	ash.world_spawn(&world, Position{3, 3}, Velocity{0, 1}, Health{100})

	f1 := ash.filter_contains(&world, {Position})
	q1 := ash.world_query(&world, f1)
	testing.expect_value(t, ash.query_count(q1), 3)

	f2 := ash.filter_contains(&world, {Position, Velocity})
	q2 := ash.world_query(&world, f2)
	testing.expect_value(t, ash.query_count(q2), 2)

	f3 := ash.filter_contains(&world, {Health})
	q3 := ash.world_query(&world, f3)
	testing.expect_value(t, ash.query_count(q3), 1)
}

@(test)
test_query_requires_excludes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	for _ in 0 ..< 5 {ash.world_spawn(&world, Position{0, 0})}
	for _ in 0 ..< 3 {ash.world_spawn(&world, Position{0, 0}, Poison{})}

	f := ash.filter_create(&world, requires = {Position}, excludes = {Poison})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 5)
}

@(test)
test_query_requires_anyof :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	for _ in 0 ..< 2 {ash.world_spawn(&world, Position{0, 0}, Sprite{0})}
	for _ in 0 ..< 3 {ash.world_spawn(&world, Position{0, 0}, Text{""})}
	for _ in 0 ..< 4 {ash.world_spawn(&world, Position{0, 0})}

	f := ash.filter_create(&world, requires = {Position}, anyof = {Sprite, Text})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 5)
}

@(test)
test_query_iter_basic :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	for i in 0 ..< 10 {
		ash.world_spawn(&world, Position{f32(i), f32(i)})
	}

	q := ash.world_query(&world, ash.FILTER_ALL)

	count := 0
	it := ash.query_iter(q)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		testing.expect(t, pos != nil, "Should have Position")
		count += 1
	}

	testing.expect_value(t, count, 10)
}

@(test)
test_query_iter_basic_update :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	entities: [5]ash.Entity
	for i in 0 ..< 5 {
		entities[i] = ash.world_spawn(&world, Position{f32(i), f32(i)}, Velocity{1, 2})
	}

	q := ash.world_query(&world, ash.FILTER_ALL)

	dt := f32(2.0)

	it := ash.query_iter(q)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		pos.x += vel.vx * dt
		pos.y += vel.vy * dt
	}

	entry0 := ash.world_entry(&world, entities[0])
	pos0 := ash.entry_get(entry0, Position)
	testing.expect_value(t, pos0^, Position{2, 4})

	entry4 := ash.world_entry(&world, entities[4])
	pos4 := ash.entry_get(entry4, Position)
	testing.expect_value(t, pos4^, Position{6, 8})
}

@(test)
test_query_iter_multiple_times :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	for _ in 0 ..< 3 {ash.world_spawn(&world, Position{0, 0})}

	q := ash.world_query(&world, ash.FILTER_ALL)

	// First iteration
	count1 := 0
	it1 := ash.query_iter(q)
	for _ in ash.query_next(&it1) {count1 += 1}
	testing.expect_value(t, count1, 3)

	// Second iteration (reuse query, new iterator)
	count2 := 0
	it2 := ash.query_iter(q)
	for _ in ash.query_next(&it2) {count2 += 1}
	testing.expect_value(t, count2, 3)
}

@(test)
test_query_iter_across_archetypes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// Arch 1: Position only
	ash.world_spawn(&world, Position{1, 0})
	ash.world_spawn(&world, Position{2, 0})

	// Arch 2: Position + Velocity
	ash.world_spawn(&world, Position{3, 0}, Velocity{0, 0})
	ash.world_spawn(&world, Position{4, 0}, Velocity{0, 0})
	ash.world_spawn(&world, Position{5, 0}, Velocity{0, 0})

	f := ash.filter_create(&world, requires = {Position})
	q := ash.world_query(&world, f)

	sum: f32
	it := ash.query_iter(q)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		sum += pos.x
	}

	testing.expect_value(t, sum, 15)
}

@(test)
test_query_iter_archs :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// Arch 1: 3 entities
	for _ in 0 ..< 3 {ash.world_spawn(&world, Position{0, 0})}

	// Arch 2: 2 entities
	for _ in 0 ..< 2 {ash.world_spawn(&world, Position{0, 0}, Velocity{1, 1})}

	f := ash.filter_create(&world, requires = {Position})
	q := ash.world_query(&world, f)

	arch_count := 0
	total_entities := 0

	it := ash.query_iter_archs(q)
	for arch in ash.query_next_arch(&it) {
		arch_count += 1
		total_entities += ash.archetype_entity_count(arch)
	}

	testing.expect_value(t, arch_count, 2)
	testing.expect_value(t, total_entities, 5)
}

@(test)
test_query_iter_bulk_update :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	entities: [100]ash.Entity
	for i in 0 ..< 100 {
		entities[i] = ash.world_spawn(&world, Position{f32(i), f32(i)}, Velocity{1, 2})
	}

	pos_id := ash.world_get_component_id(&world, Position)
	vel_id := ash.world_get_component_id(&world, Velocity)

	q := ash.world_query(&world, ash.FILTER_ALL)

	it := ash.query_iter_archs(q)
	for arch in ash.query_next_arch(&it) {
		positions := ash.archetype_slice(arch, Position, pos_id)
		velocities := ash.archetype_slice(arch, Velocity, vel_id)

		for i in 0 ..< len(positions) {
			positions[i].x += velocities[i].vx
			positions[i].y += velocities[i].vy
		}
	}

	entry0 := ash.world_entry(&world, entities[0])
	pos0 := ash.entry_get(entry0, Position)
	testing.expect_value(t, pos0^, Position{1, 2})

	entry99 := ash.world_entry(&world, entities[99])
	pos99 := ash.entry_get(entry99, Position)
	testing.expect_value(t, pos99^, Position{100, 101})
}

@(test)
test_query_first :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Position{1, 1})
	ash.world_spawn(&world, Position{2, 2})

	q := ash.world_query(&world, ash.FILTER_ALL)

	first, ok := ash.query_first(q)
	testing.expect(t, ok, "Should find first")

	pos := ash.entry_get(first, Position)
	testing.expect_value(t, pos^, Position{1, 1})
}

@(test)
test_query_first_empty :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	q := ash.world_query(&world, ash.FILTER_ALL)

	_, ok := ash.query_first(q)
	testing.expect(t, !ok, "Should not find first")
}

@(test)
test_query_cahce_updates_on_new_archetype :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	f := ash.filter_contains(&world, {Position})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 0)

	// Create a new entity and archetype
	ash.world_spawn(&world, Position{1, 1})
	testing.expect_value(t, ash.query_count(q), 1)

	// Create a another entity and archetype
	ash.world_spawn(&world, Position{1, 1}, Velocity{0, 0})
	testing.expect_value(t, ash.query_count(q), 2)
}


@(test)
test_query_empty_world :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	f := ash.filter_contains(&world, {Position})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 0)

	count := 0
	it := ash.query_iter(q)
	for _ in ash.query_next(&it) {count += 1}
	testing.expect_value(t, count, 0)
}

@(test)
test_query_no_matching_archetypes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Health)

	for _ in 0 ..< 5 {ash.world_spawn(&world, Position{0, 0})}

	f := ash.filter_contains(&world, {Health})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 0)
}

@(test)
test_query_after_despawn :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	entities: [5]ash.Entity
	for i in 0 ..< 5 {
		entities[i] = ash.world_spawn(&world, Position{f32(i), 0})
	}

	q := ash.world_query(&world, ash.FILTER_ALL)

	testing.expect_value(t, ash.query_count(q), 5)

	ash.world_despawn(&world, entities[0])
	ash.world_despawn(&world, entities[2])

	testing.expect_value(t, ash.query_count(q), 3)
}

@(test)
test_query_with_zero_size_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Tag{})
	ash.world_spawn(&world, Tag{}, Position{1, 1})

	f := ash.filter_contains(&world, {Tag})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 2)
}

@(test)
test_query_archetypes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Position{1, 1})
	ash.world_spawn(&world, Position{2, 2}, Velocity{1, 1})

	f := ash.filter_contains(&world, {Position})
	q := ash.world_query(&world, f)

	archetypes := ash.query_archetypes(q)
	testing.expect_value(t, len(archetypes), 2)
}

@(test)
test_query_with_filter_or :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Position{1, 1})
	ash.world_spawn(&world, Velocity{1, 1})
	ash.world_spawn(&world, Health{100})

	f := ash.filter_or(&world, {{requires = {Position}}, {requires = {Velocity}}})
	q := ash.world_query(&world, f)

	testing.expect_value(t, ash.query_count(q), 2)
}

@(test)
test_query_iter_locks :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_spawn(&world, Position{1, 1})

	q := ash.world_query(&world, ash.FILTER_ALL)

	testing.expect(t, !ash.world_is_locked(&world))

	it := ash.query_iter(q)
	for {
		_, ok := ash.query_next(&it)
		if !ok {
			break
		}
		testing.expect(t, ash.world_is_locked(&world))
	}

	testing.expect(t, !ash.world_is_locked(&world))
}

@(test)
test_query_break_unlocks :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	for _ in 0 ..< 10 {
		ash.world_spawn(&world, Position{})
	}

	q := ash.world_query(&world, ash.FILTER_ALL)

	count := 0
	it := ash.query_iter(q)
	for {
		_, ok := ash.query_next(&it)
		if !ok {
			break
		}

		count += 1
		if count == 3 {
			break // Early exit
		}
	}

	testing.expect(t, !ash.world_is_locked(&world))
}

@(test)
test_nested_query_iteration :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	ash.world_spawn(&world, Position{})
	ash.world_spawn(&world, Velocity{})

	f1 := ash.filter_create(&world, {Position})
	q1 := ash.world_query(&world, f1)

	f2 := ash.filter_create(&world, {Velocity})
	q2 := ash.world_query(&world, f2)

	it1 := ash.query_iter(q1)
	it2 := ash.query_iter(q2)

	for _ in ash.query_next(&it1) {
		testing.expect(t, ash.world_is_locked(&world))

		for _ in ash.query_next(&it2) {
			testing.expect(t, ash.world_is_locked(&world))
		}

		testing.expect(t, ash.world_is_locked(&world), "Still locked (outer)")
	}

	testing.expect(t, !ash.world_is_locked(&world))
}

@(test)
test_lock_empty_query :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	// No entities spawned

	query := ash.world_query(&world, ash.FILTER_ALL)

	count := 0
	it := ash.query_iter(query)
	for {
		_, ok := ash.query_next(&it)
		if !ok {break}

		count += 1
	}

	testing.expect_value(t, count, 0)
	testing.expect_value(t, world.lock_count, 0)
}
