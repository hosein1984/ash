# Scheduler with Stages Example

A structured scheduler that organizes systems into execution phases for proper data dependencies.

## What This Showcases

- **Staged execution**: Systems run in defined phases
- **Data dependencies**: Camera follows player AFTER player moves
- **Struct embedding**: Systems carry their own state and behavior
- **One-time initialization**: Startup stage runs once

## Why Stages Matter

In ECS, systems are decoupled - one writes data that another reads. Wrong order = bugs:

```
❌ Without stages (wrong order):
   Camera reads position → Player moves
   Result: Camera shows LAST frame's position (visual jitter)

✅ With stages (correct order):
   Player moves → Camera reads position  
   Result: Camera shows CURRENT position
```

By organizing systems into stages, we ensure correct sequencing without always having to manually order every system.

## Stage Definitions

```odin
Stage :: enum {
    Startup,     // Runs once at initialization
    Input,       // Process keyboard/mouse
    Update,      // Main game logic (AI, cooldowns)
    Physics,     // Movement integration
    Post_Update, // Camera, cleanup, reactions
    Render,      // Drawing
}
```

## Execution Order

```
    Frame 1:          Frame 2:          Frame N:
┌─────────────┐   ┌─────────────┐   ┌─────────────┐
│   Startup   │   │   (skip)    │   │   (skip)    │
├─────────────┤   ├─────────────┤   ├─────────────┤
│    Input    │   │    Input    │   │    Input    │
├─────────────┤   ├─────────────┤   ├─────────────┤
│   Update    │   │   Update    │   │   Update    │
├─────────────┤   ├─────────────┤   ├─────────────┤
│   Physics   │   │   Physics   │   │   Physics   │
├─────────────┤   ├─────────────┤   ├─────────────┤
│ Post_Update │   │ Post_Update │   │ Post_Update │
├─────────────┤   ├─────────────┤   ├─────────────┤
│   Render    │   │   Render    │   │   Render    │
└─────────────┘   └─────────────┘   └─────────────┘
```

## The Camera Problem (Demonstrated)

This example shows proper camera following:

```odin
// Physics stage - player moves first
scheduler_add(&sched, .Physics, &movement.system)

// Post_Update stage - camera follows AFTER movement
scheduler_add(&sched, .Post_Update, &camera.system)
```

Output shows camera smoothly following player's NEW position:
```
[Tick   10] Player: (52.41, 51.83) | Camera: (52.05, 51.47) | Delta: (0.36, 0.36)
[Tick   20] Player: (55.12, 53.91) | Camera: (54.66, 53.33) | Delta: (0.46, 0.58)
```

## System Registration

```odin
// Stage determines WHEN, not just IF
scheduler_add(&sched, .Startup,     &spawner.system)   // Once
scheduler_add(&sched, .Input,       &input.system)     // Every frame
scheduler_add(&sched, .Physics,     &movement.system)  // After input
scheduler_add(&sched, .Physics,     &bounds.system)    // With movement
scheduler_add(&sched, .Post_Update, &camera.system)    // After physics!
scheduler_add(&sched, .Render,      &renderer.system)  // Last
```

## When to Use Stages

| Scenario | Stage |
|----------|-------|
| Spawn entities, load resources | `Startup` |
| Read keyboard/mouse | `Input` |
| AI decisions, cooldowns, game rules | `Update` |
| Apply velocities, resolve collisions | `Physics` |
| Camera follow, death cleanup, UI sync | `Post_Update` |
| Draw calls, debug overlay | `Render` |

## Future Extensions

**Fixed timestep physics:**
```odin
Stage :: enum {
    // ...
    Fixed_Update,  // Runs at fixed 60Hz for deterministic physics
    // ...
}
```

**Multithreading:**

Stages act as natural synchronization barriers - systems within a stage can potentially run in parallel if they don't conflict.

## Running

```bash
cd examples/04_scheduler
odin run .
```

## See Also

- `examples/03_systems` - Simpler approach without scheduler abstraction