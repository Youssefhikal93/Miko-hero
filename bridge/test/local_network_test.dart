import 'package:iam_hero_bridge/src/common/local_network.dart';
import 'package:test/test.dart';

void main() {
  group('loopback', () {
    test('every spelling of this machine is loopback', () {
      for (final host in <String>[
        'localhost',
        'LOCALHOST',
        '127.0.0.1',
        '127.42.0.8',
        '127.255.255.255',
        '::1',
        // A web origin carries the brackets an IPv6 literal needs; a bind
        // address does not. Both have to answer the same.
        '[::1]',
        '0:0:0:0:0:0:0:1',
      ]) {
        expect(isLoopbackHost(host), isTrue, reason: host);
        expect(isPrivateOrLoopbackHost(host), isTrue, reason: host);
      }
    });

    test('a private address is not loopback', () {
      for (final host in <String>[
        '10.0.0.1',
        '172.16.0.1',
        '192.168.1.20',
        '169.254.10.20',
        '100.64.0.1',
        'fc00::1',
        'fe80::1',
      ]) {
        expect(
          isLoopbackHost(host),
          isFalse,
          reason: '$host is on the LAN, and CORS consent must not widen to it',
        );
      }
    });
  });

  group('private ranges', () {
    test('the ranges a home network and Tailscale hand out are private', () {
      for (final host in <String>[
        '10.0.0.1',
        '10.255.255.254',
        '172.16.0.1',
        '172.31.255.254',
        '192.168.1.20',
        '169.254.10.20',
        '100.64.0.1',
        '100.127.255.254',
        'fc00::1',
        'fdff::1',
        'fe80::1',
        'febf::1',
      ]) {
        expect(isPrivateOrLoopbackHost(host), isTrue, reason: host);
      }
    });

    test('the addresses just outside each range are public', () {
      for (final host in <String>[
        '0.0.0.0',
        '::',
        '8.8.8.8',
        '2001:4860:4860::8888',
        '172.15.255.255',
        '172.32.0.0',
        '100.63.255.255',
        '100.128.0.0',
        '9.255.255.255',
        '11.0.0.0',
        '192.167.1.1',
      ]) {
        expect(isPrivateOrLoopbackHost(host), isFalse, reason: host);
        expect(isLoopbackHost(host), isFalse, reason: host);
      }
    });
  });

  group('hostnames', () {
    test('only "localhost" is trusted; nothing else that must resolve is', () {
      for (final host in <String>[
        'example.com',
        'stories.example.com',
        'localhost.example.com',
        'my-pc.local',
        '',
      ]) {
        expect(
          isPrivateOrLoopbackHost(host),
          isFalse,
          reason: 'the bridge cannot tell where "$host" resolves to',
        );
        expect(isLoopbackHost(host), isFalse, reason: host);
      }
    });
  });
}
