cask "skim-nobar" do
  version "1.7.17"
  sha256 "6f9d96075ee095c289609f19636b9870681b4e9101602d3a5d102870a054d6b6"

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

  caveats <<~EOS
    This build is ad-hoc signed (no Developer ID), so Gatekeeper rejects the
    quarantined download. Install it without the quarantine flag:

      brew install --cask --no-quarantine #{token}

    "Check for Updates" inside the app reaches upstream's appcast and therefore
    offers plain Skim, which replaces this build.
  EOS
end
