class Kxkanata < Formula
  desc "Run kanata with the TCP channel its key bindings push to"
  homepage "https://github.com/jtroo/kanata"
  # Nothing is built from this: the payload is the launcher below, and the
  # binary it runs comes from the `kanata` dependency. The url names the kanata
  # release the launcher was written against, so the version says which one.
  url "https://github.com/jtroo/kanata/archive/refs/tags/v1.12.0.tar.gz"
  sha256 "7081073d1d22fe4e404cf8e7d1dfa3f72562fb2d96538367c07f64877dcbf87a"
  license "LGPL-3.0-only"

  depends_on "kanata"
  depends_on :macos

  def install
    # kanata's TCP server is compiled into every build - `tcp_server` is a
    # default cargo feature - but the listener is opt-in: `--port` is an
    # optional argument with no default, and upstream's words are "if blank, no
    # TCP port will be listened on". That is deliberate, since the protocol can
    # also inject keystrokes and a bare port listens on every interface.
    #
    # So the port has to be passed by whatever starts kanata, and a formula's
    # service block is the only place `brew services` takes arguments from.
    # This launcher is that argument list, in the one place it can be read.
    #
    # The config path is not here: it needs the user's home, and this file is
    # written inside Homebrew's build sandbox, where `Dir.home` is a temporary
    # `.brew_home`. The service block below passes it instead, where `Dir.home`
    # is the user's - the same split the core `kanata` formula uses.
    (bin/"kxkanata").write <<~SH
      #!/bin/sh
      # kanata, with the channel its key bindings push to.
      #
      # Loopback rather than a bare port: a bare port listens on every
      # interface, and this protocol can inject keystrokes as well as receive
      # them. Everything else is the caller's, including `--cfg`.
      exec "#{HOMEBREW_PREFIX}/bin/kanata" --no-wait \\
        -p 127.0.0.1:4038 \\
        "$@"
    SH
    chmod 0755, bin/"kxkanata"
  end

  service do
    # Root, because seizing the keyboard through the Karabiner driver needs it:
    # the driver's IPC lives under a directory only root can read. `Dir.home` is
    # the user's here, because this block is read by `brew services` and not
    # inside the build sandbox.
    run [opt_bin/"kxkanata", "--cfg", "#{Dir.home}/Library/Application Support/kanata/kanata.kbd"]
    keep_alive true
    require_root true
    process_type :interactive
    log_path var/"log/kxkanata.log"
    error_log_path var/"log/kxkanata.log"
  end

  test do
    assert_predicate bin/"kxkanata", :executable?
    # The launcher passes its own arguments through, so kanata's own help
    # answers without a keyboard to seize.
    assert_match "kanata", shell_output("#{bin}/kxkanata --help 2>&1")
  end

  def caveats
    <<~EOS
      The driver kanata seizes the keyboard through comes from the kxdext cask:

        brew install --cask kvndrsslr/formulae/kxdext

      This service runs as root, and root keeps its own trust store - your own
      brew already trusts the tap, which is why installing worked and starting
      did not. `brew trust` refuses to run as root, so root's store is written
      once, by hand, and then starting works from then on:

        sudo install -d -m 700 /var/root/.homebrew
        sudo tee /var/root/.homebrew/trust.json >/dev/null <<'JSON'
        {"trustedtaps":["kvndrsslr/formulae"],"trustedformulae":["kvndrsslr/formulae/kxkanata"]}
        JSON

      Two grants are needed once, and macOS asks for neither by itself:

        System Settings > Privacy & Security > Input Monitoring
        System Settings > Privacy & Security > Accessibility

      Add #{HOMEBREW_PREFIX}/bin/kanata to both - the + button, then Cmd+Shift+G
      to type the path. kanata cannot seize the keyboard without them and exits
      saying so; `keep_alive` means it starts working on its own once they are
      granted. macOS pins a grant to the executable the path resolves to, so
      after `brew upgrade kanata` remove the entry in both panes and add it
      again.

        sudo brew services start kxkanata     # start it, and at boot
        brew services info kxkanata           # what is running
        tail -f #{HOMEBREW_PREFIX}/var/log/kxkanata.log
    EOS
  end
end
