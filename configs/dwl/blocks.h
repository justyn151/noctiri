static const Block blocks[] = {
    /* icon  command                         interval  signal */
    { "", "noctiri-dwl-status memory",        5,       0 },
    { "", "noctiri-dwl-status audio",         2,       0 },
    { "", "noctiri-dwl-status network",      10,       0 },
    { "", "noctiri-dwl-status battery",      30,       0 },
    { "", "noctiri-dwl-status clock",         5,       0 },
};

static char delim[] = "  ";
static unsigned int delimLen = 2;
