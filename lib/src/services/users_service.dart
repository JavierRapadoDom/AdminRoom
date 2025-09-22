import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@immutable
class AdminUser {
  final String id;
  final String nombre;
  final String email;
  final int? edad;
  final String? genero;
  final DateTime createdAt;
  final bool baneado;

  const AdminUser({
    required this.id,
    required this.nombre,
    required this.email,
    required this.createdAt,
    this.edad,
    this.genero,
    this.baneado = false,
  });

  factory AdminUser.fromMap(Map<String, dynamic> m) {
    return AdminUser(
      id: m['id'] as String,
      nombre: (m['nombre'] ?? '') as String,
      email: m['email'] as String,
      edad: m['edad'] as int?,
      genero: m['genero'] as String?,
      createdAt: DateTime.parse(m['created_at'].toString()),
      baneado: (m['baneado'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'nombre': nombre,
    'email': email,
    'edad': edad,
    'genero': genero,
    'created_at': createdAt.toIso8601String(),
    'baneado': baneado,
  };
}

class UsersService {
  final SupabaseClient _sb;
  UsersService({SupabaseClient? client}) : _sb = client ?? Supabase.instance.client;

  static const bool _useMock = false;

  /// ===== Helpers de conteo compatibles con clientes sin FetchOptions/CountOption =====
  Future<int> _countEq(String table, String column, dynamic value) async {
    final resp = await _sb.from(table).select('id').eq(column, value);
    if (resp is List) return resp.length;
    return 0;
  }
  Future<int> _countWhere({
    required String table,
    required String selectCol,
    required String whereCol,
    required dynamic equals,
  }) async {
    final resp = await _sb.from(table).select(selectCol).eq(whereCol, equals);
    if (resp is List) return resp.length;
    return 0;
  }

  /// Cuenta filas únicas uniendo por [selectCol] cuando hay dos condiciones OR
  /// (útil para 'chats' con usuario1_id/usuario2_id).
  Future<int> _countWhereEither({
    required String table,
    required String selectCol,
    required String colA,
    required dynamic valA,
    required String colB,
    required dynamic valB,
  }) async {
    final a = await _sb.from(table).select(selectCol).eq(colA, valA);
    final b = await _sb.from(table).select(selectCol).eq(colB, valB);

    final ids = <String>{};
    if (a is List) for (final e in a) ids.add('${e[selectCol]}');
    if (b is List) for (final e in b) ids.add('${e[selectCol]}');
    return ids.length;
  }

  Future<int> _countEqAny(String table, String colA, dynamic valA, String colB, dynamic valB) async {
    final a = await _sb.from(table).select('id').eq(colA, valA);
    final b = await _sb.from(table).select('id').eq(colB, valB);
    final ids = <String>{};
    if (a is List) for (final e in a) ids.add('${e['id']}');
    if (b is List) for (final e in b) ids.add('${e['id']}');
    return ids.length;
  }

  /// ===== Stats por usuario (solo ints; sin FetchOptions) =====
  Future<Map<String, int>> getUserStats(String userId) async {
    // Reportes (recibidos y enviados) -> tabla tiene 'id'
    final repRec = await _countWhere(
      table: 'reportes', selectCol: 'id', whereCol: 'reported_id', equals: userId,
    );
    final repEnv = await _countWhere(
      table: 'reportes', selectCol: 'id', whereCol: 'reporter_id', equals: userId,
    );

    // Chats donde participa (usuario1_id o usuario2_id) -> tabla tiene 'id'
    final chats = await _countWhereEither(
      table: 'chats', selectCol: 'id',
      colA: 'usuario1_id', valA: userId,
      colB: 'usuario2_id', valB: userId,
    );

    // Favoritos (personas) marcados por él -> NO hay 'id', contamos por 'usuario_id'
    final favPers = await _countWhere(
      table: 'favoritos_personas', selectCol: 'usuario_id', whereCol: 'usuario_id', equals: userId,
    );

    // Favoritos de pisos -> tampoco hay 'id', contamos por 'usuario_id'
    final favPiso = await _countWhere(
      table: 'favoritos_piso', selectCol: 'usuario_id', whereCol: 'usuario_id', equals: userId,
    );

    // Publicaciones de piso donde es anfitrión -> tabla tiene 'id'
    final pisos = await _countWhere(
      table: 'publicaciones_piso', selectCol: 'id', whereCol: 'anfitrion_id', equals: userId,
    );

    // Amigos: tabla con array
    int amigosCount = 0;
    final amigosRow = await _sb.from('amigos').select('amigos').eq('usuario_id', userId).maybeSingle();
    if (amigosRow != null && amigosRow['amigos'] is List) {
      amigosCount = (amigosRow['amigos'] as List).length;
    }

    return {
      'reportes_recibidos': repRec,
      'reportes_enviados': repEnv,
      'chats': chats,
      'favoritos_personas': favPers,
      'favoritos_piso': favPiso,
      'publicaciones_piso': pisos,
      'amigos': amigosCount,
    };
  }
  /// Reset de swipes a 10 (según tu schema)
  Future<void> resetSwipes(String userId) async {
    await _sb.from('usuarios').update({'swipes_remaining': 10}).eq('id', userId);
  }

  /// Cambiar rol (si usas enum/USER-DEFINED, envía el literal compatible)
  Future<void> setRole(String userId, String roleLiteral) async {
    await _sb.from('usuarios').update({'rol': roleLiteral}).eq('id', userId);
  }

  /// Lista de usuarios (paginada) con búsqueda por nombre/email.
  Future<List<AdminUser>> fetchUsers({
    String q = '',
    int limit = 25,
    int offset = 0,
    String orderBy = 'created_at',
    bool ascending = false,
  }) async {
    if (_useMock) return _mock(q);

    final view = _sb.from('admin_users_view');
    final term = q.trim();

    if (term.isEmpty) {
      final resp = await view
          .select('id,nombre,email,edad,genero,created_at,baneado')
          .order(orderBy, ascending: ascending)
          .range(offset, offset + limit - 1);

      if (resp is List) {
        return resp.map((e) => AdminUser.fromMap(Map<String, dynamic>.from(e))).toList();
      }
      return const <AdminUser>[];
    }

    // BÚSQUEDA (OR) sin usar .or(...): 2 consultas y unión por id.
    final emailResp = await view
        .select('id,nombre,email,edad,genero,created_at,baneado')
        .ilike('email', '%$term%')
        .order(orderBy, ascending: ascending)
        .range(0, offset + limit - 1);

    final nombreResp = await view
        .select('id,nombre,email,edad,genero,created_at,baneado')
        .ilike('nombre', '%$term%')
        .order(orderBy, ascending: ascending)
        .range(0, offset + limit - 1);

    final mapById = <String, Map<String, dynamic>>{};
    if (emailResp is List) {
      for (final e in emailResp) {
        final m = Map<String, dynamic>.from(e);
        mapById[m['id'] as String] = m;
      }
    }
    if (nombreResp is List) {
      for (final e in nombreResp) {
        final m = Map<String, dynamic>.from(e);
        mapById[m['id'] as String] = m; // evita duplicados
      }
    }

    final merged = mapById.values.map(AdminUser.fromMap).toList()
      ..sort((a, b) {
        int cmp;
        switch (orderBy) {
          case 'nombre':
            cmp = a.nombre.toLowerCase().compareTo(b.nombre.toLowerCase());
            break;
          case 'email':
            cmp = a.email.toLowerCase().compareTo(b.email.toLowerCase());
            break;
          case 'edad':
            cmp = (a.edad ?? -1).compareTo(b.edad ?? -1);
            break;
          case 'genero':
            cmp = (a.genero ?? '').compareTo(b.genero ?? '');
            break;
          case 'created_at':
          default:
            cmp = a.createdAt.compareTo(b.createdAt);
        }
        return ascending ? cmp : -cmp;
      });

    final start = offset.clamp(0, merged.length);
    final end = (offset + limit).clamp(0, merged.length);
    return merged.sublist(start, end);
  }

  /// Total de usuarios (para paginación).
  ///
  /// Nota: sin `count` nativo en tu cliente, contamos con un select de IDs.
  /// Si la tabla crece mucho, conviene crear una RPC `admin_users_count(q text)`.
  Future<int> countUsers({String q = ''}) async {
    if (_useMock) return (await _mock(q)).length;

    final view = _sb.from('admin_users_view');
    final term = q.trim();

    if (term.isEmpty) {
      final resp = await view.select('id'); // trae solo ids
      if (resp is List) return resp.length;
      return 0;
    }

    final emailResp = await view.select('id').ilike('email', '%$term%');
    final nombreResp = await view.select('id').ilike('nombre', '%$term%');

    final ids = <String>{};
    if (emailResp is List) {
      for (final e in emailResp) ids.add(e['id'] as String);
    }
    if (nombreResp is List) {
      for (final e in nombreResp) ids.add(e['id'] as String);
    }
    return ids.length;
  }

  /// Alterna ban (RPC recomendada con fallback a tabla user_bans).
  Future<void> toggleBan(String userId, bool toBanned) async {
    if (_useMock) return;

    try {
      await _sb.rpc('admin_toggle_ban', params: {'uid': userId});
    } on PostgrestException catch (e) {
      final msg = e.message.toLowerCase();
      final noFunc = msg.contains('function') || msg.contains('admin_toggle_ban');
      if (noFunc) {
        if (toBanned) {
          await _sb.from('user_bans').upsert({'user_id': userId});
        } else {
          await _sb.from('user_bans').delete().eq('user_id', userId);
        }
      } else {
        rethrow;
      }
    }
  }

  Future<AdminUser?> getUserById(String id) async {
    if (_useMock) {
      final list = await _mock('');
      return list.firstWhere((u) => u.id == id, orElse: () => list.first);
    }
    final data = await _sb
        .from('admin_users_view')
        .select('id,nombre,email,edad,genero,created_at,baneado')
        .eq('id', id)
        .maybeSingle();

    if (data == null) return null;
    return AdminUser.fromMap(Map<String, dynamic>.from(data));
  }

  Future<void> updateUserBasics({
    required String id,
    String? nombre,
    int? edad,
    String? genero,
  }) async {
    if (_useMock) return;

    final patch = <String, dynamic>{};
    if (nombre != null) patch['nombre'] = nombre;
    if (edad != null) patch['edad'] = edad;
    if (genero != null) patch['genero'] = genero;
    if (patch.isEmpty) return;

    await _sb.from('usuarios').update(patch).eq('id', id);
  }

  // ===================== MOCK =====================
  Future<List<AdminUser>> _mock(String q) async {
    final rnd = Random(7);
    final base = List.generate(42, (i) {
      final id = '00000000-0000-0000-0000-${(1000 + i)}';
      final nombre = 'Usuario $i';
      final email = 'user$i@demo.com';
      final edad = 18 + rnd.nextInt(20);
      final genero = (i % 3 == 0) ? 'M' : (i % 3 == 1) ? 'F' : 'Otro';
      final created = DateTime.now().subtract(Duration(days: rnd.nextInt(400)));
      return AdminUser(
        id: id,
        nombre: nombre,
        email: email,
        edad: edad,
        genero: genero,
        createdAt: created,
        baneado: i % 7 == 0,
      );
    });

    if (q.isEmpty) return base;
    final l = q.toLowerCase();
    return base
        .where((u) => u.email.toLowerCase().contains(l) || u.nombre.toLowerCase().contains(l))
        .toList();
  }
}
