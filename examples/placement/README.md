# Runtime Placement 3D — laboratorio interactivo

Este ejemplo prueba el componente **NucleusPlacementSession3D** existente sin
introducir gestores, Autoloads, reglas de construccion ni escenas de juego en el
framework. Todos los objetos son `PackedScene` con primitivas de Godot y perfiles
`NucleusPlacementProfile3D` editables por Inspector.

## Atajos del laboratorio actualizado

| Control | Accion |
| --- | --- |
| `1`–`5` | Colocar casa, valla, columna, plataforma o caja |
| `F` | Iniciar valla recta: clic inicio, clic final |
| `C` | Iniciar cadena curva: clic inicio, clic(s) intermedios, `Enter` para terminar en cursor |
| `Retroceso` | Borrar ultimo punto de control de curva |
| `Ctrl+clic` | Alternar pieza dentro de la multiseleccion |
| `Mayus+arrastrar` | Seleccion por rectangulo de pantalla |
| `Ctrl+A` | Seleccionar todo lo colocado |
| `E` | Mover los objetos seleccionados (si el perfil lo permite) |
| `Q` / `R` | Rotar las previsualizaciones o todo el grupo |
| `G` | Alternar el snap global de la sesion (no fuerza los assets) |
| `Supr` | Eliminar la seleccion (comprobacion de permisos previa) |
| `Esc` | Cancelar previsualizacion / restaurar transformaciones originales |
| Ratón derecho / rueda / central / WASD | Orbitar / zoom / paneo / mover camara |

## Abrir

En **Nucleus con Runtime Placement 3D ya integrado** (Godot 4.7.2), abre y ejecuta
`res://examples/placement/placement_lab.tscn` con F6. No cambia `project.godot`
ni la escena principal. Puedes ejecutar este laboratorio independientemente.

### Controles

| Entrada | Accion |
| --- | --- |
| Botones **1–5** | Elegir casa, valla, columna, plataforma o caja |
| **F** | Cadena: primer clic establece inicio sobre terreno, segundo confirma todos los segmentos |
| Clic izquierdo mientras se previsualiza | Validar y colocar; rojo significa invalido |
| Clic izquierdo sobre pieza confirmada | Seleccionarla |
| **E** | Editar la seleccion (moverla con raton, luego confirmar con clic) |
| **Q / R** | Rotar el preview hacia izquierda/derecha según el perfil |
| **Supr** | Solicitar retirada de la pieza seleccionada |
| **Esc** | Cancelar creacion o restaurar edicion; cuando no hay sesion, deseleccionar |
| Raton derecho + arrastrar | Orbitar camara |
| Rueda | Zoom |
| Raton central + arrastrar o **WASD** | Desplazar camara |
| **H / J / K** | Enfocar pendiente 18°, zona plana y pendiente 43° |

Los botones controlan las mismas operaciones que el teclado. El HUD informa del
modo, si el cursor permite colocar y por que se rechaza un candidato.

## Snap configurable (nuevo)

El boton **G** diferencia ahora dos estados que se notan claramente:

- **OFF = LIBRE REAL**: el asset sigue al cursor continuamente, sin
  redondeos X/Z, incluso si casa, caja o plataforma tienen snap forzado.
- **ON = SNAP**: se aplican los pasos globales de `0,5 m`, `1 m` o `2 m` a
  los perfiles que los heredan. Los assets pueden imponer su cuadrícula
  especifica o desactivarla (valla curva).

El indicador **SNAP EFECTIVO** distingue `LIBRE (forzado por el usuario)`
de una cuadrícula activada por la sesion o el asset. La cuadricula
grafica orientativa se oculta en modo libre; no tiene colision ni controla
las posiciones. No se cambian los
recursos originales: G solo modifica la sesion actual.

Si desarrollas un consumidor sin el override `force_free_placement`, sigue
vigente el contrato original de perfiles:

- **Caja**: fuerza `snap_mode = ENABLED`, cuadrícula 1 m cuando G esta
  encendido; G apagado la libera.
- **Casa**: mantiene 1 m al activar snap; G apagado permite coordenadas libres.
- **Plataforma**: mantiene 0,5 m al activar snap; G apagado permite libre.
- **Columna**: usa la rejilla global solo cuando G esta encendido.
- **Valla**: fuerza `snap_mode = DISABLED` para preservar sus tramos curvos.

Para cambiar un asset, abre por ejemplo
`res://examples/placement/profiles/crate_profile.tres` en el Inspector y
modifica `snap_mode` (`INHERIT` / `ENABLED` / `DISABLED`), `grid_step` y
`grid_origin`. Los perfiles anteriores con `snap_to_grid = true` siguen siendo
compatibles. El grid afecta **X/Z**, la altura Y sigue el terreno o la plataforma
real, y la validacion sigue rechazando pendientes y solapes.

La previsualizacion libre de piezas individuales ahora responde a cada tick
fisico (solo si cambia el punto bajo el cursor); la limitacion anterior de
65 ms permanece para las cadenas largas y grupos numerosos.

El limite de la cadena de la valla es **`chain_max_count = 20` en el perfil**
`fence_profile.tres`; puedes aumentar ese valor (hasta 256 desde Inspector),
pero el coste de validar y materializar todos los tramos aumenta. No es un
limite fijo de la herramienta de curvas.

## Cinco tipos de prueba

| Pieza | Propiedades a observar |
| --- | --- |
| **Casa** | Volumen grande, huella amplia, limite de pendiente 11°, snap a malla 1 m, giro en pasos de 45° |
| **Valla** | Huella estrecha, orientacion segun normal, giro 15°, cadenas rectas y curvas de 2 m y maximo 20 segmentos |
| **Columna** | Orientacion respecto al suelo, colocacion sobre terreno o plataformas (`kind=platform`) |
| **Plataforma** | Pendiente maxima 9°, snap 0.5 m, permite encima columnas y cajas |
| **Caja** | Permite apilar cajas sobre otras cajas o sobre plataformas; editing y retirada independientes |

Todas tienen colliders nativos en la capa 2. Las superficies portantes de la
demostracion estan en la capa 1, y los obstaculos no portantes en la capa 4.
Los perfiles trazan suelo/apoyos en las capas **1|2** y comprueban ocupacion
en **2|4**. Las mallas decorativas no tienen colision.

### Bateria manual recomendada

1. **Casa:** colócala sobre terreno plano; intenta solaparla con otra casa,
   el obstaculo rojo o fuera del limite del suelo. Observa previsualizacion roja.
2. **Pendientes:** prueba la casa en la rampa 18° (debe rechazarse por
   inclinacion), y la columna o valla sobre un tramo suficientemente interior
   de esa rampa (deberian adaptarse). En la rampa 43° se deben rechazar todas.
3. **Apilado:** coloca una plataforma en terreno plano y una columna/caja
   encima. Intenta casa o valla sobre esa plataforma: su perfil no lo permite.
4. **Cajas:** pon una caja sobre otra y luego retira la superior. Observa
   que se tratan como instancias distintas.
5. **Valla recta:** pulsa F, haz clic en el plano y mueve el raton a
   varios metros de distancia; confirma 3–6 segmentos. Prueba una cadena
   que atraviese el obstaculo: el conjunto no se debe confirmar.
6. **Valla curva:** pulsa C, haz clic para iniciar, haz clic en varios puntos
   para bordear el obstaculo y mueve el cursor hasta el extremo deseado.
   Pulsa Enter para validar y colocar la cadena completa. Retroceso deshace
   el ultimo punto; Esc cancela. Tramos muy cerrados que se solapen se rechazan.
7. **Multiseleccion:** Ctrl+clic añade/quita piezas; Mayus+arrastrar dibuja
   un marco; Ctrl+A selecciona todas. Pulsa E y cambia posicion y giro del
   grupo. Con Esc recupera exactamente todos los transform originales.
   Supr solicita eliminar todos, despues de comprobar permisos para el grupo.
8. **Edicion:** elige una pieza confirmada, pulsa E, cambia posicion y giro,
   pulsa Esc y verifica que vuelve al transform anterior. Repite con clic de
   confirmacion y comprueba que permanece en la nueva ubicacion.
9. **Retirada:** selecciona una pieza confirmada y usa Supr. La retirada la
   ejecuta exclusivamente el controlador del laboratorio tras recibir la
   senal `removal_requested` de la sesion Nucleus.

## Prueba automatica liviana

```bash
godot --headless --path . --import
godot --headless --path . --script res://examples/placement/placement_lab_smoke.gd
```

Prueba carga de las 5 escenas, perfiles, colliders, dependencia real de sesion,
inicio/cancelacion de preview, edicion con revertido de transform, cadena y
compatibilidad de apilado. **No** garantiza contactos fisicos de cada pixel,
rendimiento ni apariencia: la bateria manual es necesaria.

## Limites y responsabilidades

- Nucleus posee validacion de superficie/ocupacion, preview, edicion y cadena.
- El laboratorio posee UX, seleccion simple/multiple, seleccion por marco, camara, coleccion de piezas
  y borrado.
- No persiste partidas, no deduce conexiones de sockets, no calcula costes y no
  gestiona redes. Nunca se confirman cambios de clientes no autoritativos.
- La inclinacion es **rigida**: se inclina la escena entera; no se deforma la
  malla de una casa ni se adapta cada poste de valla por separado.
- Las cadenas admiten curvas de Catmull-Rom con piezas rigidas a distancia
  casi constante, **no** mallas deformadas ni conectores de esquina automaticos.
- Las validaciones se distribuyen entre ticks: AMBAR = aun comprobando, VERDE
  = admisible segun la ultima previsualizacion, ROJO = rechazado. Confirmar
  genera una nueva verificacion antes del evento de colocacion.
- Editar grupos de piezas independientes esta admitido; grupos que se apoyan
  internamente (por ejemplo, caja sobre plataforma seleccionada) se rechazan.
  Solo se admiten formas de clearance BoxShape3D para el grupo.
- `max_checks_per_tick` controla trabajo por frame; el perfilador de Godot es
  necesario para diagnosticar stutters ajenos a esta cola.

Para los contratos reales revisa
`docs/components/runtime_placement_3d.md` y
`docs/components/safe_placement_queries.md`.
