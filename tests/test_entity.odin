package tests

import "core:testing"

import ".."

@(test)
test_entity_pack_unpack :: proc(t: ^testing.T) {
    e := ash.entity_make(12345, 67)
    testing.expect_value(t, ash.entity_id(e), 12345)
    testing.expect_value(t, ash.entity_version(e), 67)
}

@(test)
test_entity_version_increment :: proc(t: ^testing.T) {
    e1 := ash.entity_make(100, 5)
    e2 := ash.entity_inc_version(e1)
    testing.expect_value(t, ash.entity_id(e2), 100)
    testing.expect_value(t, ash.entity_version(e2), 6)
}

@(test)
test_entity_null :: proc(t: ^testing.T) {
    testing.expect_value(t, ash.entity_id(ash.ENTITY_NULL), 0)
}