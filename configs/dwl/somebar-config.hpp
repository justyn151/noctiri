// Noctiri Somebar configuration.
#pragma once
#include "common.hpp"

constexpr bool topbar = true;
constexpr int paddingX = 9;
constexpr int paddingY = 3;
constexpr const char* font = "Liberation Mono 11";

constexpr ColorScheme colorInactive = {
    Color(0xc8, 0xc0, 0xc0), Color(0x30, 0x2c, 0x32)
};
constexpr ColorScheme colorActive = {
    Color(0x30, 0x2c, 0x32), Color(0xc8, 0xbf, 0xc0)
};
constexpr const char* termcmd[] = {"foot", nullptr};

static std::vector<std::string> tagNames = {
    "1", "2", "3", "4", "5", "6", "7", "8", "9",
};

constexpr Button buttons[] = {
    { ClkStatusText, BTN_RIGHT, spawn, {.v = termcmd} },
};
