abstract interface class InviteConsumptionStore {
  Future<bool> isConsumed(String inviteId);

  Future<void> markConsumed(String inviteId);

  Future<void> unmarkConsumed(String inviteId);
}
