/// The 11 asset categories an Asset Loss Report can be filed under, plus a
/// handful of example items per category offered as quick-pick suggestions
/// — the specific asset name itself stays free text (not hardcoded into the
/// database), so "Other"/anything not listed can still be typed in.
const Map<String, List<String>> assetCategoryExamples = {
  'Building': [
    'Roof', 'Ceiling', 'Walls', 'Flooring', 'Doors', 'Windows', 'Gates',
    'Fences', 'Plumbing', 'Electrical wiring', 'Air-conditioning system',
    'Water heater',
  ],
  'Furniture': [
    'Sofa', 'Bed', 'Mattress', 'Table', 'Chair', 'Wardrobe', 'Cupboard',
    'Bookshelf', 'Desk', 'Office chair', 'Curtains', 'Carpet',
  ],
  'Appliances': [
    'Refrigerator', 'Freezer', 'Washing machine', 'Dryer', 'Television',
    'Microwave', 'Oven', 'Rice cooker', 'Fan', 'Air conditioner',
    'Vacuum cleaner',
  ],
  'Electronics': [
    'Desktop computer', 'Laptop', 'Monitor', 'Printer', 'Router',
    'Game console', 'External hard drive',
  ],
  'Personal Items': [
    'Clothing', 'Shoes', 'Bags', 'Watches', 'Jewelry', 'Books',
    'School supplies', 'Toys', 'Sports equipment', 'Personal documents',
  ],
  'Kitchen Items': [
    'Plates', 'Bowls', 'Cups', 'Glasses', 'Cutlery', 'Pots', 'Pans',
    'Kitchen utensils',
  ],
  'Vehicle': ['Car', 'Motorcycle', 'Van', 'Bicycle', 'Scooter'],
  'Outdoor Assets': [
    'Garden furniture', 'Plants', 'Gardening equipment', 'Lawn mower',
    'Outdoor equipment',
  ],
  'Tools & Equipment': [
    'Power tools', 'Hand tools', 'Drill', 'Saw', 'Toolbox', 'Machinery',
    'Workshop equipment',
  ],
  'Business Assets': [
    'Inventory', 'Business equipment', 'Machinery', 'POS system',
    'Computers', 'Furniture', 'Raw materials', 'Storage equipment',
  ],
  'Other': [],
};

const List<String> assetCategories = [
  'Building', 'Furniture', 'Appliances', 'Electronics', 'Personal Items',
  'Kitchen Items', 'Vehicle', 'Outdoor Assets', 'Tools & Equipment',
  'Business Assets', 'Other',
];

/// DB-stored value -> display label for asset condition.
const Map<String, String> assetConditionLabels = {
  'damaged': 'Damaged',
  'severely_damaged': 'Severely Damaged',
  'completely_destroyed': 'Completely Destroyed',
  'lost': 'Lost',
};

const List<String> assetConditions = [
  'damaged', 'severely_damaged', 'completely_destroyed', 'lost',
];

const Map<String, String> verificationResultLabels = {
  'verified': 'Verified',
  'not_verified': 'Not Verified',
  'partially_verified': 'Partially Verified',
};

const List<String> verificationResults = [
  'verified', 'not_verified', 'partially_verified',
];

const Map<String, String> assetLossStatusLabels = {
  'pending_review': 'Pending Review',
  'verified': 'Verified',
  'rejected': 'Rejected',
};
