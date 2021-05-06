class Ddcctl < Formula
    desc "DDC monitor controls (brightness) for Mac OSX command-line"
    homepage "https://github.com/kfix/ddcctl"
    url "https://github.com/kfix/ddcctl/archive/refs/tags/v0.tar.gz"
    sha256 "8440f494b3c354d356213698dd113003245acdf667ed3902b0d173070a1a9d1f"
    license :public_domain
  
    def install
      system "make", "install", "INSTALL_DIR=./bin"
      bin.install "#{buildpath}/bin/ddcctl"
    end
  
    test do
      assert_match "1", shell_output("#{bin}/ddcctl>/dev/null 2>&1;echo $?")
    end
  end
  