#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <syslog.h>

int main(int argc, char *argv[]) {

    printf("Using Writer.c");
    openlog(NULL, 0, LOG_USER);

    if (argc != 3) {
        syslog(LOG_ERR, "Invalid number of arguments: %d", argc - 1);
        fprintf(stderr, "Usage: %s <writefile> <writestr>\n", argv[0]);
        closelog();
        return 1;
    }

    const char *writefile = argv[1];
    const char *writestr = argv[2];

    FILE *f = fopen(writefile, "w");
    if (!f) {
        syslog(LOG_ERR, "Failed to open file: %s", writefile);
        perror("Error opening file");
        closelog();
        return 1;
    }

    fprintf(f, "%s", writestr);
    fclose(f);

    syslog(LOG_DEBUG, "Writing %s to %s", writestr, writefile);
    closelog();

    return 0;
}
