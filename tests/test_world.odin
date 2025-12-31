package tests

import ash ".."
import "base:runtime"
import "core:testing"

@(test)
test_world_register_component :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

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
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	e1 := ash.world_spawn(&world)
	e2 := ash.world_spawn(&world)

	testing.expect(t, e1 != e2, "Entities should be unique")
	testing.expect(t, ash.world_is_alive(&world, e1), "e1 should be alive")
	testing.expect(t, ash.world_is_alive(&world, e2), "e2 should be alive")
	testing.expect_value(t, ash.world_len(&world), 2)

	ash.world_despawn(&world, e1)

	testing.expect(t, !ash.world_is_alive(&world, e1), "e1 should be dead")
	testing.expect(t, ash.world_is_alive(&world, e2), "e2 should be alive")
	testing.expect_value(t, ash.world_len(&world), 1)
}

@(test)
test_world_spawn_with :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	// Single component
	e1 := ash.world_spawn_with(&world, Position{10, 20})
	entry1 := ash.world_entry(&world, e1)
	testing.expect(t, ash.entry_has(entry1, Position))
	testing.expect_value(t, ash.entry_get(entry1, Position)^, Position{10, 20})

	// Multiple components
	e2 := ash.world_spawn_with(&world, Position{1, 2}, Velocity{3, 4}, Health{100})
	entry2 := ash.world_entry(&world, e2)
	testing.expect_value(t, ash.entry_get(entry2, Position)^, Position{1, 2})
	testing.expect_value(t, ash.entry_get(entry2, Velocity)^, Velocity{3, 4})
	testing.expect_value(t, ash.entry_get(entry2, Health)^, Health{100})

	// Zero-size tag
	e3 := ash.world_spawn_with(&world, Position{5, 5}, Tag{})
	entry3 := ash.world_entry(&world, e3)
	testing.expect(t, ash.entry_has(entry3, Tag))
}

@(test)
test_spawn_with_single_archetype :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	testing.expect_value(t, len(world.archetypes), 0)

	ash.world_spawn_with(&world, Position{1, 1}, Velocity{2, 2}, Health{100}, Size{}, Sprite{})

	testing.expect_value(t, len(world.archetypes), 1)
}

@(test)
test_spawn_with_archetype_reuse :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	e1 := ash.world_spawn_with(&world, Position{1, 1}, Velocity{1, 1})
	entry1 := ash.world_entry(&world, e1)
	testing.expect_value(t, len(world.archetypes), 1)

	// Same components, different order - should reuse archetype
	e2 := ash.world_spawn_with(&world, Velocity{2, 2}, Position{2, 2})
	entry2 := ash.world_entry(&world, e2)
	testing.expect_value(t, len(world.archetypes), 1)

	arch1 := entry1.loc.archetype
	arch2 := entry2.loc.archetype
	testing.expect(t, arch1 == arch2)
}

@(test)
test_spawn_with_equivalence :: proc(t: ^testing.T) {
    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()
    
    // spawn_with vs spawn + entry_add should be equivalent
    e1 := ash.world_spawn_with(&world, Position{1, 2}, Velocity{3, 4})
	entry1:= ash.world_entry(&world, e1)
    
    e2 := ash.world_spawn(&world)
    entry2 := ash.world_entry(&world, e2)
    ash.entry_add(&entry2, Position{1, 2})
    ash.entry_add(&entry2, Velocity{3, 4})
    
    testing.expect_value(t, entry1.loc.archetype, entry2.loc.archetype)
}

@(test)
test_world_entity_recycling :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

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
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	e1 := ash.world_spawn(&world)
	ash.world_despawn(&world, e1)

	// Double despawn should be safe
	ash.world_despawn(&world, e1)
	testing.expect_value(t, ash.world_len(&world), 0)

	// Despawn null entity should be safe
	ash.world_despawn(&world, ash.ENTITY_NULL)
	testing.expect_value(t, ash.world_len(&world), 0)

	// Despawn never-existed entity should be safe
	fake := ash.entity_make(9999, 0)
	ash.world_despawn(&world, fake)
	testing.expect_value(t, ash.world_len(&world), 0)
}

@(test)
test_world_spawn_many :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	entities: [100]ash.Entity
	for i in 0 ..< 100 {
		entities[i] = ash.world_spawn(&world)
	}
	testing.expect_value(t, ash.world_len(&world), 100)

	// Despawn half
	for i in 0 ..< 50 {
		ash.world_despawn(&world, entities[i])
	}
	testing.expect_value(t, ash.world_len(&world), 50)

	// Spawn 25 move (should recycle)
	for _ in 0 ..< 25 {
		ash.world_spawn(&world)
	}
	testing.expect_value(t, ash.world_len(&world), 75)
}

@(test)
test_world_despawn_updates_moved_entity :: proc(t: ^testing.T) {
	runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD()
	world := create_test_world()

	pos_id := ash.world_register(&world, Position)

	// TODO:
}
