package bench2

import "core:fmt"
import "core:math/rand"
import "core:time"

import "../.."

// ============================================================================
// COMPONENTS (matching ode_ecs sizes)
// ============================================================================

PAYLOAD_SIZE :: 5

Position :: struct {
    x, y: int,
    payload: [PAYLOAD_SIZE]int,
}

AI :: struct {
    neurons_count: int,
    payload: [PAYLOAD_SIZE]int,
}

Physical :: struct {
    velocity, mass: f32,
    payload: [PAYLOAD_SIZE]int,
}

Component :: struct {
    payload: [PAYLOAD_SIZE]int,
}

Component_2 :: distinct Component
Component_3 :: distinct Component
Component_4 :: distinct Component

// ============================================================================
// BENCHMARK CONFIG
// ============================================================================

ENTITY_COUNT :: 100_000
EXECUTE_TIMES :: 10

// All possible component combinations for generating random entities
// Matches ode_ecs: {{ 1, 2, 3 }, {1, 0, 0}, {2, 0, 0}, {3, 0, 0}, {1, 2, 0}, {1, 3, 0}, {2, 3, 0}}
// 1 = Position, 2 = AI, 3 = Physical
Combo :: [3]int
g_combo_choice := [7]Combo{
    {1, 2, 3},  // Position + AI + Physical
    {1, 0, 0},  // Position only
    {2, 0, 0},  // AI only
    {3, 0, 0},  // Physical only
    {1, 2, 0},  // Position + AI
    {1, 3, 0},  // Position + Physical (this combo also gets Component_1-4)
    {2, 3, 0},  // AI + Physical
}

// ============================================================================
// TIME TRACKING
// ============================================================================

Time_Track :: struct {
    query_entry:   [EXECUTE_TIMES]time.Duration,
    query_bulk:    [EXECUTE_TIMES]time.Duration,
    table_ai:      [EXECUTE_TIMES]time.Duration,
}

avg :: proc(times: [EXECUTE_TIMES]time.Duration) -> time.Duration {
    sum: time.Duration = 0
    for t in times {
        sum += t
    }
    return sum / EXECUTE_TIMES
}

// ============================================================================
// BENCHMARK CONTEXT
// ============================================================================

Bench_Context :: struct {
    world:        ash.World,
    
    // Component IDs for bulk access
    pos_id:       ash.Component_ID,
    phys_id:      ash.Component_ID,
    ai_id:        ash.Component_ID,
    
    // Cached query for the "view" equivalent
    // Entities with: Position, Component_1-4, Physical
    view_query:   ^ash.Query,
    
    // Query for AI-only iteration
    ai_query:     ^ash.Query,
    
    // Stats
    view_count:   int,
    ai_count:     int,
}

// ============================================================================
// SETUP
// ============================================================================

setup :: proc(ctx: ^Bench_Context, allocator := context.allocator) {
    ash.world_init(&ctx.world, allocator)
    
    // Register all components
    ctx.pos_id = ash.world_register(&ctx.world, Position)
    ctx.ai_id = ash.world_register(&ctx.world, AI)
    ctx.phys_id = ash.world_register(&ctx.world, Physical)
    ash.world_register(&ctx.world, Component)
    ash.world_register(&ctx.world, Component_2)
    ash.world_register(&ctx.world, Component_3)
    ash.world_register(&ctx.world, Component_4)
    
    // Create entities with random components (matching ode_ecs logic)
    for i in 0..<ENTITY_COUNT {
        combo := rand.choice(g_combo_choice[:])
        
        has_position := false
        has_physical := false
        
        // First pass: spawn entity and track what we're adding
        components := make([dynamic]any, context.temp_allocator)
        
        for j in 0..<3 {
            switch combo[j] {
            case 0:
                break
            case 1:
                append(&components, Position{x = i * j, y = i})
                has_position = true
            case 2:
                append(&components, AI{neurons_count = j})
            case 3:
                append(&components, Physical{mass = f32(j + i * j)})
                has_physical = true
            }
        }
        
        // If has Position AND Physical, also add Component_1-4 (matching ode_ecs)
        if has_position && has_physical {
            append(&components, Component{})
            append(&components, Component_2{})
            append(&components, Component_3{})
            append(&components, Component_4{})
        }
        
        // Spawn with all components at once
        if len(components) > 0 {
            e := ash.world_spawn(&ctx.world, ..components[:])
            _ = e
        } else {
            ash.world_spawn(&ctx.world)
        }
    }
    
    // Create queries
    // "View" equivalent: entities with Position, Component_1-4, Physical
    view_filter := ash.filter_contains(&ctx.world, {Position, Component, Component_2, Component_3, Component_4, Physical})
    ctx.view_query = ash.world_query(&ctx.world, view_filter)
    
    // AI table equivalent
    ai_filter := ash.filter_contains(&ctx.world, {AI})
    ctx.ai_query = ash.world_query(&ctx.world, ai_filter)
    
    // Cache counts
    ctx.view_count = ash.query_count(ctx.view_query)
    ctx.ai_count = ash.query_count(ctx.ai_query)
}

teardown :: proc(ctx: ^Bench_Context) {
    ash.world_destroy(&ctx.world)
}

// ============================================================================
// ITERATION BENCHMARKS
// ============================================================================

// Equivalent to ode_ecs iterate_over_ai_table
iterate_ai_query :: proc(ctx: ^Bench_Context) {
    it := ash.query_iter(ctx.ai_query)
    index := 0
    for entry in ash.query_next(&it) {
        ai := ash.entry_get(entry, AI)
        ai.neurons_count += index
        index += 1
    }
}

// Equivalent to ode_ecs iterate_over_view (entry-based)
iterate_view_entry :: proc(ctx: ^Bench_Context) {
    it := ash.query_iter(ctx.view_query)
    index := 0
    for entry in ash.query_next(&it) {
        pos := ash.entry_get(entry, Position)
        pos.x += index
        pos.y += index
        
        ph := ash.entry_get(entry, Physical)
        ph.velocity += f32(index)
        ph.mass += f32(index)
        
        index += 1
    }
}

// Equivalent to ode_ecs iterate_over_archetype (bulk)
iterate_view_bulk :: proc(ctx: ^Bench_Context) {
    it := ash.query_iter_archs(ctx.view_query)
    for arch in ash.query_next_arch(&it) {
        positions := ash.archetype_slice(arch, Position, ctx.pos_id)
        physics := ash.archetype_slice(arch, Physical, ctx.phys_id)
        
        for i in 0..<len(positions) {
            positions[i].x += i
            positions[i].y += i
            physics[i].velocity += f32(i)
            physics[i].mass += f32(i)
        }
    }
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
    fmt.println()
    fmt.println("===============================================================")
    fmt.println("            ASH ECS vs ODE_ECS COMPARISON BENCHMARK            ")
    fmt.println("===============================================================")
    fmt.println()
    
    ctx: Bench_Context
    setup(&ctx)
    defer teardown(&ctx)
    
    tt: Time_Track
    
    // Run benchmarks multiple times
    for j in 0..<EXECUTE_TIMES {
        sw: time.Stopwatch
        
        // AI table/query iteration
        time.stopwatch_start(&sw)
        iterate_ai_query(&ctx)
        time.stopwatch_stop(&sw)
        tt.table_ai[j] = time.stopwatch_duration(sw)
        
        // View equivalent - entry iteration
        time.stopwatch_reset(&sw)
        time.stopwatch_start(&sw)
        iterate_view_entry(&ctx)
        time.stopwatch_stop(&sw)
        tt.query_entry[j] = time.stopwatch_duration(sw)
        
        // View equivalent - bulk iteration
        time.stopwatch_reset(&sw)
        time.stopwatch_start(&sw)
        iterate_view_bulk(&ctx)
        time.stopwatch_stop(&sw)
        tt.query_bulk[j] = time.stopwatch_duration(sw)
    }
    
    // Print results
    avg_ai := avg(tt.table_ai)
    avg_entry := avg(tt.query_entry)
    avg_bulk := avg(tt.query_bulk)
    
    fmt.printfln("%-35s %d", "Entity count:", ash.world_entity_count(&ctx.world))
    fmt.printfln("%-35s %d bytes", "Position component size:", size_of(Position))
    fmt.printfln("%-35s %d bytes", "Physical component size:", size_of(Physical))
    fmt.printfln("%-35s %d bytes", "AI component size:", size_of(AI))
    fmt.printfln("%-35s %d bytes", "Component size:", size_of(Component))
    fmt.println("-----------------------------------------------------------")
    fmt.printfln("%-35s %.4f ms (%d entities)", 
        "AI query iteration:", 
        time.duration_milliseconds(avg_ai),
        ctx.ai_count)
    fmt.printfln("%-35s %.4f ms (%d entities)", 
        "View query (entry-based):", 
        time.duration_milliseconds(avg_entry),
        ctx.view_count)
    fmt.printfln("%-35s %.4f ms (%d entities)", 
        "View query (bulk/archetype):", 
        time.duration_milliseconds(avg_bulk),
        ctx.view_count)
    fmt.println("-----------------------------------------------------------")
    
    // Compare entry vs bulk
    if avg_bulk < avg_entry {
        speedup := f64(avg_entry) / f64(avg_bulk)
        fmt.printfln("Bulk iteration is %.2fx faster than entry iteration", speedup)
    } else {
        speedup := f64(avg_bulk) / f64(avg_entry)
        fmt.printfln("Entry iteration is %.2fx faster than bulk iteration", speedup)
    }
    
    fmt.println()
    fmt.println("Compare these results with ode_ecs by running both benchmarks")
    fmt.println("with: odin run . -o:speed")
    fmt.println()
}