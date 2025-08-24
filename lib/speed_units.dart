enum SpeedUnit {
  kmh('km/h', 1.0),
  mph('mph', 0.621371),
  knots('kts', 0.539957);

  const SpeedUnit(this.label, this.multiplier);
  
  final String label;
  final double multiplier;
  
  double convert(double speedMps) {
    return speedMps * 3.6 * multiplier;
  }
  
  SpeedUnit get next {
    final values = SpeedUnit.values;
    final currentIndex = values.indexOf(this);
    return values[(currentIndex + 1) % values.length];
  }
}