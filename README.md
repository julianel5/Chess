# Ajedrez — Addon para WoW 3.3.5

Addon de [World of Warcraft: Wrath of the Lich King (3.3.5)](https://en.wikipedia.org/wiki/World_of_Warcraft:_Wrath_of_the_Lich_King) para jugar ajedrez **contra la máquina** (minimax con poda alfa-beta) o **contra otro jugador**, en tiempo real y por susurros.

Las pestanas _Vs Maquina_ y _Online_ son totalmente independientes: puedes jugar una partida local contra la IA y una online a la vez, alternando de pestaña sin que se pisen.

## Caracteristicas

- **Motor completo**: jaque, jaque mate, ahogado, enroque corto y largo, captura al paso, promocion, tablas por repeticion de jugadas, regla de las 50 jugadas y material insuficiente.
- **IA configurable**: dificultad Facil / Medio / Dificil (se guarda entre sesiones).
- **Partidas online** entre dos personas con el addon: retos, panel de retos recibidos con aceptar/rechazar, rendirse, oferta de tablas y revancha.
- **Dos tableros independientes**: la partida local contra la maquina y la partida online conviven; cambiar de pestaña no interrumpe ninguna.
- **Indicador de color** en el titulo online: _Ajedrez - Online (Eres las Negras)_ para no perderte al alternar entre modo maquina (siempre blancas) y online (color sorteado).
- **Girar tablero** disponible en ambos modos (esencial jugando online con las negras).
- **Turno sincronizado**: el texto de estado acompaña siempre al turno real (nunca dice _Te toca mover_ cuando esperas al rival).
- Efectos de sonido para mover, capturar y jaque.

## Requisitos

- Cliente de WoW **3.3.5a** (WotLK).
- Para el multijugador: ambos jugadores con el addon, en el mismo servidor (pueden ser reinos distintos: escribe `Nombre-Reino`), y conectados a la vez con diferentes personajes.

## Instalacion

1. Copia la carpeta `Chess` en tu carpeta de addons:
   `Interface\AddOns\Chess`
2. Abre el juego con el addon activado (boton **Addons** del login) o escribe `/console reloadui`.
3. En el juego escribe `/chess` (o `/ajedrez`) para abrir/cerrar el tablero.

> En servidores privados de 3.3.5 que no usen `.toc` es suficiente con activar el addon en el login.

## Como jugar

El addon tiene dos pestanas arriba (dorada = pestana activa):

- **Vs Maquina**: juegas con las blancas (piezas abajo) contra la IA, que lleva las negras.
  Botones: `Nueva partida`, `Deshacer`, `Pista`, `Dificultad` y `Girar tablero`.
- **Online**: contra otra persona. Sin partida activa se muestra el panel **Retos recibidos** y el boton `Retar`. Durante una partida online hay disponibles:
  `Salir` (abandona y vuelve al panel de retos), `Rendirse`, `Tablas`, `Revancha` (al terminar) y `Girar tablero`.

Tanto en local como en online:

- Haz clic en una pieza tuya para seleccionarla; las casillas legales se marcan en verde. Haz clic en una casilla verde para mover.
- Si un peon llega al final, eliges la pieza de promocion (y la jugada no se envia hasta elegirla).
- El texto bajo el tablero indica de quien es el turno, si hay jaque, el resultado y las capturas de cada bando.

## Multijugador online

1. Pestana **Online** y boton **Retar** (o `/chess reto NombreJugador`). El color se sortea al azar y el titulo te indica si eres blancas o negras.
2. Al rival le sale una ventana **Aceptar / Rechazar**; ademas, el reto queda a la vista en el panel **Retos recibidos** por si prefiere aceptarlo mas tarde (cada reto caduca a los 3 minutos).
3. Durante la partida los dos juegan a la vez en sus respectivos tableros; el addon mantiene la sincronia por si algun mensaje se pierde.

**Comunicacion**: el addon usa mensajes de addon por susurro (`CHAT_MSG_ADDON`) y, como respaldo, replica el reto dentro de un susurro normal con la palabra clave `!ajedrez` (los susurros normales llegan siempre). Por eso el protocolo no usa `|` (WoW lo interpreta como codigo de color/enlace): los campos se separan con espacios.

**Panel retos recibidos**: deja todos los retos a la vista; eliges cual aceptas (`Aceptar`) o descartas (`Rechazar`).

## Comandos

| Comando | Descripcion |
| --- | --- |
| `/chess` o `/ajedrez` | Abre/cierra el tablero |
| `/chess solo` o `/chess local` | Va a la pestana Vs Maquina |
| `/chess online` | Va a la pestana Online |
| `/chess reto <Nombre>` | Reta a otro jugador (usa `Nombre-Reino` si esta en otro reino) |
| `/chess debug` o `/chess log` | Activa/desactiva el registro de comunicaciones en el chat |
| `/chess teste <Nombre>` | Prueba de ida y vuelta con otro jugador (ambos deben ejecutar `/chess teste <tuNombre>`) |
| `/chess check` o `/chess estado` | Muestra el estado interno (personaje, reino, cola, registro de eventos, log...) |

## Diagnostico de comunicaciones

- `/chess debug` registra en el chat cada envio/recepcion (etiqueta `[Chess]`). Debe activarse en **los dos** clientes.
- `/chess teste Nombre` envia por los dos canales; el rival contesta automaticamente. Sirve para comprobar si los mensajes de addon llegan en tu servidor.
- Si el reto no llega: verifica el nombre (reino), que ambos esten online a la vez, o la red/firewall. Con el log activo se distingue si falla el canal de addon (el respaldo por susurro `!ajedrez` deberia haberte salvado) o si no llega ni el susurro.

## Archivos

| Archivo | Descripcion |
| --- | --- |
| `Chess.toc` | Indice del addon |
| `ChessEngine.lua` | Reglas del ajedrez, generador de jugadas y motor de la IA (minimax + alfa-beta) |
| `ChessNet.lua` | Comunicacion online (mensajes de addon por susurro + respaldo por chat) |
| `ChessUI.lua` | Interfaz grafica y control de ambas partidas |
| `sounds/*.wav` | Efectos de sonido (mover, capturar, jaque) |
| `textures/*.tga` | Imagenes de las piezas (128x128) |

## Creditos y licencia

Las ilustraciones de las piezas proceden del conjunto **"cburnett"** de Cburnett (Wikimedia Commons), con licencia GFDL, CC-BY-SA-3.0 y GPLv2/3 (a eleccion del autor). Fuente:
<https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces>

El resto del addon se distribuye como codigo libre: usalo, modificalo y compartelo.