package ash

import "core:mem"

Entity_Location :: struct {
	archetype: Archetype_Index,
	row:       int,
	generation:   u32,
	valid:     bool,
}

LOCATION_INVALID :: Entity_Location {
	archetype = ARCHETYPE_NULL,
	row       = -1,
	generation   = 0,
	valid     = false,
}

Location_Map :: struct {
	locations: [dynamic]Entity_Location, // Indexed by entity id
	count:     int, // Number of valid entities
	allocator: mem.Allocator,
}

location_map_init :: proc(lm: ^Location_Map, allocator := context.allocator) {
	lm.locations = make([dynamic]Entity_Location, allocator)
	lm.count = 0
	lm.allocator = allocator
}

location_map_destroy :: proc(lm: ^Location_Map) {
	delete(lm.locations)
}

// Insert or update location for entity ID
location_map_insert :: proc(
	lm: ^Location_Map,
	id: u32,
	arch: Archetype_Index,
	row: int,
	generation: u32 = 0,
) {
	assert(id > 0, "Entity ID must be >= 1 (o is reserved for ENTITY_NULL)")

	location_map_ensure_capacity(lm, id)

	idx := entity_id_to_index(id)
	was_valid := location_is_valid(lm.locations[idx])

	lm.locations[idx] = Entity_Location {
		archetype = arch,
		row       = row,
		generation   = generation,
		valid     = true,
	}

	if !was_valid {
		lm.count += 1
	}
}

// Remove entity from the map (marks as invalid)
location_map_remove :: proc(lm: ^Location_Map, id: u32) {
	if id == 0 {
		return
	}

	idx := entity_id_to_index(id)

	if idx < len(lm.locations) && location_is_valid(lm.locations[idx]) {
		lm.locations[idx] = LOCATION_INVALID
		lm.count -= 1
	}
}

// Get location for entity ID
location_map_get :: proc(lm: ^Location_Map, id: u32) -> (Entity_Location, bool) #optional_ok {
	if id == 0 {
		return LOCATION_INVALID, false
	}

	idx := entity_id_to_index(id)

	if idx < len(lm.locations) {
		loc := lm.locations[idx]
		if location_is_valid(loc) {
			return loc, true
		}
	}

	return LOCATION_INVALID, false
}

// Update just the row for an entity (used after swap-remove in archetype)
location_map_set_row :: proc(lm: ^Location_Map, id: u32, row: int) {
	if id == 0 {
		return
	}

	idx := entity_id_to_index(id)

	if idx < len(lm.locations) && location_is_valid(lm.locations[idx]) {
		lm.locations[idx].row = row
	}
}

// Check if entity ID is in the map
location_map_contains :: proc(lm: ^Location_Map, id: u32) -> bool {
	_, ok := location_map_get(lm, id)
	return ok
}

// Number of valid entities tracked
location_map_len :: proc(lm: ^Location_Map) -> int {
	return lm.count
}

@(private)
location_map_ensure_capacity :: proc(lm: ^Location_Map, id: u32) {
	needed := int(id) // e.g. i=5 needs indices 0-4, so length 5
	current := len(lm.locations)

	if needed > current {
		resize(&lm.locations, needed)
		for i in current ..< needed {
			lm.locations[i] = LOCATION_INVALID
		}
	}
}

@(private)
location_is_valid :: #force_inline proc "contextless" (loc: Entity_Location) -> bool {
	return loc.valid
}
