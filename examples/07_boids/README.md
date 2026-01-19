# Boids Flocking Simulation

A visual demonstration of Ash ECS using Raylib to render a classic boids flocking simulation.

## What This Showcases

- **Bulk iteration**: Efficient archetype-level processing for flocking calculations
- **Component design**: Position, Velocity, Acceleration as separate components

## The Simulation

[Boids](https://en.wikipedia.org/wiki/Boids) is a classic artificial life simulation that produces flocking behavior from three simple rules:

1. **Cohesion**: Steer toward the center of mass of nearby boids
2. **Alignment**: Match velocity with nearby boids
3. **Separation**: Avoid crowding nearby boids

In this example, boids only flock with same-colored boids, creating multiple distinct flocks.

## Systems

| System | Purpose |
|--------|---------|
| `system_flocking` | Calculates cohesion, alignment, separation forces |
| `system_edge_avoidance` | Steers boids away from screen edges |
| `system_velocity` | Updates velocity from acceleration, clamps speed |
| `system_movement` | Updates position from velocity |
| `system_render` | Draws triangles pointing in movement direction |

## Key Patterns

### Bulk Iteration for Performance
The flocking system uses archetype-level iteration for O(n²) neighbor checks:
```odin
it := ash.query_iter_archs(query)
for arch in ash.query_next_arch(&it) {
    positions := ash.archetype_slice(arch, Position, pos_id)
    // Direct array access for tight loops
}
```

### Separation of Concerns
Each system has a single responsibility:
- Physics doesn't know about rendering
- Rendering doesn't modify positions
- Configuration is external to all systems

## Configuration

Tweak behavior by modifying the `Config` resource:
```odin
config := Config{
    boid_count      = 500,    // More boids!
    visual_range    = 100,    // Larger flocking radius
    cohesion        = 0.01,   // Stronger grouping
    // ...
}
```

## Running

```bash
cd examples/07_boids
odin run .

# For better performance with many boids:
odin run . -o:speed
```