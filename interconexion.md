# Dispositivos de interconexión {#dispositivos_de_interconexion}

Durante el arranque, OpenBSD detecta la gran mayoría de
dispositivos conectados a un computador.  Una vez en operación
puede examinar la detección con ```dmesg```.

Si durante el arranque algún dispositivo no es detectado
o es detectado incorrectamente, puede intentar hacer modificaciones
durante el arranque iniciando con ```bsd -c``` cuando
esté en el prompt de arranque del programa ```boot```
(ver [usuario_OpenBSD](#biblio)).

## Conexión con un módem nulo {#modem-nulo}

Para conectar una terminal a un sistema OpenBSD puede emplearse un módem
nulo. La terminal puede ser un computador con OpenBSD o con cualquier
otro sistema operativo y un programa que permita ver la información que
llegue a un puerto serial y enviar la que se teclee (por ejemplo sirven
varios programas para comunicarse vía módem).

### Módem Nulo {#modem-nulo-hardware}

Un módem nulo es un cable serial que tiene en sus extremos dos
conectores hembra para puerto serial y que intercambia algunas
conexiones. Si ambos conectores son de 25 pines, todos los cables deben
estar sueltos excepto:

-   (DSR) 6 & (DCD) 8 -- 20,

-   (TxD) 2 -- 3,

-   (RxD) 3 -- 2,

-   (RTS) 4 -- 5,

-   (CTS) 5 -- 4,

-   (SG) 7 -- 7,

-   (DTR) 20 -- 6 & 8.

En un conector de 9 pines la nomenclatura es: 1 DCD, 2 TxD, 3 RxD, 4
DTR, 5 SG, 6 DSR, 7 RTS y 8 CTS.

Un módem nulo mínimo sólo requiere que se conecten SG - SG (tierra), TxD
- RxD (transmisión de uno con recepción del otro) y RxD - TxD. Sin
embargo para poder efectuar control de flujo también deben conectarse
los demás.

Aunque en el comercio es posible comprar un módem nulo, también es
relativamente fácil ensamblar uno, una vez tenga conectores, cable y
cautín. Si hace su propio módem nulo puede probar que la conexión haya
quedado bien empleando un ohmiometro.

Una vez se conecte un módem nulo puede probarlo enviando mensajes por el
puerto serial del uno y viendo lo que recibe en el otro. Por ejemplo si
conecta dos sistemas OpenBSD empleando en ambos el primer puerto serial,
en uno de los dos puede ejecutar (como usuario `root`)

        cat < /dev/cua00

mientras que en el otro ejecute

        cat > /dev/cua00

cuando escriba en el segundo y presione ENTER, en el primero recibirá el
mensaje y líneas en blanco (`cat` no es el programa apropiado para
establecer la comunicación, sólo para probar).

### Servidor

Con un módem nulo conectado y funcionado puede configurarse un sistema
OpenBSD como servidor para que permita conectar terminales a un puerto
serial. Debe configurarse el programa `init` para que durante el
arranque ejecute un programa que reciba conexiones por el puerto serial
(tal programa normalmente es `getty`).

Basta editar el archivo `/etc/ttys`, quitar el comentario a la línea
apropiada para que quede:

        tty00   "/usr/libexec/getty std.9600"   vt220 on secure

Después puede reiniciar el sistema o reiniciar `init` con:
`kill -HUP 1`.

En la línea modificada a `/etc/ttys`, `tty00` se refiere a `/dev/tty00`
(i.e el dispositivo del primer puerto serial);
`/usr/libexec/getty std.9600` es la orden por ejecutar al arranque
para manejar ese dispositivo[^dis.1]; `vt220` indica el tipo de terminal que
se conectará; `on` y `secure` son banderas[^dis.2] para `init`, el primero
indica que se esperan conexiones por esa línea tty y el segundo indica
que puede iniciar conexiones el usuario root.

### Terminal {#Terminal}

Una vez conectado su módem nulo a un servidor OpenBSD ya configurado
para recibir conexiones por el puerto serial, puede conectar una
terminal.

Si la terminal cuenta con un sistema operativo, puede emplear un
programa de comunicaciones. Con este debe poder ver los mensajes de
login del servidor. Desde ahí puede entrar como un usuario de ese
sistema y trabajar como en una de las consolas virtuales (sin ambiente
X).

Si el computador que va a conectar es un sistema OpenBSD puede emplear
el programa `tip` como usuario root:

        tip tty0 

Es posible que tenga que intentar varias veces, si configura el servidor
con una velocidad diferente puede especificarla por ejemplo con
`tip -38400 tty0`

`tip` empleará la descripción de `tty0` disponible en `/etc/remote` (que
por defecto está configurado para representar el primer puerto serial).
Le permitirá ver la información que el servidor envíe, enviar
información al servidor y hacer algunas operaciones especiales
comenzando con el carácter '\~'. Por ejemplo terminar la sesión con
'\~.', enviar un archivo con '\~p' o recibir un archivo con '\~g'.

Dado que puede haber inconvenientes enviando o recibiendo archivos de 8
bits, los archivos (especialmente binarios) que envíe o reciba con `tip`
debe codificarlos antes con `uuencode` y decodificarlos después de
transmitidos con `uudecode`. Para codificar un archivo `prog.tgz` y
dejarlo codificado en `prog.tgz.uue`:

        uuencode prog.tgz < prog.tgz > prog.tgz.uue

posteriormente para decodificarlo:

        uudecode prog.tgz.uue

El inconveniente del método descrito es que `tip` no verifica la
información transmitida. Una alternativa es emplear un protocolo como
Zmodem. Para eso instale tanto en cliente como en servidor el paquete
`zmtx-zmrx` (o `lrzsz`). Cuando desee transmitir un archivo del servidor
al cliente, inicie la transmisión en el servidor:

        zmtx Mattich2.pdf

y en el cliente desde `tip` use `~C zmrx`. Para enviar un archivo del
cliente al servidor ejecute en el servidor: `zmrx` y después desde `tip`
use: `~C zmtx miarchivo.txt`

### PPP sobre Módem Nulo {#ppp-sobre-modem-nulo}

Una vez esté conectado un cliente con un servidor OpenBSD, es posible
emplear el protocolo PPP[^dis.3] para permitirle al computador cliente
acceder a Internet o a la red a la que esté conectado el servidor.

Una forma posible para lograr conectividad a Internet en una Intranet es
asignando una dirección estática de la red al cliente y empleando el
servidor para que actúe como proxy a nivel ARP.

En el servidor asegúrese de tener en el archivo `/etc/ppp/ppp.conf`:

        default:
          set log Phase Chat LCP IPCP CCP tun command
          set device /dev/cua00
          set speed 115200
          set ctsrts on
          set dial ""
        
        modemnulo:
          set timeout 0
          set lqrperiod 10
          enable proxy
          enable lqr
          accept lqr
          allow users SuLogin

Remplazando `SuLogin`, `SuClave` y las direcciones de red por las
apropiadas. Por su parte el archivo `/etc/ppp/ppp.conf` del cliente debe
contener:

        default:
         set log Phase Chat LCP IPCP CCP tun command
         set device /dev/cua00
         set speed 115200
         set ctsrts on
         set dial ""
        
        modemnulo:
          set dial ""
          set authkey SuClave
          set login "TIMEOUT 3 ogin:-\\r-login: SuLogin word: \\P $ ppp\\s\\-direct\\smodemnulo\\r"
          set lqrperiod 10
          set timeout 0
          set ifaddr 192.168.16.20 192.168.16.131
          add default HISADDR
          enable lqr
          accept lqr
          enable dns

Después pude iniciar la comunicación desde el cliente con:

        ppp -ddial modemnulo

### Referencias y lecturas recomendadas {#referencias-modem-nulo}

Puede consultar más sobre la conexión física de un módem nulo en
[CablesModemNulo](#biblio). Puede consultar sobre
comunicaciones seriales en FreeBSD (similar a OpenBSD) en el capítulo
"Serial Communications" de [FreeBSDHandbook](#biblio) Para
emplear un sistema OpenBSD mínimo como consola de algunos eventos de un
servidor OpenBSD puede consultar [SerialOpenBSD](#biblio). La
configuración del servidor OpenBSD que le permite atender conexiones por
el puerto serial puede verse en las siguientes páginas man: init 8, ttys
5 y getty 8. La configuración de un cliente OpenBSD para funcionar como
consola puede consultarse en: tip 1 y remote 5. Para conocer más sobre
PPP puede consultarse el [RFC
1661](ftp://ftp.rfc-editor.org/in-notes/rfc1661.txt), la implementación
particular de el protocolo de usuario en OpenBSD en la página del
manual. El archivo de configuración por defecto también cuenta con
comentarios que ayudan.

[^dis.1]: Como parámetro getty recibe características de la línea que deben
    estar especificadas en `/etc/gettytab`. En este caso `std.9600`
    especifica la velocidad de transmisión. Empleando un módem nulo con
    control de flujo es posible emplear velocidades mayores hasta
    `std.115200`.

[^dis.2]: banderas del inglés *flags*

[^dis.3]: PPP es un protocolo especificado en el RFC 1661.


## Conexión a Internet con un módem o módem ISDN {#modem-isdn}

Es posible conectar un sistema OpenBSD a Internet empleando un módem o
un módem ISDN. Para esto el módem que se emplea debe estar soportado y
debe configurarse `ppp` para realizar la conexión.

Hay diversos tipos de módems (tarjetas ISA, PCI, módems externos USB o
seriales), los módems externos que se conectan a puerto serial son los
más fáciles de configurar, algunos módems USB también son soportados
(los que tengan ordens y datos multiplexados --como indica la página
del manual del controlador `umodem`) y eventualmente es posible hacer
funcionar tarjetas ISDN ISA o PCI
([http://people.freebsd.org/~hm/i4b-home/](http://people.freebsd.org/~hm/i4b-home/)).

Los módems y los módems ISDN reciben ordens AT y se configuran
empleando `ppp`. Por ejemplo el archivo `/etc/ppp/ppp.conf` podría
incluir porciones como las siguientes (remplazando el número de
teléfono, el nombre de la cuenta y la clave por los correctos):

        default:
          set log Phase Chat LCP IPCP CCP tun command
          set device /dev/cua01
          set speed 115200
          set dial "ABORT BUSY ABORT NO\\sCARRIER TIMEOUT 5 \"\" AT \
            OK-AT-OK ATE1Q0 OK \\dATDT\\T TIMEOUT 40 CONNECT"
        
        
        PAP:
         set phone 019478909891 
         set authname micuenta@miproveedor.com
         set authkey laclaveusada
         set timeout 120
         add default HISADDR
         enable dns

Para conectarse ejecute `/usr/sbin/ppp -ddial PAP` desde una cuenta que
pertenezca al grupo `network`. Cuando se establezca la conexión quedará
asociada una dirección IP a una interfaz `tun` (e.g a `tun0`). Puede
también emplear el siguiente script para realizar la conexión:

        #!/bin/sh
        # Dominio público. 2004.
        
        # Usa configuracion de /etc/ppp/ppp.conf regla PAP
        
        netw=`groups | sed -e "s/.*network.*/1/g"`;
        if (test "$netw" != "1") then {
            echo "Para usar PPP debe ser del grupo network";
            exit 1;
        } fi;
        
        IP=`/sbin/ifconfig tun0 | tail -n 1 | sed -e "s/.*inet \([.0-9]*\) .*/\1/g"`;
        esta=`echo $IP | sed -e "s/^[0-9][.0-9]*$/SI/g"`
        if (test "$esta" = "SI") then {
            echo "Ya está conectado, IP es $IP";
            exit 0;
        } fi;
        /usr/sbin/ppp -ddial PAP
        while (test "$esta" != "SI") ; do
            sleep 1;
            IP=`/sbin/ifconfig tun0 | tail -n 1 | sed -e "s/.*inet \([.0-9]*\) .*/\1/g"`;
            esta=`echo $IP | sed -e "s/^[0-9][.0-9]*$/SI/g"`
        done
        
        echo "Conectado. La IP es $IP";

Y el siguiente que facilita la desconexión:

        pid=`ps ax | grep "[p]pp" | sed -e "s/^[ ]*\([0-9]*\) .*$/\1/g"`;
        espid=`echo $pid | sed -e "s/^[0-9][0-9]*$/SI/g"`;
        if (test "$espid" != "SI") then {
          echo "No está conectado";
          exit 1;
        } fi;
        kill -HUP $pid
        echo "Desconectado";


## Conexión a Internet ADSL con pppoe {#adsl-pppoe}

En Colombia los proveedores de acceso a Internet en planes de Banda
Ancha típicamente emplean dispositivos y configuraciones que permiten
conectar un computador como si fuera un equipo más en una red Ethernet.
En tal caso basta conocer la IP que tendrá el computador (o si se usará
dhcp), la mascara de red y la dirección de la puerta de enlace, y
configurar como se explica en la sección de redes LAN Ethernet (ver
[xref](#lan-ethernet).

Puede ocurrir que su proveedor emplee un módem que requiera el protocolo
`pppoe` (e.g con un Módem Marconi). En tal caso el proveedor puede
brindar dos opciones para la configuración del módem:

-   Enrutador (router): Se conecta a un HUB o a un computador y hace NAT
    para todos los computadores cliente conectados. En la LAN basta
    configurar la IP de cada equipo para que estén en la misma subred
    del enrutador y que cada uno emplee como compuerta/pasarela al
    módem.

-   Puente (bridge): En esta configuración se requiere un servidor que
    haga NAT y enrute.

Si el módem ADSL se conecta con un cable Ethernet y el proveedor ofrece
ppp, no debe configurarse la tarjeta de red, sino una interfaz nueva
tun0 Por esto en el archivo de configuración de la tarjeta digamos
`/etc/hostname.rl0` (reemplazar `rl0` con interfaz en su caso, examinar
posibles interfaces con `ifconfig`) deje:

        up
        

Edite `/etc/ppp/ppp.conf` (si no existe cópielo de
`/etc/ppp/ppp.conf.smaple`), para que quede una sección como la
siguiente:

        pppoe:
         set log Phase Chat LCP IPCP CCP tun command
         set redial 15 0
         set reconnect 15 10000
         set device "!/usr/sbin/pppoe -i rl0"
         set mtu max 1492
         set mru max 1492
         set speed sync
         disable acfcomp protocomp
         deny acfcomp
         enable lqr
         set lqrperiod 5
         set cd 5
         set dial
         set login
         set timeout 0
         set authname "usuario"
         set authkey "miclave"
         add! default HISADDR
         enable mssfixup
        

Cambiando la interfaz de red, el usuario y la clave. Podrá probar la
conexión con:

        ppp -ddial -nat pppoe
        

Si desea que en cada arranque se conecte automáticamente, tal como se
explica en
[http://www.aei.ca/\~pmatulis/pub/obsd\_pppoe.html](http://www.aei.ca/~pmatulis/pub/obsd_pppoe.html )
agregue a `/etc/rc.local`:

        IPADSL=$(netstat -rn | grep tun0 | grep ^[0-9] | awk '{print$2}')
        if [ -z "$IPADSL" ]; then
            echo -n "Estableciendo conexion PPPoE DSL"; ppp -ddial pppoe
            for i in 10 9 8 7 6 5 4 3 2 1 0; do 
                sleep 5             
                echo -n "$i"        
                IPADSL=$(netstat -rn | grep tun0 | grep ^[0-9] | awk '{print$2}')
                if [ -z "$IPADSL" ]; then
                        break
                fi                  
            done     
        fi

### Referencias y lecturas recomendadas {#referencias-pppoe}

Página del manual `pppoe`.

http://www.aei.ca/\~pmatulis/pub/obsd\_pppoe.html


## Uso y configuración en una red LAN Ethernet {#lan-ethernet}

La red local (LAN) Ethernet más simple puede conformarse con 2
computadores cada uno con tarjeta ethernet interconectados por un cable
UTP cruzado. Sin embargo típicamente una red ethernet consta de varios
computadores con tarjetas Ethernet interconectados por uno o más[^lan.1]
concentradores (también llamado *hub* o *switch*) y cables UTP directos
de cada computador a algún concentrador. La velocidad de la red depende
de la velocidad de las tarjetas de red, la velocidad de los
concentradores y la categoria de los cables. Esta velocidad se mide en
Megabits (millones de bits por segundo), y sus valores típicos son 10Mb,
100Mb, 1000Mb o 1Gb y recientemente 10Gb.

### Tarjetas Ethernet

La inmensa mayoría de tarjetas Ethernet de 10MB, 100MB y 1000MB, así
como algunas de 10G son soportadas por OpenBSD, la lista completa la
puede consultar en: <http://www.openbsd.org/amd64.html>. Por su parte
las tarjetas populares que hemos identificado como no soportadas son:
Encore ENL832-TX-RENT, Encore ENL832-TX-EN.

En cada computador, cada dispositivo de interconexión se asocia a una
interfaz de red cuando es detectado en el momento del arranque (o por
demanda como en el caso de `tun0`). Estas interfaces se administran con
`ifconfig`, por ejemplo para listarlas todas utilice:

        ifconfig -a

A continuación se presenta un ejemplo de la salida de esta orden:

        lo0: flags=8049<UP,LOOPBACK,RUNNING,MULTICAST> mtu 33160
            priority: 0
            groups: lo
            inet 127.0.0.1 netmask 0xff000000
            inet6 ::1 prefixlen 128
            inet6 fe80::1%lo0 prefixlen 64 scopeid 0x6
        re0: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            lladdr 00:14:d1:1a:cf:b2
            priority: 0
            groups: egress
            media: Ethernet autoselect (100baseTX full-duplex,rxpause,txpause)
            status: active
            inet 189.148.51.41 netmask 0xffffff00 broadcast 189.148.51.255
            inet6 fe80::214:d1ff:fe1a:cfb2%re0 prefixlen 64 scopeid 0x1
        re1: flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            lladdr 00:14:d1:1a:ce:93
            priority: 0
            media: Ethernet autoselect (1000baseT full-duplex)
            status: active
            inet 192.168.2.1 netmask 0xffffff00 broadcast 192.168.2.255
            inet6 fe80::214:d1ff:fe1a:ce93%re1 prefixlen 64 scopeid 0x2
        re2: flags=8802<BROADCAST,SIMPLEX,MULTICAST> mtu 1500
            lladdr 00:14:d1:1a:cf:af
            priority: 0
            media: Ethernet autoselect (10baseT half-duplex)
            status: no carrier
        vr0: flags=8843LGUP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
            lladdr 00:19:db:82:8f:93
            priority: 0
            media: Ethernet autoselect (100baseTX full-duplex)
            status: active
            inet 192.168.1.1 netmask 0xffffff00 broadcast 192.168.1.255
            inet6 fe80::219:dbff:fe82:8f93%vr0 prefixlen 64 scopeid 0x4
        enc0: flags=0LG> mtu 1536
            priority: 0
        pflog0: flags=141LGUP,RUNNING,PROMISC> mtu 33160
            priority: 0
            groups: pflog

Es como una tabla con 2 columnas, en la de la izquierda se lista el
nombre de la interfaz de red (en este ejemplo `lo0`, `re0`, `re1`,
`re2`, `vr0`, `enc0`, `pflog0`), y a la derecha las características de
cada interfaz, por ejemplo las características de la interfaz `re0` son:

        flags=8843<UP,BROADCAST,RUNNING,SIMPLEX,MULTICAST> mtu 1500
        lladdr 00:14:d1:1a:cf:b2
        priority: 0
        groups: egress
        media: Ethernet autoselect (100baseTX full-duplex,rxpause,txpause)
        status: active
        inet 189.148.51.41 netmask 0xffffff00 broadcast 189.148.51.255
        inet6 fe80::214:d1ff:fe1a:cfb2%re0 prefixlen 64 scopeid 0x1

Algunas de las interfaces corresponden a tarjetas de red (en este
ejemplo `re0`, `re1`, `re2` y `vr0`) mientras que otras son virtuales,
como `lo0` que representa el mismo computador, `enc0` que sirve para
cifrados con IPSec y `pflog0` que permite examinar en tiempo real
actividad del cortafuegos `pf`.

Con respecto a las propiedades de cada interfaz física, resaltamos

`status`

:   Puede ser `active` para indicar que hay cable conectado a la tarjeta
    en un extremo y el otro extremo está conectado a algún concentrador
    (o a otro computador si es cruzado). Note que en el ejemplo la
    interfaz `re2` no está conectada.

`lladdr`

:   Con la dirección MAC de la tarjeta de red (un número único para cada
    tarjeta fabricada).

`inet`

:   Propiedades IPv4, por ejemplo:

            inet 189.148.51.41 netmask 0xffffff00 broadcast 189.148.51.255

    Indica que la IP es 189.148.51.41, con mascara de red 255.255.255.0
    (en hexadecimal 255 es `ff`), y dirección para envíos masivos
    (broadcast) 189.148.51.255.

`inet6`

:   Propiedades IPv6, por ejemplo:

            inet6 fe80::214:d1ff:fe1a:cfb2%re0 prefixlen 64 scopeid 0x1

    Indica que la dirección IPv6 es `fe80::214:d1ff:fe1a:cfb2`

`media`

:   Que indica tipo de medio físico que está conectado o configurado en
    esa interfaz. En el ejemplo presentado las interfaces `re0` y `vr0`
    están operando a 100Mb (Megabit), mientras que la interfaz `re1`
    está operando a 1Gb (Gigabit).

`flags`

:   Que indica banderas que tiene activa la interfaz y la MTU (Unidad de
    transferencia máxima). Note que `lo0` es la única que tiene la
    bandera `LOOPBACK` la cual indica que esa interfaz es virtual y se
    refiere al mismo computador.

Los dispositivos reconocidos en el momento del arranque que se asocian a
interfaces de red, así como los que no logran configurarse, pueden verse
con:

        dmesg | less

Un ejemplo típico de una tarjeta Ethernet reconocida es:

        re0 at pci0 dev 8 function 0 "Realtek 8169" rev 0x10: RTL8169/8110SB (0x1000), apic 2 int 16 (irq 10), address 00:14:d1:1a:cf:b2

Note que se lista el nombre de la interfaz (i.e `re0`), los recursos de
hardware que emplea y la dirección MAC (i.e `00:14:d1:1a:cf:b2`).

OpenBSD incluye documentación completa para cada tipo de dispositivo
detectable (por ejemplo opciones); para el caso del controlador del
ejemplo anterior puede verse con:

        man re

### Configuración de una interfaz de red {#configuracion-interfaz}

Debe configurar cada interfaz de red en un archivo con un nombre de la
forma `/etc/hostname.interfaz`. Por ejemplo para el caso de la tarjeta
con controlador `re` e interfaz asignada por el kernel en el arranque
`re0`, seria `/etc/hostname.re0`.

Como se explica en `man hostname.if` en el caso de una red IPv4 con DHCP
basta que ese archivo tenga la línea:

        dhcp

Si el direccionamiento en la red local es estático, tal archivo debe
tener en una línea separados por un espacio los siguientes datos (en
este orden):

-   Familia de direcciones. Tìpicamente `inet`

-   IP (e.g `189.148.51.41`)

-   Mascara de red (e.g `255.255.255.0`)

-   Dirección de broadcast o la palabra `NONE`

-   Eventualmente opciones

La línea completa sería:

        inet 189.148.51.41 255.255.255.0 NONE

Un archivo como estos lo puede crear y/o editar con cualquier editor de
texto (por ejemplo `mg` o `vim`). Si tiene sesión de X-Window puede
emplear desde una terminal

        doas touch /etc/hostname.re0; doas xfw /etc/hostname.re0

Estas ediciones también las puede hacer en adJ con botón derecho sobre
el escritorio Dispositivos-&gt;Red-&gt;Configurar Interfaces, que le
permitirá editar cada uno de los archivos de cada interfaz de red
detectada por ifconfig (excepto lo0, enc0, pflog0, tun).

> **Advertencia**
>
> Es importante que la línea del archivo `/etc/hostname.re0` que
> configura sus propiedades IPv4, termine con el caracter fin de línea,
> es decir que en el editor con el que la edite termine la línea con la
> tecla RETORNO.

Y la IP de la compuerta de su red (ver [xref](#ipv4)) se configura en
`/etc/mygate` que también debe editar con su editor preferido y que
también debe terminar con fin de línea. Un ejemplo típico del contenido
sería una línea con:

        189.148.51.1

Con adJ puede hacer botón derecho sobre el escritorio
Dispositivos-&gt;Red-&gt;Configurar Puerta de Enlace.

Después de hacer cambios a la configuración de red es posible que pueda
reiniciar el sistema de redes con:

        doas sh /etc/netstart

aunque en algunos casos es necesario reiniciar el computador.

Note que si ha cambiado una tarjeta de red es posible que antes de
reinicar debe reconfigurar el cortafuegos en el archivo `/etc/pf.conf`

### Protocolo ARP

La tabla del protocolo ARP asocia direcciones físicas de tarjetas de red
conectadas a su red con direcciones IP. Para examinar tal tabla use:

        arp -a 

es posible agregar entradas de manera permanente o eliminarlas con las
opciones `-s` y `-d` respectivamente.

### Cableado de una red local {#cableado}

#### Planeación

Necesitará un concentrador preferiblemente de 1Gb con suficientes
puertos para todos los computadores que tenga o varios interconectados
en cascada, cable UTP categoria 5e o 6 con conectores RJ-45 y en cada
computador deberá tener una tarjeta Ethernet (preferiblemente de 1GB)
con un puerto para un conector RJ-45 (ver [Configuración de una interfaz
de red](#configuracion-interfaz)).

El espacio físico en el que esté la red será la primera restricción que
debe tener en cuenta. Haga un plano de ese espacio con las distancias a
escala, ubique los computadores y diseñe el recorrido de los cables al
concentrador. Hay varias recomendaciones que puede tener en cuenta al
diseñar el mapa:

-   Es aconsejable por estética y seguridad que los cables vayan por
    canaletas.

-   La longitud máxima de cada cable (para unir concentrador y
    computador) es de 100 m.

    100
    Longitud máxima de un cable entre un computador y un concentrador en
    una red Ethernet.

-   Busque que los cables/canaletas vayan por las paredes del recinto y
    estén resguardadas (para evitar que alguien se tropiece).

En el mapa que haga también puede consignar las direcciones IP que
planee usar en cada computador. Emplee direcciones asignadas para redes
privadas, por ejemplo 192.168.1.1 al servidor y los clientes
192.168.1.2, 192.168.1.3 y así sucesivamente. Cómo compuerta emplee en
todos los clientes la dirección del servidor y como máscara de red
emplee `255.255.255.0` (ver [xref](#ipv4) ).

#### Adquisición de Hardware {#adquisicion-de-hardware}

Para hacer la adquisición de Hardware tenga en cuenta:

-   Los nombres de los componentes pueden variar de un almacén a otro,
    algunos sinónimos son:

    -   tarjeta ethernet, tarjeta con conectores RJ45

    -   concentrador o *hub* o *switch* repetidor

    -   cable de pares trenzados, par trenzado, twisted pair, cable
        Ethernet, UTP (*Unshielded Twisted Pair*).

-   Use el plano de red para determinar la longitud de cada cable,
    recuerde que todo computador debe tener un cable que lo una con el
    concentrador (compre un poco más de la longitud que midió pues al
    intentar ensamblar los conectores podría perder algo de cable en
    cada intento).

-   El concentrador debe tener suficientes puertos para todos los
    computadores (pueden ponerse varios concentradores en cascada).

-   Cada computador debe tener una tarjeta de red Ethernet
    preferiblemente 1Gb que pueda usar desde OpenBSD (ver [Configuración
    de una interfaz de red](#configuracion-interfaz)) ---recordar que
    las más incompatibles son las populares Encore.

-   Cada cable debe tener dos conectores RJ-45. Uno para conectarlo al
    computador y el otro para conectarlo al concentrador. (Compre varios
    conectores RJ-45 adicionales pues al intentar ensamblar podría
    perder algunos).

    RJ45
    Este es el tipo de conectores que debe ir en cada extremo de un
    cable UTP en una red Ethernet como la que sugerimos.

#### Instalación {#instalacion-de-cables-y-concentrador}

Una vez tenga instaladas las tarjetas de red debe conectar los cables a
tales tarjetas y al concentrador. Como eventualmente usted mismo hará
los cables, en esta sección damos instrucciones para que le resulte
fácil el proceso. Requerirá unas pinzas especiales [^lan.2] para conectores
RJ-45 y un probador (*tester*) para comprobar que fluye corriente en los
cables que haga.

Ubique en el espacio para la red los computadores y los cables
(verifique que las medidas de su plano hayan sido correctas).

Ponga en cada extremo de cada uno de los cables un conector RJ-45
empleando unas pinzas especiales. Como el cable UTP se compone de 8
cablecitos de colores tenga en cuenta:

Deje entre 8mm y 12 mm de los 8 cables al descubierto. [^lan.3]

Al preparar los cables tenga en cuenta que las tarjetas de 100MB y
1000MB requieren un orden especial de los cables que conforman un UTP 5,
UTP 5e o UTP 6, si no aplica este orden, con algunos cables de varios
metros puede tener problemas de comunicación (ni siquiera podrá resolver
ARP). En redes de 10MB y 100MB puede usar cualquier de estos tipos de
cables, pero para redes de 1000MB debe usar UTP 5e o UTP 6. Hay dos
secuencias estandarizadas para los cables que conforman un UTP 5/5e/6,
de las cuales la más común es la TIA/EIA-568-B:

-   Para cables directos (que unen por ejemplo un computador a un
    concentrador), los dos extremos del cable se ponen en el conector
    RJ-45 siguiendo la misma secuencia: 1 - blanco/naranja, 2 - naranja,
    3 - blanco/verde, 4 - azul, 5 - blanco/azul, 6 - verde, 7 -
    blanco/cafe, 8 - cafe

-   Para un cable cruzado (que permite unir dos computadores o en
    algunos casos 2 concentradores): Lado 1: 1 - blanco/naranja, 2 -
    naranja, 3 - blanco/verde, 4 - azul, 5 - blanco/azul, 6 - verde, 7 -
    blanco/cafe, 8 - cafe. Lado 2: 1 - blanco/verde, 2 - verde , 3 -
    blanco/naranja, 4 - blanco/cafe, 5 - cafe, 6 - naranja, 7 - azul,
    8 - blanco/azul.

Empareje los 8 cablecitos antes de intentar ponerlos en el conector
RJ-45. Pongalos en el orden antes indicado para cables directos.

El conector RJ45 tiene varios canales, por cada uno de esos canales debe
pasar un cablecito de color. Empuje bien los cablecitos hasta el fondo
del conector RJ-45 y con las pinzas especiales baje los contactos del
conector y asegure el cable.

Después de ensamblar el primer extremo verifique con un probador que
todos los cablecitos hagan contacto. Después ensamble el segundo extremo
empleando la misma secuencia de colores y después verifique que estén
haciendo buen contacto con un probador.

Una vez tenga los cables verifique que la tarjeta de red de cada
computador esté bien instalada (algunas tienen luces [^lan.4] que se
encienden cuando transmite o recibe información por el cable), y conecte
con cables todas las tarjetas al concentrador.

Verifique también que cada tarjeta de red sea reconocida por el kernel y
asigne la IP que planeó para cada una (ver [Configuración de una
interfaz de red](#configuracion-interfaz)).

Finalmente verifique la instalación transmitiendo paquetes de un
computador a otro. Por ejemplo desde el servidor (tal vez con IP
192.168.1.1) intente conectarse a un cliente (tal vez IP 192.168.1.2)
con `ping` :

        ping 192.168.1.2    

y viceversa.

### Referencias {#referencias-lan}

-   FAQ de OpenBSD Sección 6.

-   Páginas `man` de `arp`, `route`, `ifconfig`, `hostname.if`

-   Sobre cables Ethernet puede consultarse en [ethernet_cables](#biblio)

[^lan.1]: Pueden ponerse concentradores en cascada.

[^lan.2]: En Colombia a tal "pinza especial" se le conoce como "ponchadora".

[^lan.3]: Pablo Chamorro nos indicó que "algunas pinzas tienen un tope,
    entonces al colocar las puntas de los cables junto al tope, el corte
    de la envoltura del cable siempre se realiza en el mismo punto para
    que ni sobre ni falte y así no hay que preocuparse por estimar el
    punto de corte."

[^lan.4]: Luces es traducción de *LED (Light emitting diode)*.


## Red Local Inalámbrica: uso y configuración {#red-inalambrica}

Las redes inalámbrica emplean ondas electromagnéticas transmitidas por
aire, por lo que no se requieren cables, aunque el rango de alcance es
limitado por el tipo de antenas que se empleen y los obstáculos (sin
antenas especiales piense en menos de 50 metros con línea de vista y
menos cuando hay paredes y otros obstáculos).

Para redes locales los protocolos más utilizados son IEEE 802.11a,
802.11b y 802.11g, que emplean rangos del espectro electromagnético
(como 2.4GHz) los cuales pueden usarse sin requerir permiso en Colombia
y dan tasas de transferencia entre 11Mbps y 54Mbps.

Una red local inalámbrica requiere un Punto de Acceso Inalámbrico (en
inglés *Acces Point*) que atienda peticiones y de respuestas a todos los
computadores cliente que se conecten. Tal Punto de Acceso Inalámbrico
puede ser un dispositivo dedicado o bien un computador con OpenBSD que
cuente con una tarjeta de inalámbrica que soporte el modo `hostap`.

### OpenBSD como cliente en una red inalámbrica {#cliente-inalambrico}

Hay una amplia gama de tarjetas de red inalámbricas (tanto PCI, como
USB) con controladores para OpenBSD, sin embargo varias tarjetas de red
populares no son soportadas, por lo que antes de comprar examine el
listado de tarjetas soportadas en:
<http://dhobsd.pasosdejesus.org/?id=CompatibilidadHardware>. Una vez
conecte su tarjeta de red inalámbrica, búsque la interfaz de red
asociada con

        ifconfig

o algunos detalles de lo que se ve del hardware con

        dmess | less

Por ejemplo una Intel PRO/Wireless se ve así:

        wpi0 at pci3 dev 0 function 0 "Intel PRO/Wireless 3945ABG" rev 0x02: irq 10, MoW1, address 00:1b:77:d6:52:ee

y una D-Link USB típica se ve:

        rum0 at uhub0 port 5 "Ralink 802.11 bg WLAN" rev 2.00/0.01 addr 2
        rum0: MAC/BBP RT2573 (rev 0x2573a), RF RT2528, address 00:1e:58:b0:db:68

En algunos casos OpenBSD incluye el controlador completo de fuentes
abiertas para a la tarjeta (por ejemplo `rum0`) pero en otros es
necesario descargar firmware adicional (por ejemplo `wpi0`). Vea la
página del controlador para encontrar detalles, por ejemplo en el caso
de `wpi0` al examinar `man wpi` se ve que esta tarjeta requiere firmware
adicional que debe instalar con:

        doas pkg_add http://damien.bergamini.free.fr/packages/openbsd/wpi-firmware-3.2.tgz

Después de tener controlador completo puede buscar redes inalámbricas
cercanas con

        doas ifconfig rum0 scan 

remplazando `rum0` por la interfaz de su tarjeta. Verá un listado de
redes próximas con identificación, calidad de la señal, velocidad y tipo
de encripción.

Para conectarse a una red basta configurar la tarjeta con la
identificación, tipo de encripción y clave apropiadas y posteriormente
asignar una IP en la red inalámbrica, bien manualmente o bien por DHCP
si el Access Point lo soporta (como ocurre típicamente). Para configurar
a una red de nombre MIRED que no emplea encripción:

        doas ifconfig rum0 nwid MIRED 

Si la red emplea encripción WEP (un mecanismo de encripción débil),
puede especificar la llave de encripción en hexadecimal:

        doas ifconfig rum0 nwid MIRED nwkey 0x123498a2d2

o en ASCII:

        doas ifconfig rum0 nwid MIRED nwkey "clave"

Si la red emplea encripción WAP (un mecanismo de encripción más fuerte):

        doas ifconfig rum0 nwid MIRED wpakey MICLAVE

Después puede examinar nuevamente con `ifconfig` si ya se ve estado
Activo en la interfaz de red lo cual le confirma que logró conexión y
posteriormente puede establecer la IP bien manualmente si conoce el
segmente de red:

        ifconfig rum0 192.168.1.15

o bien automáticamente si el Acess Point soporta DHCP con:

        doas dhclient rum0

Tras esto al examinar con `ifconfig` se ve algo como:

        rum0: flags=8c43<UP,BROADCAST,RUNNING,OACTIVE,SIMPLEX,MULTICAST> mtu 1500
                lladdr 00:1e:58:b0:db:68
                priority: 4
                groups: wlan egress
                media: IEEE802.11 autoselect (OFDM36 mode 11g)
                status: active
                ieee80211: nwid MIRED chan 1 bssid 00:02:6f:5f:f8:6a 117dB nwkey <not displayed> 100dBm
                inet 192.168.44.50 netmask 0xffffff00 broadcast 192.168.44.255
                inet6 fe80::21e:58ff:feb0:db68%rum0 prefixlen 64 scopeid 0x6

Si requiere conectarse en cada arranque del computador configure en
`hostname.rum0` (cambiando rum0 por su interfaz). Por ejemplo si tiene
una IP fija con:

        inet 192.168.44.50 255.255.255.0 NONE nwid "MIRED" nwkey "clave"

o si requiere DHCP:

        dhcp NONE NONE NONE nwid "MIRED" nwkey "0x1112131415"

o si es WPA con DHCP:

        dhcp nwid "MIRED" wpakey "clave"

El tráfico de red inalámbrico puede examinarse con el paquete `kismet`,
el cual tiene un archivo de configuración (`/etc/kismet.conf`) en el que
debe especificarse el controlador usado.

### Dispositivo dedicado que obra como Punto de Acceso Inalámbrico {#dispositivo-AP}

Estos dispositivo cuentan con una antena (típicamente pequeña) para la
red inalámbrica y un conector para cable Ethernet que se conecta a la
red cableada, la cual típicamente va a Internet.

Normalmente los dispositivos que obran como Punto de Acceso Inalámbrico
(Acces Point) cuentan con un servicio de configuración que opera sobre
HTTP por lo que pueden conectarse a un computador y emplear un navegador
web.

Para conectarlo a un computador basta que ponga un cable Ethernet sin
cruzar entre ambos y que ambos estén en el mismo segmento de red con IPs
diferentes. La IP inicial de su Punto de Acceso Inalámbrico seguramente
la podrá ver en el manual del usuario (típicamente es 192.168.0.1 o
192.1681.1.1 con máscara de red 255.255.255.0). Para determinar la IP de
un Punto de Accesos Inalámbrico también puede intentar conectándolo a un
computador y usando `tcpdump` para examinar el tráfico que pasa por la
interfaz de red a la cual conecte el Punto de Acceso Inalámbrico.

Una vez determine la IP del Punto de Acceso Inalámbrico ponga el
computador con el que configurará en el mismo segmento de red. Por
ejemplo si el Access Point tiene IP 192.168.1.1 y lo conectó a la
interfaz `rl0`, configure esa interfaz de red por ejemplo con:

        ifconfig rl0 192.168.1.2 

tras lo cual ya debe poder ejecutar:

        ping 192.168.1.1

obtener respuesta del Punto de Acceso Inalámbrico y configurarlo
abriendo en un navegador el URL `http://192.168.1.1`.

El Punto de Acceso Inalámbrico normalmente obrará como enrutador y hará
NAT a una nueva red que será independiente de la red cableada a la cual
lo conecte. Por ejemplo si lo conecta por cable Ethernet a una red con
IPs 192.168.190/24, podrá enrutar y hacer NAT a otra red como la
192.168.1/24. Algunos Puntos de Acceso Inalámbricos (como el EnGenius
EOC 1650) soportan un modo puente que permite distribuir con DHCP
algunas direcciones de la misma red cableada. Esto tiene la ventaja de
dejar tanto la red inalámbrica como la cableada en el mismo segmento de
red.

Las particularidades de configuración de cada Punto de Accesso
Inalámbrico varían de un modelo a otro, pero normalmente debe
especificar:

-   IP, máscara de red, puerta de enlace y servidor DNS en la red
    cableada.

-   IP, máscara de red y rango de direcciones por repartir en la red
    inalámbrica.

### OpenBSD como Punto de Acceso Inalámbrico {#PAI}

Si cuenta con una tarjeta de red inalámbrica con controladores para
OpenBSD y que soporte el modo `hostap` (como puede consultar en la
página del manual del controlador) es sencillo configurar un Punto de
Acceso Inalámbrico, continuando las instrucciones de la sección [OpenBSD
como cliente en una red inalámbrica](#cliente-inalambrico).

Supongamos que su tarjeta esta asociada a la interfaz `ath0`, que desea
emplear el segmento 192.168.3/24, llamar a la red CASA con encripción
WEP y clave "uvwxy". Basta que en `/etc/hostname.ath0` configure:

        inet 192.168.3.1 255.255.255.0 NONE media autoselect \
        mediaopt hostap nwid CASA chan 11 nwkey "uvwxy"

Tras esto desde los portatiles y computadores cercanos debe poder ver la
red CASA y conectarse con WEP y la clave uvwxy.

### Referencias {#referencias-wlan}

-   Páginas `man` de `ifconfig`, `wpi`

-   Ver [wndw](#biblio)


