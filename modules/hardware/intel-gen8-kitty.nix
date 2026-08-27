{ config, pkgs, lib, ... }:

# ─── Why kitty could not open a native Wayland window on cerf ───────────────
#
# Symptom:
#     [glfw error 65542]: EGL: No EGLConfigs returned
#     [glfw error 65545]: EGL: Failed to find a suitable EGLConfig
#     OSError: Failed to create GLFWwindow. This usually happens because of
#     old/broken OpenGL drivers. kitty requires working OpenGL 3.1 drivers.
#
# The old workaround was `linux_display_server x11`, blamed on "Mesa 26.2
# failing Wayland-EGL config negotiation". That diagnosis was wrong, and the
# real chain was measured end to end on cerf:
#
#  1. Mesa is fine. `eglinfo` on the Wayland platform reports
#     "OpenGL core profile version: 4.6 (Core Profile) Mesa 26.2.1" on
#     Mesa Intel(R) HD Graphics 5500 (BDW GT2). Desktop GL over Wayland-EGL
#     works.
#
#  2. But the Wayland platform publishes 80 EGLConfigs and EVERY ONE of them
#     has EGL_ALPHA_SIZE == 0. Enumerated directly via eglGetConfigs: the
#     only pixel formats present are RGB565, RGB888, RGB10 and RGB16F — no
#     ARGB8888 at all. Replaying kitty's own eglChooseConfig attribute list
#     confirms it: with alpha requested → 0 matches; drop the alpha
#     requirement and the identical query returns 40.
#
#  3. Those configs come from what the COMPOSITOR advertises. Hyprland's
#     zwp_linux_dmabuf_v1 on this machine offers exactly
#     RG16 XB24 XB30 XB4H XR24 XR30 — all opaque.
#
#  4. Which in turn comes from the hardware. `modetest -M i915 -p` shows this
#     Broadwell primary plane's format list as
#     "C8 RG16 XR24 XB24 XR30 XB30 XB4H". Gen8 Intel primary planes have no
#     per-pixel-alpha scanout format, so ARGB8888 simply is not there, and
#     the dmabuf list is that list.
#
#  5. kitty's bundled GLFW asks for EGL_ALPHA_SIZE 8 UNCONDITIONALLY.
#     glfw/egl_context.c's chooseEGLConfig emits
#     `if (desired->alphaBits > 0) ATTR(EGL_ALPHA_SIZE, desired->alphaBits);`
#     and kitty never lowers GLFW's default alphaBits of 8 — it only sets
#     GLFW_TRANSPARENT_FRAMEBUFFER from background_opacity, which is a
#     different hint. That is why setting background_opacity 1.0 changed
#     nothing when it was tried. Upstream kitty (checked against master) has
#     no fallback for this case.
#
# So: an opaque-only compositor format list meets a client that always demands
# alpha, and the window is never created. Xwayland dodged it because GLX
# picks a visual instead of going through Wayland's dmabuf format list.
#
# The fix is the obvious one upstream is missing: if the config search comes
# back empty AND alpha was requested, retry once without the alpha
# requirement. On any normal machine the first query succeeds and this code
# never runs, so it is safe to carry.
#
# The cost is that kitty on this machine has an opaque background — there is
# no ARGB framebuffer to be had, so background_opacity cannot work here on
# native Wayland no matter what. That is the trade for a real Wayland surface
# (correct scaling, correct input, no Xwayland round-trip).
#
# Building this means kitty is compiled from source rather than substituted
# (roughly 10 minutes on this dual-core i5-5300U). To avoid that, build it on
# turing and push it over:
#     nix build ~/mixos#nixosConfigurations.cerf.pkgs.kitty
#     nix copy --to ssh://cerf ./result

{
  nixpkgs.overlays = [
    (final: prev: {
      kitty = prev.kitty.overrideAttrs (old: {
        patches = (old.patches or [ ]) ++ [ ../../packages/kitty-egl-alpha-fallback.patch ];
      });
    })
  ];
}
