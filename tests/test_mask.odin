package tests

import "core:testing"

import ".."

@(test)
test_mask_has_add_remove :: proc(t: ^testing.T) {
    mask: ash.Component_Mask

    testing.expect(t, !ash.mask_has(mask, 0), "Empty mask should not have 0")
    testing.expect(t, !ash.mask_has(mask, 5), "Empty mask should not have 5")

    ash.mask_add(&mask, 0)
    ash.mask_add(&mask, 5)
    ash.mask_add(&mask, 63)

    testing.expect(t, ash.mask_has(mask, 0), "Should have 0")
    testing.expect(t, ash.mask_has(mask, 5), "Should have 5")
    testing.expect(t, ash.mask_has(mask, 63), "Should have 63")
    testing.expect(t, !ash.mask_has(mask, 1), "Should not have 1")
    testing.expect(t, !ash.mask_has(mask, 62), "Should not have 62")

    ash.mask_remove(&mask, 5)

    testing.expect(t, ash.mask_has(mask, 0), "Should have 0")
    testing.expect(t, !ash.mask_has(mask, 5), "Should not have 5 after remove")
    testing.expect(t, ash.mask_has(mask, 63), "Should have 63")
}

@(test)
test_mask_from_id :: proc(t: ^testing.T) {
    mask := ash.mask_from_id(7)
    testing.expect(t, ash.mask_has(mask, 7), "Should have 7")
    testing.expect(t, !ash.mask_has(mask, 0), "Should not have 0")
    testing.expect(t, !ash.mask_has(mask, 6), "Should not have 6")
}

@(test)
test_mask_contains_all :: proc(t: ^testing.T) {
    a := ash.Component_Mask{0, 1, 2, 3}
    b := ash.Component_Mask{1, 2}
    c := ash.Component_Mask{1, 5}
    empty := ash.Component_Mask{}

    testing.expect(t, ash.mask_contains_all(a, b), "a contains all of b")
    testing.expect(t, !ash.mask_contains_all(b, a), "b does not contain all of a")
    testing.expect(t, !ash.mask_contains_all(a, c), "a does not contain all of c (missing 5)")
    testing.expect(t, ash.mask_contains_all(a, empty), "Any mask contains empty")
    testing.expect(t, ash.mask_contains_all(empty, empty), "Empty contains empty")
}

@(test)
test_mask_intersects :: proc(t: ^testing.T) {
    a: ash.Component_Mask
    ash.mask_add(&a, 0)
    ash.mask_add(&a, 1)

    b: ash.Component_Mask
    ash.mask_add(&b, 1)
    ash.mask_add(&b, 2)

    c: ash.Component_Mask
    ash.mask_add(&c, 5)
    ash.mask_add(&c, 6)

    empty: ash.Component_Mask

    testing.expect(t, ash.mask_intersects(a, b), "a and b share component 1")
    testing.expect(t, !ash.mask_intersects(a, c), "a and c share nothing")
    testing.expect(t, !ash.mask_intersects(a, empty), "Nothing intersects empty")
    testing.expect(t, !ash.mask_intersects(empty, empty), "Empty doesn't intersect empty")
}

@(test)
test_mask_equals :: proc(t: ^testing.T) {
    a := ash.Component_Mask{1, 2}
    b := ash.Component_Mask{1, 2}
    c := ash.Component_Mask{1}

    testing.expect(t, ash.mask_equals(a, b), "a equals b")
    testing.expect(t, !ash.mask_equals(a, c), "a does not equal c")
}

@(test)
test_mask_count :: proc(t: ^testing.T) {
    mask: ash.Component_Mask
    testing.expect_value(t, ash.mask_count(mask), 0)

    ash.mask_add(&mask, 0)
    testing.expect_value(t, ash.mask_count(mask), 1)

    ash.mask_add(&mask, 5)
    ash.mask_add(&mask, 63)
    testing.expect_value(t, ash.mask_count(mask), 3)
}
