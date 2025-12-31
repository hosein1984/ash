package ash

import "core:mem"
import "core:slice"

World_ID :: distinct u32

World :: struct {
	id:         World_ID,
	allocator:  mem.Allocator,

	// Component registry
	registry:   Component_Registry,

	// Entity tracking
	locations:  Location_Map,
	free_list:  [dynamic]Entity, // Recycled entities with incremented versions
	next_id:    u32, // Next fresh entity id

	// Archetype storage
	archetypes: [dynamic]Archetype,
	arch_index: map[u64]Archetype_Index, // layout_hash -> archetype index
}

@(private = "file")
next_world_id: World_ID = 0

// Create a new world
world_init :: proc(world: ^World, allocator := context.allocator) {
	world.id = next_world_id
	world.allocator = allocator

	registry_init(&world.registry, allocator)
	location_map_init(&world.locations, allocator)

	world.free_list = make([dynamic]Entity, allocator)
	world.next_id = 1 // 0 is reserved for ENTITY_NULL

	world.archetypes = make([dynamic]Archetype, allocator)
	world.arch_index = make(map[u64]Archetype_Index, allocator)

	next_world_id += 1
}

// Destroy world and all its resources
world_destroy :: proc(world: ^World) {
	delete(world.arch_index)

	for &arch in world.archetypes {
		archetype_destroy(&arch)
	}
	delete(world.archetypes)

	delete(world.free_list)

	location_map_destroy(&world.locations)
	registry_destroy(&world.registry)
}

// Register a component type, returns its ID
world_register :: proc(world: ^World, $T: typeid) -> Component_ID {
	return registry_register(&world.registry, T)
}

// Spawn a new entity (or recycle from free list)
world_spawn :: proc(world: ^World) -> Entity {
	entity := world_create_entity(world)

	location_map_insert(
		&world.locations,
		entity_id(entity),
		ARCHETYPE_NULL,
		0,
		entity_version(entity),
	)

	return entity
}


// Despawn an entity.
world_despawn :: proc(world: ^World, entity: Entity) {
	if !world_is_alive(world, entity) {
		return
	}

	loc := world_get_entity_location(world, entity)

	// Remove from archetype if entity has components
	if loc.archetype != ARCHETYPE_NULL {
		arch := &world.archetypes[loc.archetype]

		moved_entity := archetype_swap_remove(arch, loc.row)
		if moved_entity != ENTITY_NULL {
			// Another entity was moved. We need to update the location
			location_map_set_row(&world.locations, entity_id(moved_entity), loc.row)
		}
	}

	// Remove from the location map
	location_map_remove(&world.locations, entity_id(entity))

	// Mark as free for recycling
	append(&world.free_list, entity)
}

// Spawn entity with initial components.
// Usage:
// 	 world_spawn_with(&world, Position{1,2}, Velocity{3,4}, Health{100})
world_spawn_with :: proc(world: ^World, components: ..any) -> Entity {
	if len(components) == 0 {
		return world_spawn(world)
	}

	comp_ids := make([]Component_ID, len(components))
	defer delete(comp_ids)
	for c, i in components {
		comp_ids[i] = registry_register_dynamic(&world.registry, c.id)
	}
	slice.sort(comp_ids)

	entity := world_create_entity(world)
	arch := world_get_or_create_archetype(world, comp_ids)
	row := archetype_push_entity(arch, entity)

	for c, i in components {
		col := archetype_get_column(arch, comp_ids[i])
		if col != nil {
			column_set_raw(col, row, c.data)
		}
	}

	location_map_insert(
		&world.locations,
		entity_id(entity),
		arch.index,
		row,
		entity_version(entity),
	)

	return entity
}

// Helper to create an entity without adding it to location map
@(private = "file")
world_create_entity :: proc(world: ^World) -> Entity {
	entity: Entity

	if len(world.free_list) > 0 {
		// Recycle entity
		entity = pop(&world.free_list)
		entity = entity_inc_version(entity)
	} else {
		// Create new entity
		entity = entity_make(world.next_id, 0)
		world.next_id += 1
	}

	return entity
}

// Check if entity is alive (valid and not despawned)
world_is_alive :: proc(world: ^World, entity: Entity) -> bool {
	if entity == ENTITY_NULL {
		return false
	}

	loc, ok := world_get_entity_location(world, entity)
	if !ok {
		return false
	}

	return loc.version == entity_version(entity)
}


// Get component ID for a type (must be registered)
world_get_component_id :: proc(world: ^World, $T: typeid) -> (Component_ID, bool) #optional_ok {
	return registry_get_id(&world.registry, T)
}

@(private)
world_get_component_id_dynamic :: proc(
	world: ^World,
	type: typeid,
) -> (
	Component_ID,
	bool,
) #optional_ok {
	return registry_get_id_dynamic(&world.registry, type)
}

// Number of living entities
world_len :: proc(world: ^World) -> int {
	return location_map_len(&world.locations)
}

world_get_archetype :: #force_inline proc "contextless" (
	world: ^World,
	index: Archetype_Index,
) -> ^Archetype {
	if index == ARCHETYPE_NULL || int(index) >= len(world.archetypes) {
		return nil
	}
	return &world.archetypes[index]
}

// Get or create archetype for a layout. Takes ownership of layout on creation
world_get_or_create_archetype :: proc(world: ^World, components: []Component_ID) -> ^Archetype {
	hash := hash_component_ids(components)

	// Check if archetype already exists
	if arch_idx, ok := world.arch_index[hash]; ok {
		// TODO: Hash collision? Not serious for now
		return &world.archetypes[arch_idx]
	}

	// Create new archtype
	new_idx := Archetype_Index(len(world.archetypes))

	arch: Archetype
	archetype_init(&arch, new_idx, components, &world.registry, world.allocator)

	append(&world.archetypes, arch)
	world.arch_index[hash] = new_idx

	return &world.archetypes[new_idx]
}

// Transfer entity between archetypes, copying shared component data
// Returns the new row index in the target archetype.
world_transfer_entity :: proc(
	world: ^World,
	entity: Entity,
	src_arch_index: Archetype_Index,
	dst_arch_index: Archetype_Index,
	src_row: int,
) -> int {
	src_arch := &world.archetypes[src_arch_index]
	dst_arch := &world.archetypes[dst_arch_index]

	// 1. Add entity to destination archetype
	new_row := archetype_push_entity(dst_arch, entity)

	// 2. Copy component data for all shared components
	for comp_id in dst_arch.layout.components {
		// Check if source has this component
		src_col := archetype_get_column(src_arch, comp_id)
		if src_col == nil {
			continue // New component, already zero initialized
		}

		dst_col := archetype_get_column(dst_arch, comp_id)
		assert(dst_col != nil, "Destination should have column for its own components")

		// Copy the data
		if src_col.elem_size > 0 {
			src_ptr := column_get_raw(src_col, src_row)
			column_set_raw(dst_col, new_row, src_ptr)
		}
	}

	// 3. Remove entity from source archetype
	moved_entity := archetype_swap_remove(src_arch, src_row)

	// 4. Update location for swapped entity if eny
	if moved_entity != ENTITY_NULL {
		location_map_set_row(&world.locations, entity_id(moved_entity), src_row)
	}

	// 5. Update location for transferred entity
	location_map_insert(
		&world.locations,
		entity_id(entity),
		dst_arch.index,
		new_row,
		entity_version(entity),
	)

	return new_row
}


// Get location of an entity
@(private)
world_get_entity_location :: proc(
	world: ^World,
	entity: Entity,
) -> (
	Entity_Location,
	bool,
) #optional_ok {
	return location_map_get(&world.locations, entity_id(entity))
}
