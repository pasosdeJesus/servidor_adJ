
# Direcciones, enrutamiento, transporte y cortafuegos {#direcciones_enrutamiento_transporte_y_cortafuegos}

## Introducción a TCP/IPv4 {#ipv4}

En una red TCP/IPv4, cada computador tiene como identificación una
dirección IP única. Esta dirección consta de 32 bits, y suele escribirse
como 4 números/bytes separando unos de otros por punto (cada uno es un
número entre 0 y 255), por ejemplo 66.35.250.209. Cómo TCP/IP se diseño
para interconectar redes, una dirección IP consta de una parte que
identifica de forma única la red y otra que identifica de forma única el
computador dentro de la red. Una máscara de red determina que parte
identifica la red y cuáles computadores en la red puede denotarse con el
número de bits del comienzo de la dirección que identifican la red (e.g
16 si los primeros 16 bits identifican la red) o como otra dirección que
al hacer la operación lógica y con la dirección IP dará la dirección de
red (por ejemplo 255.255.0.0 es una máscara que indica que los primeros
16 bits de una dirección IP son la dirección de red).

mascara de red
Indica que parte de una dirección IP corresponde a la dirección de red.

Al diseñar una red debe escogerse una dirección de red junto con la
máscara de acuerdo al número de computadores, algunas posibilidades son:

/8 o 255.0.0.0

:   16777216 computadores

/12 o 255.242.0.0

:   1048576 computadores

/16 o 255.255.0.0

:   65536 computadores

/24 o 255.255.255.0

:   255 computadores

Cuantos computadores pueden instalarse en una red con mascara de red /24
o 255.255.255.0.

Además la dirección de red que escoja debe ser única para no producir
conflictos con otras redes en caso de conectarse a Internet y puede
facilitar la interconexión de diversas redes y el enrutamiento al
interior de una organización. La labor de asignación de direcciones IP
en una red local la puede hacer un administrador de red o puede hacerse
dinámicamente con el protocolo DHCP.

Para facilitar la adopción de redes TCP/IPv4 en organizaciones, el RFC
1918 destinó algunas direcciones de red para usar al interior de
organizaciones (no puede haber computadores en Internet con esas
direcciones):

10.0.0.0 - 10.255.255.255

:   máscara /8

172.16.0.0 - 172.31.255.255

:   máscara /12

192.168.0.0 - 192.168.255.255

:   máscara /16

Por ejemplo en su red local puede emplear direcciones entre 192.168.1.1
y 192.168.1.255 con máscara de red /24 o 255.255.255.0. O en caso de
contar con más redes en la misma organización, la segunda con
direcciones entre 192.168.2.1 y 192.168.2.255 y así sucesivamente.
Además de usar direcciones privadas, se facilita el crecimiento de la
infraestructura de redes y la configuración del enrutamiento entre unas
y otras.

### Tabla de Enrutamiento {#tabla-enrutamiento}

Como se presentó en la descripción de las capas en redes TCP/IP (ver
[xref](#redes_protocolos_e_internet)), el
protocolo IP mantiene una tabla de enrutamiento que asocia direcciones
de red con compuertas, es decir con computadores conectados a la misma
red que pueden retransmitir información a la red destino. En una red de
área local no es necesario configurarla, pero si se requiere por ejemplo
para interconectar varias redes de área local en una misma organización.

Puede ver la tabla de enrutamiento estático en con `route -n show` o con
`netstat -r`. Entre los campos de cada entrada de esta tabla están: red
destino, puerta de enlace, banderas, uso, MTU, interfaz por la cual
enviar/recibir paquetes con ese destino,

Hay un destino por defecto (`default`) al que se envía todo paquete que
no tiene un destino en la tabla de enrutamiento. Este destino por
defecto o puerta de enlace se configura en el archivo `/etc/mygate`. En
una red local conectada a Internet, el servidor debe emplear como puerta
de enlace la que le haya dado el proveedor de Internet, y cada
computador de la red local debe emplear la IP del servidor.

De requerirse pueden agregarse compuertas con `route add` por ejemplo,
para agregar una ruta a la red 192.168.2.0/24 usando como compuerta
192.168.1.60 que está en la misma red:

    doas route add 192.168.2/24 192.168.1.60
         

Y pueden eliminarse de forma análoga con `route
      delete`.

Para determinar problemas de enrutamiento o en general de la red, puede
emplear algunas herramientas de diagnóstico por ejemplo:

`traceroute`

:   Presenta las direcciones de los computadores y enrutadores que
    transmiten un paquete hasta llegar a su destino. Por ejemplo

        traceroute 192.168.2.2

    traceroute
    Este programa permite rastrear la ruta que sigue un paquete para
    llegar a su destino.

`netstat -s`

:   Éste presenta estadísticas sobre IP, ICMP y TCP

`arp -an`

:   Que presenta direcciones MAC junto con IPs asociadas

`tcpdump`

:   Permite analizar el tráfico de una red TCP/IP. Desde la cuenta root
    puede usarse este programa para examinar todo el tráfico que circule
    por una red. Por ejemplo para verificar lo que se transmite por la
    interfaz re0:

        doas tcpdump -i re0 -n -ttt
             

    tcpdump
    Permite analizar el tráfico de una red TCP/IP.

### Otros aspectos de configuración de redes en OpenBSD {#configuracion-OpenBSD}

Fuera de las tablas de enrutamiento y ARP, la funcionalidad de redes a
nivel de kernel se puede controlar con:

`/etc/hosts`

:   En este archivo se listan nombres asociados a la dirección IP de
    algunos computadores, por ejemplo:

        127.0.0.1       localhost
        192.168.1.1    &ESERV; &ENOMSERV;
                 

`sysctl`

:   Para configurar algunas variables del kernel relacionadas con redes.
    Los cambios pueden hacerse permanentes modificando el archivo
    `/etc/sysctl.conf`. Resaltamos la variable `net.inet.ip.forwarding`
    que debe activarse para que un sistema opere como enrutador.

pf

:   Que permite controlar el tráfico de paquetes en el kernel y por
    tanto controlar la funcionalidad de cortafuegos[^dir.1]. Se configura de
    manera permanente en el archivo `/etc/pf.conf` (o el archivo
    especificado en la variable `pf_rules` de `rc.conf.local` o
    `rc.conf`). Para que `pf` entre en operación en cada arranque del
    sistema, agregue a `rc.conf.local` la línea:

        pf=""

    Una vez esté operando si hace cambios al archivo de configuración
    puede lograr que reinicie y vuelva a leerlo con:

        doas pfctl -f /etc/pf.conf
                

    El archivo de configuración `/etc/pf.conf` tiene una sintaxis
    bastante entendible que permite definir variables y tablas.

Las secciones de este capítulo explican algunas configuraciones típicas
que pueden hacerse con pf y los correspondientes cambios a su archivo de
configuración.

[^dir.1]: Cortafuego del inglés *firewall*


## NAT (Network Address Translation) {#nat}

Puede emplear NAT para que un computador conectado a una red privada y
que se conecte a Internet, sea pasarela de los computadores de la red
interna y así estos puedan emplear Internet.

Para activarlo debe estar corriendo `pf` (como se explica al comienzo de
este capítulo) y debe activar reenvío de IP con:

        doas sysctl -w net.inet.ip.forwarding=1

o mejor aún de manera más permanente verificando que el archivo
`/etc/sysctl.conf` tenga la línea:

        net.inet.ip.forwarding=1    

Como el computador que hará NAT debe tener dos interfaces de red una
para conectarlo a la red interna (con IP de la red interna) y otra para
conectarlo a Internet (con IP pública). En el archivo `/etc/pf.conf`
configure las variables `ext_if` e `int_if` con los nombres de las
interfaces externa (conectada a Internet) e interna respectivamente
(verifiquelas antes con `ifconfig`). Por ejemplo un archivo de
configuración mínimo que hace NAT, suponiendo que la interfaz interna es
`fxp0` y la externa es `nfe0` es:

        int_if="fxp0"
        ext_if="nfe0"
        
        set skip on lo
        
        match out on $ext_if from !($ext_if) nat-to ($ext_if:0)
	pass out on $ext_if proto {icmp, tcp, udp} all keep state
        
        pass in quick on $int_if

Esta configuración podría cargarse con:

        doas pfctl -f /etc/pf.conf.

NAT es sigla de "Network Address Translation" (Traducción de direcciones de red)
lo que hace es "traducir" las direcciones privadas de la red interna 
a la dirección pública del cortafuegos 
para que el cortafuegos haga la petición a su nombre y la respuesta que 
reciba la vuelve a traducir a la dirección privadaen la red interna
para enviarla al computador de la red interna que corresponde.

Una vez realizada, un computador en la red interna debería poder ejecutar

	ping 8.8.8.8 

y recibir respuesta.

Mientras se hace el ping en en computador de la red interna, si en el 
cortafuegos se examinara el tráfico de la interfaz interna:
	
	doas tcpdump -i fxp0 -n host 8.8.8.8

Se verían peticiones como

	07:09:59.262358 192.168.44.93 > 8.8.8.8: icmp: echo request (DF)

y al examinar en otra terminal el tráfico de la interfaz conectada a Internet 
(`doas tcpdump -i nfe0 -n host 8.8.8.8`) se verían
las mismas peticiones pero con la dirección traducida, por ejemplo:

	07:09:59.262414 182.188.122.211 > 8.8.8.8: icmp: echo request (DF)

Las respuestas en la interfaz externa se verían como:

	07:09:59.359408 8.8.8.8 > 182.188.122.211: icmp: echo reply

y en la interfaz interna se vería nuevamente traducidas como:

	07:09:59.359474 8.8.8.8 > 192.168.44.93: icmp: echo reply


### Referencias y lecturas recomendadas {#referencias-nat}

Las siguientes páginas man: pf 4, pfctl 4.

Guía del usuario de PF [PF](#biblio).


## Cortafuegos: filtrado y túneles {#cortafuegos}

Un cortafuegos permite filtrar tráfico que puede llegar o salir a un
computador conectado a una red como Internet.

El siguiente ejemplo muestra parte del archivo `/etc/pf.conf` para que
permita toda conexión que salga de la red privada hacia Internet, y para
que bloquee toda conexión que llegue excepto tráfico TCP por los puertos
para ssh (22) y dns (53), también permite llegada de tráfico UDP por el
puerto 53 y tráfico ICMP (para responder `ping`). Suponemos que ya se
han configurado las variables `int_if` y `ext_if` con las interfaces de
red interna y externa respectivamente:

        servicios_tcp="{ssh,domain}
        servicios_udp="{domain}"
        servicios_icmp="echoreq"

        block in log all
        pass out keep state

        pass quick on { lo $int_if }
        antispoof quick for { lo $int_if }

        pass in on $ext_if inet proto tcp from any to ($ext_if) \
        port $servicios_tcp keep state
        pass in on $ext_if inet proto udp from any to ($ext_if) \
        port $servicios_udp keep state
        pass in inet proto icmp all icmp-type $servicios_icmp keep state

Si tiene un servidor interno (por ejemplo en una DMZ con IP 192.168.2.2)
y necesita que este preste servicios visibles al exterior como: web
(80), https (443), imaps (993), smtp (25) y ldap (389), deberá
establecer un túnel para cada uno de estos puertos, de forma que las
conexiones que lleguen al cortafuegos sean redirigidas al servidor
interno. El siguiente ejemplo presenta como puede hacerse:

        serv_ip="192.168.2.2"
        servicios_serv="{ldap,smtp,www,https,imaps, 389}"

        match in on $ext_if proto tcp from any to any port www rdr-to $serv_ip port www
        match in on $ext_if proto tcp from any to any port https rdr-to $serv_ip port https
        match in on $ext_if proto tcp from any to any port 993 rdr-to $serv_ip port 993
        match in on $ext_if proto tcp from any to any port smtp rdr-to $serv_ip port smtp
        match in on $ext_if proto tcp from any to any port 389 rdr-to $serv_ip port 389


        pass in on $ext_if proto tcp from any to $serv_ip port $servicios_serv \
        flags S/SA synproxy state

### Referencias y lecturas recomendadas {#referencias-cortafuegos}

Las siguientes páginas man: pf 4, pfctl 4.

Guía del usuario de PF [PF](#biblio).


## ftp-proxy: para usar ftp desde la red interna {#ftpproxy}

Las características del protocolo ftp hacen que sea difícil emplearlo
desde una red interna con un cortafuegos que hace NAT. pf ofrece
facilidades para lograrlo en conjunto con el programa
`/usr/sbin/ftp-proxy` que redirige conexiones ftp a su destino y
automáticamente agrega reglas a pf que permitan la conexión.

El siguiente ejemplo ejemplifica parte del archivo `/etc/pf.conf` para
esto:

        # En la sección nat/rdr
        pass on $int_if proto tcp from $lan to any port 21 
        match in on $int_if proto tcp from $lan to any port 21 rdr-to 127.0.0.1 port 8021
        
        # En la sección de reglas de filtrado
        pass out proto tcp from $ext_ip to any port 21

> **Advertencia**
>
> Para emplear ftp-proxy asegúrese que entre las reglas de su
> cortafuegos no esté:
>
>         set skip $int_if
>
> porque esto impediría la redirección al puerto 8021 (por defecto usado
> por ftp-proxy) del cortafuegos cuando se hacen peticiones de ftp.

Además de las reglas del cortafuegos (recuerde reiniciar pf con
`pfctl -f /etc/pf.conf` para que surtan efecto) debe iniciar el proxy
con:

        /usr/sbin/ftp-proxy

y para que se efectúe en cada arranque del servidor agregar a
`/etc/rc.conf.local`:

        ftpproxy_flags=""

### Referencias y lecturas recomendadas {#referencias-ftpproxy}

Las siguientes páginas man: ftp-proxy 8, pf 4.

Guía del usuario de PF [PF](#biblio).


## Ejemplo del uso de PF en una DMZ {#ejemplopf}

De las secciones anteriores resultaría un archivo `/etc/pf.conf`
(adaptado de la Guía de PF) como el siguiente:

        # Recordar poner net.inet.ip.forwarding=1 and/or net.inet6.ip6.forwarding=1
        # en /etc/sysctl.conf 
        
        ext_if="dc1"  # Cambiar por interfaz externa
        int_if="dc0"  # Cambiar por interfaz interna
        
        int_ip="192.168.1.1"  # Cambiar por dirección en LAN
        ext_ip="200.93.171.42"  # Cambiar por IP pública
        
        # LAN. Segmento de red
        lan="192.168.1/24"  
        
        # Servicios que presta cortafuegos
        servicios_tcp="{ssh,domain}" 
        servicios_udp="{domain}" 
        servicios_icmp="echoreq"
        
        # Servidor interno
        serv_ip="192.168.2.2"
        servicios_serv="{ldap,smtp,www,https,imaps}"
        
        
        set block-policy return
        set loginterface $ext_if
        
        set skip on {lo enc0}
        scrub in all
        
        match out on $ext_if from !($ext_if) nat-to ($ext_if:0)
        
        block in log all 
        pass out keep state
        pass quick on { lo }
        antispoof quick for { lo $int_if }
        
        pass in on $int_if proto tcp from $lan to any port ftp
        pass out proto tcp from $ext_ip to any port 21
        
        match in on $int_if proto tcp from $lan to any port ftp rdr-to \
            127.0.0.1 port 8021
        
        pass in quick on $int_if
        
        match in on $ext_if proto tcp from any to any port 80 rdr-to \
            $serv_ip port 80
        match in on $ext_if proto tcp from any to any port 443 rdr-to \
            $serv_ip port 443
        match in on $ext_if proto tcp from any to any port 993 rdr-to \
            $serv_ip port 993
        match in on $ext_if proto tcp from any to any port smtp rdr-to \
            $serv_ip port smtp
        match in on $ext_if proto tcp from any to any port 389 rdr-to \
            $serv_ip port 389 
        
        match in on $ext_if proto tcp from any to any port 10022 rdr-to \
            $serv_ip port 22
        pass on $ext_if proto tcp from any to any port 10022 
        
        match in on $ext_if proto tcp from any to any port 10465 rdr-to \
            $serv_ip port 465
        pass on $ext_if proto tcp from any to any port 10465 
        
        
        pass in on $ext_if inet proto tcp from any to ($ext_if) \
            port $servicios_tcp keep state
        pass in on $ext_if inet proto udp from any to ($ext_if) \
            port $servicios_udp keep state
        pass in inet proto icmp all icmp-type $servicios_icmp keep state
        
        pass in on $ext_if proto tcp from any to $serv_ip port $servicios_serv \
            flags S/SA synproxy state

### Referencias y lecturas recomendadas {#referencias-ejemplopf}

Guía del usuario de PF [PF](#biblio).


## Control de ancho de banda

El siguiente ejemplo presenta cómo puede configurarse un servidor NAT
para controlar ancho de banda de diversos computadores de la red
interna. La conexión de la red interna es a 100MB, mientras que la
conexión a Internet es de 300KB. De todos los computadores de la red
interna el ancho de banda se limita sólo a 4 computadores, cada uno
máximo 30KB. Los demás comparten el resto del ancho de banda.

        table <interna> {192.168.2.2, 192.168.2.1, 192.168.1.1, 192.168.1.8, 192.168.1.21, 192.168.1.23, 192.168.1.30, 192.168.1.31, 192.168.1.37, 192.168.1.40, 192.168.1.41, 192.168.1.42, 192.168.1.43, 192.168.1.95, 192.168.1.70}
        
        set loginterface $int_if
        set fingerprints "/etc/pf.os"
        
        altq on $int_if bandwidth 100Mb cbq queue { dflt_in, uext1_in, uext2_in, uext3_in, uext4_in}
        altq on $ext_if bandwidth 300Kb cbq queue { dflt_out }
        
        queue dflt_in cbq(default) bandwidth 80%
        queue dflt_out cbq(default)
        
        queue uext1_in bandwidth 30Kb
        queue uext2_in bandwidth 30Kb
        queue uext3_in bandwidth 30Kb
        queue uext4_in bandwidth 30Kb
        
        uext1="192.168.1.70" 
        uext2="192.168.1.23" 
        uext3="192.168.1.95"
        uext4="192.168.1.30"
        
        match out on $ext_if from <interna> to any nat-to ($ext_if)
        
        pass  out on $int_if from any to $uext1 queue uext1_in
        pass  out on $int_if from any to $uext2 queue uext2_in
        pass  out on $int_if from any to $uext3 queue uext3_in
        pass  out on $int_if from any to $uext4 queue uext4_in

### Referencias y lecturas recomendadas {#referencias-control-ancho-banda}

Las siguientes páginas man: pf 4, pfctl 4.

Guía del usuario de PF [PF](#biblio).

