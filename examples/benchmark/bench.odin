package benchmark

import ash "../.."
import "base:intrinsics"
import "base:runtime"
import "core:fmt"
import "core:math/rand"
import "core:sys/info"
import "core:time"

// ============================================================================
// Components
// ============================================================================

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
	query:    ^ash.Query,
	pos_id:   ash.Component_ID,
	vel_id:   ash.Component_ID,
	n:        int,
}

// ============================================================================
// Benchmark Result Collection
// ============================================================================

Benchmark_Result :: struct {
	name:      string,
	n:         int,
	ns_per_op: f64,
	ops_per_s: f64,
}

Benchmark_Group :: struct {
	name:    string,
	results: [dynamic]Benchmark_Result,
}

g_groups: [dynamic]Benchmark_Group
g_current_group: ^Benchmark_Group

begin_group :: proc(name: string) {
	append(&g_groups, Benchmark_Group{name = name, results = make([dynamic]Benchmark_Result)})
	g_current_group = &g_groups[len(g_groups) - 1]
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

	g_ctx.n = options.bytes
	g_ctx.pos_id = ash.world_register(&g_ctx.world, Position)
	g_ctx.vel_id = ash.world_register(&g_ctx.world, Velocity)

	for _ in 0 ..< (g_ctx.n * 10) {
		ash.world_spawn(&g_ctx.world, Position{})
	}

	for _ in 0 ..< g_ctx.n {
		ash.world_spawn(&g_ctx.world, Position{}, Velocity{1, 1})
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.world_query(&g_ctx.world, filter)

	return nil
}

bench_query_2comp_entry :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter(g_ctx.query)
		for entry in ash.query_next(&it) {
			pos := ash.entry_get(entry, Position)
			vel := ash.entry_get(entry, Velocity)
			pos.x += vel.x
			pos.y += vel.y
		}
	}

	options.count = options.rounds * g_ctx.n
	return nil
}

bench_query_2comp_bulk :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(g_ctx.query)
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

		ash.entry_set(&entry, Position{})
		ash.entry_set(&entry, Velocity{1, 1})

		if i & 1 != 0 {ash.entry_set(&entry, C1{})}
		if i & 2 != 0 {ash.entry_set(&entry, C2{})}
		if i & 4 != 0 {ash.entry_set(&entry, C3{})}
		if i & 8 != 0 {ash.entry_set(&entry, C4{})}
		if i & 16 != 0 {ash.entry_set(&entry, C5{})}
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.world_query(&g_ctx.world, filter)

	return nil
}

bench_query_32arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(g_ctx.query)
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

	for _ in 0 ..< g_ctx.n {
		ash.world_spawn(&g_ctx.world, Position{}, Velocity{1, 1})
	}

	for i in 0 ..< (g_ctx.n * 4) {
		e := ash.world_spawn(&g_ctx.world)
		entry := ash.world_entry(&g_ctx.world, e)

		ash.entry_set(&entry, Position{})

		if i & 1 != 0 {ash.entry_set(&entry, C1{})}
		if i & 2 != 0 {ash.entry_set(&entry, C2{})}
		if i & 4 != 0 {ash.entry_set(&entry, C3{})}
		if i & 8 != 0 {ash.entry_set(&entry, C4{})}
		if i & 16 != 0 {ash.entry_set(&entry, C5{})}
		if i & 32 != 0 {ash.entry_set(&entry, C6{})}
		if i & 64 != 0 {ash.entry_set(&entry, C7{})}
		if i & 128 != 0 {ash.entry_set(&entry, C8{})}
	}

	filter := ash.filter_contains(&g_ctx.world, {Position, Velocity})
	g_ctx.query = ash.world_query(&g_ctx.world, filter)

	return nil
}

bench_query_256arch :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
	for _ in 0 ..< options.rounds {
		it := ash.query_iter_archs(g_ctx.query)
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

	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world, Position{}, Velocity{})
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
			e := ash.world_spawn(&g_ctx.world, Position{}, Velocity{})
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

	for _ in 0 ..< g_ctx.n {
		e := ash.world_spawn(&g_ctx.world, C1{}, C2{}, C3{}, C4{}, C5{}, C6{}, C7{}, C8{}, C9{}, C10{})
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
			e := ash.world_spawn(&g_ctx.world, C1{}, C2{}, C3{}, C4{}, C5{}, C6{}, C7{}, C8{}, C9{}, C10{})
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

	total_entities := g_ctx.n * options.rounds
	for _ in 0 ..< total_entities {
		e := ash.world_spawn(&g_ctx.world, Position{}, Velocity{})
		append(&g_ctx.entities, e)
	}

	return nil
}

bench_delete_2comp :: proc(
	options: ^time.Benchmark_Options,
	allocator := context.allocator,
) -> time.Benchmark_Error {
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
		for _ in 0 ..< g_ctx.n {
			e := ash.world_spawn(&g_ctx.world, C1{}, C2{}, C3{}, C4{}, C5{}, C6{}, C7{}, C8{}, C9{}, C10{})
			append(&g_ctx.entities, e)
		}

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
		e := ash.world_spawn(&g_ctx.world, Position{})
		append(&g_ctx.entities, e)
	}

	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_set(&entry, Velocity{})
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
			ash.entry_set(&entry, Velocity{})
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
		e := ash.world_spawn(
			&g_ctx.world,
			Position{},
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

	for e in g_ctx.entities {
		entry := ash.world_entry(&g_ctx.world, e)
		ash.entry_set(&entry, Velocity{})
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
			ash.entry_set(&entry, Velocity{})
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
		e := ash.world_spawn(&g_ctx.world, Position{})
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

	options.hash = transmute(u128)([2]f64{sum, 0})
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
// Benchmark Runner
// ============================================================================

Benchmark_Proc :: proc(
	options: ^time.Benchmark_Options,
	allocator: runtime.Allocator,
) -> (
	err: time.Benchmark_Error,
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
		bytes    = n,
		setup    = setup,
		bench    = bench,
		teardown = teardown,
	}

	err := time.benchmark(&options, context.allocator)
	if err != nil {
		fmt.eprintf("ERROR: %s - %v\n", name, err)
		return
	}

	ns_per_op := f64(time.duration_nanoseconds(options.duration)) / f64(options.count)
	ops_per_s := f64(options.count) / time.duration_seconds(options.duration)

	if g_current_group != nil {
		append(
			&g_current_group.results,
			Benchmark_Result{name = name, n = n, ns_per_op = ns_per_op, ops_per_s = ops_per_s},
		)
	}
}

format_time :: proc(nanos: f64) -> string {
	@(static)
	buf: [32]byte

	if nanos < 1_000 {
		return fmt.bprintf(buf[:], "%.2f ns", nanos)
	} else if nanos < 1_000_000 {
		return fmt.bprintf(buf[:], "%.2f µs", nanos / 1_000)
	} else {
		return fmt.bprintf(buf[:], "%.2f ms", nanos / 1_000_000)
	}
}

format_ops :: proc(ops: f64) -> string {
	@(static)
	buf: [32]byte

	if ops < 1_000 {
		return fmt.bprintf(buf[:], "%.0f", ops)
	} else if ops < 1_000_000 {
		return fmt.bprintf(buf[:], "%.2fK", ops / 1_000)
	} else {
		return fmt.bprintf(buf[:], "%.2fM", ops / 1_000_000)
	}
}

// ============================================================================
// Markdown Output
// ============================================================================

print_system_info :: proc() {
	fmt.println("## System Information\n")
	fmt.println("| Property | Value |")
	fmt.println("|----------|-------|")

	cpu_name := info.cpu.name.?
	if len(cpu_name) > 0 {
		fmt.printfln("| CPU | %s |", cpu_name)
	} else {
		fmt.println("| CPU | Unknown |")
	}

	ram := info.ram
	if ram.total_ram > 0 {
		ram_gb := f64(ram.total_ram) / (1024 * 1024 * 1024)
		fmt.printfln("| RAM | %.1f GB |", ram_gb)
	}

	fmt.printfln("| OS | %v |", ODIN_OS)
	fmt.printfln("| Arch | %v |", ODIN_ARCH)
	fmt.printfln("| Odin | %s |", ODIN_VERSION)
	fmt.printfln("| Optimization | %v |", ODIN_OPTIMIZATION_MODE)
	fmt.println()
}

print_markdown_results :: proc() {
	for &group in g_groups {
		fmt.printfln("### %s\n", group.name)
		fmt.println("| Benchmark | N | Time/Op | Ops/Sec |")
		fmt.println("|-----------|--:|--------:|--------:|")

		for &r in group.results {
			fmt.printfln(
				"| %s | %d | %s | %s |",
				r.name,
				r.n,
				format_time(r.ns_per_op),
				format_ops(r.ops_per_s),
			)
		}
		fmt.println()
	}
}

cleanup_results :: proc() {
	for &group in g_groups {
		delete(group.results)
	}
	delete(g_groups)
}

// ============================================================================
// Main
// ============================================================================

main :: proc() {
	g_groups = make([dynamic]Benchmark_Group)
	defer cleanup_results()

	fmt.println("# Ash ECS Benchmarks\n")
	print_system_info()
	fmt.println("## Results\n")

	ns := []int{100, 1_000, 10_000}
	rounds :: 100

	// Query benchmarks
	begin_group("Query - 2 Components (1 archetype)")
	for n in ns {
		run_benchmark("entry iteration", n, rounds, setup_query_2comp, bench_query_2comp_entry, teardown_query)
		run_benchmark("bulk iteration", n, rounds, setup_query_2comp, bench_query_2comp_bulk, teardown_query)
	}

	begin_group("Query - 32 Archetypes")
	for n in ns {
		run_benchmark("bulk iteration", n, rounds, setup_query_32arch, bench_query_32arch, teardown_query)
	}

	begin_group("Query - 256 Archetypes")
	for n in ns {
		run_benchmark("bulk iteration", n, rounds, setup_query_256arch, bench_query_256arch, teardown_query)
	}

	// Entity creation benchmarks
	begin_group("Entity Creation")
	for n in ns {
		run_benchmark("spawn (2 components)", n, rounds, setup_create_2comp, bench_create_2comp, teardown_world)
		run_benchmark("spawn (10 components)", n, rounds, setup_create_10comp, bench_create_10comp, teardown_world)
	}

	// Entity deletion benchmarks
	begin_group("Entity Deletion")
	for n in ns {
		run_benchmark("despawn (2 components)", n, rounds, setup_delete_2comp, bench_delete_2comp, teardown_world)
		run_benchmark("despawn (10 components)", n, rounds, setup_delete_10comp, bench_delete_10comp, teardown_world)
	}

	// Component add/remove benchmarks
	begin_group("Component Add/Remove")
	for n in ns {
		run_benchmark("add+remove (2 comp entity)", n, rounds, setup_add_remove, bench_add_remove, teardown_world)
		run_benchmark("add+remove (11 comp entity)", n, rounds, setup_add_remove_large, bench_add_remove_large, teardown_world)
	}

	// Random access benchmarks
	begin_group("Random Entity Access")
	for n in ns {
		run_benchmark("get component", n, rounds, setup_random_access, bench_random_access, teardown_world)
	}

	// World creation
	begin_group("World Lifecycle")
	run_benchmark("init + destroy", 1, 1_000, nil, bench_new_world, nil)

	// Output results
	print_markdown_results()

	fmt.println("---")
	fmt.println("*Run with `odin run . -o:speed` for accurate results.*")
}