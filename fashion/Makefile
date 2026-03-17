CC =	cc
LIBS = 	 -lssh2
SUN_LIBS = -lsocket -lnsl -lssh2
IDIR = -I/usr/local/include -I/opt/local/include -I/usr/include
LDIR = -L/usr/local/lib -L/opt/local/lib -L/usr/lib

.PHONY:	all solaris clean

all:
	${CC} ${CFLAGS} -Wall ${IDIR} -o fashion fashion.c ${LDIR} ${LIBS}

solaris:
	${CC} ${CFLAGS} -Wall ${SUN_LIBS} ${IDIR} -o fashion fashion.c ${LDIR} ${LIBS}

clean:
	rm -rf fashion