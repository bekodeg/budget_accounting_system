enum AppSection {
  transactions('Операции'),
  planning('План'),
  reports('Отчеты'),
  settings('Настройки');

  const AppSection(this.label);

  final String label;
}
