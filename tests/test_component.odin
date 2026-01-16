package tests

import "core:testing"

import ".."

@(test)
test_register_component :: proc(t: ^testing.T) {
    reg: ash.Component_Registry
    ash.registry_init(&reg)
    defer ash.registry_destroy(&reg)

    pos_id := ash.registry_register(&reg, Position)
    vel_id := ash.registry_register(&reg, Velocity)

    testing.expect(t, pos_id != vel_id, "IDs should be unique")

    // Re-registring returns the same ID
    pos_id2 := ash.registry_register(&reg, Position)
    testing.expect(t, pos_id == pos_id2)
}

@(test)
test_zero_size_component :: proc(t: ^testing.T) {
    reg: ash.Component_Registry
    ash.registry_init(&reg)
    defer ash.registry_destroy(&reg)

    tag_id      := ash.registry_register(&reg, Tag)
    info, found := ash.registry_get_info(&reg, tag_id)
    
    testing.expect(t, found, "Info should be found")
    testing.expect_value(t, info.size, 0)
}
