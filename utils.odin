package ash

import "core:fmt"

@(private)
format_bytes :: proc(bytes: int) -> string {
    @static buf: [32]byte
    
    if bytes < 1024 {
        return fmt.bprintf(buf[:], "%d B", bytes)
    } else if bytes < 1024 * 1024 {
        return fmt.bprintf(buf[:], "%.2f KB", f64(bytes) / 1024)
    } else {
        return fmt.bprintf(buf[:], "%.2f MB", f64(bytes) / (1024 * 1024))
    }
}