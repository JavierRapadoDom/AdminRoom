import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class ReportRow {
  final String id;
  final String reporterId;
  final String reportedId;
  final String categoria;
  final String mensaje;
  final String status; // pendiente | revisado | accionado | descartado
  final DateTime createdAt;

  const ReportRow({
    required this.id,
    required this.reporterId,
    required this.reportedId,
    required this.categoria,
    required this.mensaje,
    required this.status,
    required this.createdAt,
  });

  factory ReportRow.fromMap(Map<String, dynamic> m) {
    return ReportRow(
      id: m['id'] as String,
      reporterId: m['reporter_id'] as String,
      reportedId: m['reported_id'] as String,
      categoria: m['categoria'] as String,
      mensaje: m['mensaje'] as String,
      status: m['status'] as String,
      createdAt: DateTime.parse(m['created_at'].toString()),
    );
  }
}

class ReportsService {
  final SupabaseClient _sb;
  ReportsService({SupabaseClient? client}) : _sb = client ?? Supabase.instance.client;

  Future<List<ReportRow>> fetchReports({
    String q = '',            // busca en mensaje/categoria
    String status = 'todos',  // pendiente | revisado | accionado | descartado | todos
    int limit = 25,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    final from = _sb.from('reportes');
    final cols = 'id,reporter_id,reported_id,categoria,mensaje,status,created_at';

    final term = q.trim();
    if (term.isNotEmpty) {
      // Búsqueda sin .or(...): dos consultas + unión por id
      final baseMsg = (status == 'todos')
          ? from.select(cols)
          : from.select(cols).eq('status', status);

      final baseCat = (status == 'todos')
          ? from.select(cols)
          : from.select(cols).eq('status', status);

      final byMsg = await baseMsg
          .ilike('mensaje', '%$term%')
          .order(orderBy, ascending: ascending);

      final byCat = await baseCat
          .ilike('categoria', '%$term%')
          .order(orderBy, ascending: ascending);

      final mapById = <String, Map<String, dynamic>>{};
      if (byMsg is List) {
        for (final e in byMsg) {
          final m = Map<String, dynamic>.from(e);
          mapById[m['id'] as String] = m;
        }
      }
      if (byCat is List) {
        for (final e in byCat) {
          final m = Map<String, dynamic>.from(e);
          mapById[m['id'] as String] = m;
        }
      }

      final merged = mapById.values.map(ReportRow.fromMap).toList()
        ..sort((a, b) {
          final cmp = a.createdAt.compareTo(b.createdAt);
          return ascending ? cmp : -cmp;
        });

      final start = offset.clamp(0, merged.length);
      final end = (offset + limit).clamp(0, merged.length);
      return merged.sublist(start, end);
    }

    // Sin búsqueda: filtra por status si hace falta, luego ordena y pagina en el servidor.
    final filteredQuery = (status == 'todos')
        ? from.select(cols)
        : from.select(cols).eq('status', status);

    final resp = await filteredQuery
        .order(orderBy, ascending: ascending)
        .range(offset, offset + limit - 1);

    if (resp is List) {
      return resp.map((e) => ReportRow.fromMap(Map<String, dynamic>.from(e))).toList();
    }
    return const <ReportRow>[];
  }

  Future<int> countReports({String q = '', String status = 'todos'}) async {
    final from = _sb.from('reportes');

    if (q.trim().isEmpty) {
      final base = (status == 'todos')
          ? await from.select('id')
          : await from.select('id').eq('status', status);
      if (base is List) return base.length;
      return 0;
    }

    final a = (status == 'todos')
        ? await from.select('id').ilike('mensaje', '%$q%')
        : await from.select('id').eq('status', status).ilike('mensaje', '%$q%');

    final b = (status == 'todos')
        ? await from.select('id').ilike('categoria', '%$q%')
        : await from.select('id').eq('status', status).ilike('categoria', '%$q%');

    final ids = <String>{};
    if (a is List) for (final e in a) ids.add(e['id'] as String);
    if (b is List) for (final e in b) ids.add(e['id'] as String);
    return ids.length;
  }

  Future<void> updateStatus(String reportId, String newStatus) async {
    await _sb.from('reportes').update({'status': newStatus}).eq('id', reportId);
  }
}
