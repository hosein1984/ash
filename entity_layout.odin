package ash

import "core:mem"
import "core:slice"

Entity_Layout :: struct {
	components: []Component_ID, // Sorted for consistent hashing
	hash:       u64,
	allocator:  mem.Allocator,
}

layout_create :: proc(ids: []Component_ID, allocator := context.allocator) -> Entity_Layout {
	sorted := slice.clone(ids, allocator)
	slice.sort(sorted)
	return Entity_Layout {
		components = sorted,
		hash = hash_component_ids(sorted),
		allocator = allocator,
	}
}

layout_destroy :: proc(layout: ^Entity_Layout) {
	delete(layout.components, layout.allocator)
	layout.components = nil
}

layout_has :: proc(layout: ^Entity_Layout, id: Component_ID) -> bool {
	_, found := slice.binary_search(layout.components, id)
	return found
}

layout_hash :: proc(layout: ^Entity_Layout) -> u64 {
	return layout.hash
}

layout_equals :: proc(a, b: ^Entity_Layout) -> bool {
	return slice.equal(a.components, b.components)
}

// Create new layout with the added component
layout_with :: proc(
	layout: ^Entity_Layout,
	id: Component_ID,
	allocator := context.allocator,
) -> Entity_Layout {
	if layout_has(layout, id) {
		return layout_create(layout.components, allocator)
	}

	curr_comps := len(layout.components)
	new_comps := curr_comps + 1

	new_ids := make([]Component_ID, new_comps, allocator)
	copy(new_ids, layout.components)
	new_ids[curr_comps] = id
	slice.sort(new_ids)

	return Entity_Layout {
		components = new_ids,
		hash = hash_component_ids(new_ids),
		allocator = allocator,
	}
}

// Create a new layout with removed component
layout_without :: proc(
	layout: ^Entity_Layout,
	id: Component_ID,
	allocator := context.allocator,
) -> Entity_Layout {
	if !layout_has(layout, id) {
		return layout_create(layout.components, allocator)
	}

	new_comps := len(layout.components) - 1
	new_ids := make([]Component_ID, new_comps, allocator)

	dst_idx := 0
	for comp_id in layout.components {
		if comp_id != id {
			new_ids[dst_idx] = comp_id
			dst_idx += 1
		}
	}

	return Entity_Layout {
		components = new_ids,
		hash = hash_component_ids(new_ids),
		allocator = allocator,
	}
}

layout_clone :: proc(layout: ^Entity_Layout, allocator := context.allocator) -> Entity_Layout {
	return Entity_Layout {
		components = slice.clone(layout.components, allocator),
		hash = layout.hash,
		allocator = allocator,
	}
}

@(private)
hash_component_ids :: #force_inline proc "contextless" (ids: []Component_ID) -> u64 {
	h: u64 = 14695981039346656037 // FNV offset basis
	for id in ids {
		h ~= u64(id)
		h *= 1099511628211 // FNV prime
	}
	return h
}
