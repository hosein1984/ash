package boids

import    "core:math"
import    "core:math/linalg"
import    "core:math/rand"
import rl "vendor:raylib"

import "../.."

// ============================================================================
// COMPONENTS
// ============================================================================

Vec2 :: [2]f32

Position     :: struct { v: Vec2 }
Velocity     :: struct { v: Vec2 }
Acceleration :: struct { v: Vec2 }


Flock :: struct { color: rl.Color } // Boids only flock with same-colored boids

// ============================================================================
// RESOURCES
// ============================================================================

Config :: struct {
	screen_width:    i32,
	screen_height:   i32,
	boid_count:      int,
	
	// Flocking parameters
	visual_range:    f32,
	protected_range: f32,
	max_speed:       f32,
	min_speed:       f32,
	
	// Behavior weights
	cohesion:        f32,
	alignment:       f32,
	separation:      f32,
	edge_turn:       f32,
}

default_config :: proc() -> Config {
	return Config{
		screen_width    = 1280,
		screen_height   = 720,
		boid_count      = 300,
		visual_range    = 75,
		protected_range = 20,
		max_speed       = 6,
		min_speed       = 3,
		cohesion        = 0.005,
		alignment       = 0.05,
		separation      = 0.05,
		edge_turn       = 0.2,
	}
}

// ============================================================================
// SYSTEMS
// ============================================================================

// Applies flocking behavior: cohesion, alignment, separation
system_flocking :: proc(world: ^ash.World, config: ^Config) {
	pos_id := ash.world_get_component_id(world, Position)
	vel_id := ash.world_get_component_id(world, Velocity)
	acc_id := ash.world_get_component_id(world, Acceleration)
	flock_id := ash.world_get_component_id(world, Flock)
	
	filter := ash.filter_contains(world, {Position, Velocity, Acceleration, Flock})
	query := ash.world_query(world, filter)
	
	// For each boid, calculate forces from neighbors
	it := ash.query_iter_archs(query)
	for arch in ash.query_next_arch(&it) {
		positions := ash.archetype_slice(arch, Position, pos_id)
		velocities := ash.archetype_slice(arch, Velocity, vel_id)
		accelerations := ash.archetype_slice(arch, Acceleration, acc_id)
		flocks := ash.archetype_slice(arch, Flock, flock_id)
		
		for i in 0 ..< len(positions) {
			my_pos := positions[i].v
			my_vel := velocities[i].v
			my_flock := flocks[i].color
			
			// Accumulators
			center_of_mass: Vec2
			avg_velocity: Vec2
			separation_force: Vec2
			neighbors := 0
			close_neighbors := 0
			
			// Check all other boids
			for j in 0 ..< len(positions) {
				if i == j { continue }
				if flocks[j].color != my_flock { continue }
				
				other_pos := positions[j].v
				diff := other_pos - my_pos
				dist := linalg.length(diff)
				
				if dist < config.visual_range {
					center_of_mass += other_pos
					avg_velocity += velocities[j].v
					neighbors += 1
					
					if dist < config.protected_range {
						separation_force -= diff / max(dist, 0.1)
						close_neighbors += 1
					}
				}
			}
			
			acc: Vec2
			
			if neighbors > 0 {
				// Cohesion: steer toward center of mass
				center_of_mass /= f32(neighbors)
				acc += (center_of_mass - my_pos) * config.cohesion
				
				// Alignment: match average velocity
				avg_velocity /= f32(neighbors)
				acc += (avg_velocity - my_vel) * config.alignment
			}
			
			if close_neighbors > 0 {
				// Separation: avoid crowding
				acc += separation_force * config.separation
			}
			
			accelerations[i].v = acc
		}
	}
}

// Keeps boids within screen bounds
system_edge_avoidance :: proc(world: ^ash.World, config: ^Config) {
	margin :: 100
	
	filter := ash.filter_contains(world, {Position, Acceleration})
	query := ash.world_query(world, filter)
	
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		acc := ash.entry_get(entry, Acceleration)
		
		if pos.v.x < margin {
			acc.v.x += config.edge_turn
		} else if pos.v.x > f32(config.screen_width) - margin {
			acc.v.x -= config.edge_turn
		}
		
		if pos.v.y < margin {
			acc.v.y += config.edge_turn
		} else if pos.v.y > f32(config.screen_height) - margin {
			acc.v.y -= config.edge_turn
		}
	}
}

// Updates velocity based on acceleration, clamps speed
system_velocity :: proc(world: ^ash.World, config: ^Config) {
	filter := ash.filter_contains(world, {Velocity, Acceleration})
	query := ash.world_query(world, filter)
	
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		vel := ash.entry_get(entry, Velocity)
		acc := ash.entry_get(entry, Acceleration)
		
		vel.v += acc.v
		
		// Clamp speed
		speed := linalg.length(vel.v)
		if speed > config.max_speed {
			vel.v = linalg.normalize(vel.v) * config.max_speed
		} else if speed < config.min_speed && speed > 0.01 {
			vel.v = linalg.normalize(vel.v) * config.min_speed
		}
		
		// Reset acceleration
		acc.v = {}
	}
}

// Updates position based on velocity
system_movement :: proc(world: ^ash.World) {
	filter := ash.filter_contains(world, {Position, Velocity})
	query := ash.world_query(world, filter)
	
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		pos.v += vel.v
	}
}

// Renders all boids
system_render :: proc(world: ^ash.World) {
	filter := ash.filter_contains(world, {Position, Velocity, Flock})
	query := ash.world_query(world, filter)
	
	it := ash.query_iter(query)
	for entry in ash.query_next(&it) {
		pos := ash.entry_get(entry, Position)
		vel := ash.entry_get(entry, Velocity)
		flock := ash.entry_get(entry, Flock)
		
		// Calculate rotation from velocity
		angle := math.atan2(vel.v.y, vel.v.x) * (180 / math.PI)
		
		// Draw triangle pointing in direction of movement
		rl.DrawPoly(
			{pos.v.x, pos.v.y},
			3,       // Triangle
			8,      // Size
			angle,
			flock.color,
		)
	}
}

// ============================================================================
// INITIALIZATION
// ============================================================================

spawn_boids :: proc(world: ^ash.World, config: ^Config) {
	colors := []rl.Color{
		rl.SKYBLUE,
		rl.PINK,
		rl.LIME,
		rl.GOLD,
	}
	
	for _ in 0 ..< config.boid_count {
		angle := rand.float32() * 2 * math.PI
		speed := config.min_speed + rand.float32() * (config.max_speed - config.min_speed)
		
		ash.world_spawn(
			world,
			Position{v = {
				rand.float32() * f32(config.screen_width),
				rand.float32() * f32(config.screen_height),
			}},
			Velocity{v = {math.cos(angle) * speed, math.sin(angle) * speed}},
			Acceleration{v = {}},
			Flock{color = colors[rand.int_max(len(colors))]},
		)
	}
}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
	// Configuration resource
	config := default_config()

	// Initialize world
	world: ash.World
	ash.world_init(&world)
	defer ash.world_destroy(&world)
	
	// Spawn boids
	spawn_boids(&world, &config)
	
	// Initialize raylib
	rl.SetConfigFlags({.VSYNC_HINT, .MSAA_4X_HINT})
	rl.SetTargetFPS(60)
	rl.InitWindow(config.screen_width, config.screen_height, "Boids Simulation")
	defer rl.CloseWindow()
	
	for !rl.WindowShouldClose() {
		// Update
		system_flocking(&world, &config)
		system_edge_avoidance(&world, &config)
		system_velocity(&world, &config)
		system_movement(&world)
		
		// Render
		rl.BeginDrawing()
		rl.ClearBackground({20, 20, 30, 255})
		
		system_render(&world)
		
		rl.DrawText(
			rl.TextFormat("Boids: %d | FPS: %d", config.boid_count, rl.GetFPS()),
			10, 10, 20, rl.WHITE,
		)
		
		rl.EndDrawing()
	}
}