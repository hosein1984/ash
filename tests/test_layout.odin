package tests

import "core:testing"
import ash ".."

@(test)
test_layout_hash_order_independent :: proc(t: ^testing.T) {
    // [1, 2, 3] and [3, 1, 2] should represent the same hash after sorting
    ids_a := []ash.Component_ID{1, 2, 3}
    ids_b := []ash.Component_ID{3, 1, 2}

    layout_a := ash.layout_create(ids_a)
    defer ash.layout_destroy(&layout_a)
    layout_b := ash.layout_create(ids_b)
    defer ash.layout_destroy(&layout_b)

    testing.expect(t, ash.layout_hash(&layout_a) == ash.layout_hash(&layout_b))
}

@(test)
test_layout_has :: proc(t: ^testing.T) {
    ids := []ash.Component_ID{1, 3, 5}
    layout := ash.layout_create(ids)
    defer ash.layout_destroy(&layout)

    testing.expect(t, ash.layout_has(&layout, 3), "Should have component 3")
    testing.expect(t, !ash.layout_has(&layout, 2), "Should not have component 2")
}

@(test)
test_layout_with :: proc(t: ^testing.T) {
    ids := []ash.Component_ID{1, 3}
    layout :=ash.layout_create(ids)
    defer ash.layout_destroy(&layout)

    // Add component 2
    new_layout := ash.layout_with(&layout, 2)
    defer ash.layout_destroy(&new_layout)

    testing.expect_value(t, len(new_layout.components), 3)
    testing.expect_value(t, new_layout.components[0], 1)
    testing.expect_value(t, new_layout.components[1], 2)
    testing.expect_value(t, new_layout.components[2], 3)
}

@(test)
test_layout_without :: proc(t: ^testing.T) {
        ids := []ash.Component_ID{1, 2, 3}
    layout :=ash.layout_create(ids)
    defer ash.layout_destroy(&layout)

    // Add component 2
    new_layout := ash.layout_without(&layout, 2)
    defer ash.layout_destroy(&new_layout)

    testing.expect_value(t, len(new_layout.components), 2)
    testing.expect_value(t, new_layout.components[0], 1)
    testing.expect_value(t, new_layout.components[1], 3)
}