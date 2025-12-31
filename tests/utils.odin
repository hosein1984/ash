package tests

import ash ".."

// odinfmt: disable
Position :: struct { x, y: f32 }
Velocity :: struct { vx, vy: f32 }
Size     :: struct { w, h: f32 }
Sprite   :: struct { id: u32 }
Text     :: struct { s: string }
Shape    :: struct { kind: u8 }
Health   :: struct { hp: i32 }
Poison   :: struct {}
Tag      :: struct {}
A        :: struct {}
B        :: struct {}
C        :: struct {}
D        :: struct {}
// odinfmt: enable


create_test_world :: proc() -> ash.World {
	world: ash.World
	ash.world_init(&world, context.temp_allocator)
	return world
}

create_test_archetype :: proc(
	components: []ash.Component_ID,
	registry: ^ash.Component_Registry,
) -> ash.Archetype {
	arch: ash.Archetype
	ash.archetype_init(&arch, 0, components, registry, context.temp_allocator)
	return arch
}

spawn_with :: proc {
    spawn_with_1,
    spawn_with_2,
    spawn_with_3,
}

spawn_with_1 :: proc(world: ^ash.World, c1: $T1) -> ash.Entity {
    e := ash.world_spawn(world)
    entry := ash.world_entry(world, e)
    ash.entry_add(&entry, c1)
    return e
}

spawn_with_2 :: proc(world: ^ash.World, c1: $T1, c2: $T2) -> ash.Entity {
    e := ash.world_spawn(world)
    entry := ash.world_entry(world, e)
    ash.entry_add(&entry, c1)
    ash.entry_add(&entry, c2)
    return e
}

spawn_with_3 :: proc(world: ^ash.World, c1: $T1, c2: $T2, c3: $T3) -> ash.Entity {
    e := ash.world_spawn(world)
    entry := ash.world_entry(world, e)
    ash.entry_add(&entry, c1)
    ash.entry_add(&entry, c2)
    ash.entry_add(&entry, c3)
    return e
}
