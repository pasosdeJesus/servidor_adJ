# Protocolos de soporte y de usuario {#protocolos_de_soporte_y_de_usuario}

## Servicio DNS {#servidor-dns}

### Resolución de nombres {#resolucion-de-nombres}

Para resolver nombres, OpenBSD emplea rutinas propias de resolución
incluidas en la librería de C, se configuran en `/etc/resolv.conf`. Este
archivo puede incluir, dominio (`domain`), lista de servidores
(`nameserver`), orden de fuentes donde buscar (`lookup`), lista de
dominios en los cuales buscar (`search`), retornar direcciones IP en
orden (`sortlist`), opciones (`options`). Un ejemplo del archivo
`/etc/resolv.conf` es:

        search &EDOMINIO;
        nameserver 192.168.16.1
        lookup file bind

`lookup` permite especificar un orden para hacer resolución de acuerdo a
uno o más de los siguientes argumentos separados por espacio:

-   `bind` que indica usar servidor de nombres (`named`)

-   `file` que indica buscar en `/etc/hosts`

-   `yp` que indica emplear el sistema YP si `ypbind` está corriendo.

### Servidor recursivo unbound {#unbound}

Un servidor recursivo recibe consultas de dominios y las reenvía a otros
servidores –comenzando por los servidores raíz– o si tiene respuesta a
las consultas en su repositorio temporal fresco (cache) lo usa para
responder. Es útil para responder consultas de una red local
rápidamente, y en tal caso debe responder consultas que se hagan desde
la red interna pero no desde Internet --como posiblemente ocurre con la
vista recursiva del archivo `/var/named/etc/named.conf` si tiene uno.

A continuación explicamos como configurar unbound (que hace parte del
sistema base desde OpenBSD y adJ 5.7) como servidor recursivo.

En `/etc/rc.conf.local` agregue

        unbound_flags="-c /var/unbound/etc/unbound.conf"

Y a la variable `pkg_scripts` agréguele `unbound` Configúrelo en
`/var/unbound/etc/unbound.conf`, cambiando al menos:

1.  Si su cortafuegos tiene en la red interna la IP 192.168.100.100
    responda sólo a esa interfaz:

        interface: 192.168.100.100

2.  Permita consultas desde la red interna, añadiendo:

        access-control: 192.168.100.0/24 allow

3.  Las zonas autoritarias que `nsd` esté sirviendo también debe
    responderlas de manera autoritaria con unbound pero dirigiendo a la
    red interna, por ejemplo respecto al ejemplo de la sección anterior,
    suponiendo que en la red Interna el servidor que responde correo es
    192.168.100.101:

            local-zone: "miescuela.edu.co." static
            local-data: "correo.miescuela.edu.co. IN A 192.168.100.101"
            local-data: "ns1.miescuela.edu.co. IN A 192.168.100.100"
            local-zone: "100.168.192.in-addr.arpa." static
            local-data-ptr: "192.168.100.101 correo.miescuela.edu.co."
            local-data-ptr: "192.168.100.100 ns1.miescuela.edu.co."

Inicie el servicio con

        sudo sh  /etc/rc.d/unbound start

Revise posibles errores en las bitácoras `/var/log/messages` y
`/var/log/servicio`

Pruebe que responde con:

    dig @192.168.100.100 correo.miescuela.edu.co

que debería dar la IP privada.

Si prefiere examinar con más detalle puede iniciarlo para depurar con:

        unbound -c /var/unbound/etc/unbound.conf -vvvv -d

### Servidor autoritario con NSD {#nsd}

Desde adJ y OpenBSD 5.7 hace parte del sistema base junto con `unbound`
(que vinieron a remplazar `named`). Usa una configuración basada en la de
named por lo que es sencilla la migración.

Agregue a `/etc/rc.conf.local` la línea:

        nsd_flags="-c /var/nsd/etc/nsd.conf"

e incluya `nsd` en la variable `pkg_scripts`

El archivo de configuración principal ubíquelo en
`/var/nsd/etc/nsd.conf`, por cada zona maestra que maneje de manera
autoritaria (es decir cada zona master en la vista `view "authoritative`
de `/var/named/etc/named.conf`) incluya líneas de la forma:

        zone:
            name: "miescuela.edu.co"
            zonefile: "miescuela.edu.co"

Para que responda hacía Internet en un cortafuegos con IP pública
(digamos 200.201.202.203) en el mismo archivo asegúrese de dejar:

        ip-address: 200.201.202.203

En el directorio `/var/nsd/zones` debe dejar un archivo de zona por cada
zona que configure. Afortunadamente NSD reconoce la misma sintaxis de
archivos de zona que `bind`, así que basta que copie los de las zonas
autoritarias (que típicamente se ubican en `/var/named/master/`).

Un ejemplo de un archivo de zona `/var/nsd/zones/miescuela.edu.co` es:

        $ORIGIN miescuela.edu.co.
        $TTL 6h
        
        @ IN SOA ns1.miescuela.edu.co. root.localhost. (
            2 ; Serial
            1d ; Refresco secundario
            6h ; Reintento secundario
            2d ; Expiración secundaria
            1d ) ; Cache 
        
                 NS ns1
                 A  200.201.202.203
               MX 5  correo.miescuela.edu.co.
        correo A  200.201.202.203
        ns1    A  200.201.202.203
        *        A  200.201.202.203

Si tiene zonas secundarias (esclavas) puede crear el directorio
`/var/nsd/zones/secundaria/`, copiar allí las zonas de
`/var/named/slave/` y en el archivo de configuración de NSD agregar
secciones del siguiente estilo:

        zone:
                name: "miotrozona.org"
                zonefile: "secundaria/miotrazona.org"
                allow-notify: 193.98.157.148 NOKEY
                request-xfr: 193.98.157.148 NOKEY             

Inicie el servicio con

        doas sh  /etc/rc.d/nsd start

(o reinícielo con `restart` en lugar de `start`).

Revise posibles errores en las bitácoras `/var/log/messages` y
`/var/log/servicio`

Pruebe que responde desde Internet con:

        dig @200.201.202.203 correo.miescuela.edu.co

que debería dar la IP pública.

### named

OpenBSD aún incluye como paquete el servidor BIND 9, bajo el nombre
`named`, que por defecto corre con `chroot` en el directorio
`/var/named` y que puede hacer las labores de unbound y nsd.

Puede configurarse y probarse antes de iniciarlo en cada arranque. Para
configurarlo por primera vez pueden seguirse primero los pasos de
`/etc/rc`. El archivo de configuración es `/var/named/etc/named.conf`.
Se sugiere que se agregue información de zonas de las cuales es maestro
en en archivos del directorio `/var/named/master`. Pueden configurarse
archivos como dice en [AA_Linux](#biblio) por ejemplo los datos un
servidor DNS primario del dominio &EDOMINIO; pueden quedar en el archivo
`/var/named/master/&EDOMINIO;`:

        $TTL 1D
        @ IN  SOA  @  root.localhost. (
            03091025 ; Serial
            1D   ; Refresco secundario
            6H   ; Reintento secundario
            2D   ; Expiración secundaria
            1D ) ; Cache de registro de recursos
        
            NS  @
        
            A       65.8.9.234
        
            MX      5      correo.&EDOMINIO;.
        
        correo  IN      A       201.2.3.74
        ns1     IN      A       201.2.3.74
        www     IN      A       201.2.3.74

Note que se declara el mismo dominio como servidor de nombre
autoritario, se relaciona con la IP (65.8.9.234), el nombre
`correo.&EDOMINIO;` identificara la misma máquina y es el nombre que se
usará para intercambiar correos; el nombre `www.&EDOMINIO;` será un alias
para el mismo servidor. Note que todo nombre que no termine con punto
(.), será completado por `bind` con el dominio (i.e `www` será
completado a `www.&EDOMINIO;`, si se olvida el punto después de
`correo.&EDOMINIO;`, `bind` lo completará a `correo.&EDOMINIO;.&EDOMINIO;`).
Recuerde aumentar el número serial cada vez que haga algún cambio, para
que la información pueda ser actualizada en los servidores secundarios.
Puede probar cada archivo de zonas que haga con:

        named-checkzone &EDOMINIO; /var/named/master/&EDOMINIO;

Agregue una referencia al archivo de zonas maestro en
`/var/named/etc/named.conf`, en la sección para zonas maestras algo de
la forma:

        zone "&EDOMINIO;" {
          type master;
          file "master/&EDOMINIO;";
        }

Si desea que un servidor sea secundario de algún servidor primario,
agregue en `/var/named/etc/named.conf` en la sección para zonas esclavas
algo como:

        zone "&EDOMINIO;" {
          type slave;
          file "slave/&EDOMINIO;";
          masters { 65.8.9.234; };
        }

Cuando `named` lea de nuevo sus archivos de configuración traerá la
información del servidor primario y la dejará en el archivo
`/var/named/slave/&EDOMINIO;`.

El servidor se inicia con

        doas sh /etc/rc.d/named start

Los errores que se produzcan antes de hacer `chroot` son enviados a
`/var/log/servicio`. Para probar el funcionamiento antes de modificar
`/etc/resolv.conf` puede usar:

        dig @localhost &EDOMINIO;

Si requiere volver a leer los archivos de configuración (por ejemplo
después de cambiar los archivos de zonas) puede enviar la señal `SIGHUP`
al proceso con:

        pkill -HUP named

o con

        rndc reload

Una vez compruebe que su servidor DNS está operando correctamente puede
indicar que se inicie en cada arranque agregando a `/etc/rc.conf.local`:

        named_flags="" 

y en el mismo archivo en la definición de `pkg_scripts` agregando
`named`.

#### Vistas para resolver nombres interna y externamente {#vistas}

Si cuenta con una LAN conectada a Internet por medio de un cortafuegos
con OpenBSD que maneja el DNS de su organización y si además cuenta con
una DMZ tal que las peticiones a algunos puertos del cortafuegos son
redirigidas a uno o más servidores, seguramente tendrá inconvenientes al
resolver nombres de su dominio en la LAN, pues el nombre de su
organización (digamos &EDOMINIO;) será resulto a la dirección externa, la
cual conectará al cortafuegos por el puerto pedido y tratará de
redirigir la conexión al servidor en la DMZ (i.e se reflejará). Por este
motivo desde su LAN en general no resolverá nombres de su dominio.

Una solución (ver `/var/named/etc/named-dual.conf`) es configurar bind
para que tenga dos vistas, una para computadores fuera de la LAN y otra
para computadores dentro de la LAN. Un posible archivo de configuración
(basado en los distribuidos con OpenBSD) es:

        acl clients {
            localnets;
            ::1;
        };
        options {
            version "";     
            listen-on    { any; };
            listen-on-v6 { any; };
            allow-recursion { clients; };
        };
        logging {
            category lame-servers { null; };
        };
        
        view "internal" {  // Para la red interna
            match-clients { clients; };
            match-recursive-only yes;
            recursion yes;
        
            zone "." {
                type hint;
                file "standard/root.hint";
            };
            zone "localhost" {
                type master;
            file "standard/localhost";
            allow-transfer { localhost; };
            }
            zone "127.in-addr.arpa" {
                type master;
                file "standard/loopback";
                allow-transfer { localhost; };
            };
            zone "0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.ip6.arpa" {
                type master;
                file "standard/loopback6.arpa";
                allow-transfer { localhost; };
            };
            zone "com" {
                type delegation-only;
            };
            zone "net" {
                type delegation-only;
            };
        
            zone "&EDOMINIO;" {
                type master;
                file "refleja/&EDOMINIO;.org";
            };
        };
        view "external" { // Para Internet
            recursion no;
            additional-from-auth no;
            additional-from-cache no;
            zone "&EDOMINIO;" {
                type master;
            file "master/&EDOMINIO;";
            };
            zone "168.74.245.200.IN-ADDR.ARPA" { // Para resolución inversa
                type master;
            file "master/db.168.74.245.200";
            };
        };

El archivo `master/&EDOMINIO;` sería el típico para resolver externamente,
mientras que en `refleja/&EDOMINIO;` tendría los mismo nombres del
anterior pero con las direcciones de la red local.
`master/db.167.74.245.200` tendría datos para resolución de nombres
inversa desde fuera de la organización, por ejemplo:

        $TTL 1D
        @ IN  SOA  @  root.localhost. (
          49   ; Serial de Zona
          1D   ; Refresco secundario
          6H   ; Reintento secundario
          2D   ; Expiración secundaria
          1D ) ; Cache de registros de recurso
        
        @       IN      NS      cortafuegos.&EDOMINIO;.
            IN      PTR     www.&EDOMINIO;.
            IN      PTR     correo.&EDOMINIO;
            IN      PTR     ns1.&EDOMINIO;

### Referencias y lecturas recomendadas {#referencias-dns}

-   Sección sobre DNS de las guías Aprendiendo a aprender Linux.
    [AA_Linux](#biblio)

-   Referencia para administradores de BIND 9 [bind9arm](#biblio).

-   Ayudas para configurar Bind incluido en OpenBSD.

-   Puede consultar más sobre vistas y reflexión de consultas DNS en
    <http://www.bind9.net/manual/bind/9.3.1/Bv9ARM.ch06.html#view_statement_grammar>.

-   [openbsdDnsDhcp](#biblio).

-   Las siguientes páginas man: named 8. dig 8. unbound 8. nsd 8.
    unbound.conf 5. named.conf 5.

-   https://calomel.org/nsd\_dns.html

-   http://eradman.com/posts/run-your-own-server.html

-   https://calomel.org/unbound\_dns.html


## Servidor `ssh`

Al instalar OpenBSD con soporte de red, tendrá la oportunidad de activar
o no el servidor de OpenSSH `sshd`. Si posteriormente requiere cambiar
la configuración edite el archivo `/etc/rc.conf.local` y para activarlo
agregue:

        sshd_flags=""

o para desactivarlo agregue:

        sshd_flags="NO"

El servidor OpenSSH es desarrollado por el proyecto OpenBSD y para dar
seguridad continuamente innova en métodos de cifrado, de intercambio de
llaves y de integración con el sistema operativo (por ejemplo modo
separación de privilegios que ha mostrado ser más seguro).

La configuración por defecto de este servicio típicamente esta bien para
la mayoría de casos, pero puede refinarla para su caso en el archivo de
configuración (`/etc/ssh/sshd_config`).

Por defecto este servicio dejará una bitácora en `/var/log/authlog` (y
sus copias anteriores comprimidas como `/var/log/authlog.0.gz`,
`/var/log/authlog.1.gz`, ...).

### Jaula sftp {#jaulasftp}

Supongamos que requiere que unos usuarios puedan sólo ingresar por sftp a sus
archivos pero a nada más del sistema de archivos.  Agregrue el grupo
`jaulasftp` al archivo `/etc/group` por ejemplo:

        jaulasftp:*:1002:

Indique a sshd la configuración especial para estos usuarios agregando a
`/etc/ssh/sshd_config` :
```
Match group jaulasftp
  ForceCommand internal-sftp
  ChrootDirectory /restovar/jaulasftp
  PermitTunnel no
  AllowAgentForwarding no
  AllowTcpForwarding no
  X11Forwarding no
```

Note que no se le permite ralizar tuneles ni reenvios y sólo puede
usar el sistema internal-sftp confiando a `/restovar/jaulasftp`

Por ejemplo con `doas vipw` edite cada usuario por limitar par asegurar que
su línea es de la forma siguiente:

        uslim:$2b$10$dEPqLC7YSmilUNURQXp2AeiptJVJ38H6ZsiI25w7fisMboDkBCZy.:1005:1002::0:0:Usuario Limitado:/home/uslim:/bin/false

Teniendo en cuenta que para este usuario de ejmplo `uslim`:
1. Que su grupo principal es el 1002 - jaulsftp
2. Que no tiene interprete de ordenes, es decir que es `/bin/false`
3. Que su directorio personal es `/home/uslim`, pero que en realidad debe
   ubicarse dentro de la jaula para ser `/restovar/jaulasftp/home/uslim`


Cree el directorio /restovar/jaulasftp/home/uslim y ponga la información
que debe ver el usuario `uslim` en su directorio personal.

Cuando ese usuario ingrese vía sftp verá como raíz lo que haya en
`/restovar/jaulasftp`  y podrá ingresar a los directorios y archiovs
dentro de esa jaula en la medida que el sistema de permisos típico 
se lo permita.






### Referencias y lecturas recomendadas {#referencias-sshd}

Las siguientes páginas man: sshd 8.

Separación de privilegios:
<http://www.counterpane.com/alert-openssh.html>

Página web: <http://www.openssh.com>


## Protocolo DHCP {#dhcp}

El protocolo DHCP se describen en el RFC 2131 (ver [rfc2131](#biblio)), se
trata de un modelo cliente-servidor en el que el servidor DHCP localiza
direcciones IP libres en una red y envía parámetros de configuración a
computadores cliente que se configuran dinámicamente. Entre los
parámetros de configuración que un servidor puede enviar están: IP por
asignar al computador, IP de la puerta de enlace, IPs de servidores de
nombres, nombre del dominio por utilizar.

En su modo de operación dinámico el servidor le asigna una IP a un sólo
cliente por cierto periodo de tiempo, al cabo del cual podría asignarle
otra IP[^dhcp.1].

### Configuración de un cliente DHCP {#cliente-DHCP}

La configuración de un computador para operar como cliente de DHCP
depende del sistema operativo, en el caso de Windows en las propiedades
TCP/IPv4 de la tarjeta puede especificarse obtener dirección
automáticamente. En el caso de Linux Ubuntu al Editar las Conexiones de
Red puede especificarse que una tarjeta de red usará DHCP. Un OpenBSD
con una interfaz de red (digamos `rl0`) se configura como cliente de
DHCP desde la línea de ordenes con:

        doas dhclient rl0 

que lee parámetros de configuración de `/etc/dhclient.conf` (el cual por
defecto está configurado para solicitar mascara de red, servidores de
nombres, dirección de difusión --broadcast--, nombre del dominio, nombre
del computador y puerta de enlace). Puede configurarse de manera
permanente para que en cada arranque se use este protocolo en una
interfaz (remplazar `rl0` por la de su caso) dejando en el archivo
`/etc/hostname.rl0` la línea:

        dhcp

### Configuración de un servidor DHCP {#servidor-DHCP}

Una configuración típica para un servidor DHCP que servirá direcciones
para la red local 192.168.17.x en el rango 192.168.17.142 a
192.168.17.164 y que enviará además entre los parámetros el dominio, la
puerta de enlace y la IP del servidor de nombres, se hace en el archivo
`/etc/dhcpd.conf` con:

        shared-network LOCAL-NET {
                option  domain-name "&EDOMINIO;";
                option  domain-name-servers 192.168.17.1;
                subnet 192.168.17.0 netmask 255.255.255.0 {
                        option routers 192.168.17.1;
                        range 192.168.17.142 192.168.17.164;
                }
        }

También asegúrese de iniciar el servicio DHCP editando
`/etc/rc.conf.local` para agregar:

        dhcpd_flags=""

o en lugar de "" puede especificar las interfaces de red que el servidor
debe atender separadas por espacio.

### Referencias y lecturas recomendadas {#referencias-dhcpd}

Las siguientes páginas man: dhcp8, dhclient 8, dhclient.conf5, dhcpd8 y
dhcpd.conf5.

El RFC 2131 (ver [rfc2131](#biblio)).

[^dhcp.1]: Típicamente un cliente enviará un paquete DHCPDISCOVER a toda la
    red (opcionalmente con sugerencia de la IP que quiere), un servidor
    que reciba tal paquete le responderá con un DHCPOFFER con una oferta
    de parámetros de configuración, el cliente puede responder con
    DHCPREQUEST para confirmar los parámetros y el servidor responde con
    un DHCPACK para confirmar asignación.


## Servidor `ntp`

El protocolo NTP permite mantener sincronizado el reloj de un computador
con otro donde corra un servidor NTP.

Hay varios servidores en Internet que proveen este servicio
públicamente, algunos están conectados a relojes de alta precisión

OpenBSD (dese la versión 3.6) incluye una implementación del cliente y
servidor de este protocolo llamada OpenNTPD. Para configurar un cliente
basta editar `/etc/rc.conf.local` para agregar:

        ntpd_flags=""

lo cual empleará el archivo de configuración `/etc/ntpd.conf` que por
defecto especifica:

        servers pool.ntp.org

con lo cual actúa como cliente empleando aleatoriamente alguno de los
servidores de NTP disponibles mundialmente en `pool.ntp.org`.

### Referencias y lecturas recomendadas {#referencias-ntp}

Documentación disponible en <http://www.openntpd.org>.


## Servidor de correo electrónico {#servicios-correo}

OpenBSD incluye dos MTAs de correo: (1)una versión auditada de
`sendmail` y (2) OpenSMTPD. En este capítulo detallamos la configuración
y uso de cada uno y la configuración de paquetes que implementan los
protocolos auxiliares POP3S e IMAPS, de clientes de correo web y de
listas de correo.

adJ cuenta con las ordenes `prepsendmail` y `prepopensmtpd` que
configuran de manera automática sendmail y OpenSMTPD respectivamente con
TLS y SASL, así como POP3S e IMAPS. Soportan opcionalmente mantener el
correo en una partición cifrada y copia de respaldo del correo en otra
partición también cifrada. Antes de emplearlos ejecute:

        doas cp /usr/local/share/examples/adJ/varcorreo.sh /etc/

y a continuación edite el archivo recién copiado para adaptarlo a su
entorno.

### Protocolo SMTP para enviar y recibir correo {#smtp}

SMTP
Nombre del protocolo para transmisión de correo electrónico en Internet.

MTA
Sigla para el tipo de programas que pueden transmitir un correo (por
ejemplo exim y sendmail).

MUA
Sigla para el tipo de programas que un usuario puede emplear para
redactar y leer correos (por ejemplo mail y mutt).

Como se explica en AA\_Linux el servicio básico de correo empleado en
Internet y en una red TCP/IP se basa en el protocolo SMTP (*Simple Mail
Transfer Protocol*) descrito especialmente en los RFCs
[821](ftp://ftp.rfc-editor.org/in-notes/rfc821.txt) y
[1123](ftp://ftp.rfc-editor.org/in-notes/rfc1123.txt), funcionando sobre
TCP/IP. En una situación típica en la que un usuario &EUSUARIO;@&ECLIENTE;
envía un mensaje al usuario &EUSUARIO2;@&ECLIENTE2; sin computadores
intermediarios, se requiere:

-   Que haya conexión física y a nivel de TCP/IP entre ambos
    computadores.

-   Que ambos computadores tengan un programa que permita enviar y
    recibir correo usando el protocolo SMTP, como por ejemplo sendmail o
    postfix (a tal programa se le llama MTA - *Mail Transport Agent*).

-   Que ambos usuarios tengan un programa con el que puedan leer y
    redactar correos, como por ejemplo mail, mutt, mozilla-thunderbird
    (a ese programa se le llamará MUA - *Mail User Agent*[^smtp.1]).

Si tanto &EUSUARIO; como &EUSUARIO2; emplean como MUA `mail`, y ambos
computadores tiene como MTA sendmail, el proceso sería:

&EUSUARIO; emplea `mail` en su computador &ENOMCLIENTE; para redactar el
mensaje cuyo destinatario es &EUSUARIO2;.

En &ENOMCLIENTE;, el programa mail ejecuta sendmail para enviar el
mensaje. sendmail deja el mensaje en una cola de mensajes por enviar.
Esa cola de mensajes es actualizada por sendmail a medida que envía o
intenta enviar mensajes (si un mensaje no puede ser enviado sendmail
puede reintentar el envío cierto número de veces, haciendo pausas entre
un intento y otro).

Enviar un mensaje significa crear una conexión TCP con el MTA destino o
con otro MTA que actúe de intermediario, típicamente en el puerto TCP
25, y transmitir el mensaje siguiendo las reglas del protocolo SMTP
[^smtp.2]. Para establecer el computador con el cual conectarse sendmail
revisa con el resolvedor DNS, registros MX asociados con el dominio de
la dirección, si los hay intenta enviar a cada uno en orden de prioridad
--los registros MX con menor número tienen mayor prioridad (ver
[Servicio DNS](#servidor-dns)).

En &ENOMCLIENTE2; debe estar corriendo un proceso que acepte la conexión
en el puerto 25, i.e. sendmail o algún otro MTA que reciba el mensaje
siguiendo el protocolo SMTP.

sendmail en &ENOMCLIENTE2; agrega el mensaje que recibe en el archivo tipo
texto `/var/mail/&EUSUARIO2;` que está en formato mbox.

Archivo donde exim deja los correos destinados al usuario &EUSUARIO2;.

Cuando &EUSUARIO2; lo desee, podrá emplear `mail` para leer los correos
que se hayan acumulado en `/var/mail/&EUSUARIO2;` ---a medida que los lea
saldrán de ese archivo para quedar en `~/mbox`.

Este es el esquema básico, aunque hay muchas otras situaciones en las
que se emplean otras posibilidades de SMTP, protocolos auxiliares y
programas. Por ejemplo los usuarios de una organización suelen extraer
sus correos del servidor desde otros computadores con MUAs gráficos
empleando el protocolo inseguro POP3 o los protocolos seguros POP3S e
IMAPS. También es posible configurar un cliente de correo web (webmail)
para examinar correos desde el web. Otro servicio asociado al correo son
las listas de correo que facilitan el envío de correo masivo.

#### MTA OpenSMTPD {#opensmtpd}

Se trata de un MTA desarrollado principalmente para OpenBSD por
desarrolladores de OpenBSD. Aunque aún se considera experimental hemos
comprobado su estabilidad para dominios virtuales que manejan menos de
1000 correos diarios.

Antes de iniciar el servicio es importante detener sendmail con:

        /etc/rc.d/sendmail stop

y deshabilitarlo dejando en /etc/rc.conf.local la línea:

        sendmail_flags=NO

El servicio se inicia con:

        doas /etc/rc.d/smtpd start

y se detiene con:

        doas /etc/rc.d/smtpd stop

Para que inicie en cada arranque y se reinicie fácil ejecutando
`/etc/rc.local` agregue `smtpd` a la variable `pkg_scripts` de
`/etc/rc.conf.local` y en ese mismo archivo agregue:

        smtdp_flags=""

También modifique `/etc/mailer.conf` y cambie algunas líneas para que
sean:

        sendmail        /usr/sbin/smtpctl
        send-mail       /usr/sbin/smtpctl
        mailq           /usr/sbin/smtpctl
        makemap         /usr/libexec/smtpd/makemap
        newaliases      /usr/libexec/smtpd/makemap

Una vez en operación pueden examinarse diversos aspectos (como
bitácoras, examinar cola de correos, estadísticas) con `smtpctl`.

La configuración se define en el archivo `/etc/mail/smtpd.conf`. La
configuración más simple que sólo aceptará correo local con aliases
definidos en `/etc/mail/aliases` y lo dejará en
formato mbox en `/var/mail` o hará relevo es:

        listen on lo0

        table aliases file:/etc/mail/aliases

	action "local" mbox alias <aliases>
	action "relay" relay

	match for local action "local"
	match for any action "relay"

Para que permita enviar y recibir de otros computadores debe cambiarse
la interfaz donde escucha y el nombre de quien acepta correos, por
ejemplo:

        listen on all

        table aliases file:/etc/mail/aliases

	action "local" mbox alias <aliases>
	action "relay" relay

	match from any for domain "&EDOMINIO;" action "local"
	match for local action "local"
	match for any action "relay"

Si prefiere recibir en formato maildir (por defecto en `~/Maildir` de 
cada usuario) y tener opción de procesar usuario a usuario con procmail 
vía el archivo `~/.forward` es mejor cambiar 
`action "local" mbox alias <aliases>` por:

	action "local" maildir alias <aliases>

La tabla de alias que usa esta configuración es el archivo plano
`/etc/mail/aliases`. Si prefiere usar base de datos DB en lugar de
archivo plano genere la base a partir del archivo plano con:

        doas newaliases

Y en el archivo de configuración cambie 
`table aliases file:/etc/mail/aliases` por:

        table aliases db:/etc/mail/aliases.db

Para asegurar el relevo de correos provenientes de &EDOMINIO; o de la IP
192.168.1.2, basta agregar al mismo archivo de configuración:

        match for &EDOMINIO; action "relay"
        match for 192.168.1.2 action "relay"

Para agregar autenticación y TLS basta generar certificado SSL 
y dejar `&EDOMINIO;.crt` en `/etc/ssl/` 
y `&EDOMINIO;.key` en `/etc/ssl/private` para
después cambiar en el archivo de configuración la línea con `listen`
por:

	pki &EDOMINIO; cert "/etc/ssl/&EDOMINIO;.crt"
	pki &EDOMINIO; key "/etc/ssl/private/&EDOMINIO;.key"

	listen on all port 465 smtps pki &EDOMINIO; auth-optional
	listen on all port 587 tls pki &EDOMINIO; auth
	listen on all port 25 tls pki &EDOMINIO; auth-optional

Así quedará:

* Escuchando conexiones cifradas (SMTPS) por el puerto 465
* Escuchando conexiones planas con autenticación opcional y la 
  posibilidad de cambiar a conexión cifradas (con STARTTLS) por puerto 25 y
* Escuchando conexiones planas que requieren paso a cifradas (con STARTTLS)
  y que exigen autenticación por el puerto 587.

##### Depuración de OpenSMTP {#smtpd-depura}

OpenSMTP envía mensajes de error a la bitácora `/var/log/maillog`. Puede
ejecutarse en modo de depuración para determinar problemas con:

        smtpd -d

Esto no lo activará como servicio y presentará errores en pantalla.

#### Pruebas

Desde el mismo computador inicie un diálogo con:

	$ telnet localhost 25

O desde otro computador con:

        $ telnet correo.&EDOMINIO; 25
	Trying 1.2.3.4
	Connected to correo.&EDOMINIO;
	Escape character is '^]'
        220 correo.&EDOMINIO; ESMTP OpenSMTPD

Inicie dialogo con:

        EHLO [200.21.23.4]

remplazando 200.21.23.4 por la IP desde la que inicia la conexión.

Verá algo como:

	250-correo.&EDOMINIO; Hello [200.21.23.4] [200.21.23.4], pleased to meet you
	250-8BITMIME
	250-ENHANCEDSTATUSCODES
	250-DSN
	250-STARTTLS
	250 HELP

Note que debe aparecer la línea `STARTTLS`.

Para probar la autenticación es mejor emplear el puerto 465 y openssl:

        openssl s_client -connect correo.&EDOMINIO;:465
	...
   	    Start Time: 1578243911
	    Timeout   : 7200 (sec)
	    Verify return code: 0 (ok)
	---
	220 correo.&EDOMINIO; ESMTP OpenSMTPD
        EHLO [200.21.23.4]
	250-kadosh.pasosdeJesus.org Hello [200.21.23.4] [200.21.23.4], pleased to meet you
	250-8BITMIME
	250-ENHANCEDSTATUSCODES
	250-SIZE 134217728
	250-DSN
	250-AUTH PLAIN LOGIN
	250 HELP


Note que ya está disponible autenticación `AUTH` con métodos PLAIN y 
LOGIN. Para autenticarse debe dar una identificación y una clave válida en el
sistema pero codificadas en base 64. Puede emplear la interfaz CGI
disponible en <http://www.motobit.com/util/base64-decoder-encoder.asp>
o eventualmente el programa disponible en
<http://www.sendmail.org/~ca/email/prgs/ed64.c> que puede compilar y
usar como root así:

        cd /root/tmp
        ftp http://www.sendmail.org/~ca/email/prgs/ed64.c
        cc -o ed64 ed64.c
        ./ed64 -e
        MiUsuario
        TWlVc3Vhcmlv
        MiClave
        TWlDbGF2ZQ==

Retomando la sesión y usando estos datos:

        AUTH LOGIN
        334 VXNlcm5hbWU6
        TWlVc3Vhcmlv
        334 UGFzc3dvcmQ6
        TWlDbGF2ZQ==
	235 2.0.0: Authentication succeeded

puede intentar el envío de un correo por ejemplo con:

        MAIL FROM:<&EUSUARIO;@&EDOMINIO;>
        250 OK                                                                          
        RCPT TO:<&EUSUARIO2;@&EDOMINIO;>
        250 Accepted                                                                    
        DATA                                                                            
        354 Enter message, ending with "." on a line by itself                          
        From: "&EUSUARIO;@&EDOMINIO;" <&EUSUARIO;@&EDOMINIO;>
        To:  &EUSUARIO2;@&EDOMINIO;
        Subject: probando
        1234                                                                            
        .                                                                               
        250 OK id=1GZXFP-000540-7J                                                      
        QUIT

De requerirlo puede rastrear problemas en `/var/log/maillog`.
Si desea probar el método PLAIN, con ed64 emplee:

        MiUsuario\0MiUsuario@pasosdeJesus.org\0MiClave
        TWlVc3VhcmlvAE1pVXN1YXJpb0BwYXNvc2RlamVzdXMub3JnAE1pQ2xhdmU=

y al dialogar en SMTP:

        AUTH PLAIN TWlVc3VhcmlvAE1pVXN1YXJpb0BwYXNvc2RlamVzdXMub3JnAE1pQ2xhdmU= 

También puede probar el servicio del puerto 465 con la misma secuencia,
pero iniciando con:



#### Referencias {#referencias-opensmtpd}

-   `man smtpd`, `man smtpd.conf`, `man smtpctl`

-   <http://www.opensmtpd.org/>


##### Configuración del cliente de correo (MUA) {#conf-mua}

Dependiendo de su cliente de correo será posible emplear los nuevos
protocolos. Por ejemplo `mozilla-thunderbird` lo soporta, basta que en
la configuración del servidor SMTP indique que debe emplearse un usuario
y que emplee TLS (puede usar tanto el puerto 25 como el 465). Tenga en
cuenta que el nombre del usuario con el cual autenticarse debe incluir
el dominio (e.g &EUSUARIO;@&EDOMINIO;).

##### Referencias {#referencias-smtp-auth-tls}

-   `man starttls`

-   <http://www.dorkzilla.org/~dlg/sendmail/>

-   <http://www.pingwales.co.uk/tutorials/openbsd-mail-server-config-2.html>

-   <http://www.jonfullmer.com/smtpauth/>

-   <http://www.sendmail.org/~ca/email/auth.html> y
    <http://www.sendmail.org/~ca/email/authrealms.html>

-   <http://www.bitstream.net/support/email/thunderbird/auth.html>

### Dominios virtuales {#dominios-virtuales-correo}

Si un mismo servidor atiende diversos dominios DNS, puede lograr que se
acepte correo para cada dominio. Para esto:

-   Asegúrese de tener un registro MX para el dominio que indique que su
    servidor es el servidor de correo del dominio. i.e en el archivo
    maestro del dominio (digamos `/var/named/master/&EDOMINIO;`) algo
    como:

            MX      5       correo.&EDOMINIO;.
            correo          IN      A       65.167.89.169

    ¡No omita el punto que va a continuación del nombre del servidor MX!

-   En el archivo `/etc/mail/smtpd.conf` agregue una tabla de alias, una 
    línea `action` y una línea `match` por cada dominio, por ejemplo:

        table aliasesejemplo db:/etc/mail/aliasesejemplo.db
        ...
	action "ejemplo" maildir alias &lt;aliasesejemplo>
	...
	match from any for domain "ejemplo.org" action "ejemplo"

-  La tabla de alias debe generarse a partir de un archivo plano
   `/etc/mail/aliasesjemplo` con:

        cd /etc/mail
        makemap hash aliasesejemplo < aliasesejemplo
        chmod a+r aliasesejemplo


-   Reinicie `smtpd` por ejemplo con:

            doas rcctl -d restart smtpd


### Protocolos para revisar correo {#protocolos-revisar-correo}

Para extraer correos de un servidor pueden emplearse los protocolos
inseguros[^smtp.3] POP3 e IMAP o bien sus análogos seguros sobre SSL: POP3S e
IMAPS En esta sección se describe la configuración extra-rápida pero
insegura de POP3, y la configuración segura pero que requiere
configuración más delicada de POP3S e IMAPS con las implementaciones de
Courier.

#### Implementación Dovecot de IMAPS y POP3S {#dovecot}

Instale el paquete &p-dovecot; y asegúrese de dejar `dovecot` en la
variable `pkg_scripts` de `/etc/rc.conf.local` para que se inicie en
cada arranque.

Puede generar un certificado autofirmado editando los datos para el
certificado en el archivo `/etc/ssl/dovecot-openssl.cnf` y generandolo
con

        /usr/local/sbin/dovecot-mkcert.sh

que lo dejará en `/etc/ssl/dovecotcert.pem` y
`/etc/ssl/private/dovecot.pem`.

Edite el archivo `/etc/dovecot/conf.d/auth-system.conf.ext` y asegurse
de que queden sin comentario las siguientes partes:

        passdb {                                                                        
            driver = bsdauth    
        }
        userdb {                                                                        
            driver = passwd                                                               
        }

Inicie el servicio con

        /etc/rc.d/dovecot start

y pruébelo en los puertos 143 (IAMP sin cifrar), 993 (IMAP sobre SSL),
110 (POP3 sin cifrar) y 995 (POP3 sobre SSL). Por defecto dovecot
intentará recuperar correos en formato maildir de la carpeta `Maildir`
de cada usuario.

Una vez confirme la operación recomendamos que sólo abra el puerto 993
del cortafuegos para permitir conexiones IMAP remotas sobre SSL.

#### Implementación Courier de POP3S e IMAPS {#pop3s-imaps-courier}

Esta implementación requiere que se cambie la forma de almacenar correos
recibidos por sendmail de formato mbox a formato maildir. Esto y la
autenticación que requiere courier exigen una configuración especial que
se describe a continuación.

##### Autenticación Courier {#autenticacion-courier}

Instale `courier-authlib`, paquete que se encarga de la autenticación.
Para iniciarlo en cada arranque agregue `courier_authdaemond` a la
variable `pkg_scripts` de `/etc/rc.conf.local`.

Una vez en operación puede probar la autenticación con
`authtest usuario` y `authtest usuario clave`

##### Sendmail almacenando correos en formato maildir {#acomplamiento-sendmail}

El formato mbox almacena todos los correos en un sólo archivo, uno tras
otro. El formato maildir (propio del MTA qmail) almacena cada correo en
un archivo separado en algún directorio, por defecto hay 3 directorios
(`cur`, `new` y `tmp`) aunque el usuario puede crear otros.

Típicamente `sendmail` deja los correos que recibe en formato mbox en
archivos del directorio `/var/mail`. En esta sección se explica como
lograr que los almacene en el directorio `Maildir` de la cuenta de un
usuario.

Una sencilla solución que no requiere mayores cambios es emplear
`procmail`. Instale el paquete `` y en la cuenta de cada usuario que
vaya a usar POP3S o IMAPS cree los archivos `.forward` y `.procmailrc`,
análogos a los siguientes (suponemos que se trata del usuario ``):

-   En `/home/&EUSUARIO;/.forward`

            "| exec /usr/local/bin/procmail"
              

    las comillas son indispensables así como el símbolo '|'.

-   En `/home/&EUSUARIO;/.procmailrc`

            LINEBUF=4096
            #VERBOSE=on
            PMDIR=/home/&EUSUARIO;/
            MAILDIR=$PMDIR/Maildir/
            FORMAIL=/usr/local/bin/formail
            SENDMAIL=/usr/sbin/sendmail
            #LOGFILE=$PMDIR/log

            :0
            * .*
            /home/&EUSUARIO;/Maildir/

    Note que el directorio de la variable `MAILDIR` termina con '/'.
    Esto es indispensable para indicar a `procmail` que debe guardar en
    esa ruta en formato Maildir.

-   Deje además listo un directorio en formato Maildir en
    `/home/&EUSUARIO;/Maildir` con:

            maildirmake /home/&EUSUARIO;/Maildir
            chown -R &EUSUARIO;:estudiante /home/&EUSUARIO;/Maildir
              

De esta forma cada vez que sendmail reciba un correo para el usuario
local `` en vez de almacenar en `/var/mail/&EUSUARIO;`  ejecutará la línea
del archivo `/home/&EUSUARIO;/.forward`, la cual a su vez ejecutará
procmail para procesar el correo que llega por entrada estándar.
`procmail`  empleará la configuración de `/home/&EUSUARIO;/.procmailrc` que
le indica guardar todo correo que llegue a la cuenta en
`/home/&EUSUARIO;/Maildir/` (como se trata de un directorio y termina con
'/', `procmail` identifica que debe salvar en formato `Maildir`, si
fuera un archivo agregaría en formato `MBOX`).

El usuario &EUSUARIO; podría probar su archivo de configuración de
`procmail` modificando `~/.procmail` para quitar el comentario de la
línea

        VERBOSE=on
          

y ejecutando:

        cd /home/&EUSUARIO;
        procmail 
        Mensaje de prueba
        Termínelo con Control-D
        .
        procmail: [21024] Fri Jul  1 18:32:30 2005
        procmail: Assigning "PMDIR=/home/&EUSUARIO;/"
        procmail: Assigning "MAILDIR=/home/&EUSUARIO;/Maildir/"
        procmail: Assigning "FORMAIL=/usr/local/bin/formail"
        procmail: Assigning "SENDMAIL=/usr/sbin/sendmail"
        procmail: Assigning "LOGFILE=/home/&EUSUARIO;/log"

Tras lo cual debe encontrar un nuevo archivo en `Maildir/new` con el
mensaje de prueba.

Puede verificar el funcionamiento de `.forward` enviando un correo a la
cuenta del usuario y revisando la bitácora `/var/log/maillog` donde
deben aparecer un par de líneas análogas a:

    Dec 19 18:31:59 servidor sendmail[22209]: kBJNVwMt022209: to=test@localhost, ctladdr=&EUSUARIO; (1000/1000), delay=00:00:01, xdelay=00:00:01, mailer=relay, pri=30061, relay=[127.0.0.1] [127.0.0.1], dsn=2.0.0, stat=Sent (kBJNVw3t021322 Message accepted for delivery)
    Dec 19 18:31:59 servidor sm-mta[21454]: kBJNVw3t021322: to="| exec /usr/local/bin/procmail", ctladdr=<test@&EDOMINIO;> (1008/10), delay=00:00:00, xdelay=00:00:00, mailer=prog, pri=30756, dsn=2.0.0, stat=Sent
            

##### POP3S con Courier {#pop3s-courier}

POP3 (Post Office Protocol) es un protocolo que permite sacar correos de
un servidor para llevarlos a otro computador donde podrán examinarse con
un MUA.

Para que los usuarios puedan emplear clientes de correo que soporten
POP3, es necesario configurar un servidor de este protocolo. Dado que
este protocolo por defecto transmite claves planas es necesario
emplearlo sobre una conexión SSL --de ahí el nombre POP3S.

Después de configurar autenticación y acople con sendmail como se
explicó en secciones anteriores. Instale el paquete `courier-pop3`. Este
paquete se configura en el directorio `/etc/courier`, donde deja varios
archivos de configuración de ejemplo que debe editar (también podrá
encontrar los archivos de ejemplo en
`/usr/local/share/examples/courier/`).

En `/etc/courier/pop3d` cambie

        POP3DSTART=YES
        MAILDIRPATH=Maildir
          

y en `/etc/courier/pop3d-ssl` cambie

        MAILDIRPATH=Maildir
          

Para emplear SSL requiere un certificado (por defecto en
`/etc/ssl/private/pop3d.pem`) firmado por una Autoridad Certificadora, .
Alternativamente puede generar certificados autofirmados, para esto
modifique la información del archivo `/etc/courier/pop3d.cnf` y ejecute:

        doas mkpop3dcert
          

Script que creará un certificado válido por un año (si lo requiere por
más tiempo puede editar el script y cambiar el número de días de validez
en la opción `-days` de `openssl`).

En caso de que si tenga un certificado firmado digamos para su servidor
web, puede emplearlo (ver courier-cert) así:

        cd /etc/ssl/private
        cat server.key ../server.crt > pop3d.pem
              

Para iniciar POP3S ejecute:

        doas mkdir -p /var/run/courier
        doas /usr/local/libexec/pop3d-ssl.rc start
          

líneas que se recomienda agregar a `/etc/rc.local` si planea prestar
servicio continuo (y abrir el puerto apropiado del cortafuegos, ver a
continuación).

Para detener POP3S:

        doas /usr/local/libexec/pop3d-ssl.rc stop
          

POP3 usa por defecto el puerto 110, POP3S típicamente emplea el puerto
995. Para abrir ese puerto en un cortafuegos en `/etc/pf.conf` podría
emplear una línea de la forma:

        pass in on $ext_if proto tcp to ($ext_if) port pop3s keep state
          

Puede probar el funcionamiento del servidor con:

        openssl s_client -connect localhost:995 

teniendo en cuenta que el correo debe estar en formato Maildir en el
directorio `Maildir` del usuario que revisará. Una sesión típica sería:

        +OK Hello there.
        user &EUSUARIO;
        +OK Password required.
        pass ejem
        +OK logged in.
        list
        +OK POP3 clients that break here, they violate STD53.
        1 17559
        2 1128
        3 2430
        . 

Notará que la implementación Courier de POP3S intenta extraer correos
del directorio `Maildir/cur`

##### IMAP-SSL con Courier {#imap-ssl-courier}

IMAP es un protocolo que permite a un MUA examinar y administrar correos
que llegan a un servidor, típicamente sin sacar los correos del servidor
(a diferencia de POP) y con la posibilidad de manejar
directorios/carpetas.

Después de configurar autenticación y acople con `sendmail` como se
explicó en secciones anteriores. Instale el paquete `courier-imap` y
edite `/etc/courier/imapd` para cambiar por lo menos:

        IMAPDSTART=YES
        MAILDIRPATH=Maildir

y `/etc/courier/imapd-ssl` para dejar

        MAILDIRPATH=Maildir

y eventualmente dependiendo de los clientes para el IMAPS (por ejemplo
roundcube-0.5) también puede requerir:

        TLS_PROTOCOL=SSL23

Para generar un certificado autofirmado edite `imapd.cnf` para
personalizar sus datos y ejecute

        mkimapdcert

o si desea emplear el mismo certificado de su servidor web:

        cd /etc/ssl/private
        cat server.key ../server.crt > imapd.pem

Para iniciar IMAPS ejecute:

        doas /etc/rc.d/courier_imap_ssl start

y para detenerlo:

        doas /etc/rc.d/courier_imap_ssl stop

Para iniciar el servicio cada vez que arranque el sistema agregue
`courier_imap_ssl` a la variable `pkg_scripts` en `/etc/rc.conf.local`.

Cuando ejecute tanto `authdaemond` como `imapd-ssl` deben quedar
corriendo varios procesos: `authdaemond` (o el método de autenticación
que haya configurado), `couriertcpd`, `courierlogger`. Si desea ver
mensajes de depuración en `/var/log/maillog`, cambie en
`/etc/courier/imapd`:

        DEBUG_LOGIN=1

podrá detener los servicios con:

        doas /usr/local/libexec/imapd-ssl.rc stop
        rm /var/run/courier/imapd-ssl.pid

Si tiene cortafuegos activo asegúrese también de abrir el puerto 993
agregando a `/etc/pf.conf` algo como:

        pass in on $ext_if proto tcp to ($ext_if) port 993 keep state
            

Una vez en ejecución puede hacer una prueba como:

        $ openssl s_client -connect localhost:993
        ...
        AB LOGIN &EUSUARIO; MiClave
        AB OK LOGIN Ok.
        BC SELECT "Inbox"
        BC NO Unable to open this mailbox.
        ZZZZ LOGOUT
        * BYE Courier-IMAP server shutting down
        ZZZZ OK LOGOUT completed

##### Facilitar uso de implementación Courier {#courier-cuentas}

Una vez se use procmail para recibir en formato Maildir los correos de
un usuario, ese usuario no podrá seguir usando `mail` para ver los
correos recibidos, pero si podrá emplear `mutt` agregando al archivo de
configuración `~/.muttrc`:

    set spoolfile=imaps://localhost/INBOX
    set folder=imaps://localhost/
            

Como administrador del sistema podrá automatizar más la configuración de
cuentas nuevas así:

1.  Crear archivos en `/etc/skel` que se copiarán a cada cuenta nueva,
    (el contenido de cada uno debe ser como el descrito en secciones
    anteriores):

        maildirmake /etc/skel
        /etc/skel/.forward
        /etc/skel/.muttrc
        /etc/skel/.procmailrc
                            

2.  Como será `procmail` y no `sendmail` quien manejará correos, cada
    vez que cree una cuenta ejecute:

        touch /var/mail/usuario
        chown usuario:usuario /var/mail/usuario
        chmod go-r /var/mail/usuario

    y ajuste el archivo `.procmailrc`. Es recomendable que haga esto en
    un script que primero ejecute `adduser`, y que sería la nueva
    orden para crear cuentas en el sistema.

Esta configuración se aplicará a nuevas cuentas que cree, pero debe
replicarla en cuentas ya creadas:

    cd /etc/skel
    cp -rf Maildir .forward .procmailrc .muttrc /home/cuenta/ 
    chown -R cuenta:cuenta /home/cuenta/{.forward,.procmailrc,.muttrc,Maildir}
    touch /var/mail/cuenta
    chown -R cuenta:cuenta /var/mail/cuenta
    chmod og-r /var/mail/cuenta

##### Referencias y lecturas recomendadas {#referencias-courier}

* El protocolo POP3 se describe en el RFC 1939
<http://www.faqs.org/rfcs/rfc1939.html> 
* Puede consultar más sobre la
configuración de IMAP con Courier en
<http://dantams.sdf-eu.org/guides/obsd_courier_imap.html > y
<http://es.tldp.org/Manuales-LuCAS/doc-tutorial-postfix-ldap-courier-spamassassin-amavis-squirrelmail>
* Más sobre `procmail` en <http://pm-doc.sourceforge.net/pm-tips.html >
y <http://structio.sourceforge.net/guias/basico_OpenBSD/correo.html#procmail>
* Más sobre IMAP en <http://www.linux-sec.net/Mail/SecurePop3/ > y
<http://talk.trekweb.com/~jasonb/articles/exim_maildir_imap.shtml>
* POP3S e IMAPS en OpenBSD/LDAP/Sendmail
<http://dhobsd.pasosdeJesus.org/index.php?id=view/POP3S+e+IMAPS+en+OpenBSD%2FLDAP%2FSendmail>
* El uso de certificados existentes con courier se señala en
<http://milliwaysconsulting.net/support/systems/courier-ssl.html>

### Combatiendo correo no solicitado con SpamAssassin {#spam}

OpenBSD incluye el programa `spamd` que maneja listas negras (o grises)
de IPs de las cuales no recibe correo alguno. Tal aproximación es
bastante radical y en ocasiones puede listar o evitar recepción de
servidores válidos como gmail, yahoo o hotmail o de servidores que no
reintentan el envío como lo espera spamd. Tal comportamiento puede no
resultar aceptable en algunas organizaciones.

SpamAssassin (paquete &p-p5-Mail-SpamAssassin;) junto con procmail
(paquete &p-procmail;) son una solución intermedia que permiten recibir
todo correo pero intentan clasificar automáticamente (y con buena
precisión) los que son no solicitados en carpetas separadas por usuario
que configure el servicio.

SpamAssassin incluye el servicio `/usr/local/bin/spamd` que espera
conexiones del cliente `spamc` para aplicar una secuencia de reglas a un
correo y darle un puntaje. Tal puntaje debe agregarse al encabezado del
correo y ser tratado como spam envíandolo por ejemplo a la carpeta Junk
(que es el nombre estándar empleado por diversos clientes de correo).

#### Configuración de spamd {#configuracion-spamd}

Para iniciar el servicio ejecute:

        /usr/local/bin/spamd -u _spamdaemon -d      

y para que inicie automáticamente en cada arranque, agregue
`spamassassin` en la variable `pkg_scripts` de `/etc/rc.local`.

La configuración por defecto de SpamAssassin es bastante buena, pero
puede personalizarse en el archivo `/etc/mail/spamassassin/local.cf`.

#### Configuración de procmail por usuario {#configuracion-usuario-procmail}

Cada usuario que requiera el uso de SpamAssassin para clasificar
automáticamente los no solicitados en el buzón `spamagarrado`, debe
tener configurado `procmail`, esto puede hacerse modificando o creando
el archivo `~/.procmailrc` para que incluya líneas como las siguientes
(en caso de que el usuario maneje su correo en formato `mbox` como
ocurre por defecto en OpenBSD):

        :0fw                                                                            
        * < 256000
        | spamc                                                                         
        
        :0e                                                                             
        {
            EXITCODE=$?
        }
        
        :0:                                                                             
        * ^X-Spam-Status: Yes
        spamagarrado # buzón donde va todo el spam

O como las siguientes que suponen que el usuario `pablo` maneja su
correo en formato `maildir` (para permitir consulta con IMAPS --ver
[Implementación Courier de POP3S e IMAPS](#pop3s-imaps-courier)):

        :0fw: spamassassin.lock
        * < 512000
        | spamc
        
        # Los correos con puntaje de 15 o superior casi que con seguridad son spam (con
        # 0.05% de falsos positivos de acuerdo a rules/STATISTICS.txt). Pongamolos
        # en un mbox diferente llamado .Spam.
        :0:
        * ^X-Spam-Level: \*\*\*\*\*\*\*\*\*\*\*\*\*\*\*
        /home/pablo/Maildir/.Spam/
        
        # Todo correo marcado como spam (e.g. con puntaje mayor que el umbral puesto)
        # se mueve a "PosibleSpam".
        :0:
        * ^X-Spam-Status: Yes
        /home/pablo/Maildir/.PosibleSpam/
        
        :0
        * .*
        /home/pablo/Maildir/

#### Pruebas {#pruebas-spam}

Envíe al usuario al cual le configuró procmail un archivo cuyo cuerpo
sea el mensaje del archivo
`/usr/local/share/doc/SpamAssassin/sample-spam.txt`. Debe quedar en la
carpeta de correos no solicitados.

#### Referencias y lecturas recomendadas {#referencias-spamd}

`/usr/local/share/doc/SpamAssassin/OpenBSD-SpamAssassin-mini-howto.html`

### Correo desde el web (webmail) {#correo-web}

#### Roundcubemail

Este cliente de correo para el web tiene una interfaz bastante agradable
para el usuario final, con buen rango de posibilidades (libreta de
direcciones LDAP, búsquedas, corrección ortográfica) y facilidad de
configuración e instalación.

Requiere una base de datos para almacenar parte de la información, puede
obtener correo de servidores IMAP e IMAPS.

Basta instalar el paquete `roundcubemail` o descargar ls fuentes más
recientes de <http://sourceforge.net/projects/roundcubemail/> e
instalarlas en `/var/www/roundcubemail`, y seguir instrucciones del
archivo INSTALL que resumimos a continuación junto con instrucciones de
módulos, suponiendo que en el mismo servidor (`correo.&EDOMINIO;`) están
los servicios IMAPS y SMTP y que se empleará el motor de bases de datos
PostgreSQL:

1.  Tras instalar, el cliente quedará en `/var/www/roundcubemail` por lo
    que es necesario configurar el servidor web. Por ejemplo si el
    correo de la organización se consultará en `correo.&EDOMINIO;` (IP
    interna 192.168.60.1 y externa 200.200.200.200) con protocolo HTTPS,
    el archivo `/var/www/conf/httpd.conf` debe incluir:

            <VirtualHost 127.0.0.1:443 192.168.60.1:443 200.200.200.200:443>
            DocumentRoot "/var/www/roundcubemail/"
            ServerName correo.&EDOMINIO;
            
            <Directory /var/www/roundcubemail/>
                AllowOverride All
            </Directory>
            
            ServerAdmin admin@&EDOMINIO;
            ErrorLog logs/round-error_log
            TransferLog logs/round-access_log
            
            SSLEngine on
            SSLCertificateFile    /etc/ssl/server.crt
            SSLCertificateKeyFile /etc/ssl/private/server.key
            </VirtualHost>                                  

    > **Advertencia**
    >
    > Es importante que en la configuración de Apache, como se presenta
    > en el ejemplo incluya
    >
    >         <Directory /var/www/roundcubemail/>
    >             AllowOverride All
    >         </Directory>
    >
    > para que se tomen las opciones de configuración del archivo
    > `.htaccess` especialmente del directorio `logs` donde se almacenan
    > bitácoras y en particular si se activa puede mantenerse la
    > bitácora `imap` donde quedan claves planas.

2.  Para configurar una base de datos en PostgreSQL con socket en
    `/var/www/var/run/postgresql` (ver [???](#postgresql)) ejecutar:

            doas su - _postgresql
            createuser -h /var/www/var/run/postgresql -Upostgres roundcube
            createdb -h /var/www/var/run/postgresql -Upostgres -E UNICODE roundcubemail -T template0
            psql -h /var/www/var/run/postgresql -Upostgres template1

    y desde la interfaz administrativa de PostgreSQL establezcla una
    clave para el usuario `roundcube` con:

            ALTER USER roundcube WITH PASSWORD 'nueva_clave';

    Salir con '\\q' y desde la línea de ordenes ingresar a la nueva
    base con:

            psql -h /var/www/var/run/postgresql -Uroundcube roundcubemail

    le solicitará la clave que estableció para el usuario `roundcube`, a
    continuación desde la interfaz de PostgreSQL ejecute el script de
    inicialización con:

            \i /var/www/roundcubemail/SQL/postgres.initial.sql
                    

3.  Salga de la interfaz de PostgreSQL con `\q` y de la cuenta
    \_postgresql con `exit`. Después debe configurar roundcubemail,
    editando los archivos del directorio
    `/var/www/roundcubemail/config`. Si al examinar con

            ls /var/www/roundcubemail/config

    le faltan los archivos `main.inc.php` y `db.inc.php` inicie con
    plantillas así:

            cp /var/www/roundcubemail/config/main.inc.php.dist \
                /var/www/roundcubemail/config/main.inc.php
            cp /var/www/roundcubemail/config/db.inc.php.dist \
                /var/www/roundcubemail/config/db.inc.php

    Edítelos para que se adapten a su caso. Por ejemplo en
    `config/main.inc.php` basta modificar las líneas:

            $rcmail_config['force_https'] = TRUE;

            $rcmail_config['auto_create_user'] = TRUE;

            $rcmail_config['default_host'] = 'ssl://correo.&EDOMINIO;:993';
            
            $rcmail_config['default_port'] = 993;
            
            $rcmail_config['smtp_server'] = '127.0.0.1';
            
            $rcmail_config['mail_domain'] = '&EDOMINIO;';

    y en el archivo `config/db.inc.php` la línea:

            $rcmail_config['db_dsn'] = 'pgsql://roundcube:nueva_clave@127.0.0.1/roundcubemail';

4.  Edite el archivo de configuración de Apache `/var/www/conf/php.ini`
    para deshabilitar cifrado de sesiones y establecer zona horaria
    en la líneas:

            suhosin.session.encrypt = Off
            date.timezone = America/Bogota
                  

    y reinicie Apache.

5.  De permiso para completar instalación y pruebas desde el web,
    editando el archivo `config/main.inc.php` y cambiando la línea:

            $rcmail_config['enable_installer'] = true;

    y ejecutando:

            doas chmod -R a+rx /var/www/roundcubemail/installer

6.  Con un navegador examine el URL `https://correo.&EDOMINIO;/installer/`
    compruebe las dependencias solicitadas y realice las pruebas
    disponibles. Una vez concluya evite el uso de ese directorio
    ejecutando:

            doas chmod -R a-rx /var/www/roundcubemail/installer

    y cambiando en `config/main.inc.php` la línea:

            $rcmail_config['enable_installer'] = false;

Roundcubemail incluye plugins para diversas labores, por ejemplo si
desea añadir la posibilidad de cambiar la clave a los usuarios desde
este programa debe activar el plugin `password`, para esto:

1.  En el archivo `config/main.inc.php` agregue password en el arreglo
    `plugins`, si sólo tiene este plugin quedará:

            $rcmail_config['plugins'] = array('password');
                          

Si además desea permitir que los usuarios puedan cambiar su clave desde
este webmail active el plugin password como se presenta a continuación:

1.  Edite el archivo `config/main.inc.php` y añada `password` al arreglo
    `rcmail_config['plugins']`, por ejemplo si no hay otros plugins
    cambiando

            $rcmail_config['plugins'] = array();

    por

            $rcmail_config['plugins'] = array('password');

2.  Si no existe el archivo `plugins/password/config.inc.php` inicie uno
    con:

            cp plugins/password/config.inc.php.dist plugins/password/config.inc.php

3.  Modifique el archivo `plugins/password/config.inc.php` de acuerdo a
    su configuración, por lo menos los siguientes 3 valores deben
    cambiarse:

            $rcmail_config['password_driver'] = 'poppassd';
            $rcmail_config['password_pop_host'] = '127.0.0.1';
            $rcmail_config['password_pop_port'] = 106;

4.  Instale el paquete `openpoppassd` disponible en
    <ftp://ftp.pasosdeJesus.org/pub/AprendiendoDeJesus/> (tiene una
    falla corregida con respecto al paquete oficial por lo cual le
    sugerimos emplear ese) y configúrelo para que inicie durante el
    arranque por ejemplo agregando a `/etc/rc.local`:

            pgrep poppassd > /dev/null 2>&1
            if (test "$?" != "0") then {
                    echo -n ' poppassd'
                    /usr/local/libexec/openpoppassd
            } fi;

    Una vez lo haya iniciado puede probarlo con:

            telnet localhost 106

    que debe responder con:

            Trying 127.0.0.1...
            Connected to localhost.
            Escape character is '^]'.
            200 openpoppassd v1.1 hello, who are you?


### Listas de correo {#listas-correo}

#### Instalación de Mailman (sin `chroot`) {#mailman}

Instalar paquete de mailman `pkg_add $PKG_PATH/&p-mailman;.tgz` que
requiere `` se crean automáticamente el grupo `_mailman` y el usuario
`_mailman`

Leer `/usr/local/share/doc/mailman/README.OpenBSD`

Editar `/var/www/conf/httpd.conf` agregando la linea:

        ScriptAlias /mailman/ "$mailmandir/cgi-bin/"

donde \$mailmandir es `/usr/local/lib/mailman/` agregar también:

        <Directory "/usr/local/lib/mailman/cgi-bin">
            AllowOverride None
            Options None
            Order allow,deny
            Allow from all
        </Directory>

además agregar las lineas:

        Alias /pipermail/ "/var/spool/mailman/archives/public/"
        
        <Directory "/var/spool/mailman/archives/public/">
                Options FollowSymLinks
                AddDefaultCharset Off
        </Directory>

al mismo archivo.

Copiar los iconos: `cp /usr/local/lib/mailman/icons/*  /var/www/icons/`
Reiniciar el apache para que cargue los cambios.

        apachectl stop
        . /etc/rc.conf.local
        httpd $httpd_flags

editar el archivo `/usr/local/lib/mailman/Mailman/mm_cfg.py` agregando
las lineas

        DEFAULT_EMAIL_HOST = 'dominio.net'
        DEFAULT_URL_HOST = 'www.dominio.net'
        DEFAULT_URL_PATTERN = 'http://%s/mailman/'
        add_virtualhost(DEFAULT_URL_HOST, DEFAULT_EMAIL_HOST)

Crear primera lista llamada mailman

        /usr/local/lib/mailman/bin/newlist mailman

agregar a `/etc/mail/aliases` las lineas:

        ## mailman mailing list
        mailman:              "|/usr/local/lib/mailman/mail/mailman post mailman"
        mailman-admin:        "|/usr/local/lib/mailman/mail/mailman admin mailman"
        mailman-bounces:      "|/usr/local/lib/mailman/mail/mailman bounces mailman"
        mailman-confirm:      "|/usr/local/lib/mailman/mail/mailman confirm mailman"
        mailman-join:         "|/usr/local/lib/mailman/mail/mailman join mailman"
        mailman-leave:        "|/usr/local/lib/mailman/mail/mailman leave mailman"
        mailman-owner:        "|/usr/local/lib/mailman/mail/mailman owner mailman"
        mailman-request:      "|/usr/local/lib/mailman/mail/mailman request mailman"
        mailman-subscribe:    "|/usr/local/lib/mailman/mail/mailman subscribe mailman"
        mailman-unsubscribe:  "|/usr/local/lib/mailman/mail/mailman unsubscribe mailman"

Regenerar alias con `newaliases`

Poner en el crontab algunas lineas:

        crontab -u _mailman  /usr/local/lib/mailman/cron/crontab.in

Reiniciar mailman:

        /usr/local/lib/mailman/bin/mailmanctl start

Hacer que cada vez que se inicie el equipo corra mailman, agregando al
archivo `/etc/rc.local` las lineas:

        if [ X"$mailmanctl_flags" != X"NO" -a  \
            -x /usr/local/lib/mailman/bin/mailmanctl ]; then
                  echo -n ' mailman'
                  /usr/local/lib/mailman/bin/mailmanctl $mailmanctl_flags
        fi

y en `/etc/rc.conf.local`:

        mailmanctl_flags="-s -q start"

Asignar password al sitio de mailman con

        /usr/local/lib/mailman/bin/mmsitepass

##### Lecturas recomendadas {#lecturas-mailman}

* `/usr/local/share/doc/mailman/README.OpenBSD`

[^smtp.1]: De acuerdo al RFC 1123 los nombre MUA y MTA son propios del
    protocolo X.400.

[^smtp.2]: De acuerdo al protocolo SMTP, sendmail de &ENOMCLIENTE; se
    conectaría por el puerto 25 a sendmail en &ENOMCLIENTE2; y enviaría
    los mensajes `EHLO`, `MAIL FROM:
           &EUSUARIO;@&ECLIENTE;`, después enviaría
    `RCPT TO: &EUSUARIO2;@&ECLIENTE2;`, después `DATA` y a continuación el
    cuerpo del correo comenzando con el encabezado de acuerdo al RFC
    822, con un cuerpo de mensaje que emplee 7 bits y terminando con una
    línea que sólo tenga un punto. Por ejemplo

            From: &EUSUARIO;@&ECLIENTE;
            To: &EUSUARIO2;@&ECLIENTE2;
            Subject: Saludo

            Un cortísimo saludo para bendición de nuestro Creador.
            .  

    Si lo desea puede experimentar con este protocolo, empleando telnet
    y el MTA de su computador: `telnet localhost 25`. Claro resulta más
    transparente empleando directamente sendmail :

         
            sendmail -bm
            &EUSUARIO2;@&ECLIENTE2; -f
            &EUSUARIO;@&ECLIENTE; 

    (para emplear `-f` con sendmail debe ser usuario autorizado).

[^smtp.3]: Son inseguros porque transmiten claves y el contenido de los
    mensajes planos por la red

## Servidor `ftp`

Sólo recomendamos el servicio ftp para poner un servidor anónimo (con el
usuario `anonymous` y una clave arbitraria). No para que transfiera
datos de un usuario porque este servicio transmite claves planas por la
red, y así mismo transmite archivos sin cifrado alguno. Para
transferir información de usuarios emplee un protocolo seguro como
`scp`.

OpenBSD incluye un servidor de ftp auditado, para que los usuarios del
sistema puedan emplearlo basta agregar la siguiente línea al archivo
`/etc/rc.conf.local`:

        ftpd_flags="-D -A"

Que especifica operar en el fondo y sólo para recibir conexiones
anónimas. Para ejecutarlo sin reiniciar use:

        /usr/libexec/ftpd -D -A

Para permitir conexiones anónimas debe crear una cuenta `ftp`. Los
detalles de creación al usar `adduser` se presentan a continuación
(emplee una clave difícil, preferiblemente generada con `apg`):

        Enter username []: ftp
        Enter full name []: FTP anonimo
        Enter shell csh ksh nologin sh [ksh]: nologin
        Uid [1008]: 
        Login group ftp [ftp]: 
        Login group is ``ftp''. Invite ftp into other groups: guest no 
        [no]: 
        Login class auth-defaults auth-ftp-defaults daemon default staff 
        [default]: auth-ftp-defaults
        Enter password []: 
        Enter password again []: 

Después puede ubicar lo que desee que aparezca en el servidor ftp en el
directorio de tal cuenta (e.g `/home/ftp`) y quitar los permisos de
escritura para todos los usuarios.

Cuando un usuario anonymous inicie una sesión, el servidor pondrá el
directorio `/home/ftp` como jaula (chroot) de la conexión. Se espera que
el dueño de ese directorio sea root y no permita escritura (modo 555),
como subdirectorios se espera:

-   bin: puede ubicar programas que permitirá que sean ejecutados (no se
    recomienda). De tenerlo el dueño debe ser root y no permitir
    escritura ni lectura por nadie (modo 511).

-   etc: El dueño debe ser root y no permitir escritura ni lectura de
    nadie (modo 511). Para que `ls` presente nombres en lugar de números
    deben estar presentes `pwd.db` y `group` (sin claves reales). Si
    existe el archivo `motd` será presentado tras ingresos exitosos.
    Estos archivos deben tener modo 444.

-   pub: el dueño debe ser root, sin permitir escritura de nadie (modo
    555). En este directorio se ponen los archivos por compartir.

Si desea mantener una bitácora de las descargas que se realicen (en
`/var/log/ftpd`), asegúrese de agregar entre los flags en
`/etc/rc.conf.local`, las opciones `-S -l` y ejecutar:

        touch /var/log/ftpd

### Servicio FTP en una DMZ {#ftpdmz}

Si su servicio ftp opera en un servidor de la red interna, puede emplear
ftp-proxy para hacerlo visible al exterior.

Además del ftp-proxy que podría estar corriendo en el cortafuegos para
servir a la red interna, debe ejecutar una segunda instancia que opere
en modo reverso. Para esto agregue en `/etc/rc.local`:

        pgrep ftp-proxy > /dev/null
        if (test "$?" != 0  -a X"${ftpproxy_flags}" != X"NO" -a \
            -x /usr/sbin/ftp-proxy) then {
            echo -n ' ftp-proxy'
            /usr/sbin/ftp-proxy ${ftpproxy_flags}
            /usr/sbin/ftp-proxy -b 200.1.10.44 -p 21 -a 200.1.10.44 -R 192.168.1.30
        } fi;

cambiando 200.1.10.44 por su IP pública y 192.168.1.30 por la IP del
servidor en el que corre ftp.

Para monitorear su operación antes de activarlo puede emplear las
opciones `-D 7 -dvv` que lo hará correr en primer plano enviando
bitácora a salida estándar con máximo nivel de verbosidad.

### Referencias y lecturas recomendadas {#referencias-ftp}

La página del manual de `ftpd`.


## Servidor web {#servidor-web}

Un servidor web recibe peticiones acordes al protocolo HTTP, las procesa, 
recolecta la información que va retornar y la retorna típicamente en 
HTML/CSS/Javascipt también mediante el protocolo HTTP.     
Las peticiones pudieron pasar antes por el cortafuegos si lo hay o de otro 
servidor que actue como proxy.

El siguiente diagrama presenta más detalles de los elementos involucrados
en servir páginas web generadas por una aplicación Ruby on Rails.

![Diagrama de peticion y respuesta web](img/diagrama-web.png)


Así que la configuración de un servidor web debe tener en cuenta por lo 
menos:

* Al lado del usuario, la forma de los URL que se espera que emplee. 
  Por ejemplo es más simple de configurar, pero menos usable, si el 
  usuario emplea directamente la dirección IP en lugar de un nombre de servidor.
* La lado del servidor, de donde provienen el HTML el CSS y el Javascript.
  Por ejemplo es más simple servir páginas HTML, CSS y Javascript alojadas en 
  el sistema de archivos, que páginas generadas con PHP o que páginas 
  generadas con Ruby.
* Al lado del usuario y del servidor si la conexión será cifrada o no.

adJ y OpenBSD incluyen en el sistema base su propio servidor 
OpenBSD httpd.  Es eficiente aunque mínimo, por lo que puede emplearse
también el paquete nginx, especialmente entre más compleja sea la generación
de páginas al lado del servidor.

Ambos pueden emplear certificados SSL tanto comprados como los gratuitos
de Let's Encrypt.

### nginx

nginx es un servidor web que en el caso de adJ está incluido entre
los paquetes que se insalan por omisión.
Su binario queda ubica en `/usr/local/sbin/nginx` y puede consultar la versión 
ejecutando `nginx -v`

Cuando corre en OpenBSD lee el archivo de configuración `/etc/nginx/nginx.conf`
y después cambia el directorio raíz  con `chroot` a  `/var/www` para correr en 
esa jaula. Esta es una medida de seguridad para evitar que un atacante que 
desde el web logre acceso al sistema de archivos pueda ver o escribir en 
archivos de configuración (como los de `/etc`) o binarios o el kernel mismo, 
un atacante vería como raíz lo que este en `/var/www`.

Puede iniciarlo manualmente con:

        doas /etc/rc.d/nginx start

y detenerlo con

        doas /etc/rc.d/nginx stop

Para que inicie automáticamente en cada arranque basta agregar en
`/etc/rc.conf.local`:

       nginx_flags=""

y que añada `nginx` en `pkg_scripts`.


#### Generalidades del archivo de configuración de nginx

El archivo de configuración consta de directivas que le indican a nginx 
como responder a solicitudes http.

Algunas de las directivas del archivo de configuracioń tienen bloques que a su 
vez tienen directivas. Cada bloque se inicia con `{` y se cierra con `}`.  
Las directivas que no tienen bloque deben terminarse con `;`

Pueden ponerse comentarios a la derecha del símbolo `#` en cualquier línea (el 
resto de la línea después del `#` es comentario).

El siguiente es un archivo de configuración mínimo para que nginx sirva
páginas estáticas HTML, CSS y Javascript alojadas en el sistema de 
archivos en `/var/www/htdocs/`, iniciando por omisión con `index.html`
requiriendo que el usuario final acceda desde el mismo servidor con un 
navegador empleando una dirección de la forma <http://127.0.0.1>

	http {
	  include mime.types;
	  default_type application/octet-stream;
	  index index.html;
	  server {
	    server_name 127.0.0.1;
	    listen 80:
	    root htdocs;
	  }
	}

Dentro del bloque de la directiva `http` debe ponerse una directiva 
`server` por cada sitio web que sea servido por nginx. 

La directiva `server` tiene un bloque dentro del cual deben ponerse,
entre otras, las directivas `server_name` (con nombre de servidor) y 
`listen` (con puerto) acordes a los URLs que se esperan sean usados 
por los usuarios y otras directivas de acuerdo al contenido que se
desea servir.

En el ejemplo anterior la directiva `root` indica que se servirán
contenido alojado en el sistema de archivos en la ruta `/var/www/htdocs`
(como nginx correo en la jaula `/var/www` basta indicar la ruta
dentro de esa).  La directiva `index index.html` indica que si
el usuario no especifica una ruta particular en el URL se servirá
el archivo `/var/www/htdocs/index.html` que si desea probar puede 
iniciar con el contenido:

	<h1>Bienvenido a servir contenido web con nginx</h1>


#### Configuración de `server_name` y `listen` de acuerdo a URLs que se esperan del usuario

Los URLs que usen que incluyen el protocolo (`http` sin cifrar o
`https` con cifrado) el nombre del servidor (o dirección IP si no tiene 
dominos DNS configurados) y el puerto (si el usuario no emplea un puerto 
y el URL comienza con `http` se usa el puerto 80, o si comienza con 
`https` se emplea por omisión el puerto 443).

Otro caso sencillo de configurar es servir contenido estático HTML, CSS
y Javascript a usuarios ubicados en computadores en una red local en
la que el servidor tiene una IP estática asignada (digamos
192.168.20.20) o si ha contratado una IP pública con su proveedor de 
Internet digamos 125.125.123.1

	http {
	  include mime.types;
	  default_type application/octet-stream;
	  index index.html;
	  server {
	    server_name 125.125.123.1;
	    listen 80:
	    root htdocs;
	  }
	}


Si prefiere usar un nombre en lugar de una IP (digamos &EDOMINIO;) 
deberá tramitar el registro del dominio ante un registrador y pagar la 
anualidad.  En tal caso la sección `server` para el puerto 80 sería 
(cambiando `www` por el registro que hay configurado en su dominio y 
`minombre.org` por el dominio que haya contratado): 

	  server {
	    server_name www.minombre.org;
	    listen 80:
	    root htdocs;
	  }

Claro que es posible configurar a manera de prueba resolución local en un 
computador para que el nombre se asocie a la IP esperada o incluso si tiene 
control de un resolvedor de una red local para que en la red local el 
nombre resuelva al servidor donde corre el nginx.

##### Pruebas cambiando resolución local en un computador

Si en su red local el servidor nginx corre en la dirección 192.168.10.2, 
en otro computador con adJ (digamos con IP 192.168.10.15) podría configurar 
la resolución local para asociar www.midominio.org a la IP 192.168.10.2.

Eso lo puede hacer en el archivo `/etc/hosts` con una línea de la forma

	192.168.10.2 www.midominio.org

Siempre y cuando en  `/etc/resolv.conf` tenga `lookup file`

##### Pruebas en una red cambiando resolución local para la red

Para cambiar la resolución de nombres en una red local podría emplear un 
servidor de nombres completo como `nsd`, pero basta con un resolvedor 
como `unbound`.

Por ejemplo si `unbound` corre en el servidor 192.168.10.1 para su 
dominio `midominio.org`, puede configurarlo para que dirija a 192.168.10.2 
cuando desde la red local soliciten `www.mindominio.org`, modificando
el archivo `/var/unbound/etc/unbound.conf` para que incluya:

	interface: 127.0.0.1
	interface: 192.168.10.2

	access-control: 192.168.10.0/24 allow

	local-zone: "midominio.org" static
	local-data: "midominio.org IN A 192.168.10.2"
	local-data: "www.midominio.org IN A 192.168.10.2"


Cada vez que haga modificaciones al archivo de configuracion de unbound 
debe reiniciar por ejemplo con:

	doas rcctl -d restart unbound

Y en cada computador de la red local debe configura que el servidor DNS sea 192.168.10.1.


##### Pruebas cambiando configuración de servidor DNS

Si está pagand a su proveedor de Internet una IP (digamos 125.125.121.1) 
y si pagó el registro de un dominio (digamos www.midominio.org) ante un 
registrador de dominios, debe editar la configuración del servidor DNS
que haya configurado con el registrador (muchos registradores ofrecen
servidores DNS editables desde el web). 

Debe agregar un registro que indique que las peticiones a su dominio
y al y al subdominio `www.midominio.org` se dirigen a la IP pública de 
su servidor.  Tanto con `bind` como con `nsd` que son 2 servidores DNS
populares se harían con líneas de la forma:

	midominio.org.	A	125.125.121.1;
	www.midominio.org.	A	125.125.121.1;

#### Configuración de nginx de acuerdo a como se almacenan o generan páginas en el servidor

Hay varias posibilidades:

- Servir archivos HTML del sistema de archivos, para lo que bastan
  las directivas `root`  e `index` antes introducidas.

- Generar automáticamente páginas HTML para permitir ver directorios y 
  archivos y descargar archivos, para lo que basta que agregue
  la directiva `autoindex on;`

- Redirigir la petición a un proceso que corre en el mismo servidor mediante 
  un socket, por ejemplo para servir páginas con un programa en PHP o para
  servir páginas generadas con una aplicacińo sobre Ruby on Rails.

- Redirigir la petición a otro computador donde corra un servidor web 
  operando así como un proxy

##### Caso: Servir archivos HTML ubicados en el sistema de archivos

Este es el caso de uso original, se espera que organice los contenidos HTML 
(junto con gráficas, documentos que referencien, hojas de éstilo CSS, fuentes 
Javascript, etc) en un directorio (tal vez con subidrectorios).  Como debe 
ser servidor por nginx debe estar dentro de `/var/www` y el lugar por omisión 
y recomendado es dentro de `/var/www/htdocs`.  El archivo inicial suele 
llamarse `index.html`.

Por ejemplo:

	doas mkdir /var/www/htdocs/miproyecto1
	doas chown $USER:$USER /var/www/htdocs/miproyecto1
	cat > /var/www/htdocs/miproyecto1/index.html << EOF
	A Dios sea la gloria
	EOF

Después debe editar el archivo de configuración de nginx para agregar una 
sección para su nuevo servicio.   Suponiendo que los usuarios usarán la 
IP 192.168.10.50 y el puerto 8080 (i.e con una URL de la forma 
<http://192.168.10.50:8080>:

	server { 
	  listen 8080;
	  server_name 192.168.10.50;
	  root /var/www/htdocs/miproyecto1;
	  index index.html;

	  error_log logs/miproyecto1-error.log;
	  access_log logs/miproyecto1-access.log ;
	} 

Note que  se agregan las directivas `error_log` y `acces_log` que
indican que las bitácoras de errores y de acceso quedarán
en `/var/www/logs/miproyecto1-error.log` y
`/var/www/logs/miproyecto1-access.log`


##### Caso: Servir páginas generadas por un programa en PHP {#nginx-php}

En el caso de adJ, se recomienda emplear php con nginx mediante Fast-CGI
comunicandose con un zócalo (socket) ubicado en 
`/var/www/var/run/php-fpm.sock`

Para esto una vez instalado el paquete &p-php; configure:

1. Que en cada arranque se inicie el servicio `php73_fpm` por ejemplo con:

    doas rcctl enable php73_fpm

2. Que `php73_fpm` use el socket en la ubicación correcta, para esto cambie 
el archivo `/etc/php-fpm.ini` para que en lugar de la línea con comentario 
`;listen =` tenga:

    listen = /var/www/var/run/php-fpm.sock

En un servidor los archivos de PHP suelen mezclarse con archivos HTML así 
que la configuración del caso anterior servirá, pero además debe añadir 
dentro de la misma sección server una directiva `location` que le indique a 
nginx que debe tratar de manera especial los archivos que terminen con la 
extensión php, esos archivos debe servirlos con el protocolo FastCGI usando 
el servicio que respone en el socket apropiado (recordando quitar el 
`/var/www` de la ruta por lo que nginx corre dentro de la jaula `/var/www`):

	location ~ ^(.+\.php)$ {
	  try_files $uri =404;
	  fastcgi_intercept_errors on;
	  include fastcgi_params;
	  fastcgi_param SERVER_NAME $host;
	  fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
	  fastcgi_index index.php;
	  fastcgi_pass unix:/var/run/php-fpm.sock;
	}

Si además prefiere que el archivo de inicio por omisión sea
`index.php` en lugar de `index.html` cambie la directiva `index` para
que primero intente con `index.php` y si este falta intente con 
`index.html`:
	
	index index.php index.html;	
 
#### Soportar cifrado entre cliente y servidor

El cifrado con TLS requiere en el servidor un certificado firmado por una
autoridad certificadora que consta de un archivo público y uno privado.   
Típicamente usted debe generar ambos archivos y enviar el público a una
autoridad certificadora, que por un pago, lo devolverá firmado.

Otra posibilidad es que emplee los certificados gratuitos generados por
Let's Encrypt como se describe más adelante.

Supongamos que tiene un certificado con parte pública en 
`/etc/ssl/midominio.org.crt` y para privada en 
`/etc/ssl/private/midominio.org.key`.

Como se ha mencionado el bloque de la directiva `server` posiblemente 
tendrá `listen 443;` (si escucha en puerto estándar), el mismo bloque debe 
tener:

	  ssl on;
	  ssl_certificate /etc/ssl/midominio.org.crt;
	  ssl_certificate_key /etc/ssl/private/midominio.org.key;


### Certificados SSL gratuitos con Let's Encrypt {#letsencrypt}

Hasta hace un tiempo era impensable contar con un certificado SSL válido
para los diversos navegadores (candadito verde) y que fuese gratuito.
Sin embargo algunas empresas empezaron a ofrecerlos (e.g Gandi da
certificado gratuito por un año para un dominio por la compra de un
dominio), y finalmente de diversos intentos por parte de organizaciones
sin ánimo de lucro, letsencrypt.org es reconocida por los navegadores
principales y ofrece todo tipo de certificados validos por 3 meses de
manera gratuita (cada 3 meses debe renovarse con el mismo letsencrypt).

Por ejemplo para un dominio &EDOMINIO; sólo certificado para el web:

        doas letsencrypt certonly --webroot -w /var/www/htdocs/ -d &EDOMINIO; -d www.&EDOMINIO; 

Si además de los dominios web necesita cubrir con el mismo certificado
el servidor de correo: correo.&EDOMINIO; que tiene una raíz diferente:

        doas letsencrypt certonly --webroot -w /var/www/htdocs/ -d &EDOMINIO; -d www.&EDOMINIO;  -w /var/www/roundcubemail -d correo.&EDOMINIO;




### OpenBSD httpd

A continuación describimos algunos casos de uso del nuevo `httpd` que
soporta contenido estático, FastCGI sin reescritura y SSL. Sus fuentes
se basan en las de `relayd` que fue introducido y madurado en OpenBSD
desde la versión 4.1 (inicialmente llamado `hoststated`).

#### Configuración mínima {#httpd-min}

En el archivo `/etc/rc.conf.local` agregue:

        httpd_flags=""

y en adJ agregue `httpd` a la variable `pkg_scripts`.

Se configura en el archivo `/etc/httpd.conf` cuya sintaxis tiene algunas
similitudes con la de `nginx` y con la de `relayd`. Puede constar de 4
secciones: macros, configuraciones globales, uno o más servidores y
tipos.

La sintaxis de la sección de tipos es idéntica a la de `nginx` y como
puede usarse `include` para incluir otro archivo de configuración, el
siguiente es un ejemplo mínimo (incluyendo el macro `ext_ip`):

        ext_ip="200.201.202.203"
        server "default" {
            listen on $ext_ip port 80
        }
        include "/etc/nginx/mime.types"

Podría probarlo iniciando en modo de depuración con:

        doas httpd -vn

Y examinando con un navegador la URL `http://200.201.202.203`, con lo
que vería el archivo `/var/www/htdocs/index.html` y notaría que:

-   Debido a la opción `listen on $ext_ip port 80` serviría por el
    puerto 80 de 200.201.202.203. En lugar de \$ext\_ip puede usar una
    interfaz o incluso un grupo como `egress` para servir en todas las
    interfaces conectadas a Internet.

-   Por defecto pondría una jaula chroot en `/var/www`. Esto podría
    modificarse en la sección de configuración, antes del primer
    `server` y después del macro con la opción `chroot directorio`

-   Iniciaría 3 procesos para servir páginas. Esto puede modificarse en
    la sección de configuración con la opción `prefork numero`

-   Que serviría los archivos de `/var/www/htdocs`. Esto puede
    modificarse agregando la opción `root directorio_relativo_a_jaula`
    dentro de la sección `server`.

#### Servidor con cifrado {#httpd-ssl}

Al ejemplo de configuración mínima anterior bastaría agregarle ssl a la
opción listen e indicar el puerto 443, que es el asignado por defecto
para HTTPS:

        ext_ip="200.201.202.203"
        server "default" {
            listen on $ext_ip ssl port 443
        }
        include "/etc/nginx/mime.types"

El certificado que emplea por defecto es el par `/etc/ssl/server.crt` y
`/etc/ssl/private/server.key`. Podría especificarse otro par con las
opciones `ssl certificate archivo` y `ssl key archivo` dentro de la
sección server.

#### Dominios virtuales {#httpd-dom}

Si la misma IP debe servir diversos dominios, cree una sección `server`
por cada dominio con el nombre del dominio y emplee la misma opción
`listen` para todos y si es el caso directorios raices diferentes.

Si se configuraran los dominios www.miescuela.edu.co y
www.otrodominio.co apuntando a la misma IP de los ejemplos anteriores y
tiene las páginas de cada dominio en `/var/www/htdocs/miescuela` y
`/var/www/htdocs/otrodominio`:

        ext_ip="200.201.202.203"
        server "www.miescuela.edu.co" {
            listen on $ext_ip port 80
            root /htdocs/miescuela
        }

        server "www.otrodominio.co" {
            listen on $ext_ip port 80
            root /htdocs/otrodominio
        }

        include "/etc/nginx/mime.types"

#### Sitio con PHP {#httpd-php}

Es posible que sirva contenidos PHP usando php-fpm como FastCGI. Sin
embargo debe asegurar haber aplicado los parches más recientes para 5.6
(ya incluidos en binarios de adJ) y tener en cuenta que no soporta, y
posiblemente no soportará reescritura de URLs.

Una configuración mínima para SIVeL 1.2 que opere en 192.168.1.1, con
archivos en `/var/www/htdcos/sivel` y con SSL es:

        server "192.168.1.1" {
            listen on egress ssl port 443

            location "*.php" {
                fastcgi socket "/run/php-fpm.sock"
            }
            root "/htdocs/sivel/"
            include "/etc/nginx/mime.types"
        }

Operará bien con la configuración por defecto de php-fpm, que puede
instalar con:

        doas pkg_add php-fpm
        doas cp /usr/local/share/examples/php-5.4/php-fpm.conf /etc/

e iniciar con:

        doas sh /etc/rc.d/php-fpm start

o mejor en cada arranque de su sistema editando `/etc/rc.conf.local` y
agregando

-   Agregar `php_fpm_flags=""`

-   A la variable `pkg_scripts` añadir `php-fpm`

#### Otros detalles de uso {#httpd-otros}

Si requiere volver a leer archivo de configuración, en lugar de reiniciar
httpd puede ejecutar:

                            pkill -HUP httpd

El formato de las bitácoras por defecto es similar al de `nginx`



