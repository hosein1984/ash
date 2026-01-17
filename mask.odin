package ash

import "core:math/bits"

MAX_COMPONENTS :: 512
WORD_SIZE      :: 64
NUM_CHUNKS     :: (MAX_COMPONENTS + WORD_SIZE - 1) / WORD_SIZE

Component_Mask :: struct {
    bits: [NUM_CHUNKS]u64,
}

mask_from_id :: #force_inline proc "contextless" (id: Component_ID) -> Component_Mask {
    mask: Component_Mask
    chunk_idx := int(id) / WORD_SIZE
    bit_idx   := int(id) % WORD_SIZE
    mask.bits[chunk_idx] = 1 << u64(bit_idx)
    return mask
}

mask_from_ids :: #force_inline proc "contextless" (ids: ..Component_ID) -> Component_Mask {
    mask: Component_Mask
    for id in ids {
        mask_add(&mask, id)
    }
    return mask
}

mask_add :: #force_inline proc "contextless" (mask: ^Component_Mask, id: Component_ID) {
    chunk_idx := int(id) / WORD_SIZE
    bit_idx   := int(id) % WORD_SIZE
    mask.bits[chunk_idx] |= (1 << u64(bit_idx))
}

mask_remove :: #force_inline proc "contextless" (mask: ^Component_Mask, id: Component_ID) {
    chunk_idx := int(id) / WORD_SIZE
    bit_idx   := int(id) % WORD_SIZE
    mask.bits[chunk_idx] &= ~(1 << u64(bit_idx))
}

mask_has :: #force_inline proc "contextless" (mask: Component_Mask, id: Component_ID) -> bool {
    chunk_idx := int(id) / WORD_SIZE
    bit_idx   := int(id) % WORD_SIZE
    return (mask.bits[chunk_idx] & (1 << u64(bit_idx))) != 0
}

mask_is_empty :: #force_inline proc "contextless" (mask: Component_Mask) -> bool {
    for chunk in mask.bits {
        if chunk != 0 do return false
    }
    return true
}

mask_contains_all :: #force_inline proc "contextless" (a, b: Component_Mask) -> bool {
    for i in 0..<NUM_CHUNKS {
        // "a has all bits of b" means (a & b) == b
        if (a.bits[i] & b.bits[i]) != b.bits[i] do return false
    }
    return true
}

mask_intersects :: #force_inline proc "contextless" (a, b: Component_Mask) -> bool {
    for i in 0..<NUM_CHUNKS {
        if (a.bits[i] & b.bits[i]) != 0 do return true
    }
    return false
}

mask_equals :: #force_inline proc "contextless" (a, b: Component_Mask) -> bool {
    return a.bits == b.bits
}

mask_count :: #force_inline proc "contextless" (mask: Component_Mask) -> int {
    count := 0
    for chunk in mask.bits {
        count += int(bits.count_ones(chunk))
    }
    return count
}

mask_hash :: #force_inline proc "contextless" (mask: Component_Mask) -> u64 {
    // FNV-1a hash over the chunks
    h: u64 = 14695981039346656037
    for chunk in mask.bits {
        h ~= chunk
        h *= 1099511628211
    }
    return h
}