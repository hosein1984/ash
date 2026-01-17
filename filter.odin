package ash

import "core:fmt"
MAX_FILTER_CLAUSES :: 8

// Single clause: 'requires' AND 'excludes' AND 'optional'
Filter_Clause :: struct {
    requires: Component_Mask, // Must have ALL of these
    excludes: Component_Mask, // Must have NONE of these
    anyof:    Component_Mask, // Must have AT LEAST ONE of these (ignored if empty)
}

// Filter with multiple clauses (OR between clauses)
Filter :: struct {
    clauses:      [MAX_FILTER_CLAUSES]Filter_Clause,
    clause_count: u8,
    exact:        bool, // If true, requires must match EXACTLY (first clause only)
}

// Empty filter matching everything
FILTER_ALL :: Filter{}

// Descriptor for building clauses with typeids
Filter_Clause_Desc :: struct {
    requires: []typeid,
    excludes: []typeid,
    anyof:    []typeid,
}

// Check if filter matches archetype
filter_matches_archetype :: proc(filter: ^Filter, arch: ^Archetype) -> bool {
    return filter_matches_mask(filter, arch.mask)
}

// Check if filter matches component mask
filter_matches_mask :: proc(filter: ^Filter, mask: Component_Mask) -> bool {
    if filter.clause_count == 0 {
        return true
    }

    // OR logic: any clause matching is enough
    for i in 0 ..< filter.clause_count {
        // exact only applies to first clause
        exact := filter.exact && i == 0
        clause := &filter.clauses[i]

        if filter_clause_matches(clause, mask, exact) {
            return true
        }
    }

    return false
}

// Check if single clause matches mask
filter_clause_matches :: proc(clause: ^Filter_Clause, mask: Component_Mask, exact: bool) -> bool {
    // Must have ALL required
    if !mask_contains_all(mask, clause.requires) {
        return false
    }

    // Must have NONE of excluded
    if mask_intersects(mask, clause.excludes) {
        return false
    }

    // Must have AT LEAST ONE of anyof
    if clause.anyof != {} && !mask_intersects(mask, clause.anyof) {
        return false
    }

    // If exact, mask must equal requires exactly (no extra components)
    if exact && !mask_equals(mask, clause.requires) {
        return false
    }

    return true
}

// Create a filter with required, excluded and anyof components (single clause).
// Usage:
//   filter_create(&world, requires = {Position, Velocity})
//   filter_create(&world, requires = {Position}, excludes = {Poison})
//   filter_create(&world, requires = {Position, Size}, anyof = {Sprite, Text, Shape})
//   filter_create(&world, requires = {Position, Velocity}, exact = true)
filter_create :: proc(
    world: ^World,
    requires: []typeid = {},
    excludes: []typeid = {},
    anyof: []typeid = {},
    exact: bool = false,
) -> Filter {
    return Filter {
        clauses = {
            0 = {
                requires = mask_from_types(world, requires),
                excludes = mask_from_types(world, excludes),
                anyof = mask_from_types(world, anyof),
            },
        },
        clause_count = 1,
        exact = exact,
    }
}

// Create a filter requiring specified components
// Usage:
//   filter_contains(&world, {Position, Velocity})
filter_contains :: proc(world: ^World, types: []typeid) -> Filter {
    return filter_create(world, requires = types)
}

// Create filter from multiple clauses (OR between clauses)
// Usage:
//   filter_or(&world, {
//       {with = {A, B}},
//       {with = {C, D}},
//   })
filter_or :: proc(world: ^World, clause_descs: []Filter_Clause_Desc) -> Filter {
    f: Filter
    f.clause_count = u8(min(len(clause_descs), MAX_FILTER_CLAUSES))

    for i in 0 ..< f.clause_count {
        clause_desc := clause_descs[i]
        f.clauses[i] = Filter_Clause {
            requires = mask_from_types(world, clause_desc.requires),
            excludes = mask_from_types(world, clause_desc.excludes),
            anyof    = mask_from_types(world, clause_desc.anyof),
        }
    }

    return f
}

@(private = "file")
mask_from_types :: proc(world: ^World, types: []typeid) -> Component_Mask {
    mask: Component_Mask
    for type in types {
        comp_id, ok := world_get_component_id_dynamic(world, type)
        assert(ok, fmt.tprintf("Filtered component type '%v' is not registered.", type))
        mask_add(&mask, comp_id)
    }
    return mask
}

// FNV-1a hash of the filter for caching
filter_hash :: proc(f: Filter) -> u64 {
    h: u64 = 14695981039346656037
    prime: u64 : 1099511628211

    // Hash exact boolean
    h ~= u64(f.exact)
    h *= prime

    // Hash clauses
    for i in 0 ..< int(f.clause_count) {
        clause := f.clauses[i]
        
        h ~= mask_to_u64(clause.requires)
        h *= prime
        
        h ~= mask_to_u64(clause.excludes)
        h *= prime
        
        h ~= mask_to_u64(clause.anyof)
        h *= prime
    }
    return h
}