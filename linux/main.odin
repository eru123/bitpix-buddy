package main

import "core:fmt"
import "core:os"
import "core:strings"
import "core:time"
import "vendor:x11/xlib"

STATE_PATH :: "/tmp/bitpix-state.json"
BUDDY_PACK :: "/apps/bitpix-buddy/buddy-packs/default"

w, h := 320, 200

Pixel :: struct {
    r, g, b, a: u8,
}

Draw_Pixel :: proc(buf: []Pixel, x, y, w, h: int, p: Pixel) {
    if x < 0 || x >= w || y < 0 || y >= h do return
    i := y * w + x
    if i >= 0 && i < len(buf) do buf[i] = p
}

Fill_Rect :: proc(buf: []Pixel, x, y, rw, rh, bw, bh: int, p: Pixel) {
    for j := y; j < y + rh && j < bh; j += 1 {
        for i := x; i < x + rw && i < bw; i += 1 {
            Draw_Pixel(buf, i, j, bw, bh, p)
        }
    }
}

Checkerboard :: proc(buf: []Pixel, w, h: int) {
    for j := 0; j < h; j += 1 {
        for i := 0; i < w; i += 1 {
            if ((i / 8) + (j / 8)) % 2 == 0 {
                Draw_Pixel(buf, i, j, w, h, Pixel{80, 80, 80, 255})
            }
        }
    }
}

Apply_State :: proc(buf: []Pixel, action: string) {
    switch action {
    case "idle":
        Checkerboard(buf, w, h)
        Fill_Rect(buf, 20, 20, 60, 60, w, h, Pixel{0, 0xcc, 0, 255})
    case "working":
        Checkerboard(buf, w, h)
        Fill_Rect(buf, 20, 20, 120, 60, w, h, Pixel{0, 0x66, 0xff, 255})
    case "error":
        Checkerboard(buf, w, h)
        Fill_Rect(buf, 20, 20, 160, 60, w, h, Pixel{0xff, 0, 0, 255})
    case "deploying":
        Checkerboard(buf, w, h)
        Fill_Rect(buf, 20, 20, 200, 60, w, h, Pixel{0xff, 0xaa, 0, 255})
    case:
        Checkerboard(buf, w, h)
    }
}

Read_State :: proc() -> string {
    data, err := os.read_entire_file_from_path(STATE_PATH, context.allocator)
    if err != nil || len(data) == 0 do return "idle"
    text := string(data)
    for line in strings.split(text, "\n") {
        if strings.has_prefix(line, "action=") {
            return strings.trim_prefix(line, "action=")
        }
    }
    return "idle"
}

main :: proc() {
    action := Read_State()
    fmt.println("BitPix action:", action)

    dpy := xlib.OpenDisplay(nil)
    if dpy == nil {
        fmt.println("OpenDisplay failed")
        return
    }
    defer xlib.CloseDisplay(dpy)

    screen := xlib.DefaultScreen(dpy)
    root := xlib.RootWindow(dpy, screen)
    black := xlib.BlackPixel(dpy, screen)
    white := xlib.WhitePixel(dpy, screen)
    gc := xlib.DefaultGC(dpy, screen)

    win := xlib.CreateSimpleWindow(dpy, root, 100, 100, 320, 200, 2, black, white)
    if win == 0 {
        fmt.println("CreateSimpleWindow failed")
        return
    }
    defer xlib.DestroyWindow(dpy, win)

    xlib.StoreName(dpy, win, "BitPix Buddy")
    xlib.SelectInput(dpy, win, xlib.EventMask{.ButtonPress, .KeyPress, .Exposure, .StructureNotify})
    xlib.MapRaised(dpy, win)

    buf := make([]Pixel, w * h)
    Apply_State(buf, action)

    for y := 0; y < h; y += 1 {
        for x := 0; x < w; x += 1 {
            p := buf[y * w + x]
            xlib.SetForeground(dpy, gc, uint(u32(p.r) << 16 | u32(p.g) << 8 | u32(p.b)))
            xlib.DrawPoint(dpy, win, gc, i32(x), i32(y))
        }
    }
    xlib.Flush(dpy)

    fmt.println("BitPix visible")
    for {
        ev := xlib.XEvent{}
        if xlib.Pending(dpy) > 0 {
            xlib.NextEvent(dpy, &ev)
        }
    }
}
