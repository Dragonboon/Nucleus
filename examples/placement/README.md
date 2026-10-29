## Variantes y rotación libre (laboratorio)

Al seleccionar **Casa (1)**, el laboratorio usa un `NucleusPlacementVariantSet3D`
con tres opciones: `roof_gable`, `roof_flat` y `roof_hip`.
**V** y **X** recorren las variantes, actualizan el preview y fuerzan la
reevaluación de soporte y colisiones; también hay botones en el panel.
El catálogo se mantiene en la demo, sin imponer assets ni HUD al componente.

**T** alterna entre rotación por pasos (pulsación Q/R) y rotación continua
(mantener Q/R). El giro utiliza `delta` y la velocidad configurable
`NucleusPlacementProfile3D.rotation_speed_degrees_per_second`.
No altera los pasos que usa `rotate_step()`, ni los permisos `can_rotate`.
Los frames bloqueados tienen un límite de `delta` para evitar saltos bruscos.

El documento del laboratorio sigue aceptando mundos anteriores. Las casas
con una variante seleccionada incorporan opcionalmente `variant` al registro
guardado; la restauración busca únicamente claves autorizadas como
`house:roof_flat` en el catálogo del juego, nunca rutas de recursos
proporcionadas por el archivo. Esta información viaja también por undo/redo
sin cambiar el esquema de mundos existente.

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
| `C` | Iniciar cadena curva: clic izquierdo para inicio; derecho para nuevos puntos; izquierdo para colocar |
| `Retroceso` | Borrar ultimo punto de control de curva |
| `Alt` + clic derecho y arrastrar | Orbitar la camara mientras se dibuja una curva |
| `Ctrl+clic` | Alternar pieza dentro de la multiseleccion |
| `Mayus+arrastrar` | Seleccion por rectangulo de pantalla |
| `Ctrl+A` | Seleccionar todo lo colocado |
| `E` | Mover los objetos seleccionados (si el perfil lo permite) |
| `Q` / `R` | Rotar por pasos o, en modo libre, mantener pulsadas para giro continuo |
| `T` | Alternar rotación por pasos y libre |
| `V` / `X` | Siguiente/anterior variante de tejado mientras se coloca una casa |
| `G` | Alternar el snap global de la sesion (no fuerza los assets) |
| `Supr` | Eliminar la seleccion (comprobacion de permisos previa) |
| `Esc` | Cancelar previsualizacion / restaurar transformaciones originales |
| Ratón derecho / rueda / central / WASD | Orbitar / zoom / paneo / mover camara (en curva: derecho = giro) |

## Interaccion de curvas (correccion de flujo)

1. Pulsa `C` y haz **clic izquierdo** en el terreno para fijar el inicio.
2. Desplaza el cursor y usa **clic derecho** para fijar uno o varios puntos de giro.
3. Desplaza el cursor al extremo deseado y haz **clic izquierdo** para confirmar
   **toda la cadena**. No se inserta un nuevo punto de control con ese clic.
4. Mientras trazas, `Alt + clic derecho` permite orbitar la camara, `Retroceso`
   deshace el ultimo control y `Esc` cancela el trazado.

`Enter` ya no es necesario para confirmar. El boton del panel **Curva: colocar
(clic izq.)** sigue disponible para accesibilidad. La previsualizacion verde
indica la ultima comprobacion completada; un clic de confirmacion solicita una
**nueva validacion incremental** del trazado final. Si algo cambia o el conjunto
se vuelve invalido, se rechaza indicando el motivo sin crear piezas parciales.

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
| **Q / R** | Rotación por pasos; con T activado, mantener para girar libremente |
| **T** | Alternar rotación continua a 120°/s por defecto (configurable por asset) |
| **V / X** | Cambiar variante de tejado de una casa durante el preview |
| **Supr** | Solicitar retirada de la pieza seleccionada |
| **Esc** | Cancelar creacion o restaurar edicion; cuando no hay sesion, deseleccionar |
| Raton derecho + arrastrar | Orbitar camara fuera del modo curva; dentro, anadir un giro |
| Alt + raton derecho + arrastrar | Orbitar camara mientras se dibuja una curva |
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

## Seis tipos de prueba

| Pieza | Propiedades a observar |
| --- | --- |
| **Casa** | Volumen grande, huella amplia, limite de pendiente 11°, snap a malla 1 m, giro en pasos de 45° |
| **Valla** | Huella estrecha, orientacion segun normal, giro 15°, cadenas rectas y curvas de 2 m y maximo 20 segmentos |
| **Columna** | Orientacion respecto al suelo, colocacion sobre terreno o plataformas (`kind=platform`) |
| **Plataforma** | Pendiente maxima 9°, snap 0.5 m, permite encima columnas y cajas |
| **Caja** | Permite apilar cajas sobre otras cajas o sobre plataformas; editing y retirada independientes |
| **Tótem** | Pivote central, `VISUAL_BOTTOM`, corrección automática de la base geométrica |

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
6. **Valla curva:** pulsa C y haz **clic izquierdo** para iniciar. Anade
   giros con **clic derecho** para bordear el obstaculo y mueve el cursor
   hasta el extremo deseado. Haz **clic izquierdo** para validar y colocar
   la cadena completa. **Alt + derecho** permite orbitar durante el trazado.
   Retroceso deshace el ultimo punto; Esc cancela. Tramos muy cerrados que
   se solapen se rechazan.
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

## World Authoring Tools — guardar, duplicar, deshacer (nueva iteración)

Este laboratorio también funciona como un **mini editor de mundos en runtime**.
El flujo de selección, colocación libre y snap, cadenas rectas/curvas,
multiselección y validación física permanece sin cambios.

| Control | Operación |
| --- | --- |
| `Ctrl+Z` | Deshacer una operación **confirmada** completa |
| `Ctrl+Y` / `Ctrl+Mayús+Z` | Rehacer |
| `Ctrl+C` | Copiar la selección al portapapeles interno |
| `Ctrl+V` | Pegar el grupo, desplazado 4 m a la derecha de la cámara |
| `Ctrl+D` | Duplicar la selección (copiar + pegar) |
| Selector **Mundo 1–3** | Elegir una de las tres ranuras de mundo independientes |
| `Ctrl+S` | Guardar el mundo actual en la ranura seleccionada |
| `Ctrl+O` | Cargar un mundo guardado, con confirmación |
| `Ctrl+N` | Vaciar el mundo, con confirmación; operación reversible |

Los botones del panel izquierdo exponen también estas acciones; ahora el panel es
**desplazable**, para que siga siendo accesible en ventanas pequeñas. El panel
de estado informa de piezas, acciones deshacibles y cambios sin guardar.

**Deshacer/rehacer** utiliza el componente Nucleus existente
`NucleusValidatedActionHistory` (24 operaciones en el laboratorio). Una cadena
entera, una multiedición y una eliminación múltiple consumen **una sola**
operación cada una. Los estados se vuelven a construir desde descriptores de
escena, no desde punteros a nodos liberados. No se guarda el historial en disco.
Una nueva operación después de deshacer descarta la rama de rehacer.

**Duplicación:** solo se admiten grupos de hasta **8** piezas por operación.
`Ctrl+D` y `Ctrl+V` ahora preparan **copias fantasma** que siguen el cursor.
No se confirman ni guardan hasta hacer clic en una posición validada; `Esc`
descarta todas las copias pendientes. El solver revalida el terreno, los
obstáculos y los solapes del grupo de forma incremental. La duplicación de un
conjunto internamente apilado necesita un contrato de soportes relativo: no
debe utilizarse como editor completo de estructuras articuladas. El portapapeles es local
a esta sesión; no contiene rutas de archivos ejecutables ni se expone al SO.

**Persistencia:** `Ctrl+S` usa `NucleusSave.save_manual()` para guardar el
payload `{"world": documento}` en la ranura `placement_lab_world_1`, `_2` o
`_3`; `Ctrl+O` lo recupera mediante `NucleusSave.load_manual()`. Se reutilizan
las copias de seguridad, la integridad y las migraciones del servicio. Los
JSON antiguos `user://placement_lab_world_1.json`, `_2.json` y `_3.json` se
pueden importar con `Ctrl+O` **solo cuando aún no existe la ranura NucleusSave**.
Tras importar, `Ctrl+S` migra ese mundo al nuevo sistema. Cambiar la ranura por si solo no
sustituye el mundo que se esta editando. La escena no se carga automáticamente al iniciar el
laboratorio. El formato `schema_version = 1` almacena exclusivamente `{id,
kind, transform}`: identidad estable, tipo cerrado del catálogo y 12 valores
de una transformación rígida. El usuario **no puede** introducir una ruta a
una escena arbitraria, un recurso externo o un script a través del JSON.

Antes de restaurar, `placement_world_document.gd` comprueba: versión, campos,
tipos numéricos, IDs únicos, tipo autorizado, límites de coordenadas,
transformaciones sin escala/reflexión y hasta **384 piezas / 512 KiB**.
Preinstancia los nodos antes de sustituir el mundo: los archivos inválidos
no destruyen el escenario actual. No revalida todas las colisiones de una
partida guardada, porque la geometría de terreno del juego podría cambiar.
Por ello **este documento es un formato de autoría local, no una prueba de
legalidad para un servidor multijugador**. Un juego publicado debe validar de
nuevo sobre su estado autoritativo y migrar explícitamente futuros esquemas.

Los IDs se asignan al confirmar, no durante la previsualización. Los ajustes
de cuadrícula se aplican al colocar, pero **guardar/cargar y deshacer nunca
vuelven a redondear** las posiciones previamente confirmadas.

### Comprobación de aceptación

1. Coloca una casa y una valla curva: una sola pulsación de `Ctrl+Z` debe
   deshacer **toda la valla**, otra deshace la casa. `Ctrl+Y` las recupera.
2. Selecciona dos cajas, `Ctrl+C`, `Ctrl+V`. Si el destino está libre y el
   soporte es válido, aparecen ambas con IDs nuevos. En caso contrario no
   aparece ninguna. `Ctrl+Z` elimina las dos copias de una vez.
3. Mueve una pieza, confirma y deshaz; luego rehace. La transformación
   restaurada debe coincidir con la anterior, incluso con `G` libre.
4. Guarda con `Ctrl+S`, limpia con `Ctrl+N` y carga con `Ctrl+O`; compara la
   cantidad, el tipo, las orientaciones y las posiciones originales.
5. Edita una pieza y pulsa `Ctrl+S` durante la previsualización: debe rechazar
   el guardado hasta confirmar o cancelar. `Esc` restaura la transformación.
6. Comprueba que un archivo JSON de mundo con `kind` desconocido o una
   transformación no numérica se rechaza sin modificar la escena.

**Ejecutar smoke:**

```bash
godot --headless --path . --script res://examples/placement/placement_lab_smoke.gd
```

El smoke incluye deserialización, denegaciones por esquema y seguridad,
restauración atómica y operaciones de historial. La validación de colisiones,
latencia de vista previa, render y usabilidad requieren además abrir la escena
con F6 en Godot.

## Flujo rápido de autoría (iteración actual)

- **Colocación repetida, activada por defecto:** pulsa `1`–`5` una vez y coloca
  cuantas piezas quieras. Tras cada confirmación aparece otro preview del mismo
  asset, sin volver al ratón libre. `B` o el checkbox **Repetir tras colocar**
  alterna la repetición; `Esc` abandona el pincel. `Ctrl+A` sale del pincel y
  selecciona automáticamente todas las piezas confirmadas.
- **Mover todo:** `Ctrl+A` y luego `E`. El máximo de edición del laboratorio es
  384 piezas, igual que el límite del documento, y se comprueba en lotes. Los
  soportes apilados **directos y compatibles** preservan su relación cuando el
  objeto base también está seleccionado. Para estructuras articuladas o apoyos
  ambiguos hay que diseñar una política de edición más específica.
- **Duplicar para colocar:** selecciona una o varias piezas y pulsa `Ctrl+D`;
  las copias se muestran en modo preview bajo el cursor. Muévelas, usa `Q/R`
  para girarlas, clic izquierdo para confirmar o `Esc` para descartar. `Ctrl+V`
  hace lo mismo con el portapapeles. El laboratorio conserva el límite de ocho
  copias por operación y asigna IDs nuevos solo tras confirmar.
- **Curvas precisas:** `C`, inicio con clic izquierdo, puntos de control con derecho y colocacion con izquierdo. `chain_curve_tension`
  permite ajustar cuánto se suavizan las esquinas; la orientación se calcula
  con la tangente física de cada segmento, no con el lado de una polilínea
  gruesa. `chain_spacing` debe corresponder a la longitud real de la malla.
  Los segmentos rígidos no pueden eliminar por completo las separaciones
  visuales de giros cerrados: se necesitan piezas de esquina, sockets o malla
  deformable si se quiere una continuidad perfecta.
- **Guardar sin salir del pincel:** `Ctrl+S`, `Ctrl+Z` y `Ctrl+Y` suspenden
  temporalmente el preview individual, ejecutan la operación y lo recuperan;
  no almacenan el fantasma. Los mundos están protegidos por `NucleusSave`; la
  validación y el catálogo de escenas siguen en el laboratorio.

El módulo `addons/nucleus/modules/world_state` **no se utiliza** porque este laboratorio
reconstruye un documento entero en una sola escena. Para un juego con regiones,
objetos persistentes entre cargas y reaparición dinámica, `WorldStateService`
es el consumidor adecuado y puede conectarse a `NucleusSaveSession`.

### Comprobaciones manuales principales

1. Con `B` activo, pulsa `5` y coloca tres cajas seguidas; solo debe hacer falta
   elegir Caja una vez. `Esc` elimina únicamente el preview pendiente.
2. Selecciona todo con `Ctrl+A`, mueve con `E`, comprueba la previsualización por
   lotes, confirma y usa `Ctrl+Z`. La restauración debe conservar todas las piezas.
3. Duplica una columna con `Ctrl+D`, muévela antes de hacer clic y cancela otra
   duplicación con `Esc`: no deben aparecer duplicados hasta el commit.
4. Crea una valla curva con puntos desigualmente espaciados; prueba tensiones
   0 / 0.7 / 1 y confirma el rechazo si hay solapes.
5. Guarda y vuelve a abrir un mundo con `Ctrl+S`/`Ctrl+O`, sin perder IDs ni
   transforms; comprueba la carga de JSON legacy si vienes de la versión anterior.

## Extensión P1: origen geométrico y pincel de placement (2026-10-11)

El laboratorio incorpora un **sexto placeholder (`6`, Tótem)** para mostrar
la nueva opción de perfil `origin_mode`:

- `AUTHORED_ORIGIN` (predeterminado): respeta el pivote de siempre.
- `VISUAL_BOTTOM`: calcula la caja visual local de las mallas hijas una sola vez,
  compensa su base hacia el terreno y comprueba la colisión con ese transform
  definitivo. Puedes comparar ambas opciones en
  `examples/placement/profiles/totem_profile.tres`.

**Nuevo control `P`**: activa/desactiva el *pincel de objetos*. Selecciona
antes un asset con `1`–`6` (o actívalo sin selección para usar Caja). Con P
activo, **mantén pulsado y arrastra el clic izquierdo** por el terreno:

- **Separación**: 0,8 / 1,5 / 2,5 / 4 m, control del espaciado sobre la ruta.
- **Dispersión radial**: 0 / 0,5 / 1 / 2 m. Los desplazamientos son
  reproducibles con la semilla fija de este laboratorio. No es un sistema
  de plantas con densidad por metro cuadrado: genera un candidato por paso
  del cursor, con *jitter* opcional dentro del radio.
- **Límite**: 64 candidatos por trazo y máximo 384 objetos persistentes
  en el mundo de demostración.
- **Presupuesto**: como máximo un candidato del pincel por tick físico,
  utilizando los métodos de validación y confirmación de `PlacementSession3D`.
- **Undo**: todo el trazo se registra como **una sola acción** al finalizar la
  cola; `Ctrl+Z` la revierte de una vez. Las posiciones no admitidas cuentan
  como rechazadas y no se convierten en escenas.
- **Cancelar**: `Esc` mientras se pinta o termina de validar revierte
  completamente el trazo. `Esc` una vez en reposo sale del modo pincel.
- **Volver al modo normal**: `P` apaga el pincel. Las curvas con `C`, las
  cadenas rectas con `F`, el snap con `G`, las acciones sobre multiselección y
  el guardado mediante `NucleusSave` no cambian.

El pincel consulta solo la superficie del terreno de demostración (capa 1)
para evitar que el cursor se adhiera accidentalmente a la parte superior de
los objetos que ya estás pintando. Cada perfil sigue verificando sus propias
capas, pendiente, huella, obstáculos y restricciones de apilado. El trazo no
puede utilizarse para crear objetos en el aire. Si el usuario quiere un
pincel sobre paredes o sobre otras piezas, la política de superficie debe
configurarse explícitamente en su juego.

**Limitaciones:** no se altera la escala del objeto, no hay brochazo de área
con múltiples candidatos simultáneos y no se generan `MultiMesh` ni objetos
físicamente asentados con `RigidBody3D`. Para vegetación masiva visual debe
usarse el módulo `NucleusScatter`. No está implementado un pincel de borrado.

**Pruebas manuales:** empieza con Caja (`5`) en zona plana, `P`, arrastra
unos 10 m, suelta, espera al mensaje de finalización y pulsa `Ctrl+Z`;
prueba después el Tótem (`6`) para validar su origen central. Activa el
snap (`G`) y compara posiciones frente al modo libre. Verifica por último
que una cadena curva siga funcionando como antes.
