
#include <signal.h>



// Client/Daemon
#define SOCK_PATH "/var/tmp/wifriedx.sock"

enum {
    kWiFriedXMagic = 'wifr'
};


struct WiFriedXRequest {
    OSType          magic;                          // must be kWiFriedXMagic
    bool             up;
};


