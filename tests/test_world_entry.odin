package tests

import ash ".."
import "core:testing"

@(test)
test_entry_valid_entity :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e := ash.world_spawn(&world)

	entry, ok := ash.world_entry(&world, e)
	testing.expect(t, ok, "Should get entry for valid entity")
	testing.expect_value(t, entry.entity, e)
}

@(test)
test_entry_invalid_entity :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// Null entity
	_, ok1 := ash.world_entry(&world, ash.ENTITY_NULL)
	testing.expect(t, !ok1, "Should fail for null entity")

	// Never existed
	fake := ash.entity_make(9999, 0)
	_, ok2 := ash.world_entry(&world, fake)
	testing.expect(t, !ok2, "Should fail for non-existent entity")

	// Despawn entity
	e := ash.world_spawn(&world)
	ash.world_despawn(&world, e)
	_, ok3 := ash.world_entry(&world, e)
	testing.expect(t, !ok3, "Should fail for despawn entity")
}

@(test)
test_entry_add_components :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)
	ash.world_register(&world, Health)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})
	ash.entry_add(&entry, Velocity{3, 4})
	ash.entry_add(&entry, Health{100})

	testing.expect(t, ash.entry_has(entry, Position), "Entry should have Position")
	testing.expect(t, ash.entry_has(entry, Velocity), "Entry should have Velocity")
	testing.expect(t, ash.entry_has(entry, Health), "Entry should have Health")

	pos := ash.entry_get(entry, Position)
	vel := ash.entry_get(entry, Velocity)
	health := ash.entry_get(entry, Health)

	testing.expect_value(t, pos^, Position{1, 2})
	testing.expect_value(t, vel^, Velocity{3, 4})
	testing.expect_value(t, health^, Health{100})
}

@(test)
test_entry_add_overwrites_existing :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 1})
	ash.entry_add(&entry, Position{99, 99}) // Overwrite

	pos := ash.entry_get(entry, Position)
	testing.expect_value(t, pos^, Position{99, 99})

	// Should still be in same archetype (no new archetype created)
	testing.expect_value(t, len(world.archetypes), 1)

	arch := ash.entry_archetype(entry)
	testing.expect_value(t, ash.archetype_len(arch), 1)
}

@(test)
test_entry_add_zero_size_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Tag)
	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Tag{})
	ash.entry_add(&entry, Position{5, 5})

	testing.expect(t, ash.entry_has(entry, Tag), "Should have Tag")
	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")
}

@(test)
test_entry_add_auto_registers_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})

	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")

	pos := ash.entry_get(entry, Position)
	testing.expect_value(t, pos^, Position{1, 2})
}

@(test)
test_entry_get_nonexistent :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	// No components yet
	pos := ash.entry_get(entry, Position)
	testing.expect(t, pos == nil, "Should return nil for missing component")

	// Position but not velocity
	ash.entry_add(&entry, Position{1, 2})
	pos = ash.entry_get(entry, Position)
	testing.expect(t, pos != nil, "Should return value for valid component")

	vel := ash.entry_get(entry, Velocity)
	testing.expect(t, vel == nil, "Should return nil for missing component")
}

@(test)
test_get_modify_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})

	// Modify through pointer
	pos := ash.entry_get(entry, Position)
	pos.x = 100
	pos.y = 200

	// Verify changes persisted
	pos2 := ash.entry_get(entry, Position)
	testing.expect_value(t, pos2^, Position{100, 200})
}


@(test)
test_entry_has :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	testing.expect(t, !ash.entry_has(entry, Position), "Should not have Position")
	testing.expect(t, !ash.entry_has(entry, Velocity), "Should not have Velocity")

	ash.entry_add(&entry, Position{0, 0})

	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")
	testing.expect(t, !ash.entry_has(entry, Velocity), "Should not have Velocity")
}

@(test)
test_entry_remove_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})
	ash.entry_add(&entry, Velocity{3, 4})

	ash.entry_remove(&entry, Position)

	testing.expect(t, !ash.entry_has(entry, Position), "Should not have Position")
	testing.expect(t, ash.entry_has(entry, Velocity), "Should have Velocity")

	vel := ash.entry_get(entry, Velocity)
	testing.expect_value(t, vel^, Velocity{3, 4})
}

@(test)
test_entry_remove_nonexistent :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})

	// Remove component entitiy doesn't have - should be no-op
	ash.entry_remove(&entry, Velocity)

	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")
	testing.expect(t, !ash.entry_has(entry, Velocity), "Should not have Velocity")
}

@(test)
test_entry_remove_last_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})
	ash.entry_remove(&entry, Position)

	testing.expect(t, !ash.entry_has(entry, Position), "Should not have Position")

	// Entity should still be alive, just no components
	testing.expect(t, ash.world_is_alive(&world, e), "Entity should still be alive")

	// Archetype should be null
	arch := ash.entry_archetype(entry)
	testing.expect(t, arch == nil, "Should have no archetype")
}

@(test)
test_entry_remove_zero_size_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Tag)
	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Tag{})
	ash.entry_add(&entry, Position{})

	ash.entry_remove(&entry, Tag)

	testing.expect(t, !ash.entry_has(entry, Tag), "Should not have Tag")
	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")
}

@(test)
test_entry_archetype_sharing :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e1 := ash.world_spawn(&world)
	e2 := ash.world_spawn(&world)

	entry1 := ash.world_entry(&world, e1)
	entry2 := ash.world_entry(&world, e2)

	// Both get same component - should share archetype
	ash.entry_add(&entry1, Position{1, 1})
	ash.entry_add(&entry2, Position{2, 2})

	arch1 := ash.entry_archetype(entry1)
	arch2 := ash.entry_archetype(entry2)

	testing.expect(t, arch1 == arch2, "Should share archetype")
	testing.expect_value(t, ash.archetype_len(arch1), 2)
}

@(test)
test_entry_archetype_divergence :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e1 := ash.world_spawn(&world)
	e2 := ash.world_spawn(&world)

	entry1 := ash.world_entry(&world, e1)
	entry2 := ash.world_entry(&world, e2)

	// Both start with Position
	ash.entry_add(&entry1, Position{1, 1})
	ash.entry_add(&entry2, Position{2, 2})

	// e1 gets Velocity, e2 doesn't
	ash.entry_add(&entry1, Velocity{3, 3})

	// Refresh entries atfer archetype change (just for sanity not really needed)
	entry1 = ash.world_entry(&world, e1)
	entry2 = ash.world_entry(&world, e2)

	arch1 := ash.entry_archetype(entry1)
	arch2 := ash.entry_archetype(entry2)

	testing.expect(t, arch1 != arch2, "Should be different archetypes")
	testing.expect_value(t, ash.archetype_len(arch1), 1)
	testing.expect_value(t, ash.archetype_len(arch2), 1)
}

@(test)
test_entry_component_preserved_after_add :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{42, 43})
	ash.entry_add(&entry, Velocity{1, 2}) // Moves to new archetype

	pos := ash.entry_get(entry, Position)
	testing.expect_value(t, pos^, Position{42, 43})
}

@(test)
test_entry_component_preserved_after_remove :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)
	ash.world_register(&world, Health)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{1, 2})
	ash.entry_add(&entry, Velocity{1, 2})
	ash.entry_add(&entry, Health{100})

	// Remove velocity - should preserve Position and Health
	ash.entry_remove(&entry, Velocity)

	pos := ash.entry_get(entry, Position)
	hp := ash.entry_get(entry, Health)

	testing.expect_value(t, pos^, Position{1, 2})
	testing.expect_value(t, hp^, Health{100})
}

@(test)
test_entry_multiple_entities_complex :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)
	ash.world_register(&world, Health)

	// Create 10 entities with varying components
	entities: [10]ash.Entity
	for i in 0 ..< len(entities) {
		entities[i] = ash.world_spawn(&world)
		entry := ash.world_entry(&world, entities[i])

		ash.entry_add(&entry, Position{f32(i), f32(i * 2)})

		if i % 2 == 0 {
			ash.entry_add(&entry, Velocity{f32(i), 0})
		}
		if i % 3 == 0 {
			ash.entry_add(&entry, Health{i32(i * 10)})
		}
	}

	// Verify entity 6 has all three components
	entry6 := ash.world_entry(&world, entities[6])
	testing.expect(t, ash.entry_has(entry6, Position), "e6 should have Position")
	testing.expect(t, ash.entry_has(entry6, Velocity), "e6 should have Velocity")
	testing.expect(t, ash.entry_has(entry6, Health), "e6 should have Health")

	// Verify e5 only has Position
	entry5 := ash.world_entry(&world, entities[5])
	testing.expect(t, ash.entry_has(entry5, Position), "e5 should have Position")
	testing.expect(t, !ash.entry_has(entry5, Velocity), "e5 not should have Velocity")
	testing.expect(t, !ash.entry_has(entry5, Health), "e5 not should have Health")
}

@(test)
test_entry_despawn_middle_entity :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e1 := ash.world_spawn(&world)
	e2 := ash.world_spawn(&world)
	e3 := ash.world_spawn(&world)

	entry1, _ := ash.world_entry(&world, e1)
	entry2, _ := ash.world_entry(&world, e2)
	entry3, _ := ash.world_entry(&world, e3)

	ash.entry_add(&entry1, Position{1, 1})
	ash.entry_add(&entry2, Position{2, 2})
	ash.entry_add(&entry3, Position{3, 3})

	// Despawn middle entity
	ash.world_despawn(&world, e2)

	// e1 and e3 should still have correct data
	entry1, _ = ash.world_entry(&world, e1)
	entry3, _ = ash.world_entry(&world, e3)

	pos1 := ash.entry_get(entry1, Position)
	pos3 := ash.entry_get(entry3, Position)

	testing.expect_value(t, pos1^, Position{1, 1})
	testing.expect_value(t, pos3^, Position{3, 3})
}

@(test)
test_entry_rapid_add_remove :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e := ash.world_spawn(&world)

	// Rapidly add and remove
	for i in 0 ..< 1000 {
		entry := ash.world_entry(&world, e)

		ash.entry_add(&entry, Position{f32(i), f32(i)})
		ash.entry_add(&entry, Velocity{f32(i), f32(i)})

		entry = ash.world_entry(&world, e)
		ash.entry_remove(&entry, Velocity)
	}

	entry := ash.world_entry(&world, e)
	testing.expect(t, ash.entry_has(entry, Position), "Should have Position")
	testing.expect(t, !ash.entry_has(entry, Velocity), "Should not have Velocity")

	pos := ash.entry_get(entry, Position)
	testing.expect_value(t, pos^, Position{999, 999})
}

@(test)
test_entry_archetype_nil_when_no_component :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	arch := ash.entry_archetype(entry)
	testing.expect(t, arch == nil, "Should have no archetype when no components")
}

@(test)
test_entry_archetype_valid_with_components :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)

	e := ash.world_spawn(&world)
	entry := ash.world_entry(&world, e)

	ash.entry_add(&entry, Position{0, 0})

	entry = ash.world_entry(&world, e)
	arch := ash.entry_archetype(entry)
	testing.expect(t, arch != nil, "Should have archetype")
	testing.expect(t, ash.archetype_has(arch, 0), "Archetype should have Position (id=0)")
}
