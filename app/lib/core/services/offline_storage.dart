import 'package:hive/hive.dart';

import '../../features/delivery/models/delivery_model.dart';
import '../../shared/models/cash_collection_model.dart';

class OfflineStorage {
  static const deliveriesBox = 'paperpay_delivery_queue';
  static const cashCollectionsBox = 'paperpay_cash_queue';

  Future<void> saveDelivery(DeliveryModel delivery) async {
    final box = await Hive.openBox<DeliveryModel>(deliveriesBox);
    await box.put(delivery.id, delivery);
  }

  Future<List<DeliveryModel>> getPendingDeliveries() async {
    final box = await Hive.openBox<DeliveryModel>(deliveriesBox);
    return box.values.where((item) => !item.synced).toList()
      ..sort((a, b) => a.createdAt?.compareTo(b.createdAt ?? '') ?? 0);
  }

  Future<void> markDeliverySynced(String id) async {
    final box = await Hive.openBox<DeliveryModel>(deliveriesBox);
    final current = box.get(id);
    if (current != null) {
      await box.put(id, current.copyWith(synced: true));
    }
  }

  Future<void> clearSyncedDeliveries() async {
    final box = await Hive.openBox<DeliveryModel>(deliveriesBox);
    final keys = box.keys.where((key) => box.get(key)?.synced == true).toList();
    if (keys.isNotEmpty) {
      await box.deleteAll(keys);
    }
  }

  Future<void> saveCashCollection(CashCollectionModel cash) async {
    final box = await Hive.openBox<CashCollectionModel>(cashCollectionsBox);
    await box.put(cash.id, cash);
  }

  Future<List<CashCollectionModel>> getPendingCashCollections() async {
    final box = await Hive.openBox<CashCollectionModel>(cashCollectionsBox);
    return box.values.where((item) => !item.synced).toList()
      ..sort((a, b) => a.createdAt?.compareTo(b.createdAt ?? '') ?? 0);
  }

  Future<void> markCashCollectionSynced(String id) async {
    final box = await Hive.openBox<CashCollectionModel>(cashCollectionsBox);
    final current = box.get(id);
    if (current != null) {
      await box.put(id, current.copyWith(synced: true));
    }
  }

  Future<void> clearSyncedCashCollections() async {
    final box = await Hive.openBox<CashCollectionModel>(cashCollectionsBox);
    final keys = box.keys.where((key) => box.get(key)?.synced == true).toList();
    if (keys.isNotEmpty) {
      await box.deleteAll(keys);
    }
  }
}
