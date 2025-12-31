package benchmark

import ash "../.."
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:time"

// odinfmt: disable
Position :: struct { x, y: f64 }
Velocity :: struct { x, y: f64 }
C1       :: struct { v: f64 }
C2       :: struct { v: f64 }
C3       :: struct { v: f64 }
C4       :: struct { v: f64 }
C5       :: struct { v: f64 }
C6       :: struct { v: f64 }
C7       :: struct { v: f64 }
C8       :: struct { v: f64 }
C9       :: struct { v: f64 }
C10      :: struct { v: f64 }
// odinfmt: enable

// ============================================================================
// Benchmark Context
// ============================================================================

@(private)
g_ctx: Bench_Context

Bench_Context :: struct {
	world:    ash.World,
	entities: [dynamic]ash.Entity,
	query:    ash.Query,
	pos_id:   ash.Component_ID,
	vel_id:   ash.Component_ID,
	n:        int,
}

// ============================================================================
// QUERY 2 COMPONENTS
// ============================================================================

setup_query_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)

	g_ctx.n = options.bytes // We use 'bytes' field to pass N
	g_ctx.pos_id = ash.world_register(&g_ctx.world, Position)
	g_ctx.vel_id = ash.world_register(&g_ctx.world, Velocity)

	// Create n*10 entities with just Position (noise)
	for _ in 0 ..< (g_ctx.n * 10) {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
	}

	// Create n entities with Position + Velocity
	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, Velocity{1, 1})
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.query_create(&g_ctx.world, filter, allocator)

	return nil
}

bench_query_2comp_entry :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter(&g_ctx.query)
		for entry in ash.query_next(&it) {
			pos := ash.entry_get(entry, Position)
			vel := ash.entry_get(entry, Velocity)
			pos.x += vel.x
			pos.y += vel.y
		}


	}

	options.count = options.rounds * g_ctx.n // Total operations
	return nil
}

bench_query_2comp_bulk :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(&g_ctx.query)
		for arch in ash.query_next_arch(&it) {
			positions := ash.archetype_slice(arch, Position, g_ctx.pos_id)
			velocities := ash.archetype_slice(arch, Velocity, g_ctx.vel_id)

			for i in 0 ..< len(positions) {
				positions[i].x += velocities[i].x
				positions[i].y += velocities[i].y
			}
		}
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

teardown_query :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	ash.query_destroy(&g_ctx.query)
	ash.world_destroy(&g_ctx.world)
	delete(g_ctx.entities)
	return nil
}

// ============================================================================
// QUERY 32 ARCHETYPES
// ============================================================================

setup_query_32arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)

	g_ctx.n = options.bytes
	g_ctx.pos_id = ash.world_register(&g_ctx.world, Position)
	g_ctx.vel_id = ash.world_register(&g_ctx.world, Velocity)
	ash.world_register(&g_ctx.world, C1)
	ash.world_register(&g_ctx.world, C2)
	ash.world_register(&g_ctx.world, C3)
	ash.world_register(&g_ctx.world, C4)
	ash.world_register(&g_ctx.world, C5)

	for i in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)

		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, Velocity{1, 1})

		if i & 1 != 0 {ash.entry_add(&entry, C1{})}
		if i & 2 != 0 {ash.entry_add(&entry, C2{})}
		if i & 4 != 0 {ash.entry_add(&entry, C3{})}
		if i & 8 != 0 {ash.entry_add(&entry, C4{})}
		if i & 16 != 0 {ash.entry_add(&entry, C5{})}
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.query_create(&g_ctx.world, filter, allocator)

	return nil
}

bench_query_32arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(&g_ctx.query)
		for arch in ash.query_next_arch(&it) {
			positions := ash.archetype_slice(arch, Position, g_ctx.pos_id)
			velocities := ash.archetype_slice(arch, Velocity, g_ctx.vel_id)

			for i in 0 ..< len(positions) {
				positions[i].x += velocities[i].x
				positions[i].y += velocities[i].y
			}
		}
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

// ============================================================================
// QUERY 256 ARCHETYPES
// ============================================================================

setup_query_256arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)

	g_ctx.n = options.bytes
	g_ctx.pos_id = ash.world_register(&g_ctx.world, Position)
	g_ctx.vel_id = ash.world_register(&g_ctx.world, Velocity)
	ash.world_register(&g_ctx.world, C1)
	ash.world_register(&g_ctx.world, C2)
	ash.world_register(&g_ctx.world, C3)
	ash.world_register(&g_ctx.world, C4)
	ash.world_register(&g_ctx.world, C5)
	ash.world_register(&g_ctx.world, C6)
	ash.world_register(&g_ctx.world, C7)
	ash.world_register(&g_ctx.world, C8)

	// n entities with Position + Velocity (queried)
	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, Velocity{1, 1})
	}

	// n*4 noise entities across 256 archetypes
	for i in 0 ..< (g_ctx.n * 4) {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)

		ash.entry_add(&entry, Position{})

		if i & 1 != 0 {ash.entry_add(&entry, C1{})}
		if i & 2 != 0 {ash.entry_add(&entry, C2{})}
		if i & 4 != 0 {ash.entry_add(&entry, C3{})}
		if i & 8 != 0 {ash.entry_add(&entry, C4{})}
		if i & 16 != 0 {ash.entry_add(&entry, C5{})}
		if i & 32 != 0 {ash.entry_add(&entry, C6{})}
		if i & 64 != 0 {ash.entry_add(&entry, C7{})}
		if i & 128 != 0 {ash.entry_add(&entry, C8{})}
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.query_create(&g_ctx.world, filter, allocator)

	return nil
}

bench_query_256arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(&g_ctx.query)
		for arch in ash.query_next_arch(&it) {
			positions := ash.archetype_slice(arch, Position, g_ctx.pos_id)
			velocities := ash.archetype_slice(arch, Velocity, g_ctx.vel_id)

			for i in 0 ..< len(positions) {
				positions[i].x += velocities[i].x
				positions[i].y += velocities[i].y
			}
		}
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

// ============================================================================
// CREATE 2 COMPONENTS
// ============================================================================

setup_create_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, Position)
	ash.world_register(&g_ctx.world, Velocity)

	// Warmup
	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, Velocity{})
		append(&g_ctx.entities, e)
	}
	for e in g_ctx.entities {ash.world_despawn(&g_ctx.world, e)}
	clear(&g_ctx.entities)

	return nil
}

bench_create_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		for _ in 0 ..< g_ctx.n {
			e := ash.world_spawn(&g_ctx.world)
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_add(&entry, Position{})
			ash.entry_add(&entry, Velocity{})
			append(&g_ctx.entities, e)
		}
		for e in g_ctx.entities {ash.world_despawn(&g_ctx.world, e)}
		clear(&g_ctx.entities)
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

teardown_world :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	ash.world_destroy(&g_ctx.world)
	delete(g_ctx.entities)
	return nil
}

// ============================================================================
// CREATE 2 COMPONENTS (new world each round)
// ============================================================================

bench_create_2comp_alloc :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	n := options.bytes

	for _ in 0 ..< options.rounds {
		world: ash.World
		ash.world_init(&world, allocator)

		ash.world_register(&world, Position)
		ash.world_register(&world, Velocity)

		for _ in 0 ..< n {
			e := ash.world_spawn(&world)
			entry := ash.world_entry(&world, e)
			ash.entry_add(&entry, Position{})
			ash.entry_add(&entry, Velocity{})
		}

		ash.world_destroy(&world)
	}

	options.count = options.rounds * n
	return nil
}

// ============================================================================
// CREATE 10 COMPONENTS
// ============================================================================

setup_create_10comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, C1)
	ash.world_register(&g_ctx.world, C2)
	ash.world_register(&g_ctx.world, C3)
	ash.world_register(&g_ctx.world, C4)
	ash.world_register(&g_ctx.world, C5)
	ash.world_register(&g_ctx.world, C6)
	ash.world_register(&g_ctx.world, C7)
	ash.world_register(&g_ctx.world, C8)
	ash.world_register(&g_ctx.world, C9)
	ash.world_register(&g_ctx.world, C10)

	// Warmup
	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn_with(
			&g_ctx.world,
			C1{},
			C2{},
			C3{},
			C4{},
			C5{},
			C6{},
			C7{},
			C8{},
			C9{},
			C10{},
		)
		append(&g_ctx.entities, e)
	}
	for e in g_ctx.entities {ash.world_despawn(&g_ctx.world, e)}
	clear(&g_ctx.entities)

	return nil
}

bench_create_10comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		for _ in 0 ..< g_ctx.n {
			e := ash.world_spawn_with(
				&g_ctx.world,
				C1{},
				C2{},
				C3{},
				C4{},
				C5{},
				C6{},
				C7{},
				C8{},
				C9{},
				C10{},
			)
			append(&g_ctx.entities, e)
		}
		for e in g_ctx.entities {ash.world_despawn(&g_ctx.world, e)}
		clear(&g_ctx.entities)
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

// ============================================================================
// DELETE 2 COMPONENTS
// ============================================================================

setup_delete_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, Position)
	ash.world_register(&g_ctx.world, Velocity)

	// Pre-create all entities for ALL rounds
	total_entities := g_ctx.n * options.rounds
	for _ in 0 ..< total_entities {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, Velocity{})
		append(&g_ctx.entities, e)
	}

	return nil
}

bench_delete_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	// Just delete - all entities pre-created in setup
	for e in g_ctx.entities {
		ash.world_despawn(&g_ctx.world, e)
	}

	options.count = len(g_ctx.entities)
	return nil
}

// ============================================================================
// DELETE 10 COMPONENTS
// ============================================================================

setup_delete_10comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, C1)
	ash.world_register(&g_ctx.world, C2)
	ash.world_register(&g_ctx.world, C3)
	ash.world_register(&g_ctx.world, C4)
	ash.world_register(&g_ctx.world, C5)
	ash.world_register(&g_ctx.world, C6)
	ash.world_register(&g_ctx.world, C7)
	ash.world_register(&g_ctx.world, C8)
	ash.world_register(&g_ctx.world, C9)
	ash.world_register(&g_ctx.world, C10)

	return nil
}

bench_delete_10comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		// Create
		for _ in 0 ..< g_ctx.n {
			e := ash.world_spawn(&g_ctx.world)
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_add(&entry, C1{})
			ash.entry_add(&entry, C2{})
			ash.entry_add(&entry, C3{})
			ash.entry_add(&entry, C4{})
			ash.entry_add(&entry, C5{})
			ash.entry_add(&entry, C6{})
			ash.entry_add(&entry, C7{})
			ash.entry_add(&entry, C8{})
			ash.entry_add(&entry, C9{})
			ash.entry_add(&entry, C10{})
			append(&g_ctx.entities, e)
		}

		// Delete
		for e in g_ctx.entities {
			ash.world_despawn(&g_ctx.world, e)
		}
		clear(&g_ctx.entities)
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

// ============================================================================
// ADD/REMOVE COMPONENT
// ============================================================================

setup_add_remove :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, Position)
	ash.world_register(&g_ctx.world, Velocity)

	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		append(&g_ctx.entities, e)
	}

	// Warmup
	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Velocity{})
	}
	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_remove(&entry, Velocity)
	}

	return nil
}

bench_add_remove :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		for e in g_ctx.entities {
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_add(&entry, Velocity{})
		}
		for e in g_ctx.entities {
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_remove(&entry, Velocity)
		}
	}

	options.count = options.rounds * g_ctx.n * 2 // add + remove
	return nil
}

// ============================================================================
// ADD/REMOVE LARGE (11 components)
// ============================================================================

setup_add_remove_large :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	ash.world_register(&g_ctx.world, Position)
	ash.world_register(&g_ctx.world, Velocity)
	ash.world_register(&g_ctx.world, C1)
	ash.world_register(&g_ctx.world, C2)
	ash.world_register(&g_ctx.world, C3)
	ash.world_register(&g_ctx.world, C4)
	ash.world_register(&g_ctx.world, C5)
	ash.world_register(&g_ctx.world, C6)
	ash.world_register(&g_ctx.world, C7)
	ash.world_register(&g_ctx.world, C8)
	ash.world_register(&g_ctx.world, C9)
	ash.world_register(&g_ctx.world, C10)

	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		ash.entry_add(&entry, C1{})
		ash.entry_add(&entry, C2{})
		ash.entry_add(&entry, C3{})
		ash.entry_add(&entry, C4{})
		ash.entry_add(&entry, C5{})
		ash.entry_add(&entry, C6{})
		ash.entry_add(&entry, C7{})
		ash.entry_add(&entry, C8{})
		ash.entry_add(&entry, C9{})
		ash.entry_add(&entry, C10{})
		append(&g_ctx.entities, e)
	}

	// Warmup
	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Velocity{})
	}
	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_remove(&entry, Velocity)
	}

	return nil
}

bench_add_remove_large :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		for e in g_ctx.entities {
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_add(&entry, Velocity{})
		}
		for e in g_ctx.entities {
			entry := ash.world_entry(&g_ctx.world, e)
			ash.entry_remove(&entry, Velocity)
		}
	}

	options.count = options.rounds * g_ctx.n * 2
	return nil
}

// ============================================================================
// RANDOM ACCESS
// ============================================================================

setup_random_access :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	g_ctx = {}
	ash.world_init(&g_ctx.world, allocator)
	g_ctx.entities = make([dynamic]ash.Entity, allocator)
	g_ctx.n = options.bytes

	g_ctx.pos_id = ash.world_register(&g_ctx.world, Position)

	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_add(&entry, Position{})
		append(&g_ctx.entities, e)
	}

	rand.shuffle(g_ctx.entities[:])

	return nil
}

bench_random_access :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	sum: f64
	for _ in 0 ..< options.rounds {
		for e in g_ctx.entities {
			entry := ash.world_entry(&g_ctx.world, e)
			pos := ash.entry_get(entry, Position)
			sum += pos.x
		}
	}

	options.hash = transmute(u128)([2]f64{sum, 0}) // Prevent optimization
	options.count = options.rounds * g_ctx.n
	return nil
}

// ============================================================================
// NEW WORLD
// ============================================================================

bench_new_world :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		world: ash.World
		ash.world_init(&world, allocator)
		ash.world_destroy(&world)
	}

	options.count = options.rounds
	return nil
}

// ============================================================================
// Runner
// ============================================================================

Benchmark_Proc :: proc(
	options: ^time.Benchmark_Options,
	allocator: runtime.Allocator,
) -> (
	err: time.Benchmark_Error
)

run_benchmark :: proc(
	name: string,
	n: int,
	rounds: int,
	setup: Benchmark_Proc,
	bench: Benchmark_Proc,
	teardown: Benchmark_Proc,
) {
	options := time.Benchmark_Options {
		rounds   = rounds,
		bytes    = n, // Pass n via bytes field
		setup    = setup,
		bench    = bench,
		teardown = teardown,
	}

	err := time.benchmark(&options, context.allocator)
	if err != nil {
		fmt.printf("    %-30s ERROR: %v\n", name, err)
		return
	}

	// Calculate ns/op from duration and count
	ns_per_op := f64(time.duration_nanoseconds(options.duration)) / f64(options.count)

	fmt.printf(
		"    %-30s %12s/op   (%.2f ops/s)\n",
		name,
		format_time(ns_per_op),
		options.rounds_per_second,
	)
}

format_time :: proc(nanos: f64) -> string {
	@(static) buf: [32]byte

	if nanos < 1_000 {
		return fmt.bprintf(buf[:], "%.2f ns", nanos)
	} else if nanos < 1_000_000 {
		return fmt.bprintf(buf[:], "%.2f us", nanos / 1_000)
	} else {
		return fmt.bprintf(buf[:], "%.2f ms", nanos / 1_000_000)
	}
}

// ============================================================================
// Main
// ===========================================================================

main :: proc() {
    // odinfmt: disable
    fmt.println()
	fmt.println("===============================================================")
    fmt.println("                    ASH ECS BENCHMARKS                         ")
    fmt.println("===============================================================")
    // odinfmt: enable

	ns := []int{100, 1_000, 10_000}
	rounds :: 100

	fmt.println("\n=== Query 2 Components ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"entry iteration",
			n,
			rounds,
			setup_query_2comp,
			bench_query_2comp_entry,
			teardown_query,
		)
		run_benchmark(
			"bulk (archetype)",
			n,
			rounds,
			setup_query_2comp,
			bench_query_2comp_bulk,
			teardown_query,
		)
	}

	fmt.println("\n=== Query 32 Archetypes ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"bulk iteration",
			n,
			rounds,
			setup_query_32arch,
			bench_query_32arch,
			teardown_query,
		)
	}

	fmt.println("\n=== Query 256 Archetypes ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"bulk iteration",
			n,
			rounds,
			setup_query_256arch,
			bench_query_256arch,
			teardown_query,
		)
	}

	fmt.println("\n=== Create Entities (2 comp) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"create 2 components",
			n,
			rounds,
			setup_create_2comp,
			bench_create_2comp,
			teardown_world,
		)
	}

	fmt.println("\n=== Create Entities (2 comp, alloc) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark("create + new world", n, rounds, nil, bench_create_2comp_alloc, nil)
	}

	fmt.println("\n=== Create Entities (10 comp) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"create 10 components",
			n,
			rounds,
			setup_create_10comp,
			bench_create_10comp,
			teardown_world,
		)
	}

	fmt.println("\n=== Delete Entities (2 comp) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"delete 2 components",
			n,
			rounds,
			setup_delete_2comp,
			bench_delete_2comp,
			teardown_world,
		)
	}

	fmt.println("\n=== Delete Entities (10 comp) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"delete 10 components",
			n,
			rounds,
			setup_delete_10comp,
			bench_delete_10comp,
			teardown_world,
		)
	}

	fmt.println("\n=== Add/Remove Components ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"add + remove",
			n,
			rounds,
			setup_add_remove,
			bench_add_remove,
			teardown_world,
		)
	}

	fmt.println("\n=== Add/Remove Large (11 comp entities) ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"add + remove large",
			n,
			rounds,
			setup_add_remove_large,
			bench_add_remove_large,
			teardown_world,
		)
	}

	fmt.println("\n=== Random Entity Access ===")
	for n in ns {
		fmt.printf("\n  N = %d\n", n)
		run_benchmark(
			"random access",
			n,
			rounds,
			setup_random_access,
			bench_random_access,
			teardown_world,
		)
	}

	fmt.println("\n=== World Creation ===")
	fmt.println()
	run_benchmark("new world", 1, 1_000, nil, bench_new_world, nil)

	fmt.println("\nBenchmarks complete!\n")
}
