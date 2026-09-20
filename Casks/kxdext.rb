cask "kxdext" do
  version "6.14.0"
  sha256 "ebfb6a643ea98bb7c2e08a4f99353b2a3129e397f4302340443bbd936f12eb1c"

  url "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice/releases/download/v#{version}/Karabiner-DriverKit-VirtualHIDDevice-#{version}.pkg"
  name "Karabiner-DriverKit-VirtualHIDDevice"
  desc "Virtual HID device driver, with the daemon kanata grabs through"
  homepage "https://github.com/pqrs-org/Karabiner-DriverKit-VirtualHIDDevice"

  # The version is pinned deliberately, and so is the pairing it implies: kanata's
  # client speaks a driver *protocol*, and the two move together. kanata 1.12.0's
  # karabiner-driverkit 0.3.0 speaks protocol 5, which is this 6.x driver; kanata
  # 1.13's 0.4.0 speaks protocol 7, which needs the 8.x driver. Upgrading one
  # without the other leaves kanata unable to seize a keyboard, with the daemon
  # saying "client protocol version is mismatched".
  depends_on macos: :big_sur

  # Karabiner-Elements carries its own copy of this driver *and* its own core
  # service, a second thing that seizes the keyboard - and a newer driver than
  # kanata 1.12.0 can talk to.
  conflicts_with cask: "karabiner-elements"

  pkg "Karabiner-DriverKit-VirtualHIDDevice-#{version}.pkg"

  daemon_label = "org.pqrs.service.daemon.Karabiner-VirtualHIDDevice-Daemon"
  daemon_plist = "/Library/LaunchDaemons/#{daemon_label}.plist"
  daemon_bin = "/Library/Application Support/org.pqrs/Karabiner-DriverKit-VirtualHIDDevice" \
               "/Applications/Karabiner-VirtualHIDDevice-Daemon.app/Contents/MacOS" \
               "/Karabiner-VirtualHIDDevice-Daemon"
  manager = "/Applications/.Karabiner-VirtualHIDDevice-Manager.app/Contents/MacOS" \
            "/Karabiner-VirtualHIDDevice-Manager"

  postflight_steps do
    # The daemon's launchd job, which the package does not provide: it ships no
    # plist and its postinstall is empty, so a machine with the driver but
    # without Karabiner-Elements has nothing running the daemon - and kanata,
    # whose macOS grab goes through it, has nothing to connect to. Written here
    # so that `brew uninstall` can take it away again (see `uninstall`).
    plist = <<~PLIST
      <?xml version="1.0" encoding="UTF-8"?>
      <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
      <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>#{daemon_label}</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{daemon_bin}</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>ProcessType</key>
        <string>Interactive</string>
        <key>StandardOutPath</key>
        <string>/var/log/karabiner-virtualhiddevice-daemon.log</string>
        <key>StandardErrorPath</key>
        <string>/var/log/karabiner-virtualhiddevice-daemon.log</string>
      </dict>
      </plist>
    PLIST

    # One root step for the job: the plist, then the load. `bootout` is only for
    # a reinstall, where the job is already loaded - on a first install there is
    # nothing to boot out and it says so on stderr, which reads like a failure.
    run "/bin/sh",
        args: ["-c", "cat > #{daemon_plist} <<'PLIST'\n#{plist}\nPLIST\n" \
                     "launchctl bootout system/#{daemon_label} 2>/dev/null || true\n" \
                     "launchctl bootstrap system #{daemon_plist}"],
        sudo: true

    # Installed but inactive, and an inactive dext is a driver kanata cannot grab
    # through. pqrs's own activation command; macOS still asks for approval of
    # the system extension, which is the one step only a click can do.
    run manager, args: ["forceActivate"], sudo: true
  end

  uninstall launchctl: daemon_label,
            pkgutil:   "org.pqrs.Karabiner-DriverKit-VirtualHIDDevice",
            delete:    daemon_plist

  uninstall_postflight_steps do
    # `pkgutil` takes the files away; the system extension stays registered until
    # it is told otherwise, which is what the manager's other verb is for.
    run manager, args: ["deactivate"], sudo: true, must_succeed: false
  end

  caveats <<~EOS
    Two permissions are granted by hand, and macOS asks for neither by itself.
    Add /opt/homebrew/bin/kanata to both - the + button, then Cmd+Shift+G:

      System Settings > Privacy & Security > Input Monitoring
      System Settings > Privacy & Security > Accessibility

    Approve the driver's system extension when macOS asks, or find it in
    System Settings > General > Login Items & Extensions > Driver Extensions.

    The daemon's job is #{daemon_label};
    `sudo launchctl print system/#{daemon_label}` says whether it is up.
  EOS
end
