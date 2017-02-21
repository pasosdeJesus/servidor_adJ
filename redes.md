# Redes, protocolos e Internet {#redes_protocolos_e_internet}

Las redes de computadores constan de medios de transmisión (e.g cables),
dispositivos (e.g tarjetas de red) y programas (e.g pila TCP/IP del
kernel) que permiten transmitir información entre computadores. Pueden
clasificarse de acuerdo al tamaño (WAN de cobertura amplia como un país,
MAN de cobertura metropolitana o LAN para edificios o salones) o de
acuerdo a la estructura de sus protocolos (e.g el módelo OSI que consta
de 7 capas de protocolos: física, enlace, red, transporte, sesión,
presentación y aplicación), o de acuerdo a la distribución física de los
medios de transmisión y dispositivos (e.g estrella, bus).

LAN es acrónimo de *Local Area Network*, con este término se hace
referencia a redes pequeñas (comúnmente menos de 100 computadores) cuyos
computadores están generalmente en un mismo espacio físico. Los
principales usos de una red LAN son:

-   Compartir información distribuida en los discos duros o medios de
    almacenamiento de cada computador.

-   Emplear recursos de un computador desde otro, o recursos conectados
    en red (por ejemplo una impresora).

-   Compartir una conexión a Internet.

-   Conformar una Intranet con servicios como correo, *web*, ftp,
    *news*.

LAN
Este tipo de redes, es apropiada para conectar pocos computadores (menos
de 100) en un espacio relativamente pequeño.

Un protocolo [^red.1] es una serie de reglas que indican como debe ocurrir
una comunicación entre dos computadores de una red; las reglas de un
protocolo son seguidas por programas que se ejecutan en los computadores
interconectados. Su computador puede tener procesos activos que esperan
conexiones de otros computadores o procesos para iniciar protocolos (por
ejemplo con `ps -ax` es posible que vea: `sshd`, `inetd`, `httpd`,
`postgres`). A estos programas, que esperan conexiones, se les llama
servicios[^red.2]. Usted puede iniciar un protocolo con otro computador
empleando el programa cliente adecuado, por ejemplo el cliente `ping`
con:

        ping 127.0.0.1

iniciará el protocolo de ping (`ICMP`, `ECHO_REQUEST`) con el computador
con dirección IP 127.0.0.1 (su propio computador), un programa de su
computador estará pendiente de conexiones de este tipo y seguirá el
protocolo[^red.3].

Dado que estamos en paso de IPv4 a IPv6 también mencionamos que el mismo
ejemplo con IPv6 (y protocolo ICMP6) es:

        ping6 ::1

protocolo
Conjunto de reglas que determinan como se realiza la comunicación entre
computadores conectados a una red.

Internet es una red mundial de redes que están interconectadas vía
satélite, por cables submarinos, fibra óptica y muchos otros medios de
transmisión financiados por estados y organizaciones. Las heterogeneidad
de las redes que interconecta (e.g una LAN de un colegio con Linux, una
LAN de una ONG con OpenBSD, una WAN de un banco con X.25) es superada
con los protocolos TCP/IP. Para facilitar la conexión de una LAN a
Internet, en esta sección se presenta una introducción a los aspectos de
redes de Internet; los temas introducidos serán tratados en detalle en
otras secciones aplicándolos especialmente al caso de redes Ethernet
(ver [xref](#dispositivos_de_interconexion),
[xref](#direcciones_enrutamiento_transporte_y_cortafuegos) y [xref](#protocolos_de_soporte_y_de_usuario)).

## Internet {#Internet}

Hay muchas personas que aportan su trabajo (muchos de forma voluntaria)
para mantener Internet en funcionamiento, para solucionar problemas que
ocurren y para planear su futuro. Quienes dirigen el rumbo de Internet
están organizados en comités encargados de diversas actividades:

IETF Internet Engineering Task Force

:   Compuesta enteramente de voluntarios autoorganizados que colaboran
    en la ingeniería requerida para la evolución de Internet, es decir
    identifican problemas y proponen soluciones. Quien lo desee puede
    participar, asistir a las reuniones, ayudar a dar forma o proponer
    estándares. La IETF recibe borradores (*Internet Draft*) de autores
    que renuncian al control del protocolo que proponen. Tras
    refinamiento estos borradores pueden llegar a ser RFC (*Request for
    Comment*) de uno de estos tipos: estándar propuesto, protocolo
    experimental, documento informativo o estándar histórico. Un
    estándar propuesto puede después convertirse en borrador de estándar
    y en casos muy contados en estándar de Internet.

ISOC Internet Society

:   Organización sin ánimo de lucro, da soporte legal y financiero a
    otros grupos.

IESG Internet Engineering Steering Group

:   Ratifica o corrige estándares propuestos por la IETF.

IAB Internet Architecture Board

:   Planeación a largo plazo y coordinación entre las diversas áreas.

IANA Internet Assigned Numbers Authority

:   Mantienen registros de diversos nombres y números asignados a
    organizaciones. Es financiado por ICANN (*Internet Corporation for
    Assigned Names and Numbers*).

LACNIC Registro de Direcciones de Internet para América Latina y CaribeRegistro de Direcciones de Internet para América Latina y Caribe

:   Es responsable de la asignación y administración de los recursos de
    numeración de Internet (IPv4, IPv6), Números Autónomos y Resolución
    Inversa, entre otros recursos para la región de América Latina y el
    Caribe. Es uno de los 5 Registros Regionales de Internet en el
    mundo.

La interconexión de las redes conectadas a Internet y su mantenimiento
se basa en el protocolo IP, que asigna a cada red y a cada computador un
número único (dirección IP) que permite identificarlo y enviarle
información.

La asignación de direcciones IP[^red.4] es manejada por IANA, que a su vez
la ha delegado a registros en diversas regiones. La región de América
Latina es manejada por el registro LACNIC, que recibe solicitudes para
asignar bloques a proveedores de servicio a Internet (ISP) o usuarios,
estos proveedores deben contar con la infraestructura para conectar sus
computadores a Internet (e.g con cables submarinos, vía satélite) y a su
vez ofrecen bloques de direcciones y conexión a otros proveedores o a
usuarios.

Dada que la comunicación de dos computadores es un proceso complejo (aún
más dada la variedad de redes conectadas a Internet), además de una
basta infraestructura física, Internet se basa en varios protocolos que
siguen todos los computadores y enrutadores conectados. Algunos de estos
protocolos dependen de otros, dando lugar a varias capas de protocolos:
aplicación, transporte, Internet, enlace[^red.5]. El siguiente diagrama
presenta algunos protocolos en las diversas capas de una red TCP/IP
sobre una red física Ethernet o sobre una conexión con modem:

    Capa de aplicación:
         Protocolos de usuario             FTP Telnet ssh   http   SMTP ...
                                            |     |     |      |    | 
         Protocolos de soporte    DNS       |     |     |      |    | 
                                 |   \      |     |     |      |    |
    Capa de transporte           UDP   TCP --------------------------
                                  \  /
    Capa de Internet (red):      IP -  ICMP                  
                                 ___|___
                                /       \
    Capa de enlace:           ARP        PPP
                               |          |
    Capa física:           Ethernet     Modem
                            |              | 
                         Par trenzado    Línea telef.

## Capas de una red TCP/IP sobre algunos medios físicos

### Capa física

física
Esta capa de red se refiere a conexiones eléctrica y mecánicas de la
red. Por ejemplo codificiación/decodificación de información y
arbitramento en caso de coliciones.

Se refiere a las conexiones eléctricas y mecánicas de la red. Ejemplos
de protocolos a este nivel son: Ethernet, Inalámbrico IEEE 802.11, Modem
y fibra óptica. La información por transmitir se codifica en últimas
como una señal electríca que debe transmitirse por cables o como una
señal electromagnética (luz, ondas). En medios de transmisión
compartidos por más computadores (Ethernet, fibra óptica, aire), el
protocolo de este nivel debe tener en cuenta:
codificación/decodificación de información del bus al medio de
transmisión y arbitrar en caso de colisión de datos. Este tipo de
protocolos es implementado por hardware, comúnmente por una tarjeta o
dispositivo dedicado que se debe conectar al bus de cada computador. Las
tarjetas de los computadores que se comunican se conectan empleando el
medio de transmisión. OpenBSD, a nivel físico soporta dispositivos
ethernet, fddi (fibra óptica) y conexiones inalámbricas. En caso
particular de Ethernet, existen en el momento de este escrito estándares
para 10Mbps, 100Mbps, 1Gbps y 10Gbps, que se emplean en topología de
estrella (i.e. todos los computadores conectados por cables de pares
trenzados a un concentrador), puede configurarse como *Half-duplex* o
como *Full-Duplex*. Describiremos el uso del esquema más popular y
económico en este momento: 100Mbps, Full-duplex con cable de pares
trenzados [^red.6]. Cada tarjeta Ethernet tiene una dirección única (llamada
dirección MAC), que en una transmisión permite indicar tarjeta fuente y
tarjeta destino (la dirección MAC de ambos es transmitida también).

### Capa de enlace

ARP
En el caso de redes Ethernet e IPv4 la capa de enlace corresponde al
protocolo ... Este protocolo permite traducir direcciones IPv4 a
direcciones MAC.

Los protocolos de esta capa permiten interconectar la capa de internet
(IP) con la red que se use.

En el caso de una red Ethernet e IPv4 se trata del protocolo ARP[^red.7], y
que se encarga de traducir direcciones IPv4 a direcciones MAC [^red.8].

Cada vez que un computador de una LAN identifica una dirección IPv4 de
otro computador conectado a la LAN y su correspondiente dirección ARP,
almacena la información en una tabla (se borra automáticamente después
de algunos minutos o manualmente por ejemplo con
`doas arp -d 192.168.2.2`). La tabla puede consultarse con `arp -a`.

Para monitorear una red Ethernet e IPv4 y detectar nuevos computadores
que se conecten, puede emplearse el programa arpwatch (paquete
`arpwatch`) que cada vez que detecta cambios envía un correo a la cuenta
root.

En el caso de IPv6 y Ethernet se empa el portocolo NDP (Neighbor
Discovery Protocol). Puede examinarse la tabla de vecinos con `ndp -a`

En el caso de una conexión por modem el protocolo es PPP[^red.9], que se
encarga de establecer, terminar y verificar la conexión. Durante la
conexión autentica el computador que se conecta ante el servidor (bien
con el protocolo PAP o con CHAP) y durante la operación prepara los
paquetes enviados por otros protocolos (como IP) para transmitirlos por
modem.

### Capa de internet

IP
Este protocolo fragmenta y envia información empleando la capa física.
Cada computador se identifica con un número de 4 bytes (en la versión 4
de este protocolo).

En esta capa la información es fragmentada y envíada empleando el
protocolo de la capa física. Los protocolos de esta capa deben tener en
cuenta la retransmisión de la información en caso de error al enviar y
el verificar información recibida. En esta capa está el *Internet
Protocol* (IP) que es un protocolo diseñado para Internet y del cual hay
dos versiones: IPv4 e IPv6. Describiremos la versión 4 [^red.10] (la versión
6 fue diseñada para soportar más computadores conectados a Internet y se
espera que pronto se use ampliamente [^red.11]).

Este protocolo permite la transmisión de paquetes (llamados datagramas)
en redes donde cada computador interconectado se identifica con una
dirección única. Tales direcciones están diseñadas para interconectar
varias redes, identificar los computadores que pertenecen a una red
(empleando una máscara de red que indica que parte de la dirección del
computador corresponde a la dirección de la red) y facilitar el
enrutamiento. Si el medio de transmisión lo requiere, el protocolo IP se
encarga de la división de los datagramas en paquetes más pequeños para
su tranmisión y de la posterior reagrupación (fragmentación), el tamaño
máximo que un paquete puede tener para un protocolo de nivel físico se
llama MTU (*Maximal Transfer Unit*), en el caso de Ethernet es 1500
bytes.

Cada datagrama por transmitir es pasado a la capa de IP por otro
protocolo de una capa superior (e.g TCP) junto con dirección destino, IP
mantiene una tabla de enrutamiento que asocia direcciones destino con
compuertas (computadores intermediarios en inglés *gateways*). Así que
envía el datagrama empleando el nível físico a la dirección de la
compuerta que mantenga en su tabla de enrutamiento. La tabla de
enrutamiento puede ser modificada manualmente (con `route show`) o puede
ser modificada automáticamente cuando una compuerta envía un mensaje
indicando la dirección de otra compuerta más apropiada para llegar a un
dirección. Hay siempre una compuerta por defecto a la que se envían
paquetes que IP no sepa como enrutar.

route
Con este programa puede modificarse la tabla de enrutamiento del
protocolo IP.

IP no es protocolo fiable, porque no asegura que un paquete llegue a su
destino y no realiza retransmisiones. Aunque para informar algunas
situaciones anomalas emplea el protocolo ICMP [^red.12].

ICMP
Este protocolo es empleado por IP para transmitir mensajes de error y
para realizar algunas consultas para verificar el funcionamiento de una
red o medir (e.g eco, estampilla de tiempo).

OpenBSD cuenta con una excelente implementación de IPv4 con posibilidad
de filtrar, redirigir, traducir direcciones, balancear carga y muchas
otras opciones que se configuran de forma sencilla con PF. Además
implementa características no estándar como IPsec para transmisión
encriptada y IPcomp para comprimir.

### Capa de transporte

TCP
En Internet este protocolo está en la capa de enlace, se encarga de
procurar una conexión continua, libre de errores.

Los protocolos de esta capa asegura una conexión continua y posiblemente
libre de errores entre emisor y receptor. Un protocolo de esta capa debe
tener en cuenta mantener los paquetes en orden y asegurar que están
completos. Esto se requiere porque el nivel de red puede enrutar
diversos paquetes de forma diferente. En esta capa hay dos protocolos:
TCP[^red.13] y UDP[^red.14]. El primero es fiable, asegura que la transmisión
enviada sea recibida, UDP por su parte no busca confirmar que la
información llegue a su destino (aunque permite hacer difusión[^red.15] y
multidifusión[^red.16] mientras que TCP no). Ambos protocolos emplean
puertos para permitir más de una conexión con uno o más computadores, un
puerto se identifica con un número entre 0 y 65536, los primeros 1024
números sólo pueden ser usados por servidores iniciados desde la cuenta
root, los demás pueden ser usados por todos los usuarios.

/proc/net/tcp
En este archivo pueden examinarse conexiones a puertos TCP.

doas pfctl -sa
Permite examinar entre otras, conexiones a puertos TCP y UDP.

Puede examinar información sobre conexiones a puertos TCP y UDP con
`doas pfctl -sa`

### Capa de aplicación

Consta de protocolos empleados por aplicaciones con propósitos
específicos. Emplean los protocolos de la capa de transporte para
establecer comunicación. Los protocolos de esta capa pueden dividirse a
su vez en protocolos de usuario y protocolos de soporte. Los primeros
son para programas empleados directamente por usuarios y los segundos
son empleados por el sistema operativo o por otros protocolos.

#### Protocolos de usuario

Telnet

:   Telnet está definido en el RFC 854 y complementado en el RFC 1123.
    Permite la operación remota de otro computador de forma insegura
    pues las claves se transmiten planas (ssh es un remplazo seguro, ver
    [xref](#servidor-ssh)), además puede usarse para interactuar con
    otros protocolos (por ejemplo puede interactuar con el protocolo de
    correo SMTP de su propio computador ---puerto 25--- con
    `telnet localhost 25`).

(*File Transfer Protocol*) FTP

:   FTP está definido en el RFC 959 y complementado en el RFC 1123,
    permite transmisión de archivos de manera insegura pues las claves
    se transmiten planas (ver [xref](#servidor-ftp)).

TFPT

:   Está definido en el RFC 1350 (*Trivial File Transfer Protocol*), es
    análogo a FTP pues permite transmitir archivos, aunque es mucho más
    simple, es apropiado para transmitir el sistema operativo a
    computadores sin disco duro que arrancan por red.

SMTP

:   SMTP se definió en el RFC 822 y se complementó en el RFC 1123
    (*Simple Mail Transfer Protocol*) que especifica como se realiza la
    transmisión de correo electrónico (ver [xref](#servicios-correo)).

#### Protocolos de soporte

DNS

:   Definido en los RFC 1034 y 1035 y complementado en el RFC 1123. Es
    empleado para dar nombres descriptivos a direcciones IP (e.g
    structio.sourceforge.net es el nombre DNS de la dirección
    216.34.181.96).

BOOTP

:   Empleado por un computador en el que no ha iniciado el sistema
    operativo para solicitar su dirección IP a un servidor de este
    protocolo.

SMMP

:   Empleado para monitorear uso de una red.

## Lecturas recomendadas {#lecturas-redes-protocolos-internet}

-   Puede consultar más sobre el IETF y otras organizaciones que
    mantienen Internet en [taioetf](#biblio) y en [osietf](#biblio).

-   Puede consultar los RFC en [rfceditor](#biblio). También puede
    consultar versiones en castellano en [rfces](#biblio)

-   Páginas del manual netintro4, ip4, inet4, ip4

[^red.1]: Para ampliar el significado de los términos técnicos introducidos
    en estas guías (como *protocol*), se sugiere consultar el
    diccionario FOLDOC <http://foldoc.doc.ic.ac.uk/foldoc>

[^red.2]: También suele llamárseles *daemons* pero como puede resultar
    ofensivo para cristian@s, procuramos no emplear ese término, ver
    [](http://aprendiendo.pasosdejesus.org/?id=Renombrando+Daemon+por+Service).

[^red.3]: El programa que sigue este protocolo hace parte de la
    implementación de IPv4 en el kernel.

[^red.4]: Puede verse más sobre asignación de IPs en el RFC 2050 y sobre
    asignación de direcciones in redes IP privadas en RFC 1918.

[^red.5]: El RFC 1122 presenta las capas de una red TCP/IP

[^red.6]: El estándar que define este esquema es IEEE 802.3, que se basa en
    el uso de un sólo medio de transmisión compartido por todos los
    dispositivos en el que sólo trasmite un sólo dispositivo durante un
    tiempo para evitar colisiones, se elige el siguiente dispositivo por
    transmitir con el algoritmo CSMA/CD --cuando un dispositivo detecta
    que la línea está libre transmite parte de la información si detecta
    colisión da oportunidad de transmisión a otros un intervalo
    aleatorio de tiempo.

[^red.7]: ARP que se define en el RFC 826

[^red.8]: Un computador envía un mensaje a todos los demás de la red
    (*broadcast* que es posible en Ethernet), solicitando la dirección
    MAC de una dirección IPv4, el dispositivo con esa MAC responde
    enviando su dirección MAC al dispositivo que hizo la solicitud.

[^red.9]: PPP se describe en el RFC 1661.

[^red.10]: El protocolo IPv4 está descrito en el RFC 791, aunque puede verse
    una descripción en conjunto con otros protocolos en el RFC 1122

[^red.11]: OpenBSD tiene soporte para IPv6

[^red.12]: ICMP Internet Control Message Protocol, se describe en el RFC792,
    permite enviar mensajes de error (e.g dirección inalcanzable, tiempo
    excedido) y algunos mensajes para hacer consultas (e.g eco,
    estampilla de tiempo).

[^red.13]: TCP se describe en el RFC 793 y se complementa y corrige en el
    RFC 1122

[^red.14]: UDP está descrito en el RFC 768 y corregido en el RFC 1122

[^red.15]: Del inglés *broadcast*

[^red.16]: Del inglés *multicast*
