package ash

Component_ID :: distinct u16

// Represents information needed for getting and setting a component.
Component_Info :: struct {
	id:      Component_ID,
	size:    int,
	align:   int,
	type_id: typeid,
}

// Represents a registry for all game components.
Component_Registry :: struct {
	infos:      [dynamic]Component_Info,
	type_to_id: map[typeid]Component_ID,
}

registry_init :: proc(reg: ^Component_Registry, allocator := context.allocator) {
	reg.infos = make([dynamic]Component_Info, allocator)
	reg.type_to_id = make(map[typeid]Component_ID, allocator)
}

registry_destroy :: proc(reg: ^Component_Registry) {
	delete(reg.infos)
	delete(reg.type_to_id)
}

registry_register :: proc(reg: ^Component_Registry, $T: typeid) -> Component_ID {
	if existing_id, ok := reg.type_to_id[T]; ok {
		return existing_id
	}

	comp_id := Component_ID(len(reg.infos))
	comp_info := Component_Info {
		id      = comp_id,
		size    = size_of(T),
		align   = align_of(T),
		type_id = T,
	}
	append(&reg.infos, comp_info)
	reg.type_to_id[T] = comp_id

	return comp_id
}

registry_register_dynamic :: proc(reg: ^Component_Registry, type: typeid) -> Component_ID {
	if existing_id, ok := reg.type_to_id[type]; ok {
		return existing_id
	}

	comp_id := Component_ID(len(reg.infos))
	comp_info := Component_Info {
		id      = comp_id,
		size    = size_of(type),
		align   = align_of(type),
		type_id = type,
	}
	append(&reg.infos, comp_info)
	reg.type_to_id[type] = comp_id

	return comp_id
}

registry_get_id :: #force_inline proc(reg: ^Component_Registry, $T: typeid) -> (Component_ID, bool) {
	id, ok := reg.type_to_id[T]
	return id, ok
}

registry_get_id_dynamic :: #force_inline proc(reg: ^Component_Registry, type: typeid) -> (Component_ID, bool) {
	id, ok := reg.type_to_id[type]
	return id, ok
}

registry_get_info :: #force_inline proc( reg: ^Component_Registry, id: Component_ID, ) -> ( ^Component_Info, bool, ) #optional_ok {
	index := int(id)
	if index < 0 || index >= len(reg.infos) {
		return nil, false
	}
	return &reg.infos[id], true
}