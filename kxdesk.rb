class Kxdesk < Formula
  desc "Personal desktop daemon for SketchyBar, yabai and friends"
  homepage "https://github.com/kvndrsslr/kxdesk"
  url "https://github.com/kvndrsslr/kxdesk.git",
      tag:      "v0.1.1",
      revision: "e8413d09c9cd9edb653bf07bdc7c6a23f1be2801"
  head "https://github.com/kvndrsslr/kxdesk.git", branch: "main"

  depends_on "zig" => :build
  depends_on :macos

  def install
    system "zig", "build", "--prefix", prefix
  end

  service do
    run [opt_bin/"kxdesk", "daemon"]
    keep_alive true
    process_type :interactive
  end

  test do
    # Every other command is answered by the daemon, and `brew test` does not
    # start one; the version is the one question the binary answers itself.
    assert_match(/\d+\.\d+\.\d+/, shell_output("#{bin}/kxdesk version"))
  end
end
