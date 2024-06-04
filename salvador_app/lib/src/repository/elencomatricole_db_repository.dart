import 'package:isar/isar.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:salvador_task_management/src/config/providers.dart';
import 'package:salvador_task_management/src/models/elencomatricole_model.dart';

part 'elencomatricole_db_repository.g.dart';

@Riverpod(keepAlive: true)
class ElencoMatricoleDbRepository extends _$ElencoMatricoleDbRepository {
  @override
  Future<List<ElencoMatricole>> build() async {
    var db = await ref.read(erpdbProvider.future);

    var elencoMatricole = await db.elencoMatricoles.where().build().findAllAsync();

    return elencoMatricole;
  }

  void updateElencoMatricole(List<ElencoMatricole> elencoMatricole) async {
    state = const AsyncLoading();
    var db = await ref.read(erpdbProvider.future);
    await db.writeAsync((isar) {
      isar.elencoMatricoles.putAll(elencoMatricole);
    });
    state = AsyncData(elencoMatricole);
  }
}