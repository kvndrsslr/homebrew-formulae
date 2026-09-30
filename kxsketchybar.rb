class Kxsketchybar < Formula
  desc "Status bar for macOS with the badge, ring and wake-retention PR stack"
  homepage "https://github.com/kvndrsslr/SketchyBar"
  url "https://github.com/kvndrsslr/SketchyBar.git",
      tag:      "v2.24.0-daily.2",
      revision: "46f85cc2a6a28abeca9d6ef67170241d5f70eb7e"
  head "https://github.com/kvndrsslr/SketchyBar.git", branch: "daily"
  license "GPL-3.0-only"
  version "2.24.0-daily.2"

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
        and three local fixes: `topmost` only re-creates the bar when it changes,
        a bar reset clears its pending display decision, and a click on the bar
        re-orders the item windows so the opaque background cannot land on top
        of them.

      Back to the released SketchyBar:
        brew services stop kxsketchybar
        brew uninstall kxsketchybar
        brew install sketchybar
        brew services start sketchybar

      Logs: #{var}/log/kxsketchybar.out.log, #{var}/log/kxsketchybar.err.log
    EOS
  end

  test do
    assert_match(/sketchybar-v\d+\.\d+\.\d+/, shell_output("#{bin}/sketchybar --version"))
  end
end
