CC =	cc
LIBS = 	 -lssh2 
SUN_LIBS = -lsocket -lnsl -lssh2

all:
	${CC} ${CFLAGS} -Wall ${LIBS} -I/usr/local/include -L/usr/local/lib -o fashion fashion.c

solaris:
	${CC} ${CFLAGS} -Wall ${SUN_LIBS} -I/usr/local/include -L/usr/local/lib -o fashion fashion.c
