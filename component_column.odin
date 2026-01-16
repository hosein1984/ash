package ash

import "core:slice"
import "core:mem"

Component_Column :: struct {
    data:      [dynamic]byte,
    count:     int,
    elem_size: int,
}

column_init :: proc(col: ^Component_Column, elem_size: int, allocator := context.allocator) {
    col.data      = make([dynamic]byte, allocator) 
    col.count     = 0
    col.elem_size = elem_size
}

column_destroy :: proc(col: ^Component_Column) {
    delete(col.data)
    col.count     = 0
    col.elem_size = 0
}

column_reserve :: proc(col: ^Component_Column, count: int) {
    reserve(&col.data, count * col.elem_size)
}

column_clear :: proc(col: ^Component_Column) {
    clear(&col.data)
    col.count = 0
}

column_len :: proc(col: ^Component_Column) -> int {
    return col.count
}

column_push :: proc {
    column_push_typed,
    column_push_raw,
}

column_push_typed :: proc(col: ^Component_Column, value: ^$T) {
    assert(size_of(T) == col.elem_size, "type size mismatch")
    bytes := mem.ptr_to_bytes(value)
    append(&col.data, ..bytes)
    col.count += 1
}

column_push_raw :: proc(col: ^Component_Column, value: rawptr) {
    bytes := slice.bytes_from_ptr(value, col.elem_size)
    append(&col.data, ..bytes)
    col.count += 1
}

// Push a zero-initialized element, returns index of new element
column_push_empty :: proc(col: ^Component_Column) -> int {
    idx       := col.count
    col.count += 1

    if col.elem_size == 0 {
        return idx  // Tags have no data
    }
    
    old_len := len(col.data)
    new_len := old_len + col.elem_size
    resize(&col.data, new_len)
    // resize zero-initializes new memory by default
    
    return idx
}

column_set :: proc {
    column_set_typed,
    column_set_raw,
}

column_set_typed :: proc(col: ^Component_Column, index: int, value: ^$T) {
    assert(size_of(T) == col.elem_size, "type size mismatch")
    assert(index >= 0 && index < column_len(col), "index out of bounds")
    if col.elem_size == 0 {
        return // Tags have no data
    }
    offset := col.elem_size * index
    mem.copy(raw_data(col.data[offset:]), value, col.elem_size)    
}

column_set_raw :: proc(col: ^Component_Column, index: int, value: rawptr) {
    assert(index >= 0 && index < column_len(col), "index out of bounds")
    if col.elem_size == 0 {
        return // Tags have no data
    }
    offset := col.elem_size * index
    mem.copy(raw_data(col.data[offset:]), value, col.elem_size)    
}

column_get :: proc {
    column_get_typed,
    column_get_raw,
}

column_get_typed :: proc(col: ^Component_Column, $T: typeid, index: int) -> ^T {
    assert(index >= 0 && index < column_len(col), "index out of bounds")
    offset := col.elem_size * index
    return (^T)(raw_data(col.data[offset:]))
}

column_get_raw :: proc(col: ^Component_Column, index: int) -> rawptr {
    assert(index >= 0 && index < column_len(col), "index out of bounds")
    offset := col.elem_size * index
    return raw_data(col.data[offset:])
}

column_get_slice :: proc(col: ^Component_Column, $T: typeid) -> []T {
    assert(size_of(T) == col.elem_size, "type size mismatch")
    if col.count == 0 || col.elem_size == 0 {
        return nil
    }
    return slice.reinterpret([]T, col.data[:])
}

// Remove element at index, swapping with last element
// Returns true if a swap occurred (i.e., removed element wasn't last)
column_swap_remove :: proc(col: ^Component_Column, index: int) -> bool {
    assert(index >= 0 && index < col.count, "index out of bounds")
    
    col.count -= 1

    if col.elem_size == 0 {
        return index != col.count // Would have swapped if not last
    }

    size     := col.elem_size
    last_idx := col.count
    swapped  := false

    if index != last_idx {
        dst := raw_data(col.data[index * size:]) 
        src := raw_data(col.data[last_idx * size:]) 
        mem.copy(dst, src, size)
        swapped = true
    }

    resize(&col.data, last_idx * size)
    return swapped
}

// Move element from src column to dst column
// The element is appended to dst and swap-removed from src
column_move :: proc(dst, src: ^Component_Column, src_idx: int) {
    assert(src.elem_size == dst.elem_size, "column sizes must match")

    if src.elem_size == 0 {
        // Tags have no data
        dst.count += 1
        src.count -= 1
        return 
    }

    src_ptr := column_get_raw(src, src_idx)
    column_push_raw(dst, src_ptr)
    column_swap_remove(src, src_idx)
}