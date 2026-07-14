package main

import "core:fmt"
import "core:os"
import "core:strings"
import "vendor:sdl2"

STATE_PATH :: "/tmp/bitpix-state.json"
BUDDY_PACK :: "/apps/bitpix-buddy/buddy-packs/default"

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
Apply_State :: proc(buf: []Pixel, w, h: int, action: string) {
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
    if err != nil || len(data) == 0 { return "idle" }
    text := string(data)
    for line in strings.split(text, "\n") {
        if strings.has_prefix(line, "action=") {
            return strings.trim_prefix(line, "action=")
        }
    }
    return "idle"
}

sdl_err :: proc(label: string) {
    e := sdl2.GetErrorString()
    if e != "" {
        fmt.println(label, e)
    }
}

main :: proc() {
    dispb := make([]u8, 256)
    disp := os.get_env_buf(dispb, "DISPLAY")
    fmt.println("DISPLAY: \"", disp, "\"")

    if sdl2.Init(sdl2.INIT_VIDEO) == 0 {
        fmt.println("SDL_Init VIDEO failed: ", sdl2.GetErrorString())
        return
    }
    defer sdl2.Quit()
    sdl_err("SDL err after init: ")

    w, h := 320, 200
    win := sdl2.CreateWindow(
        "BitPix Buddy",
        sdl2.WINDOWPOS_CENTERED,
        sdl2.WINDOWPOS_CENTERED,
        i32(w), i32(h),
        {.ALWAYS_ON_TOP, .BORDERLESS, .SHOWN},
    )
    sdl_err("SDL err after CreateWindow: ")
    if win == nil {
        fmt.println("CreateWindow failed")
        return
    }
    defer sdl2.DestroyWindow(win)

    renderer := sdl2.CreateRenderer(win, -1, {.ACCELERATED})
    sdl_err("SDL err after CreateRenderer: ")
    if renderer == nil {
        fmt.println("CreateRenderer failed")
        return
    }
    defer sdl2.DestroyRenderer(renderer)

    texture := sdl2.CreateTexture(renderer, sdl2.PixelFormatEnum.RGBA8888, sdl2.TextureAccess.STATIC, i32(w), i32(h))
    sdl_err("SDL err after CreateTexture: ")
    if texture == nil {
        fmt.println("CreateTexture failed")
        return
    }
    defer sdl2.DestroyTexture(texture)

    buf := make([]Pixel, w*h)
    out := make([]u32, w*h)
    Apply_State(buf, w, h, Read_State())
    for i := 0; i < len(buf); i += 1 {
        out[i] = u32(buf[i].a) << 24 | u32(buf[i].r) << 16 | u32(buf[i].g) << 8 | u32(buf[i].b)
    }
    sdl2.UpdateTexture(texture, nil, &out[0], i32(w*4))
    sdl_err("SDL err after UpdateTexture: ")

    fmt.println("entering event loop")
    running := true
    for running {
        ev := sdl2.Event{}
        for sdl2.PollEvent(&ev) {
            #partial switch ev.type {
            case .QUIT:       running = false
            case .KEYDOWN:    running = false
            case .WINDOWEVENT:
                wev := ev.window
                if wev.event == sdl2.WindowEventID.CLOSE { running = false }
            }
        }
        sdl2.RenderClear(renderer)
        sdl2.RenderCopy(renderer, texture, nil, nil)
        sdl2.RenderPresent(renderer)
        for i := 0; i < 16_000_000; i += 1 {}
    }
}
