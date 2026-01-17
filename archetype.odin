package ash

Archetype_Index :: distinct u32

ARCHETYPE_NULL :: Archetype_Index(max(u32))

Archetype :: struct {
	index:        	Archetype_Index,
	layout:       	Entity_Layout,
	mask:         	Component_Mask,
	entities:     	[dynamic]Entity,
	columns:        []Component_Column,
	comp_to_column: [MAX_COMPONENTS]int, // comp_id -> column index, -1 if not present

	// Edge cache for o(1) archetype transitions
	add_edges:    map[Component_ID]Archetype_Index,
	remove_edges: map[Component_ID]Archetype_Index,
}

// Initialize the archetype with layout and component info
archetype_init :: proc(
	arch: ^Archetype,
	index: Archetype_Index,
	components: []Component_ID,
	reg: ^Component_Registry,
	allocator := context.allocator,
) {
	arch.index = index
	arch.layout = layout_create(components, allocator)
	arch.entities = make([dynamic]Entity, allocator)
	arch.columns = make([]Component_Column, len(arch.layout.components), allocator)

	for i in 0..<MAX_COMPONENTS {
		arch.comp_to_column[i] = -1
	}

	arch.mask = {}
	for comp_id, col_idx in arch.layout.components {
		mask_add(&arch.mask, comp_id)
		arch.comp_to_column[comp_id] = col_idx
	}
	
	for comp_id, i in arch.layout.components {
		info, ok := registry_get_info(reg, comp_id)
		assert(ok, "Component ID not registered - did you forget to call registry_register?")
		column_init(&arch.columns[i], info.size, allocator)
	}

	arch.add_edges = make(map[Component_ID]Archetype_Index, allocator)
	arch.remove_edges = make(map[Component_ID]Archetype_Index, allocator)
}

// Clean up all archetype resources
archetype_destroy :: proc(arch: ^Archetype) {
	for &col in arch.columns {
		column_destroy(&col)
	}

	delete(arch.columns)
	delete(arch.entities)
	layout_destroy(&arch.layout)

	delete(arch.add_edges)
	delete(arch.remove_edges)
}

// Add entity to archtetype, returns row index
archetype_add_entity :: proc(arch: ^Archetype, entity: Entity) -> int {
	row := len(arch.entities)
	append(&arch.entities, entity)

	// Extend all columns with zeroed data
	for &col in arch.columns {
		column_push_empty(&col)
	}

	return row
}

// Remove entity at row via swap-remove. Returns entity that was moved or ENTITY_NULL if none
archetype_swap_remove :: proc(arch: ^Archetype, row: int) -> Entity {
	count := len(arch.entities)
	assert(row >= 0 && row < count, "row out of bound")

	last_row := count - 1

	// Remove component data from all columns
	for &col in arch.columns {
		column_swap_remove(&col, row)
	}

	moved := ENTITY_NULL
	if row != last_row {
		moved = arch.entities[last_row]
		arch.entities[row] = moved
	}

	pop(&arch.entities)
	return moved
}

// Get column index for component ID (-1 if not present)
archetype_column_index :: #force_inline proc(arch: ^Archetype, id: Component_ID) -> int {
	return arch.comp_to_column[id]
}

// Get column for component ID (nil if not present)
archetype_get_column :: #force_inline proc(arch: ^Archetype, id: Component_ID) -> ^Component_Column {
	idx := archetype_column_index(arch, id)
	if idx == -1 {
		return nil
	}
	return &arch.columns[idx]
}

// Check if archetype has component
archetype_has :: proc(arch: ^Archetype, id: Component_ID) -> bool {
	return mask_has(arch.mask, id)
}

// Number of entities in archetype
archetype_entity_count :: proc(arch: ^Archetype) -> int {
	return len(arch.entities)
}

// Number of components in archetype
archetype_component_count :: proc(arch: ^Archetype) -> int {
	return len(arch.layout.components)
}

// Set the data of a component for an entity
archetype_set :: proc(arch: ^Archetype, row: int, id: Component_ID, data: ^$T) {
	col := archetype_get_column(arch, id)
	if col != nil {
		column_set(col, row, data)
	}
}

// Get the data of a component for an entity
archetype_get :: proc(arch: ^Archetype, row: int, $T: typeid, id: Component_ID) -> ^T {
	col := archetype_get_column(arch, id)
	if col == nil {
		return nil
	}
	return column_get(col, T, row)
}

// Get the data of a component for an entity
archetype_slice :: proc(arch: ^Archetype, $T: typeid, id: Component_ID) -> []T {
	col := archetype_get_column(arch, id)
	if col == nil {
		return nil
	}
	return column_get_slice(col, T)
}

// Check if archetype has ALL components in the given slice
archetype_matches :: proc(arch: ^Archetype, required: []Component_ID) -> bool {
	for id in required {
		if !archetype_has(arch, id) {
			return false
		}
	}
	return true
}

// Reserve space for N more entities (pre-allocate columns)
archetype_reserve :: proc(arch: ^Archetype, new_entities: int) {
    new_cap := archetype_entity_count(arch) + new_entities

    // Reserve in entity array
    reserve(&arch.entities, new_cap)

    // Reserve in each column
    for &col in arch.columns {
        column_reserve(&col, new_cap)
    }
}