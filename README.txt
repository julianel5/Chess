Ajedrez para WoW 3.3.5
========================

Addon que te permite jugar ajedrez contra una maquina (minimax + poda alfa-beta).

Instalacion
-----------
1. Copia la carpeta "Chess" a tu carpeta de addons:
   \\Archivos de programa\\World of Warcraft\\Interface\\AddOns\\Chess
2. Abre el juego con el addon activado (boton "Addons" del login) o escribe:
   /console reloadui
3. En el juego escribe  /chess  (o  /ajedrez ) para abrir/cerrar el tablero.

Como jugar
----------
- El addon tiene dos pestanas arriba (dorada = pestana activa):
    * "Vs Maquina": contra la IA. Tu juegas con las blancas (abajo)
      y la maquina con las negras.
    * "Online": contra otra persona con el addon.
- Haz clic en una pieza blanca para seleccionarla; las casillas legales
  se marcan en verde. Haz clic en una casilla verde para mover.
- Si un peon llega al final del tablero, eliges la pieza de promocion.
- Botones (pestana "Vs Maquina"):
  * Nueva partida  - reinicia el juego
  * Deshacer       - revierte tu ultima jugada y la de la maquina
  * Pista          - resalta la jugada recomendada
  * Dificultad     - Facil / Medio / Dificil (se guarda)
  * Girar tablero  - rota la vista 180 grados
- Se detectan jaque, jaque mate, ahogado, repeticion de jugadas,
  regla de las 50 jugadas y material insuficiente.
- Puedes alternar de pestana cuando quieras: la partida online sigue
  en segundo plano aunque mires la pestana de la maquina. Cuando acabe
  una partida online, pulsa "Nueva partida" para salir del modo online
  y volver a jugar contra la maquina.
- Desde el chat tambien puedes cambiar de modo al instante:
  /chess solo   (vuelve a jugar contra la maquina)
  /chess online (abre la pestana online)

Multijugador (jugadores con el addon)
-------------------------------------
- Ambos deben tener el addon y estar conectados al mismo servidor,
  a la vez, en otra cuenta de personaje.
- La comunicacion se hace por susurro (mensajes de addon). El addon
  escucha el evento CHAT_MSG_WHISPER (susurros normales) y CHAT_MSG_ADDON
  (mensajes de addon por susurro). Los mensajes del protocolo NO usan el
  caracter "|" (WoW se lo come en el chat: son codigos internos de
  color/link); los campos se separan con espacios. Para que el reto
  llegue SIEMPRE, este tambien viaja dentro de un susurro normal con la
  palabra clave "!ajedrez" (los susurros normales llegan siempre).
- Si algo falla, puedes forzar la sincronizacion a mano: escribe en el
  chat  /w NombreJugador !ajedrez  y espera 2 segundos antes de retar.
- Para retar a alguien: pestana "Online" y boton "Retar"
  (o escribe  /chess reto NombreJugador ).
  Si el rival esta en otro reino, escribe  Nombre-Reino .
- El color se sortea al azar al enviar el reto.
- Si te retan, sale una ventana de Aceptar / Rechazar y, ademas, todos
  los retos recibidos quedan a la vista en la pestana "Online" (panel
  "Retos recibidos") por si no quieres aceptarlos en ese momento:
  elige quien aceptas (Aceptar) o descartas (Rechazar) desde la lista.
  Cada reto caduca a los 3 minutos.
- Si no llega respuesta en ~25 segundos, el addon te lo avisa:
  comprueba que el rival tenga el addon cargado y este en linea.

Diagnostico de comunicaciones
-----------------------------
-  /chess debug   - registra en el chat cada envio/recepcion
                    (mensajes con etiqueta "[Chess]"). Activarlo en
                    LOS DOS clientes y repetir el reto.
-  /chess teste Nombre - prueba de ida y vuelta: envia a "Nombre" un
                    mensaje por addon y otro por susurro normal; el
                    rival contesta automaticamente. Tambien debe
                    ejecutar el rival  /chess teste TuNombre.
-  /chess check   - estado interno (personaje, eventos, auto-eco, cola).
- Con el log activo se distingue la causa: si el cable de addon no se
  entrega en tu servidor pero el susurro si llega, el reto igualmente
  llega (protocolo dual). Si NI el susurro llega, revisa el nombre
  (reino), que ambos esten online a la vez, o la red/firewall.
- Botones de la pestana Online durante la partida: Rendirse, Tablas
  (oferta de empate) y Revancha (al terminar).
- Sin pistas ni deshacer en partidas online (no romperian la sincronia).

Archivos
--------
Chess.toc         - indice del addon
ChessEngine.lua   - reglas y motor de la IA
ChessNet.lua      - comunicacion online (mensajes de addon por susurro)
ChessUI.lua       - interfaz grafica
sounds/*.wav      - efectos de sonido (mover, capturar, jaque)
textures/*.tga    - imagenes de las piezas (128x128)

Agradecimientos
---------------
Las ilustraciones de las piezas proceden del conjunto "cburnett" de
Cburnett (Wikimedia Commons), con licencia: GFDL, CC-BY-SA-3.0 y GPLv2/3
(a opcion del autor). Fuente:
https://commons.wikimedia.org/wiki/Category:SVG_chess_pieces