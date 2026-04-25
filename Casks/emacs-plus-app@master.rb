cask "emacs-plus-app@master" do
  # Version format: <emacs-version>-<build-number>
  # Build number corresponds to GitHub Actions run number
  version "31.0.50-164"

  # Base URL for release assets (versioned releases: cask-31-<build>)
  base_url = "https://github.com/d12frosted/homebrew-emacs-plus/releases/download/cask-31-#{version.sub(/^[\d.]+-/, "")}"
  emacs_ver = version.sub(/-\d+$/, "")

  on_intel do
    sha256 "9f47c20ab85003be792cf2b0b0e04b05e31061d739dae48c22af4841a2bbbc9b"
    url "#{base_url}/emacs-plus-#{emacs_ver}-x86_64-15.zip",
        verified: "github.com/d12frosted/homebrew-emacs-plus"
  end

  on_arm do
    if MacOS.version >= :tahoe # macOS 26
      sha256 "a030954fbb4de5c43d3c63c13ddfed620a52a2a8ce585ed6685efffc1140fd84"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-26.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    elsif MacOS.version >= :sequoia # macOS 15
      sha256 "ff109a1c877d317861d317bfc671c244a31d67a2f72180c5181aa6b40944096a"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-15.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    else # macOS 14 (Sonoma) and 13 (Ventura)
      sha256 "81c80d2fa5b8f6abf0ece449f158d339d1135e6e964fdb6e03f34f2c64b76ed5"
      url "#{base_url}/emacs-plus-#{emacs_ver}-arm64-14.zip",
          verified: "github.com/d12frosted/homebrew-emacs-plus"
    end
  end

  name "Emacs+ (Development)"
  desc "GNU Emacs text editor with patches for macOS (development version)"
  homepage "https://github.com/d12frosted/homebrew-emacs-plus"

  # Required for native compilation (JIT) at runtime
  # - libgccjit: JIT compilation library
  # - gcc: provides toolchain and libemutls_w.a runtime library
  depends_on formula: "libgccjit"
  depends_on formula: "gcc"

  # Conflict with other Emacs cask installations
  conflicts_with cask: [
    "emacs",
    "emacs-mac",
    "emacs-mac-spacemacs-icon",
    "emacs-plus-app",
  ]

  # Install the app
  app "Emacs.app"
  app "Emacs Client.app"

  # Remove quarantine attribute, inject PATH, and apply custom icon
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/Emacs.app"],
                   sudo: false
    system_command "/usr/bin/xattr",
                   args: ["-r", "-d", "com.apple.quarantine", "#{appdir}/Emacs Client.app"],
                   sudo: false

    # Environment setup for native compilation and CLI usage
    tap = Tap.fetch("d12frosted", "emacs-plus")
    load "#{tap.path}/Library/CaskEnv.rb"
    needs_resign = CaskEnv.inject("#{appdir}/Emacs.app", "#{appdir}/Emacs Client.app")

    # Apply custom icon from ~/.config/emacs-plus/build.yml if configured
    load "#{tap.path}/Library/IconApplier.rb"
    needs_resign = IconApplier.apply("#{appdir}/Emacs.app", "#{appdir}/Emacs Client.app") || needs_resign

    if needs_resign
      # Re-sign after modifications
      system_command "/usr/bin/codesign",
                     args: ["--force", "--deep", "--sign", "-", "#{appdir}/Emacs.app"],
                     sudo: false
      system_command "/usr/bin/codesign",
                     args: ["--force", "--deep", "--sign", "-", "#{appdir}/Emacs Client.app"],
                     sudo: false
    end

    # Create emacs symlink manually (can't use binary stanza since wrapper is created above)
    emacs_wrapper = "#{appdir}/Emacs.app/Contents/MacOS/bin/emacs"
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    if File.exist?(emacs_wrapper) && !File.exist?(emacs_symlink)
      FileUtils.ln_sf(emacs_wrapper, emacs_symlink)
    end
  end

  # Clean up emacs symlink on uninstall (since we create it manually in postflight)
  uninstall_postflight do
    emacs_symlink = "#{HOMEBREW_PREFIX}/bin/emacs"
    FileUtils.rm_f(emacs_symlink) if File.symlink?(emacs_symlink)
  end

  # Symlink binaries (emacs symlink created in postflight after wrapper is generated)
  # Note: emacs is symlinked manually in postflight because the wrapper script
  # is created there and binary stanzas run before postflight
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/emacsclient"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/ebrowse"
  binary "#{appdir}/Emacs.app/Contents/MacOS/bin/etags"

  # Man pages (not gzipped in the build)
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacs.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/emacsclient.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/ebrowse.1"
  manpage "#{appdir}/Emacs.app/Contents/Resources/man/man1/etags.1"

  # Cleanup on uninstall
  zap trash: [
    "~/Library/Caches/org.gnu.Emacs",
    "~/Library/Preferences/org.gnu.Emacs.plist",
    "~/Library/Saved Application State/org.gnu.Emacs.savedState",
    "~/.emacs.d",
  ]

  caveats <<~EOS
    Emacs+ (development) has been installed to /Applications.

    This is a pre-built binary from the Emacs master branch.
    For custom patches or build options, use the formula instead:
      brew install emacs-plus@master --with-...

    Custom icons can be configured via ~/.config/emacs-plus/build.yml:
      icon: dragon-plus

    To re-apply an icon after changing build.yml:
      brew reinstall --cask emacs-plus-app@master

    Note: Emacs Client.app requires Emacs to be running as a daemon.
    Add to your Emacs config: (server-start)
  EOS
end
