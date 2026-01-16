package ash

// Entry provides easy access to an entity's component through world
World_Entry :: struct {
	world:  ^World,
	entity: Entity,
	loc:    Entity_Location, 	// Cached
	arch:	^Archetype,			// Cached
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

	ok = loc.generation == entity_generation(entity)
	entry = World_Entry {
		entity = entity,
		world  = world,
		loc    = loc,
	}
	return
}

// Returns entry or panics if entity is invalid
@(require_results)
world_entry_must :: proc(world: ^World, entity: Entity) -> World_Entry {
    entry, ok := world_entry(world, entity)
    assert(ok, "Entity is not alive")
    return entry
}

// Get entity's component. Returns nil if entity doesn't have the component.
@(require_results)
entry_get :: #force_inline proc(entry: World_Entry, $T: typeid) -> ^T {
	comp_id, ok := world_get_component_id(entry.world, T)
	if !ok {
		return nil
	}
	return entry_get_by_id(entry, T, comp_id)
}

// Get entity's component. Returns nil if entity doesn't have the component.
@(require_results)
entry_get_by_id :: #force_inline proc(entry: World_Entry, $T: typeid, comp_id: Component_ID) -> ^T {
	arch := entry_archetype(entry)
	if arch == nil {
		return nil
	}
	return archetype_get(arch, entry.loc.row, T, comp_id)
}

// Check if entity has a component
@(require_results)
entry_has :: #force_inline proc(entry: World_Entry, $T: typeid) -> bool {
	comp_id, ok := world_get_component_id(entry.world, T)
	if !ok {
		return false
	}
	return entry_has_by_id(entry, comp_id)
}

@(require_results)
entry_has_by_id :: #force_inline proc(entry: World_Entry, comp_id: Component_ID) -> bool {
	arch := entry_archetype(entry)
	if arch == nil {
		return false
	}
	return archetype_has(arch, comp_id)
}

// Get the entity's current archetype (nil if not entity has not components)
@(require_results)
entry_archetype :: #force_inline proc(entry: World_Entry) -> ^Archetype {
	// Check cache
	if entry.arch != nil {
		return entry.arch
	}

	// Look it up
	if entry.loc.archetype == ARCHETYPE_NULL {
		return nil
	}
	return &entry.world.archetypes[entry.loc.archetype]
}

// Set a component to the entity. Moves the entity to appropriate archetype.
// If entity already have this component, just updates the value.
entry_set :: proc(entry: ^World_Entry, value: $T) {
	comp_id := world_register(entry.world, T)
    v := value
    new_loc, loc_changed := world_set_entity_component(entry.world, entry.entity, comp_id, &v, entry.loc)
	if loc_changed {
		entry.loc = new_loc
		entry.arch = nil
	}
}

// Internal: Set component from raw data and Component_ID
@(private)
entry_set_raw :: proc(entry: ^World_Entry, comp_id: Component_ID, data: rawptr, size: int) {
	new_loc, loc_changed := world_set_entity_component(entry.world, entry.entity, comp_id, data, entry.loc)
	if loc_changed {
		entry.loc = new_loc
		entry.arch = nil
	}
}

// Remove a component from the entity. Moves entity to appropriate archetype.
// No-op if entity doesn't have the component
entry_remove :: proc(entry: ^World_Entry, $T: typeid) {
    comp_id, ok := world_get_component_id(entry.world, T)
    if !ok { return }
    new_loc, loc_changed := world_remove_entity_component(entry.world, entry.entity, comp_id, entry.loc)
	if loc_changed {
		entry.loc = new_loc
		entry.arch = nil
	}
}

// Internal: Remove component by Component_ID
@(private)
entry_remove_by_id :: proc(entry: ^World_Entry, comp_id: Component_ID) {
    new_loc, loc_changed := world_remove_entity_component(entry.world, entry.entity, comp_id, entry.loc)
	if loc_changed {
		entry.loc = new_loc
		entry.arch = nil
	}
}
// Queue component add/update via entry.
entry_queue_set :: proc(entry: ^World_Entry, component: $T) {
	world_queue_set(entry.world, entry.entity, component)
}

// Queue component removal via entry.
entry_queue_remove :: proc(entry: ^World_Entry, $T: typeid) {
	world_queue_remove(entry.world, entry.entity, T)
}

// Queue despawn via entry.
entry_queue_despawn :: proc(entry: ^World_Entry) {
	world_queue_despawn(entry.world, entry.entity)
}
