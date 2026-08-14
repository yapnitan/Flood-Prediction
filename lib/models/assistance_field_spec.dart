/// show form based on assistant type
library;

enum AssistanceFieldType { text, multiline, number, dropdown, multiSelect, checkbox }

class AssistanceField {
  const AssistanceField({
    required this.key,
    required this.label,
    required this.type,
    this.options = const [],
    this.required = false,
    this.hint,
  });

  final String key;
  final String label;
  final AssistanceFieldType type;

  final List<String> options;
  final bool required;
  final String? hint;
}

/// Shared with the Structural Repair spec and `PropertyFormView` so a
/// linked property's `property_type` lines up with the request field.
const List<String> propertyTypeOptions = ['House', 'Apartment/Condo', 'Shophouse', 'Other'];

const Map<String, List<AssistanceField>> assistanceFieldSpecs = {
  'Structural Repair': [
    AssistanceField(
      key: 'property_type',
      label: 'Property type',
      type: AssistanceFieldType.dropdown,
      options: propertyTypeOptions,
      required: true,
    ),
    AssistanceField(
      key: 'ownership_status',
      label: 'Ownership status',
      type: AssistanceFieldType.dropdown,
      options: ['Owner', 'Tenant', 'Other'],
      required: true,
    ),
    AssistanceField(
      key: 'number_of_floors',
      label: 'Number of floors',
      type: AssistanceFieldType.number,
    ),
    AssistanceField(
      key: 'damaged_areas',
      label: 'Damaged areas',
      type: AssistanceFieldType.multiSelect,
      options: ['Roof', 'Walls', 'Floor', 'Electrical System', 'Plumbing', 'Doors', 'Windows', 'Furniture'],
      required: true,
    ),
    AssistanceField(
      key: 'severity',
      label: 'Severity of damage',
      type: AssistanceFieldType.dropdown,
      options: ['Minor', 'Moderate', 'Severe', 'Total loss'],
      required: true,
    ),
    AssistanceField(
      key: 'estimated_repair_cost',
      label: 'Estimated repair cost (optional)',
      type: AssistanceFieldType.number,
      hint: 'RM',
    ),
  ],
  'Temporary Shelter': [
    AssistanceField(
      key: 'number_of_people',
      label: 'Number of people requiring shelter',
      type: AssistanceFieldType.number,
      required: true,
    ),
    AssistanceField(
      key: 'number_of_children',
      label: 'Number of children',
      type: AssistanceFieldType.number,
    ),
    AssistanceField(
      key: 'number_of_elderly',
      label: 'Number of elderly persons',
      type: AssistanceFieldType.number,
    ),
    AssistanceField(
      key: 'number_of_pwd',
      label: 'Number of persons with disabilities',
      type: AssistanceFieldType.number,
    ),
    AssistanceField(
      key: 'preferred_shelter',
      label: 'Preferred shelter / evacuation centre (optional)',
      type: AssistanceFieldType.text,
      hint: 'An admin will confirm the actual assigned shelter',
    ),
    AssistanceField(
      key: 'shelter_period',
      label: 'Required shelter period',
      type: AssistanceFieldType.dropdown,
      options: ['A few days', 'About a week', 'Two weeks or more', 'Not sure'],
      required: true,
    ),
    AssistanceField(
      key: 'special_requirements',
      label: 'Special requirements (optional)',
      type: AssistanceFieldType.multiline,
    ),
    AssistanceField(
      key: 'emergency_evacuation',
      label: 'Emergency evacuation required',
      type: AssistanceFieldType.checkbox,
    ),
  ],
  'Food & Water Supply': [
    AssistanceField(
      key: 'number_of_people',
      label: 'Number of affected people / households',
      type: AssistanceFieldType.number,
      required: true,
    ),
    AssistanceField(
      key: 'food_required',
      label: 'Food required',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'water_required',
      label: 'Water required',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'estimated_quantity',
      label: 'Estimated quantity',
      type: AssistanceFieldType.text,
      hint: 'e.g. 10 boxes / 5 days',
    ),
    AssistanceField(
      key: 'dietary_requirements',
      label: 'Dietary requirements (optional)',
      type: AssistanceFieldType.text,
    ),
    AssistanceField(
      key: 'preferred_delivery_date',
      label: 'Preferred delivery date (optional)',
      type: AssistanceFieldType.text,
      hint: 'e.g. 20/08/2026',
    ),
    AssistanceField(
      key: 'additional_notes',
      label: 'Additional notes (optional)',
      type: AssistanceFieldType.multiline,
    ),
  ],
  'Medical Assistance': [
    AssistanceField(
      key: 'number_of_people',
      label: 'Number of people requiring assistance',
      type: AssistanceFieldType.number,
      required: true,
    ),
    AssistanceField(
      key: 'medical_assistance_type',
      label: 'Type of medical assistance needed',
      type: AssistanceFieldType.multiSelect,
      options: ['First Aid', 'Medication', 'Medical Consultation', 'Transportation to Medical Facility'],
      required: true,
    ),
    AssistanceField(
      key: 'mobility_assistance',
      label: 'Mobility assistance required',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'emergency_transportation',
      label: 'Emergency transportation required',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'is_critical',
      label: 'This is a critical / life-threatening case',
      type: AssistanceFieldType.checkbox,
      hint: 'Critical cases are automatically flagged urgent and highlighted to admins',
    ),
  ],
  'Financial Aid': [
    AssistanceField(
      key: 'reason',
      label: 'Reason for requesting financial assistance',
      type: AssistanceFieldType.multiline,
      required: true,
    ),
    AssistanceField(
      key: 'affected_household_members',
      label: 'Number of affected household members',
      type: AssistanceFieldType.number,
    ),
    AssistanceField(
      key: 'employment_affected',
      label: 'Employment affected',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'business_affected',
      label: 'Business affected',
      type: AssistanceFieldType.checkbox,
    ),
    AssistanceField(
      key: 'estimated_financial_loss',
      label: 'Estimated financial loss (optional)',
      type: AssistanceFieldType.number,
      hint: 'RM',
    ),
    AssistanceField(
      key: 'requested_amount',
      label: 'Amount of assistance requested (optional)',
      type: AssistanceFieldType.number,
      hint: 'RM',
    ),
  ],
  'Other': [
    AssistanceField(
      key: 'assistance_type_text',
      label: 'Type of assistance required',
      type: AssistanceFieldType.text,
      required: true,
    ),
    AssistanceField(
      key: 'title',
      label: 'Title',
      type: AssistanceFieldType.text,
      required: true,
    ),
    AssistanceField(
      key: 'urgency',
      label: 'Urgency',
      type: AssistanceFieldType.dropdown,
      options: ['Low', 'Medium', 'High', 'Critical'],
      required: true,
    ),
  ],
};

/// The shared narrative box (`repair_request.damage_description`) is
/// labeled contextually per type, and skipped entirely for the two types
/// whose structured fields already cover it.
String? descriptionLabelFor(String assistanceType) {
  switch (assistanceType) {
    case 'Structural Repair':
      return 'Damage description';
    case 'Financial Aid':
      return 'Description of financial impact';
    case 'Other':
      return 'Detailed description';
    case 'Medical Assistance':
      return 'Situation description';
    case 'Temporary Shelter':
    case 'Food & Water Supply':
      return null;
    default:
      return 'Description';
  }
}

bool isDescriptionRequiredFor(String assistanceType) =>
    const {'Structural Repair', 'Financial Aid', 'Other', 'Medical Assistance'}.contains(assistanceType);
