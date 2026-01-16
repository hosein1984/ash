package tests

import "core:testing"

import ".."

@(test)
test_location_map_basic :: proc(t: ^testing.T) {
	lm: ash.Location_Map
	ash.location_map_init(&lm)
	defer ash.location_map_destroy(&lm)

	// Empty state
	testing.expect_value(t, ash.location_map_len(&lm), 0)
	testing.expect(t, !ash.location_map_contains(&lm, 5), "Should be empty")

	// Insert and retrieve
	ash.location_map_insert(&lm, 5, ash.Archetype_Index(2), 10)
	testing.expect_value(t, ash.location_map_len(&lm), 1)
	testing.expect(t, ash.location_map_contains(&lm, 5), "Should contain 5")

	loc, ok := ash.location_map_get(&lm, 5)
	testing.expect(t, ok, "Should find entity 5")
	testing.expect_value(t, loc.archetype, ash.Archetype_Index(2))
	testing.expect_value(t, loc.row, 10)

	// Get nonexistent
	_, ok2 := ash.location_map_get(&lm, 999)
	testing.expect(t, !ok2, "Should not find 999")
}

@(test)
test_location_map_update :: proc(t: ^testing.T) {
	lm: ash.Location_Map
	ash.location_map_init(&lm)
	defer ash.location_map_destroy(&lm)

	ash.location_map_insert(&lm, 5, ash.Archetype_Index(1), 10)

	// Update same ID - count should stay 1
	ash.location_map_insert(&lm, 5, ash.Archetype_Index(2), 20)
	testing.expect_value(t, ash.location_map_len(&lm), 1)

	loc, _ := ash.location_map_get(&lm, 5)
	testing.expect_value(t, loc.archetype, ash.Archetype_Index(2))
	testing.expect_value(t, loc.row, 20)

	// set_row updates only row
	ash.location_map_set_row(&lm, 5, 99)
	loc2, _ := ash.location_map_get(&lm, 5)
	testing.expect_value(t, loc2.archetype, ash.Archetype_Index(2)) // unchanged
	testing.expect_value(t, loc2.row, 99)
}

@(test)
test_location_map_remove :: proc(t: ^testing.T) {
	lm: ash.Location_Map
	ash.location_map_init(&lm)
	defer ash.location_map_destroy(&lm)

	ash.location_map_insert(&lm, 5, ash.Archetype_Index(1), 10)
	ash.location_map_remove(&lm, 5)

	testing.expect_value(t, ash.location_map_len(&lm), 0)
	testing.expect(t, !ash.location_map_contains(&lm, 5), "Should be removed")

	// Remove nonexistent - no-op
	ash.location_map_remove(&lm, 999)
	testing.expect_value(t, ash.location_map_len(&lm), 0)

	// Reinsert after remove
	ash.location_map_insert(&lm, 5, ash.Archetype_Index(3), 25)
	testing.expect_value(t, ash.location_map_len(&lm), 1)

	loc, ok := ash.location_map_get(&lm, 5)
	testing.expect(t, ok, "Should find reinserted entity")
	testing.expect_value(t, loc.archetype, ash.Archetype_Index(3))
}

@(test)
test_location_map_sparse_ids :: proc(t: ^testing.T) {
	lm: ash.Location_Map
	ash.location_map_init(&lm)
	defer ash.location_map_destroy(&lm)

	// Sparse IDs with gaps
	ash.location_map_insert(&lm, 100, ash.Archetype_Index(0), 0)
	ash.location_map_insert(&lm, 500, ash.Archetype_Index(1), 1)
	ash.location_map_insert(&lm, 1000, ash.Archetype_Index(2), 2)

	testing.expect_value(t, ash.location_map_len(&lm), 3)
	testing.expect(t, ash.location_map_contains(&lm, 100), "Should have 100")
	testing.expect(t, ash.location_map_contains(&lm, 500), "Should have 500")
	testing.expect(t, ash.location_map_contains(&lm, 1000), "Should have 1000")
	testing.expect(t, !ash.location_map_contains(&lm, 50), "Gap should be empty")
	testing.expect(t, !ash.location_map_contains(&lm, 300), "Gap should be empty")
}

@(test)
test_location_map_multiple_operations :: proc(t: ^testing.T) {
	lm: ash.Location_Map
	ash.location_map_init(&lm)
	defer ash.location_map_destroy(&lm)

	// Insert 5 entities
	for i in 1 ..= 5 {
		ash.location_map_insert(&lm, u32(i), ash.Archetype_Index(0), i * 10)
	}
	testing.expect_value(t, ash.location_map_len(&lm), 5)

	// Remove odd
	ash.location_map_remove(&lm, 1)
	ash.location_map_remove(&lm, 3)
	ash.location_map_remove(&lm, 5)

	testing.expect_value(t, ash.location_map_len(&lm), 2)
	testing.expect(t, !ash.location_map_contains(&lm, 1), "1 removed")
	testing.expect(t, ash.location_map_contains(&lm, 2), "2 exists")
	testing.expect(t, !ash.location_map_contains(&lm, 3), "3 removed")
	testing.expect(t, ash.location_map_contains(&lm, 4), "4 exists")
}
