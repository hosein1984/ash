package scheduler

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

// Player marker - camera will follow this entity
Player :: struct {}

// Camera state
Camera :: struct {
	x, y:   f32,
	target: ash.Entity,
}

// ============================================================================
// SYSTEM INTERFACE
// ============================================================================

System :: struct {
	name:    string,
	enabled: bool,
	init:    proc(s: ^System, world: ^ash.World),
	update:  proc(s: ^System, world: ^ash.World),
	cleanup: proc(s: ^System, world: ^ash.World),
}

// ============================================================================
// STAGES - Define execution order
// ============================================================================

Stage :: enum {
	Startup,     // Runs once at initialization
	Input,       // Process input (placeholder for this example)
	Update,      // Main game logic
	Physics,     // Physics integration
	Post_Update, // Camera, cleanup, reactions to new state
	Render,      // Drawing (placeholder for this example)
}

// ============================================================================
// SCHEDULER
// ============================================================================

Scheduler :: struct {
	world:       ^ash.World,
	stages:      [Stage][dynamic]^System,
	initialized: bool,
}

scheduler_init :: proc(s: ^Scheduler, world: ^ash.World) {
	s.world = world
	for &stage in s.stages {
		stage = make([dynamic]^System)
	}
}

scheduler_destroy :: proc(s: ^Scheduler) {
	// Run cleanup on all systems
	for stage in Stage {
		for sys in s.stages[stage] {
			if sys.cleanup != nil && sys.enabled {
				sys->cleanup(s.world)
			}
		}
		delete(s.stages[stage])
	}
}

scheduler_add :: proc(s: ^Scheduler, stage: Stage, sys: ^System) {
	append(&s.stages[stage], sys)
}

// Run startup systems once
scheduler_startup :: proc(s: ^Scheduler) {
    if s.initialized do return

	// Run init on ALL systems first
	for stage in Stage {
		for sys in s.stages[stage] {
			if sys.init != nil && sys.enabled {
				sys->init(s.world)
			}
		}
	}

	// Then run Startup stage update
	for sys in s.stages[.Startup] {
		if sys.update != nil && sys.enabled {
			sys->update(s.world)
		}
	}
	
	s.initialized = true
}

// Run one frame of all stages (except Startup)
scheduler_update :: proc(s: ^Scheduler) {
	if !s.initialized {
		scheduler_startup(s)
	}
	
	// Run stages in order, skipping Startup
	for stage in Stage {
		if stage == .Startup do continue
		
		for sys in s.stages[stage] {
			if sys.update != nil && sys.enabled {
				sys->update(s.world)
			}
		}
	}
}

// Convenience: run for N frames
scheduler_run :: proc(s: ^Scheduler, frames: int) {
	scheduler_startup(s)
	
	for _ in 0 ..< frames {
		scheduler_update(s)
	}
}

// ============================================================================
// SPAWNER SYSTEM (Startup stage)
// ============================================================================

Spawner :: struct {
	using system: System,
	entity_count: int,
}

spawner_create :: proc(count: int) -> Spawner {
	return Spawner{
		name         = "Spawner",
		enabled      = true,
		update       = spawner_update,
		entity_count = count,
	}
}

spawner_update :: proc(s: ^System, world: ^ash.World) {
	sys := cast(^Spawner)s

	// Spawn regular entities
	for _ in 0 ..< sys.entity_count {
		ash.world_spawn(
			world,
			Position{x = rand.float32() * 100, y = rand.float32() * 100},
			Velocity{vx = rand.float32() - 0.5, vy = rand.float32() - 0.5},
		)
	}

	// Spawn player
	player := ash.world_spawn(
		world,
		Position{x = 50, y = 50},
		Velocity{vx = 0.3, vy = 0.2},
		Player{},
	)

	fmt.printfln("[%s] Spawned %d entities + 1 player", sys.name, sys.entity_count)

	// Store player reference in a resource for camera

	cam := ash.world_get_resource(world, Camera)
    cam.x = 50
    cam.y = 50
    cam.target = player
}

// ============================================================================
// INPUT SYSTEM (Input stage)
// ============================================================================

Input_Handler :: struct {
	using system: System,
}

input_create :: proc() -> Input_Handler {
	return Input_Handler{
		name    = "Input",
		enabled = true,
		update  = input_update,
	}
}

input_update :: proc(s: ^System, world: ^ash.World) {
	// In a real game, you'd read keyboard/mouse here
	// and set velocities or flags on entities
	
	// We simply adjust player velocity randomly
	filter := ash.filter_contains(world, {Player, Velocity})
	query := ash.world_query(world, filter)
	
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		vel := ash.entry_get(entry, Velocity)
		vel.vx += (rand.float32() - 0.5) * 0.1
		vel.vy += (rand.float32() - 0.5) * 0.1
	}
}

// ============================================================================
// MOVEMENT SYSTEM (Physics stage)
// ============================================================================

Movement :: struct {
	using system: System,
	query: ^ash.Query,
}

movement_create :: proc() -> Movement {
	return Movement{
		name    = "Movement",
		enabled = true,
		init    = movement_init,
		update  = movement_update,
	}
}

movement_init :: proc(s: ^System, world: ^ash.World) {
	sys       := cast(^Movement)s
	filter    := ash.filter_contains(world, {Position, Velocity})
	sys.query  = ash.world_query(world, filter)
}

movement_update :: proc(s: ^System, world: ^ash.World) {
	sys := cast(^Movement)s

	it := ash.query_iter(sys.query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		pos.x += vel.vx
		pos.y += vel.vy
	}
}

// ============================================================================
// BOUNDS SYSTEM (Physics stage)
// ============================================================================

Bounds :: struct {
	using system: System,
	width:  f32,
	height: f32,
	query:  ^ash.Query,
}

bounds_create :: proc(width, height: f32) -> Bounds {
	return Bounds{
		name    = "Bounds",
		enabled = true,
		init    = bounds_init,
		update  = bounds_update,
		width   = width,
		height  = height,
	}
}

bounds_init :: proc(s: ^System, world: ^ash.World) {
	sys       := cast(^Bounds)s
	filter    := ash.filter_contains(world, {Position})
	sys.query  = ash.world_query(world, filter)
}

bounds_update :: proc(s: ^System, world: ^ash.World) {
	sys := cast(^Bounds)s

	it := ash.query_iter(sys.query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		
		if pos.x < 0           { pos.x += sys.width  }
		if pos.x >= sys.width  { pos.x -= sys.width  }
		if pos.y < 0           { pos.y += sys.height }
		if pos.y >= sys.height { pos.y -= sys.height }
	}
}

// ============================================================================
// CAMERA SYSTEM (Post_Update stage)
// This MUST run after Movement, demonstrating why stages matter
// ============================================================================

Camera_Follow :: struct {
	using system: System,
	smoothing: f32,
}

camera_create :: proc(smoothing: f32 = 0.1) -> Camera_Follow {
	return Camera_Follow{
		name      = "Camera",
		enabled   = true,
		update    = camera_update,
		smoothing = smoothing,
	}
}

camera_update :: proc(s: ^System, world: ^ash.World) {
	sys := cast(^Camera_Follow)s

	cam := ash.world_get_resource(world, Camera)
	if cam == nil { return }

	// Get player position (already updated by Movement system)
	entry, ok := ash.world_entry(world, cam.target)
	if !ok { return }

	pos := ash.entry_get(entry, Position)
	if pos == nil { return }

	// Smooth follow - interpolate toward player
	cam.x += (pos.x - cam.x) * sys.smoothing
	cam.y += (pos.y - cam.y) * sys.smoothing
}

// ============================================================================
// RENDER SYSTEM (Render stage) - Prints state
// ============================================================================

Renderer :: struct {
	using system: System,
	tick:     int,
	interval: int,
}

renderer_create :: proc(interval: int) -> Renderer {
	return Renderer{
		name     = "Renderer",
		enabled  = true,
		update   = renderer_update,
		interval = interval,
	}
}

renderer_update :: proc(s: ^System, world: ^ash.World) {
	sys := cast(^Renderer)s
	sys.tick += 1

	if sys.tick % sys.interval != 0 { return }

	// Get camera and player positions
	cam := ash.world_get_resource(world, Camera)
	if cam == nil { return }

	entry, ok := ash.world_entry(world, cam.target)
	if !ok { return }

	pos := ash.entry_get(entry, Position)

	// Show that camera follows player (with lag due to smoothing)
	fmt.printfln("[Tick %4d] Player: (%.2f, %.2f) | Camera: (%.2f, %.2f) | Delta: (%.2f, %.2f)",
		sys.tick, pos.x, pos.y, cam.x, cam.y, 
		pos.x - cam.x, pos.y - cam.y)
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)

	sched: Scheduler
	scheduler_init(&sched, &world)
	defer scheduler_destroy(&sched)

    ash.world_register(&world, Position)
    ash.world_register(&world, Velocity)
    ash.world_register(&world, Player)

    cam := Camera{}
	ash.world_set_resource(&world, &cam)

	// Create systems
	spawner  := spawner_create(50)
	input    := input_create()
	movement := movement_create()
	bounds   := bounds_create(100, 100)
	camera   := camera_create(0.15)
	renderer := renderer_create(10)

	// Add systems to appropriate stages
	// The stage determines WHEN the system runs
	scheduler_add(&sched, .Startup,     &spawner)
	scheduler_add(&sched, .Input,       &input)
	scheduler_add(&sched, .Physics,     &movement)
	scheduler_add(&sched, .Physics,     &bounds)
	scheduler_add(&sched, .Post_Update, &camera)   // Camera AFTER movement!
	scheduler_add(&sched, .Render,      &renderer)

	// Show stage organization
	fmt.println("=== Stage Organization ===")
	fmt.println("  Startup:     Spawner")
	fmt.println("  Input:       Input")
	fmt.println("  Physics:     Movement -> Bounds")
	fmt.println("  Post_Update: Camera (follows player AFTER movement)")
	fmt.println("  Render:      Renderer")
	fmt.println()

	// Run simulation
	fmt.println("=== Running Simulation ===\n")
	scheduler_run(&sched, 100)
	fmt.println("\n=== Simulation Complete ===")
}