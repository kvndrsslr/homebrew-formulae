
class Brync < Formula
    desc "A brightness syncing service."
    homepage "https://github.com/kvndrsslr/brync"
    url "https://github.com/kvndrsslr/brync/archive/refs/tags/0.1.tar.gz"
    sha256 "4feec735794cf22eeb6f985d661b9cd2e7dcddf71d8f6b69ea2de9387627b9ac"
  
    depends_on :macos => :high_sierra
    depends_on "brightness"
    depends_on "zsh"
    depends_on "kvndrsslr/formulae/ddcctl"
  
    def install
      bin.install "#{buildpath}/brync"
    end
  
    plist_options :manual => "brync"
  
    def plist; <<~EOS
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{plist_name}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{opt_bin}/brync</string>
        </array>
        <key>EnvironmentVariables</key>
        <dict>
          <key>PATH</key>
          <string>#{HOMEBREW_PREFIX}/bin:/usr/bin:/bin:/usr/sbin:/sbin</string>
        </dict>
        <key>RunAtLoad</key>
        <true/>
        <key>StartInterval</key>
        <integer>10</integer>
        <key>KeepAlive</key>
        <true/>
        <key>StandardOutPath</key>
        <string>#{var}/log/brync/brync.out.log</string>
        <key>StandardErrorPath</key>
        <string>#{var}/log/brync/brync.err.log</string>
        <key>ProcessType</key>
        <string>Background</string>
      </dict>
      </plist>
      EOS
    end
  
  end