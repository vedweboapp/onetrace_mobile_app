import 'package:flutter/material.dart';

enum EmployeeReportStockStatus { normal, critical, good }

extension EmployeeReportStockStatusX on EmployeeReportStockStatus {
  String get label => switch (this) {
        EmployeeReportStockStatus.normal => 'Normal',
        EmployeeReportStockStatus.critical => 'Critical',
        EmployeeReportStockStatus.good => 'Good',
      };

  Color get color => switch (this) {
        EmployeeReportStockStatus.normal => const Color(0xFF0B8F49),
        EmployeeReportStockStatus.critical => const Color(0xFFDC2626),
        EmployeeReportStockStatus.good => const Color(0xFF0B8F49),
      };
}

final class EmployeeReportProduct {
  const EmployeeReportProduct({
    required this.id,
    required this.name,
    required this.lastUpdated,
    required this.totalQuantity,
    required this.allocations,
  });

  final String id;
  final String name;
  final String lastUpdated;
  final String totalQuantity;
  final List<EmployeeReportSiteAllocation> allocations;
}

final class EmployeeReportSiteAllocation {
  const EmployeeReportSiteAllocation({
    required this.siteName,
    required this.quantityAllocated,
  });

  final String siteName;
  final String quantityAllocated;
}

final class EmployeeReportSite {
  const EmployeeReportSite({
    required this.id,
    required this.name,
    required this.address,
    required this.itemsTrackedLabel,
    required this.trackingIcon,
    required this.status,
    required this.lastUpdated,
    required this.inventory,
  });

  final String id;
  final String name;
  final String address;
  final String itemsTrackedLabel;
  final IconData trackingIcon;
  final String status;
  final String lastUpdated;
  final List<EmployeeReportInventoryItem> inventory;
}

final class EmployeeReportInventoryItem {
  const EmployeeReportInventoryItem({
    required this.name,
    required this.quantity,
    required this.icon,
    this.stockStatus,
    this.inTransitLabel,
  });

  final String name;
  final String quantity;
  final IconData icon;
  final EmployeeReportStockStatus? stockStatus;
  final String? inTransitLabel;
}

abstract final class EmployeeReportsData {
  EmployeeReportsData._();

  static const products = [
    EmployeeReportProduct(
      id: 'cement-opc',
      name: 'Cement (OPC)',
      lastUpdated: 'Today, 11:30 AM',
      totalQuantity: '750 Bags',
      allocations: [
        EmployeeReportSiteAllocation(
          siteName: 'Downtown Hub',
          quantityAllocated: '550 Bags',
        ),
        EmployeeReportSiteAllocation(
          siteName: 'Skyline Towers',
          quantityAllocated: '200 Bags',
        ),
      ],
    ),
    EmployeeReportProduct(
      id: 'tmt-steel',
      name: 'TMT Steel Bars',
      lastUpdated: 'Today, 9:15 AM',
      totalQuantity: '42.5 Tons',
      allocations: [
        EmployeeReportSiteAllocation(
          siteName: 'Downtown Hub',
          quantityAllocated: '12.5 Tons',
        ),
        EmployeeReportSiteAllocation(
          siteName: 'Riverside Yard',
          quantityAllocated: '30 Tons',
        ),
      ],
    ),
    EmployeeReportProduct(
      id: 'ready-mix',
      name: 'Ready-Mix Concrete',
      lastUpdated: 'Yesterday, 4:20 PM',
      totalQuantity: '18 Trucks',
      allocations: [
        EmployeeReportSiteAllocation(
          siteName: 'Downtown Hub',
          quantityAllocated: '4 Trucks',
        ),
        EmployeeReportSiteAllocation(
          siteName: 'Greenfield Site',
          quantityAllocated: '14 Trucks',
        ),
      ],
    ),
    EmployeeReportProduct(
      id: 'fly-ash-bricks',
      name: 'Fly Ash Bricks',
      lastUpdated: 'Today, 8:00 AM',
      totalQuantity: '12,000 Units',
      allocations: [
        EmployeeReportSiteAllocation(
          siteName: 'Skyline Towers',
          quantityAllocated: '12,000 Units',
        ),
      ],
    ),
  ];

  static const sites = [
    EmployeeReportSite(
      id: 'downtown-hub',
      name: 'Downtown Hub',
      address: 'Central District, Block A',
      itemsTrackedLabel: '8 items tracked',
      trackingIcon: Icons.inventory_2_outlined,
      status: 'ACTIVE',
      lastUpdated: 'Today, 10:45 AM',
      inventory: [
        EmployeeReportInventoryItem(
          name: 'Cement (OPC)',
          quantity: '550 Bags',
          icon: Icons.inventory_2_outlined,
          stockStatus: EmployeeReportStockStatus.normal,
        ),
        EmployeeReportInventoryItem(
          name: 'TMT Steel Bars',
          quantity: '12.5 Tons',
          icon: Icons.construction_outlined,
          stockStatus: EmployeeReportStockStatus.critical,
        ),
        EmployeeReportInventoryItem(
          name: 'Ready-Mix Concrete',
          quantity: '4 Trucks',
          icon: Icons.local_shipping_outlined,
          inTransitLabel: 'In Transit: 4 Trucks',
        ),
        EmployeeReportInventoryItem(
          name: 'Fly Ash Bricks',
          quantity: '2,400 Units',
          icon: Icons.grid_view_rounded,
          stockStatus: EmployeeReportStockStatus.good,
        ),
      ],
    ),
    EmployeeReportSite(
      id: 'north-view-residencies',
      name: 'North View Residencies',
      address: 'Lake District · Block C',
      itemsTrackedLabel: '12 items tracked',
      trackingIcon: Icons.inventory_2_outlined,
      status: 'ACTIVE',
      lastUpdated: 'Today, 8:20 AM',
      inventory: [
        EmployeeReportInventoryItem(
          name: 'Cement (OPC)',
          quantity: '120 Bags',
          icon: Icons.inventory_2_outlined,
          stockStatus: EmployeeReportStockStatus.normal,
        ),
        EmployeeReportInventoryItem(
          name: 'TMT Steel Bars',
          quantity: '4 Tons',
          icon: Icons.construction_outlined,
          stockStatus: EmployeeReportStockStatus.good,
        ),
      ],
    ),
    EmployeeReportSite(
      id: 'skyline-towers',
      name: 'Skyline Towers',
      address: 'North Ridge, Tower B',
      itemsTrackedLabel: '5 items tracked',
      trackingIcon: Icons.inventory_2_outlined,
      status: 'ACTIVE',
      lastUpdated: 'Today, 9:30 AM',
      inventory: [
        EmployeeReportInventoryItem(
          name: 'Cement (OPC)',
          quantity: '200 Bags',
          icon: Icons.inventory_2_outlined,
          stockStatus: EmployeeReportStockStatus.normal,
        ),
        EmployeeReportInventoryItem(
          name: 'Fly Ash Bricks',
          quantity: '12,000 Units',
          icon: Icons.grid_view_rounded,
          stockStatus: EmployeeReportStockStatus.good,
        ),
      ],
    ),
    EmployeeReportSite(
      id: 'riverside-yard',
      name: 'Riverside Yard',
      address: 'Riverfront Industrial Park',
      itemsTrackedLabel: '3 items tracked',
      trackingIcon: Icons.local_shipping_outlined,
      status: 'ACTIVE',
      lastUpdated: 'Yesterday, 3:10 PM',
      inventory: [
        EmployeeReportInventoryItem(
          name: 'TMT Steel Bars',
          quantity: '30 Tons',
          icon: Icons.construction_outlined,
          stockStatus: EmployeeReportStockStatus.normal,
        ),
      ],
    ),
    EmployeeReportSite(
      id: 'greenfield-site',
      name: 'Greenfield Site',
      address: 'East Expansion Zone',
      itemsTrackedLabel: '6 items tracked',
      trackingIcon: Icons.list_alt_outlined,
      status: 'ACTIVE',
      lastUpdated: 'Today, 7:55 AM',
      inventory: [
        EmployeeReportInventoryItem(
          name: 'Ready-Mix Concrete',
          quantity: '14 Trucks',
          icon: Icons.local_shipping_outlined,
          stockStatus: EmployeeReportStockStatus.normal,
        ),
      ],
    ),
  ];

  static EmployeeReportProduct? productById(String id) {
    for (final product in products) {
      if (product.id == id) return product;
    }
    return null;
  }

  static EmployeeReportSite? siteById(String id) {
    for (final site in sites) {
      if (site.id == id) return site;
    }
    return null;
  }
}
