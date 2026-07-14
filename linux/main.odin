package main

import "core:fmt"
import "vendor:sdl2"

Pixel :: struct {
    r, g, b, a: u8,
}

Draw_Pixel :: proc(buf: []Pixel, x, y, w, h: int, p: Pixel) {
    if x < 0 || x >= w || y < 0 || y >= h do return
    idx := y * w + x
    if idx >= 0 && idx < len(buf) do buf[idx] = p
}

Fill_Rect :: proc(buf: []Pixel, x, y, rw, rh, bw, bh: int, p: Pixel) {
    for j := y; j < y + rh && j < bh; j += 1 {
        for i := x; i < x + rw && i < bw; i += 1 {
            Draw_Pixel(buf, i, j, bw, bh, p)
        }
    }
}

Render_Checkerboard :: proc(buf: []Pixel, w, h: int) {
    for j := 0; j < h; j += 1 {
        for i := 0; i < w; i += 1 {
            if ((i / 8) + (j / 8)) % 2 == 0 {
                Draw_Pixel(buf, i, j, w, h, Pixel{80, 80, 80, 255})
            }
        }
    }
}

main :: proc() {
    if sdl2.Init(sdl2.INIT_VIDEO) == 0 {
        fmt.println("SDL2 init failed: ", sdl2.GetErrorString())
        return
    }
    defer sdl2.Quit()

    w, h := 320, 200
    win := sdl2.CreateWindow(
        "Pixel App",
        sdl2.WINDOWPOS_CENTERED,
        sdl2.WINDOWPOS_CENTERED,
        i32(w), i32(h),
        {.ALWAYS_ON_TOP, .BORDERLESS},
    )
    if win == nil {
        fmt.println("CreateWindow failed")
        return
    }
    defer sdl2.DestroyWindow(win)

    renderer := sdl2.CreateRenderer(win, -1, {.ACCELERATED})
    if renderer == nil {
        fmt.println("CreateRenderer failed: ", sdl2.GetErrorString())
        return
    }
    defer sdl2.DestroyRenderer(renderer)

    texture := sdl2.CreateTexture(renderer, sdl2.PixelFormatEnum.RGBA8888, sdl2.TextureAccess.STATIC, i32(w), i32(h))
    if texture == nil {
        fmt.println("CreateTexture failed: ", sdl2.GetErrorString())
        return
    }
    defer sdl2.DestroyTexture(texture)

    buf := make([]Pixel, w * h)
    Render_Checkerboard(buf, w, h)
    Fill_Rect(buf, 20, 20, 280, 160, w, h, Pixel{0xFF, 0xEE, 0xEE, 255})

    pixels32 := make([]u32, w * h)
    for i := 0; i < len(buf); i += 1 {
        pixels32[i] = u32(buf[i].a) << 24 | u32(buf[i].r) << 16 | u32(buf[i].g) << 8 | u32(buf[i].b)
    }

    sdl2.UpdateTexture(texture, nil, &pixels32[0], i32(w * 4))

    running := true
    for running {
        ev := sdl2.Event{}
        for sdl2.PollEvent(&ev) {
            #partial switch ev.type {
            case .QUIT:       running = false
            case .KEYDOWN:    running = false
            case .WINDOWEVENT:
                wev := ev.window
                if wev.event == sdl2.WindowEventID.CLOSE {
                    running = false
                }
            }
        }

        sdl2.SetRenderDrawColor(renderer, 0, 0, 0, 0)
        sdl2.RenderClear(renderer)
        sdl2.RenderCopy(renderer, texture, nil, nil)
        sdl2.RenderPresent(renderer)
    }

    fmt.println("exit")
}
