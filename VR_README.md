# Modo VR (rama `vr`)

Base de soporte VR (OpenXR) para el juego. **Aditivo**: sin casco/runtime, el
juego corre exactamente igual que en plano, así que esta rama sigue siendo
jugable en monitor.

## Qué hay montado (base)

- **OpenXR activado** en `project.godot` (`xr/openxr/enabled=true`).
- **`XRManager`** (autoload, `scripts/vr/xr_manager.gd`): arranca OpenXR si hay
  casco + runtime; si no, modo plano. Cuando hay VR, activa el render XR y monta
  el rig.
- **Rig** (`scripts/vr/vr_rig.gd`): cámara del casco + **dos mandos, cada uno con
  un arma** (`vr_hand.gd`) que dispara con el **gatillo** reutilizando el sistema
  de proyectiles del juego. La mano derecha lleva además un **puntero láser**
  (`vr_ui_pointer.gd`) para el menú.

## Probar (necesitas casco)

1. Instala un runtime OpenXR (SteamVR, Oculus/Meta, o Monado) y conéctalo.
2. Abre el proyecto en Godot 4.6.3 y dale a Play con el casco puesto.
3. En consola verás `[VR] OpenXR activo.` y `[VR] Rig VR montado.`. Tendrás un
   arma en cada mano; el gatillo dispara.

> Sin casco verás `[VR] OpenXR no disponible/inicializable — modo plano`. Normal.

## Lo que falta / hay que afinar CON CASCO (es iterativo)

Esto **no se puede probar sin hardware**, así que queda como siguiente paso:

- **Menú 2D en 3D**: el puntero ya lanza el rayo y "clica" sobre nodos del grupo
  `vr_ui` con método `vr_click(world_point)`. Falta mostrar el menú actual
  (un `CanvasLayer`) en un **SubViewport sobre un quad** y mapear el clic del
  rayo a eventos de ratón del SubViewport. Es el patrón estándar (Godot XR Tools
  lo trae hecho con su *Viewport2Din3D* + *function pointer*).
- **Locomoción y cámara**: el juego corre por el **interior de una esfera con
  gravedad radial**. Con locomoción suave eso **marea** en VR. Hay que decidir
  modelo de confort (teleport, snap-turn, viñeta) e integrar la dirección de
  movimiento con la del casco (ahora el rig sigue al cuerpo del jugador y el
  casco mueve la cámara por encima).
- **Acciones del juego**: mapear escudo/impulso/salto a botones de los mandos.

Para el menú-en-3D, la locomoción cómoda y el agarre de armas, lo más robusto es
añadir **Godot XR Tools** (addon) en vez de reimplementarlo a mano.
