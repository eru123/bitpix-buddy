package main
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:x11/xlib"

STATE_PATH := "/tmp/bitpix-state.json"

BuddyConfig :: struct { base_w, base_h, min_w, min_h, max_w, max_h: int, bg: uint }
config := BuddyConfig{320, 200, 96, 60, 960, 600, 0x00cc00}

dragging := false
last_rx, last_ry, win_x, win_y: i32

apply_scale :: proc(base_w, base_h, new_scale: int) -> (int, int, int) {
    s := new_scale
    if s < 1 { s = 1 }
    if s > 8 { s = 8 }
    w := base_w * s
    h := base_h * s
    if w < config.min_w { w = config.min_w }
    if h < config.min_h { h = config.min_h }
    if w > config.max_w { w = config.max_w; s = w / base_w }
    if h > config.max_h { h = config.max_h; s = h / base_h }
    return w, h, s
}

Read_State :: proc() -> string {
    data, err := os.read_entire_file_from_path(STATE_PATH, context.allocator)
    if err != nil || len(data) == 0 do return "idle"
    for line in strings.split(string(data), "\n") {
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
    if dpy == nil { fmt.println("OpenDisplay failed"); return }
    defer xlib.CloseDisplay(dpy)

    screen := xlib.DefaultScreen(dpy)
    root := xlib.RootWindow(dpy, screen)
    black := xlib.BlackPixel(dpy, screen)
    white := xlib.WhitePixel(dpy, screen)
    gc := xlib.DefaultGC(dpy, screen)

    sw := xlib.DisplayWidth(dpy, screen)
    sh := xlib.DisplayHeight(dpy, screen)
    bw, bh, _ := apply_scale(config.base_w, config.base_h, 1)
    win_x = (sw - i32(bw)) / 2
    win_y = (sh - i32(bh)) / 2
    win := xlib.CreateSimpleWindow(dpy, root, win_x, win_y, u32(bw), u32(bh), 0, black, white)
    if win == 0 { fmt.println("CreateSimpleWindow failed"); return }
    defer xlib.DestroyWindow(dpy, win)

    atom := xlib.InternAtom(dpy, "WM_DELETE_WINDOW", true)
    xlib.SetWMProtocols(dpy, win, &atom, 1)
    xlib.StoreName(dpy, win, "BitPix Buddy")
    attrs := xlib.XSetWindowAttributes{override_redirect = true}
    xlib.ChangeWindowAttributes(dpy, win, xlib.WindowAttributeMask{.CWOverrideRedirect}, &attrs)
    xlib.SelectInput(dpy, win, xlib.EventMask{.ButtonPress, .ButtonRelease, .Button1Motion, .Exposure, .StructureNotify, .KeyPress})
    xlib.MapRaised(dpy, win)

    xlib.SetForeground(dpy, gc, config.bg)
    xlib.FillRectangle(dpy, win, gc, 0, 0, u32(bw), u32(bh))
    xlib.Flush(dpy)

    fmt.println("BitPix visible")
    for {
        ev := xlib.XEvent{}
        if xlib.Pending(dpy) > 0 {
            xlib.NextEvent(dpy, &ev)
            if ev.type == xlib.EventType.ClientMessage || ev.type == xlib.EventType.DestroyNotify { break }

            if ev.type == xlib.EventType.KeyPress {
                xe := &ev.xkey
                if xe.keycode == 113 {
                    nw, nh, ns := apply_scale(config.base_w, config.base_h, 2)
                    xlib.ResizeWindow(dpy, win, u32(nw), u32(nh))
                    xlib.SetForeground(dpy, gc, config.bg)
                    xlib.FillRectangle(dpy, win, gc, 0, 0, u32(nw), u32(nh))
                    xlib.Flush(dpy)
                }
                if xe.keycode == 111 {
                    nw, nh, ns := apply_scale(config.base_w, config.base_h, 1)
                    xlib.ResizeWindow(dpy, win, u32(nw), u32(nh))
                    xlib.SetForeground(dpy, gc, config.bg)
                    xlib.FillRectangle(dpy, win, gc, 0, 0, u32(nw), u32(nh))
                    xlib.Flush(dpy)
                }
            }

            if ev.type == xlib.EventType.ButtonPress {
                xe := &ev.xbutton
                if xe.button == xlib.MouseButton(1) {
                    dragging = true
                    last_rx = xe.x_root
                    last_ry = xe.y_root
                    xlib.GrabPointer(dpy, win, true, xlib.EventMask{.ButtonRelease, .Button1Motion},
                        xlib.GrabMode.GrabModeAsync, xlib.GrabMode.GrabModeAsync, 0, 0, xlib.CurrentTime)
                }
            }
            if ev.type == xlib.EventType.ButtonRelease {
                dragging = false
                xlib.UngrabPointer(dpy, xlib.CurrentTime)
            }
            if ev.type == xlib.EventType.MotionNotify {
                xe := &ev.xmotion
                win_x += xe.x_root - last_rx
                win_y += xe.y_root - last_ry
                last_rx = xe.x_root
                last_ry = xe.y_root
                xlib.MoveWindow(dpy, win, win_x, win_y)
                xlib.Flush(dpy)
            }
        }
    }
}
