abstract interface class InviteFileGateway {
  Future<void> share({required String fileName, required String payload});

  Future<String?> pick();
}
