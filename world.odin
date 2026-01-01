package ash

import "core:mem"
import "core:slice"

World_ID :: distinct u32

World :: struct {
	id:               World_ID,
	allocator:        mem.Allocator,

	// Component registry
	registry:         Component_Registry,

	// Entity tracking
	locations:        Location_Map,
	free_list:        [dynamic]Entity, // Recycled entities with incremented versions
	next_id:          u32, // Next fresh entity id

	// Archetype storage
	archetypes:       [dynamic]Archetype,
	arch_index:       map[u64]Archetype_Index, // layout_hash -> archetype index

	// Query (Cache)
	queries:          map[u64]Query,

	// Command Buffer
	command_arena:    mem.Dynamic_Arena, // Owns component data copies
	pending_commands: [dynamic]Command,

	// Resources
	resources:        map[typeid]rawptr,

	// Lock
	lock_count:       int,
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

	world.queries = make(map[u64]Query, allocator)

	mem.dynamic_arena_init(&world.command_arena, allocator, allocator)
	world.pending_commands = make([dynamic]Command, allocator)

	world.resources = make(map[typeid]rawptr, allocator)

	world.lock_count = 0

	next_world_id += 1
}

// Destroy world and all its resources
world_destroy :: proc(world: ^World) {
	delete(world.resources)

	delete(world.pending_commands)
	mem.dynamic_arena_destroy(&world.command_arena)

	for _, &q in world.queries {
		query_destroy(&q)
	}
	delete(world.queries)

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


// Spawn an entity with initial components.
// Usage:
// 	 world_spawn(&world})
// 	 world_spawn(&world, Position{1,2}, Velocity{3,4}, Health{100})
world_spawn :: proc(world: ^World, components: ..any) -> Entity {
	if len(components) == 0 {
		entity := world_next_entity(world)

		location_map_insert(
			&world.locations,
			entity_id(entity),
			ARCHETYPE_NULL,
			0,
			entity_version(entity),
		)

		return entity
	}

	if world_is_locked(world) {
		panic(
			"world_spawn: Cannot spawn during iteration.\n" +
			"  Use world_queue_spawn(&world, components..) instead.\n" +
			"  Then call world_flush(&world) after the loop.",
		)
	}

	comp_ids := make([]Component_ID, len(components))
	defer delete(comp_ids)
	for c, i in components {
		comp_ids[i] = registry_register_dynamic(&world.registry, c.id)
	}
	slice.sort(comp_ids)

	entity := world_next_entity(world)
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


// Despawn an entity.
world_despawn :: proc(world: ^World, entity: Entity) {
	if !world_is_alive(world, entity) {
		return
	}

	if world_is_locked(world) {
		panic(
			"world_despawn: Cannot despawn during iteration.\n" +
			"  Use world_queue_despawn(&world, entity) or entry_queue_despawn(&entry) instead.\n" +
			"  Then call world_flush(&world) after the loop.",
		)
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


// Helper to create an entity without adding it to location map
@(private = "file")
world_next_entity :: proc(world: ^World) -> Entity {
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
world_entity_count :: proc(world: ^World) -> int {
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

// Increment lock (called when query iteration starts)
world_lock :: #force_inline proc "contextless" (world: ^World) {
	world.lock_count += 1
}

// Decrement lock (called when query iteration ends)
world_unlock :: #force_inline proc "contextless" (world: ^World) {
	if world_is_locked(world) {
		world.lock_count -= 1
	}
}

// Check if world is locked
world_is_locked :: #force_inline proc "contextless" (world: ^World) -> bool {
	return world.lock_count > 0
}

// Get or create a persistent query for the given filter.
world_query :: proc(world: ^World, filter: Filter) -> ^Query {
	hash := filter_hash(filter)

	if _, found := world.queries[hash]; !found {
		world.queries[hash] = query_create(world, filter, world.allocator)
	}

	return &world.queries[hash]
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

// Queue entity spawn. Returns reserved Entity ID immediately.
// Entity becomes "alive" after flush.
world_queue_spawn :: proc(world: ^World, components: ..any) -> Entity {
	entity := world_next_entity(world)
	allocator := mem.dynamic_arena_allocator(&world.command_arena)

	comp_data: []Command_Component
	if len(components) > 0 {
		comp_data = make([]Command_Component, len(components), allocator)

		for c, i in components {
			comp_id := registry_register_dynamic(&world.registry, c.id)
			size := size_of(c.id)

			// Copy component data into arena
			data_copy, _ := mem.dynamic_arena_alloc(&world.command_arena, size)
			mem.copy(data_copy, c.data, size)

			comp_data[i] = Command_Component {
				id   = comp_id,
				data = data_copy,
				size = size,
			}
		}
	}

	cmd := Command {
		kind       = .Spawn,
		entity     = entity,
		components = comp_data,
	}
	append(&world.pending_commands, cmd)
	return entity
}

// Queue entity despawn.
world_queue_despawn :: proc(world: ^World, entity: Entity) {
	cmd := Command {
		kind   = .Despawn,
		entity = entity,
	}
	append(&world.pending_commands, cmd)
}

// Queue component add/update.
world_queue_set :: proc(world: ^World, entity: Entity, component: $T) {
	comp_id := registry_register(&world.registry, T)
	size := size_of(component)
	v := component

	// Copy component data into arena
	data_copy, _ := mem.dynamic_arena_alloc(&world.command_arena, size)
	data_src := mem.ptr_to_bytes(&v)
	mem.copy(data_copy, raw_data(data_src), size)

	alloctor := mem.dynamic_arena_allocator(&world.command_arena)
	comp_data := make([]Command_Component, 1, alloctor)
	comp_data[0] = Command_Component {
		id   = comp_id,
		data = data_copy,
		size = size,
	}

	cmd := Command {
		kind       = .Set_Component,
		entity     = entity,
		components = comp_data,
	}
	append(&world.pending_commands, cmd)
}

// Queue component removal.
world_queue_remove :: proc(world: ^World, entity: Entity, $T: typeid) {
	comp_id, ok := registry_get_id(&world.registry, T)
	if !ok {
		return // Component not registered, nothing to remove
	}

	cmd := Command {
		kind      = .Remove_Component,
		entity    = entity,
		component = comp_id,
	}
	append(&world.pending_commands, cmd)
}

// Execute all queued commands in order.
world_flush :: proc(world: ^World) {
	if world_is_locked(world) {
		panic(
			"world_flush: Cannot flush commands while world is locked.\n" +
			"  Flush must be called after iteration completes, not inside a query loop.\n" +
			"  Move world_flush(&world) outside of your for loop.",
		)
	}

	for &cmd in world.pending_commands {
		switch cmd.kind {
		case .Spawn:
			// Entity ID already reserved, now actually create it
			if len(cmd.components) == 0 {
				// Empty entity
				location_map_insert(
					&world.locations,
					entity_id(cmd.entity),
					ARCHETYPE_NULL,
					0,
					entity_version(cmd.entity),
				)
			} else {
				// Get component IDs and sort them
				comp_ids := make([]Component_ID, len(cmd.components))
				for c, i in cmd.components {
					comp_ids[i] = c.id
				}
				slice.sort(comp_ids)

				// Get or create archetype
				arch := world_get_or_create_archetype(world, comp_ids)
				row := archetype_push_entity(arch, cmd.entity)

				// Copy component data
				for c in cmd.components {
					col := archetype_get_column(arch, c.id)
					if col != nil {
						column_set_raw(col, row, c.data)
					}
				}

				location_map_insert(
					&world.locations,
					entity_id(cmd.entity),
					arch.index,
					row,
					entity_version(cmd.entity),
				)

				delete(comp_ids)
			}
		case .Despawn:
			world_despawn(world, cmd.entity)
		case .Set_Component:
			if !world_is_alive(world, cmd.entity) {
				continue
			}
			if len(cmd.components) > 0 {
				c := cmd.components[0]
				entry := world_entry(world, cmd.entity)
				entry_set_raw(&entry, c.id, c.data, c.size)
			}
		case .Remove_Component:
			if !world_is_alive(world, cmd.entity) {
				continue
			}
			entry := world_entry(world, cmd.entity)
			entry_remove_by_id(&entry, cmd.component)
		}
	}
	world_clear_queue(world)
}

// Discard all queued commands without executing.
world_clear_queue :: proc(world: ^World) {
	clear(&world.pending_commands)
	mem.dynamic_arena_reset(&world.command_arena)
}

// Check if commands are pending.
world_has_pending :: proc(world: ^World) -> bool {
	return len(world.pending_commands) > 0
}

// Get pending command count.
world_pending_count :: proc(world: ^World) -> int {
	return len(world.pending_commands)
}

// ============================================================================
// RESOURCE MANAGEMENT
// ============================================================================

// Add/replace a resource. Caller owns the memory.
world_set_resource :: proc(world: ^World, resource: ^$T) {
	world.resources[T] = resource
}

// Get resource by type. Returns nil if not found.
world_get_resource :: proc(world: ^World, $T: typeid) -> ^T {
	resource, ok := world.resources[T]
	if !ok {
		return nil
	}
	return transmute(^T)resource
}

// Check if resource exists
world_has_resource :: proc(world: ^World, $T: typeid) -> bool {
	_, ok := world.resources[T]
	return ok
}

// Remove a resource (does not free memory)
world_remove_resource :: proc(world: ^World, $T: typeid) {
	delete_key(&world.resources, T)
}
