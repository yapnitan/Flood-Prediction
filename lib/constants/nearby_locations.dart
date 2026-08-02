/// A well-known point of interest offered as a quick-pick suggestion on
/// location-picking steps (flood reports, repair requests), alongside
/// "Use current location" and free-text search.
class ReportLocation {
  final String name;
  final double latitude;
  final double longitude;

  const ReportLocation(this.name, this.latitude, this.longitude);
}

const List<ReportLocation> kNearbyLocations = <ReportLocation>[
  ReportLocation('Jalan Tun Razak, Kuala Lumpur', 3.1688, 101.7203),
  ReportLocation('Bukit Bintang, Kuala Lumpur', 3.1466, 101.7108),
  ReportLocation('KL Sentral, Kuala Lumpur', 3.1340, 101.6869),
  ReportLocation('Bangsar, Kuala Lumpur', 3.1279, 101.6719),
  ReportLocation('Petaling Jaya, Selangor', 3.1073, 101.6067),
  ReportLocation('Shah Alam, Selangor', 3.0733, 101.5185),
  ReportLocation('Gombak, Selangor', 3.2382, 101.7223),
];
