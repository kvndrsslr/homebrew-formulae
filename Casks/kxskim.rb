cask "kxskim" do
  version "1.7.17"
  sha256 "7538469605ad5330e6807469b6d77bd50afe04b9753d62ec57f4e305a2f3fcf2"

  url "https://github.com/kvndrsslr/skim/releases/download/v#{version}/Skim-#{version}.dmg"

  name "Skim"
  desc "PDF reader and note-taking application, with a title bar that hides until hovered"
  homepage "https://github.com/kvndrsslr/skim"

  livecheck do
    url :url
    strategy :github_latest
  end

  # The fork keeps upstream's bundle identifier on purpose, so documents,
  # preferences and window state carry over from a plain Skim install. Two casks
  # cannot own the same /Applications/Skim.app, hence the separate token and the
  # conflict with the core cask.
  depends_on macos: :golden_gate
  conflicts_with cask: "skim"

  # Sparkle is wired to upstream's appcast, so the app offers plain Skim as an
  # update and would replace this build. Left to the app, as with upstream's
  # cask, rather than having brew and Sparkle fight over the bundle.
  auto_updates true

  app "Skim.app"
  binary "#{appdir}/Skim.app/Contents/SharedSupport/displayline"
  binary "#{appdir}/Skim.app/Contents/SharedSupport/skimnotes"
  binary "#{appdir}/Skim.app/Contents/SharedSupport/skimpdf"

  # The build is ad-hoc signed and cannot be notarized (no Developer ID
  # certificate exists for it), so Gatekeeper balks at the quarantine flag brew
  # propagates onto the staged bundle and refuses the launch. Clearing that flag
  # on the installed app is what makes a plain `brew install --cask` work.
  postflight_steps do
    run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{appdir}}/Skim.app"]
  end

  caveats <<~EOS
    This build is ad-hoc signed (no Developer ID, hence no notarization), so the
    quarantine flag macOS puts on downloaded apps makes Gatekeeper reject it.
    This cask clears that flag from the installed app. On other machines you can
    instead keep brew's hands off the attribute:

      HOMEBREW_CASK_OPTS="--no-quarantine" brew install --cask #{token}

    "Check for Updates" inside the app reaches upstream's appcast and therefore
    offers plain Skim, which replaces this build.
  EOS
end
