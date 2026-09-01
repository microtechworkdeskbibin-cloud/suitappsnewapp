import 'package:suitapps/core/database/database_helper.dart';
import 'package:suitapps/features/customer/data/models/customer_model.dart';

class CustomerService {
  Future<int> insertCustomer(
    CustomerModel customer,
  ) async {
    final db = await DatabaseHelper.instance.database;

    return db.insert(
      'customers',
      customer.toMap(),
    );
  }

  Future<bool> customerExists(String mobile) async {
  final db = await DatabaseHelper.instance.database;

  final result = await db.query(
    'customers',
    where: 'mobile = ?',
    whereArgs: [mobile],
  );

  return result.isNotEmpty;
}

  Future<List<CustomerModel>> getCustomers() async {
    final db = await DatabaseHelper.instance.database;

    final result = await db.query('customers');

    return result
        .map((e) => CustomerModel.fromMap(e))
        .toList();
  }

  Future<int> updateCustomer(
    CustomerModel customer,
  ) async {
    final db = await DatabaseHelper.instance.database;

    return db.update(
      'customers',
      customer.toMap(),
      where: 'id=?',
      whereArgs: [customer.id],
    );
  }

  Future<int> deleteCustomer(int id) async {
    final db = await DatabaseHelper.instance.database;

    return db.delete(
      'customers',
      where: 'id=?',
      whereArgs: [id],
    );
  }
}
