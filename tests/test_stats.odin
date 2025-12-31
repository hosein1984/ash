package tests

import ash ".."
import "core:testing"

@(test)
test_world_stats :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	ash.world_register(&world, Position)
	ash.world_register(&world, Velocity)

	e1 := ash.world_spawn(&world)
	entry1 := ash.world_entry(&world, e1)
	ash.entry_add(&entry1, Position{1, 2})

	e2 := ash.world_spawn(&world)
	entry2 := ash.world_entry(&world, e2)
	ash.entry_add(&entry2, Position{3, 4})
	ash.entry_add(&entry2, Velocity{1, 1})

	stats := ash.world_stats(&world)
	defer ash.world_stats_destroy(&stats)
    ash.world_stats_print(&stats)

	testing.expect_value(t, stats.entity_count, 2)
	testing.expect_value(t, stats.archetype_count, 2)
	testing.expect_value(t, stats.component_count, 2)
	testing.expect_value(t, stats.free_list_count, 0)
	testing.expect(t, stats.total_memory > 0, "Should track memory")
}
