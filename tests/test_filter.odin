package tests

import "base:runtime"
import "core:testing"

import ".."

create_test_archetype :: proc(
	components: []ash.Component_ID,
	registry: ^ash.Component_Registry,
) -> ash.Archetype {
	arch: ash.Archetype
	ash.archetype_init(&arch, 0, components, registry, context.temp_allocator)
	return arch
}

@(test)
test_filter_contains_single :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)

	filter := ash.filter_contains(&world, {Position})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, vel_id}, &world.registry)
	arch3 := create_test_archetype({vel_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_filter_contains_multiple :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)
	health_id := ash.world_register(&world, Health)

	filter := ash.filter_contains(&world, {Position, Velocity})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, vel_id}, &world.registry)
	arch3 := create_test_archetype({pos_id, vel_id, health_id}, &world.registry)

	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_filter_contains_empty :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)

	filter := ash.filter_contains(&world, {})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
}

@(test)
test_filter_create_requires_only :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)

	filter := ash.filter_create(&world, requires = {Position, Velocity})

	arch := create_test_archetype({pos_id, vel_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch))
}

@(test)
test_filter_create_excludes_only :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	poison_id := ash.world_register(&world, Poison)

	filter := ash.filter_create(&world, excludes = {Poison})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({}, &world.registry)
	arch3 := create_test_archetype({poison_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_create_filter_anyof_only :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	sprite_id := ash.world_register(&world, Sprite)
	text_id := ash.world_register(&world, Text)

	filter := ash.filter_create(&world, anyof = {Sprite, Text})

	arch1 := create_test_archetype({sprite_id}, &world.registry)
	arch2 := create_test_archetype({text_id}, &world.registry)
	arch3 := create_test_archetype({pos_id}, &world.registry)
	arch4 := create_test_archetype({pos_id, sprite_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch4))
}


@(test)
test_filter_create_requires_excludes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)
	poison_id := ash.world_register(&world, Poison)

	filter := ash.filter_create(&world, requires = {Position}, excludes = {Poison})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, vel_id}, &world.registry)
	arch3 := create_test_archetype({pos_id, poison_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_filter_create_multiple_excludes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	poison_id := ash.world_register(&world, Poison)
	tag_id := ash.world_register(&world, Tag)

	filter := ash.filter_create(&world, requires = {Position}, excludes = {Poison, Tag})

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, poison_id}, &world.registry)
	arch3 := create_test_archetype({pos_id, tag_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_filter_create_requires_anyof :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	size_id := ash.world_register(&world, Size)
	sprite_id := ash.world_register(&world, Sprite)
	text_id := ash.world_register(&world, Text)
	shape_id := ash.world_register(&world, Shape)

	filter := ash.filter_create(&world, requires = {Position, Size}, anyof = {Sprite, Text, Shape})

	arch1 := create_test_archetype({pos_id, size_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, size_id, sprite_id}, &world.registry)
	arch3 := create_test_archetype({pos_id, size_id, text_id}, &world.registry)
	arch4 := create_test_archetype({pos_id, size_id, sprite_id, text_id}, &world.registry)
	arch5 := create_test_archetype({pos_id, sprite_id}, &world.registry)

	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch4))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch5))
}

@(test)
test_filter_create_combo :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	size_id := ash.world_register(&world, Size)
	sprite_id := ash.world_register(&world, Sprite)
	text_id := ash.world_register(&world, Text)
	poison_id := ash.world_register(&world, Poison)

	filter := ash.filter_create(
		&world,
		requires = {Position, Size},
		excludes = {Poison},
		anyof = {Sprite, Text},
	)

	arch1 := create_test_archetype({pos_id, size_id, sprite_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, size_id, text_id}, &world.registry)
	arch3 := create_test_archetype({pos_id, size_id, sprite_id, poison_id}, &world.registry)
	arch4 := create_test_archetype({pos_id, size_id}, &world.registry)
	arch5 := create_test_archetype({pos_id, sprite_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch4))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch5))
}

@(test)
test_filter_create_exact :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)
	health_id := ash.world_register(&world, Health)

	filter := ash.filter_create(&world, requires = {Position, Velocity}, exact = true)

	arch1 := create_test_archetype({pos_id, vel_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, vel_id, health_id}, &world.registry)
	arch3 := create_test_archetype({pos_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch3))
}

@(test)
test_filter_create_exact_empty :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)

	filter := ash.filter_create(&world, requires = {}, exact = true)

	arch1 := create_test_archetype({}, &world.registry)
	arch2 := create_test_archetype({pos_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch2))
}

@(test)
test_filter_or_requires :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	a_id := ash.world_register(&world, A)
	b_id := ash.world_register(&world, B)
	c_id := ash.world_register(&world, C)
	d_id := ash.world_register(&world, D)
	
    // odinfmt: disable
	// Or(
    //   Contains(A, B),
    //   Contains(C, D)
    // )
	filter := ash.filter_or(
		&world,
		{
            {requires = {A, B}}, 
            {requires = {C, D}}
        },
	)
    // odinfmt: enable

	arch1 := create_test_archetype({a_id, b_id}, &world.registry)
	arch2 := create_test_archetype({c_id, d_id}, &world.registry)
	arch3 := create_test_archetype({a_id, b_id, c_id, d_id}, &world.registry)
	arch4 := create_test_archetype({a_id, c_id}, &world.registry)
	arch5 := create_test_archetype({a_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch4))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch5))
}

@(test)
test_filter_or_requires_excludes :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	a_id := ash.world_register(&world, A)
	b_id := ash.world_register(&world, B)
	c_id := ash.world_register(&world, C)
	d_id := ash.world_register(&world, D)
	
    // odinfmt: disable
	// Or(
    //   And(A, Not(B)), 
    //   And(C, Not(D))
    // )
	filter := ash.filter_or(
		&world,
		{
            {requires = {A}, excludes = {B}}, 
            {requires = {C}, excludes = {D}}
        },
	)
    // odinfmt: enable

	arch1 := create_test_archetype({a_id}, &world.registry)
	arch2 := create_test_archetype({a_id, b_id}, &world.registry)
	arch3 := create_test_archetype({c_id}, &world.registry)
	arch4 := create_test_archetype({c_id, d_id}, &world.registry)
	arch5 := create_test_archetype({a_id, c_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch4))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch5))
}

@(test)
test_filter_or_requires_anyof :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	sprite_id := ash.world_register(&world, Sprite)
	text_id := ash.world_register(&world, Text)
	health_id := ash.world_register(&world, Health)
	a_id := ash.world_register(&world, A)
	b_id := ash.world_register(&world, B)
	
    // odinfmt: disable
	// Or(
	//   And(Position, Or(Sprite, Text)),
	//   And(Health, Or(A, B))
	// )
	filter := ash.filter_or(
		&world,
		{
            {requires = {Position}, anyof = {Sprite, Text}}, 
            {requires = {Health}, anyof = {A, B}}
        },
	)
    // odinfmt: enable

	arch1 := create_test_archetype({pos_id, sprite_id}, &world.registry)
	arch2 := create_test_archetype({pos_id}, &world.registry)
	arch3 := create_test_archetype({health_id, a_id}, &world.registry)
	arch4 := create_test_archetype({health_id}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
	testing.expect(t, !ash.filter_matches_archetype(&filter, &arch4))
}

@(test)
test_filter_all :: proc(t: ^testing.T) {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)

	filter := ash.FILTER_ALL

	arch1 := create_test_archetype({pos_id}, &world.registry)
	arch2 := create_test_archetype({pos_id, vel_id}, &world.registry)
	arch3 := create_test_archetype({}, &world.registry)

	testing.expect(t, ash.filter_matches_archetype(&filter, &arch1))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch2))
	testing.expect(t, ash.filter_matches_archetype(&filter, &arch3))
}
