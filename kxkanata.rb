class Kxkanata < Formula
  desc "Run kanata with the TCP channel its key bindings push to, and grab keyboards plugged in later"
  homepage "https://github.com/jtroo/kanata"
  # Nothing is built from the kanata tarball: the payload is the supervisor
  # below, and the binary it runs comes from the `kanata` dependency. The url
  # names the kanata release the scripts were written against, so the version
  # says which one. The one thing compiled here is a 70-line IOKit waiter of
  # our own.
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
      # kanata, with the channel its key bindings push to, and with the
      # keyboards you plug in after it started.
      #
      # Loopback rather than a bare port: a bare port listens on every
      # interface, and this protocol can inject keystrokes as well as receive
      # them. Everything else is the caller's, including `--cfg`.
      #
      # The supervision around it exists because kanata's macOS grab registers
      # the keyboards attached when it starts and afterwards only ever
      # re-captures devices whose hash is already registered
      # (karabiner-driverkit c_src/driverkit.cpp: register_device() fills a set
      # of FNV hashes of "vendor:product:name",
      # capture_registered_devices() subscribes kIOMatchedNotification once per
      # hash, and device_connected_callback() seizes a device only when its
      # hash is in that set). A keyboard plugged in after kanata started is
      # therefore never grabbed: upstream says so in docs/config.adoc ("Device
      # IDs are matched at startup") and tracks it as issue #1982. skhd never
      # had the gap because it read the event stream, where every keyboard
      # appears by itself; kanata seizes devices, so it has to enumerate them.
      #
      # So: wait for a keyboard to be published, ask kxkanata-devices whether
      # the grab now covers everything attached, and if not - and only if the
      # grab is otherwise active, which keeps kanata's own startup, screen-lock
      # release and DriverKit recovery out of the way - restart kanata with
      # everything attached. That is the one path that registers new devices.
      # A restart is a couple of seconds of plain typing, and the backoff keeps
      # a persistent failure from looping.
      set -u

      KANATA="#{HOMEBREW_PREFIX}/bin/kanata"
      DEVICES="#{HOMEBREW_PREFIX}/bin/kxkanata-devices"
      ARRIVAL="#{HOMEBREW_PREFIX}/opt/kxkanata/libexec/kxkanata-arrival"
      PORT=127.0.0.1:4038
      POLL=2            # seconds between child liveness checks
      MAX_BACKOFF=900   # seconds; reached after six restarts of one complaint

      child=0
      restarting=0
      backoff=0
      last_restart=0

      start() {
        "$KANATA" --no-wait -p "$PORT" "$@" &
        child=$!
      }

      stop() {
        [ "$child" -gt 0 ] || return 0
        kill "$child" 2>/dev/null
        i=0
        while kill -0 "$child" 2>/dev/null && [ "$i" -lt 20 ]; do
          sleep 0.2
          i=$((i + 1))
        done
        kill -9 "$child" 2>/dev/null
        wait "$child" 2>/dev/null
        child=0
      }

      trap 'stop; exit 0' TERM INT HUP

      start "$@"

      while :; do
        sleep "$POLL"
        if ! kill -0 "$child" 2>/dev/null; then
          wait "$child"
          status=$?
          if [ "$restarting" = 1 ]; then
            restarting=0
            start "$@"
            continue
          fi
          # kanata's own exit - the emergency chord, a config error, a crash -
          # stays kanata's: hand the status to launchd, whose keep_alive and
          # minimum-runtime throttle then do exactly what they did before.
          exit "$status"
        fi

        # Block on the device tree, not the clock: nothing between keyboard
        # arrivals. The timeout only puts the same loop over kanata's health.
        "$ARRIVAL" --timeout 30 >/dev/null 2>&1
        arrival_status=$?
        if [ "$arrival_status" -ne 0 ] && [ "$arrival_status" -ne 4 ]; then
          continue
        fi

        "$DEVICES" >/dev/null 2>&1
        check=$?
        if [ "$check" -eq 0 ]; then
          backoff=0
          continue
        fi
        [ "$check" -eq 1 ] || continue

        now=$(date +%s)
        if [ $((now - last_restart)) -lt "$backoff" ]; then
          continue
        fi

        last_restart=$now
        if [ "$backoff" -eq 0 ]; then
          backoff=30
        elif [ "$backoff" -lt "$MAX_BACKOFF" ]; then
          backoff=$((backoff * 2))
        fi
        echo "kxkanata: keyboard attached but not grabbed; restarting kanata"
        "$DEVICES" 2>/dev/null | awk '/^MISSING/ { print "kxkanata:   " $0 }'
        restarting=1
        stop
        start "$@"
      done
    SH
    chmod 0755, bin/"kxkanata"

    (bin/"kxkanata-devices").write <<~SH
      #!/bin/sh
      # kxkanata-devices — say which keyboards the running kanata has not grabbed.
      #
      # kanata's macOS backend registers the keyboards attached when it starts
      # and afterwards only ever re-captures devices whose hash is already
      # registered (karabiner-driverkit c_src/driverkit.cpp:
      # register_device() fills a set of FNV hashes of "vendor:product:name",
      # capture_registered_devices() subscribes kIOMatchedNotification once per
      # hash, and device_connected_callback() seizes a device only when its
      # hash is in that set). A keyboard plugged in after kanata started is
      # therefore never seized: upstream words are "Device IDs are matched at
      # startup" (docs/config.adoc) and the gap is tracked as issue #1982.
      #
      # This reads the HID device tree and names every keyboard-interface
      # device kanata is not holding, the way IORegistry shows it: a device
      # kanata seized has an IOHIDLibUserClient whose IOUserClientCreator
      # names the kanata process. Exit codes: 0 every keyboard held, 1 at
      # least one missing while the grab is otherwise active, 2 the grab is
      # not active at all (kanata down, or it released everything), 3 the
      # device tree could not be read. kxkanata restarts kanata only on 1.
      LC_ALL=C
      export LC_ALL

      LC_ALL=C /usr/sbin/ioreg -r -c IOHIDDevice -l -w0 2>/dev/null | awk '
      BEGIN { held_count = 0; missing_count = 0 }
      function flush() {
        if (name == "")
          return
        # The keyboard interface only: usage 1/6. Skip the devices kanata
        # itself refuses to register - its own virtual keyboard, and Sidecar,
        # which aborts the grab when seized (the kanata
        # SKIPPED_VIRTUAL_DEVICE_SUBSTRINGS list).
        if (usage != 6)
          return
        lname = tolower(name)
        if (lname ~ /karabiner/ || lname ~ /sidecar/ || name ~ /^ +$/)
          return
        status = held ? "held" : "MISSING"
        printf "%s\\t%s\\t%s\\n", status, name, loc
        if (held)
          held_count++
        else
          missing_count++
      }
      /^\\+\\-o /                  { flush(); name=""; usage=""; loc=""; held=0; inlib=0; next }
      /^ *\\+\\-o IOHIDLibUserClient/ { inlib=1; next }
      /^ *\\+\\-o /                 { inlib=0 }
      /"Product" =/ {
        if (name == "") {
          line = $0
          sub(/^.*"Product" = "/, "", line)
          sub(/"$/, "", line)
          name = line
        }
      }
      /"PrimaryUsage" =/           { if (usage == "") usage = $NF }
      /"LocationID" =/             { if (loc == "") loc = $NF }
      /IOUserClientCreator/        { if (inlib && /, kanata/) held = 1 }
      END {
        flush()
        if (held_count + missing_count == 0)
          exit 3
        if (missing_count > 0 && held_count > 0)
          exit 1
        if (missing_count > 0)
          exit 2
        exit 0
      }
      '
    SH
    chmod 0755, bin/"kxkanata-devices"

    # The wait is the only thing worth compiling: kxkanata must learn about a
    # keyboard the moment it is published, without polling the registry every
    # couple of seconds. IOServiceAddMatchingNotification with the same
    # matching dictionary kanata's C++ uses does exactly that, and the
    # canonical drain-first pattern keeps the keyboards kanata already
    # registered from counting as news. Failure here degrades, not breaks: the
    # supervisor treats any non-arrival exit as "nothing to do", and its own
    # 30s timeout re-checks the device tree regardless.
    (libexec/"kxkanata-arrival.c").write <<~C
      // kxkanata-arrival - block until a keyboard HID device is published.
      //
      // kanata's macOS grab registers the keyboards attached when it starts
      // and afterwards only re-captures devices whose hash is already
      // registered (karabiner-driverkit c_src/driverkit.cpp:
      // register_device() fills a set of hashes,
      // capture_registered_devices() subscribes kIOMatchedNotification once
      // per hash, and device_connected_callback() only seizes a device whose
      // hash is in that set). A keyboard plugged in later is therefore never
      // seized; upstream says so in docs/config.adoc ("Device IDs are matched
      // at startup") and tracks it as issue #1982. The kxkanata supervisor
      // restarts kanata when that happens; this program is how it waits
      // without polling.
      //
      // It subscribes the same matching dictionary kanata's C++ does -
      // IOHIDDevice with usage page 1, usage 6 - drains the devices already
      // present (the notification also fires for current matches the first
      // time through, and kanata registered those at its own startup), then
      // returns as soon as a new matching device is published, printing its
      // product name.
      //
      // Exit codes: 0 a keyboard arrived, 4 the timeout expired first, 3
      // IOKit setup failed. Usage: kxkanata-arrival [--timeout seconds]

      #include <IOKit/IOKitLib.h>
      #include <IOKit/hid/IOHIDKeys.h>
      #include <CoreFoundation/CoreFoundation.h>
      #include <stdio.h>
      #include <stdlib.h>
      #include <string.h>

      static CFMutableDictionaryRef keyboard_matching(void)
      {
        CFMutableDictionaryRef dict = IOServiceMatching("IOHIDDevice");
        if (!dict)
          return NULL;
        UInt32 page = 0x01;  // kHIDPage_GenericDesktop
        UInt32 usage = 0x06; // kHIDUsage_GD_Keyboard
        CFNumberRef page_num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &page);
        CFNumberRef usage_num = CFNumberCreate(kCFAllocatorDefault, kCFNumberIntType, &usage);
        CFDictionarySetValue(dict, CFSTR(kIOHIDDeviceUsagePageKey), page_num);
        CFDictionarySetValue(dict, CFSTR(kIOHIDDeviceUsageKey), usage_num);
        CFRelease(page_num);
        CFRelease(usage_num);
        return dict;
      }

      static int arrived = 0;

      // The matching dictionary is consumed by IOServiceAddMatchingNotification.
      // IONotificationPortRef and the iterator are kept for the process
      // lifetime; the supervisor re-runs the whole program per wait, so
      // nothing needs teardown.
      static void matched(void *context, io_iterator_t iterator)
      {
        (void)context;
        arrived = 1;
        CFRunLoopStop(CFRunLoopGetCurrent());
      }

      static void timed_out(CFRunLoopTimerRef timer, void *context)
      {
        (void)timer;
        (void)context;
        CFRunLoopStop(CFRunLoopGetCurrent());
      }

      static void print_device(io_object_t device)
      {
        CFStringRef name = IORegistryEntryCreateCFProperty(
            device, CFSTR(kIOHIDProductKey), kCFAllocatorDefault, 0);
        if (!name)
          name = CFSTR("(unnamed)");
        char buf[256];
        if (CFStringGetCString(name, buf, sizeof(buf), kCFStringEncodingUTF8))
          printf("%s\\n", buf);
        CFRelease(name);
      }

      int main(int argc, char **argv)
      {
        double timeout = 0;
        for (int i = 1; i < argc; i++) {
          if (strcmp(argv[i], "--timeout") == 0 && i + 1 < argc)
            timeout = atof(argv[++i]);
        }

        CFMutableDictionaryRef matching = keyboard_matching();
        if (!matching) {
          fputs("kxkanata-arrival: IOServiceMatching failed\\n", stderr);
          return 3;
        }

        IONotificationPortRef port = IONotificationPortCreate(kIOMainPortDefault);
        if (!port) {
          fputs("kxkanata-arrival: IONotificationPortCreate failed\\n", stderr);
          return 3;
        }
        io_iterator_t matched_iter = IO_OBJECT_NULL;
        kern_return_t kr = IOServiceAddMatchingNotification(
            port, kIOMatchedNotification, matching, matched, NULL, &matched_iter);
        if (kr != KERN_SUCCESS) {
          fprintf(stderr, "kxkanata-arrival: IOServiceAddMatchingNotification 0x%x\\n", kr);
          return 3;
        }

        // The first pass yields the devices already present. kanata
        // registered those at its own startup, so they are not news; swallow
        // them without stopping the run loop.
        io_object_t device;
        while ((device = IOIteratorNext(matched_iter)) != IO_OBJECT_NULL)
          IOObjectRelease(device);

        CFRunLoopSourceRef source = IONotificationPortGetRunLoopSource(port);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopDefaultMode);
        if (timeout > 0) {
          CFRunLoopTimerRef timer = CFRunLoopTimerCreate(
              kCFAllocatorDefault, CFAbsoluteTimeGetCurrent() + timeout, 0, 0, 0,
              timed_out, NULL);
          CFRunLoopAddTimer(CFRunLoopGetCurrent(), timer, kCFRunLoopDefaultMode);
          CFRelease(timer);
        }
        CFRunLoopRun();

        if (!arrived)
          return 4;
        while ((device = IOIteratorNext(matched_iter)) != IO_OBJECT_NULL) {
          print_device(device);
          IOObjectRelease(device);
        }
        return 0;
      }
    C
    system ENV.cc, "-O2", "-Wall", "-framework", "IOKit", "-framework", "CoreFoundation",
           "-o", libexec/"kxkanata-arrival", libexec/"kxkanata-arrival.c"
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
    assert_predicate bin/"kxkanata-devices", :executable?
    assert_predicate libexec/"kxkanata-arrival", :executable?
    # The launcher passes its own arguments through, so kanata's own help
    # answers without a keyboard to seize. The supervisor exits with kanata's
    # status once that child is done.
    assert_match "kanata", shell_output("#{bin}/kxkanata --help 2>&1")
  end

  def caveats
    <<~EOS
      The driver kanata seizes the keyboard through comes from the kxdext cask:

        brew install --cask kvndrsslr/formulae/kxdext

      This service runs as root, and root reads its own trust store - your own
      brew already trusts the tap, which is why installing worked and starting
      did not. `brew trust` refuses to run as root, so root's store is written
      once, by hand:

        install -d -m 700 ~/.homebrew
        printf '%s\\n' '{"trustedtaps":["kvndrsslr/formulae"]}' > ~/.homebrew/trust.json

      That path is the one brew derives for root here - with XDG_CONFIG_HOME
      unset, `Homebrew::Trust.trust_file` answers ~/.homebrew/trust.json for the
      invoking user's home, and root's sudo invocation lands on the same file.

      Two grants are needed once, and macOS asks for neither by itself:

        System Settings > Privacy & Security > Input Monitoring
        System Settings > Privacy & Security > Accessibility

      Add #{HOMEBREW_PREFIX}/bin/kanata to both - the + button, then Cmd+Shift+G
      to type the path. kanata cannot seize the keyboard without them and exits
      saying so; `keep_alive` means it starts working on its own once they are
      granted. macOS pins a grant to the executable the path resolves to, so
      after `brew upgrade kanata` remove the entry in both panes and add it
      again.

      Keyboard plug-in: kanata only registers the keyboards attached when it
      starts, so this formula supervises it and restarts it (about two seconds
      of plain typing) when kxkanata-devices reports a keyboard the grab does
      not cover. `kxkanata-devices` prints the list; what it restarts on is in
      the log under "keyboard attached but not grabbed".

        sudo brew services start kxkanata     # start it, and at boot
        brew services info kxkanata           # what is running
        #{HOMEBREW_PREFIX}/bin/kxkanata-devices        # what is grabbed, what is not
        tail -f #{HOMEBREW_PREFIX}/var/log/kxkanata.log
    EOS
  end
end
