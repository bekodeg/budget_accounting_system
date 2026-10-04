final class AppBuildInfo {
  const AppBuildInfo({
    required this.version,
    required this.channel,
    required this.commit,
  });

  final String version;
  final String channel;
  final String commit;

  String get shortCommit {
    if (commit.length <= 12) return commit;
    return commit.substring(0, 12);
  }
}

const currentBuildInfo = AppBuildInfo(
  version: String.fromEnvironment(
    'APP_VERSION',
    defaultValue: 'unknown',
  ),
  channel: String.fromEnvironment(
    'APP_CHANNEL',
    defaultValue: 'local',
  ),
  commit: String.fromEnvironment(
    'APP_COMMIT',
    defaultValue: 'unknown',
  ),
);
