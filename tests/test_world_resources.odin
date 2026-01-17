package tests

import "core:testing"

import ".."

Time_Resource :: struct {
    delta:   f32,
    elapsed: f32,
    frame:   u64,
}

Input_Resource :: struct {
    mouse_x, mouse_y: i32,
    mouse_buttons:    bit_set[0 ..< 8],
}

@(test)
test_resource_get_set :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    time := Time_Resource {
        delta   = 0.016,
        elapsed = 100.0,
        frame   = 6000,
    }
    ash.world_set_resource(&world, &time)

    fetched := ash.world_get_resource(&world, Time_Resource)

    testing.expect(t, fetched != nil)
    testing.expect_value(t, fetched.delta, 0.016)
    testing.expect_value(t, fetched.elapsed, 100.0)
}


@(test)
test_resource_multiple_types :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    time := Time_Resource {
        delta = 0.016,
    }
    input := Input_Resource {
        mouse_x = 100,
        mouse_y = 200,
    }

    ash.world_set_resource(&world, &time)
    ash.world_set_resource(&world, &input)

    testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.016)
    testing.expect_value(t, ash.world_get_resource(&world, Input_Resource).mouse_x, 100)
}

@(test)
test_resource_not_found :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    fetched := ash.world_get_resource(&world, Time_Resource)
    testing.expect(t, fetched == nil)
}

@(test)
test_resource_modification :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    time := Time_Resource {
        delta = 0.016,
    }
    ash.world_set_resource(&world, &time)

    // Modify via fetched pointer
    fetched := ash.world_get_resource(&world, Time_Resource)
    fetched.delta = 0.033

    // Original should be modified (same memory)
    testing.expect_value(t, time.delta, 0.033)
}

@(test)
test_resource_remove :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    time := Time_Resource{}
    ash.world_set_resource(&world, &time)

    testing.expect(t, ash.world_has_resource(&world, Time_Resource))

    ash.world_remove_resource(&world, Time_Resource)

    testing.expect(t, !ash.world_has_resource(&world, Time_Resource))
}

@(test)
test_resource_replace :: proc(t: ^testing.T) {
    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    time1 := Time_Resource {
        delta = 0.016,
    }
    time2 := Time_Resource {
        delta = 0.033,
    }

    ash.world_set_resource(&world, &time1)
    testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.016)

    ash.world_set_resource(&world, &time2)
    testing.expect_value(t, ash.world_get_resource(&world, Time_Resource).delta, 0.033)
}