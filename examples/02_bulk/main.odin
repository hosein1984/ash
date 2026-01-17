package bulk

import "core:fmt"
import "core:math/rand"
import "core:time"

import ash "../.."

// ============================================================================
// COMPONENTS
// ============================================================================

Position :: struct {
	x, y: f64,
}

Velocity :: struct {
	vx, vy: f64,
}

// ============================================================================
// ITERATION PATTERNS
// ============================================================================

// Entry-by-entry iteration - more convenient, slightly slower
update_entry_style :: proc(query: ^ash.Query) {
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		
		pos.x += vel.vx
		pos.y += vel.vy
	}
}

// Bulk/archetype iteration - more verbose, faster for large datasets
update_bulk_style :: proc(query: ^ash.Query, pos_id, vel_id: ash.Component_ID) {
	it := ash.query_iter_archs(query)
	for arch in ash.query_next_arch(&it) {
		// Get slices of all components in this archetype
		positions := ash.archetype_slice(arch, Position, pos_id)
		velocities := ash.archetype_slice(arch, Velocity, vel_id)
		
		// Process all entities in the archetype contiguously
		for i in 0 ..< len(positions) {
			positions[i].x += velocities[i].vx
			positions[i].y += velocities[i].vy
		}
	}
}

// ============================================================================
// BENCHMARK
// ============================================================================

benchmark :: proc(name: string, iterations: int, proc_fn: proc()) -> time.Duration {
	start := time.now()
	for _ in 0 ..< iterations {
		proc_fn()
	}
	return time.diff(start, time.now())
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	// Get component IDs for bulk iteration
	pos_id := ash.world_register(&world, Position)
	vel_id := ash.world_register(&world, Velocity)

	// Create entities
	entity_count :: 100_000
	for _ in 0 ..< entity_count {
		ash.world_spawn(
			&world,
			Position{x = rand.float64() * 100, y = rand.float64() * 100},
			Velocity{vx = rand.float64() - 0.5, vy = rand.float64() - 0.5},
		)
	}

	fmt.printfln("Created %d entities\n", entity_count)

	// Create query
	filter := ash.filter_contains(&world, {Position, Velocity})
	query  := ash.world_query(&world, filter)

	// Benchmark parameters
	iterations :: 100

	// Benchmark entry-style iteration
	start := time.now()
	for _ in 0 ..< iterations {
		update_entry_style(query)
	}
	entry_duration := time.diff(start, time.now())

	// Benchmark bulk-style iteration  
	start = time.now()
	for _ in 0 ..< iterations {
		update_bulk_style(query, pos_id, vel_id)
	}
	bulk_duration := time.diff(start, time.now())

	// Report results
	fmt.println("=== Benchmark Results ===")
	fmt.printfln("Entities:   %d", entity_count)
	fmt.printfln("Iterations: %d\n", iterations)

	entry_ns := f64(time.duration_nanoseconds(entry_duration)) / f64(iterations)
	bulk_ns  := f64(time.duration_nanoseconds(bulk_duration))  / f64(iterations)
	
	entry_per_entity := entry_ns / f64(entity_count)
	bulk_per_entity  := bulk_ns  / f64(entity_count)

	fmt.printfln("Entry-style: %.2f ms/iter (%.2f ns/entity)", entry_ns / 1_000_000, entry_per_entity)
	fmt.printfln("Bulk-style:  %.2f ms/iter (%.2f ns/entity)", bulk_ns / 1_000_000, bulk_per_entity)
	
	if bulk_ns < entry_ns {
		speedup := entry_ns / bulk_ns
		fmt.printfln("\nBulk iteration is %.2fx faster", speedup)
	} else {
		speedup := bulk_ns / entry_ns
		fmt.printfln("\nEntry iteration is %.2fx faster", speedup)
	}

	fmt.println("\nNote: Run with -o:speed for accurate benchmarks")
}