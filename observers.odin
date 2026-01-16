package ash

import "core:mem"
Observer_Handle   :: distinct u32
Observer_Callback :: #type proc(world: ^World, entity: Entity, user_data: rawptr)

Observer :: struct {
    handle:    Observer_Handle,
    callback:  Observer_Callback,
    user_data: rawptr,
}

Observer_Kind :: enum {
    Spawn,      // Spawn an entity
    Despawn,    // Despawn an entity
    Insert,     // Add a component to an entity
    Set,        // Set/Update a component value
    Remove      // Remove a component from an entity
}

Observer_Location :: struct {
    kind:           Observer_Kind,
    component_id:   Component_ID, // For Insert/Remove observers
    index:          int
}

Observers :: struct {
    allocator:      mem.Allocator,

    spawn:          [dynamic]Observer,
    despawn:        [dynamic]Observer,
    insert:         map[Component_ID][dynamic]Observer,
    set:            map[Component_ID][dynamic]Observer,
    remove:         map[Component_ID][dynamic]Observer,

    next_handle:    Observer_Handle,
    registry:       map[Observer_Handle]Observer_Location
}

observers_init :: proc(obs: ^Observers, allocator := context.allocator) {
    obs.allocator = allocator

    obs.spawn     = make([dynamic]Observer, allocator)
    obs.despawn   = make([dynamic]Observer, allocator)
    obs.insert    = make(map[Component_ID][dynamic]Observer, allocator)
    obs.set       = make(map[Component_ID][dynamic]Observer, allocator)
    obs.remove    = make(map[Component_ID][dynamic]Observer, allocator)

    obs.next_handle = 1
    obs.registry    = make(map[Observer_Handle]Observer_Location, allocator)
}

observers_destroy :: proc(obs: ^Observers) {
    delete(obs.spawn)
    delete(obs.despawn)

    for _, &list in obs.insert {
        delete(list)
    }
    delete(obs.insert)

    for _, &list in obs.set {
        delete(list)
    }
    delete(obs.set)

    for _, &list in obs.remove {
        delete(list)
    }
    delete(obs.remove)

    delete(obs.registry)
}

// ============================================================================
// REGISTRATION
// ============================================================================

observers_on_spawn :: proc(obs: ^Observers, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    observer := Observer{handle, callback, user_data}
    append(&obs.spawn, observer)
    
    obs.registry[handle] = Observer_Location{
        kind  = .Spawn,
        index = len(obs.spawn) - 1,
    }
    
    return handle
}

observers_on_despawn :: proc(obs: ^Observers, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    observer := Observer{handle, callback, user_data}
    append(&obs.despawn, observer)
    
    obs.registry[handle] = Observer_Location{
        kind  = .Despawn,
        index = len(obs.despawn) - 1,
    }
    
    return handle
}

observers_on_insert :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.insert {
        obs.insert[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.insert[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Insert,
        component_id = comp_id,
        index        = len(obs.insert[comp_id]) - 1,
    }
    
    return handle
}

observers_on_set :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.set {
        obs.set[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.set[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Set,
        component_id = comp_id,
        index        = len(obs.set[comp_id]) - 1,
    }
    
    return handle
}

observers_on_remove :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.remove {
        obs.remove[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.remove[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Remove,
        component_id = comp_id,
        index        = len(obs.remove[comp_id]) - 1,
    }
    
    return handle
}

// ============================================================================
// UNREGISTRATION
// ============================================================================

observers_unregister :: proc(obs: ^Observers, handle: Observer_Handle) {
    loc, ok := obs.registry[handle]
    if !ok {
        // Already unregistered or invalid handle
        return 
    }

    // Get the appropriate list
    list: ^[dynamic]Observer
    switch loc.kind {
    case .Spawn:
        list = &obs.spawn
    case .Despawn:
        list = &obs.despawn
    case .Insert:
        list = &obs.insert[loc.component_id]
    case .Set:
        list = &obs.set[loc.component_id]
    case .Remove:
        list = &obs.remove[loc.component_id]
    }
    
    // Swap-remove from list
    last_index := len(list) - 1
    
    if loc.index != last_index {
        // Move last element to this position
        list[loc.index] = list[last_index]
        
        // Update registry for the moved observer
        moved_handle := list[loc.index].handle
        if moved_loc, found := &obs.registry[moved_handle]; found {
            moved_loc.index = loc.index
        }
    }
    
    pop(list)
    
    // Remove from registry
    delete_key(&obs.registry, handle)
}

// ============================================================================
// NOTIFICATIONS
// ============================================================================

@(private)
observers_notify_spawn :: proc(obs: ^Observers, world: ^World, entity: Entity) {
    for &o in obs.spawn {
        o.callback(world, entity, o.user_data)
    }
}

@(private)
observers_notify_despawn :: proc(obs: ^Observers, world: ^World, entity: Entity) {
    for &o in obs.despawn {
        o.callback(world, entity, o.user_data)
    }
}

@(private)
observers_notify_insert :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.insert[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}

@(private)
observers_notify_set :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.set[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}

@(private)
observers_notify_remove :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.remove[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}