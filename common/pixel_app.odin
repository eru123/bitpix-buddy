package pixel_app

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
