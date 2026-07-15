package main

import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:x11/xlib"

STATE_PATH := "/tmp/bitpix-state.json"
FRAME_PATH := "/apps/bitpix-buddy/buddy-packs/default/frames.bin"

BuddyConfig :: struct { base_w, base_h, min_w, min_h, max_w, max_h: int }
config  := BuddyConfig{320, 200, 96, 60, 960, 600}
SPRITE_W :: 12
SPRITE_H :: 16
FRAME_COUNT :: 4
Frame    :: []u8
TRANSPARENT: u32 = 0

dragging := false
last_rx, last_ry, win_x, win_y: i32
mul := 1
current_state := "idle"
frame_idx := 0
frame_tick := 0
frames := [FRAME_COUNT]Frame{}
raw_buf := []u8{}
last_action_buf := []u8{}

Read_State :: proc() -> string {
    if len(last_action_buf) > 0 {
        return string(last_action_buf)
    }
    return "idle"
}

Cache_State :: proc() {
    data, err := os.read_entire_file_from_path(STATE_PATH, context.allocator)
    defer os.free(data)
    if err != nil || len(data) == 0 {
        return
    }
    for line in strings.split(string(data), "\n") {
        if strings.has_prefix(line, "action=") {
            v := strings.trim_prefix(line, "action=")
            last_action_buf = make([]byte, len(v))
            copy(last_action_buf, []byte(v))
            break
        }
    }
}

Load_Frames :: proc() {
    raw, err := os.read_entire_file_from_path(FRAME_PATH, context.allocator)
    defer os.free(raw)
    if err != nil || len(raw) < 768*FRAME_COUNT {
        fmt.println("load frames failed:", err, "bytes:", len(raw))
        return
    }
    raw_buf = make([]u8, len(raw))
    copy(raw_buf, raw)
    stride := 768
    for i in 0..<FRAME_COUNT {
        frames[i] = raw_buf[i*stride:(i+1)*stride]
    }
    fmt.println("loaded frames count:", FRAME_COUNT)
}

Color_At :: proc(f: Frame, y, x: int) -> u32 {
    if len(f) == 0 {
        return TRANSPARENT
    }
    i := (y*SPRITE_W + x) * 4
    if i+3 >= len(f) {
        return TRANSPARENT
    }
    a := f[i+3]
    if a < 128 {
        return TRANSPARENT
    }
    r := u32(f[i])
    g := u32(f[i+1])
    b := u32(f[i+2])
    return (r << 16) | (g << 8) | b
}

Draw_Sprite :: proc(dpy: ^xlib.Display, win: xlib.Window, gc: xlib.GC, f: Frame, x: i32, y: i32, mul: int) {
    if mul < 1 || len(f) == 0 { return }
    for sy in 0..<SPRITE_H {
        for sx in 0..<SPRITE_W {
            c := Color_At(f, sy, sx)
            if c != TRANSPARENT {
                xlib.SetForeground(dpy, gc, uint(c))
                xlib.FillRectangle(dpy, win, gc,
                    i32(sx*mul), i32(sy*mul),
                    u32(mul), u32(mul))
            }
        }
    }
}

main :: proc() {
    dpy := xlib.OpenDisplay(nil)
    if dpy == nil { fmt.println("OpenDisplay failed"); return }
    defer xlib.CloseDisplay(dpy)

    screen := xlib.DefaultScreen(dpy)
    root   := xlib.RootWindow(dpy, screen)
    black  := xlib.BlackPixel(dpy, screen)
    white  := xlib.WhitePixel(dpy, screen)
    gc     := xlib.DefaultGC(dpy, screen)

    sw := xlib.DisplayWidth(dpy, screen)
    sh := xlib.DisplayHeight(dpy, screen)
    mul = (config.base_w - 16) / SPRITE_W
    if mul < 1 { mul = 1 }
    if mul > 12 { mul = 12 }
    w := SPRITE_W * mul
    h := SPRITE_H * mul
    win_x = i32((int(sw) - w) / 2)
    win_y = i32((int(sh) - h) / 2)
    win := xlib.CreateSimpleWindow(dpy, root,
        win_x, win_y,
        u32(w), u32(h),
        0, black, white)
    if win == 0 { fmt.println("CreateSimpleWindow failed"); return }
    defer xlib.DestroyWindow(dpy, win)

    bga := xlib.XSetWindowAttributes{background_pixel = 0x00cc00}
    xlib.ChangeWindowAttributes(dpy, win,
        xlib.WindowAttributeMask{.CWBackPixel}, &bga)
    attrs := xlib.XSetWindowAttributes{override_redirect = true}
    xlib.ChangeWindowAttributes(dpy, win,
        xlib.WindowAttributeMask{.CWOverrideRedirect}, &attrs)
    xlib.SelectInput(dpy, win,
        xlib.EventMask{
            .ButtonPress, .ButtonRelease,
            .Button1Motion, .Exposure,
            .StructureNotify, .KeyPress,
        },
    )
    xlib.MapRaised(dpy, win)

    Load_Frames()
    Cache_State()
    fmt.println("BitPix visible")

    state := Read_State()
    frame_idx = 0
    frame_tick = 0
    cancel := false
    for !cancel {
        ev := xlib.XEvent{}
        if xlib.Pending(dpy) > 0 {
            xlib.NextEvent(dpy, &ev)
            if ev.type == xlib.EventType.ClientMessage ||
               ev.type == xlib.EventType.DestroyNotify {
                break
            }
            if ev.type == xlib.EventType.KeyPress {
                xe := &ev.xkey
                if xe.keycode == 113 && mul < 16 {
                    mul += 1
                    xlib.ResizeWindow(dpy, win, u32(SPRITE_W*mul), u32(SPRITE_H*mul))
                    Draw_Sprite(dpy, win, gc, frames[frame_idx % FRAME_COUNT], 0, 0, mul)
                    xlib.Flush(dpy)
                }
                if xe.keycode == 111 && mul > 1 {
                    mul -= 1
                    xlib.ResizeWindow(dpy, win, u32(SPRITE_W*mul), u32(SPRITE_H*mul))
                    Draw_Sprite(dpy, win, gc, frames[frame_idx % FRAME_COUNT], 0, 0, mul)
                    xlib.Flush(dpy)
                }
            }
            if ev.type == xlib.EventType.ButtonPress {
                xe := &ev.xbutton
                if xe.button == xlib.MouseButton(1) {
                    dragging = true
                    last_rx = xe.x_root
                    last_ry = xe.y_root
                    xlib.GrabPointer(dpy, win, true,
                        xlib.EventMask{.ButtonRelease, .Button1Motion},
                        xlib.GrabMode.GrabModeAsync,
                        xlib.GrabMode.GrabModeAsync,
                        0, 0, xlib.CurrentTime)
                }
            }
            if ev.type == xlib.EventType.ButtonRelease {
                dragging = false
                xlib.UngrabPointer(dpy, xlib.CurrentTime)
            }
            if ev.type == xlib.EventType.MotionNotify {
                xe := &ev.xbutton
                win_x += xe.x_root - last_rx
                win_y += xe.y_root - last_ry
                last_rx = xe.x_root
                last_ry = xe.y_root
                xlib.MoveWindow(dpy, win, win_x, win_y)
                xlib.Flush(dpy)
            }
        }

        Cache_State()
        new_state := Read_State()
        if new_state != state {
            state = new_state
            frame_idx = 0
            frame_tick = 0
        }

        frame_tick += 1
        if frame_tick >= 24 {
            frame_tick = 0
            show := frame_idx % FRAME_COUNT
            if state == "working" {
                show = 2
            } else if state == "error" {
                show = 3
            }
            Draw_Sprite(dpy, win, gc, frames[show], 0, 0, mul)
            xlib.Flush(dpy)
            frame_idx += 1
        }
    }
}
