package tests

import "core:testing"

import ".."

@(test)
test_archetype_init_destroy :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)
	vel_id := ash.registry_register(&reg, Velocity)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id, vel_id}, &reg)
	defer ash.archetype_destroy(&arch)

	testing.expect_value(t, len(arch.columns), 2)
	testing.expect_value(t, ash.archetype_entity_count(&arch), 0)
	testing.expect(t, ash.archetype_has(&arch, pos_id), "Should have Position")
	testing.expect(t, ash.archetype_has(&arch, vel_id), "Should have Velocity")
}

@(test)
test_archetype_add_entity :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id}, &reg)
	defer ash.archetype_destroy(&arch)

	e1 := ash.entity_make(1, 0)
	e2 := ash.entity_make(2, 0)

	row1 := ash.archetype_add_entity(&arch, e1)
	row2 := ash.archetype_add_entity(&arch, e2)

	testing.expect_value(t, row1, 0)
	testing.expect_value(t, row2, 1)
	testing.expect_value(t, ash.archetype_entity_count(&arch), 2)
	testing.expect_value(t, arch.entities[0], e1)
	testing.expect_value(t, arch.entities[1], e2)
}

@(test)
test_archetype_swap_remove :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id}, &reg)
	defer ash.archetype_destroy(&arch)

	e1 := ash.entity_make(1, 0)
	e2 := ash.entity_make(2, 0)
	e3 := ash.entity_make(3, 0)

	p1 := Position{1, 1}
	p2 := Position{2, 2}
	p3 := Position{3, 3}

	row1 := ash.archetype_add_entity(&arch, e1)
	row2 := ash.archetype_add_entity(&arch, e2)
	row3 := ash.archetype_add_entity(&arch, e3)

	col := ash.archetype_get_column(&arch, pos_id)
	ash.column_set(col, row1, &p1)
	ash.column_set(col, row2, &p2)
	ash.column_set(col, row3, &p3)

	// Remove middle entity (e2 at row 1)
	moved := ash.archetype_swap_remove(&arch, 1)

	testing.expect_value(t, moved, e3) // e3 was moved to fill the gap
	testing.expect_value(t, ash.archetype_entity_count(&arch), 2)
	testing.expect_value(t, arch.entities[0], e1)
	testing.expect_value(t, arch.entities[1], e3)

	// Verify component data as also swapped
	position := ash.column_get_slice(col, Position)
	testing.expect_value(t, position[0], p1)
	testing.expect_value(t, position[1], p3)
}

@(test)
test_archetype_swap_remove_last :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id}, &reg)
	defer ash.archetype_destroy(&arch)

	e1 := ash.entity_make(1, 0)
	e2 := ash.entity_make(2, 0)

	ash.archetype_add_entity(&arch, e1)
	ash.archetype_add_entity(&arch, e2)

	// Remove last entity - no swap needed
	moved := ash.archetype_swap_remove(&arch, 1)

	testing.expect_value(t, moved, ash.ENTITY_NULL)
	testing.expect_value(t, ash.archetype_entity_count(&arch), 1)
	testing.expect_value(t, arch.entities[0], e1)
}

@(test)
test_archetype_get_column :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)
	vel_id := ash.registry_register(&reg, Velocity)
	health_id := ash.registry_register(&reg, Health)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id, vel_id}, &reg)
	defer ash.archetype_destroy(&arch)

	pos_col := ash.archetype_get_column(&arch, pos_id)
	vel_col := ash.archetype_get_column(&arch, vel_id)
	health_col := ash.archetype_get_column(&arch, health_id)

	testing.expect(t, pos_col != nil, "Should have Position column")
	testing.expect(t, vel_col != nil, "Should have Velocity column")
	testing.expect(t, health_col == nil, "Should not have Health column")
}

@(test)
test_archetype_multiple_component :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	pos_id := ash.registry_register(&reg, Position)
	vel_id := ash.registry_register(&reg, Velocity)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{pos_id, vel_id}, &reg)
	defer ash.archetype_destroy(&arch)

	pos_col := ash.archetype_get_column(&arch, pos_id)
	vel_col := ash.archetype_get_column(&arch, vel_id)

	for i in 0 ..< 3 {
		e := ash.entity_make(u32(i + 1), 0)
		row := ash.archetype_add_entity(&arch, e)

		pos := Position{f32(i), f32(i * 2)}
		vel := Velocity{f32(i) * 0.1, f32(i) * 0.2}

		ash.column_set(pos_col, row, &pos)
		ash.column_set(vel_col, row, &vel)
	}

	testing.expect_value(t, ash.archetype_entity_count(&arch), 3)

	// Verify data
	positions := ash.column_get_slice(pos_col, Position)
	velocities := ash.column_get_slice(vel_col, Velocity)

	testing.expect_value(t, positions[1], Position{1, 2})
	testing.expect_value(t, velocities[2], Velocity{0.2, 0.4})
}

@(test)
test_archetype_zero_size_component :: proc(t: ^testing.T) {
	reg: ash.Component_Registry
	ash.registry_init(&reg)
	defer ash.registry_destroy(&reg)

	tag_id := ash.registry_register(&reg, Tag)
	pos_id := ash.registry_register(&reg, Position)

	arch: ash.Archetype
	ash.archetype_init(&arch, 0, []ash.Component_ID{tag_id, pos_id}, &reg)
	defer ash.archetype_destroy(&arch)

	e := ash.entity_make(1, 0)
	ash.archetype_add_entity(&arch, e)

	testing.expect_value(t, ash.archetype_entity_count(&arch), 1)
	testing.expect(t, ash.archetype_has(&arch, tag_id), "Should have tag")

	// Tag column exists but has zero size
	tag_col := ash.archetype_get_column(&arch, tag_id)
	testing.expect(t, tag_col != nil, "Tag column should exist")
	testing.expect_value(t, tag_col.elem_size, 0)
}
