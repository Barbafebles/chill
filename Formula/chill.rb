class Chill < Formula
  desc "Lightweight native macOS CLI hardware and telemetry monitor in Swift"
  homepage "https://github.com/Barbafebles/chill"
  url "https://github.com/Barbafebles/chill/archive/refs/tags/v1.0.0.tar.gz"
  head "https://github.com/Barbafebles/chill.git", branch: "main"
  license "MIT"

  depends_on :macos
  depends_on xcode: ["14.0", :build]

  def install
    system "swift", "build", "-c", "release", "--disable-sandbox"
    bin.install ".build/release/chill"
  end

  test do
    system "#{bin}/chill", "--help"
  end
end
