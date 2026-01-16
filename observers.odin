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
    Spawn,   // Entity created (after all initial components added)
    Despawn, // Entity destroyed (before removal, components still accessible)
    Add,     // Component added to entity (first time this component type)
    Update,  // Component value updated (entity already had this component)
    Remove,  // Component removed from entity (before removal, value still accessible)
}

Observer_Location :: struct {
    kind:           Observer_Kind,
    component_id:   Component_ID, // For Insert/Remove observers
    index:          int
}

Observers :: struct {
    allocator:          mem.Allocator,

    spawn_observers:    [dynamic]Observer,
    despawn_observers:  [dynamic]Observer,
    add_observers:      map[Component_ID][dynamic]Observer,
    update_observers:   map[Component_ID][dynamic]Observer,
    remove_observers:   map[Component_ID][dynamic]Observer,

    next_handle:        Observer_Handle,
    registry:           map[Observer_Handle]Observer_Location
}

observers_init :: proc(obs: ^Observers, allocator := context.allocator) {
    obs.allocator = allocator

    obs.spawn_observers     = make([dynamic]Observer, allocator)
    obs.despawn_observers   = make([dynamic]Observer, allocator)
    obs.add_observers       = make(map[Component_ID][dynamic]Observer, allocator)
    obs.update_observers    = make(map[Component_ID][dynamic]Observer, allocator)
    obs.remove_observers    = make(map[Component_ID][dynamic]Observer, allocator)

    obs.next_handle = 1
    obs.registry    = make(map[Observer_Handle]Observer_Location, allocator)
}

observers_destroy :: proc(obs: ^Observers) {
    delete(obs.spawn_observers)
    delete(obs.despawn_observers)

    for _, &list in obs.add_observers {
        delete(list)
    }
    delete(obs.add_observers)

    for _, &list in obs.update_observers {
        delete(list)
    }
    delete(obs.update_observers)

    for _, &list in obs.remove_observers {
        delete(list)
    }
    delete(obs.remove_observers)

    delete(obs.registry)
}

// ============================================================================
// REGISTRATION
// ============================================================================

observers_on_spawn :: proc(obs: ^Observers, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    observer := Observer{handle, callback, user_data}
    append(&obs.spawn_observers, observer)
    
    obs.registry[handle] = Observer_Location{
        kind  = .Spawn,
        index = len(obs.spawn_observers) - 1,
    }
    
    return handle
}

observers_on_despawn :: proc(obs: ^Observers, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    observer := Observer{handle, callback, user_data}
    append(&obs.despawn_observers, observer)
    
    obs.registry[handle] = Observer_Location{
        kind  = .Despawn,
        index = len(obs.despawn_observers) - 1,
    }
    
    return handle
}

observers_on_add :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.add_observers {
        obs.add_observers[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.add_observers[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Add,
        component_id = comp_id,
        index        = len(obs.add_observers[comp_id]) - 1,
    }
    
    return handle
}

observers_on_update :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.update_observers {
        obs.update_observers[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.update_observers[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Update,
        component_id = comp_id,
        index        = len(obs.update_observers[comp_id]) - 1,
    }
    
    return handle
}

observers_on_remove :: proc(obs: ^Observers, comp_id: Component_ID, callback: Observer_Callback, user_data: rawptr = nil) -> Observer_Handle {
    handle := obs.next_handle
    obs.next_handle += 1
    
    // Ensure dynamic array exists for this component
    if comp_id not_in obs.remove_observers {
        obs.remove_observers[comp_id] = make([dynamic]Observer, obs.allocator)
    }
    
    observer := Observer{handle, callback, user_data}
    append(&obs.remove_observers[comp_id], observer)
    
    obs.registry[handle] = Observer_Location{
        kind         = .Remove,
        component_id = comp_id,
        index        = len(obs.remove_observers[comp_id]) - 1,
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
        list = &obs.spawn_observers
    case .Despawn:
        list = &obs.despawn_observers
    case .Add:
        list = &obs.add_observers[loc.component_id]
    case .Update:
        list = &obs.update_observers[loc.component_id]
    case .Remove:
        list = &obs.remove_observers[loc.component_id]
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
    for &o in obs.spawn_observers {
        o.callback(world, entity, o.user_data)
    }
}

@(private)
observers_notify_despawn :: proc(obs: ^Observers, world: ^World, entity: Entity) {
    for &o in obs.despawn_observers {
        o.callback(world, entity, o.user_data)
    }
}

@(private)
observers_notify_add :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.add_observers[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}

@(private)
observers_notify_update :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.update_observers[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}

@(private)
observers_notify_remove :: proc(obs: ^Observers, world: ^World, entity: Entity, comp_id: Component_ID) {
    if list, ok := &obs.remove_observers[comp_id]; ok {
        for &o in list {
            o.callback(world, entity, o.user_data)
        }
    }
}