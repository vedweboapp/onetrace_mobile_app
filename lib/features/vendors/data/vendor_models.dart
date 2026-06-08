import 'package:flutter/material.dart';

class VendorListItem {
  const VendorListItem({
    required this.id,
    required this.name,
    required this.contactPerson,
    required this.phone,
    required this.isActive,
  });

  final String id;
  final String name;
  final String contactPerson;
  final String phone;
  final bool isActive;
}

class VendorAddress {
  const VendorAddress({
    required this.addressLine1,
    required this.addressLine2,
    required this.city,
    required this.state,
    required this.postalCode,
    required this.country,
  });

  final String addressLine1;
  final String addressLine2;
  final String city;
  final String state;
  final String postalCode;
  final String country;

  String get street {
    final a = addressLine1.trim();
    final b = addressLine2.trim();
    if (a.isEmpty && b.isEmpty) return '—';
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return '$a, $b';
  }
}

class VendorContactEntry {
  const VendorContactEntry({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.addressLine,
  });

  final String id;
  final String name;
  final String email;
  final String phone;
  final String addressLine;
}

class VendorProjectEntry {
  const VendorProjectEntry({
    required this.id,
    required this.name,
    required this.siteName,
    required this.status,
  });

  final String id;
  final String name;
  final String siteName;
  final String status;
}

class VendorDetail {
  const VendorDetail({
    required this.id,
    required this.name,
    required this.isActive,
    required this.contactPerson,
    required this.email,
    required this.phone,
    required this.address,
    required this.contacts,
    required this.projects,
  });

  final String id;
  final String name;
  final bool isActive;
  final String contactPerson;
  final String email;
  final String phone;
  final VendorAddress address;
  final List<VendorContactEntry> contacts;
  final List<VendorProjectEntry> projects;
}

/// Static preview data until vendor API exists.
abstract final class VendorMockData {
  VendorMockData._();

  static const _address = VendorAddress(
    addressLine1: '4500 Industrial Parkway, Suite 200',
    addressLine2: '',
    city: 'Chicago',
    state: 'IL',
    postalCode: '60601',
    country: 'United States',
  );

  static final VendorDetail primary = VendorDetail(
    id: '1',
    name: 'Apex Structural Group',
    isActive: true,
    contactPerson: 'Jonathan Miller',
    email: 'j.miller@apexstructural.com',
    phone: '+1 (555) 124-8902',
    address: _address,
    contacts: const [
      VendorContactEntry(
        id: 'c1',
        name: 'Jonathan Miller',
        email: 'j.miller@apexstructural.com',
        phone: '+1 (555) 124-8902',
        addressLine: '4500 Industrial Parkway, Suite 200, Chicago, IL 60601',
      ),
      VendorContactEntry(
        id: 'c2',
        name: 'a.richards@apexstructural.com',
        email: 'a.richards@apexstructural.com',
        phone: '+1 (555) 982-4410',
        addressLine: '4500 Industrial Parkway, Suite 200, Chicago, IL 60601',
      ),
    ],
    projects: const [
      VendorProjectEntry(
        id: 'p1',
        name: 'PRJ-2024-001',
        siteName: 'Metropolis Tower',
        status: 'Active',
      ),
      VendorProjectEntry(
        id: 'p2',
        name: 'PRJ-2024-014',
        siteName: 'Northwind Plaza',
        status: 'Planning',
      ),
    ],
  );

  static VendorDetail detailForId(String rawId) {
    final id = rawId.trim();
    if (id == '1' || id.toLowerCase() == 'apex-structural-group') {
      return primary;
    }
    VendorListItem? listMatch;
    for (final v in listItems) {
      if (v.id == id) {
        listMatch = v;
        break;
      }
    }
    if (listMatch != null) {
      return VendorDetail(
        id: listMatch.id,
        name: listMatch.name,
        isActive: listMatch.isActive,
        contactPerson: listMatch.contactPerson,
        email: '${listMatch.contactPerson.split(' ').first.toLowerCase()}@vendor.com',
        phone: listMatch.phone,
        address: _address,
        contacts: [
          VendorContactEntry(
            id: 'c-${listMatch.id}',
            name: listMatch.contactPerson,
            email: '${listMatch.contactPerson.split(' ').first.toLowerCase()}@vendor.com',
            phone: listMatch.phone,
            addressLine: '4500 Industrial Parkway, Suite 200, Chicago, IL 60601',
          ),
        ],
        projects: primary.projects,
      );
    }
    return VendorDetail(
      id: id,
      name: 'Vendor $id',
      isActive: true,
      contactPerson: 'Contact',
      email: 'contact@vendor.com',
      phone: '—',
      address: _address,
      contacts: const [],
      projects: const [],
    );
  }

  static final List<VendorListItem> listItems = [
    const VendorListItem(
      id: '1',
      name: 'Apex Structural Group',
      contactPerson: 'Jonathan Miller',
      phone: '+1 (555) 124-8902',
      isActive: true,
    ),
    const VendorListItem(
      id: '2',
      name: 'BuildPro Supply Co',
      contactPerson: 'Sarah Chen',
      phone: '+1 (555) 882-3301',
      isActive: true,
    ),
    const VendorListItem(
      id: '3',
      name: 'Northwind Materials',
      contactPerson: 'David Brooks',
      phone: '+1 (555) 441-2290',
      isActive: false,
    ),
    const VendorListItem(
      id: '4',
      name: 'Metropolis Urban Dev',
      contactPerson: 'Emily Watson',
      phone: '+1 (555) 903-1188',
      isActive: true,
    ),
    const VendorListItem(
      id: '5',
      name: 'Riverview Developments',
      contactPerson: 'Mark Thompson',
      phone: '+1 (555) 667-4402',
      isActive: false,
    ),
  ];
}

Color vendorStatusBg(bool active) =>
    active ? const Color(0xFFE9F9EE) : const Color(0xFFF1F1F2);

Color vendorStatusFg(bool active) =>
    active ? const Color(0xFF137333) : const Color(0xFF6B6B70);
