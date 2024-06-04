import 'package:collection/collection.dart';
import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:salvador_task_management/src/config/providers.dart';
import 'package:salvador_task_management/src/models/intervento_model.dart';

part 'interventi_db_repository.g.dart';

// use this only for underlying db operations. use the InterventiStateRepository for operations.
@Riverpod()
class InterventiDbOpRepository extends _$InterventiDbOpRepository {
  @override
  Future<List<Intervento>> build() async {
    var erpdb = await ref.read(erpdbProvider.future);
    var erpinterventi = await erpdb.interventos.where().build().findAllAsync();

    var localdb = await ref.read(localdbProvider.future);
    var localinterventi =
        await localdb.interventos.where().build().findAllAsync();

    // var archividb = await ref.read(archividbProvider.future);
    // var archivinterventi =
    //     await archividb.interventos.where().build().findAllAsync();

    var result = [
      ...erpinterventi.where(
          (ei) => !localinterventi.any((li) => li.idTestata == ei.idTestata)),
      ...localinterventi,
      //...archivinterventi
    ];

    return result;
  }

  Future<void> deleteInterventoById(int idTestata) async {
    try {
      var db = await ref.read(localdbProvider.future);

      await db.writeAsync((isar) {
        isar.interventos.delete(idTestata);
      });
    } catch (e) {
      print('Error deleting Intervento: $e');
    }
  }

  // no need to read from db. we work with the in memory data - see parameter keepAlive : true
  // Future<int?> findDocIdByNumDoc(String? numDoc) async {
  //   var db = await ref.read(localdbProvider.future);
  //   var intervento = db.interventos.where().numDocEqualTo(numDoc).findFirst();

  //   return intervento?.idTestata;
  // }

  Future<void> updateInterventiErp(List<Intervento> erpinterventi) async {
    //state = const AsyncLoading();
    var db = await ref.read(erpdbProvider.future);
    await db.writeAsync((isar) {
      isar.interventos.putAll(erpinterventi);
    });
    //state = AsyncData(erpinterventi);
  }

  Future<void> addOrUpdate(Intervento nuovoIntervento) async {
    var db = await ref.read(localdbProvider.future);
    await db.writeAsync((isar) {
      isar.interventos.put(nuovoIntervento);
    });

    var archividb = await ref.read(archividbProvider.future);
    await archividb.writeAsync((isar) {
      isar.interventos.put(nuovoIntervento);
    });
  }

  // no need to read from db. we work with the in memory data - see parameter keepAlive : true
  // Future<String?> getUltimoNumeroDocumento() async {
  //   var db = await ref.read(localdbProvider.future);
  //   var interventi = await db.interventos.where().findAllAsync();

  //   if (interventi.isNotEmpty) {
  //     interventi.sort((a, b) => b.dataDoc.compareTo(a.dataDoc));
  //     var ultimoIntervento = interventi.first;
  //     return ultimoIntervento.numDoc;
  //   } else {
  //     return null;
  //   }
  // }
}

@Riverpod(keepAlive: true)
class InterventiStateRepository extends _$InterventiStateRepository {
  @override
  Future<List<Intervento>> build() async {
    var interventi = await ref.read(interventiDbOpRepositoryProvider.future);

    return interventi;
  }

  Future<void> deleteInterventoById(int idTestata) async {
    try {
      var interventiDb = ref.read(interventiDbOpRepositoryProvider.notifier);
      await interventiDb.deleteInterventoById(idTestata);

      var interventi = state.asData!.value;
      interventi.removeWhere((element) => element.idTestata == idTestata);
      state = AsyncData(interventi);
    } catch (e) {
      print('Error deleting Intervento: $e');
    }
  }

  Future<int?> findDocIdByNumDoc(String? numDoc) async {
    // we use the isDirty property to search localdb elements from the inmemory total collection
    var interventi = state.asData!.value.where((element) => element.isDirty);

    var intervento =
        interventi.firstWhereOrNull((element) => element.numDoc == numDoc);

    return intervento?.idTestata;
  }

  void updateInterventiErp(List<Intervento> erpinterventi) async {
    // todo - Please check this logic. I think here you wanted to reload everything not just the erp interventi
    var interventiDb = ref.read(interventiDbOpRepositoryProvider.notifier);
    await interventiDb.updateInterventiErp(erpinterventi);

    // from what i see here is a sync of interventi from the erp. what should happen to the interventi in localdb with same id?
    var interventi = state.asData!.value;
    for (var ei in erpinterventi) {
      final index = interventi.indexWhere((i) => i.idTestata == ei.idTestata);
      if (index > -1) {
        interventi[index] = ei;
      } else {
        interventi.add(ei);
      }
    }

    state = AsyncData(interventi);
  }

  Future<void> addOrUpdate(Intervento intervento) async {
    var interventiDb = ref.read(interventiDbOpRepositoryProvider.notifier);
    await interventiDb.addOrUpdate(intervento);

    var interventi = state.asData!.value;
    final index =
        interventi.indexWhere((i) => i.idTestata == intervento.idTestata);
    if (index > -1) {
      interventi[index] = intervento;
    } else {
      interventi.add(intervento);
    }

    state = AsyncData(interventi);
  }

  Future<String?> getUltimoNumeroDocumento() async {
    // we use the isDirty property to search localdb elements from the inmemory total collection
    var interventi =
        state.asData!.value.where((element) => element.isDirty).toList();

    interventi.sort((a, b) => b.dataDoc.compareTo(a.dataDoc));
    var ultimoIntervento = interventi.firstOrNull;

    return ultimoIntervento?.numDoc;
  }

  // with this method you force the refresh of the provider (it will reload everything from db)
  void refresh() async {
    ref.invalidateSelf();
  }
}
