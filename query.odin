package ash

import "core:fmt"
import "base:runtime"

// Query with cached archetype matching
Query :: struct {
	world:           ^World,
	filter:          Filter,
	cached_archs:    [dynamic]Archetype_Index,
	last_arch_count: int, // For incremental cache updates
}

// Iterator for entity-by-entity access
Query_Entry_Iter :: struct {
	query:      ^Query,
	arch_idx:   int, // Index into cached_archs
	entity_idx: int, // Index into current archetype's entities
	locked:     bool, // World is locked
}

// Iterator for archetype-by-archetype access (bulk processing)
Query_Arch_Iter :: struct {
	query:    ^Query,
	arch_idx: int, // Index into cache.archetype
	locked:   bool, // World is locked
}

// ============================================================================
// QUERY LIFECYCLE
// ============================================================================


// Create query with filter (automatically cleans up after itself)
// At the moment I don't see any use case for passing iterators around to auto-cleaning should be fine.
@(private)
query_create :: proc(world: ^World, filter: Filter, allocator := context.allocator) -> Query {
	return Query {
		world = world,
		filter = filter,
		cached_archs = make([dynamic]Archetype_Index, allocator),
		last_arch_count = 0,
	}
}

// Destroy query and free cache
@(private)
query_destroy :: proc(q: ^Query) {
	delete(q.cached_archs)
}

// Refresh cache (incremental - only scans new archetypes).
// Automatically called when needed.
@(private)
query_refresh :: proc(q: ^Query) {
	world_arch_count := len(q.world.archetypes)

	// Only scan archetypes added since last refresh
	for i in q.last_arch_count ..< world_arch_count {
		arch := &q.world.archetypes[i]
		if filter_matches_archetype(&q.filter, arch) {
			append(&q.cached_archs, arch.index)
		}
	}

	q.last_arch_count = world_arch_count
}


// ============================================================================
// ENTITY ITERATION
// ============================================================================

// Create entity iterator
query_iter :: proc(q: ^Query) -> Query_Entry_Iter {
	query_refresh(q)
	return Query_Entry_Iter{query = q, arch_idx = 0, entity_idx = 0}
}

// Advance to next entity
//
// USAGE (explicit for loop - RECOMMENDED):
//   it := query_iter(&q)
//   for {
//       entry, ok := query_next(&it)
//       if !ok { break }
//       // ... use entry, safe to break/return ...
//   }
//
// USAGE (for-in - OK if no break):
//   it := query_iter(&q)
//   for entry in query_next(&it) {
//       // ... use entry, do NOT break ...
//   }
//
// WARNING: Using `break` inside `for-in` will leak the lock!
//
@(deferred_in = unlock_query_iter)
query_next :: proc(it: ^Query_Entry_Iter) -> (World_Entry, bool) {
	lock_query_iter(it)

	// Skip empty archetypes
	for it.arch_idx < len(it.query.cached_archs) {
		arch_index := it.query.cached_archs[it.arch_idx]
		arch := world_get_archetype(it.query.world, arch_index)

		if it.entity_idx < len(arch.entities) {
			entity := arch.entities[it.entity_idx]
			entry := world_entry(it.query.world, entity)
			it.entity_idx += 1
			return entry, true
		}

		// No more entity in archetype. Try next.
		it.arch_idx += 1
		it.entity_idx = 0
	}

	unlock_query_iter(it)
	return {}, false
}

lock_query_iter :: #force_inline proc(it: ^Query_Entry_Iter) {
	if !it.locked {
		world_lock(it.query.world)
		it.locked = true
	}
}

unlock_query_iter :: #force_inline proc(it: ^Query_Entry_Iter) {
	if it.locked {
		world_unlock(it.query.world)
		it.locked = false
	}
}

// ============================================================================
// ARCHETYPE ITERATION
// ============================================================================

// Create archetype iterator
query_iter_archs :: proc(q: ^Query) -> Query_Arch_Iter {
	query_refresh(q)
	return Query_Arch_Iter{query = q, arch_idx = 0}
}

// Advance to next archetype
//
// USAGE (explicit for loop - RECOMMENDED):
//   it := query_iter_archs(&q)
//   for {
//       arch, ok := query_next_arch(&it)
//       if !ok { break }
//       // ... bulk process arch.entities ...
//   }
//
@(deferred_in = unlock_query_arch_iter)
query_next_arch :: proc(it: ^Query_Arch_Iter) -> (^Archetype, bool) {
	lock_query_arch_iter(it)

	if it.arch_idx < len(it.query.cached_archs) {
		arch_index := it.query.cached_archs[it.arch_idx]
		arch := world_get_archetype(it.query.world, arch_index)
		it.arch_idx += 1
		return arch, true
	}

	unlock_query_arch_iter(it)
	return nil, false
}

@(private)
lock_query_arch_iter :: #force_inline proc(it: ^Query_Arch_Iter) {
	if !it.locked {
		world_lock(it.query.world)
		it.locked = true
	}
}

@(private)
unlock_query_arch_iter :: #force_inline proc(it: ^Query_Arch_Iter) {
	if it.locked {
		world_unlock(it.query.world)
		it.locked = false
	}
}




// ============================================================
// UTILITY FUNCTIONS
// ============================================================

// Get first matching entry
query_first :: proc(q: ^Query) -> (World_Entry, bool) {
	it := query_iter(q)
	return query_next(&it)
}

// Count matching entities
query_count :: proc(q: ^Query) -> int {
	query_refresh(q)

	count := 0
	for arch_index in q.cached_archs {
		arch := world_get_archetype(q.world, arch_index)
		count += len(arch.entities)
	}
	return count
}

// Get cached archetype indices (for advanced use)
query_archetypes :: proc(q: ^Query) -> []Archetype_Index {
	query_refresh(q)
	return q.cached_archs[:]
}
