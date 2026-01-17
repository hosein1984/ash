package tests

import ".."

// odinfmt: disable
Position :: struct { x, y: f32 }
Velocity :: struct { vx, vy: f32 }
Size     :: struct { w, h: f32 }
Sprite   :: struct { id: u32 }
Text     :: struct { s: string }
Shape    :: struct { kind: u8 }
Health   :: struct { hp: i32 }
Poison   :: struct {}
Child_Of :: struct { parent: ash.Entity}
Target   :: struct { entity: ash.Entity}
Tag      :: struct {}
A        :: struct {}
B        :: struct {}
C        :: struct {}
D        :: struct {}

Small    :: struct { a: u8 }
Medium   :: struct { b: i32 }
Large    :: struct { c: f64 }
// odinfmt: enable