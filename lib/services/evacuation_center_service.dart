import '../models/evacuation_center.dart';

class EvacuationCenterService {
  static final List<EvacuationCenter> _centers = [
    const EvacuationCenter(
      id: 'ec-1',
      name: 'Dewan Seri Selangor Evacuation Center',
      state: 'Selangor',
      district: 'Shah Alam',
      capacity: 450,
      currentOccupants: 310,
      status: 'Active',
      contactPerson: 'Ahmad Zaki',
      contactPhone: '012-3456789',
      latitude: 3.0733,
      longitude: 101.5185,
    ),
    const EvacuationCenter(
      id: 'ec-2',
      name: 'Kompleks Sukan Klang Relief Shelter',
      state: 'Selangor',
      district: 'Klang',
      capacity: 600,
      currentOccupants: 480,
      status: 'Active',
      contactPerson: 'Siti Nurhaliza',
      contactPhone: '013-9876543',
      latitude: 3.0449,
      longitude: 101.4456,
    ),
    const EvacuationCenter(
      id: 'ec-3',
      name: 'Dewan Jubilee Perak JB',
      state: 'Johor',
      district: 'Johor Bahru',
      capacity: 500,
      currentOccupants: 220,
      status: 'Active',
      contactPerson: 'Tan Mei Ling',
      contactPhone: '017-1122334',
      latitude: 1.4927,
      longitude: 103.7414,
    ),
    const EvacuationCenter(
      id: 'ec-4',
      name: 'Dewan Serbaguna Batu Pahat',
      state: 'Johor',
      district: 'Batu Pahat',
      capacity: 350,
      currentOccupants: 0,
      status: 'Standby',
      contactPerson: 'M. Muthusamy',
      contactPhone: '016-5544332',
      latitude: 1.8548,
      longitude: 102.9325,
    ),
    const EvacuationCenter(
      id: 'ec-5',
      name: 'Dewan Sultan Haji Ahmad Shah',
      state: 'Pahang',
      district: 'Kuantan',
      capacity: 700,
      currentOccupants: 650,
      status: 'Active',
      contactPerson: 'Rosli Ibrahim',
      contactPhone: '019-8877665',
      latitude: 3.8077,
      longitude: 103.3260,
    ),
    const EvacuationCenter(
      id: 'ec-6',
      name: 'Dewan MPOB Temerloh',
      state: 'Pahang',
      district: 'Temerloh',
      capacity: 400,
      currentOccupants: 400,
      status: 'Full',
      contactPerson: 'Hassan Basri',
      contactPhone: '011-22334455',
      latitude: 3.4484,
      longitude: 102.4176,
    ),
    const EvacuationCenter(
      id: 'ec-7',
      name: 'Dewan Kelantan Kota Bharu',
      state: 'Kelantan',
      district: 'Kota Bharu',
      capacity: 550,
      currentOccupants: 420,
      status: 'Active',
      contactPerson: 'Nik Faiz',
      contactPhone: '014-6655443',
      latitude: 6.1254,
      longitude: 102.2381,
    ),
    const EvacuationCenter(
      id: 'ec-8',
      name: 'Dewan Orang Ramai Kuala Terengganu',
      state: 'Terengganu',
      district: 'Kuala Terengganu',
      capacity: 380,
      currentOccupants: 150,
      status: 'Active',
      contactPerson: 'Wan Azman',
      contactPhone: '018-9988776',
      latitude: 5.3302,
      longitude: 103.1408,
    ),
    const EvacuationCenter(
      id: 'ec-9',
      name: 'Dewan Bandaraya Ipoh',
      state: 'Perak',
      district: 'Ipoh',
      capacity: 450,
      currentOccupants: 0,
      status: 'Standby',
      contactPerson: 'Chong Wei',
      contactPhone: '012-7766554',
      latitude: 4.5975,
      longitude: 101.0901,
    ),
    const EvacuationCenter(
      id: 'ec-10',
      name: 'Dewan Suka Menanti Alor Setar',
      state: 'Kedah',
      district: 'Kota Setar',
      capacity: 300,
      currentOccupants: 180,
      status: 'Active',
      contactPerson: 'Mahadzir Khalid',
      contactPhone: '013-4455667',
      latitude: 6.1184,
      longitude: 100.3685,
    ),
    const EvacuationCenter(
      id: 'ec-11',
      name: 'Dewan Suarah Kuching',
      state: 'Sarawak',
      district: 'Kuching',
      capacity: 650,
      currentOccupants: 90,
      status: 'Active',
      contactPerson: 'Abang Johari',
      contactPhone: '016-8899001',
      latitude: 1.5533,
      longitude: 110.3592,
    ),
    const EvacuationCenter(
      id: 'ec-12',
      name: 'Dewan Kebudayaan Kota Kinabalu',
      state: 'Sabah',
      district: 'Kota Kinabalu',
      capacity: 500,
      currentOccupants: 0,
      status: 'Standby',
      contactPerson: 'Joseph Pairin',
      contactPhone: '019-3322110',
      latitude: 5.9804,
      longitude: 116.0735,
    ),
    const EvacuationCenter(
      id: 'ec-13',
      name: 'Dewan Wawasan Kangar',
      state: 'Perlis',
      district: 'Kangar',
      capacity: 250,
      currentOccupants: 0,
      status: 'Standby',
      contactPerson: 'Syed Razlan',
      contactPhone: '017-9900112',
      latitude: 6.4414,
      longitude: 100.1986,
    ),
    const EvacuationCenter(
      id: 'ec-14',
      name: 'Dewan Belia Sentral KL',
      state: 'WP Kuala Lumpur',
      district: 'Kuala Lumpur',
      capacity: 400,
      currentOccupants: 60,
      status: 'Active',
      contactPerson: 'Lim Guan Eng',
      contactPhone: '012-9988776',
      latitude: 3.1340,
      longitude: 101.6869,
    ),
  ];

  /// Total evacuation center count breakdown per Malaysian state.
  static const Map<String, int> stateCenterCounts = {
    'Selangor': 142,
    'Johor': 118,
    'Pahang': 95,
    'Kelantan': 86,
    'Terengganu': 74,
    'Perak': 62,
    'Sarawak': 55,
    'Kedah': 48,
    'Sabah': 40,
    'Negeri Sembilan': 32,
    'Pulau Pinang': 28,
    'Melaka': 22,
    'WP Kuala Lumpur': 18,
    'Perlis': 15,
  };

  List<EvacuationCenter> getAllCenters() {
    return List.unmodifiable(_centers);
  }

  Map<String, int> getStateDemographics() {
    return stateCenterCounts;
  }

  void addCenter(EvacuationCenter center) {
    _centers.insert(0, center);
  }

  bool updateCenter(EvacuationCenter updated) {
    final index = _centers.indexWhere((c) => c.id == updated.id);
    if (index != -1) {
      _centers[index] = updated;
      return true;
    }
    return false;
  }

  bool deleteCenter(String id) {
    final index = _centers.indexWhere((c) => c.id == id);
    if (index != -1) {
      _centers.removeAt(index);
      return true;
    }
    return false;
  }
}
