# Bulk Iteration Example

This example demonstrates high-performance archetype-level iteration for processing large numbers of entities.

## What This Showcases

- **Entry-style iteration**: Convenient entity-by-entity access
- **Bulk-style iteration**: High-performance archetype-level processing
- **Component slices**: Direct array access to component data
- **Performance comparison**: Benchmarking both approaches

## Key Concepts

### Entry-Style Iteration
More ergonomic, works with any component combination:

```odin
it := ash.query_iter(query)
for entry in ash.query_next(&it) {
    pos := ash.entry_get(entry, Position)
    vel := ash.entry_get(entry, Velocity)
    pos.x += vel.vx
}
```

### Bulk-Style Iteration
Faster for large datasets, requires component IDs:

```odin
it := ash.query_iter_archs(query)
for arch in ash.query_next_arch(&it) {
    positions := ash.archetype_slice(arch, Position, pos_id)
    velocities := ash.archetype_slice(arch, Velocity, vel_id)
    
    for i in 0 ..< len(positions) {
        positions[i].x += velocities[i].vx
    }
}
```

### Getting Component IDs

Component IDs are required for bulk iteration:
```odin
// Cache during registration
pos_id := ash.world_register(&world, Position)
vel_id := ash.world_register(&world, Velocity)

// or retrieve later
pos_id := ash.world_get_component_id(&world, Position)
vel_id := ash.world_get_component_id(&world, Velocity)
```

## When to Use Each

| Pattern | Use When |
|---------|----------|
| Entry-style | Default choice, code clarity matters |
| Bulk-style | Hot paths, >10k entities, performance critical |

## Performance Characteristics

**Entry-style:**
- More pointer indirection per entity
- Virtual call-like overhead
- Better for complex per-entity logic
- Easier to debug

**Bulk-style:**
- Contiguous memory access
- Better cache utilization
- Lower per-entity overhead
- Ideal for simple SIMD-friendly operations

## Running

```bash
# Debug build (for testing)
cd examples/02_bulk
odin run .

# Optimized build (for accurate benchmarks)
odin run . -o:speed
```