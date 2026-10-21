# shellcheck shell=bash disable=SC2034
# settings.sh: the settings registry, its readers and its writers.
# Sourced by replicant-core.sh, which sets the paths it uses. It defines
# functions and data and runs nothing. Other modules read its data.

# ─── SETTINGS — curated, individually-editable fields (not whole files) ─────
# Unlike MANIFEST (whole files, tracked for backup/sync), each entry here is one
# single field inside an already-tracked file, safe to read and write
# mechanically. The panel renders a control per type, so adding a setting is one
# line here and no QML change.
#
# Format: "id|group|file|path|type|label|unit|min|max|options|hint|apply|fallback|scale|display|step"
#
#   group    the section the panel files this control under
#   file     the file holding the value ("-" for types that don't read a file)
#   path     jq path (".idle.lock") for JSON | "section.key" for TOML |
#            the Hyprland option ("input:touchpad:natural_scroll") for lua-*,
#            whose full colon route is the Lua nesting and whose leaf is the
#            Lua key. Two routes may share a leaf (input:scroll_factor and
#            input:touchpad:scroll_factor); the reader tracks the full route,
#            never the leaf alone.
#   type     number | bool | enum            JSON, via jq
#            toml-int | toml-float           "key = <n>" inside a [section]
#            lua-int | lua-float | lua-bool | lua-enum
#                                            a "key = value" line in a Hyprland
#                                            Lua file, read by full route inside
#                                            hl.config blocks (see lua_get)
#            theme                           the active Omarchy theme
#            line-enum                       a file holding one bare word
#   min/max  numeric types only, in the STORED unit. Empty means no bound,
#            which is what the official Hyprland limits say for gaps.
#   options  enum types only, comma-separated
#   hint     one short line shown under the control (80 chars max, see tests)
#   apply    command run after a successful write. Empty means the value is
#            picked up live: the Omarchy shell watches both shell.json and
#            ~/.config/omarchy/shell.toml (FileView watchChanges), so those
#            need nothing. Hyprland does not, hence `hyprctl reload`.
#   fallback the value in force when the key is absent from the file, i.e. the
#            shell's own built-in default. Only for keys the writer can create
#            (the toml-* types): shell.toml ships nearly empty, so most
#            appearance keys are missing until you change one, and reporting
#            them as "unavailable" would leave a control the user can see but
#            never touch. Reported with implicit:true so the panel can say the
#            value is inherited rather than written down anywhere. It doubles as
#            the value "reset to the Omarchy default" writes when the file
#            Omarchy ships has nothing to read. For lua-* the Hyprland value in
#            force only supplies the current-value display. It is never a
#            default fallback.
#   scale    stored-unit -> shown-unit divisor. Omarchy stores idle timers in
#            seconds; nobody thinks in "600 seconds", so the panel edits them in
#            minutes (scale 60) and multiplies back before writing. Empty or 1
#            means the two units are the same. The CLI always speaks the STORED
#            unit — `set idle.lock 600` is still seconds — so scripts do not
#            have to know what the panel happens to display.
#   display  the unit shown next to the control once `scale` is applied
#            ("min"). Empty falls back to `unit`.
#   step     the numeric step the panel offers. Empty means the historic rule
#            (5 for long minute ranges, 50 for ms, 1 otherwise; 0.05 for
#            floats is decided in QML from display_step). Set it for every
#            lua-float so the slider moves in useful increments.
#
# A setting whose file or key is missing on this machine reads as null and the
# panel greys the control out. That is the intended behaviour, not an error:
# these files are the user's own and no two machines carry the same keys.
SETTINGS=(
  # ── Idle & power — ~/.config/omarchy/shell.json, watched live by the shell.
  # Stored in seconds by Omarchy, edited in minutes here.
  "idle.screensaver|Idle & power|$HOME/.config/omarchy/shell.json|.idle.screensaver|number|Screensaver|s|60|3600||Idle time before the screensaver starts|||60|min|"
  "idle.lock|Idle & power|$HOME/.config/omarchy/shell.json|.idle.lock|number|Lock screen|s|60|7200||Idle time before the screen locks|||60|min|"
  "idle.lazyDpms|Idle & power|$HOME/.config/omarchy/shell.json|.idle.lazyDpms|number|Turn off display|s|60|7200||Idle time before the display powers down|||60|min|"
  "idle.lazySuspendAc|Idle & power|$HOME/.config/omarchy/shell.json|.idle.lazySuspendAc|number|Suspend on AC|s|0|14400||Idle time before suspending on AC power (0 = never)|||60|min|"
  "idle.lazySuspendBatt|Idle & power|$HOME/.config/omarchy/shell.json|.idle.lazySuspendBatt|number|Suspend on battery|s|0|14400||Idle time before suspending on battery (0 = never)|||60|min|"
  # ── Appearance
  "theme.current|Appearance|-|-|theme|Theme|||||The theme applied to the shell, terminals and editor||tokyo-night|1||"
  "bar.position|Appearance|$HOME/.config/omarchy/shell.json|.bar.position|enum|Bar position||||top,bottom,left,right|Which screen edge the status bar sits on|||1||"
  "bar.transparent|Appearance|$HOME/.config/omarchy/shell.json|.bar.transparent|bool|Transparent bar|||||Let the wallpaper show through the bar|||1||"
  "font.baseSize|Appearance|$HOME/.config/omarchy/shell.toml|font.base-size|toml-int|Interface font size|pt|8|32||Base size every bar, menu and panel font derives from||12|1||"
  "spacing.scale|Appearance|$HOME/.config/omarchy/shell.toml|spacing.scale|toml-float|Interface density|×|0.5|2||Multiplies every margin, gap and control size||1.0|1||0.05"
  "bar.sizeHorizontal|Appearance|$HOME/.config/omarchy/shell.toml|bar.size-horizontal|toml-int|Bar thickness (top/bottom)|px|16|80||Bar height on a horizontal edge; setting it stops the font scaling it||26|1||"
  "bar.sizeVertical|Appearance|$HOME/.config/omarchy/shell.toml|bar.size-vertical|toml-int|Bar thickness (left/right)|px|16|120||Bar width on a vertical edge; setting it stops the font scaling it||28|1||"
  "bar.iconFont|Appearance|$HOME/.config/omarchy/shell.toml|bar.icon-font|toml-int|Bar icon size|px|8|28||How large the glyphs in the bar are drawn||13|1||"
  # The active monospace font, applied with `omarchy font set` and saved
  # through fontconfig/fonts.conf. The repo copy holds the same XML, so the
  # repo value is parsed out of it. No Omarchy default to revert to.
  "font.mono|Appearance|$HOME/.config/fontconfig/fonts.conf|-|font|Monospace font|||||System monospace font for terminals|||1||"
  # Which widget the center section centers on. A free string: any installed
  # widget id works, Omarchy ships omarchy.clock as the default.
  "bar.centerAnchor|Appearance|$HOME/.config/omarchy/shell.json|.bar.centerAnchor|string|Bar center anchor|||||Widget the center section centers on|||1||"
  # ── Keyboard — Hyprland reads Lua at startup, so these need an explicit reload.
  # Official Hyprland 0.56.2 limits: repeat_rate 0-200, repeat_delay 0-2000.
  "input.repeatRate|Keyboard|$HOME/.config/hypr/input.lua|input:repeat_rate|lua-int|Key repeat rate|/s|0|200||Characters a held key sends per second|hyprctl reload||1||"
  "input.repeatDelay|Keyboard|$HOME/.config/hypr/input.lua|input:repeat_delay|lua-int|Key repeat delay|ms|0|2000||How long a key is held before it starts repeating|hyprctl reload||1||"
  "input.kbLayout|Keyboard|$HOME/.config/hypr/input.lua|input:kb_layout|lua-enum|Keyboard layout||||@x11-layouts|X11 layout code for the keyboard|hyprctl reload||1||"
  "input.numlock|Keyboard|$HOME/.config/hypr/input.lua|input:numlock_by_default|lua-bool|Num lock at login|||||Turn the numeric keypad on when the session starts|hyprctl reload||1||"
  # XKB variant and options are free strings, not enums: a variant depends on
  # the layout (localectl lists hundreds) and options combine with commas
  # (compose:caps plus shift:both_capslock_cancel). Empty means none.
  "input.kbVariant|Keyboard|$HOME/.config/hypr/input.lua|input:kb_variant|lua-string|Keyboard variant|||||Variant for the layout, empty means none|hyprctl reload||1||"
  "input.kbOptions|Keyboard|$HOME/.config/hypr/input.lua|input:kb_options|lua-string|Keyboard options|||||Comma options, Caps is Compose by default|hyprctl reload||1||"
  # ── Mouse & pointer — global, portable between machines.
  # sensitivity -1.0-1.0, scroll_factor 0-100, accel_profile adaptive/flat
  # (custom needs manual config and is not offered).
  "input.sensitivity|Mouse & pointer|$HOME/.config/hypr/input.lua|input:sensitivity|lua-float|Pointer sensitivity||-1|1||Mouse speed; negative slows, positive speeds up|hyprctl reload|0|1||0.05"
  "input.accelProfile|Mouse & pointer|$HOME/.config/hypr/input.lua|input:accel_profile|lua-enum|Acceleration profile||||adaptive,flat|How the pointer accelerates; flat is constant|hyprctl reload|adaptive|1||"
  "input.naturalScrollMouse|Mouse & pointer|$HOME/.config/hypr/input.lua|input:natural_scroll|lua-bool|Natural scrolling (mouse)|||||Mouse: move content with the wheel, not the bar|hyprctl reload||1||"
  "input.scrollFactor|Mouse & pointer|$HOME/.config/hypr/input.lua|input:scroll_factor|lua-float|Wheel scroll speed||0|100||Multiplier for the mouse wheel movement|hyprctl reload|1.0|1||0.1"
  "input.leftHanded|Mouse & pointer|$HOME/.config/hypr/input.lua|input:left_handed|lua-bool|Left-handed mouse|||||Swap left and right mouse buttons|hyprctl reload||1||"
  # Pointer focus policy — official 0.56.2 limits: follow 0-3, focus_on_close
  # 0-2, float_switch 0-2. Verified with getoption on the live compositor.
  "input.followMouse|Mouse & pointer|$HOME/.config/hypr/input.lua|input:follow_mouse|lua-int|Focus follows mouse||0|3||How cursor movement affects focus|hyprctl reload|1|1||"
  "input.focusOnClose|Mouse & pointer|$HOME/.config/hypr/input.lua|input:focus_on_close|lua-int|Focus after close||0|2||Where focus goes when a window closes|hyprctl reload|0|1||"
  "input.floatSwitchFocus|Mouse & pointer|$HOME/.config/hypr/input.lua|input:float_switch_override_focus|lua-int|Focus on float switch||0|2||Follow focus when toggling floating|hyprctl reload|1|1||"
  # ── Touchpad — visible even with none connected, so the config restores elsewhere.
  # touchpad scroll_factor 0-100, the rest are bools.
  "input.naturalScroll|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:natural_scroll|lua-bool|Natural scrolling|||||Touchpad: two fingers down moves the page up|hyprctl reload||1||"
  "input.tapToClick|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:tap_to_click|lua-bool|Tap to click|||||Touchpad: a tap counts as a click|hyprctl reload||1||"
  "input.disableWhileTyping|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:disable_while_typing|lua-bool|Ignore touchpad while typing|||||Stops the cursor jumping mid-sentence|hyprctl reload||1||"
  "input.touchScrollFactor|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:scroll_factor|lua-float|Touchpad scroll speed||0|100||Multiplier for two-finger scrolling|hyprctl reload|1.0|1||0.05"
  "input.clickFinger|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:clickfinger_behavior|lua-bool|Multi-finger click|||||One, two, three fingers mean left, right, middle|hyprctl reload||1||"
  "input.tapAndDrag|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:tap_and_drag|lua-bool|Tap and drag|||||Tap, then drag without pressing down|hyprctl reload||1||"
  "input.middleEmulation|Touchpad|$HOME/.config/hypr/input.lua|input:touchpad:middle_button_emulation|lua-bool|Middle-click emulation|||||Left and right together click as middle|hyprctl reload||1||"
  # ── Windows — ~/.config/hypr/looknfeel.lua. Official 0.56.2 limits:
  # border_size 0-20, rounding 0-100, dim_strength 0-1, opacities 0-1,
  # column_width 0.1-1.0, gaps officially unbounded (min 0 as sanity guard),
  # layout the four portable ones.
  "window.rounding|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:rounding|lua-int|Corner radius|px|0|100||Round the corners of windows|hyprctl reload|0|1||"
  "window.gapsIn|Windows|$HOME/.config/hypr/looknfeel.lua|general:gaps_in|lua-int|Inner gaps|px|0|||Space between windows|hyprctl reload|5|1||"
  "window.gapsOut|Windows|$HOME/.config/hypr/looknfeel.lua|general:gaps_out|lua-int|Outer gaps|px|0|||Space between windows and screen edges|hyprctl reload|10|1||"
  "window.borderSize|Windows|$HOME/.config/hypr/looknfeel.lua|general:border_size|lua-int|Border size|px|0|20||Thickness of window borders|hyprctl reload|1|1||"
  "window.resizeOnBorder|Windows|$HOME/.config/hypr/looknfeel.lua|general:resize_on_border|lua-bool|Drag borders to resize|||||Resize by dragging borders and gaps|hyprctl reload||1||"
  "window.layout|Windows|$HOME/.config/hypr/looknfeel.lua|general:layout|lua-enum|Window layout||||dwindle,master,scrolling,monocle|How new windows tile; scrolling is side to side|hyprctl reload|dwindle|1||"
  "window.animations|Windows|$HOME/.config/hypr/looknfeel.lua|animations:enabled|lua-bool|Animations|||||Animate windows, workspaces and layers|hyprctl reload||1||"
  "window.dimInactive|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:dim_inactive|lua-bool|Dim inactive windows|||||Darken windows that lack focus|hyprctl reload||1||"
  "window.dimStrength|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:dim_strength|lua-float|Dim strength||0|1||How much inactive windows dim|hyprctl reload|0.5|1||0.05"
  "window.inactiveOpacity|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:inactive_opacity|lua-float|Inactive opacity||0|1||Transparency of windows without focus|hyprctl reload|1.0|1||0.05"
  "window.blur|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:enabled|lua-bool|Blur|||||Blur the wallpaper behind windows|hyprctl reload||1||"
  "window.blurSpecial|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:special|lua-bool|Blur special workspace|||||Blur behind the scratchpad workspace|hyprctl reload||1||"
  "window.shadows|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:shadow:enabled|lua-bool|Window shadows|||||Draw drop shadows under windows|hyprctl reload||1||"
  "window.columnWidth|Windows|$HOME/.config/hypr/looknfeel.lua|scrolling:column_width|lua-float|Scrolling column width||0.1|1||Fraction of the screen one column takes|hyprctl reload|0.5|1||0.01"
  # ── Windows, effects — every route below answers Hyprland 0.56.2 getoption
  # and carries the wiki bound. border-inside has no 0.56.2 route and animation
  # speed has no scalar route: both stay out (see TASKS.md).
  "window.floatGaps|Windows|$HOME/.config/hypr/looknfeel.lua|general:float_gaps|lua-int|Floating gaps|px|0|||Space around floating windows|hyprctl reload|0|1||"
  "window.workspaceGaps|Windows|$HOME/.config/hypr/looknfeel.lua|general:gaps_workspaces|lua-int|Workspace gaps|px|0|||Extra gaps per workspace, added to outer gaps|hyprctl reload|0|1||"
  "window.roundingPower|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:rounding_power|lua-float|Rounding curve||2|10||Corner curve: 2 is a circle, 4 a squircle|hyprctl reload|2.0|1||0.5"
  "window.activeOpacity|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:active_opacity|lua-float|Active opacity||0|1||Transparency of the focused window|hyprctl reload|1.0|1||0.05"
  "window.fullscreenOpacity|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:fullscreen_opacity|lua-float|Fullscreen opacity||0|1||Transparency of fullscreen windows|hyprctl reload|1.0|1||0.05"
  "window.dimSpecial|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:dim_special|lua-float|Special workspace dim||0|1||How much the screen dims behind scratchpad|hyprctl reload|0.2|1||0.05"
  "window.dimAround|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:dim_around|lua-float|Surrounding dim||0|1||Dim level for the dim-around window rule|hyprctl reload|0.4|1||0.05"
  "window.dimModal|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:dim_modal|lua-bool|Modal dim|||||Dim parents of modal windows|hyprctl reload||1||"
  "window.animWrap|Windows|$HOME/.config/hypr/looknfeel.lua|animations:workspace_wraparound|lua-bool|Workspace wraparound|||||Animate edge workspaces as neighbours|hyprctl reload||1||"
  "window.blurSize|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:size|lua-int|Blur size|px|1|||Blur distance in pixels|hyprctl reload|8|1||"
  "window.blurPasses|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:passes|lua-int|Blur passes||1|||Blur refinement passes|hyprctl reload|1|1||"
  "window.blurNoise|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:noise|lua-float|Blur noise||0|1||Grain over the blur|hyprctl reload|0.0117|1||0.01"
  "window.blurContrast|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:contrast|lua-float|Blur contrast||0|2||Contrast of blurred content|hyprctl reload|0.8916|1||0.05"
  "window.blurBrightness|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:brightness|lua-float|Blur brightness||0|2||Brightness of blurred content|hyprctl reload|1.0|1||0.05"
  "window.blurVibrancy|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:vibrancy|lua-float|Blur vibrancy||0|1||Saturation of blurred colours|hyprctl reload|0.1696|1||0.05"
  "window.blurVibrancyDarkness|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:vibrancy_darkness|lua-float|Blur vibrancy darkness||0|1||Vibrancy strength on dark areas|hyprctl reload|0.0|1||0.05"
  "window.blurPopups|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:popups|lua-bool|Blur popups|||||Blur behind menus and popups|hyprctl reload||1||"
  "window.blurXray|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:blur:xray|lua-bool|Blur x-ray|||||Floating windows ignore tiled ones in blur|hyprctl reload||1||"
  "window.shadowRange|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:shadow:range|lua-int|Shadow range|px|0|||Shadow size in pixels|hyprctl reload|4|1||"
  "window.shadowPower|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:shadow:render_power|lua-int|Shadow power||1|4||Shadow falloff speed, 1 to 4|hyprctl reload|3|1||"
  "window.shadowScale|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:shadow:scale|lua-float|Shadow scale||0|1||Shadow size multiplier|hyprctl reload|1.0|1||0.05"
  "window.shadowSharp|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:shadow:sharp|lua-bool|Sharp shadows|||||Hard-edged shadows|hyprctl reload||1||"
  "window.glowEnabled|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:glow:enabled|lua-bool|Window glow|||||Inner glow on windows|hyprctl reload||1||"
  "window.glowRange|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:glow:range|lua-int|Glow range|px|0|||Glow size in pixels|hyprctl reload|10|1||"
  "window.glowPower|Windows|$HOME/.config/hypr/looknfeel.lua|decoration:glow:render_power|lua-int|Glow power||1|4||Glow falloff speed, 1 to 4|hyprctl reload|3|1||"
  "window.snapEnabled|Windows|$HOME/.config/hypr/looknfeel.lua|general:snap:enabled|lua-bool|Window snapping|||||Snap floating windows to edges|hyprctl reload||1||"
  "window.snapWindowGap|Windows|$HOME/.config/hypr/looknfeel.lua|general:snap:window_gap|lua-int|Snap window gap|px|0|||Gap before windows snap together|hyprctl reload|10|1||"
  "window.snapMonitorGap|Windows|$HOME/.config/hypr/looknfeel.lua|general:snap:monitor_gap|lua-int|Snap screen gap|px|0|||Gap before windows snap to edges|hyprctl reload|10|1||"
  "window.snapBorderOverlap|Windows|$HOME/.config/hypr/looknfeel.lua|general:snap:border_overlap|lua-bool|Snap border overlap|||||Snap with one border of space|hyprctl reload||1||"
  # ── Windows, layout: dwindle — verified against Hyprland 0.56.2 getoption.
  # split_bias 0-1 (directional or current), force_split 0-2 (mouse, left/top,
  # right/bottom), multiplier 0.1-4 (wiki gives no upper bound; 4 is generous).
  "window.dwindleBias|Windows|$HOME/.config/hypr/looknfeel.lua|dwindle:split_bias|lua-int|Split recipient||0|1||Which window receives the split ratio|hyprctl reload|0|1||"
  "window.dwindleForceSplit|Windows|$HOME/.config/hypr/looknfeel.lua|dwindle:force_split|lua-int|Forced split direction||0|2||0 follows mouse, 1 left or top, 2 right or bottom|hyprctl reload|0|1||"
  "window.dwindlePreserveSplit|Windows|$HOME/.config/hypr/looknfeel.lua|dwindle:preserve_split|lua-bool|Keep split direction|||||Split side never changes by itself|hyprctl reload||1||"
  "window.dwindleSmartSplit|Windows|$HOME/.config/hypr/looknfeel.lua|dwindle:smart_split|lua-bool|Smart split|||||Split follows the cursor position|hyprctl reload||1||"
  "window.dwindleSplitMultiplier|Windows|$HOME/.config/hypr/looknfeel.lua|dwindle:split_width_multiplier|lua-float|Split width multiplier||0.1|4||Width multiplier for auto-split on wide screens|hyprctl reload|1.0|1||0.05"
  # ── Windows, layout: master — mfact 0-1, new_status the three portable
  # words, orientation the five placements. Verified on 0.56.2.
  "window.masterFactor|Windows|$HOME/.config/hypr/looknfeel.lua|master:mfact|lua-float|Master area size||0|1||Share of the screen for the master window|hyprctl reload|0.55|1||0.01"
  "window.masterNewStatus|Windows|$HOME/.config/hypr/looknfeel.lua|master:new_status|lua-enum|New window status||||master,slave,inherit|Master, slave stack or inherit from focus|hyprctl reload|slave|1||"
  "window.masterOrientation|Windows|$HOME/.config/hypr/looknfeel.lua|master:orientation|lua-enum|Master orientation||||left,right,top,bottom,center|Where the master area sits|hyprctl reload|left|1||"
  # ── Windows, grouped windows — every route answers 0.56.2 getoption.
  # Colors (col.*, text_color) are not portable scalars and stay out, like
  # border-inside before them. gradient_rounding stays out: one rounding
  # control is enough for a portable catalog.
  "window.groupbarEnabled|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:enabled|lua-bool|Group bar|||||Show a bar on grouped windows|hyprctl reload||1||"
  "window.groupbarHeight|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:height|lua-int|Group bar height|px|0|64||Height of the grouped window bar|hyprctl reload|14|1||"
  "window.groupbarIndicatorGap|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:indicator_gap|lua-int|Group indicator gap|px|0|64||Gap between the indicator and the title|hyprctl reload|0|1||"
  "window.groupbarIndicatorHeight|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:indicator_height|lua-int|Group indicator height|px|0|64||Height of the group indicator|hyprctl reload|3|1||"
  "window.groupbarTitles|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:render_titles|lua-bool|Group titles|||||Show window titles in the group bar|hyprctl reload||1||"
  "window.groupbarRounding|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:rounding|lua-int|Group indicator rounding|px|0|40||Rounding of the group indicator|hyprctl reload|1|1||"
  "window.groupbarGradients|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:gradients|lua-bool|Group gradients|||||Gradient colors on the group bar|hyprctl reload||1||"
  "window.groupbarStacked|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:stacked|lua-bool|Stacked group bar|||||Render the group bar vertically|hyprctl reload||1||"
  "window.groupbarFontSize|Windows|$HOME/.config/hypr/looknfeel.lua|group:groupbar:font_size|lua-int|Group bar font size|pt|2|64||Title size in the group bar|hyprctl reload|8|1||"
  # ── Lid & sleep — /etc/systemd/logind.conf.d/, root-owned, laptop only.
  # These are the three questions a laptop actually asks. logind's own built-in
  # default for all three is 'suspend'; the fallback field records that so the
  # panel can show a value even before a drop-in exists.
  "lid.close|Lid & sleep|$LOGIND_DROPIN|Login.HandleLidSwitch|ini-enum|Closing the lid||||suspend,suspend-then-hibernate,hibernate,lock,ignore,poweroff|What happens on battery when the lid closes|systemctl reload systemd-logind|suspend|1||"
  "lid.closeAc|Lid & sleep|$LOGIND_DROPIN|Login.HandleLidSwitchExternalPower|ini-enum|Closing the lid on AC||||suspend,suspend-then-hibernate,hibernate,lock,ignore,poweroff|What happens while plugged in; many people want 'ignore' here|systemctl reload systemd-logind|suspend|1||"
  "lid.closeDocked|Lid & sleep|$LOGIND_DROPIN|Login.HandleLidSwitchDocked|ini-enum|Closing the lid when docked||||ignore,suspend,suspend-then-hibernate,hibernate,lock,poweroff|What happens with an external monitor attached; 'ignore' is clamshell mode|systemctl reload systemd-logind|ignore|1||"
  # ── Defaults
  "default.editor|Defaults|$HOME/.local/state/omarchy/defaults/editor|-|line-enum|Default editor||||nvim,code,hx,micro,nano,zed|Editor Omarchy opens config files with||nvim|1||"
)

# Settings groups, in panel order: "name|icon|description"
SETTING_GROUPS=(
  "Idle & power|󰐥|When the screen dims, locks and the machine suspends"
  "Appearance|󰏘|Theme, bar and how large everything is drawn"
  "Keyboard|󰌌|Key repeat, delay, layout and num lock"
  "Mouse & pointer|󰍽|Sensitivity, acceleration, wheel and handedness"
  "Touchpad|󰎶|Scrolling, tapping, dragging and clicks"
  "Windows|󰖯|Corners, gaps, borders, layout and effects"
  "Lid & sleep|󰌢|What closing the lid does — shown on laptops only"
  "Defaults|󰒓|Which program Omarchy reaches for"
)


# Pure bash: `cut` here meant a fork per field, and the panel reads sixteen
# fields from forty-odd settings on every refresh — hundreds of processes
# for a string split.
setting_field() { local -a fields; IFS='|' read -ra fields <<<"$1"; printf '%s' "${fields[$(($2 - 1))]:-}"; }

find_setting() {
  local id="$1" entry
  # The id is the first field, so a prefix match finds it without a fork.
  # `$(setting_field ...)` here was one fork per registry line, and the panel
  # payload looks up every setting three times: hundreds of forks, and about
  # half of the time that `status --json` took.
  for entry in "${SETTINGS[@]}"; do
    [[ "${entry%%|*}" == "$id" ]] && { printf '%s\n' "$entry"; return 0; }
  done
  return 1
}

# root_apply <destination> <staged file> [command to run afterwards]
# Writes a staged file into a root-owned path, keeping the same .bak.<epoch>
# every other write in this plugin makes, and runs the reload in the SAME
# privileged call so the user is asked at most once.
#
# There is no silent path here. It tries, in order:
#   1. pkexec  — a graphical prompt, when the session runs a polkit agent
#   2. sudo -n — only if this user already has passwordless rights for it
#   3. nothing — prints the exact command and fails, leaving /etc untouched
# Omarchy ships no polkit agent by default, so (3) is the common outcome in the
# panel and (2)/(1) the common one from a terminal. Saying so is the point:
# a settings control that quietly does nothing is worse than one that explains.
root_apply() {
  local dst="$1" staged="$2" after="${3:-}" script
  script='dst="$1"; staged="$2"; after="$3";
    if [ -f "$dst" ]; then cp -a "$dst" "$dst.bak.$(date +%s)" || exit 1; fi
    install -D -m 644 -o root -g root "$staged" "$dst" || exit 1
    [ -n "$after" ] && { sh -c "$after" || exit 2; }
    exit 0'
  if command -v pkexec >/dev/null 2>&1 && [[ -n "${XDG_SESSION_ID:-}${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]]; then
    pkexec /bin/sh -c "$script" _ "$dst" "$staged" "$after" 2>/dev/null && return 0
  fi
  if sudo -n true 2>/dev/null; then
    sudo -n /bin/sh -c "$script" _ "$dst" "$staged" "$after" 2>/dev/null && return 0
  fi
  echo "This one needs root, and nothing on this session could ask for it." >&2
  echo "Nothing was changed. To apply it yourself:" >&2
  echo "  sudo install -D -m 644 $staged $dst" >&2
  [[ -n "$after" ]] && echo "  sudo $after" >&2
  # Always a failure. This read `return "${rc:-1}"` with rc starting at 0, so
  # the path above returned success: `set` printed the new value, exited 0,
  # and the panel reported a write that never happened.
  return 1
}

# ini_set <file> <Section.Key> <value> [reload command]
# Stages the whole edited file under $HOME first, so the privileged step is a
# single copy of a file the user could have inspected, not an editor run as root.
ini_set() {
  invalidate_file_maps
  local file="$1" path="$2" value="$3" after="${4:-}" staged
  # Staged in the plugin's own directory, not in /tmp. When nothing can ask for
  # root, root_apply prints a `sudo install` of this file for the user to run,
  # so the file has to outlive this call. It used to be deleted on the way
  # out, and the printed command named a file that did not exist.
  mkdir -p "$REPLICANT_HOME/staged" || return 1
  staged="$REPLICANT_HOME/staged/$(basename -- "$file")"
  if [[ -f "$file" ]]; then cp -- "$file" "$staged"; else printf '[%s]\n' "${path%%.*}" > "$staged"; fi
  toml_set "$staged" "$path" "$value" || { rm -f "$staged"; return 1; }
  # toml_set keeps whatever spacing surrounded the '='; TOML writes `key = v`
  # and systemd writes `Key=v`. Normalise to systemd's idiom so a drop-in this
  # plugin has touched still reads like every other one on the machine.
  local k="${path#*.}"
  sed -i -E "s|^([[:space:]]*)${k}[[:space:]]*=[[:space:]]*|\1${k}=|" "$staged"
  if [[ -w "$file" || ( ! -e "$file" && -w "$(dirname "$file")" ) ]]; then
    backup_before_write "$file"
    install -D -m 644 "$staged" "$file" || { rm -f "$staged"; return 1; }
    # A test redirects $file to a throwaway fixture, but "systemctl reload
    # systemd-logind" still targets the REAL system service — polkit pops a
    # graphical, fingerprint-eligible auth prompt for it even though nothing
    # here calls sudo/pkexec directly. REPLICANT_NO_RELOAD is the test-only
    # escape hatch, the same shape as REPLICANT_MACHINE/OMARCHY_PATH elsewhere.
    [[ -n "$after" && -z "${REPLICANT_NO_RELOAD:-}" ]] && bash -c "$after" >/dev/null 2>&1
    rm -f "$staged"; return 0
  fi
  # On failure the staged file stays: the message names it.
  root_apply "$file" "$staged" "$after" || return 1
  rm -f "$staged"
}

# Only a machine with a lid should be offered lid settings. On a desktop the
# group is not greyed out, it is absent — an irrelevant control is clutter.
is_laptop() {
  if command -v omarchy-hw-laptop >/dev/null 2>&1; then omarchy-hw-laptop >/dev/null 2>&1; return; fi
  [[ -d /proc/acpi/button/lid ]]
}

# Writes key = value, creating the [section] and/or the key when either is
# absent — shell.toml ships nearly empty, so "the key isn't there yet" is the
# normal first write for most appearance settings, not an error.
# ── TOML / INI writing ──────────────────────────────────────────────────────
# Deliberately minimal: these target a flat "key = value" line inside a
# "[section]" of a small, hand-written config (shell.toml, a logind drop-in).
# They are not a TOML parser and are not meant to grow into one; anything more
# complex stays a whole-file MANIFEST entry, edited in a real editor.
# Reading goes through file_map() instead, which parses the whole file once.
toml_set() {
  invalidate_file_maps
  local file="$1" section="${2%%.*}" key="${2#*.}" value="$3" tmp
  [[ -f "$file" ]] || printf '' > "$file"
  tmp=$(mktemp)
  awk -v sect="[$section]" -v key="$key" -v val="$value" '
    BEGIN { done_it = 0; seen_sect = 0 }
    $0 ~ /^[[:space:]]*\[/ {
      if (in_sect && !done_it) { print key " = " val; done_it = 1 }
      in_sect = ($0 ~ "^[[:space:]]*\\" sect)
      if (in_sect) seen_sect = 1
      print; next
    }
    in_sect && $0 ~ "^[[:space:]]*" key "[[:space:]]*=" {
      if (done_it) next
      sub(/=[[:space:]]*.*/, "= " val); done_it = 1; print; next
    }
    { print }
    END {
      if (!done_it) {
        if (!seen_sect) { print ""; print sect }
        print key " = " val
      }
    }
  ' "$file" > "$tmp" || { rm -f "$tmp"; return 1; }
  [[ -s "$tmp" ]] || { rm -f "$tmp"; return 1; }
  mv "$tmp" "$file"
}

# ── Hyprland Lua helpers ────────────────────────────────────────────────────
# Full-route parsing, never leaf-only. Two routes may share a leaf
# (input:scroll_factor and input:touchpad:scroll_factor); the reader tracks
# the colon-joined nesting inside hl.config blocks, without evaluating Lua.
# Commented lines are ignored. hl.device / o.window single-line rules never
# match the anchored `name =` pattern, and multiline device tables sit outside
# any input parent, so their flat keys (e.g. `sensitivity`) never collide with
# a global full route (e.g. `input:sensitivity`).
REPL_BLOCK_START="-- replicant:settings:start"
REPL_BLOCK_END="-- replicant:settings:end"

# lua_key_of <option> — the leaf of a registry path: "input:touchpad:
# natural_scroll" is the line `natural_scroll = …` in its table.
lua_key_of() { printf '%s\n' "${1##*:}"; }

# lua_all_routes <file> — every uncommented `key = literal` inside the file as
# "full:route<TAB>literal", in file order, duplicates included. The caller
# decides: the managed block takes the last occurrence, outside content
# requires exactly one (anything else reads as missing, refusing to guess).
#
# The literal stays intact. A managed block must retain quotes around enums
# when a later edit rewrites it. The public readers unquote after this parser.
lua_all_routes() {
  local file="$1"
  [[ -f "$file" ]] || return 1
  awk '
    {
      orig = $0
      line = orig
      # Strip line comments without treating `--` inside a quoted literal as a
      # comment. A complete multiline comment does not describe configuration.
      if (in_comment) {
        ci = index(line, "]]")
        if (ci == 0) next
        line = substr(line, ci + 2); in_comment = 0
      }
      out = ""; quote = ""; escaped = 0
      for (ci = 1; ci <= length(line); ci++) {
        ch = substr(line, ci, 1); nextch = substr(line, ci + 1, 1)
        if (quote != "") {
          out = out ch
          if (escaped) escaped = 0
          else if (ch == "\\") escaped = 1
          else if (ch == quote) quote = ""
          continue
        }
        if (ch == "\"" || ch == "\047") { quote = ch; out = out ch; continue }
        if (ch == "-" && nextch == "-") {
          if (substr(line, ci + 2, 2) == "[[") in_comment = 1
          break
        }
        out = out ch
      }
      line = out
      if (line ~ /^[[:space:]]*$/) next
      tmp = line; opens = gsub(/\{/, "{", tmp)
      tmp = line; closes = gsub(/\}/, "}", tmp)
      # table open: `name = {` with nothing after the brace
      if (line ~ /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*\{[[:space:]]*$/) {
        name = line; sub(/^[[:space:]]*/, "", name); sub(/[[:space:]]*=.*$/, "", name)
        if (name ~ /^[A-Za-z0-9_]+$/) {
          new_depth = depth + opens - closes
          sp++; stack[sp] = name; sdepth[sp] = new_depth
          depth = new_depth
          next
        }
      }
      # leaf: anchored `key = raw`, key a bare identifier
      if (line ~ /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=/) {
        key = line; sub(/^[[:space:]]*/, "", key); sub(/[[:space:]]*=.*$/, "", key)
        if (key ~ /^[A-Za-z0-9_]+$/) {
          raw = line; sub(/^[^=]*=/, "", raw)
          sub(/^[[:space:]]*/, "", raw); sub(/[[:space:]]*$/, "", raw)
          sub(/,[[:space:]]*$/, "", raw); sub(/[[:space:]]*$/, "", raw)
          route = ""
          for (i = 1; i <= sp; i++) route = (route == "" ? stack[i] : route ":" stack[i])
          route = (route == "" ? key : route ":" key)
          printf "%s\t%s\n", route, raw
        }
      }
      new_depth = depth + opens - closes
      # table opens already pushed above; only pop here
      if (!(line ~ /^[[:space:]]*[A-Za-z0-9_]+[[:space:]]*=[[:space:]]*\{[[:space:]]*$/)) {
        depth = new_depth
        while (sp > 0 && sdepth[sp] > depth) sp--
      } else {
        depth = new_depth
      }
    }
  ' "$file"
}

# lua_literal_value <literal> — turn the supported Lua scalar literals into
# the value used by the settings registry. The writer keeps the literal above;
# this boundary prevents an enum such as "us" becoming the Lua variable `us`.
lua_literal_value() {
  local literal="$1"
  if [[ "$literal" =~ ^\"([^\"\\]|\\.)*\"$ ]]; then
    literal="${literal:1:${#literal}-2}"
    literal="${literal//\\\"/\"}"
    literal="${literal//\\\\/\\}"
  elif [[ "$literal" =~ ^\'([^\'\\]|\\.)*\'$ ]]; then
    literal="${literal:1:${#literal}-2}"
    literal="${literal//\\\'/\'}"
    literal="${literal//\\\\/\\}"
  fi
  printf '%s\n' "$literal"
}

# lua_block_check <file>: 0 block present and well-formed, 2 no block,
# 1 duplicated or damaged markers (do not modify the file).
lua_block_check() {
  local file="$1" s e cs ce sl el
  [[ -f "$file" ]] || return 1
  s=$(grep -cF -- "$REPL_BLOCK_START" "$file" 2>/dev/null || true)
  e=$(grep -cF -- "$REPL_BLOCK_END" "$file" 2>/dev/null || true)
  [[ "$s" == "0" && "$e" == "0" ]] && return 2
  [[ "$s" == "1" && "$e" == "1" ]] || return 1
  # Extraction accepts only canonical full lines. Treat every other spelling
  # as damaged, rather than appending a second block that no reader recognises.
  cs=$(grep -cxF -- "$REPL_BLOCK_START" "$file" 2>/dev/null || true)
  ce=$(grep -cxF -- "$REPL_BLOCK_END" "$file" 2>/dev/null || true)
  [[ "$cs" == "1" && "$ce" == "1" ]] || return 1
  sl=$(grep -nxF -- "$REPL_BLOCK_START" "$file" | cut -d: -f1)
  el=$(grep -nxF -- "$REPL_BLOCK_END" "$file" | cut -d: -f1)
  [[ -n "$sl" && -n "$el" && "$sl" -lt "$el" ]] || return 1
  return 0
}

# lua_block_lines <file> — inner lines of the managed block. Empty when the
# file carries no block. Fails on damaged markers.
lua_block_lines() {
  local file="$1" rc=0
  lua_block_check "$file"; rc=$?
  (( rc == 2 )) && return 0
  (( rc != 0 )) && return 1
  awk -v s="$REPL_BLOCK_START" -v e="$REPL_BLOCK_END" '
    $0 == s { inside = 1; next }
    $0 == e { inside = 0; next }
    inside { print }
  ' "$file"
}

# lua_outside_lines <file> — the file with the managed block removed.
# Fails on damaged markers so the caller never edits half a file.
lua_outside_lines() {
  local file="$1" rc=0
  lua_block_check "$file"; rc=$?
  (( rc == 2 )) && { cat -- "$file"; return 0; }
  (( rc != 0 )) && return 1
  awk -v s="$REPL_BLOCK_START" -v e="$REPL_BLOCK_END" '
    $0 == s { skip = 1; next }
    $0 == e { skip = 0; next }
    !skip { print }
  ' "$file"
}

# lua_value_in_routes <route> — last occurrence of route on stdin
# ("route<TAB>value" lines). Used for block content, where the block wins.
lua_value_in_routes() {
  local want="$1" k v found=1 out=""
  while IFS=$'\t' read -r k v; do
    [[ "$k" == "$want" ]] && { out="$v"; found=0; }
  done
  (( found == 0 )) || return 1
  lua_literal_value "$out"
}

# lua_settings_map <file> — resolve manual routes once and let a valid managed
# block override them. A duplicate manual route remains unavailable. A managed
# block must contain only one supported literal per route.
lua_settings_map() {
  local file="$1" rc=0 tmpdir outside block k v type
  [[ -f "$file" ]] || return 1
  lua_block_check "$file"; rc=$?
  (( rc == 1 )) && return 1
  tmpdir=$(mktemp -d) || return 1
  outside="$tmpdir/outside"; block="$tmpdir/block"
  lua_outside_lines "$file" > "$outside" 2>/dev/null || { rm -rf "$tmpdir"; return 1; }
  declare -A outside_count=() outside_value=() block_count=() block_value=()
  while IFS=$'\t' read -r k v; do
    [[ -n "$k" ]] || continue
    outside_count["$k"]=$(( ${outside_count[$k]:-0} + 1 ))
    outside_value["$k"]="$v"
  done < <(lua_all_routes "$outside" 2>/dev/null || true)
  if (( rc == 0 )); then
    lua_block_lines "$file" > "$block" 2>/dev/null || { rm -rf "$tmpdir"; return 1; }
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] || continue
      type=$(lua_setting_type "$file" "$k") || { rm -rf "$tmpdir"; return 1; }
      lua_literal_matches_type "$type" "$v" || { rm -rf "$tmpdir"; return 1; }
      block_count["$k"]=$(( ${block_count[$k]:-0} + 1 ))
      block_value["$k"]="$v"
    done < <(lua_all_routes "$block" 2>/dev/null || true)
  fi
  for k in "${!outside_count[@]}"; do
    [[ "${outside_count[$k]}" == 1 ]] || continue
    [[ -z "${block_count[$k]:-}" ]] || continue
    printf '%s\t%s\n' "$k" "$(lua_literal_value "${outside_value[$k]}")"
  done
  for k in "${!block_count[@]}"; do
    [[ "${block_count[$k]}" == 1 ]] || { rm -rf "$tmpdir"; return 1; }
    printf '%s\t%s\n' "$k" "$(lua_literal_value "${block_value[$k]}")"
  done
  rm -rf "$tmpdir"
}

# lua_file_value <file> <route> — a cache-backed lookup. build_settings_json
# warms this map once per source, default, and repo file before its readers run.
lua_file_value() {
  local file="$1" route="$2" k v entries
  if [[ "${REPLICANT_SETTINGS_REFRESH:-}" == 1 ]]; then
    map_lookup "$file" lua "$route"
    return
  fi
  entries=$(lua_settings_map "$file") || return 1
  while IFS=$'\t' read -r k v; do
    [[ "$k" == "$route" ]] && { printf '%s\n' "$v"; return 0; }
  done <<<"$entries"
  return 1
}

# Backwards-compatible leaf counter, now full-route aware. Counts occurrences
# of a full route in the whole file (block included).
lua_key_hits() { lua_all_routes "$1" 2>/dev/null | awk -F'\t' -v w="$2" '$1 == w { c++ } END { print c+0 }'; }

# lua_get <file> <route> — kept for callers that read one value.
lua_get() { lua_file_value "$1" "$2"; }

# lua_set <file> <route> <formatted-value> — low-level block update without
# Hyprland validation. set_setting_value uses the validating wrapper below.
lua_set() {
  local file="$1" route="$2" formatted="$3"
  lua_block_write "$file" "$route" "$formatted"
}

# lua_format_value <type> <value> — the Lua literal for the block.
lua_format_value() {
  local type="$1" value="$2"
  case "$type" in
    lua-enum|lua-string) printf '"%s"\n' "$value" ;;
    *) printf '%s\n' "$value" ;;
  esac
}

lua_setting_type() {
  local file="$1" route="$2" entry
  local -a fields
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -ra fields <<<"$entry"
    [[ "${fields[2]}" == "$file" && "${fields[3]}" == "$route" ]] || continue
    printf '%s\n' "${fields[4]}"
    return 0
  done
  # Saved and installed-default copies have different absolute paths. Routes
  # remain globally named, so their registry type stays the authority there.
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -ra fields <<<"$entry"
    [[ "${fields[3]}" == "$route" ]] || continue
    printf '%s\n' "${fields[4]}"
    return 0
  done
  return 1
}

lua_literal_matches_type() {
  local type="$1" literal="$2"
  case "$type" in
    lua-int) [[ "$literal" =~ ^-?[0-9]+$ ]] ;;
    lua-float) [[ "$literal" =~ ^-?[0-9]*\.?[0-9]+$ ]] ;;
    lua-bool) [[ "$literal" == true || "$literal" == false ]] ;;
    lua-enum|lua-string) [[ "$literal" =~ ^\"([^\"\\]|\\.)*\"$ ]] || [[ "$literal" =~ ^\'([^\'\\]|\\.)*\'$ ]] ;;
    *) return 1 ;;
  esac
}

# lua_block_write <file> <route> <formatted-value> — replace the managed block
# deterministically, preserving every byte outside it. The block always sits
# at the end of the file. Rejects duplicated/damaged markers without touching
# the file. Idempotent: the same values always render the same bytes.
lua_block_write() {
  invalidate_file_maps
  local file="$1" route="$2" formatted="$3" rc=0
  [[ -f "$file" ]] || return 1
  lua_block_check "$file"; rc=$?
  (( rc == 1 )) && return 1
  local tmpdir tmp_out tmp_blk tmp_new
  tmpdir=$(mktemp -d) || return 1
  tmp_out="$tmpdir/outside"; tmp_blk="$tmpdir/block"; tmp_new="$tmpdir/new"
  if (( rc == 0 )); then
    lua_outside_lines "$file" > "$tmp_out" || { rm -rf "$tmpdir"; return 1; }
  else
    cat -- "$file" > "$tmp_out" || { rm -rf "$tmpdir"; return 1; }
  fi
  # existing managed values, last wins
  declare -A vals=()
  if (( rc == 0 )); then
    local blk="$tmpdir/blkroutes"
    lua_block_lines "$file" > "$blk" 2>/dev/null || { rm -rf "$tmpdir"; return 1; }
    local k v type
    while IFS=$'\t' read -r k v; do
      [[ -n "$k" ]] || continue
      type=$(lua_setting_type "$file" "$k") || { rm -rf "$tmpdir"; return 1; }
      lua_literal_matches_type "$type" "$v" || { rm -rf "$tmpdir"; return 1; }
      [[ -z "${vals[$k]+x}" ]] || { rm -rf "$tmpdir"; return 1; }
      vals["$k"]="$v"
    done < <(lua_all_routes "$blk" 2>/dev/null || true)
  fi
  vals["$route"]="$formatted"
  if ! lua_render_block "$file" "$tmp_blk" vals; then rm -rf "$tmpdir"; return 1; fi
  # outside bytes untouched, block at the end
  if [[ -s "$tmp_out" ]] && [[ -n "$(tail -c1 "$tmp_out" 2>/dev/null)" ]]; then
    printf '\n' >> "$tmp_out" || { rm -rf "$tmpdir"; return 1; }
  fi
  cat -- "$tmp_out" "$tmp_blk" > "$tmp_new" || { rm -rf "$tmpdir"; return 1; }
  [[ -s "$tmp_new" ]] || { rm -rf "$tmpdir"; return 1; }
  mv -- "$tmp_new" "$file" || { rm -rf "$tmpdir"; return 1; }
  rm -rf "$tmpdir"
}

# lua_render_block <file> <out> <assoc-name> — deterministic hl.config block
# for the file's managed routes. Only tables carrying values are emitted,
# keys sorted byte-wise (LC_ALL=C).
lua_render_block() {
  local file="$1" out="$2" aname="$3"
  local -a routes=()
  eval 'for k in "${!'"$aname"'[@]}"; do routes+=("$k"); done'
  [[ ${#routes[@]} -gt 0 ]] || return 1
  {
    printf '%s\n' "$REPL_BLOCK_START"
    printf -- '-- Managed by Replicant. Do not edit inside this block by hand.\n'
    if [[ "$file" == *input.lua ]]; then
      lua_render_input_block "$aname"
    elif [[ "$file" == *looknfeel.lua ]]; then
      lua_render_look_block "$aname"
    else
      return 1
    fi
    printf '%s\n' "$REPL_BLOCK_END"
  } > "$out" || return 1
  [[ -s "$out" ]] || return 1
}

lua_render_input_block() {
  local aname="$1" k v
  local -a direct=() touch=()
  eval 'for k in "${!'"$aname"'[@]}"; do
    case "$k" in
      input:touchpad:*) touch+=("${k#input:touchpad:}") ;;
      input:*) direct+=("${k#input:}") ;;
    esac
  done'
  [[ ${#direct[@]} -eq 0 && ${#touch[@]} -eq 0 ]] && return 1
  printf 'hl.config({\n  input = {\n'
  local key
  while IFS= read -r key; do
    [[ -n "$key" ]] || continue
    eval 'v="${'"$aname"'[input:'"$key"']}"'
    printf '    %s = %s,\n' "$key" "$v"
  done < <(printf '%s\n' "${direct[@]}" | LC_ALL=C sort -u)
  if (( ${#touch[@]} )); then
    printf '    touchpad = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[input:touchpad:'"$key"']}"'
      printf '      %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${touch[@]}" | LC_ALL=C sort -u)
    printf '    },\n'
  fi
  printf '  },\n})\n'
}

lua_render_look_block() {
  local aname="$1" k v
  local -a general=() anim=() scroll=() deco=() blur=() shadow=() dwindle=() master=() groupbar=()
  eval 'for k in "${!'"$aname"'[@]}"; do
    case "$k" in
      general:*) v="${k#general:}"; general+=("$v") ;;
      animations:*) v="${k#animations:}"; anim+=("$v") ;;
      scrolling:*) v="${k#scrolling:}"; scroll+=("$v") ;;
      decoration:blur:*) v="${k#decoration:blur:}"; blur+=("$v") ;;
      decoration:shadow:*) v="${k#decoration:shadow:}"; shadow+=("$v") ;;
      decoration:*) v="${k#decoration:}"; deco+=("$v") ;;
      dwindle:*) v="${k#dwindle:}"; dwindle+=("$v") ;;
      master:*) v="${k#master:}"; master+=("$v") ;;
      group:groupbar:*) v="${k#group:groupbar:}"; groupbar+=("$v") ;;
    esac
  done'
  printf 'hl.config({\n'
  local key
  if (( ${#anim[@]} )); then
    printf '  animations = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[animations:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${anim[@]}" | LC_ALL=C sort -u)
    printf '  },\n'
  fi
  if (( ${#deco[@]} + ${#blur[@]} + ${#shadow[@]} > 0 )); then
    printf '  decoration = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[decoration:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${deco[@]}" | LC_ALL=C sort -u)
    if (( ${#blur[@]} )); then
      printf '    blur = {\n'
      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        eval 'v="${'"$aname"'[decoration:blur:'"$key"']}"'
        printf '      %s = %s,\n' "$key" "$v"
      done < <(printf '%s\n' "${blur[@]}" | LC_ALL=C sort -u)
      printf '    },\n'
    fi
    if (( ${#shadow[@]} )); then
      printf '    shadow = {\n'
      while IFS= read -r key; do
        [[ -n "$key" ]] || continue
        eval 'v="${'"$aname"'[decoration:shadow:'"$key"']}"'
        printf '      %s = %s,\n' "$key" "$v"
      done < <(printf '%s\n' "${shadow[@]}" | LC_ALL=C sort -u)
      printf '    },\n'
    fi
    printf '  },\n'
  fi
  if (( ${#general[@]} )); then
    printf '  general = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[general:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${general[@]}" | LC_ALL=C sort -u)
    printf '  },\n'
  fi
  if (( ${#scroll[@]} )); then
    printf '  scrolling = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[scrolling:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${scroll[@]}" | LC_ALL=C sort -u)
    printf '  },\n'
  fi
  if (( ${#dwindle[@]} )); then
    printf '  dwindle = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[dwindle:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${dwindle[@]}" | LC_ALL=C sort -u)
    printf '  },\n'
  fi
  if (( ${#master[@]} )); then
    printf '  master = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[master:'"$key"']}"'
      printf '    %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${master[@]}" | LC_ALL=C sort -u)
    printf '  },\n'
  fi
  if (( ${#groupbar[@]} )); then
    printf '  group = {\n'
    printf '    groupbar = {\n'
    while IFS= read -r key; do
      [[ -n "$key" ]] || continue
      eval 'v="${'"$aname"'[group:groupbar:'"$key"']}"'
      printf '      %s = %s,\n' "$key" "$v"
    done < <(printf '%s\n' "${groupbar[@]}" | LC_ALL=C sort -u)
    printf '    },\n'
    printf '  },\n'
  fi
  printf '})\n'
}

# hypr_in_force <option> — the value Hyprland is using now, as the file would
# spell it ("40", "true", "es"). Fails when there is no Hyprland to ask, when
# the option is unset ([[EMPTY]]/[[AUTO]] placeholders), or for mixed per-side
# css gaps which are not a single int.
hypr_in_force() {
  command -v hyprctl >/dev/null 2>&1 || return 1
  local out
  out=$(timeout 2 hyprctl getoption "$1" -j 2>/dev/null) || return 1
  local kind
  kind=$(jq -r 'if has("int") then "int" elif has("float") then "float"
    elif has("bool") then "bool" elif has("str") then "str"
    elif has("css") then "css" else "none" end' <<<"$out" 2>/dev/null) || return 1
  case "$kind" in
    int|float|bool)
      jq -er 'if has("int") then .int elif has("float") then .float
              elif has("bool") then .bool else empty end
              | tostring' <<<"$out" 2>/dev/null
      ;;
    str)
      local s
      s=$(jq -er '.str' <<<"$out" 2>/dev/null) || return 1
      [[ "$s" == "[["*"]]" ]] && return 1
      printf '%s\n' "$s"
      ;;
    css)
      local css first ok=1 part
      css=$(jq -er '.css' <<<"$out" 2>/dev/null) || return 1
      first=""; ok=1
      for part in $css; do
        [[ -z "$first" ]] && first="$part"
        [[ "$part" == "$first" ]] || { ok=0; break; }
      done
      (( ok )) && [[ -n "$first" ]] && printf '%s\n' "$first" || return 1
      ;;
    *) return 1 ;;
  esac
}

# hypr_config_errors — return only actual configuration errors. A failed query
# is unsafe: the caller cannot prove that the candidate loaded correctly.
hypr_config_errors() {
  local out
  out=$(timeout 2 hyprctl configerrors 2>&1) || return 1
  printf '%s\n' "$out" | awk '$0 !~ /^no errors[[:space:]]*$/ && $0 != ""'
}

# hypr_overrider <route> <own-file> — the tracked Hyprland file, other than the
# setting's own, holding the same full route. Found modules are asked first:
# OmaSettings' omasettings.lua is loaded last, which is why it wins.
hypr_overrider() {
  local route="$1" own="$2" entry src
  for entry in ${AUTO_MANIFEST[@]+"${AUTO_MANIFEST[@]}"} "${TRACKED[@]}"; do
    src="${entry%%:*}"
    [[ "$src" == "$HOME/.config/hypr/"*.lua && "$src" != "$own" && -f "$src" ]] || continue
    lua_file_value "$src" "$route" >/dev/null 2>&1 && { printf '%s\n' "${entry##*:}"; return 0; }
  done
  return 1
}

# hypr_device_override <file> <leaf> — true when any hl.device rule in the
# file sets <leaf>. Device names are never printed: the notice names no
# private hardware.
hypr_device_override() {
  local file="$1" leaf="$2"
  [[ -f "$file" ]] || return 1
  awk -v leaf="$leaf" '
    {
      line = $0
      ci = index(line, "--")
      if (ci > 0) line = substr(line, 1, ci - 1)
      if (line ~ /hl\.device[[:space:]]*\(/) { indev = 1 }
      if (indev) {
        # anchored inner line (multiline tables) or anywhere inside a
        # single-line hl.device({ ... leaf = ... }) rule
        if (line ~ "^[[:space:]]*" leaf "[[:space:]]*=") { found = 1; exit 0 }
        if (line ~ "(^|[^A-Za-z0-9_])" leaf "[[:space:]]*=") { found = 1; exit 0 }
        # track multiline device tables by brace depth
        if (!started) {
          t = line; o = gsub(/\{/, "{", t); t = line; c = gsub(/\}/, "}", t)
          d = o - c
          if (d > 0) { started = 1; depth = d }
          else if (o > 0 && c > 0) { indev = 0 }
        } else {
          t = line; o = gsub(/\{/, "{", t); t = line; c = gsub(/\}/, "}", t)
          depth += o - c
          if (depth <= 0) { indev = 0; started = 0; depth = 0 }
        }
      }
    }
    END { exit !found }
  ' "$file"
}

# ── read / write one setting ────────────────────────────────────────────────
setting_options() {
  # Two option lists are not fixed: the themes installed now, and the keyboard
  # layouts this machine knows (`@x11-layouts` in the registry). A fixed list
  # of eight layouts left anyone outside it with a control that could not show
  # or keep the value.
  local entry="$1" opts cache_key="$1"
  if [[ "${REPLICANT_SETTINGS_REFRESH:-}" == 1 && -v "SETTING_OPTIONS_CACHE[$cache_key]" ]]; then
    printf '%s\n' "${SETTING_OPTIONS_CACHE[$cache_key]}"
    return 0
  fi
  if [[ "$(setting_field "$entry" 5)" == "theme" ]]; then
    opts=$(omarchy-theme-list 2>/dev/null | paste -sd, - || true)
  elif [[ "$(setting_field "$entry" 5)" == "font" ]]; then
    opts=$(omarchy font list 2>/dev/null | paste -sd, - || true)
  else
    opts=$(setting_field "$entry" 10)
    if [[ "$opts" == "@x11-layouts" ]]; then
      opts=$(localectl list-x11-keymap-layouts 2>/dev/null | paste -sd, - || true)
      [[ -n "$opts" ]] || opts="us,es,gb,de,fr,it,pt,latam"
    fi
  fi
  [[ "${REPLICANT_SETTINGS_REFRESH:-}" == 1 ]] && SETTING_OPTIONS_CACHE["$cache_key"]="$opts"
  printf '%s\n' "$opts"
}

get_setting_value() {
  # The builder passes its split entry to skip repeated registry searches.
  local entry="${2:-}"
  [[ -n "$entry" ]] || entry=$(find_setting "$1") || return 1
  local file path type raw
  if [[ -n "${2:-}" ]]; then
    file="$3"; path="$4"; type="$5"
  else
    file=$(setting_field "$entry" 3); path=$(setting_field "$entry" 4); type=$(setting_field "$entry" 5)
  fi
  case "$type" in
    theme)
      omarchy-theme-current 2>/dev/null || return 1
      ;;
    font)
      raw=$(omarchy font current 2>/dev/null | head -n1)
      [[ -n "$raw" ]] || return 1
      printf '%s\n' "$raw"
      ;;
    line-enum)
      [[ -f "$file" ]] || return 1
      raw=$(head -n1 "$file" 2>/dev/null | tr -d '[:space:]')
      [[ -n "$raw" ]] || return 1
      printf '%s\n' "$raw"
      ;;
    toml-int|toml-float)
      [[ -f "$file" ]] || return 1
      raw=$(map_lookup "$file" toml "$path") || return 1
      [[ -n "$raw" ]] || return 1
      printf '%s\n' "$raw"
      ;;
    ini-enum)
      # No drop-in yet means logind is on its built-in default, which is what
      # the fallback field records — so report that rather than "missing".
      if [[ -f "$file" ]]; then
        raw=$(map_lookup "$file" toml "$path" 2>/dev/null || true)
        [[ -n "$raw" ]] && { printf '%s\n' "$raw"; return 0; }
      fi
      raw=$(setting_field "$entry" 13)
      [[ -n "$raw" ]] || return 1
      printf '%s\n' "$raw"
      ;;
    lua-int|lua-float|lua-bool|lua-enum|lua-string)
      lua_file_value "$file" "$path"
      ;;
    *)
      [[ -f "$file" ]] || return 1
      # A missing key reads as absent, but `false` must not: jq's `//` fires on
      # false as well as null, so a boolean setting that is genuinely off would
      # look like a setting that is not there.
      raw=$(map_lookup "$file" json "$path") || return 1
      [[ "$raw" == "null" ]] && return 1
      printf '%s\n' "$raw"
      ;;
  esac
}

# numeric guard that also works for floats (bash arithmetic is integer-only)
num_in_range() {
  # Callers have already checked the shape of $1; this only bounds it, in awk
  # because bash arithmetic cannot compare floats.
  awk -v v="$1" -v lo="$2" -v hi="$3" '
    BEGIN {
      if (lo != "" && v + 0 < lo + 0) exit 1
      if (hi != "" && v + 0 > hi + 0) exit 1
      exit 0
    }' </dev/null
}

set_setting_value() {
  require_ready_schema || return 1
  invalidate_file_maps
  local entry; entry=$(find_setting "$1") || { echo "unknown setting: $1" >&2; return 1; }
  local file path type label unit min max options apply value="$2"
  file=$(setting_field "$entry" 3);    path=$(setting_field "$entry" 4)
  type=$(setting_field "$entry" 5);    label=$(setting_field "$entry" 6)
  unit=$(setting_field "$entry" 7);    min=$(setting_field "$entry" 8)
  max=$(setting_field "$entry" 9);     apply=$(setting_field "$entry" 12)
  options=$(setting_options "$entry")

  # ── validate before touching anything
  case "$type" in
    number|toml-int|lua-int)
      [[ "$value" =~ ^-?[0-9]+$ ]] || { echo "$1: '$value' is not a whole number" >&2; return 1; }
      num_in_range "$value" "$min" "$max" || { echo "$1: $value$unit is outside ${min:-?}–${max:-?}$unit" >&2; return 1; }
      ;;
    toml-float|lua-float)
      [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]] || { echo "$1: '$value' is not a number" >&2; return 1; }
      num_in_range "$value" "$min" "$max" || { echo "$1: $value$unit is outside ${min:-?}–${max:-?}$unit" >&2; return 1; }
      ;;
    bool|lua-bool)
      [[ "$value" == "true" || "$value" == "false" ]] || { echo "$1: '$value' must be true or false" >&2; return 1; }
      ;;
    enum|lua-enum|line-enum|theme|font|ini-enum)
      [[ -n "$options" ]] || { echo "$1: no options available on this machine" >&2; return 1; }
      if [[ "$options" == "@x11-layouts" ]]; then
        # dynamic list already resolved above; accept what this machine knows
        [[ ",$options," == *",$value,"* ]] || { echo "$1: '$value' is not one of: ${options//,/, }" >&2; return 1; }
      else
        [[ ",$options," == *",$value,"* ]] || { echo "$1: '$value' is not one of: ${options//,/, }" >&2; return 1; }
      fi
      ;;
    string)
      [[ -n "$value" ]] || { echo "$1: value must not be empty" >&2; return 1; }
      [[ "$value" =~ ^[A-Za-z0-9._-]+$ ]] || { echo "$1: '$value' is not a widget id" >&2; return 1; }
      ;;
    lua-string)
      # Free Hyprland strings: letters, digits and the separators an XKB
      # setup needs (comma, colon, plus, underscore, dash). Empty means none.
      [[ "$value" =~ ^[A-Za-z0-9_:,+\.-]*$ ]] || { echo "$1: '$value' holds unsupported characters" >&2; return 1; }
      ;;
  esac

  # ── write
  case "$type" in
    theme)
      omarchy-theme-set "$value" >/dev/null 2>&1 || { echo "$1: omarchy-theme-set failed" >&2; return 1; }
      ;;
    font)
      omarchy font set "$value" >/dev/null 2>&1 || { echo "$1: omarchy font set failed" >&2; return 1; }
      ;;
    line-enum)
      backup_before_write "$file"
      mkdir -p "$(dirname "$file")"
      printf '%s\n' "$value" > "$file" || { echo "$1: could not write $file" >&2; return 1; }
      ;;
    toml-int|toml-float)
      backup_before_write "$file"
      toml_set "$file" "$path" "$value" || { echo "$1: could not write '$path' in $file — left untouched" >&2; return 1; }
      ;;
    ini-enum)
      # The reload is part of the privileged write, so root is asked once, not
      # twice — hence apply is consumed here and cleared before the tail below.
      ini_set "$file" "$path" "$value" "$apply" || { echo "$1: $file was left untouched" >&2; return 1; }
      apply=""
      ;;
    lua-int|lua-float|lua-bool|lua-enum|lua-string)
      local out_tmp out_n backup_path new_errors
      [[ -f "$file" ]] || { echo "file not found: $file" >&2; return 1; }
      if ! command -v hyprctl >/dev/null 2>&1; then
        echo "$1: Hyprland is not available — left $file untouched, nothing was applied" >&2
        return 1
      fi
      # A repeated full route outside the managed block is ambiguous: refuse
      # rather than guessing. The block itself always wins (it sits last), so
      # one outside occurrence plus the block is fine — only two outside is not.
      {
        out_tmp=$(mktemp) || { echo "$1: could not stage $file" >&2; return 1; }
        if lua_outside_lines "$file" > "$out_tmp" 2>/dev/null; then
          out_n=$(lua_all_routes "$out_tmp" 2>/dev/null | awk -F'\t' -v w="$path" '$1 == w { c++ } END { print c+0 }')
          [[ "$out_n" -gt 1 ]] && { rm -f "$out_tmp"; echo "$1: '$path' is ambiguous in $file — left untouched" >&2; return 1; }
        fi
        rm -f "$out_tmp"
      }
      formatted=$(lua_format_value "$type" "$value")
      before_errs=$(hypr_config_errors) || { echo "$1: could not validate the current Hyprland configuration" >&2; return 1; }
      backup_before_write "$file" || { echo "$1: could not back up $file" >&2; return 1; }
      # The backup function gives each file a unique timestamped name. Capture
      # this exact copy before the replacement so rollback never guesses.
      backup_path=$(ls -1t -- "$file".bak.* 2>/dev/null | head -n1 || true)
      [[ -n "$backup_path" ]] || { echo "$1: backup for $file is missing" >&2; return 1; }
      if ! lua_block_write "$file" "$path" "$formatted"; then
        echo "$1: '$path' markers are duplicated or damaged in $file — left untouched" >&2
        return 1
      fi
      if ! timeout 2 bash -c "$apply" >/dev/null 2>&1; then
        if ! cp -a -- "$backup_path" "$file"; then
          echo "$1: '$apply' failed and Replicant could not restore $file from $backup_path" >&2
          return 1
        fi
        invalidate_file_maps
        timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
        echo "$1: '$apply' failed — restored $file, nothing was applied" >&2
        return 1
      fi
      after_errs=$(hypr_config_errors) || {
        if ! cp -a -- "$backup_path" "$file"; then
          echo "$1: could not validate the candidate and Replicant could not restore $file from $backup_path" >&2
          return 1
        fi
        invalidate_file_maps
        timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
        echo "$1: could not validate the candidate — restored $file, nothing was saved" >&2
        return 1
      }
      new_errors=""
      while IFS= read -r line; do
        [[ -n "$line" ]] || continue
        grep -Fxq -- "$line" <(printf '%s\n' "$before_errs") 2>/dev/null || new_errors+="$line"$'\n'
      done <<<"$after_errs"
      if [[ -n "$new_errors" ]]; then
        if ! cp -a -- "$backup_path" "$file"; then
          echo "$1: Hyprland reported new config errors and Replicant could not restore $file from $backup_path" >&2
          return 1
        fi
        invalidate_file_maps
        timeout 2 bash -c "$apply" >/dev/null 2>&1 || true
        echo "$1: Hyprland reported new config errors — restored $file, nothing was saved" >&2
        printf '%s' "$new_errors" >&2
        return 1
      fi
      apply=""
      # A reader can have warmed this file while it validated defaults or
      # notices. Drop that snapshot after a successful replacement so the
      # next read never reports the manual value above the managed block.
      invalidate_file_maps
      ;;
    number|bool)
      [[ -f "$file" ]] || { echo "file not found: $file" >&2; return 1; }
      backup_before_write "$file"
      local tmp; tmp=$(mktemp)
      jq --argjson v "$value" "$path = \$v" "$file" > "$tmp" 2>/dev/null
      [[ -s "$tmp" ]] || { echo "$1: write failed, left $file untouched" >&2; rm -f "$tmp"; return 1; }
      mv "$tmp" "$file"
      ;;
    *)
      [[ -f "$file" ]] || { echo "file not found: $file" >&2; return 1; }
      backup_before_write "$file"
      local tmp; tmp=$(mktemp)
      jq --arg v "$value" "$path = \$v" "$file" > "$tmp" 2>/dev/null
      [[ -s "$tmp" ]] || { echo "$1: write failed, left $file untouched" >&2; rm -f "$tmp"; return 1; }
      mv "$tmp" "$file"
      ;;
  esac

  # ── make it take effect, when the target isn't watching its own file
  if [[ -n "$apply" ]]; then
    bash -c "$apply" >/dev/null 2>&1 || echo "$1: written, but '$apply' failed — it may need a manual reload" >&2
  fi
  echo "$label -> $value$unit" >&2
}

# ── humanising values ───────────────────────────────────────────────────────
# Omarchy stores idle timers in seconds and densities as bare multipliers.
# Those are the right things to store and the wrong things to *read*: "600"
# tells you nothing, "10 min" tells you everything. Every number the panel
# shows goes through here, and the CLI keeps speaking the stored unit.
human_duration() {
  local s="$1" h m
  [[ "$s" =~ ^[0-9]+$ ]] || { printf '%s\n' "$s"; return; }
  (( s == 0 )) && { echo "never"; return; }
  (( s < 60 )) && { echo "${s} s"; return; }
  if (( s < 3600 )); then
    m=$(( s / 60 ))
    if (( s % 60 == 0 )); then echo "${m} min"; else echo "${m} min $(( s % 60 )) s"; fi
    return
  fi
  h=$(( s / 3600 )); m=$(( (s % 3600) / 60 ))
  if (( m == 0 )); then echo "${h} h"; else echo "${h} h ${m} min"; fi
}

# "1" and "1.0" are the same density; printing them differently made the panel
# offer a "back to the Omarchy default" button that would have changed nothing.
canon_number() {
  local v="$1"
  [[ "$v" == *.* ]] || { printf '%s\n' "$v"; return; }
  v="${v%"${v##*[!0]}"}"   # drop trailing zeros
  v="${v%.}"               # and a bare trailing dot
  printf '%s\n' "${v:-0}"
}

# human_value <type> <unit> <scale> <display_unit> <raw>
human_value() {
  local type="$1" unit="$2" scale="$3" disp="$4" raw="$5"
  [[ -n "$raw" ]] || { echo "—"; return; }
  case "$type" in
    bool|lua-bool) [[ "$raw" == "true" ]] && echo "on" || echo "off"; return ;;
    toml-float|lua-float) raw=$(canon_number "$raw") ;;
  esac
  if [[ "$scale" == "60" ]]; then human_duration "$raw"; return; fi
  case "$unit" in
    "")  printf '%s\n' "$raw" ;;
    "×") printf '%s×\n' "$raw" ;;
    "/s") printf '%s/s\n' "$raw" ;;
    *)   printf '%s %s\n' "$raw" "${disp:-$unit}" ;;
  esac
}

# read_setting_from <entry> <file> — the same getter as get_setting_value, but
# pointed at any file. Used to read the key out of Omarchy's shipped default
# and out of the repo's saved copy, which is what makes the two revert buttons
# possible without a second parser.
# ─── One pass per file, not one process per value ───────────────────────────
# Every setting is read three times — the live file, Omarchy's default, and the
# copy in the repo — and each read forked at least one process. lua_get forked
# FOUR (two greps, a head and a sed). Twenty-four settings came to something
# like seventy processes per panel refresh, which was two thirds of the time
# `status --json` took.
#
# Each file is now parsed once, whole, into "path<TAB>value" lines, and the
# per-setting reads are lookups in a string. Parsing the whole file costs the
# same as parsing one key out of it: the process was the expense, not the work.
declare -gA FILE_MAP_CACHE=()
declare -gA FILE_MAP_LOADED=()
declare -gA SETTING_OPTIONS_CACHE=()
declare -gA SETTING_DEFAULT_FILE=()
declare -gA SETTING_REPO_FILE=()
invalidate_file_maps() { FILE_MAP_CACHE=(); FILE_MAP_LOADED=(); SETTING_OPTIONS_CACHE=(); }

# Command substitution forks, and a fork copies the caches rather than sharing
# them: a map built inside `$(file_map ...)` dies with the subshell, so the
# first version of this parsed every file on every single lookup and saved
# almost nothing. The parse therefore has to happen in the PARENT — warm_*
# below does that once, and the subshells then inherit a populated map.
#
# load_file_map is the half that may be called in the parent: it prints nothing.
load_file_map() {
  local file="$1" kind="$2" key="$1|$2"
  if [[ -z "${FILE_MAP_LOADED[$key]:-}" ]]; then
    FILE_MAP_LOADED[$key]=1
    FILE_MAP_CACHE[$key]=""
    if [[ -f "$file" ]]; then
      case "$kind" in
        json)
          # ".idle.lock<TAB>600" — the same dotted form field 4 uses.
          #
          # NOT paths(scalars): jq's path filter selects on truthiness, so a key
          # whose value is `false` produces no path and vanishes from the map.
          # A boolean setting that is genuinely off would then read as missing,
          # which is the exact bug the comment in get_setting_value warns about.
          FILE_MAP_CACHE[$key]=$(jq -r '
            paths as $p | getpath($p) as $v
            | select(($v|type) != "object" and ($v|type) != "array")
            | "." + ($p|map(tostring)|join(".")) + "\t" + ($v|tostring)
          ' "$file" 2>/dev/null || true) ;;
        toml)
          # The key charset is deliberately "anything that is not whitespace or
          # an equals sign", because that is what the greps this replaces
          # matched. shell.toml's key is `base-size`: an identifier pattern
          # dropped it, and the setting read as missing.
          FILE_MAP_CACHE[$key]=$(awk '
            /^[[:space:]]*\[/ { sect = $0; gsub(/^[[:space:]]*\[|\][[:space:]]*$/, "", sect); next }
            /^[[:space:]]*[^#=[:space:]]+[[:space:]]*=/ {
              k = $0; sub(/[[:space:]]*=.*$/, "", k); gsub(/^[[:space:]]+/, "", k)
              v = $0; sub(/^[^=]*=[[:space:]]*/, "", v); gsub(/[[:space:]]*$/, "", v)
              print (sect == "" ? k : sect "." k) "\t" v
            }' "$file" 2>/dev/null || true) ;;
        lua)
          FILE_MAP_CACHE[$key]=$(lua_settings_map "$file" 2>/dev/null || true) ;;
      esac
    fi
  fi
}

# file_map <file> <json|toml|lua> — every scalar in the file, keyed the way the
# SETTINGS registry addresses it.
file_map() {
  load_file_map "$1" "$2"
  printf '%s' "${FILE_MAP_CACHE[$1|$2]}"
}

# Parse, in this shell, every file the registry will be read from: the live one,
# Omarchy's default and the copy in the repo. The cache preserves managed-block
# precedence and lets all Lua routes in one file share the same parse.
map_kind_for_type() {
  case "$1" in
    toml-int|toml-float|ini-enum)  echo toml ;;
    number|bool|enum|string)        echo json ;;
    lua-int|lua-float|lua-bool|lua-enum|lua-string) echo lua ;;
    *)                             echo "" ;;
  esac
}
warm_setting_file_maps() {
  # File paths repeat across rows. Resolve each source once per payload.
  local entry file type kind def rel copy om
  local -a fields
  local -A seen_file=() seen_map=()
  SETTING_DEFAULT_FILE=()
  SETTING_REPO_FILE=()
  for entry in "${SETTINGS[@]}"; do
    IFS='|' read -ra fields <<<"$entry"
    file="${fields[2]}"; type="${fields[4]}"
    [[ "$file" != "-" ]] || continue
    if [[ -z "${seen_file[$file]:-}" ]]; then
      seen_file[$file]=1
      def=$(default_for_src "$file" 2>/dev/null || true)
      SETTING_DEFAULT_FILE[$file]="$def"
      rel=$(rel_for_src "$file" 2>/dev/null || true)
      copy=""
      [[ -n "$rel" ]] && copy=$(repo_copy_for_rel "$rel")
      SETTING_REPO_FILE[$file]="$copy"
    else
      def="${SETTING_DEFAULT_FILE[$file]}"
      copy="${SETTING_REPO_FILE[$file]}"
    fi
    kind=$(map_kind_for_type "$type"); [[ -n "$kind" ]] || continue
    [[ -z "${seen_map[$file|$kind]:-}" ]] || continue
    seen_map[$file|$kind]=1
    load_file_map "$file" "$kind"
    [[ -n "$def" ]] && load_file_map "$def" "$kind"
    # Omarchy's config copy can contain only comments while default/hypr has
    # the active literal values. setting_default_value checks that sibling, so
    # warm it once here instead of reparsing it for every Lua setting.
    if [[ "$type" == lua-* && "$file" == "$HOME/.config/"* ]]; then
      om="${OMARCHY_PATH:-/usr/share/omarchy}"
      rel="${file#$HOME/.config/}"
      [[ -f "$om/default/$rel" ]] && load_file_map "$om/default/$rel" "$kind"
    fi
    [[ -n "$copy" ]] && load_file_map "$copy" "$kind"
  done
}

# map_lookup <file> <kind> <key> — the value, or failure when the key is absent.
#
# The obvious spelling, map_get "$(file_map ...)" "$key", is TWO command
# substitutions and therefore two forks per read, three reads per setting,
# forty-seven settings. This is one.
map_lookup() {
  load_file_map "$1" "$2"
  local k v
  while IFS=$'\t' read -r k v; do
    [[ "$k" == "$3" ]] && { printf '%s\n' "$v"; return 0; }
  done <<<"${FILE_MAP_CACHE[$1|$2]}"
  return 1
}

# fontconfig_family <file> — the monospace family omarchy font set recorded
# in a fontconfig drop-in: the <string> inside the <edit> block. The match
# block also carries a <string> (monospace), so the whole file is not grepped.
fontconfig_family() {
  local file="$1" fam
  [[ -f "$file" ]] || return 1
  fam=$(awk '/<edit/,/<\/edit>/ { if (match($0, /<string>[^<]*<\/string>/)) { s = substr($0, RSTART, RLENGTH); gsub(/<\/?string>/, "", s); print s; exit } }' "$file" || true)
  [[ -n "$fam" ]] || return 1
  printf '%s\n' "$fam"
}
read_setting_from() {
  local entry="$1" file="$2" path="${3:-}" type="${4:-}" raw
  [[ -n "$path" ]] || path=$(setting_field "$entry" 4)
  [[ -n "$type" ]] || type=$(setting_field "$entry" 5)
  [[ -f "$file" ]] || return 1
  case "$type" in
    line-enum)
      raw=$(head -n1 "$file" 2>/dev/null | tr -d '[:space:]')
      [[ -n "$raw" ]] && printf '%s\n' "$raw" || return 1 ;;
    toml-int|toml-float|ini-enum)
      raw=$(map_lookup "$file" toml "$path") || return 1
      [[ -n "$raw" ]] && printf '%s\n' "$raw" || return 1 ;;
    lua-int|lua-float|lua-bool|lua-enum|lua-string)
      lua_file_value "$file" "$path" ;;
    number|bool|enum|string)
      raw=$(map_lookup "$file" json "$path") || return 1
      [[ "$raw" == "null" ]] && return 1
      printf '%s\n' "$raw" ;;
    font)
      fontconfig_family "$file" ;;
    *) return 1 ;;
  esac
}

# The value this setting would have on a machine that had never been touched.
# Read out of the file Omarchy actually ships where there is one; otherwise the
# registry's `fallback`, which is the shell's own built-in default. A current
# Hyprland value can describe the current session, but cannot describe what
# Omarchy ships, so it is never a default fallback.
setting_default_value() {
  # A supplied entry uses the source paths prepared by warm_setting_file_maps.
  local entry="${2:-}" file def type path fallback
  [[ -n "$entry" ]] || entry=$(find_setting "$1") || return 1
  if [[ -n "${2:-}" ]]; then
    file="$3"; path="$4"; type="$5"; fallback="$6"
  else
    file=$(setting_field "$entry" 3)
    type=$(setting_field "$entry" 5)
    path=$(setting_field "$entry" 4)
    fallback=$(setting_field "$entry" 13)
  fi
  if [[ "$file" != "-" ]]; then
    if [[ -n "${2:-}" ]]; then def="${SETTING_DEFAULT_FILE[$file]:-}"
    else def=$(default_for_src "$file" 2>/dev/null || true); fi
    if [[ -n "$def" ]]; then
      if cand=$(read_setting_from "$entry" "$def" "$path" "$type" 2>/dev/null); then
        if [[ "$type" == lua-enum ]]; then
          opts=$(setting_options "$entry" 2>/dev/null || true)
          if [[ -n "$opts" && "$opts" != "@x11-layouts" ]]; then
            [[ ",$opts," == *",$cand,"* ]] || cand=""
          fi
        fi
        [[ -n "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
      fi
      # default_for_src returns the commented config file for hypr/*.lua,
      # whose real values live under default/hypr/. Try that sibling too.
      if [[ "$type" == lua-* ]]; then
        local om="${OMARCHY_PATH:-/usr/share/omarchy}"
        # shellcheck disable=SC2295  # $HOME has no glob characters here
        local rel="${file#$HOME/.config/}"
        if [[ "$rel" != "$file" && -f "$om/default/$rel" ]]; then
          if cand=$(read_setting_from "$entry" "$om/default/$rel" "$path" "$type" 2>/dev/null); then
            if [[ "$type" == lua-enum ]]; then
              opts=$(setting_options "$entry" 2>/dev/null || true)
              if [[ -n "$opts" && "$opts" != "@x11-layouts" ]]; then
                [[ ",$opts," == *",$cand,"* ]] || cand=""
              else
                # kb_layout in the default file is a Lua variable
                # (kb_layout = kb_layout), not a literal layout code.
                [[ "$cand" == "kb_layout" || "$cand" == "kb_variant" || "$cand" == "kb_options" ]] && cand=""
              fi
            elif [[ "$type" == lua-string ]]; then
              # The default file carries Lua variables (kb_variant = kb_variant),
              # not literals. A bare variable name is not a default value.
              [[ "$cand" == "kb_variant" || "$cand" == "kb_options" || "$cand" == "kb_layout" ]] && cand=""
            fi
            [[ -n "$cand" ]] && { printf '%s\n' "$cand"; return 0; }
          fi
        fi
      fi
    fi
  fi
  [[ -n "$fallback" ]] && { printf '%s\n' "$fallback"; return 0; }
  # The active compositor value is useful for the current-value display. It is
  # never an Omarchy default: an override must not remove or invent a reset.
  return 1
}

# The value saved in the user's own repo — "what my other machine has".
setting_repo_value() {
  local entry="${2:-}" file type path rel copy
  [[ -n "$entry" ]] || entry=$(find_setting "$1") || return 1
  if [[ -n "${2:-}" ]]; then
    file="$3"; path="$4"; type="$5"
  else
    file=$(setting_field "$entry" 3)
    path=$(setting_field "$entry" 4)
    type=$(setting_field "$entry" 5)
  fi
  [[ "$type" == theme ]] && file="$HOME/.local/state/omarchy/current/theme.name"
  [[ "$file" != "-" ]] || return 1
  if [[ -n "${2:-}" && "$type" != theme ]]; then
    copy="${SETTING_REPO_FILE[$file]:-}"
    [[ -n "$copy" ]] || return 1
  else
    rel=$(rel_for_src "$file") || return 1
    copy=$(repo_copy_for_rel "$rel")
  fi
  if [[ "$type" == theme ]]; then
    head -n1 "$copy" 2>/dev/null | tr -d '\r'
    return "${PIPESTATUS[0]}"
  fi
  read_setting_from "$entry" "$copy" "$path" "$type"
}

# setting_save_id <id>: the one tracked entry that owns this setting's file.
# The active theme uses its tracked theme-name file. Other settings use the
# registry's live-path mapping, which also resolves profile-scoped copies.
setting_save_id() {
  local entry type file rel row
  entry=$(find_setting "$1") || return 1
  type=$(setting_field "$entry" 5)
  file=$(setting_field "$entry" 3)
  [[ "$type" == theme ]] && file="$HOME/.local/state/omarchy/current/theme.name"
  [[ "$file" != "-" ]] || return 1
  rel=$(rel_for_src "$file") || return 1
  registry_build || return 1
  row=$(registry_row_for "$rel") || return 1
  [[ "$(registry_field "$row" 2)" == config ]] || return 1
  printf '%s\n' "$rel"
}

setting_value_saved() {
  local entry type live repo live_norm repo_norm
  entry=$(find_setting "$1") || return 1
  type=$(setting_field "$entry" 5)
  repo=$(setting_repo_value "$1") || return 1
  live="$2"
  if [[ "$type" == theme ]]; then
    live_norm=$(tr -cd '[:alnum:]' <<<"${live,,}")
    repo_norm=$(tr -cd '[:alnum:]' <<<"${repo,,}")
    [[ -n "$live_norm" && "$live_norm" == "$repo_norm" ]]
  elif [[ "$type" == font ]]; then
    live_norm=$(tr -cd '[:alnum:]' <<<"${live,,}")
    repo_norm=$(tr -cd '[:alnum:]' <<<"${repo,,}")
    [[ -n "$live_norm" && "$live_norm" == "$repo_norm" ]]
  else
    [[ "$repo" == "$live" ]]
  fi
}

# core_revert <id> <default|repo> — put one setting back without touching the
# rest of the file it lives in. The whole-file equivalents (`reset`, `restore`)
# are still there; this is the small, everyday one.
core_revert() {
  require_ready_schema || return 1
  local id="$1" to="${2:-default}" value
  # Say which of the two things is wrong. Both failures below assume the id is
  # real, so an id that is not reported "no Omarchy default known for
  # nope.setting" — which reads as a fact about a setting that does not exist.
  find_setting "$id" >/dev/null || { echo "unknown setting: $id" >&2; return 1; }
  case "$to" in
    default) value=$(setting_default_value "$id") || { echo "no Omarchy default known for $id" >&2; return 1; } ;;
    repo)    value=$(setting_repo_value "$id")    || { echo "$id is not saved in your repo yet" >&2; return 1; } ;;
    *)       echo "revert: --to must be 'default' or 'repo'" >&2; return 1 ;;
  esac
  set_setting_value "$id" "$value"
}

# Numbers the panel can show without the user doing arithmetic. `value` stays
# the stored value (what the CLI reads and writes); `display_*` is the same
# quantity in the unit a person thinks in, and `value_text` is the exact
# current value written out in full, which is what the Overview table shows.
settings_display_step() {
  local scale="$1" dmax="$2" unit="$3"
  if [[ "$scale" != "1" && -n "$scale" ]]; then
    if [[ -n "$dmax" ]] && (( dmax > 60 )); then echo 5; else echo 1; fi
  elif [[ "$unit" == "ms" ]]; then echo 50
  else echo 1
  fi
}

build_settings_json() {
  local prior_refresh="${REPLICANT_SETTINGS_REFRESH-}" had_prior_refresh=0
  [[ -v REPLICANT_SETTINGS_REFRESH ]] && had_prior_refresh=1
  export REPLICANT_SETTINGS_REFRESH=1
  invalidate_file_maps
  warm_setting_file_maps
  # One jq invocation for the whole array, not one per setting. The panel polls
  # status once a minute and refreshes after every write, and forty-odd `jq -n`
  # spawns per build were most of the time that took.
  local entry id group file path type label unit min max options hint value available fallback implicit
  local domain apply mrel mscope _tre
  local scale disp step dvalue dmin dmax dstep vtext defval deftext repoval repotext canrd canrr numeric boolean
  local lnotice inforce by blocked
  local dim_inactive_val="" blur_val="" layout_val=""
  local shadow_val="" glow_val="" snap_val="" anims_val="" groupbar_val=""
  {
  local laptop=1; is_laptop || laptop=0
  local -a F
  for entry in "${SETTINGS[@]}"; do
    # Split the line ONCE. Each setting_field call is a command substitution,
    # which is a fork, and sixteen of them per setting across forty-odd
    # settings would be hundreds of forks to read a string this shell already had.
    IFS='|' read -ra F <<<"$entry"
    id="${F[0]}";        group="${F[1]}"
    # A desktop has no lid. The group is absent rather than greyed out.
    [[ "$group" == "Lid & sleep" && "$laptop" == 0 ]] && continue
    file="${F[2]}";      path="${F[3]}"
    apply="${F[11]:-}"
    # The domain is the top-level Settings section the group belongs to. A
    # case, not a helper call: each command substitution is a fork, and this
    # loop already paid hundreds of them once. Nothing maps to Desktop yet:
    # workspace and display editors arrive in a later phase.
    case "$group" in
      "Idle & power"|"Lid & sleep") domain="Power" ;;
      "Appearance"|"Windows") domain="Look & feel" ;;
      "Keyboard"|"Mouse & pointer"|"Touchpad") domain="Input" ;;
      "Defaults") domain="Defaults" ;;
      *) domain="$group" ;;
    esac
    type="${F[4]}";      label="${F[5]}"
    unit="${F[6]}";      min="${F[7]}"
    max="${F[8]}";       hint="${F[10]}"
    fallback="${F[12]:-}"
    scale="${F[13]:-}";  disp="${F[14]:-}"; step="${F[15]:-}"
    [[ -n "$scale" ]] || scale=1
    [[ -n "$disp" ]] || disp="$unit"
    case "$type" in
      theme|font) options=$(setting_options "$entry") ;;
      *)
        options="${F[9]:-}"
        [[ "$options" == "@x11-layouts" ]] && options=$(setting_options "$entry")
        ;;
    esac
    value=""; value_found=false
    if value=$(get_setting_value "$id" "$entry" "$file" "$path" "$type" 2>/dev/null); then value_found=true; else value=""; fi
    implicit=false
    # The Hyprland value in force when the option is not written anywhere.
    # Tried before the registry fallback: the session already merges Omarchy's
    # defaults, so its answer beats the wiki default the fallback records.
    if [[ -z "$value" && "$type" == lua-* && -n "$path" ]]; then
      if inforce_tmp=$(hypr_in_force "$path" 2>/dev/null); then
        # bool normalisation (hypr may report 1/0)
        if [[ "$type" == lua-bool ]]; then
          [[ "$inforce_tmp" == 1 ]] && inforce_tmp=true
          [[ "$inforce_tmp" == 0 ]] && inforce_tmp=false
        fi
        # enum guard: only accept what this machine offers
        if [[ "$type" == lua-enum && -n "$options" && "$options" != "@x11-layouts" ]]; then
          [[ ",$options," == *",$inforce_tmp,"* ]] || inforce_tmp=""
        elif [[ "$type" == lua-enum && "$options" == "@x11-layouts" ]]; then
          : # dynamic list checked below via shape; accept for now
        fi
        if [[ "$type" == lua-float ]]; then
          inforce_tmp=$(canon_number "$inforce_tmp" 2>/dev/null || printf '%s' "$inforce_tmp")
        fi
        if [[ -n "$inforce_tmp" ]]; then value="$inforce_tmp"; implicit=true; fi
      fi
    fi
    if [[ -z "$value" && -n "$fallback" ]]; then value="$fallback"; implicit=true; fi
    # A free Hyprland string distinguishes "not set" (missing) from "none"
    # (set to ""): an empty variant is a valid answer, and the control must
    # stay usable so one can be added. Every other empty value stays missing.
    if [[ -n "$value" ]]; then available=true
    elif [[ "$value_found" == true && "$type" == "lua-string" ]]; then available=true
    else available=false; fi

    # Shape check per type — a malformed value is "not available", never a
    # control bound to a value it cannot render.
    numeric=false; boolean=false
    case "$type" in
      number|toml-int|lua-int)
        numeric=true; [[ "$value" =~ ^-?[0-9]+$ ]] || { value=""; available=false; } ;;
      toml-float|lua-float)
        numeric=true; [[ "$value" =~ ^-?[0-9]*\.?[0-9]+$ ]] || { value=""; available=false; } ;;
      bool|lua-bool)
        boolean=true; [[ "$value" == "true" || "$value" == "false" ]] || { value="false"; available=false; } ;;
      lua-enum)
        if [[ -n "$value" && -n "$options" && "$options" != "@x11-layouts" ]]; then
          [[ ",$options," == *",$value,"* ]] || { value=""; available=false; }
        fi ;;
    esac

    dvalue=""; dmin=""; dmax=""; dstep=""
    if [[ "$numeric" == true ]]; then
      if [[ "$scale" == "1" ]]; then
        dvalue="$value"; dmin="$min"; dmax="$max"
      else
        [[ -n "$value" ]] && dvalue=$(( (value + scale / 2) / scale ))
        [[ -n "$min" ]] && dmin=$(( (min + scale - 1) / scale ))
        [[ -n "$max" ]] && dmax=$(( max / scale ))
      fi
      if [[ -n "$step" ]]; then dstep="$step"
      else dstep=$(settings_display_step "$scale" "$dmax" "$unit"); fi
    else
      # Non-numeric rows still carry a step for the QML slider (floats).
      if [[ -n "$step" ]]; then dstep="$step"; else dstep=1; fi
    fi

    vtext=$(human_value "$type" "$unit" "$scale" "$disp" "$value")
    defval=$(setting_default_value "$id" "$entry" "$file" "$path" "$type" "$fallback" 2>/dev/null) || defval=""
    repoval=$(setting_repo_value "$id" "$entry" "$file" "$path" "$type" 2>/dev/null) || repoval=""
    deftext=$(human_value "$type" "$unit" "$scale" "$disp" "$defval")
    repotext=$(human_value "$type" "$unit" "$scale" "$disp" "$repoval")
    # Compare the rendered text, not the raw string: shell.toml holding "1" and
    # a fallback of "1.0" are the same density, and offering a revert button
    # that would change nothing is worse than offering none.
    canrd=false; canrr=false
    [[ -n "$defval"  && "$deftext"  != "$vtext" && "$available" == true ]] && canrd=true
    [[ -n "$repoval" && "$repotext" != "$vtext" && "$available" == true ]] && canrr=true

    # Remember dependency drivers as they pass: the dependents follow in
    # registry order (dimInactive before dimStrength, blur before blurSpecial,
    # layout before columnWidth).
    case "$id" in
      window.dimInactive) dim_inactive_val="$value" ;;
      window.blur) blur_val="$value" ;;
      window.layout) layout_val="$value" ;;
      window.shadows) shadow_val="$value" ;;
      window.glowEnabled) glow_val="$value" ;;
      window.snapEnabled) snap_val="$value" ;;
      window.animations) anims_val="$value" ;;
      window.groupbarEnabled) groupbar_val="$value" ;;
    esac
    blocked=""
    case "$id" in
      window.dimStrength)
        [[ "$dim_inactive_val" != "true" ]] && blocked="Turn on Dim inactive windows to use dim strength." ;;
      window.blurSpecial)
        [[ "$blur_val" != "true" ]] && blocked="Turn on Blur to use the special workspace blur." ;;
      window.blurSize|window.blurPasses|window.blurNoise|window.blurContrast|window.blurBrightness|window.blurVibrancy|window.blurVibrancyDarkness|window.blurPopups|window.blurXray)
        [[ "$blur_val" != "true" ]] && blocked="Turn on Blur to use this blur control." ;;
      window.shadowRange|window.shadowPower|window.shadowScale|window.shadowSharp)
        [[ "$shadow_val" != "true" ]] && blocked="Turn on Window shadows to use this shadow control." ;;
      window.glowRange|window.glowPower)
        [[ "$glow_val" != "true" ]] && blocked="Turn on Window glow to use this glow control." ;;
      window.snapWindowGap|window.snapMonitorGap|window.snapBorderOverlap)
        [[ "$snap_val" != "true" ]] && blocked="Turn on Window snapping to use this snapping control." ;;
      window.animWrap)
        [[ "$anims_val" != "true" ]] && blocked="Turn on Animations to use workspace wraparound." ;;
      window.columnWidth)
        [[ "$layout_val" != "scrolling" ]] && blocked="Switch Window layout to scrolling to use column width." ;;
      window.dwindleBias|window.dwindleForceSplit|window.dwindlePreserveSplit|window.dwindleSmartSplit|window.dwindleSplitMultiplier)
        [[ "$layout_val" != "dwindle" ]] && blocked="Switch Window layout to dwindle to use this control." ;;
      window.masterFactor|window.masterNewStatus|window.masterOrientation)
        [[ "$layout_val" != "master" ]] && blocked="Switch Window layout to master to use this control." ;;
      window.groupbarHeight|window.groupbarIndicatorGap|window.groupbarIndicatorHeight|window.groupbarTitles|window.groupbarRounding|window.groupbarGradients|window.groupbarStacked|window.groupbarFontSize)
        [[ "$groupbar_val" != "true" ]] && blocked="Turn on Group bar to use this group control." ;;
    esac

    # Hyprland is asked, not the file. These controls write input.lua and
    # looknfeel.lua, and a module loaded after them that sets the same route
    # wins: OmaSettings keeps its pages in hypr/omasettings.lua, loaded last.
    # Said only when Hyprland answers, and only when the two differ.
    lnotice=""
    if [[ "$type" == lua-* && "$available" == true && -z "$blocked" ]] && inforce=$(hypr_in_force "$path" 2>/dev/null); then
      if [[ "$type" == lua-bool ]]; then
        [[ "$inforce" == 1 ]] && inforce=true
        [[ "$inforce" == 0 ]] && inforce=false
      fi
      # floats: "1" and "1.0" are the same value
      if [[ "$type" == lua-float ]]; then
        inforce=$(canon_number "$inforce" 2>/dev/null || printf '%s' "$inforce")
        vcanon=$(canon_number "$value" 2>/dev/null || printf '%s' "$value")
      else
        vcanon="$value"
      fi
      if [[ "$inforce" != "$vcanon" ]]; then
        by=$(hypr_overrider "$path" "$file") || by="a file loaded later"
        lnotice="In force: $(human_value "$type" "$unit" "$scale" "$disp" "$inforce") — set by $by."
      fi
    fi

    # A per-device rule inside the same file wins for that device.
    # Replicant never modifies hl.device rules; it only names the fact,
    # never the private hardware.
    if [[ -z "$lnotice" && -z "$blocked" && "$type" == lua-* && "$available" == true && -n "$file" ]]; then
      leaf=$(lua_key_of "$path")
      if hypr_device_override "$file" "$leaf" 2>/dev/null; then
        lnotice="A per-device rule also sets this value and wins for that device."
      fi
    fi

    # A scope of off is policy, not failure, but the row must say so before the
    # person touches the control. Without this the change applies locally and the
    # save step warns afterwards, which reads as a surprise error.
    # Owner and scope metadata for the panel: which Configs row owns this
    # file, and what scope that row carries. Untracked files and file-less
    # types carry empty strings, never a guessed scope. Inline loops, not
    # rel_for_src/scope_for calls: each one is a fork, and this runs per row.
    mrel=""; mscope=""
    if [[ "$file" != "-" ]]; then
      for _tre in "${TRACKED[@]}" "${TRACKED_SECRETS[@]}"; do
        [[ "${_tre%%:*}" == "$file" ]] && { mrel="${_tre##*:}"; break; }
      done
      if [[ -n "$mrel" ]]; then
        load_scope_map
        mscope="${SCOPE_OF[$mrel]:-shared}"
      fi
    fi
    if [[ -z "$lnotice" && -z "$blocked" && -n "$mrel" && "$mscope" == "off" && "$available" == true ]]; then
      lnotice="Applies locally only — $mrel is off. Set it to Shared to save it."
    fi

    printf '%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\x1f%s\n' \
      "$id" "$group" "$label" "$type" "$unit" "$min" "$max" "$options" "$hint" "$file" \
      "$available" "$implicit" "$value" "$scale" "$disp" "$dvalue" "$dmin" "$dmax" "$dstep" \
      "$vtext" "$defval" "$deftext" "$repoval" "$repotext" "$canrd" "$canrr" "$numeric" "$boolean" \
      "$lnotice" "$blocked" "$domain" "$mrel" "$mscope" "$apply"
  done
  } | jq -Rsc '
    def num: if . == "" then null else (tonumber? // null) end;
    def flag: . == "true";
    split("\n") | map(select(length > 0) | split("\u001f") | {
      id: .[0], group: .[1], label: .[2], type: .[3], unit: .[4],
      min: (.[5]|num), max: (.[6]|num),
      options: (if .[7] == "" then [] else (.[7]|split(",")) end),
      hint: .[8], file: .[9],
      available: (.[10]|flag), implicit: (.[11]|flag),
      value: (if (.[27]|flag) then (.[12] == "true")
              elif (.[26]|flag) then (.[12]|num)
              else .[12] end),
      scale: (.[13]|num), display_unit: .[14],
      display_value: (.[15]|num), display_min: (.[16]|num),
      display_max: (.[17]|num), display_step: (.[18]|num),
      value_text: .[19],
      default_value: .[20], default_text: .[21],
      repo_value: .[22], repo_text: .[23],
      can_revert_default: (.[24]|flag), can_revert_repo: (.[25]|flag),
      lua_notice: (.[28] // ""),
      blocked_reason: (.[29] // ""),
      domain: .[30], entry: .[31], scope: .[32], apply_action: .[33]
    })' | jq -c --arg lidblock "$(lid_blocked_by)" '
    # A second pass, because a notice is about how settings sit RELATIVE to each
    # other and the per-setting record cannot see its siblings.
    #
    # Exactly one rule, on purpose. A screensaver set at or after the lock timer
    # can never appear — the setting silently does nothing, which is worth
    # saying. The other orderings people assume are wrong are not: a display that
    # sleeps long before the lock is a normal power choice, and suspending before
    # the lock timer is fine because Omarchy locks on suspend. Warning about
    # those fires on a perfectly good config and teaches people to ignore
    # notices, which costs more than it saves.
    #
    # A notice, never a refusal. A deliberate 0 ("never") is a real answer.
    def val($id): [ .[] | select(.id == $id) | .value ][0];
    (val("idle.screensaver")) as $ss
    | (val("idle.lock")) as $lock
    | map(. + { notice: (
        if .id == "idle.screensaver" and ($ss != null and $lock != null and $lock > 0 and $ss >= $lock)
          then "The screen locks first, so this screensaver never appears."
        # Not a warning about how you configured it — a statement that what you
        # configured is not what happens. Something else is holding the lid
        # switch and logind is ignoring this file.
        elif (.id | startswith("lid.")) and $lidblock != ""
          # Two lines of about 34 characters is what the row gives it, so the
          # sentence has to fit in ~66 — the first attempt said the same thing
          # in 91 and lost "does nothing" to the ellipsis, which was the half
          # worth reading.
          then "Overridden by \($lidblock) — the lid does nothing."
        # The same statement about Hyprland: what the session uses is not what
        # the file says (see lnotice above).
        elif .lua_notice != "" then .lua_notice
        else "" end) } | del(.lua_notice))'
  local rc=$?
  if (( had_prior_refresh )); then export REPLICANT_SETTINGS_REFRESH="$prior_refresh"
  else unset REPLICANT_SETTINGS_REFRESH
  fi
  return "$rc"
}

# lid_blocked_by — who, if anyone, is holding a `block` inhibitor on the lid
# switch. Empty when nobody is.
#
# This exists because the panel was telling a confident lie. It reported
# lid.close by reading /etc/systemd/logind.conf.d/99-lid.conf — the file it
# writes itself — while a plugin (Omarchy Sleepwalker) held a block inhibitor
# that makes logind ignore the lid entirely. The config said
# "suspend-then-hibernate"; closing the lid did nothing at all.
#
# Same shape as the bug that opened this whole line of work: answering a
# question about the SYSTEM by reading the ARTIFACT you wrote. A `delay`
# inhibitor is not this — those are normal and transient (NetworkManager and
# UPower each hold one). Only `block` overrides the setting.
lid_blocked_by() {
  # WHO is free text and often contains spaces ("Omarchy Sleepwalker"), so it
  # is neither $1 nor a greedy regex — both got it wrong. Between WHO and WHAT
  # there are exactly four columns (UID USER PID COMM), so WHO is everything
  # up to five fields before the one reading handle-lid-switch.
  # An inhibitor may hold SEVERAL whats at once, and systemd prints them
  # colon-joined in one column: `sleep:idle:handle-lid-switch`. Testing the
  # field for equality missed every one of those — it only ever matched a holder
  # that wanted the lid and nothing else.
  systemd-inhibit --list --no-pager 2>/dev/null | awk '
    $NF == "block" {
      for (i = 1; i <= NF; i++) if ($i ~ /(^|:)handle-lid-switch(:|$)/) {
        who = ""
        for (j = 1; j <= i - 5; j++) who = who (j > 1 ? " " : "") $j
        if (who != "") { print who; exit }
      }
    }'
}

build_setting_groups_json() {
  local entries=() entry
  local laptop=1; is_laptop || laptop=0
  for entry in "${SETTING_GROUPS[@]}"; do
    [[ "${entry%%|*}" == "Lid & sleep" && "$laptop" == 0 ]] && continue
    entries+=("$(jq -nc --arg name "$(printf '%s' "$entry" | cut -d'|' -f1)" \
      --arg icon "$(printf '%s' "$entry" | cut -d'|' -f2)" \
      --arg description "$(printf '%s' "$entry" | cut -d'|' -f3)" \
      '{name:$name,icon:$icon,description:$description}')")
  done
  printf '%s\n' "${entries[@]}" | jq -s '.'
}
