class Kxmusic < Formula
  desc "Terminal music player with full Spotify feature parity"
  homepage "https://github.com/kvndrsslr/kxmusic"
  url "https://github.com/kvndrsslr/kxmusic.git",
      revision: "3663593636f7e7fdbb3dc46eda9eddf56716778f"
  version "0.24.1"
  license "MIT"
  head "https://github.com/kvndrsslr/kxmusic.git", branch: "main"

  depends_on "pkgconf" => :build
  depends_on "rust" => :build
  depends_on :macos

  def install
    # Default features (rodio, media control, TSP) plus album art and desktop
    # notifications, the same set scripts/install-brew builds from a checkout.
    system "cargo", "install", *std_cargo_args(path: "kxmusic", features: ["image", "notify"])

    generate_completions_from_executable(bin/"kxmusic", "generate")
  end

  test do
    assert_match version.to_s, shell_output("#{bin}/kxmusic --version")
    assert_match "complete -F _kxmusic", shell_output("#{bin}/kxmusic generate bash")
  end
end
