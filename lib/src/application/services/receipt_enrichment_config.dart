final class ReceiptEnrichmentConfig {
  const ReceiptEnrichmentConfig({required this.mode});

  const ReceiptEnrichmentConfig.disabled() : mode = 'disabled';

  factory ReceiptEnrichmentConfig.fromEnvironment() {
    const mode = String.fromEnvironment(
      'RECEIPT_PROVIDER_MODE',
      defaultValue: 'disabled',
    );
    return const ReceiptEnrichmentConfig(mode: mode);
  }

  final String mode;

  bool get enabled => mode != 'disabled';
}
