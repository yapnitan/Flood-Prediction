
class WeatherData {
  final double latitude;
  final double longitude;
  final double temperatureCelsius;
  final double humidityPercent;
  final double rainfallMm;
  final int weatherCode;
  final DateTime observedAt;

  WeatherData({
    required this.latitude,
    required this.longitude,
    required this.temperatureCelsius,
    required this.humidityPercent,
    required this.rainfallMm,
    required this.weatherCode,
    required this.observedAt,
  });

  factory WeatherData.fromJson(
    Map<String, dynamic> json, {
    required double latitude,
    required double longitude,
  }) {
    final current = json['current'] as Map<String, dynamic>;
    return WeatherData(
      latitude: latitude,
      longitude: longitude,
      temperatureCelsius: (current['temperature_2m'] as num).toDouble(),
      humidityPercent: (current['relative_humidity_2m'] as num).toDouble(),
      rainfallMm: (current['precipitation'] as num).toDouble(),
      weatherCode: (current['weather_code'] as num).toInt(),
      observedAt: DateTime.parse(current['time'] as String),
    );
  }
  
  String get description => _wmoDescriptions[weatherCode] ?? 'Unknown';

  static const Map<int, String> _wmoDescriptions = {
    0: 'Clear sky',
    1: 'Mainly clear',
    2: 'Partly cloudy',
    3: 'Overcast',
    45: 'Fog',
    48: 'Depositing rime fog',
    51: 'Light drizzle',
    53: 'Moderate drizzle',
    55: 'Dense drizzle',
    61: 'Slight rain',
    63: 'Moderate rain',
    65: 'Heavy rain',
    66: 'Light freezing rain',
    67: 'Heavy freezing rain',
    71: 'Slight snow fall',
    73: 'Moderate snow fall',
    75: 'Heavy snow fall',
    80: 'Slight rain showers',
    81: 'Moderate rain showers',
    82: 'Violent rain showers',
    95: 'Thunderstorm',
    96: 'Thunderstorm with slight hail',
    99: 'Thunderstorm with heavy hail',
  };
}
