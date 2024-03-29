
class Brync < Formula
  desc "A brightness syncing service."
  homepage "https://github.com/kvndrsslr/brync"
  url "https://github.com/kvndrsslr/brync/archive/refs/tags/0.3.tar.gz"
  sha256 "de6b5bbd54c4e2410dff5a59e0052bf61b690ed66ea79b915d3781236f37014b"

  depends_on :macos => :high_sierra
  depends_on "brightness"
  depends_on "ddcctl"
  depends_on "zsh"
  depends_on "gnu-sed"

  def install
    bin.install "#{buildpath}/brync"
  end

  service do
    run "#{opt_bin}/brync"
    environment_variables PATH: "#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin:/usr/sbin:/sbin"
    keep_alive true
    interval 10
    process_type :background
  end
  
#   def plist; <<~EOS
#     <?xml version="1.0" encoding="UTF-8"?>
#     <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
#     <plist version="1.0">
#     <dict>
#       <key>Label</key>
#       <string>#{plist_name}</string>
#       <key>ProgramArguments</key>
#       <array>
#         <string>#{opt_bin}/brync</string>
#       </array>
#       <key>EnvironmentVariables</key>
#       <dict>
#         <key>PATH</key>
#         <string></string>
#       </dict>
#       <key>RunAtLoad</key>
#       <true/>
#       <key>StartInterval</key>
#       <integer>10</integer>
#       <key>KeepAlive</key>
#       <true/>
#       <key>StandardOutPath</key>
#       <string>#{var}/log/brync/brync.out.log</string>
#       <key>StandardErrorPath</key>
#       <string>#{var}/log/brync/brync.err.log</string>
#       <key>ProcessType</key>
#       <string>Background</string>
#     </dict>
#     </plist>
#     EOS
#   end
  
end
