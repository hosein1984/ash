package tests

import ash ".."
import "core:testing"

@(test)
test_column_push_get :: proc(t: ^testing.T) {
	col: ash.Component_Column
	ash.column_init(&col, size_of(Position))
	defer ash.column_destroy(&col)

	p1 := Position{1, 2}
	p2 := Position{3, 4}

	ash.column_push(&col, &p1)
	ash.column_push(&col, &p2)

	got1 := ash.column_get(&col, Position, 0)
	testing.expect_value(t, got1^, p1)

	got2 := ash.column_get(&col, Position, 1)
	testing.expect_value(t, got2^, p2)
}

@(test)
test_column_push_empty :: proc(t: ^testing.T) {
    col: ash.Component_Column
    ash.column_init(&col, size_of(Position))
    defer ash.column_destroy(&col)

    idx1 := ash.column_push_empty(&col)
    idx2 := ash.column_push_empty(&col)

    testing.expect_value(t, idx1, 0)
    testing.expect_value(t, idx2, 1)
    testing.expect_value(t, ash.column_len(&col), 2)

    // Values should be zero-initialized
    p1 := ash.column_get(&col, Position, 0)
    testing.expect_value(t, p1^, Position{0, 0})
}

@(test)
test_column_push_empty_zero_size :: proc(t: ^testing.T) {
    col: ash.Component_Column
    ash.column_init(&col, size_of(Tag))
    defer ash.column_destroy(&col)

    // Should be no-op for zero-size
    ash.column_push_empty(&col)
    testing.expect_value(t, ash.column_len(&col), 1)
}

@(test)
test_column_set :: proc(t: ^testing.T) {
	col: ash.Component_Column
	ash.column_init(&col, size_of(Position))
	defer ash.column_destroy(&col)

	p1 := Position{1, 2}
	ash.column_push(&col, &p1)

	p2 := Position{3, 4}
	ash.column_set(&col, 0, &p2)

	got := ash.column_get(&col, Position, 0)
	testing.expect_value(t, got^, p2)
}

@(test)
test_column_swap_remove :: proc(t: ^testing.T) {
	col: ash.Component_Column
	ash.column_init(&col, size_of(i32))
	defer ash.column_destroy(&col)

	// Push [0, 10, 20, 30, 40]
	for i in 0 ..< 5 {
        v := i32(i * 10)
        ash.column_push(&col, &v)
	}
    testing.expect_value(t, ash.column_len(&col), 5)

    // Remove index 1, should swap with 40
    swapped := ash.column_swap_remove(&col, 1)
    testing.expect(t, swapped, "Should have swapped")
    testing.expect_value(t, ash.column_len(&col), 4)

    // Should now be [0, 40, 20, 30]
    got := ash.column_get(&col, i32, 1)
    testing.expect_value(t, got^, i32(40))

    // Remove last element, no swap needed
    swapped2 := ash.column_swap_remove(&col, 3)
    testing.expect(t, !swapped2, "Should not have swapped (was last)")
    testing.expect_value(t, ash.column_len(&col), 3)
}

@(test)
test_column_swap_remove_single :: proc(t: ^testing.T) {
    col: ash.Component_Column
	ash.column_init(&col, size_of(i32))
	defer ash.column_destroy(&col)

    v := i32(42)
    ash.column_push(&col, &v)
    testing.expect_value(t, ash.column_len(&col), 1)

    ash.column_swap_remove(&col, 0)
    testing.expect_value(t, ash.column_len(&col), 0)
}

@(test)
test_column_slice_reinterpret :: proc(t: ^testing.T) {
	col: ash.Component_Column
	ash.column_init(&col, size_of(Position))
	defer ash.column_destroy(&col)

	p1 := Position{1, 1}
	p2 := Position{2, 2}
	p3 := Position{3, 3}

	ash.column_push(&col, &p1)
	ash.column_push(&col, &p2)
	ash.column_push(&col, &p3)

	positions := ash.column_get_slice(&col, Position)
	testing.expect_value(t, len(positions), 3)
	testing.expect_value(t, positions[0], p1)
	testing.expect_value(t, positions[1], p2)
	testing.expect_value(t, positions[2], p3)
}

@(test)
test_column_move :: proc(t: ^testing.T) {
    src: ash.Component_Column
    dst: ash.Component_Column
    ash.column_init(&src, size_of(Position))
    ash.column_init(&dst, size_of(Position))
    defer ash.column_destroy(&src)
    defer ash.column_destroy(&dst)

    p1 := Position{1, 1}
    p2 := Position{2, 2}
    p3 := Position{3, 3}

    ash.column_push(&src, &p1)
    ash.column_push(&src, &p2)
    ash.column_push(&src, &p3)

    // Move index 1 (p2) from src to dst
    ash.column_move(&dst, &src, 1)

    // src should now be [p1, p3] (p3 swapped into p2's spot)
    testing.expect_value(t, ash.column_len(&src), 2)
    src_slice := ash.column_get_slice(&src, Position)
    testing.expect_value(t, src_slice[0], p1)
    testing.expect_value(t, src_slice[1], p3)

    // dst should be [p2]
    testing.expect_value(t, ash.column_len(&dst), 1)
    dst_slice := ash.column_get_slice(&dst, Position)
    testing.expect_value(t, dst_slice[0], p2)
}

@(test)
test_column_zero_size :: proc(t: ^testing.T) {
    col: ash.Component_Column
	ash.column_init(&col, size_of(Tag))
	defer ash.column_destroy(&col)

    testing.expect_value(t, col.elem_size, 0)
    testing.expect_value(t, ash.column_len(&col), 0)

    t1 := Tag{}
    t2 := Tag{}

    ash.column_push(&col, &t1)
    ash.column_push(&col, &t2)

    got1 := ash.column_get(&col, Tag, 0)
    got2 := ash.column_get(&col, Tag, 1)

    testing.expect_value(t, ash.column_len(&col), 2)
    testing.expect_value(t, got1^, t1)
    testing.expect_value(t, got2^, t2)

    // These should be no-ops for zero-size components
    ash.column_swap_remove(&col, 0)
    testing.expect_value(t, ash.column_len(&col), 1)
}
