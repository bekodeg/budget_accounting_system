import 'dart:io';

import '../../application/ports/lan_local_address_resolver.dart';

final class IoLanLocalAddressResolver implements LanLocalAddressResolver {
  const IoLanLocalAddressResolver();

  @override
  Future<String?> resolveIpv4() async {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLoopback: false,
      includeLinkLocal: false,
    );

    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback && address.type == InternetAddressType.IPv4) {
          return address.address;
        }
      }
    }
    return null;
  }
}
