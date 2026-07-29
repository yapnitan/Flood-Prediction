/// Approximate lat/lng lookup for Malaysian states and districts.
///
/// The official JPS/DID historical flood dataset has no coordinates, only
/// State/District names. This table lets [HistoricalFloodService] derive an
/// approximate coordinate for each imported record so "nearby records"
/// search is possible.
///
/// Coordinates are bounding-box centers of Malaysia's administrative
/// district boundaries (source: mptwaktusolat/jakim.geojson, itself derived
/// from JAKIM prayer-zone boundaries, which align with official district
/// boundaries). They are centroids of a district/state, not precise flood
/// locations — good enough for "which historical floods happened near here"
/// ranking, not for pinpoint mapping.
class _Coord {
  final double lat;
  final double lng;
  const _Coord(this.lat, this.lng);
}

class MalaysiaGeocoder {
  MalaysiaGeocoder._();

  /// Malaysia's 13 states + 3 federal territories, in the naming used
  /// throughout this app (matches the DID dataset's "WP ..." style).
  static const List<String> states = [
    'Johor',
    'Kedah',
    'Kelantan',
    'Melaka',
    'Negeri Sembilan',
    'Pahang',
    'Perak',
    'Perlis',
    'Pulau Pinang',
    'Sabah',
    'Sarawak',
    'Selangor',
    'Terengganu',
    'WP Kuala Lumpur',
    'WP Labuan',
    'WP Putrajaya',
  ];

  /// Best-effort centroid for [district] within [state]. Tries an exact
  /// district match first, then falls back to the state centroid, then
  /// null if neither is recognized.
  static (double lat, double lng)? centroidFor({
    required String state,
    String? district,
  }) {
    if (district != null && district.trim().isNotEmpty) {
      final coord = _districtCentroids[_normalize(district)];
      if (coord != null) return (coord.lat, coord.lng);
    }

    final stateCoord = _stateCentroids[_normalize(state)];
    if (stateCoord != null) return (stateCoord.lat, stateCoord.lng);

    return null;
  }

  static String _normalize(String s) =>
      s.toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');

  // District centroids (bounding-box center of JAKIM district boundaries).
  static const Map<String, _Coord> _districtCentroids = {
    'alor gajah': _Coord(2.383510, 102.106500),
    'asajaya': _Coord(1.531625, 110.610110),
    'bachok': _Coord(6.027615, 102.373875),
    'bagan datuk': _Coord(3.877430, 100.972085),
    'baling': _Coord(5.723155, 100.862395),
    'bandar baharu': _Coord(5.207200, 100.616525),
    'barat daya': _Coord(5.362050, 100.245650),
    'batang padang': _Coord(4.118290, 101.290910),
    'batu pahat': _Coord(1.913215, 103.015385),
    'bau': _Coord(1.383520, 110.101050),
    'beaufort': _Coord(5.291295, 115.704555),
    'belaga': _Coord(2.660855, 114.274995),
    'beluran': _Coord(6.199915, 117.313095),
    'beluru': _Coord(3.552215, 114.339225),
    'bentong': _Coord(3.416345, 102.050275),
    'bera': _Coord(3.136035, 102.538165),
    'besut': _Coord(5.647385, 102.577420),
    'betong': _Coord(1.481830, 111.483500),
    'bintulu': _Coord(3.313910, 113.201905),
    'bukit mabong': _Coord(1.765550, 113.876390),
    'cameron highlands': _Coord(4.468675, 101.469035),
    'dalat': _Coord(2.696945, 111.994420),
    'daro': _Coord(2.565260, 111.445100),
    'dungun': _Coord(4.682510, 103.145255),
    'gombak': _Coord(3.277000, 101.641260),
    'gua musang': _Coord(5.023675, 102.054355),
    'hilir perak': _Coord(4.018080, 101.062485),
    'hulu perak': _Coord(5.449125, 101.309935),
    'hulu terengganu': _Coord(5.075095, 102.821405),
    'jasin': _Coord(2.293300, 102.452615),
    'jelebu': _Coord(3.059975, 102.134185),
    'jeli': _Coord(5.580770, 101.819425),
    'jempol': _Coord(2.867975, 102.468405),
    'jerantut': _Coord(4.258565, 102.544805),
    'johor bahru': _Coord(1.480505, 103.782305),
    'julau': _Coord(1.818305, 111.964055),
    'kabong': _Coord(1.875910, 111.260235),
    'kalabakan': _Coord(4.482985, 117.413635),
    'kampar': _Coord(4.393485, 101.217710),
    'kanowit': _Coord(1.933875, 112.216625),
    'kapit': _Coord(2.175795, 113.185525),
    'kecil lojing': _Coord(4.772050, 101.588565),
    'kemaman': _Coord(4.240630, 103.191920),
    'keningau': _Coord(5.220590, 116.330635),
    'kerian': _Coord(4.988310, 100.548990),
    'kinabatangan': _Coord(5.331805, 118.125410),
    'kinta': _Coord(4.515585, 101.160745),
    'klang': _Coord(3.037315, 101.395560),
    'kluang': _Coord(2.049095, 103.371855),
    'kota belud': _Coord(6.359225, 116.466690),
    'kota bharu': _Coord(6.056225, 102.246250),
    'kota kinabalu': _Coord(5.999865, 116.104395),
    'kota marudu': _Coord(6.449675, 116.836480),
    'kota setar': _Coord(6.101370, 100.366610),
    'kota tinggi': _Coord(1.691440, 103.923465),
    'kuala kangsar': _Coord(4.799620, 101.097090),
    'kuala krai': _Coord(5.428315, 102.117725),
    'kuala langat': _Coord(2.812940, 101.482760),
    'kuala muda': _Coord(5.715575, 100.501505),
    'kuala nerus': _Coord(5.524045, 103.024130),
    'kuala penyu': _Coord(5.505795, 115.515110),
    'kuala pilah': _Coord(2.723010, 102.222925),
    'kuala selangor': _Coord(3.379540, 101.297520),
    'kuala terengganu': _Coord(5.280305, 103.082020),
    'kuantan': _Coord(3.897565, 103.076750),
    'kubang pasu': _Coord(6.362560, 100.399740),
    'kuching': _Coord(1.428430, 110.320230),
    'kudat': _Coord(7.003630, 117.129360),
    'kulai': _Coord(1.664170, 103.550330),
    'kulim': _Coord(5.403050, 100.696095),
    'kunak': _Coord(4.685785, 118.032240),
    'lahad datu': _Coord(5.118435, 118.366545),
    'langkawi': _Coord(6.315365, 99.792935),
    'larut dan matang': _Coord(4.812915, 100.732330),
    'lawas': _Coord(4.454645, 115.410590),
    'limbang': _Coord(4.352435, 115.147090),
    'lipis': _Coord(4.342810, 101.879390),
    'lubok antu': _Coord(1.287090, 111.856595),
    'lundu': _Coord(1.749525, 109.864880),
    'machang': _Coord(5.771795, 102.271190),
    'manjung': _Coord(4.276795, 100.701090),
    'maradong': _Coord(2.167100, 111.624225),
    'maran': _Coord(3.600550, 102.673180),
    'marang': _Coord(5.058710, 103.216060),
    'marudi': _Coord(4.177115, 114.593365),
    'matu': _Coord(2.648985, 111.701765),
    'melaka tengah': _Coord(2.192180, 102.243470),
    'mersing': _Coord(2.353220, 103.918685),
    'miri': _Coord(3.787580, 114.729625),
    'muallim': _Coord(3.897530, 101.435130),
    'muar': _Coord(2.133235, 102.784665),
    'mukah': _Coord(2.812545, 112.350970),
    'nabawan': _Coord(4.693030, 116.464165),
    'padang terap': _Coord(6.234040, 100.679815),
    'pakan': _Coord(1.781910, 111.693755),
    'papar': _Coord(5.602560, 116.042275),
    'pasir mas': _Coord(6.020030, 102.071245),
    'pasir puteh': _Coord(5.841995, 102.399685),
    'pekan': _Coord(3.303070, 103.122350),
    'penampang': _Coord(5.839580, 116.195620),
    'pendang': _Coord(5.981705, 100.544720),
    'perak tengah': _Coord(4.264425, 100.932655),
    'perlis': _Coord(6.491355, 100.245825),
    'petaling': _Coord(3.104900, 101.579100),
    'pitas': _Coord(6.730620, 117.071975),
    'pokok sena': _Coord(6.167260, 100.540445),
    'pontian': _Coord(1.514265, 103.383510),
    'port dickson': _Coord(2.556845, 101.866430),
    'pusa': _Coord(1.548285, 111.159030),
    'putatan': _Coord(5.881470, 116.060495),
    'ranau': _Coord(5.898225, 116.782850),
    'raub': _Coord(3.872660, 101.832000),
    'rembau': _Coord(2.564645, 102.111675),
    'rompin': _Coord(2.919460, 103.459430),
    'sabak bernam': _Coord(3.678675, 101.079285),
    'samarahan': _Coord(1.438020, 110.476780),
    'sandakan': _Coord(5.809575, 117.980665),
    'saratok': _Coord(1.765515, 111.398360),
    'sarikei': _Coord(2.067190, 111.416450),
    'sebauh': _Coord(3.151020, 113.529120),
    'seberang perai selatan': _Coord(5.210425, 100.468350),
    'seberang perai tengah': _Coord(5.364500, 100.449120),
    'seberang perai utara': _Coord(5.484335, 100.432475),
    'segamat': _Coord(2.499785, 102.992735),
    'selama': _Coord(5.253685, 100.788545),
    'selangau': _Coord(2.498055, 112.420495),
    'semporna': _Coord(4.394420, 118.608230),
    'sepang': _Coord(2.805410, 101.681090),
    'seremban': _Coord(2.755985, 101.908985),
    'serian': _Coord(1.113690, 110.636760),
    'setiu': _Coord(5.455425, 102.794630),
    'sibu': _Coord(2.292280, 111.866555),
    'sik': _Coord(5.984405, 100.864240),
    'simunjan': _Coord(1.272195, 110.817355),
    'sipitang': _Coord(4.633510, 115.650535),
    'song': _Coord(1.814590, 112.475050),
    'sri aman': _Coord(1.212715, 111.300160),
    'subis': _Coord(3.759635, 113.727590),
    'tambunan': _Coord(5.687110, 116.376860),
    'tampin': _Coord(2.547030, 102.416770),
    'tanah merah': _Coord(5.725075, 102.029860),
    'tangkak': _Coord(2.262080, 102.649785),
    'tanjung manis': _Coord(2.283320, 111.321030),
    'tatau': _Coord(2.627775, 113.169035),
    'tawau': _Coord(4.434365, 118.027905),
    'tebedu': _Coord(1.035175, 110.450840),
    'telang usan': _Coord(3.314230, 114.775210),
    'telupid': _Coord(5.784615, 117.133115),
    'temerloh': _Coord(3.606815, 102.259125),
    'tenom': _Coord(4.910710, 115.943365),
    'timur laut': _Coord(5.393060, 100.290555),
    'tongod': _Coord(5.067070, 116.966480),
    'tuaran': _Coord(6.063480, 116.311815),
    'tumpat': _Coord(6.166615, 102.163015),
    'ulu langat': _Coord(3.074900, 101.845620),
    'ulu selangor': _Coord(3.564190, 101.567090),
    'yan': _Coord(5.847800, 100.370420),

    // Aliases for common alternate spellings used in the DID dataset.
    'hulu langat': _Coord(3.074900, 101.845620),
    'hulu selangor': _Coord(3.564190, 101.567090),
    'kuala lumpur': _Coord(3.142075, 101.686095),
    'labuan': _Coord(5.289335, 115.225540),
    'putrajaya': _Coord(2.929565, 101.694850),
    'w.p. kuala lumpur': _Coord(3.142075, 101.686095),
    'w.p. labuan': _Coord(5.289335, 115.225540),
    'w.p. putrajaya': _Coord(2.929565, 101.694850),
    'wp kuala lumpur': _Coord(3.142075, 101.686095),
    'wp labuan': _Coord(5.289335, 115.225540),
    'wp putrajaya': _Coord(2.929565, 101.694850),
    'barat daya pulau pinang': _Coord(5.362050, 100.245650),
    'timur laut pulau pinang': _Coord(5.393060, 100.290555),
  };

  // State-level fallback centroids, used when a district has no match above.
  static const Map<String, _Coord> _stateCentroids = {
    'johor': _Coord(2.047250, 103.508140),
    'kedah': _Coord(5.809340, 100.383260),
    'kelantan': _Coord(5.395240, 102.001070),
    'kuala lumpur': _Coord(3.142075, 101.686095),
    'labuan': _Coord(5.289335, 115.225540),
    'melaka': _Coord(2.272435, 102.219950),
    'negeri sembilan': _Coord(2.839715, 102.200690),
    'pahang': _Coord(3.618450, 102.777220),
    'perak': _Coord(4.800570, 101.057535),
    'perlis': _Coord(6.491355, 100.245825),
    'pulau pinang': _Coord(5.354410, 100.364235),
    'penang': _Coord(5.354410, 100.364235),
    'putrajaya': _Coord(2.929565, 101.694850),
    'sabah': _Coord(5.714110, 117.300765),
    'sarawak': _Coord(2.923610, 112.605400),
    'selangor': _Coord(3.233395, 101.390295),
    'terengganu': _Coord(4.922515, 102.936310),
    'wp kuala lumpur': _Coord(3.142075, 101.686095),
    'wp labuan': _Coord(5.289335, 115.225540),
    'wp putrajaya': _Coord(2.929565, 101.694850),
  };
}
