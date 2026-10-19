/* Noctiri DWL preview, based on BreadOnPenguins/dwl. */

#define COLOR(hex) { ((hex >> 24) & 0xFF) / 255.0f, \
                     ((hex >> 16) & 0xFF) / 255.0f, \
                     ((hex >> 8) & 0xFF) / 255.0f, \
                     (hex & 0xFF) / 255.0f }

static const int sloppyfocus = 1;
static const int bypass_surface_visibility = 0;
static const int smartgaps = 0;
static const int monoclegaps = 0;
static const unsigned int borderpx = 0;
static const unsigned int gappih = 7;
static const unsigned int gappiv = 7;
static const unsigned int gappoh = 25;
static const unsigned int gappov = 35;
static const float rootcolor[] = COLOR(0x302c32ff);
static const float bordercolor[] = COLOR(0x5d565eff);
static const float focuscolor[] = COLOR(0xc8bfc0ff);
static const float urgentcolor[] = COLOR(0xc45b65ff);
static const float fullscreen_bg[] = COLOR(0x000000ff);
static const int respect_monitor_reserved_area = 0;
static const float default_opacity_unfocus = 0.94f;
static const float default_opacity_focus = 1.0f;

#define TAGCOUNT (9)
static int log_level = WLR_ERROR;

static const Rule rules[] = {
    /* app_id  title  tags  floating  unfocused opacity  monitor  x  y  w  h */
    { NULL, NULL, 0, 0, default_opacity_unfocus, -1, -1, -1, -1, -1 },
};

static const Layout layouts[] = {
    { "[]=" , tile },
    { "><>" , NULL },
    { "[M]" , monocle },
};

static const MonitorRule monrules[] = {
    /* A connector-independent fallback lets wlroots choose the preferred mode,
     * including 144 Hz panels, instead of hard-coding one laptop's output. */
    { NULL, 0.55f, 1, 1, &layouts[0], WL_OUTPUT_TRANSFORM_NORMAL, -1, -1 },
};

static const struct xkb_rule_names xkb_rules = {
    .options = "ctrl:nocaps",
};

static const int repeat_rate = 50;
static const int repeat_delay = 250;
static const int tap_to_click = 1;
static const int tap_and_drag = 1;
static const int drag_lock = 0;
static const int natural_scrolling = 0;
static const int disable_while_typing = 1;
static const int left_handed = 0;
static const int middle_button_emulation = 0;
static const enum libinput_config_scroll_method scroll_method = LIBINPUT_CONFIG_SCROLL_2FG;
static const enum libinput_config_click_method click_method = LIBINPUT_CONFIG_CLICK_METHOD_BUTTON_AREAS;
static const uint32_t send_events_mode = LIBINPUT_CONFIG_SEND_EVENTS_ENABLED;
static const enum libinput_config_accel_profile accel_profile = LIBINPUT_CONFIG_ACCEL_PROFILE_ADAPTIVE;
static const double accel_speed = 0.0;
static const enum libinput_config_tap_button_map button_map = LIBINPUT_CONFIG_TAP_MAP_LRM;

#define MODKEY WLR_MODIFIER_LOGO
#define TAGKEYS(KEY,SKEY,TAG) \
    { MODKEY, KEY, view, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_CTRL, KEY, toggleview, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_SHIFT, SKEY, tag, {.ui = 1 << TAG} }, \
    { MODKEY|WLR_MODIFIER_CTRL|WLR_MODIFIER_SHIFT, SKEY, toggletag, {.ui = 1 << TAG} }
#define SHCMD(cmd) { .v = (const char*[]){ "/bin/sh", "-c", cmd, NULL } }

static const char *term[] = { "foot", NULL };
static const char *launcher[] = { "wmenu-run", "-p", "Run:", NULL };
static const char *browser[] = { "firefox", NULL };
static const char *files[] = { "foot", "-e", "yazi", NULL };

static const Key keys[] = {
    { MODKEY, XKB_KEY_Return, spawn, {.v = term} },
    { MODKEY, XKB_KEY_d, spawn, {.v = launcher} },
    { MODKEY, XKB_KEY_b, spawn, {.v = browser} },
    { MODKEY, XKB_KEY_e, spawn, {.v = files} },

    { MODKEY, XKB_KEY_j, focusstack, {.i = +1} },
    { MODKEY, XKB_KEY_k, focusstack, {.i = -1} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_J, rotate_clients, {.i = +1} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_K, rotate_clients, {.i = -1} },
    { MODKEY, XKB_KEY_h, setmfact, {.f = -0.05f} },
    { MODKEY, XKB_KEY_l, setmfact, {.f = +0.05f} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Return, zoom, {0} },
    { MODKEY, XKB_KEY_Tab, view, {0} },
    { MODKEY, XKB_KEY_q, killclient, {0} },
    { MODKEY, XKB_KEY_t, setlayout, {.v = &layouts[0]} },
    { MODKEY, XKB_KEY_m, setlayout, {.v = &layouts[2]} },
    { MODKEY, XKB_KEY_space, setlayout, {0} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_space, togglefloating, {0} },
    { MODKEY, XKB_KEY_f, togglefullscreen, {0} },
    { MODKEY, XKB_KEY_g, togglegaps, {0} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_G, defaultgaps, {0} },
    { MODKEY, XKB_KEY_0, view, {.ui = ~0} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_parenright, tag, {.ui = ~0} },

    { MODKEY, XKB_KEY_comma, focusmon, {.i = WLR_DIRECTION_LEFT} },
    { MODKEY, XKB_KEY_period, focusmon, {.i = WLR_DIRECTION_RIGHT} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_less, tagmon, {.i = WLR_DIRECTION_LEFT} },
    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_greater, tagmon, {.i = WLR_DIRECTION_RIGHT} },

    { 0, XKB_KEY_XF86AudioRaiseVolume, spawn, SHCMD("wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+") },
    { 0, XKB_KEY_XF86AudioLowerVolume, spawn, SHCMD("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-") },
    { 0, XKB_KEY_XF86AudioMute, spawn, SHCMD("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle") },
    { 0, XKB_KEY_XF86MonBrightnessUp, spawn, SHCMD("brightnessctl set 5%+") },
    { 0, XKB_KEY_XF86MonBrightnessDown, spawn, SHCMD("brightnessctl set 5%-") },

    TAGKEYS(XKB_KEY_1, XKB_KEY_exclam, 0),
    TAGKEYS(XKB_KEY_2, XKB_KEY_at, 1),
    TAGKEYS(XKB_KEY_3, XKB_KEY_numbersign, 2),
    TAGKEYS(XKB_KEY_4, XKB_KEY_dollar, 3),
    TAGKEYS(XKB_KEY_5, XKB_KEY_percent, 4),
    TAGKEYS(XKB_KEY_6, XKB_KEY_asciicircum, 5),
    TAGKEYS(XKB_KEY_7, XKB_KEY_ampersand, 6),
    TAGKEYS(XKB_KEY_8, XKB_KEY_asterisk, 7),
    TAGKEYS(XKB_KEY_9, XKB_KEY_parenleft, 8),

    { MODKEY|WLR_MODIFIER_SHIFT, XKB_KEY_Q, quit, {0} },
    { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_Terminate_Server, quit, {0} },
#define CHVT(n) { WLR_MODIFIER_CTRL|WLR_MODIFIER_ALT, XKB_KEY_XF86Switch_VT_##n, chvt, {.ui = (n)} }
    CHVT(1), CHVT(2), CHVT(3), CHVT(4), CHVT(5), CHVT(6),
    CHVT(7), CHVT(8), CHVT(9), CHVT(10), CHVT(11), CHVT(12),
};

static const Button buttons[] = {
    { MODKEY, BTN_LEFT, moveresize, {.ui = CurMove} },
    { MODKEY, BTN_MIDDLE, togglefloating, {0} },
    { MODKEY, BTN_RIGHT, moveresize, {.ui = CurResize} },
};
