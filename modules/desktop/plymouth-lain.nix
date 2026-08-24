# Two-phase Serial Experiments Lain Plymouth theme: a static logo during
# normal boot, and a TV-static-style animation (looping frames from
# hyprlain-src's TV_Lain.gif) while Plymouth is actually waiting on input —
# i.e. exactly when it's showing the LUKS passphrase prompt.
#
# This is a fork of Stylix's plymouth theme script (upstream:
# danth/stylix, modules/plymouth/theme-script.nix) rather than a
# from-scratch theme, since that script is the one that's already proven to
# render the LUKS prompt correctly on this encrypted system (see the comment
# in modules/core/boot.nix). We keep its password/question/message handling
# verbatim and only replace the logo/spinner half with the static->TV-static
# swap. Stylix's own plymouth target is disabled in favour of this theme
# (see stylix.targets.plymouth.enable = false in each host's boot.nix).
{ pkgs, inputs, ... }:
let
  assets = "${inputs.hyprlain-src}/src/hyprland/src/assets/media";
  logoSrc = "${assets}/imgs/lainsmall2.png";
  tvStaticGif = "${assets}/anim/TV_Lain.gif";

  # Colors from hosts/turing/lain-base16.yaml (identical on cerf), as 0-1
  # decimal RGB triples the way Plymouth's script language expects them.
  # base00 (background, pure black) and base05 (foreground, Lain tan).
  backgroundColor = "0.0, 0.0, 0.0";
  foregroundColor = "0.757, 0.706, 0.557";

  # Verified via `identify TV_Lain.gif`: 6 frames, 700x700. Update this if
  # the upstream asset ever changes.
  tvStaticFrameCount = 6;

  tvStaticFrames = pkgs.runCommand "lain-tv-static-frames"
    { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    mkdir -p $out
    convert -coalesce -background black -alpha remove -alpha off \
      -resize 260x \
      ${tvStaticGif} $out/frame-%d.png
  '';

  themeScript = builtins.toFile "lain-plymouth-theme" ''
    center_x = Window.GetWidth() / 2;
    center_y = Window.GetHeight() / 2;
    baseline_y = Window.GetHeight() * 0.9;
    message_y = Window.GetHeight() * 0.75;

    ### BACKGROUND ###

    Window.SetBackgroundTopColor(${backgroundColor});
    Window.SetBackgroundBottomColor(${backgroundColor});

    ### LOGO (static, no spin) ###

    logo.image = Image("logo.png");
    logo.sprite = Sprite(logo.image);
    logo.sprite.SetPosition(
      center_x - (logo.image.GetWidth() / 2),
      center_y - (logo.image.GetHeight() / 2),
      1
    );

    ### TV STATIC (looping frames, shown only while waiting on input) ###

    tv.frame_count = ${toString tvStaticFrameCount};
    for (tv.i = 0; tv.i < tv.frame_count; tv.i++) {
      tv.image[tv.i] = Image("frame-" + tv.i + ".png");
    }
    tv.sprite = Sprite();
    tv.sprite.SetPosition(
      center_x - (tv.image[0].GetWidth() / 2),
      center_y - (tv.image[0].GetHeight() / 2),
      2
    );
    tv.sprite.SetOpacity(0);
    tv.active = 0;
    tv.index = 0;
    tv.tick = 0;

    fun activate_tv_static () {
      tv.active = 1;
      logo.sprite.SetOpacity(0);
      tv.sprite.SetOpacity(1);
    }

    fun deactivate_tv_static () {
      tv.active = 0;
      tv.sprite.SetOpacity(0);
      logo.sprite.SetOpacity(1);
    }

    fun refresh_callback () {
      if (tv.active) {
        tv.tick = (tv.tick + 1) % 3;
        if (tv.tick == 0) {
          tv.index = (tv.index + 1) % tv.frame_count;
          tv.sprite.SetImage(tv.image[tv.index]);
        }
      }
    }

    Plymouth.SetRefreshFunction(refresh_callback);

    ### PASSWORD ###

    prompt = null;
    bullets = null;
    bullet.image = Image.Text("•", ${foregroundColor});

    fun password_callback (prompt_text, bullet_count) {
      activate_tv_static();

      prompt.image = Image.Text(prompt_text, ${foregroundColor});
      prompt.sprite = Sprite(prompt.image);
      prompt.sprite.SetPosition(
        center_x - (prompt.image.GetWidth() / 2),
        baseline_y - prompt.image.GetHeight(),
        3
      );

      total_width = bullet_count * bullet.image.GetWidth();
      start_x = center_x - (total_width / 2);

      bullets = null;
      for (i = 0; i < bullet_count; i++) {
          bullets[i].sprite = Sprite(bullet.image);
          bullets[i].sprite.SetPosition(
            start_x + (i * bullet.image.GetWidth()),
            baseline_y + bullet.image.GetHeight(),
            3
          );
      }
    }

    Plymouth.SetDisplayPasswordFunction(password_callback);

    ### QUESTION ###

    question = null;
    answer = null;

    fun question_callback(prompt_text, entry) {
        activate_tv_static();

        question = null;
        answer = null;

        question.image = Image.Text(prompt_text, ${foregroundColor});
        question.sprite = Sprite(question.image);
        question.sprite.SetPosition(
            center_x - (question.image.GetWidth() / 2),
            baseline_y - question.image.GetHeight(),
            3
        );

        answer.image = Image.Text(entry, ${foregroundColor});
        answer.sprite = Sprite(answer.image);
        answer.sprite.SetPosition(
            center_x - (answer.image.GetWidth() / 2),
            baseline_y + answer.image.GetHeight(),
            3
        );
    }

    Plymouth.SetDisplayQuestionFunction(question_callback);

    ### MESSAGE ###

    message = null;

    fun message_callback(text) {
        message.image = Image.Text(text, ${foregroundColor});
        message.sprite = Sprite(message.image);
        message.sprite.SetPosition(
            center_x - message.image.GetWidth() / 2,
            message_y,
            3
        );
    }

    Plymouth.SetMessageFunction(message_callback);

    ### NORMAL ###

    fun normal_callback() {
        prompt = null;
        bullets = null;

        question = null;
        answer = null;

        message = null;

        deactivate_tv_static();
    }

    Plymouth.SetDisplayNormalFunction(normal_callback);

    ### QUIT ###

    fun quit_callback() {
      prompt = null;
      bullets = null;
      deactivate_tv_static();
    }

    Plymouth.SetQuitFunction(quit_callback);
  '';

  theme = pkgs.runCommand "lain-plymouth" { nativeBuildInputs = [ pkgs.imagemagick ]; } ''
    themeDir="$out/share/plymouth/themes/lain"
    mkdir -p "$themeDir"

    convert -background transparent ${logoSrc} "$themeDir/logo.png"
    cp ${tvStaticFrames}/frame-*.png "$themeDir/"
    cp ${themeScript} "$themeDir/lain.script"

    echo "
    [Plymouth Theme]
    Name=Lain
    ModuleName=script

    [script]
    ImageDir=$themeDir
    ScriptFile=$themeDir/lain.script
    " > "$themeDir/lain.plymouth"
  '';
in
{
  stylix.targets.plymouth.enable = false;

  boot.plymouth = {
    theme = "lain";
    themePackages = [ theme ];
  };
}
