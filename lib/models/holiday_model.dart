// ─────────────────────────────────────────────────────────────────────────────
// HolidayModel — represents a public / company holiday.
//
// Firestore collection: `holidays`
// Each document has:
//   id, name, date (ISO string), type (public/optional/restricted),
//   isNational (bool — Indian public holiday), applicable_departments ([])
//   — empty list means applies to ALL departments.
// ─────────────────────────────────────────────────────────────────────────────

class HolidayModel {
  final String id;
  final String name;
  final DateTime date;
  final String type;          // 'public' | 'optional' | 'restricted'
  final bool isNational;      // true = Indian public holiday (pre-seeded)
  final List<String> applicableDepartments; // empty = all depts

  const HolidayModel({
    required this.id,
    required this.name,
    required this.date,
    this.type = 'public',
    this.isNational = false,
    this.applicableDepartments = const [],
  });

  /// Returns true if this holiday applies to the given department.
  /// An empty applicableDepartments means it applies to ALL departments.
  bool appliesToDept(String dept) {
    if (applicableDepartments.isEmpty) return true;
    return applicableDepartments.contains(dept);
  }

  factory HolidayModel.fromMap(Map<String, dynamic> map) {
    return HolidayModel(
      id: map['id'] as String? ?? '',
      name: map['name'] as String? ?? '',
      date: map['date'] != null
          ? DateTime.tryParse(map['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      type: map['type'] as String? ?? 'public',
      isNational: map['is_national'] as bool? ?? false,
      applicableDepartments:
          (map['applicable_departments'] as List<dynamic>?)
                  ?.map((e) => e as String)
                  .toList() ??
              [],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'date': date.toIso8601String(),
      'type': type,
      'is_national': isNational,
      'applicable_departments': applicableDepartments,
    };
  }

  HolidayModel copyWith({
    String? name,
    DateTime? date,
    String? type,
    bool? isNational,
    List<String>? applicableDepartments,
  }) {
    return HolidayModel(
      id: id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      isNational: isNational ?? this.isNational,
      applicableDepartments:
          applicableDepartments ?? this.applicableDepartments,
    );
  }

  // ── Month / day helpers ────────────────────────────────────────────────────
  String get monthName {
    const m = [
      'January','February','March','April','May','June',
      'July','August','September','October','November','December'
    ];
    return m[date.month - 1];
  }

  String get shortMonthName {
    const m = ['Jan','Feb','Mar','Apr','May','Jun',
                'Jul','Aug','Sep','Oct','Nov','Dec'];
    return m[date.month - 1];
  }

  String get dayName {
    const d = ['Mon','Tue','Wed','Thu','Fri','Sat','Sun'];
    return d[date.weekday - 1];
  }

  String get typeLabel {
    switch (type) {
      case 'optional': return 'Optional';
      case 'restricted': return 'Restricted';
      default: return 'Public';
    }
  }

  bool get isUpcoming => date.isAfter(DateTime.now().subtract(const Duration(days: 1)));
}

// ─────────────────────────────────────────────────────────────────────────────
// Indian Public Holidays 2025 — pre-seeded defaults
// ─────────────────────────────────────────────────────────────────────────────
class IndianHolidays {
  static List<HolidayModel> get holidays2025 => [
    HolidayModel(id: 'h_republic_day',       name: "Republic Day",            date: DateTime(2025, 1, 26),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_maha_shivratri',     name: "Maha Shivratri",          date: DateTime(2025, 2, 26),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_holi',               name: "Holi",                    date: DateTime(2025, 3, 14),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_good_friday',        name: "Good Friday",             date: DateTime(2025, 4, 18),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_ram_navami',         name: "Ram Navami",              date: DateTime(2025, 4, 6),   type: 'public',     isNational: true),
    HolidayModel(id: 'h_ambedkar_jayanti',   name: "Ambedkar Jayanti",        date: DateTime(2025, 4, 14),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_labour_day',         name: "Labour Day",              date: DateTime(2025, 5, 1),   type: 'public',     isNational: true),
    HolidayModel(id: 'h_buddha_purnima',     name: "Buddha Purnima",          date: DateTime(2025, 5, 12),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_eid_ul_adha',        name: "Eid ul-Adha",             date: DateTime(2025, 6, 7),   type: 'public',     isNational: true),
    HolidayModel(id: 'h_muharram',           name: "Muharram",                date: DateTime(2025, 7, 6),   type: 'public',     isNational: true),
    HolidayModel(id: 'h_independence_day',   name: "Independence Day",        date: DateTime(2025, 8, 15),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_janmashtami',        name: "Krishna Janmashtami",     date: DateTime(2025, 8, 16),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_ganesh_chaturthi',   name: "Ganesh Chaturthi",        date: DateTime(2025, 8, 27),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_milad_un_nabi',      name: "Milad-un-Nabi",           date: DateTime(2025, 9, 5),   type: 'public',     isNational: true),
    HolidayModel(id: 'h_gandhi_jayanti',     name: "Gandhi Jayanti",          date: DateTime(2025, 10, 2),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_dussehra',           name: "Dussehra (Vijayadashami)", date: DateTime(2025, 10, 2), type: 'public',     isNational: true),
    HolidayModel(id: 'h_diwali',             name: "Diwali",                  date: DateTime(2025, 10, 20), type: 'public',     isNational: true),
    HolidayModel(id: 'h_diwali_extra',       name: "Diwali Holiday",          date: DateTime(2025, 10, 21), type: 'public',     isNational: true),
    HolidayModel(id: 'h_govardhan_puja',     name: "Govardhan Puja",          date: DateTime(2025, 10, 22), type: 'public',     isNational: true),
    HolidayModel(id: 'h_bhai_dooj',          name: "Bhai Dooj",               date: DateTime(2025, 10, 23), type: 'public',     isNational: true),
    HolidayModel(id: 'h_guru_nanak',         name: "Guru Nanak Jayanti",      date: DateTime(2025, 11, 5),  type: 'public',     isNational: true),
    HolidayModel(id: 'h_christmas',          name: "Christmas Day",           date: DateTime(2025, 12, 25), type: 'public',     isNational: true),
    // Optional holidays
    HolidayModel(id: 'h_lohri',              name: "Lohri",                   date: DateTime(2025, 1, 13),  type: 'optional',   isNational: false),
    HolidayModel(id: 'h_makar_sankranti',    name: "Makar Sankranti",         date: DateTime(2025, 1, 14),  type: 'optional',   isNational: false),
    HolidayModel(id: 'h_pongal',             name: "Pongal",                  date: DateTime(2025, 1, 14),  type: 'optional',   isNational: false),
    HolidayModel(id: 'h_vasant_panchami',    name: "Vasant Panchami",         date: DateTime(2025, 2, 2),   type: 'optional',   isNational: false),
    HolidayModel(id: 'h_new_year',           name: "New Year's Day",          date: DateTime(2025, 1, 1),   type: 'optional',   isNational: false),
    HolidayModel(id: 'h_eid_ul_fitr',        name: "Eid ul-Fitr",             date: DateTime(2025, 3, 31),  type: 'optional',   isNational: false),
    HolidayModel(id: 'h_mahavir_jayanti',    name: "Mahavir Jayanti",         date: DateTime(2025, 4, 10),  type: 'optional',   isNational: false),
    HolidayModel(id: 'h_christmas_eve',      name: "Christmas Eve",           date: DateTime(2025, 12, 24), type: 'optional',   isNational: false),
  ];
}
