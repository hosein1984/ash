package systems

import "core:fmt"
import "core:math/rand"

import ash "../.."

// ============================================================================
// COMPONENTS
// ============================================================================

Position :: struct {
	x, y: f32,
}

Velocity :: struct {
	vx, vy: f32,
}

// ============================================================================
// SYSTEMS - Just procedures that operate on the world
// ============================================================================

// Creates initial entities
spawn_entities_system :: proc(world: ^ash.World, count: int) {
	for _ in 0 ..< count {
		ash.world_spawn(
			world,
			Position{x = rand.float32() * 100, y = rand.float32() * 100},
			Velocity{vx = rand.float32() - 0.5, vy = rand.float32() - 0.5},
		)
	}
	fmt.printfln("Spawned %d entities", count)
}

// Updates positions based on velocity
movement_system :: proc(world: ^ash.World) {
    filter := ash.filter_contains(world, {Position, Velocity})
	query  := ash.world_query(world, filter)

	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		pos.x += vel.vx
		pos.y += vel.vy
	}
}

// Wraps entities at world boundaries
bounds_system :: proc(world: ^ash.World, width, height: f32) {
    filter := ash.filter_contains(world, {Position})
	query  := ash.world_query(world, filter)

	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		
		if pos.x < 0       { pos.x += width }
		if pos.x >= width  { pos.x -= width }
		if pos.y < 0       { pos.y += height }
		if pos.y >= height { pos.y -= height }
	}
}

// Prints statistics
stats_system :: proc(world: ^ash.World, tick: int) {
    filter := ash.filter_contains(world, {Position})
	query  := ash.world_query(world, filter)

	sum_x, sum_y: f32
	count := 0

	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		sum_x += pos.x
		sum_y += pos.y
		count += 1
	}

	if count > 0 {
		fmt.printfln("Tick %4d: %d entities, avg pos (%.2f, %.2f)",
			tick, count, sum_x / f32(count), sum_y / f32(count))
	}
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// World bounds
	world_width:  f32 = 100
	world_height: f32 = 100

    // Initialize - create entities
    spawn_entities_system(&world, 100)

	// Game loop - you control the order explicitly
	fmt.println("\n=== Running simulation ===\n")
	
	for tick in 1 ..= 100 {
		// 1. Movement
		movement_system(&world)

		// 2. Bounds checking
		bounds_system(&world, world_width, world_height)

		// 3. Stats (every 20 ticks)
		if tick % 20 == 0 {
			stats_system(&world, tick)
		}
	}

	fmt.println("\n=== Simulation complete ===")
}