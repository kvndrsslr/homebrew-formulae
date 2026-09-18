class SketchybarDaily < Formula
  desc "Status bar for macOS with the badge, ring and wake-retention PR stack"
  homepage "https://github.com/kvndrsslr/SketchyBar"
  url "https://github.com/kvndrsslr/SketchyBar.git",
      tag:      "v2.24.0-daily.1",
      revision: "430c0337fe30570f9c2b1937c1c4ff6bfb6b61d9"
  head "https://github.com/kvndrsslr/SketchyBar.git", branch: "daily"
  license "GPL-3.0-only"

  # Both install bin/sketchybar: uninstall the released formula first.
  conflicts_with "sketchybar", because: "both install a sketchybar binary"
  depends_on :macos

  def install
    system "make"
    bin.install "bin/sketchybar"
  end

  service do
    run [opt_bin/"sketchybar"]
    keep_alive true
    process_type :interactive
  end

  def caveats
    <<~EOS
      On top of upstream master this build carries:
        #816 anchored text badges,
        #817 ring component (stacked on #816),
        #847 retain bar windows across a display wake,
        and a local guard so `topmost` only re-creates the bar when it changes.

      Back to the released SketchyBar:
        brew services stop sketchybar-daily
        brew uninstall sketchybar-daily
        brew install sketchybar
        brew services start sketchybar

      Logs: #{var}/log/sketchybar-daily.out.log, #{var}/log/sketchybar-daily.err.log
    EOS
  end

  test do
    assert_match(/sketchybar-v\d+\.\d+\.\d+/, shell_output("#{bin}/sketchybar --version"))
  end
end
