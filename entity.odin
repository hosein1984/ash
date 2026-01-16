package ash

// Generational entity identifier.
// Upper 32 bits: ID, Lower 32 bits: generation.
// The generation is incremented when entity is destroyed/recycled.
Entity :: distinct u64 

@(private = "file") ENTITY_ID_BITS         :: 32
@(private = "file") ENTITY_ID_MASK         :: 0xFFFFFFFF00000000
@(private = "file") ENTITY_GENERATION_MASK :: 0x00000000FFFFFFFF

// Null Entity represents an invalid entity
// Note: This means valid entity ids start from 1.
ENTITY_NULL :: Entity(0)

entity_make :: #force_inline proc "contextless" (id: u32, generation: u32 = 0) -> Entity {
    return Entity(u64(id) << ENTITY_ID_BITS | u64(generation))
}

entity_id :: #force_inline proc "contextless" (e: Entity) -> u32 {
    return u32(u64(e) >> ENTITY_ID_BITS)
}

entity_generation :: #force_inline proc "contextless" (e: Entity) -> u32 {
    return u32(u64(e) & ENTITY_GENERATION_MASK)
}

entity_inc_generation :: #force_inline proc "contextless" (e: Entity) -> Entity {
    generation := entity_generation(e)
    return entity_make(entity_id(e), generation + 1)
}

@(private)
entity_id_to_index :: #force_inline proc "contextless" (id: u32) -> int {
    return int(id) - 1
}