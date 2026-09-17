Ajedrez - Addon para WoW 3.3.5
==============================

Addon de World of Warcraft: Wrath of the Lich King (3.3.5) para jugar
ajedrez contra la maquina (minimax con poda alfa-beta) o contra otro
jugador, en tiempo real y por susurros.

Las pestanas "Vs Maquina" y "Online" son totalmente independientes:
puedes jugar una partida local contra la IA y una online a la vez,
alternando de pestana sin que se pisen.

Caracteristicas
---------------
- Motor completo: jaque, jaque mate, ahogado, enroque corto y largo,
  captura al paso, promocion, tablas por repeticion de jugadas, regla
  de las 50 jugadas y material insuficiente.
- IA configurable: dificultad Facil / Medio / Dificil (se guarda).
- Partidas online entre dos personas con el addon: retos, panel de
  retos recibidos con aceptar/rechazar, rendirse, oferta de tablas y
  revancha.
- Dos tableros independientes: la partida local y la online conviven;
  cambiar de pestana no interrumpe ninguna.
- Indicador de color en el titulo online: "Ajedrez - Online (Eres las
  Negras)" para no perderte al alternar entre modo maquina (siempre
  blancas) y online (color sorteado).
- Girar tablero disponible en ambos modos (esencial online con negras).
- Turno sincronizado: el texto de estado acompaña siempre al turno real.
- Efectos de sonido para mover, capturar y jaque.

Requisitos
----------
- Cliente de WoW 3.3.5a (WotLK).
- Para el multijugador: ambos jugadores con el addon, en el mismo
  servidor (pueden ser reinos distintos: escribe Nombre-Reino), y
  conectados a la vez con diferentes personajes.

Instalacion
-----------
1. Copia la carpeta "Chess" a Interface\AddOns\Chess.
2. Abre el juego con el addon activado (boton "Addons" del login) o
   escribe: /console reloadui
3. En el juego escribe  /chess  (o  /ajedrez ) para abrir/cerrar.

Como jugar
----------
El addon tiene dos pestanas arriba (dorada = pestana activa):
  * "Vs Maquina": juegas con las blancas (piezas abajo) contra la IA,
    que lleva las negras. Botones: Nueva partida, Deshacer, Pista,
    Dificultad y Girar tablero.
  * "Online": contra otra persona. Sin partida se muestra el panel
    "Retos recibidos" y el boton "Retar". Durante la partida online:
    Salir (abandona y vuelve al panel de retos), Rendirse, Tablas,
    Revancha (al terminar) y Girar tablero.

En local y en online:
- Haz clic en una pieza tuya para seleccionarla; las casillas legales
  se marcan en verde. Haz clic en una casilla verde para mover.
- Si un peon llega al final, eliges la pieza de promocion (la jugada
  no se envia hasta elegirla).
- El texto bajo el tablero indica de quien es el turno, si hay jaque,
  el resultado y las capturas de cada bando.

Multijugador online
-------------------
- Ambos deben tener el addon y estar conectados al mismo servidor, y
  estar online a la vez con otro personaje.
- La comunicacion se hace por susurro. El addon usa mensajes de addon
  (CHAT_MSG_ADDON) y, como respaldo, replica el reto dentro de un
  susurro normal con la palabra clave "!ajedrez" (los susurros normales
  llegan siempre). Por eso los mensajes NO usan el caracter "|" (WoW
  lo interpreta como codigo de color/enlace): los campos se separan
  con espacios.
- Para retar: pestana "Online" y boton "Retar" (o  /chess reto Nombre ).
  Si el rival esta en otro reino, escribe  Nombre-Reino. El color se
  sortea al azar al enviar el reto y el titulo te indica cual te toco.
- Si te retan, sale una ventana Aceptar / Rechazar y, ademas, el reto
  queda a la vista en el panel "Retos recibidos" por si prefieres
  aceptarlo mas tarde. Cada reto caduca a los 3 minutos.
- Durante la partida ambos juegan a la vez; el addon mantiene la
  sincronia aunque algun mensaje se pierda.

Comandos
--------
  /chess  o  /ajedrez         abre/cierra el tablero
  /chess solo o /chess local  pestana Vs Maquina
  /chess online               pestana Online
  /chess reto Nombre          reta a otro jugador
  /chess debug o /chess log   registro de comunicaciones en el chat
  /chess teste Nombre         prueba de ida y vuelta con otro jugador
  /chess check o /chess estado  estado interno del addon

Diagnostico de comunicaciones
-----------------------------
-  /chess debug  registra en el chat cada envio/recepcion (etiqueta
   "[Chess]"). Debe activarse en LOS DOS clientes y repetir el reto.
-  /chess teste Nombre  prueba de ida y vuelta: envia por los dos
   canales; el rival contesta automaticamente. Ambos deben ejecutar
   /chess teste TuNombre.
-  /chess check  muestra el estado interno (personaje, reino, eventos,
   cola, log).
- Si el reto no llega: revisa el nombre (reino), que ambos esten online
  a la vez, o la red/firewall. Con el log activo se distingue si falla
  el canal de addon (el respaldo "!ajedrez" deberia haberte salvado) o
  si no llega ni el susurro.

Archivos
--------
Chess.toc         - indice del addon
ChessEngine.lua   - reglas del ajedrez, generador de jugadas y motor
                    de la IA (minimax + alfa-beta)
ChessNet.lua      - comunicacion online (mensajes de addon por susurro
                    + respaldo por chat)
ChessUI.lua       - interfaz grafica y control de ambas partidas
sounds/*.wav      - efectos de sonido (mover, capturar, jaque)
textures/*.tga    - imagenes de las piezas (128x128)

Creditos y licencia
-------------------
Las ilustraciones de las piezas proceden del conjunto "cburnett" de
Cburnett (Wikimedia Commons), con licencia GFDL, CC-BY-SA-3.0 y GPLv2/3
(a eleccion del autor). Fuente:
https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces

El resto del addon se distribuye como codigo libre: usalo, modificalo
y compartelo.