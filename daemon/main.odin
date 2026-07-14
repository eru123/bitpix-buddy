package main

import "core:fmt"
import "core:os"
import "core:io"

STATE_PATH :: "/tmp/bitpix-state.json"

write_state :: proc(action: string) {
    s := fmt.tprintf("action=%s\nupdated_at=%d\n", action, os.now_unix())
    f, _ := os.open(STATE_PATH, .WRITE, .CREATE, .TRUNCATE)
    if f != os.INVALID_HANDLE {
        io.write(f, s)
        os.close(f)
    }
}

read_state :: proc() -> (action: string, ok: bool) {
    data, err := os.read_entire_file(STATE_PATH)
    if err != nil || len(data) == 0 {
        return "idle", false
    }
    text := string(data)
    for line in io.split_lines(text) {
        parts := io.split(line, '=')
        if len(parts) >= 2 && parts[0] == "action" {
            return parts[1], true
        }
    }
    return "idle", false
}

usage :: proc() {
    fmt.println("Usage: bitpix-daemon <action>")
    fmt.println("Actions: idle, working, error, deploying")
}

main :: proc() {
    args := os.args[1:]
    if len(args) == 0 {
        usage()
        current, _ := read_state()
        fmt.println("current: ", current)
        return
    }

    action := args[0]
    valid := []string{"idle", "working", "error", "deploying"}
    ok := false
    for a in valid {
        if a == action {
            ok = true
            break
        }
    }
    if !ok {
        fmt.println("Unknown action: ", action)
        usage()
        return
    }

    write_state(action)
    fmt.println("state -> ", action)
}
