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

### Jaula sftp {#jaula-sftp}

Supongamos que requiere que unos usuarios puedan sólo ingresar por sftp a 
una jaula de archivos que incluya sus archivos y otros directorios y archivos
pero no al sistema de archivos completo.
Para esto agregue un grupo, digamos `jaulasftp`, al archivo `/etc/group`
con un gid no usado (digamos 1002):

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

Note que no se le permite realizar túneles ni reenvíos y sólo puede
usar el sistema `internal-sftp` confinado a `/restovar/jaulasftp`

Por ejemplo con `doas vipw` edite cada usuario por limitar (en
el siguiente ejemplo `uslim`) para asegurar que
su línea es de la forma siguiente:

        uslim:$2b$10$dEPqLC7YSmilUNURQXp2AeiptJVJ38H6ZsiI25w7fisMboDkBCZy.:1005:1002::0:0:Usuario Limitado:/home/uslim:/bin/false

Teniendo en cuenta que para este usuario de ejemplo `uslim`:

1. Su grupo principal es el 1002 - jaulsftp
2. No tiene interprete de órdenes, es decir que es `/bin/false`
3. Su directorio personal es `/home/uslim` pero dentro de jaula, pues
   el administrador ubicará su directorio en `/restovar/jaulasftp/home/uslim`


Cree el directorio `/restovar/jaulasftp/home/uslim` y ponga la información
del directorio personal del usuario `uslim`.

Cuando ese usuario ingrese vía sftp verá como raíz del sistema de
archivos lo que haya en `/restovar/jaulasftp`  y podrá ingresar a los 
directorios y archivos dentro de esa jaula en la medida que el sistema de 
permisos típico se lo permita.


### Referencias y lecturas recomendadas {#referencias-sshd}

Las siguientes páginas man: sshd 8, sftp 1.

Separación de privilegios:
<http://www.counterpane.com/alert-openssh.html>

Página web: <http://www.openssh.com>

Ejemplo de jaula sftp: <https://www.golinuxcloud.com/sftp-chroot-restrict-user-specific-directory/>

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
DHCP desde la línea de órdenes con:

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

### Instalación de OpenBSD/adJ en red {#instalacion-openbsd-red}

En un servidor OpenBSD, prepare un directorio para servir archivos de arranque
con tftp:

doas mkdir /var/tftp
doas cp /usr/mdec/pxeboot /var/tftp
doas cp /bsd.rd /var/tftp
doas chown -R _tftpd /var/tftp
cp 


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

OpenBSD incluye en el sistema base el MTAs OpenSMTPD y cuenta con un 
porte de `sendmail`.
En este capítulo detallamos la configuración de OpenSMTPD,
así como la configuración del paquete `dovecot` que implementa los
protocolos auxiliares POP3S e IMAPS para leer correo de manera segura,
así como de SpamAssassin para combatir spam y el cliente de 
correo web Roundcube.

En [versiones históricas de este documento](https://github.com/pasosdeJesus/servidor_adJ/blob/servidor_adJ-7.0/protocolossop.md#servidor-de-correo-electr%C3%B3nico-servicios-correo) 
podrá consultar sobre la configuración de sendmail (otro MTA), de couriermail
(otro sistema que implementa POP3S e IMAPS) y de mailman (para manejar 
listas de correo).


adJ cuenta con la órden `prepopensmtpd` que
configura de manera automática OpenSMTPD con
TLS y SASL, así como POP3S e IMAPS. Soportan opcionalmente mantener el
correo en una partición cifrada y copia de respaldo del correo en otra
partición también cifrada. Antes de emplearlos ejecute:

        doas cp /usr/local/share/examples/adJ/varcorreo.sh /etc/

y a continuación edite el archivo recién copiado para adaptarlo a su
entorno.

### Protocolo SMTP para enviar y recibir correo {#smtp}

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
en el puerto 25, i.e. `smtpd` (que es el servicio de OpenSMTP) o algún 
otro MTA que reciba el mensaje siguiendo el protocolo SMTP.

`smtpd` en &ENOMCLIENTE2; agrega el mensaje que recibe en el archivo tipo
texto `/var/mail/&EUSUARIO2;` que está en formato mbox.

Cuando &EUSUARIO2; lo desee, podrá emplear `mail` para leer los correos
que se hayan acumulado en `/var/mail/&EUSUARIO2;` ---a medida que los lea
saldrán de ese archivo para quedar en `~/mbox`.

Este es el esquema básico, aunque hay muchas otras situaciones en las
que se emplean otras posibilidades de SMTP, protocolos auxiliares y
programas. Por ejemplo los usuarios de una organización suelen extraer
sus correos del servidor desde otros computadores con MUAs gráficos
empleando los protocolos seguros POP3S e IMAPS. 
También es posible configurar un cliente de correo web (webmail)
para examinar correos desde el web. 

#### MTA OpenSMTPD {#opensmtpd}

Se trata de un MTA desarrollado principalmente para OpenBSD por
desarrolladores de OpenBSD. 

El servicio se inicia con:

        doas rcctl start smtpd

y se detiene con:

        doas rcctl stop smtpd

Para que inicie en cada arranque ejecute
        doas rcctl enable smtpd

lo cual modificará el archivo `/etc/rc.conf.local` y agregará `smtpd` a la 
variable `pkg_scripts` y allí mismo agregará la línea

        smtdp_flags=""

Puede también verificar que `/etc/mailer.conf` incluya:

        sendmail        /usr/sbin/smtpctl
        send-mail       /usr/sbin/smtpctl
        mailq           /usr/sbin/smtpctl
        makemap         /usr/sbin/smtpctl
        newaliases      /usr/sbin/smtpctl

Una vez en operación pueden examinarse diversos aspectos (como
bitácoras, examinar cola de correos o estadísticas) con `smtpctl`.

La configuración se define en el archivo `/etc/mail/smtpd.conf`. La
configuración más simple que sólo aceptará correo local con aliases
definidos en `/etc/mail/aliases` y lo dejará en
formato mbox en `/var/mail` o hará relevo es:

        listen on lo0

        table aliases file:/etc/mail/aliases

        action "local_mail" mbox alias <aliases>
        action "outbound" relay

        match for local action "local_mail"
        match for any action "outbound"

Puede verificar la sintaxis del archivo de configuración con:

        doas smtpd -n

Y puede iniciar el servicio en consola produciendo mucho detalle de
depuración con:

        doas smtpd -d -vvvvvvvvv

Y probar un envío a un usuario local con:

        mail &EUSUARIO;@localhost
        Subject: hola
        
        1,2,3
        .

Si prefiere recibir en formato maildir (por defecto en `~/Maildir` de 
cada usuario) y tener opción de procesar usuario a usuario con procmail 
vía el archivo `~/.forward` es mejor cambiar 
`action "local_mail" mbox alias <aliases>` por:

       action "local_mail" maildir alias <aliases>

La tabla de alias que usa esta configuración es el archivo plano
`/etc/mail/aliases`. Si prefiere usar base de datos DB en lugar de
archivo plano genere la base a partir del archivo plano con:

        doas newaliases

Y en el archivo de configuración cambie 
`table aliases file:/etc/mail/aliases` por:

        table aliases db:/etc/mail/aliases.db

Para que permita enviar y recibir desde otros computadores debe habilitar
TLS, así como generar certificado SSL
y dejar `&EDOMINIO;.crt` en `/etc/ssl/` 
y `&EDOMINIO;.key` en `/etc/ssl/private` para
después agregar al archivo de configuración:

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

Para asegurar el relevo de correos provenientes de &EDOMINIO; o de la IP
192.168.1.2, basta agregar al mismo archivo de configuración:

        match for &EDOMINIO; action "outbound"
        match for 192.168.1.2 action "outbound"



##### Depuración de OpenSMTP {#smtpd-depura}

OpenSMTP envía mensajes de error a la bitácora `/var/log/maillog`. Puede
ejecutarse en modo de depuración para determinar problemas con:

        smtpd -d -vvvvv

Esto no lo activará como servicio y presentará errores detallados en pantalla.

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

Para probar la autenticación debe usar OpenSSL.
Bien conectandose de manera cifrada directamente al puerto 465:

        openssl s_client -connect correo.&EDOMINIO;:465

O iniciando sesión de TLS por el puerto 25 o por el puerto 587:

        openssl s_client -connect correo.&EDOMINIO;:587 -starttls smtp
        ...
            Start Time: 1578243911
            Timeout   : 7200 (sec)
            Verify return code: 0 (ok)
        ---
        250 HELP
        EHLO [200.21.23.4]
        250-correo.&EDOMINIO; Hello [200.21.23.4] [200.21.23.4], pleased to meet you
        250-8BITMIME
        250-ENHANCEDSTATUSCODES
        250-SIZE 134217728
        250-DSN
        250-AUTH PLAIN LOGIN
        250 HELP


Una vez tenga una conexión con TLS tendrá disponibles autenticación `AUTH` con 
métodos `PLAIN` y `LOGIN`. 
Para autenticarse debe dar una identificación y una clave válida en el
sistema pero codificadas en base 64. Para esto instale el paquete
`base64` con `pkg_add base64` y para ver la cadena que tendría que emplear 
con `AUTH PLAIN` use:

        printf '\0MiUsario\0MiClave' | base64
        AE1pVXNhcmlvAE1pQ2xhdmU=

o para ver las 2 cadenas por usar con `AUTH LOGIN` use:

        printf 'MiUsario' | base64  
        TWlVc3Vhcmlv
        printf 'MiClave' | base64  
        TWlDbGF2ZQ==

Para obtener la codificación de una cadena en base 64 también podría emplear
un sitio como <http://www.motobit.com/util/base64-decoder-encoder.asp>
(aunque no es recomendable digitar el par usuario y clave válidos).

Retomando la sesión iniciada y usando estos datos con `AUTH PLAIN`:

        AUTH PLAIN
        334
        AE1pVXNhcmlvAE1pQ2xhdmU=
        235 2.0.0: Authentication succeeded

o bien con `AUTH LOGIN`:

        AUTH LOGIN
        334 VXNlcm5hbWU6
        TWlVc3Vhcmlv
        334 UGFzc3dvcmQ6
        TWlDbGF2ZQ==
        235 2.0.0: Authentication succeeded

puede intentar el envío de un correo por ejemplo con:

        mail from:<&EUSUARIO;@&EDOMINIO;>
        250 OK
        rcpt to:<&EUSUARIO2;@&EDOMINIO;>
        250 Accepted
        data
        354 Enter mail, ending with "." on a line by itself
        From: "&EUSUARIO;@&EDOMINIO;" <&EUSUARIO;@&EDOMINIO;>
        To:  &EUSUARIO2;@&EDOMINIO;
        Subject: probando
        1234
        .
        250 2.0.0 52476910 Message accepted for delivery
        quit


De requerirlo puede rastrear problemas en `/var/log/maillog`[^smtp.4]: 


#### Referencias {#referencias-opensmtpd}

- `man smtpd`, `man smtpd.conf`, `man smtpctl`

- <http://www.opensmtpd.org/>

- <https://wiki.archlinux.org/title/OpenSMTPD#Local_mail>

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
IMAPS En esta sección se describe la configuración de estos.

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

y pruébelo en los puertos 143 (IMAP sin cifrar), 993 (IMAP sobre SSL),
110 (POP3 sin cifrar) y 995 (POP3 sobre SSL). Por defecto dovecot
intentará recuperar correos en formato maildir de la carpeta `Maildir`
de cada usuario.

##### Pruebas a POP3S {#dovecot-pop3s}

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

##### Pruebas a IMAPS {#dovecot-imaps}

IMAP es un protocolo que permite a un MUA examinar y administrar correos
que llegan a un servidor, típicamente sin sacar los correos del servidor
(a diferencia de POP) y con la posibilidad de manejar
directorios/carpetas.

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

    set folder=imaps://localhost/



##### Referencias y lecturas recomendadas {#referencias-dovecot}

* El protocolo POP3 se describe en el RFC 1939
<http://www.faqs.org/rfcs/rfc1939.html> 
* Más sobre IMAP en <http://www.linux-sec.net/Mail/SecurePop3/ > y
<http://talk.trekweb.com/~jasonb/articles/exim_maildir_imap.shtml>
* POP3S e IMAPS en OpenBSD/LDAP/Sendmail
<https://dhobsd.pasosdejesus.org/pop3s_e_imaps_en_openbsd_ldap_sendmail.html>

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
que suponene que el usuario `pablo` maneja su correo en formato `maildir` 
(para permitir consulta con IMAPS --ver 
[Implementación Dovecot de IMAPS y POP3S](#dovecot)):

        LINEBUF=4096
        VERBOSE=on
        PMDIR=/home/pablo
        LOGFILE=/home/pablo/proclog
        
        :0fw: spamassassin.lock
        * < 256000
        | spamc
        
        :0:
        * ^X-Spam-Status: Yes
        /home/pablo/Maildir/.Junk/ # This is the mailbox where all spam goes.
        
        
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

Basta instalar el paquete `roundcubemail` o descargar las fuentes más
recientes de <http://sourceforge.net/projects/roundcubemail/> e
instalarlas en `/var/www/roundcubemail`, y seguir instrucciones del
archivo INSTALL.  Las complementaremos aquí suponiendo que en el 
mismo servidor (`correo.&EDOMINIO;`) están los servicios IMAPS y 
SMTP y que se empleará el motor de bases de datos PostgreSQL:

1.  Tras instalar, el cliente quedará en `/var/www/roundcubemail` por lo
    que es necesario configurar el servidor web. Por ejemplo si el
    correo de la organización se consultará en `correo.&EDOMINIO;` (IP
    interna 192.168.60.1 y externa 200.200.200.200) con protocolo HTTPS,
    el archivo `/etc/nginx/nginx.conf` debe incluir:


        location /roundcubemail/ {
                root /var/www/htdocs/;
                index index.php;

                location ~ ^/roundcubemail/(.+\.php)$ {
                        root /var/www/htdocs/;
                        try_files $uri =404;
                        fastcgi_intercept_errors on;
                        include        fastcgi_params;
                        fastcgi_param  SERVER_NAME      $host;
                        fastcgi_param  SCRIPT_FILENAME  $document_root$fastcgi_script_name;
                        fastcgi_read_timeout 900;
                        fastcgi_index       index.php;
                        fastcgi_pass   unix:/var/run/php-fpm.sock;
                }

                location ~ ^/roundcubemail/logs/errors {
                       deny all;
                }
        }


2.  Para configurar una base de datos en PostgreSQL con socket en
    `/var/www/var/run/postgresql` (ver [???](#postgresql)) ejecutar:

            doas su - _postgresql
            createuser -h /var/www/var/run/postgresql -Upostgres roundcube
            createdb -h /var/www/var/run/postgresql -Upostgres -E UNICODE roundcubemail -T template0
            psql -h /var/www/var/run/postgresql -Upostgres template1

    y desde la interfaz administrativa de PostgreSQL establezcla una
    clave para el usuario `roundcube` con:

            ALTER USER roundcube WITH PASSWORD 'nueva_clave';

    Salir con '\\q' y desde la línea de órdenes ingresar a la nueva
    base con:

            psql -h /var/www/var/run/postgresql -Uroundcube roundcubemail

    le solicitará la clave que estableció para el usuario `roundcube`.

3.  Salga de la interfaz de PostgreSQL con `\q` y de la cuenta
    \_postgresql con `exit`. Después debe configurar roundcubemail,
    editando los archivos del directorio
    `/var/www/roundcubemail/config`. Si al examinar con

            ls /var/www/roundcubemail/config

    le faltan el archivo `config.inc.php` inicielo con
    la plantilla así:

            cp /var/www/roundcubemail/config/config.inc.php.dist \
                /var/www/roundcubemail/config/config.inc.php

    Edítelo para que se adapten a su caso. Por ejemplo en
    las líneas:


            $config['db_dsnw'] = 'pgsql://roundcube:nueva_clave@unix(/var/run/postgresql)/roundcubemail';

            $config['default_host'] = 'ssl://correo.&EDOMINIO;';
            
            $config['default_port'] = 993;

            $config['imap_conn_options'] = array(
              'ssl' => array(
                'verify_peer'       => false,
                'allow_self_signed' => true,
                'cafile'  => '/etc/ssl/cert.pem',
                'ciphers' => 'TLSv1+HIGH:!aNull:@STRENGTH',
                'peer_name'         => 'correo.&EDOMINIO;',
              ),
            );

            $config['smtp_server'] = 'ssl://correo.&EDOMINIO';
            $config['smtp_port'] = 465;
            $config['smtp_user'] = '%u';
            $config['smtp_pass'] = '%p';


5.  De permiso para completar instalación y pruebas desde el web,
    editando el archivo `config/config.inc.php` y cambiando la línea:

            $config['enable_installer'] = true;


6.  Con un navegador examine el URL `https://correo.&EDOMINIO;/installer/`
    compruebe las dependencias solicitadas y realice las pruebas
    disponibles. Una vez concluya evite el uso de ese directorio
    cambiando en `config/main.inc.php` la línea:

            $rcmail_config['enable_installer'] = false;

Roundcubemail incluye plugins para diversas labores, por ejemplo si
desea añadir la posibilidad de cambiar la clave a los usuarios desde
este programa debe activar el plugin `password`, para esto:

1.  En el archivo `config/main.inc.php` agregue password en el arreglo
    `plugins`, si sólo tiene este plugin quedará:

            $config['plugins'] = array('password');

Si además desea permitir que los usuarios puedan cambiar su clave desde
este webmail active el plugin password como se presenta a continuación:

1.  Edite el archivo `config/config.inc.php` y añada `password` al arreglo
    `config['plugins']`, por ejemplo si no hay otros plugins
    cambiando

            $config['plugins'] = array();

    por

            $config['plugins'] = array('password');

2.  Si no existe el archivo `plugins/password/config.inc.php` inicie uno
    con:

            cp plugins/password/config.inc.php.dist plugins/password/config.inc.php

3.  Modifique el archivo `plugins/password/config.inc.php` de acuerdo a
    su configuración, por lo menos los siguientes 3 valores deben
    cambiarse:

            $rcmail_config['password_driver'] = 'poppassd';
            $rcmail_config['password_pop_host'] = '127.0.0.1';
            $rcmail_config['password_pop_port'] = 106;

4.  Instale el paquete `openpoppassd` y configúrelo para que inicie durante el
    arranque con `doas rcctl enable openpoppassd`

    Una vez lo haya iniciado puede probarlo con:

            telnet localhost 106

    que debe responder con:

            Trying 127.0.0.1...
            Connected to localhost.
            Escape character is '^]'.
            200 openpoppassd v1.1 hello, who are you?


[^smtp.1]: De acuerdo al RFC 1123 los nombre MUA y MTA son propios del
    protocolo X.400.

[^smtp.2]: De acuerdo al protocolo SMTP, el MTA de &ENOMCLIENTE; se
    conectaría por el puerto 25 al MTA en &ENOMCLIENTE2; y enviaría
    los mensajes `EHLO`, `MAIL FROM:<&EUSUARIO;@&ECLIENTE;>`, después enviaría
    `RCPT TO: &EUSUARIO2;@&ECLIENTE2;`, después `DATA` y a continuación el
    cuerpo del correo comenzando con el encabezado de acuerdo al RFC
    822, con un cuerpo de mensaje que emplee 7 bits y terminando con una
    línea que sólo tenga un punto. Por ejemplo

            From: &EUSUARIO;@&ECLIENTE;
            To: &EUSUARIO2;@&ECLIENTE2;
            Subject: Saludo

            Un cortísimo saludo para bendición de nuestro Creador.
            .  

[^smtp.3]: Son inseguros porque transmiten claves y el contenido de los
    mensajes planos por la red

[^smtp.4]: Hemos notado que no funciona `RCPT TO` en mayúscula sino sólo
    `rcpto to` en minúscula.  Al usar mayúscula se genera un error
    del estilo 
    
        RENEGOTIATING
        9898059462808:error:1404C042:SSL routines:ST_OK:called a function you should not call:/usr/src/lib/libssl/ssl_lib.c:2435:`


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
Las peticiones pudieron pasar antes por el cortafuegos si lo hay o por otro 
servidor que actue como proxy.

El siguiente diagrama presenta más detalles de los elementos involucrados
en servir páginas web generadas por una aplicación Ruby on Rails.

![](img/diagrama-web.png)


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
los paquetes que se instalan por omisión.
Su binario queda ubicado en `/usr/local/sbin/nginx` y puede consultar la 
versión ejecutando `nginx -v`

Cuando corre en OpenBSD lee el archivo de configuración `/etc/nginx/nginx.conf`
y después cambia el directorio raíz  con `chroot` a  `/var/www` para correr en 
esa jaula. Esta es una medida de seguridad para evitar que un atacante que 
desde el web logre acceso al sistema de archivos pueda ver o escribir en 
archivos de configuración (como los de `/etc`) o binarios o el kernel mismo, 
un atacante vería como raíz lo que este en `/var/www`.

Puede iniciarlo manualmente con:

        doas rcctl start nginx

y detenerlo con

        doas rcctl stop nginx

Para que inicie automáticamente en cada arranque basta agregar en
`/etc/rc.conf.local`:

       nginx_flags=""

y que añada `nginx` en `pkg_scripts`.


#### Generalidades del archivo de configuración de nginx

El archivo de configuración consta de directivas que le indican a nginx 
como responder a solicitudes http.

Algunas de las directivas del archivo de configuración tienen bloques que a su 
vez tienen directivas. Cada bloque se inicia con `{` y se cierra con `}`.  
Las directivas que no tienen bloque deben terminar con `;`

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
	    listen [::]:80:
	    root htdocs;
	  }
	}

Dentro del bloque de la directiva `http` debe ponerse una directiva 
`server` por cada sitio web que sea servido por nginx. 

La directiva `server` tiene un bloque dentro del cual deben ponerse,
entre otras, las directivas `server_name` (con nombre de servidor) y 
`listen` (con puerto) acordes a los URLs que se esperan sean usados 
por los usuarios y otras directivas de acuerdo al contenido que se
desea servir. En este ejemplo el servidor escucha en el puerto 80 por IPv4 
y en el puerto 80 por IPv6.

En este ejemplo la directiva `root` indica que se servirán
contenido alojado en el sistema de archivos en la ruta `/var/www/htdocs`
(como nginx correo en la jaula `/var/www` basta indicar la ruta
dentro de esa).  La directiva `index index.html` indica que si
el usuario no especifica una ruta particular en el URL se servirá
el archivo `/var/www/htdocs/index.html` que si desea probar puede 
iniciar con el contenido:

	<h1>Bienvenido a servir contenido web con nginx</h1>


#### Configuración de `server_name` y `listen` de acuerdo a URLs que se esperan del usuario

Los URLs que usen que incluyen el protocolo (`http` sin cifrar o
`https` con cifrado) el nombre del servidor (o dirección IPv4 o IPv6 si 
no tiene dominos DNS configurados) y el puerto (si el usuario no emplea un 
puerto y el URL comienza con `http` se usa el puerto 80, o si comienza con 
`https` se emplea por omisión el puerto 443).

Otro caso sencillo de configurar es servir contenido estático HTML, CSS
y Javascript a usuarios ubicados en computadores en una red local en
la que el servidor tiene una IP estática asignada (digamos
192.168.20.20) o si ha contratado una IP pública con su proveedor de 
Internet digamos 125.125.123.1 como en el siguiente ejemplo que supone
que sólo configura IPv4:

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

En caso de usar IPv6 tras configurar nginx, para abrir la página desde un
navegador deberá seguir el estándar de encerrar la dirección IPv6 entre 
paréntesis cuadrados.

Si prefiere usar un nombre en lugar de una IP (digamos &EDOMINIO;) 
deberá tramitar el registro del dominio ante un registrador y pagar la 
anualidad.  En tal caso la sección `server` para el puerto 80 por IPv4
y 80 por IPv6 sería 
(cambiando `www` por el registro que hay configurado en su dominio y 
`minombre.org` por el dominio que haya contratado): 

	  server {
	    server_name www.minombre.org;
	    listen 80:
	    listen [::]:80:
	    root htdocs;
	  }



##### Pruebas cambiando resolución local en un computador

Si en su red local el servidor nginx corre en la dirección 192.168.10.2, 
en otro computador con adJ (digamos con IP 192.168.10.15) podría configurar 
la resolución local para asociar www.midominio.org a la IP 192.168.10.2.

Eso lo puede hacer en el archivo `/etc/hosts` con una línea de la forma

	192.168.10.2 www.midominio.org

Siempre y cuando en  `/etc/resolv.conf` tenga `lookup file`

Si en su red emplea IPv6 con direcciones estáticas lo que tendría que agregar
a `/etc/hosts` sería una línea de la forma:

	fd4d:da20:9e56:8:10 www.midominio.org

##### Pruebas en una red cambiando resolución local para la red

Para cambiar la resolución de nombres en una red local podría emplear un 
servidor de nombres completo como `nsd`, pero basta con un resolvedor 
como `unbound`.

Por ejemplo si `unbound` corre en el servidor 192.168.10.1 para su 
dominio `midominio.org`, puede configurarlo para que dirija a 192.168.10.2 
cuando desde la red local alguien solicite `www.mindominio.org`, modificando
el archivo `/var/unbound/etc/unbound.conf` para que incluya:

	interface: 127.0.0.1
	interface: 192.168.10.2

	access-control: 192.168.10.0/24 allow

	local-zone: "midominio.org" static
	local-data: "midominio.org IN A 192.168.10.2"
	local-data: "www.midominio.org IN A 192.168.10.2"

Si además (o en cambio) el servidor tiene una dirección IPv6 debe agregar otro
`local-data`:

	local-data: "midominio.org IN A fd4d:da20:9e54::10:10"

Cada vez que haga modificaciones al archivo de configuración de unbound 
debe reiniciarlo por ejemplo con:

	doas rcctl -d restart unbound

Y en cada computador de la red local debe configurar que el servidor DNS 
sea 192.168.10.1.


##### Pruebas cambiando configuración de servidor DNS

Si está pagando a su proveedor de Internet una IP pública (digamos 
125.125.121.1) y si pagó el registro de un dominio (digamos www.midominio.org) 
ante un registrador de dominios, debe editar la configuración del servidor DNS
que haya configurado con el registrador (muchos registradores ofrecen
servidores DNS editables desde el web). 

Debe agregar un registro que indique que las peticiones a su dominio
y al subdominio `www.midominio.org` se dirigen a la IP pública de 
su servidor.  Tanto con `bind` como con `nsd` que son 2 servidores DNS
populares se harían con líneas de la forma:

	midominio.org.	A	125.125.121.1;
	www.midominio.org.	A	125.125.121.1;

Si además cuenta con una IPv6 pública también deberá agregarla con registros
AAAA, por ejemplo:

	www.midominio.org.	AAAA	2600:33:33::10:10


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



