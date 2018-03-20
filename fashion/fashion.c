/*
 * fashion - Simple wrapper to run commands over SSH without typing passwords every time
 *
 * usage:
 * 	fashion host user password "command"
 * 	fashion -f config.txt host
 */

 /* Based on LIBSSH2 library and libssh2 example code */

/*
 * ----------------------------------------------------------------------------
 * "THE BEER-WARE LICENSE" (Revision 42):
 * <zmey20000@yahoo.com> wrote this file. As long as you retain this notice you
 * can do whatever you want with this stuff. If we meet some day, and you think
 * this stuff is worth it, you can buy me a beer in return.    Mikhail Zakharov
 * ----------------------------------------------------------------------------
*/

#include <libssh2.h>
#include <libssh2_sftp.h>

#include <unistd.h>
#include <arpa/inet.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <netdb.h>
#include <sys/types.h>
#include <fcntl.h>
#include <errno.h>
#include <stdio.h>
#include <ctype.h>
#include <strings.h>
#include <string.h>
#include <stdlib.h>
#include <limits.h>

const char *version = "0.0.3";

const char *keyfile1 = "~/.ssh/id_rsa.pub";
const char *keyfile2 = "~/.ssh/id_rsa";
char *host = NULL;
char *username = NULL;
char *password = NULL;
char *commandline = NULL;
char l_cfg[LINE_MAX], *l_cfgp;

int read_cfgfile(char *cfgfile, char *hst);
static void usage(void);

/* ------------------------------------------------------------------------- */
static int waitsocket(int socket_fd, LIBSSH2_SESSION *session) {
	struct timeval timeout;
	int rc;
	fd_set fd;
	fd_set *writefd = NULL;
	fd_set *readfd = NULL;
	int dir;


	timeout.tv_sec = 10;
	timeout.tv_usec = 0;

	FD_ZERO(&fd);
	FD_SET(socket_fd, &fd);

	/* now make sure we wait in the correct direction */
	dir = libssh2_session_block_directions(session);

	if (dir & LIBSSH2_SESSION_BLOCK_INBOUND)
		readfd = &fd;

	if (dir & LIBSSH2_SESSION_BLOCK_OUTBOUND)
		writefd = &fd;

	rc = select(socket_fd + 1, readfd, writefd, NULL, &timeout);
	return rc;
}

/* ------------------------------------------------------------------------- */
static void kbd_callback(const char *name, int name_len,
				const char *instruction, int instruction_len,
				int num_prompts,
				const LIBSSH2_USERAUTH_KBDINT_PROMPT *prompts,
				LIBSSH2_USERAUTH_KBDINT_RESPONSE *responses,
				void **abstract)
{
	(void)name;
	(void)name_len;
	(void)instruction;
	(void)instruction_len;
	if (num_prompts == 1) {
		responses[0].text = strdup(password);
		responses[0].length = strlen(password);
    	}
	(void)prompts;
	(void)abstract;
}

/* ------------------------------------------------------------------------- */
int main(int argc, char *argv[]) {
	char *host;
	int rc, sock, i, auth_pw = 0;
	struct sockaddr_in sin;
	struct hostent *he;
	const char *fingerprint;
	char *userauthlist;
	LIBSSH2_SESSION *session;
	LIBSSH2_CHANNEL *channel;

	int exitcode;
	int bytecount = 0;


	if (argc == 5) {
		/* usage: fashion host user password "command line" */
		host = argv[1];
		username = argv[2];
		password = argv[3];
		commandline = argv[4];
	} else
		/* usage: fashion -f config.file host */
		if (argc == 4 && !strncasecmp(argv[1], "-f", 2)) {
			read_cfgfile(argv[2], argv[3]);
			host = argv[3];
		} else
			/* wrong fashion usage */
			(void)usage();
	
	/* Init LIBSSH2 */
	if ((rc = libssh2_init(0))) {
		fprintf (stderr, "libssh2 initialization failed (%d)\n", rc);
		return 1;
	}

	/* Get hostname */
	if ((he = gethostbyname(host)) == NULL) {
		fprintf(stderr, "Host %s not found\n", host);
		return 1;
	}
  
	/* Connect with the host */
	sock = socket(AF_INET, SOCK_STREAM, 0);
	bcopy(he->h_addr_list[0], &sin.sin_addr, he->h_length);
	sin.sin_family = AF_INET;
	sin.sin_port = htons(22);
	if (connect(sock, (struct sockaddr*)(&sin), sizeof(struct sockaddr_in)) != 0) {
		fprintf(stderr, "failed to connect with %s!\n", host);
		return 1;
	}

	/* Create a session instance and start it up. This will trade welcome
	* banners, exchange keys, and setup crypto, compression, and MAC layers */
	session = libssh2_session_init();
	if (libssh2_session_startup(session, sock)) {
		fprintf(stderr, "Failure establishing SSH session\n");
		return 1;
	}

	/* At this point we havn't authenticated. The first thing to do is check
	* the hostkey's fingerprint against our known hosts Your app may have it
	* hard coded, may go to a file, may present it to the user, that's your
	* call */
	fingerprint = libssh2_hostkey_hash(session, LIBSSH2_HOSTKEY_HASH_SHA1);
	fprintf(stderr, "Fingerprint: ");
	for(i = 0; i < 20; i++)
		fprintf(stderr, "%02X ", (unsigned char)fingerprint[i]);
	fprintf(stderr, "\n");

	/* check what authentication methods are available */
	userauthlist = libssh2_userauth_list(session, username, strlen(username));
	fprintf(stderr, "Authentication methods: %s\n", userauthlist);
	if (strstr(userauthlist, "password")) auth_pw |= 1;
	if (strstr(userauthlist, "keyboard-interactive")) auth_pw |= 2;
	if (strstr(userauthlist, "publickey")) auth_pw |= 4;

	if (auth_pw & 1) {
		/* We could authenticate via password */
        	if (libssh2_userauth_password(session, username, password)) {
            		fprintf(stderr, "Authentication by password failed!\n");
		} else {
			fprintf(stderr,"Authentication by password succeeded.\n");
			goto getchannel;
		}
	} 
	
	if (auth_pw & 2) {
		/* Or via keyboard-interactive */
		if (libssh2_userauth_keyboard_interactive(session, username, &kbd_callback) ) {
			fprintf(stderr,"Authentication by keyboard-interactive failed!\n");
		} else {
			fprintf(stderr,"Authentication by keyboard-interactive succeeded.\n");
			goto getchannel;
		}
	} 
	
	if (auth_pw & 4) {
        	/* Or by public key */
		if (libssh2_userauth_publickey_fromfile(session, username, keyfile1, keyfile2, password)) {
			fprintf(stderr,"Authentication by public key failed!\n");
			goto shutdown;
		} else {
			fprintf(stderr,"Authentication by public key succeeded.\n");
			goto getchannel;
		}
	} else {
		fprintf(stderr,"No supported authentication methods found!\n");
		goto shutdown;
	}

getchannel:
	/* Request a shell */
	if (!(channel = libssh2_channel_open_session(session))) {
		fprintf(stderr, "Unable to open a session\n");
		goto shutdown;
	}

	while ((rc = libssh2_channel_exec(channel, commandline)) == LIBSSH2_ERROR_EAGAIN ) {
	        waitsocket(sock, session);
	}
    	
	if (rc != 0) {
		fprintf(stderr, "Error executing command: %s\n", commandline);
		goto shutdown;
	}

	for (;;) {
        	/* loop until we block */
        	int rc;
        	do {
			char buffer[0x4000];
			rc = libssh2_channel_read(channel, buffer, sizeof(buffer));
			if (rc >= 0) {
				int i;
				bytecount += rc;

				for(i = 0; i < rc; ++i)
					fputc(buffer[i], stdout);
			} else
				fprintf(stderr, "libssh2_channel_read returned %d\n", rc);
		} while (rc > 0);
		
        	/* this is due to blocking that would occur otherwise so we loop on
	 	    this condition */
        	if( rc == LIBSSH2_ERROR_EAGAIN )
			waitsocket(sock, session);
		else
			break;
	}

	while((rc = libssh2_channel_close(channel)) == LIBSSH2_ERROR_EAGAIN)
		waitsocket(sock, session);

	if (rc == 0) exitcode = libssh2_channel_get_exit_status(channel);
	
	libssh2_channel_free(channel);
	channel = NULL;

/* skip_shell: */
	if (channel) {
		libssh2_channel_free(channel);
		channel = NULL;
	}

shutdown:
	libssh2_session_disconnect(session, "Normal Shutdown");
	libssh2_session_free(session);

	close(sock);
	libssh2_exit();

	return 0;
}

int read_cfgfile(char *cfgfile, char *hst) { 
	FILE *f_cfg;
	char host_ptn[LINE_MAX]; 

	if ((f_cfg = fopen(cfgfile, "r")) == NULL) {
		fprintf(stderr, "Unable to open %s\n", cfgfile);
		exit(1);
	}

	/* prepare pattern "host:" to seek host-keys */
	strncpy(host_ptn, hst, strlen(hst)); 
	strncat(host_ptn, ":", 1);
	l_cfgp=l_cfg;

	while (fgets(l_cfg, LINE_MAX, f_cfg) != NULL) {
		/* Check if it's a comment */
		if (l_cfg[0] != ' ' && l_cfg[0] != '\t') {
			/* Check the host pattern by the host-key */
			if (strstr(l_cfg, host_ptn) == l_cfg) {
				/* and parse the rest tokens */
#if defined(__SVR4)
				/* SUNOS Solaris */
				host = strtok(l_cfgp, ":");
				username = strtok(NULL,  ":");
				password = strtok(NULL,  ":");
				commandline = strtok(NULL,  ":");
#else
				host = strsep(&l_cfgp, ":");
				username = strsep(&l_cfgp, ":");
				password = strsep(&l_cfgp, ":");
				commandline = strsep(&l_cfgp, "\n"); 
#endif
				fclose(f_cfg);
				return 0;
			}
		}	
	}

	/* key-host not found */
	fclose(f_cfg);
	exit(1);
}


/* ------------------------------------------------------------------------- */
static void usage(void) {
	fprintf(stderr, "Fashion version: %s\n\
Usage:\n\
\tfashion host user password \"command line\"\n\
\tfashion -f config.txt host\n", version);

	exit(1);
}
