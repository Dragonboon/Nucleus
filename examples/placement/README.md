# Runtime Placement 3D — laboratorio interactivo

Este ejemplo prueba el componente **NucleusPlacementSession3D** existente sin
introducir gestores, Autoloads, reglas de construccion ni escenas de juego en el
framework. Todos los objetos son `PackedScene` con primitivas de Godot y perfiles
`NucleusPlacementProfile3D` editables por Inspector.

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

## Cinco tipos de prueba

| Pieza | Propiedades a observar |
| --- | --- |
| **Casa** | Volumen grande, huella amplia, limite de pendiente 11°, snap a malla 1 m, giro en pasos de 45° |
| **Valla** | Huella estrecha, orientacion segun normal, giro 15°, cadenas rectas de 2 m y maximo 20 segmentos |
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
5. **Valla en cadena:** pulsa F, haz clic en el plano y mueve el raton a
   varios metros de distancia; confirma 3–6 segmentos. Prueba una cadena
   que atraviese el obstaculo: el conjunto no se debe confirmar.
6. **Edicion:** elige una pieza confirmada, pulsa E, cambia posicion y giro,
   pulsa Esc y verifica que vuelve al transform anterior. Repite con clic de
   confirmacion y comprueba que permanece en la nueva ubicacion.
7. **Retirada:** selecciona una pieza confirmada y usa Supr. La retirada la
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
- El laboratorio posee UX, seleccion, camara, coleccion de piezas y borrado.
- No persiste partidas, no deduce conexiones de sockets, no calcula costes y no
  gestiona redes. Nunca se confirman cambios de clientes no autoritativos.
- La inclinacion es **rigida**: se inclina la escena entera; no se deforma la
  malla de una casa ni se adapta cada poste de valla por separado.
- La cadena es lineal, no curva ni un Mesh unificado. Una cadena solo se confirma
  si todos los tramos son validos segun el motor de Nucleus.

Para los contratos reales revisa
`docs/components/runtime_placement_3d.md` y
`docs/components/safe_placement_queries.md`.
