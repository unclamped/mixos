{ pkgs, lib, ... }:

let
  exts = import ./extensions.nix { inherit pkgs; };

  inherit (lib.lists) concatLists;
  inherit (lib.strings) concatMapStrings enableFeature;

  features = en: feats: "--${en}-features=" + (concatMapStrings (x: x + ",") feats);
in
{
  programs.chromium = {
    extensions = exts.chromium;

    nativeMessagingHosts = [ pkgs.ff2mpv-rust ];

    package = pkgs.ungoogled-chromium.override {
      enableWideVine = true;

      # https://github.com/isabelroses/dotfiles/blob/main/home/isabel/chromium.nix
      commandLineArgs = concatLists [
        # Aesthetics
        [ "--gtk-version=4" "--vertical-tabs" ]

        # Performance
        [
          (enableFeature true "gpu-rasterization")
          (enableFeature true "oop-rasterization")
          (enableFeature true "zero-copy")
          "--process-per-site"
          (enableFeature true "parallel-downloading")
          "--ignore-gpu-blocklist"
          "--disable-gpu-driver-bug-workaround"
        ]

        # Wayland
        [ "--ozone-platform=wayland" ]

        # General
        [
          "--disk-cache=$XDG_RUNTIME_DIR/chromium-cache"
          "--no-first-run"
          "--disable-wake-on-wifi"
          "--disable-breakpad"
          "--no-default-browser-check"
          (enableFeature true "experimental-web-platform-features")
          (enableFeature false "speech-api")
          (enableFeature false "speech-synthesis-api")
        ]

        # Security / privacy
        [
          "--no-pings"
          "--component-updater=require_encryption"
          "--no-crash-upload"
          "--no-service-autorun"
          "--disable-sync"
          "--password-store=gnome-libsecret"
        ]

        # Feature flags
        [
          (features "enable" [
            "UseOzonePlatform"
            "MiddleClickAutoscroll"
            "AllowLegacyMV2Extensions"
            "AcceleratedVideoEncoder"
            "AcceleratedVideoDecodeLinuxGL"
            "VaapiOnNvidiaGPUs"
            "WaylandLinuxDrmSyncobj"
            "PartitionVisitedLinkDatabase"
            "PrefetchPrivacyChanges"
            "SplitCacheByNetworkIsolationKey"
            "SplitCodeCacheByNetworkIsolationKey"
            "EnableCrossSiteFlagNetworkIsolationKey"
            "HttpCacheKeyingExperimentControlGroup"
            "PartitionConnectionsByNetworkIsolationKey"
            "StrictOriginIsolation"
            "ReduceAcceptLanguage"
            "ContentSettingsPartitioning"
          ])
          (features "disable" [
            "AutofillPaymentCardBenefits"
            "AutofillPaymentCvcStorage"
            "TpcdHeuristicsGrants"
            "TpcdMetadataGrants"
            "EnableHyperlinkAuditing"
            "NTPPopularSitesBakedInContent"
            "UsePopularSitesSuggestions"
            "EnableSnippets"
            "ArticlesListVisible"
            "EnableSnippetsByDse"
            "InterestFeedV2"
            "MediaDrmPreprovisioning"
            "AutofillServerCommunication"
            "PrivacySandboxSettings4"
            "BrowsingTopics"
            "BrowsingTopicsDocumentAPI"
            "BrowsingTopicsParameters"
            "AdaptiveButtonInTopToolbarTranslate"
            "DetailedLanguageSettings"
            "OptimizationHintsFetching"
            "DisableThirdPartyStoragePartitioningDeprecationTrial2"
            "PreloadMediaEngagementData"
            "MediaEngagementBypassAutoplayPolicies"
            "ExtensionsManifestV3Only"
            "ExtensionManifestV2Unsupported"
            "ExtensionManifestV2Disabled"
          ])
        ]
      ];
    };
  };
}
