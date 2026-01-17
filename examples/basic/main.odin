package basic

import "core:crypto"
import "core:fmt"
import "core:math/rand"

import "../.."

// ============================================================================
// COMPONENTS
// ============================================================================

Name :: struct {
    value: string
}

Health :: struct {
    current: int,
    max:	 int,
}

Position :: struct {
    x, y: f32
}

// Tags
Player	  :: struct {}
Enemy	  :: struct {}
Poisoned  :: struct {}

// ============================================================================
// MAIN
// ============================================================================

main :: proc() {
    context.random_generator = crypto.random_generator()

    world: ash.World
    ash.world_init(&world)
    defer ash.world_destroy(&world)

    fmt.println("=== Creating Entities ===")

    // ----------------------------------------------------------------------------
    // SETUP
    // ----------------------------------------------------------------------------

    // Create player
    player := ash.world_spawn(
        &world,
        Name{"Hero"},
        Health{current = 100, max = 100},
        Position{0, 0},
        Player{}
    )
    fmt.printfln("Created player: Entity %d", ash.entity_id(player))

    // Create some enemies
    enemy_data := []struct{name: string, hp: int}{
		{"Goblin",   15},
		{"Orc",      45},
		{"Troll",    80},
		{"Skeleton", 25},
		{"Slime",    10},
		{"Rat",       5},
		{"Wolf",     30},
	}
	for data in enemy_data {
		ash.world_spawn(&world,
			Name{data.name},
			Health{current = data.hp, max = data.hp},
			Position{rand.float32() * 100, rand.float32() * 100},
			Enemy{},
		)
	}
    fmt.printfln("Created %d enemies", len(enemy_data))


    // ----------------------------------------------------------------------------
    // QUERY EXAMPLES
    // ----------------------------------------------------------------------------

    fmt.println("\n=== Query: All entities with Health ===")
    {
        filter := ash.filter_contains(&world, {Name, Health})
        query  := ash.world_query(&world, filter)

        it := ash.query_iter(query)
        for entry in ash.query_next(&it) {
            name   := ash.entry_get(entry, Name)
            health := ash.entry_get(entry, Health)
            fmt.printfln("  %s: %d/%d HP", name.value, health.current, health.max)			
        }
    }

    fmt.println("\n=== Query: Only enemies ===")
    {
        filter := ash.filter_contains(&world, {Name, Enemy})
        query  := ash.world_query(&world, filter)

        it := ash.query_iter(query)
        for entry in ash.query_next(&it) {
            name := ash.entry_get(entry, Name)
            fmt.printfln("  Enemy: %s", name.value)
        }
    }

    fmt.println("\n=== Query: Only player ===")
    {
        filter := ash.filter_contains(&world, {Name, Player})
        query  := ash.world_query(&world, filter)

        first, ok := ash.query_first(query)
        if ok {
            name := ash.entry_get(first, Name)
            fmt.printfln("  Found player: %s", name.value)
        }
    }

    // ----------------------------------------------------------------------------
    // COMPONENT MANIPULATION
    // ----------------------------------------------------------------------------
    
    fmt.println("\n=== Poisoning weaker enemies ===")
    {
        filter := ash.filter_contains(&world, {Name, Health, Enemy})
        query  := ash.world_query(&world, filter)

        count := 0
        it := ash.query_iter(query)
        for {
            entry, ok := ash.query_next(&it)
            if !ok {
                break
            }

            name   := ash.entry_get(entry, Name)
            health := ash.entry_get(entry, Health)

            // Poison enemies with 30 HP or less
            if health.max <= 30 {
				ash.entry_queue_set(entry, Poisoned{})
				fmt.printfln("  Poisoned: %s (%d HP)", name.value, health.current)
				count += 1
			}
        }

        ash.world_flush_queue(&world)
        fmt.printfln("  Total poisioned: %d", count)
    }

    fmt.println("\n=== Query: Enemies that are NOT poisoned ===")
    {
        filter := ash.filter_create(&world, requires = {Enemy, Name}, excludes = {Poisoned})
        query  := ash.world_query(&world, filter)
        
        it := ash.query_iter(query)
        for entry in ash.query_next(&it) {
            name := ash.entry_get(entry, Name)
            fmt.printfln("  Healthy enemy: %s", name.value)
        }
    }

    fmt.println("\n=== Applying poison damage (3 ticks) ===")
	for tick in 1..=3 {
		filter := ash.filter_contains(&world, {Poisoned, Health, Name})
		query  := ash.world_query(&world, filter)
		
		it := ash.query_iter(query)
		for entry in ash.query_next(&it) {
			name := ash.entry_get(entry, Name)
			health := ash.entry_get(entry, Health)
			
			// Apply poison damage
			health.current -= 10
			fmt.printfln("  [Tick %d] %s takes 10 poison damage -> %d/%d HP", tick, name.value, health.current, health.max)
		}
	}

    // ----------------------------------------------------------------------------
    // REMOVING DEAD ENTITIES
    // ----------------------------------------------------------------------------

    fmt.println("\n=== Removing dead entities ===")
	{
		filter := ash.filter_contains(&world, {Health, Name})
		query  := ash.world_query(&world, filter)
		
		it := ash.query_iter(query)
		for entry in ash.query_next(&it) {
            name   := ash.entry_get(entry, Name)
			health := ash.entry_get(entry, Health)

			if health.current <= 0 {
				fmt.printfln("  %s has died!", name.value)
                ash.entry_queue_despawn(entry)
			}
		}

        ash.world_flush_queue(&world)
	}
    
    // ----------------------------------------------------------------------------
    // FINAL STATE
    // ----------------------------------------------------------------------------
    
    fmt.println("\n=== Final World State ===")
	fmt.printfln("Total entities: %d", ash.world_entity_count(&world))
	
	{
		filter := ash.filter_contains(&world, {Name, Health})
		query  := ash.world_query(&world, filter)
		
		it := ash.query_iter(query)
		for entry in ash.query_next(&it) {
			name   := ash.entry_get(entry, Name)
			health := ash.entry_get(entry, Health)
			
			tags: [dynamic]string
			defer delete(tags)
			
			if ash.entry_has(entry, Player)   { append(&tags, "Player")   }
			if ash.entry_has(entry, Enemy)    { append(&tags, "Enemy")    }
			if ash.entry_has(entry, Poisoned) { append(&tags, "Poisoned") }
			
			fmt.printfln("  %s [%d/%d HP] %v", name.value, health.current, health.max, tags[:])
		}
	}

    // ----------------------------------------------------------------------------
    // WORLD STATS
    // ----------------------------------------------------------------------------
    fmt.println()
    {
        stats := ash.world_stats(&world)
        defer ash.world_stats_destroy(&stats)

        ash.world_stats_print(&stats)
    }
}