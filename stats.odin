package ash

import "core:fmt"
import "core:strings"

World_Stats :: struct {
	entity_count:    int,
	entity_capacity: int,
	free_list_count: int,
	archetype_count: int,
	component_count: int,
	total_memory:    int, // Approximate bytes used
	archetype_stats: []Archetype_Stats, // Per-archetype breakdown
}

Archetype_Stats :: struct {
	index:           Archetype_Index,
	entity_count:    int,
	component_count: int,
	components:      []typeid,
	memory_used:     int,
}

world_stats :: proc(world: ^World, allocator := context.allocator) -> World_Stats {
	stats: World_Stats

	stats.entity_count = location_map_len(&world.locations)
	stats.entity_capacity = len(&world.locations.locations)
	stats.free_list_count = len(world.free_list)
	stats.archetype_count = len(world.archetypes)
	stats.component_count = len(world.registry.infos)

	stats.archetype_stats = make([]Archetype_Stats, len(world.archetypes), allocator)

	for &arch, i in world.archetypes {
		arch_mem := 0
		for &col in arch.columns {
			arch_mem += len(col.data)
		}
		arch_mem += len(arch.entities) * size_of(Entity)

		components := make([]typeid, len(arch.layout.components), allocator)
		for comp_id, j in arch.layout.components {
			info, _ := registry_get_info(&world.registry, comp_id)
			components[j] = info.type_id
		}

		stats.archetype_stats[i] = Archetype_Stats {
			index           = arch.index,
			entity_count    = len(arch.entities),
			component_count = len(arch.layout.components),
			components      = components,
			memory_used     = arch_mem,
		}

		stats.total_memory += arch_mem
	}

	// Add overhead from maps and dynamic arrays
	stats.total_memory += len(world.locations.locations) * size_of(Entity_Location)
	stats.total_memory += len(world.free_list) * size_of(Entity)

	return stats
}

world_stats_destroy :: proc(stats: ^World_Stats, allocator := context.allocator) {
    for &arch_stat in stats.archetype_stats {
        delete(arch_stat.components, allocator)
    }
	delete(stats.archetype_stats, allocator)
}

// Pretty print stats
// odinfmt: disable
world_stats_print :: proc(stats: ^World_Stats) {
    // 1. Define the specific width of the content area (excluding the border pipes)
    // The top bar has 66 dashes, so the inner width is 66 chars.
    CONTENT_WIDTH :: 66 

    // Helper to print the horizontal separators
    sep :: proc() {
        fmt.println("+------------------------------------------------------------------+")
    }

    // Helper to format a line and ensure the right border is aligned
    // It pads the content with spaces to fill CONTENT_WIDTH
    row :: proc(format_str: string, args: ..any) {
        // Format the content first
        text := fmt.tprintf(format_str, ..args)
        // Print: | [space] [text-padded-left] [space] |
        // %-*s takes two args: length and string. It pads with spaces on the right.
        fmt.printf("| %-*s |\n", CONTENT_WIDTH - 2, text)
    }

    // --- Header ---
    sep()
    // Explicit center alignment for the title
    fmt.println("|                          WORLD STATS                             |")
    sep()

    // --- Stats Rows ---
    row("Entities:     %8d  (capacity: %d, free: %d)", 
        stats.entity_count, stats.entity_capacity, stats.free_list_count)
    row("Archetypes:   %8d", stats.archetype_count)
    row("Components:   %8d registered", stats.component_count)
    row("Memory:       %8s (approx)", format_bytes(stats.total_memory))
    
    // --- Archetypes Section ---
    sep()
    row("ARCHETYPES")
    sep()
    
    for &arch_stat in stats.archetype_stats {
        // Print the Entity count line
        row("  [%3d] %6d entities, %s", 
            arch_stat.index, 
            arch_stat.entity_count,
            format_bytes(arch_stat.memory_used))
        
        // Build the component string using a Builder
        // We need to build the whole string first so we know how much padding to add
        sb := strings.builder_make(context.temp_allocator)
        fmt.sbprint(&sb, "        Components: ")
        
        for comp_type, i in arch_stat.components {
            if i > 0 { fmt.sbprint(&sb, ", ") }
            fmt.sbprintf(&sb, "%v", comp_type)
        }
        
        // Print the component line using the row helper
        row(strings.to_string(sb))
    }
    
    sep()
}
// odinfmt: enable
