#!/bin/sh

for i in *xdbk; do 
	echo $i; 
	n=`echo $i | sed -e 's/.xdbk/.md/g'`; 
	~/.cabal/bin/pandoc -f docbook -t markdown -o syslog.md syslog.xdbk; 
	echo $n; 
done
