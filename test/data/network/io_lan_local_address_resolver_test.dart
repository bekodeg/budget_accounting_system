import 'dart:io';

import 'package:budget_accounting_system/src/data/network/io_lan_local_address_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses Wi-Fi even when VPN and cellular interfaces come first', () {
    final addresses = [
      (name: 'tun0', address: InternetAddress('26.26.26.1')),
      (name: 'ccmni0', address: InternetAddress('12.194.56.185')),
      (name: 'wlan0', address: InternetAddress('192.168.0.247')),
    ];

    expect(selectLanIpv4(addresses), '192.168.0.247');
    expect(selectLanIpv4(addresses.reversed), '192.168.0.247');
  });

  test('uses Ethernet when Wi-Fi is unavailable', () {
    expect(
      selectLanIpv4([
        (name: 'utun0', address: InternetAddress('10.0.0.1')),
        (name: 'en0', address: InternetAddress('172.16.2.4')),
      ]),
      '172.16.2.4',
    );
  });

  test('does not publish cellular or VPN addresses as LAN endpoint', () {
    expect(
      selectLanIpv4([
        (name: 'ccmni0', address: InternetAddress('12.194.56.185')),
        (name: 'tun0', address: InternetAddress('26.26.26.1')),
        (name: 'utun0', address: InternetAddress('10.0.0.1')),
      ]),
      isNull,
    );
  });

  test('recognizes a named Wi-Fi adapter on desktop', () {
    expect(
      selectLanIpv4([
        (name: 'VPN', address: InternetAddress('10.0.0.1')),
        (name: 'Wi-Fi', address: InternetAddress('192.168.1.9')),
      ]),
      '192.168.1.9',
    );
  });
}
