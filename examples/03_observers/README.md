# Observers Example

This example demonstrates Ash's observer/event system for reacting to entity and component lifecycle events.

## What This Showcases

- **Spawn observers**: React when entities are created
- **Despawn observers**: React when entities are removed  
- **Add observers**: React when a specific component is added to an entity
- **Remove observers**: React when a specific component is removed from an entity
- **User data passing**: Passing context to observer callbacks
- **Component access in callbacks**: Reading component data during observer execution

## Key Concepts

### Registering Observers
```odin
// Entity lifecycle observers
ash.world_on_spawn(&world, callback, user_data)
ash.world_on_despawn(&world, callback, user_data)

// Component lifecycle observers  
ash.world_on_add(&world, Health, callback, user_data)
ash.world_on_remove(&world, Health, callback, user_data)
```

### Observer Callback Signature
```odin
callback :: proc(world: ^ash.World, entity: ash.Entity, user_data: rawptr)
```

### Observer Execution Order

When spawning an entity with components:
1. `on_spawn` fires
2. `on_add` fires for each component

When despawning an entity:
3. `on_remove` fires for each component
4. `on_despawn` fires (entity still alive, components accessible)

## Use Cases

- Logging and debugging
- Statistics tracking
- Cleanup when entities are removed
- Initializing related data when components are added
- Triggering side effects on component changes

## Running

```bash
cd examples/03_observers
odin run .
```