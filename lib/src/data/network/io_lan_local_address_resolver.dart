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
    return selectLanIpv4(
      interfaces.expand(
        (interface) => interface.addresses.map(
          (address) => (name: interface.name, address: address),
        ),
      ),
    );
  }
}

String? selectLanIpv4(
  Iterable<({String name, InternetAddress address})> candidates,
) {
  String? selected;
  var selectedPriority = 3;

  for (final candidate in candidates) {
    final address = candidate.address;
    if (address.type != InternetAddressType.IPv4 ||
        address.isLoopback ||
        address.isLinkLocal) {
      continue;
    }

    final name = candidate.name.toLowerCase();
    final priority = switch (name) {
      _
          when name.startsWith('wlan') ||
              name.startsWith('wl') ||
              name.contains('wi-fi') ||
              name.contains('wifi') =>
        0,
      _
          when name.startsWith('eth') ||
              name.startsWith('en') ||
              name.contains('ethernet') =>
        1,
      _ => 3,
    };

    if (priority < selectedPriority) {
      selected = address.address;
      selectedPriority = priority;
    }
  }

  return selected;
}
