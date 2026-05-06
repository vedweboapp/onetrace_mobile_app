import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:red5/features/clients/data/client_models.dart';

final clientsStoreProvider =
    StateNotifierProvider<ClientsStore, List<ClientModel>>((ref) {
  return ClientsStore.initial();
});

final class ClientsStore extends StateNotifier<List<ClientModel>> {
  ClientsStore(super.state);

  factory ClientsStore.initial() {
    return ClientsStore(<ClientModel>[
      const ClientModel(
        id: 'c_001',
        createdAt: '',
        modifiedAt: '',
        name: 'Apex Structural Group',
        contactPerson: 'Jonathan Miller',
        email: 'jonathan.miller@apex.com',
        phone: '+1 (555) 124-8902',
        addressLine1: '4500 Industrial Parkway',
        addressLine2: 'Suite 200',
        city: 'Chicago',
        state: 'IL',
        country: 'United States',
        pincode: '60601',
        isActive: true,
      ),
      const ClientModel(
        id: 'c_002',
        createdAt: '',
        modifiedAt: '',
        name: 'Summit Development Corp',
        contactPerson: 'Jonathan Miller',
        email: 'jonathan.miller@summit.com',
        phone: '+1 (555) 124-8902',
        addressLine1: '12 Main Street',
        addressLine2: '',
        city: 'New York',
        state: 'NY',
        country: 'United States',
        pincode: '10001',
        isActive: false,
      ),
      const ClientModel(
        id: 'c_003',
        createdAt: '',
        modifiedAt: '',
        name: 'Blue Horizon Architects',
        contactPerson: 'Jonathan Miller',
        email: 'jonathan.miller@bluehorizon.com',
        phone: '+1 (555) 124-8902',
        addressLine1: '88 Lake View',
        addressLine2: '',
        city: 'Austin',
        state: 'TX',
        country: 'United States',
        pincode: '73301',
        isActive: true,
      ),
      const ClientModel(
        id: 'c_004',
        createdAt: '',
        modifiedAt: '',
        name: 'Legacy Infrastructure Partners',
        contactPerson: 'Jonathan Miller',
        email: 'jonathan.miller@legacy.com',
        phone: '+1 (555) 124-8902',
        addressLine1: '10 Harbor Road',
        addressLine2: '',
        city: 'Seattle',
        state: 'WA',
        country: 'United States',
        pincode: '98101',
        isActive: false,
      ),
    ]);
  }

  void add(ClientModel client) {
    state = <ClientModel>[client, ...state];
  }
}

