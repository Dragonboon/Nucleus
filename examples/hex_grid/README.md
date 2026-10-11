# Hex Grid 3D Lab

Open `res://examples/hex_grid/hex_grid_lab.tscn` and run **F6**. This lab is independent of the existing Placement3D Lab and does not change its behavior or project startup.

| Input | Action |
|---|---|
| `P` and left click/drag | Paint hexagonal cells on the ghost grid |
| `X` and left click/drag | Erase a cell (dragging eraser is not yet enabled) |
| `M`, then two left clicks | Choose an occupied cell, then move it to a vacant cell |
| `I` and left click | Select a painted hexagon |
| `Q` / `R` | Rotate selected tile by ±60° |
| `Supr` | Erase selected tile |
| `Esc` | Cancel a pending move / clear selection |
| `[` / `]` | Rotate the **whole board** by ±60° |
| Arrow keys | Move the whole board |
| `Page Up` / `Page Down` | Select elevation layer |
| Right mouse drag / mouse wheel | Orbit camera / zoom |
| Left-hand panel | Change cell radius, grid rings, tile height, layer step, active layer, grid origin, visibility |

**Vertex connection experiment:** paint two neighboring tiles (for example the center then the cell immediately east). The event panel shows two `CONNECT` messages, because neighboring regular hexagons share two corners. Erase one and observe two `DISCONNECT` messages. Paint another tile one layer higher: it must not connect with the lower tiles.

**Grid transforms:** paint a few cells, move the board with arrow keys, and rotate it with `[ ]`. Painting should still land in the intended axial cell. Change cell radius or height: painted cells should keep their integer addresses, changing only spacing/geometry.

**Headless smoke:** `godot --headless --path . --script res://examples/hex_grid/hex_grid_smoke.gd`.

The reference ground is **visual only**, so the demo intentionally doesn't claim valid gameplay collisions. See [Hex Grid contract](../../docs/components/hex_grid_3d.md) for the boundary with physical Runtime Placement3D.

## Selección y orientación individual (parche)

- `I` y clic sobre un tile, o **Mayús + clic** desde cualquier herramienta,
  selecciona una pieza sin pintar nada nuevo. Su superficie se vuelve amarilla.
- `Q`/`R` o los botones **Rotar pieza seleccionada −60° / +60°** modifican
  exclusivamente esa pieza; el resto del tablero permanece inmóvil.
- El indicador de dirección **es una flecha oscura visible solo en la selección**
  (desactivable con el checkbox). La anterior cuña anaranjada que aparecía
  sobre todos los hexágonos era simplemente un marcador de orientación.
- `[`/`]` y los botones **Girar grid 60°** siguen rotando el tablero entero.
- La geometría del tile es hexagonalmente simétrica. Por eso, el giro se ve
  claramente mediante la flecha, aunque el contorno no cambie.

### Suite headless

El manifiesto de Nucleus debe encontrar el archivo físico
`res://tests/headless/hex_grid_3d_test.gd`. El overlay incluye esta suite
con comprobaciones de giro individual, dirección seleccionada y aislamiento
respecto al giro del tablero.

## 2D/3D shared extension

The 3D panel now exposes a **flat-top** checkbox. It changes projection and
mesh orientation without changing stored coordinates, piece yaw, or connection
identity. Paired neighbor cells additionally emit edge-contact events; they
still emit two corner-contact events. The new 2D lab is in
`res://examples/hex_grid_2d/hex_grid_2d_lab.tscn`.
