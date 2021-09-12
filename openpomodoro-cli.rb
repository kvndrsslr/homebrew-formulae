
class OpenpomodoroCli < Formula
  desc "A brightness syncing service."
  homepage "https://github.com/open-pomodoro/openpomodoro-cli"
  url "https://github.com/open-pomodoro/openpomodoro-cli/releases/download/v0.3.0/openpomodoro-cli_0.3.0_darwin_amd64.tar.gz"
  sha256 "9be3b538d54a7828c8f99aa214414f4e6e178e46d4707c6bbdfa421c07bfc161"

  depends_on :macos => :high_sierra
  depends_on "go"

  def install
    bin.mkpath
    bin.install "openpomodoro-cli" "pomodoro"
  end
  
end