package pixel_app

Pixel :: struct {
    r, g, b, a: u8,
}

Clear_Pixel :: Pixel { 0, 0, 0, 0 }

Draw_Pixel :: proc(buf: []Pixel, x, y, w, h: int, p: Pixel) {
    if x < 0 || x >= w || y < 0 || y >= h do return
    idx := y * w + x
    if idx >= 0 && idx < len(buf) do buf[idx] = p
}

Fill_Rect :: proc(buf: []Pixel, x, y, w, h, rw, rh: int, p: Pixel) {
    for j in 0..<rh {
        for i in 0..<rw {
            Draw_Pixel(buf, x+i, y+j, w, h, p)
        }
    }
}

Render_Checkerboard :: proc(buf: []Pixel, w, h: int) {
    for j in 0..<h {
        for i in 0..<w {
            if (i/8 + j/8) % 2 == 0 {
                Draw_Pixel(buf, i, j, w, h, Pixel{80, 80, 80, 255})
            }
        }
    }
}
