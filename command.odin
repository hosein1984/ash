package ash

Command_Kind :: enum {
	Spawn,
	Despawn,
	Set_Component,
	Remove_Component,
}

Command_Component :: struct {
	id:   Component_ID,
	data: rawptr,
	size: int,
}

Command :: struct {
	kind:       Command_Kind,
	entity:     Entity,
	component:  Component_ID, // Used in component removal
	components: []Command_Component, // Use when spawning entities or setting components
}
