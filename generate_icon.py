from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
draw = ImageDraw.Draw(img)

BG   = (15, 18, 24, 255)
CYAN = (0, 255, 224, 255)

# ── Fondo redondeado ──────────────────────────────────────────────────────────
def rounded_rect(draw, x0, y0, x1, y1, r, color):
    draw.rectangle([x0+r, y0, x1-r, y1], fill=color)
    draw.rectangle([x0, y0+r, x1, y1-r], fill=color)
    draw.ellipse([x0, y0, x0+2*r, y0+2*r], fill=color)
    draw.ellipse([x1-2*r, y0, x1, y0+2*r], fill=color)
    draw.ellipse([x0, y1-2*r, x0+2*r, y1], fill=color)
    draw.ellipse([x1-2*r, y1-2*r, x1, y1], fill=color)

rounded_rect(draw, 0, 0, SIZE, SIZE, 160, BG)

# ── Círculo (anillo doble) ────────────────────────────────────────────────────
cx, cy = 420, 400

# 1. Disco cian exterior
draw.ellipse([cx-370, cy-370, cx+370, cy+370], fill=CYAN)
# 2. Anillo oscuro (separador)
draw.ellipse([cx-335, cy-335, cx+335, cy+335], fill=BG)
# 3. Disco cian interior
draw.ellipse([cx-295, cy-295, cx+295, cy+295], fill=CYAN)

# ── Letra "P" dibujada como formas sólidas ────────────────────────────────────
# La P tiene: tallo vertical + bump semicircular en la mitad superior

# Tallo vertical (rectángulo oscuro sobre el cian)
stem_x = cx - 120
stem_y = cy - 230
stem_w = 75
stem_h = 460
draw.rectangle([stem_x, stem_y, stem_x + stem_w, stem_y + stem_h], fill=BG)

# Bump de la P: semicírculo derecho en la mitad superior
# Centro del bump alineado con el centro del tallo
bump_cx = stem_x + stem_w
bump_cy = stem_y + 130          # centro vertical del bump
bump_r_out = 145                # radio exterior del bump
bump_r_in  = 75                 # radio del hueco interior

# Semicírculo exterior (lado derecho solamente)
# Dibujamos el disco completo y luego tapamos la mitad izquierda
draw.ellipse([bump_cx - bump_r_out, bump_cy - bump_r_out,
              bump_cx + bump_r_out, bump_cy + bump_r_out], fill=BG)
# Tapar mitad izquierda del disco exterior
draw.rectangle([bump_cx - bump_r_out - 5, bump_cy - bump_r_out - 5,
                bump_cx, bump_cy + bump_r_out + 5], fill=CYAN)
# Hueco interior del bump
draw.ellipse([bump_cx - bump_r_in, bump_cy - bump_r_in,
              bump_cx + bump_r_in, bump_cy + bump_r_in], fill=CYAN)
# Tapar mitad izquierda del hueco (para que quede solo el lado derecho)
draw.rectangle([bump_cx - bump_r_in - 5, bump_cy - bump_r_in - 5,
                bump_cx, bump_cy + bump_r_in + 5], fill=BG)

# ── Carro (esquina inferior derecha) ─────────────────────────────────────────
# Vista frontal del carro, estilo flat icon como la referencia

car_cx = 720   # centro horizontal del carro
car_by = 950   # base del carro (y inferior)
car_w  = 320   # ancho total
car_h  = 200   # alto del cuerpo

bx = car_cx - car_w // 2
by = car_by - car_h

# Cuerpo principal (rectángulo redondeado)
rounded_rect(draw, bx, by, bx + car_w, car_by, 35, CYAN)

# Cabina (parte superior, más angosta)
cab_margin = 50
cab_h = 110
rounded_rect(draw, bx + cab_margin, by - cab_h, bx + car_w - cab_margin, by + 20, 25, CYAN)

# Ventana (hueco oscuro)
win_margin = 75
win_top = by - cab_h + 15
win_bot = by - 15
draw.rectangle([bx + win_margin, win_top, bx + car_w - win_margin, win_bot], fill=BG)

# Ruedas (círculos oscuros en la base)
wheel_r = 38
wheel_y = car_by - wheel_r + 5
draw.ellipse([bx + 25, wheel_y - wheel_r, bx + 25 + wheel_r*2, wheel_y + wheel_r], fill=BG)
draw.ellipse([bx + car_w - 25 - wheel_r*2, wheel_y - wheel_r,
              bx + car_w - 25, wheel_y + wheel_r], fill=BG)

# Faros (óvalos oscuros en la parte baja del cuerpo)
hl_w, hl_h = 55, 30
hl_y = by + 55
draw.ellipse([bx + 18, hl_y, bx + 18 + hl_w, hl_y + hl_h], fill=BG)
draw.ellipse([bx + car_w - 18 - hl_w, hl_y, bx + car_w - 18, hl_y + hl_h], fill=BG)

# ── Guardar ───────────────────────────────────────────────────────────────────
img.save("assets/icon/app_icon.png")
print("Icono generado.")
