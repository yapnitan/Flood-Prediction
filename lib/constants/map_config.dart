import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

final kMalaysiaMapBounds = LatLngBounds(
  const LatLng(0.5, 99.0),
  const LatLng(7.8, 120.0),
);

final kMalaysiaCameraConstraint = CameraConstraint.contain(bounds: kMalaysiaMapBounds);

const kMapInteractionFlags = InteractiveFlag.all & ~InteractiveFlag.rotate;

const kMapInteractionOptions = InteractionOptions(flags: kMapInteractionFlags);
