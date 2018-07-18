# Reglas para generar HTML, PostScript y PDF de servidor_adJ
# Basadas en infraestructura de dominio público de repasa 
#   (http://structio.sourceforge.net/repasa)

include Make.inc

# Variables requeridas por comdocbook.mak

EXT_DOCBOOK=xdbk

FUENTESDB=redes.xdbk interconexion.xdbk direcciones.xdbk protocolossop.xdbk otrosservicios.xdbk novedades.xdbk biblio.xdbk 

SOURCES=$(PROYECTO).xdbk $(FUENTESDB)
# Listado de fuentes XML. Preferiblmente en el orden de inclusión.

IMAGES= img/home.png img/prev.png img/toc-minus.png img/blank.png img/important.png img/toc-plus.png img/caution.png img/next.png img/tip.png img/up.png img/draft.png img/note.png img/toc-blank.png img/warning.png
# Listado de imagenes, preferiblemente en formato PNG

HTML_DIR=html
# Directorio en el que se generará información en HTML (con reglas por defecto)

HTML_TARGET=$(HTML_DIR)/index.html
# Nombre del HTML principal (debe coincidir con el especificado en estilohtml.xsl)

XSLT_HTML=estilohtml.xsl
# Hoja XSLT para generar HTML con regla por defecto

PRINT_DIR=imp
# Directorio en el que se genera PostScript y PDF en reglas por defecto

DSSSL_PRINT=estilo.dsl\#print
# Hoja de estilo DSSSL para generar TeX en reglas por defecto

DSSSL_HTML=estilo.dsl\#html
# Hoja de estilo DSSSL para generar HTML en reglas por defecto

OTHER_HTML=

PRECVS=guias/

INDEX=indice.$(EXT_DOCBOOK)
# Si habrá un índice, nombre del archivo con el que debe generarse (incluirlo al final del documento).


# Variables requeridas por comdist.mk

GENDIST=Derechos.txt $(SOURCES) $(IMAGES)
# Dependencias por cumplir antes de generar distribución

ACTHOST=git@github.com:pasosdeJesus/
# Sitio en Internet donde actualizar. Método indicado por ACT_PROC de confv.sh

ACTDIR=servidor_adJ
# Directorio en ACTHOST por actualizar


GENACT=ghtodo $(PROYECTO)-$(PRY_VERSION)_html.tar.gz $(PRINT_DIR)/$(PROYECTO)-$(PRY_VERSION).ps.gz $(PRINT_DIR)/$(PROYECTO)-$(PRY_VERSION).pdf 
# Dependencias por cumplir antes de actualizar sitio en Internet al publicar

FILESACT=$(PROYECTO)-$(PRY_VERSION).tar.gz $(PROYECTO)-$(PRY_VERSION)_html.tar.gz $(HTML_DIR)/* #$(PRINT_DIR)/$(PROYECTO)-$(PRY_VERSION).ps.gz $(PRINT_DIR)/$(PROYECTO)-$(PRY_VERSION).pdf 
# Archivos que se debe actualizar en sitio de Internet cuando se publica

all: $(HTML_TARGET) #$(PRINT_DIR)/$(PROYECTO).ps $(PRINT_DIR)/$(PROYECTO).pdf

cvstodo: distcvs 
	rm -rf $(PROYECTO)-$(PRY_VERSION)
	tar xvfz $(PROYECTO)-$(PRY_VERSION).tar.gz
	(cd $(PROYECTO)-$(PRY_VERSION); ./conf.sh; make $(PROYECTO)-$(PRY_VERSION)_html.tar.gz)
	cp $(PROYECTO)-$(PRY_VERSION)/$(PROYECTO)-$(PRY_VERSION)_html.tar.gz .

ghtodo: distgh
	(cd $(PROYECTO)-$(PRY_VERSION); ./conf.sh; make $(PROYECTO)-$(PRY_VERSION)_html.tar.gz)
	cp $(PROYECTO)-$(PRY_VERSION)/$(PROYECTO)-$(PRY_VERSION)_html.tar.gz .


repasa:
	DEF=$(PROYECTO).def CLA=$(PROYECTO).cla SEC=$(PROYECTO).sec DESC="Información extraida de $(PROYECTO) $(PRY_VERSION)" FECHA="$(FECHA_ACT)" BIBLIO="$(URLSITE)" TIPO_DERECHOS="Dominio Público" TIEMPO_DERECHOS="$(MES_ACT)" DERECHOS="Información cedida al dominio público de acuerdo a la legislación colombiana. Sin garantías" AUTORES="Vladimir Támara Patiño" IDSIGNIFICADO="adJ_servidor" $(AWK) -f herram_confsh/db2rep $(SOURCES)

# Para usar DocBook
include herram_confsh/comdocbook.mak

# Para crear distribución de fuentes y publicar en Internet
include herram_confsh/comdist.mak

# Elimina hasta configuración
limpiadist: limpiamas
	rm -f confv.sh confv.ent Make.inc personaliza.ent
	rm -rf $(HTML_DIR)/*
	rm -rf $(PRINT_DIR)

# Elimina archivos generables
limpiamas: limpia
	rm -f img/*.eps img/*.ps
	rm -f $(PROYECTO)-$(PRY_VERSION).tar.gz
	rm -rf $(PROYECTO)-$(PRY_VERSION)
	rm -rf $(PROYECTO)_gh-pages
	rm -f $(INDEX).xdbk $(INDEX).xdbk.m $(INDEX).xml.m HTML.index.m
	rm -f confaux.sed indice.xdbk.m

# Elimina backups y archivos temporales
limpia:
	rm -f *bak *~ *.tmp confaux.tmp $(PROYECTO)-$(PRY_VERSION)_html.tar.gz
	rm -f $(PROYECTO)-4.1.*
	rm -f $(FUENTESDB)

infoversion.ent:
	echo '<?xml version="1.0" encoding="ISO-8859-1"?>' > infoversion.ent
	export v=`uname -r` && echo "<!ENTITY VER-ADJ \"$$v\">" >> infoversion.ent && echo "<!ENTITY VER-OPENBSD \"$$v\">" >> infoversion.ent && export v2=`echo $$v | sed -e "s/\.//g"` && echo "<!ENTITY VER-OPENBSD-S \"$${v2}\">" >> infoversion.ent && export v3=`echo $$v | sed -e s"/\./_/g"`  && echo "<!ENTITY VER-OPENBSD-U \"$${v3}\">" >> infoversion.ent
	Xorg -version 2> /tmp/Xver && v=`grep "Version [0-9]*\." /tmp/Xver | sed -e "s/.*Version //g"` && echo "<!ENTITY VER-XORG \"$${v}\">" >> infoversion.ent
	echo '<!ENTITY p-mailman "mailman">' >> infoversion.ent
	echo '<!ENTITY p-jdk-linux "jdk-linux">' >> infoversion.ent
	n=`pkg_info | sed -e "s/^\([^ ]*\) .*/ \1 /g"`; \
	for i in $$n; do \
	  q=`echo $$i | sed -e "s/^\(.*\)-[0-9].*/\1/g" | tr "+" "p"`; \
	  p=`echo $$i | sed -e "s/^\(.*\)-[0-9].*/p-\1/g" | tr "+" "p"`; \
	  v=`echo $$i | sed -e "s/^.*-\([0-9].*\)/\1/g"`; \
	  echo "<!ENTITY $$p \"$$q-$$v\">" >> infoversion.ent; \
	done;


Derechos.txt: $(PROYECTO).$(EXT_DOCBOOK)
	make html/index.html
	$(W3M) $(W3M_OPT) -dump html/index.html | awk -f herram_confsh/conthtmldoc.awk > Derechos.txt

instala:
	mkdir -p $(DESTDIR)$(INSDOC)/img/
	install html/*html $(DESTDIR)$(INSDOC)
	install img/*png $(DESTDIR)$(INSDOC)/img/
	if (test -f $(PRINT_DIR)/$(PROYECTO).ps) then { \
		install imp/*ps $(DESTDIR)$(INSDOC);\
	} fi;

