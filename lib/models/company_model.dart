class CompanyModel {
  final String id;
  final String name;
  final String shortName;
  final String description;
  final String logoUrl;
  final String accentColorHex;
  final String address;
  final bool isActive;
  final DateTime createdAt;
  final List<String> branches;
  final List<String> departments;

  CompanyModel({
    required this.id,
    required this.name,
    required this.shortName,
    this.description = '',
    this.logoUrl = '',
    required this.accentColorHex,
    this.address = '',
    this.isActive = true,
    required this.createdAt,
    this.branches = const [],
    this.departments = const [],
  });

  factory CompanyModel.fromMap(Map<String, dynamic> map) {
    return CompanyModel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      shortName: map['short_name'] ?? '',
      description: map['description'] ?? '',
      logoUrl: map['logo_url'] ?? '',
      accentColorHex: map['accent_color_hex'] ?? '#60A5FA',
      address: map['address'] ?? '',
      isActive: map['is_active'] ?? true,
      createdAt: map['created_at'] != null
          ? DateTime.tryParse(map['created_at']) ?? DateTime.now()
          : DateTime.now(),
      branches: List<String>.from(map['branches'] ?? []),
      departments: List<String>.from(map['departments'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'short_name': shortName,
      'description': description,
      'logo_url': logoUrl,
      'accent_color_hex': accentColorHex,
      'address': address,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'branches': branches,
      'departments': departments,
    };
  }

  CompanyModel copyWith({
    String? id,
    String? name,
    String? shortName,
    String? description,
    String? logoUrl,
    String? accentColorHex,
    String? address,
    bool? isActive,
    DateTime? createdAt,
    List<String>? branches,
    List<String>? departments,
    String? website,
  }) {
    return CompanyModel(
      id: id ?? this.id,
      name: name ?? this.name,
      shortName: shortName ?? this.shortName,
      description: description ?? this.description,
      logoUrl: logoUrl ?? this.logoUrl,
      accentColorHex: accentColorHex ?? this.accentColorHex,
      address: address ?? this.address,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
      branches: branches ?? this.branches,
      departments: departments ?? this.departments,
    );
  }

  static List<CompanyModel> get defaultCompanies => [
    CompanyModel(
      id: 'c_001',
      name: 'Learning Saint',
      shortName: 'LS',
      description: 'Professional EdTech & Learning Platform',
      accentColorHex: '#F09B1A',
      address: 'Noida, Uttar Pradesh',
      createdAt: DateTime(2023, 1, 1),
      branches: ['Noida', 'Remote'],
      departments: ['USA Sales', 'UK Sales', 'Domestic Sales', 'HR', 'Tech', 'Marketing', 'Support', 'Accounts', 'Management'],
    ),
    CompanyModel(
      id: 'c_002',
      name: 'Khush Lifestyle',
      shortName: 'KL',
      description: 'Premium Fashion & Lifestyle Brand',
      accentColorHex: '#D5815A',
      address: 'B-127, Sector 69, Noida',
      createdAt: DateTime(2023, 1, 1),
      branches: ['Noida', 'Remote'],
      departments: ['Sales', 'Marketing', 'HR', 'Accounts', 'Design', 'Support', 'Management'],
    ),
    CompanyModel(
      id: 'c_003',
      name: 'Vibgyor',
      shortName: 'VB',
      description: 'Creative Services & Solutions',
      accentColorHex: '#6366F1',
      address: 'Noida, Uttar Pradesh',
      createdAt: DateTime(2023, 1, 1),
      branches: ['Noida', 'Kanpur', 'Remote'],
      departments: ['Creative', 'Sales', 'Marketing', 'HR', 'Accounts', 'Management'],
    ),
    CompanyModel(
      id: 'c_004',
      name: 'Possessive Panda',
      shortName: 'PP',
      description: 'Lifestyle & Retail Brand',
      accentColorHex: '#4ADE80',
      address: 'Noida, Uttar Pradesh',
      createdAt: DateTime(2023, 1, 1),
      branches: ['Noida', 'Remote'],
      departments: ['Sales', 'Marketing', 'HR', 'Accounts', 'Support', 'Management'],
    ),
  ];
}
