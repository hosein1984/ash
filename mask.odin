package ash

// Note: Should a reasonable upper limit. We can increase if needed
MAX_COMPONENTS :: 64

Component_Mask :: distinct bit_set[0 ..< MAX_COMPONENTS;u64]

// Create mask with single component
mask_from_id :: #force_inline proc "contextless" (id: Component_ID) -> Component_Mask {
	mask: Component_Mask
	mask = {int(id)}
	return mask
}

// Add component to mask
mask_add :: #force_inline proc "contextless" (mask: ^Component_Mask, id: Component_ID) {
	mask^ += mask_from_id(id)
}

// Remove component from mask
mask_remove :: #force_inline proc "contextless" (mask: ^Component_Mask, id: Component_ID) {
	mask^ -= mask_from_id(id)
}

// Count number components in mask
mask_count :: #force_inline proc "contextless" (mask: Component_Mask) -> int {
	return card(mask)
}

// Check if mask is empty
mask_emtpy :: #force_inline proc "contextless" (mask: Component_Mask) -> bool {
	return mask == nil || mask_count(mask) == 0
}

// Check if mask has component
mask_has :: #force_inline proc "contextless" (mask: Component_Mask, id: Component_ID) -> bool {
	return int(id) in mask
}

// Check if `a` has all components in `b`
mask_contains_all :: proc(a, b: Component_Mask) -> bool {
    return a >= b
}

// Check if `a` and `b` share any components
mask_intersects :: proc(a, b: Component_Mask) -> bool {
    return card(a & b) > 0
}

mask_equals :: proc(a, b: Component_Mask) -> bool {
    return a == b
}
