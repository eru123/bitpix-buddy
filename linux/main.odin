package main
import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:x11/xlib"

STATE_PATH := "/tmp/bitpix-state.json"

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

    bw, bh := 160, 160
    win := xlib.CreateSimpleWindow(dpy, root, 40, 40, u32(bw), u32(bh), 3, black, white)
    if win == 0 {
        fmt.println("CreateSimpleWindow failed")
        return
    }
    defer xlib.DestroyWindow(dpy, win)

    xlib.StoreName(dpy, win, "BitPix Buddy")

    attrs := xlib.XSetWindowAttributes{override_redirect = true}
    xlib.ChangeWindowAttributes(dpy, win, xlib.WindowAttributeMask{.CWOverrideRedirect}, &attrs)

    xlib.SelectInput(dpy, win, xlib.EventMask{.ButtonPress, .KeyPress, .Exposure, .StructureNotify})
    xlib.MapRaised(dpy, win)

    color := uint(0x00cc00)
    if action == "working" { color = 0x3366ff }
    if action == "error"   { color = 0xff0033 }
    if action == "deploying" { color = 0xff7700 }

    xlib.SetForeground(dpy, gc, color)
    xlib.FillRectangle(dpy, win, gc, 0, 0, u32(bw), u32(bh))
    xlib.Flush(dpy)

    fmt.println("BitPix visible")
    for {
        ev := xlib.XEvent{}
        if xlib.Pending(dpy) > 0 {
            xlib.NextEvent(dpy, &ev)
            if ev.type == xlib.EventType.KeyPress || ev.type == xlib.EventType.ClientMessage || ev.type == xlib.EventType.DestroyNotify {
                break
            }
        }
    }
}
