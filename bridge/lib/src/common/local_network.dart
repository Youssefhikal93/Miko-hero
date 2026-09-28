import 'dart:io';

/// Whether [host] names the machine the bridge itself runs on.
///
/// `localhost`, anything in `127.0.0.0/8`, and the IPv6 loopback `::1` — in
/// bare or bracketed spelling, because an origin carries the brackets and a
/// bind address does not.
bool isLoopbackHost(String host) => _classify(host) == _HostKind.loopback;

/// Whether [host] is loopback or an address only a private network hands out:
/// `10/8`, `172.16/12`, `192.168/16`, link-local `169.254/16` and `fe80::/10`,
/// unique-local `fc00::/7`, and the Tailscale range `100.64/10`.
///
/// This is the wider of the two questions and is deliberately **not** what
/// CORS asks: a page served from the LAN still has to be listed in
/// `allowedWebOrigins` by hand. Both questions are answered from the same
/// parsed address so they can never disagree about what an address is.
bool isPrivateOrLoopbackHost(String host) {
  final kind = _classify(host);
  return kind == _HostKind.loopback || kind == _HostKind.private;
}

/// What one host string turned out to be.
enum _HostKind { loopback, private, other }

_HostKind _classify(String host) {
  var text = host.trim().toLowerCase();
  // A web origin spells an IPv6 literal `[::1]`; `Uri.host` and a bind address
  // both spell it bare. Accepting either keeps callers from having to know.
  if (text.length > 1 && text.startsWith('[') && text.endsWith(']')) {
    text = text.substring(1, text.length - 1);
  }
  if (text == 'localhost') {
    return _HostKind.loopback;
  }
  final address = InternetAddress.tryParse(text);
  if (address == null) {
    // Any other hostname: the bridge cannot tell where it resolves to, so it
    // is treated as public rather than trusted.
    return _HostKind.other;
  }
  final List<int> bytes = address.rawAddress;
  if (address.type == InternetAddressType.IPv4) {
    if (bytes[0] == 127) {
      return _HostKind.loopback;
    }
    final private =
        bytes[0] == 10 ||
        bytes[0] == 172 && bytes[1] >= 16 && bytes[1] <= 31 ||
        bytes[0] == 192 && bytes[1] == 168 ||
        bytes[0] == 169 && bytes[1] == 254 ||
        bytes[0] == 100 && bytes[1] >= 64 && bytes[1] <= 127;
    return private ? _HostKind.private : _HostKind.other;
  }
  if (_isIpv6Loopback(bytes)) {
    return _HostKind.loopback;
  }
  final private =
      (bytes[0] & 0xfe) == 0xfc ||
      bytes[0] == 0xfe && (bytes[1] & 0xc0) == 0x80;
  return private ? _HostKind.private : _HostKind.other;
}

bool _isIpv6Loopback(List<int> bytes) {
  for (var index = 0; index < bytes.length - 1; index++) {
    if (bytes[index] != 0) {
      return false;
    }
  }
  return bytes.last == 1;
}
