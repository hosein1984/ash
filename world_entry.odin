package ash

import "base:runtime"

// Entry provides easy access to an entity's component through world
World_Entry :: struct {
    world:  ^World,
    entity: Entity,
    loc:    Entity_Location,
}

// Create entry for entity.
@(require_results)
world_entry :: proc(world: ^World, entity: Entity) -> (entry: World_Entry, ok: bool) #optional_ok {
	if entity == ENTITY_NULL {
		return
	}

	loc, loc_ok := world_get_entity_location(world, entity)
	if !loc_ok {
		return
	}

	ok = loc.version == entity_version(entity)
    entry = World_Entry{
        entity = entity,
        world  = world,
        loc    = loc,
    }
	return
}

// Get entity's component. Returns nil if entity doesn't have the component.
@(require_results)
entry_get :: #force_inline proc (entry: World_Entry, $T: typeid) -> ^T {
    comp_id, ok := world_get_component_id(entry.world, T)
    if !ok {
        return nil
    }
    if entry.loc.archetype == ARCHETYPE_NULL {
        return nil
    }
    arch := &entry.world.archetypes[entry.loc.archetype]
    return archetype_get(arch, entry.loc.row, T, comp_id)
}

// Check if entity has a component
entry_has :: #force_inline proc(entry: World_Entry, $T: typeid) -> bool {
    if entry.loc.archetype == ARCHETYPE_NULL {
        return false
    }
    comp_id, ok := world_get_component_id(entry.world, T)
    if !ok {
        return false
    }
    arch := &entry.world.archetypes[entry.loc.archetype]
    return archetype_has(arch, comp_id)
}

// Get the entity's current archetype (nil if not entity has not components)
entry_archetype :: #force_inline proc(entry: World_Entry) -> ^Archetype {
    if entry.loc.archetype == ARCHETYPE_NULL {
        return nil
    }
    return &entry.world.archetypes[entry.loc.archetype]
}

// Add a comppnent to the entity. Moves the entity to appropriate archetype.
// If entity already have this component, just updates the value.
entry_add :: proc(entry: ^World_Entry, value: $T) {
    world := entry.world
    entity := entry.entity
    v := value

    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = world.allocator == context.temp_allocator)

    comp_id := world_register(world, T)
    curr_arch_idx := entry.loc.archetype
    curr_arch: ^Archetype = nil
    if curr_arch_idx != ARCHETYPE_NULL {
        curr_arch = &world.archetypes[curr_arch_idx]
    }

    if curr_arch == nil {
        // Entity has no components yet
        new_arch := world_get_or_create_archetype(world, []Component_ID{comp_id})
        new_row := archetype_push_entity(new_arch, entity)
        archetype_set(new_arch, new_row, comp_id, &v)

        // Update location map
        location_map_insert(
            &world.locations,
            entity_id(entity),
            new_arch.index,
            new_row,
            entity_version(entity),
        )

        // Update cached location in entry
        entry.loc = Entity_Location{
            archetype = new_arch.index,
            row       = new_row,
            version   = entity_version(entity),
            valid     = true,
        }

    } else if archetype_has(curr_arch, comp_id) {
        // Already has component - just update value (no move)
        archetype_set(curr_arch, entry.loc.row, comp_id, &v)
        // loc unchanged

    } else {
        // Move to new archetype
        new_arch: ^Archetype

        if cached_idx, ok := curr_arch.add_edges[comp_id]; ok {
            new_arch = &world.archetypes[cached_idx]
        } else {
            new_layout := layout_with(&curr_arch.layout, comp_id, context.temp_allocator)
            new_arch = world_get_or_create_archetype(world, new_layout.components)
            world.archetypes[curr_arch_idx].add_edges[comp_id] = new_arch.index
        }

        new_row := world_transfer_entity(world, entity, curr_arch_idx, new_arch.index, entry.loc.row)
        archetype_set(new_arch, new_row, comp_id, &v)

        // Update cached location in entry
        entry.loc = Entity_Location{
            archetype = new_arch.index,
            row       = new_row,
            version   = entity_version(entity),
            valid     = true,
        }
    }
}

// Remove a component from the entity. Moves entity to appropriate archetype.
// No-op if entity doesn't have the component
entry_remove :: proc(entry: ^World_Entry, $T: typeid) {
    world := entry.world
    entity := entry.entity

    runtime.DEFAULT_TEMP_ALLOCATOR_TEMP_GUARD(ignore = world.allocator == context.temp_allocator)

    comp_id, ok := world_get_component_id(world, T)
    if !ok {
        return
    }

    curr_arch_idx := entry.loc.archetype
    if curr_arch_idx == ARCHETYPE_NULL {
        return
    }
    
    curr_arch := &world.archetypes[curr_arch_idx]

    if !archetype_has(curr_arch, comp_id) {
        return
    }

    if archetype_component_count(curr_arch) == 1 {
        // Last component - entity becomes component-less
        moved_entity := archetype_swap_remove(curr_arch, entry.loc.row)

        if moved_entity != ENTITY_NULL {
            location_map_set_row(&world.locations, entity_id(moved_entity), entry.loc.row)
        }

        location_map_insert(
            &world.locations,
            entity_id(entity),
            ARCHETYPE_NULL,
            0,
            entity_version(entity),
        )

        // Update cached location
        entry.loc = Entity_Location{
            archetype = ARCHETYPE_NULL,
            row       = 0,
            version   = entity_version(entity),
            valid     = true,
        }
    } else {
        // Move to archetype without this component
        new_arch: ^Archetype

        if cached_idx, ok := curr_arch.remove_edges[comp_id]; ok {
            new_arch = &world.archetypes[cached_idx]
        } else {
            new_layout := layout_without(&curr_arch.layout, comp_id, context.temp_allocator)
            new_arch = world_get_or_create_archetype(world, new_layout.components)
            world.archetypes[curr_arch_idx].remove_edges[comp_id] = new_arch.index
        }

        new_row := world_transfer_entity(world, entity, curr_arch_idx, new_arch.index, entry.loc.row)

        // Update cached location
        entry.loc = Entity_Location{
            archetype = new_arch.index,
            row       = new_row,
            version   = entity_version(entity),
            valid     = true,
        }
    }
}