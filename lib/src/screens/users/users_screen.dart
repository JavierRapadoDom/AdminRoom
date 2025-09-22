import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/users_service.dart';
import 'user_detail_drawer.dart';

class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _svc = UsersService();
  final _searchCtrl = TextEditingController();

  // Estado de paginación
  int _page = 0; // 0-based
  int _pageSize = 25;
  int _total = 0;

  // Datos
  bool _loading = true;
  String _query = '';
  String _orderBy = 'created_at';
  bool _ascending = false;
  List<AdminUser> _rows = const [];

  Timer? _deb;

  @override
  void initState() {
    super.initState();
    _loadAll();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _deb?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _deb?.cancel();
    _deb = Timer(const Duration(milliseconds: 350), () {
      setState(() {
        _query = _searchCtrl.text.trim();
        _page = 0; // reset a primera página
      });
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final total = await _svc.countUsers(q: _query);
      final rows = await _svc.fetchUsers(
        q: _query,
        limit: _pageSize,
        offset: _page * _pageSize,
        orderBy: _orderBy,
        ascending: _ascending,
      );
      if (!mounted) return;
      setState(() {
        _total = total;
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error cargando usuarios: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _toggleBan(AdminUser u) async {
    try {
      await _svc.toggleBan(u.id, !u.baneado);
      await _loadAll();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error al cambiar ban: $e')));
    }
  }

  void _changePage(int newPage) {
    final maxPage = (_total == 0) ? 0 : ((_total - 1) ~/ _pageSize);
    final page = newPage.clamp(0, maxPage);
    if (page != _page) {
      setState(() => _page = page);
      _loadAll();
    }
  }

  void _changePageSize(int newSize) {
    setState(() {
      _pageSize = newSize;
      _page = 0;
    });
    _loadAll();
  }

  void _setSort(String col) {
    setState(() {
      if (_orderBy == col) {
        _ascending = !_ascending;
      } else {
        _orderBy = col;
        _ascending = (col == 'nombre' || col == 'email'); // por defecto ascendente en texto
      }
      _page = 0;
    });
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final from = _total == 0 ? 0 : (_page * _pageSize + 1);
    final to = (_page * _pageSize + _rows.length).clamp(0, _total);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra superior: búsqueda + acciones
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por nombre o email',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: () {
                  // TODO: abrir wizard para crear ficticio
                },
                icon: const Icon(Icons.person_add_alt_1),
                label: const Text('Añadir ficticio'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tabla
          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('No hay usuarios'))
                  : Column(
                children: [
                  // Encabezado con orden
                  _TableHeader(
                    orderBy: _orderBy,
                    ascending: _ascending,
                    onSort: _setSort,
                  ),

                  const Divider(height: 1),

                  // Filas
                  Expanded(
                    child: ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final u = _rows[index];
                        return ListTile(
                          dense: true,
                          title: Row(
                            children: [
                              SizedBox(
                                width: 120,
                                child: SelectableText(u.id.substring(0, 8)),
                              ),
                              _cell(u.nombre.isEmpty ? '—' : u.nombre, flex: 2),
                              _cell(u.email, flex: 3),
                              _cell(u.edad?.toString() ?? '—'),
                              _cell(u.genero ?? '—'),
                              _cell(
                                '${u.createdAt.year}-${u.createdAt.month.toString().padLeft(2, '0')}-${u.createdAt.day.toString().padLeft(2, '0')}',
                                flex: 2,
                              ),
                              SizedBox(
                                width: 120,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Chip(
                                    label: Text(u.baneado ? 'Baneado' : 'Activo'),
                                    color: WidgetStatePropertyAll(
                                      u.baneado
                                          ? Colors.red.withOpacity(.15)
                                          : Colors.green.withOpacity(.15),
                                    ),
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Wrap(
                                spacing: 4,
                                children: [
                                  IconButton(
                                    tooltip: u.baneado ? 'Desbanear' : 'Banear',
                                    icon: Icon(u.baneado
                                        ? Icons.lock_open
                                        : Icons.lock_outline),
                                    onPressed: () => _toggleBan(u),
                                  ),
                                  IconButton(
                                    tooltip: 'Ver perfil',
                                    icon: const Icon(Icons.open_in_new),
                                    onPressed: () {
                                      // Empuja el diálogo en el ROOT navigator para no interferir con go_router
                                      final rootCtx = Navigator.of(context, rootNavigator: true).context;

                                      showGeneralDialog(
                                        context: rootCtx,
                                        barrierDismissible: true,
                                        barrierLabel: 'Cerrar',
                                        barrierColor: Colors.black54,
                                        pageBuilder: (ctx, a1, a2) {
                                          // No uses Positioned.fill + GestureDetector propio.
                                          // Deja que barrierDismissible cierre el diálogo.
                                          return Align(
                                            alignment: Alignment.centerRight,
                                            child: UserDetailDrawer(userId: u.id),
                                          );
                                        },
                                        transitionBuilder: (ctx, anim, _, child) {
                                          final dx = Tween<double>(begin: 1, end: 0)
                                              .animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
                                          return Transform.translate(
                                            offset: Offset(dx.value * MediaQuery.of(ctx).size.width, 0),
                                            child: child,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

                  const Divider(height: 1),

                  // Paginador
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    child: Row(
                      children: [
                        Text('Mostrando $from–$to de $_total'),
                        const SizedBox(width: 16),
                        const Text('Filas por página:'),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: _pageSize,
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 25, child: Text('25')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: (v) {
                            if (v != null) _changePageSize(v);
                          },
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Primera',
                          onPressed: _page == 0 ? null : () => _changePage(0),
                          icon: const Icon(Icons.first_page),
                        ),
                        IconButton(
                          tooltip: 'Anterior',
                          onPressed: _page == 0 ? null : () => _changePage(_page - 1),
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Text('${_page + 1}'),
                        IconButton(
                          tooltip: 'Siguiente',
                          onPressed: ((_page + 1) * _pageSize >= _total)
                              ? null
                              : () => _changePage(_page + 1),
                          icon: const Icon(Icons.chevron_right),
                        ),
                        IconButton(
                          tooltip: 'Última',
                          onPressed: ((_page + 1) * _pageSize >= _total)
                              ? null
                              : () {
                            final last = _total == 0
                                ? 0
                                : ((_total - 1) ~/ _pageSize);
                            _changePage(last);
                          },
                          icon: const Icon(Icons.last_page),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _cell(String text, {int flex = 1}) {
    return Expanded(
      flex: flex,
      child: Padding(
        padding: const EdgeInsets.only(left: 12),
        child: Text(text, overflow: TextOverflow.ellipsis),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String orderBy;
  final bool ascending;
  final void Function(String col) onSort;

  const _TableHeader({
    required this.orderBy,
    required this.ascending,
    required this.onSort,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle? th(BuildContext c) =>
        Theme.of(c).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    Widget sortBtn(String label, String col, {int flex = 1}) {
      final active = orderBy == col;
      return Expanded(
        flex: flex,
        child: TextButton.icon(
          onPressed: () => onSort(col),
          style: TextButton.styleFrom(alignment: Alignment.centerLeft, padding: const EdgeInsets.symmetric(horizontal: 12)),
          icon: Icon(
            active
                ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
                : Icons.unfold_more,
            size: 18,
          ),
          label: Align(
            alignment: Alignment.centerLeft,
            child: Text(label, style: th(context)),
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 120, child: Text('ID', style: th(context))),
          sortBtn('Nombre', 'nombre', flex: 2),
          sortBtn('Email', 'email', flex: 3),
          sortBtn('Edad', 'edad'),
          sortBtn('Género', 'genero'),
          sortBtn('Alta', 'created_at', flex: 2),
          SizedBox(width: 120, child: Text('Estado', style: th(context))),
          const Spacer(),
          SizedBox(width: 120, child: Text('Acciones', style: th(context))),
        ],
      ),
    );
  }
}
