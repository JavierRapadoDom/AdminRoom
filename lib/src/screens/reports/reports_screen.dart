import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/reports_service.dart';

class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  final _svc = ReportsService();
  final _searchCtrl = TextEditingController();

  int _page = 0;
  int _pageSize = 25;
  int _total = 0;
  String _status = 'pendiente'; // default útil
  bool _loading = true;
  String _query = '';
  List<ReportRow> _rows = const [];

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
    _deb = Timer(const Duration(milliseconds: 300), () {
      setState(() {
        _query = _searchCtrl.text.trim();
        _page = 0;
      });
      _loadAll();
    });
  }

  Future<void> _loadAll() async {
    setState(() => _loading = true);
    try {
      final total = await _svc.countReports(q: _query, status: _status);
      final rows = await _svc.fetchReports(
        q: _query,
        status: _status,
        limit: _pageSize,
        offset: _page * _pageSize,
      );
      if (!mounted) return;
      setState(() {
        _total = total;
        _rows = rows;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error cargando reportes: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeStatus(String s) {
    setState(() {
      _status = s;
      _page = 0;
    });
    _loadAll();
  }

  void _changePage(int newPage) {
    final maxPage = (_total == 0) ? 0 : ((_total - 1) ~/ _pageSize);
    final page = newPage.clamp(0, maxPage);
    if (page != _page) {
      setState(() => _page = page);
      _loadAll();
    }
  }

  void _changePageSize(int size) {
    setState(() {
      _pageSize = size;
      _page = 0;
    });
    _loadAll();
  }

  Future<void> _setReportStatus(ReportRow r, String newStatus) async {
    try {
      await _svc.updateStatus(r.id, newStatus);
      await _loadAll();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Estado actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error actualizando estado: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final from = _total == 0 ? 0 : (_page * _pageSize + 1);
    final to = (_page * _pageSize + _rows.length).clamp(0, _total);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          // Filtros
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Buscar por mensaje o categoría…',
                  ),
                ),
              ),
              const SizedBox(width: 12),
              DropdownButton<String>(
                value: _status,
                items: const [
                  DropdownMenuItem(value: 'todos', child: Text('Todos')),
                  DropdownMenuItem(value: 'pendiente', child: Text('Pendiente')),
                  DropdownMenuItem(value: 'revisado', child: Text('Revisado')),
                  DropdownMenuItem(value: 'accionado', child: Text('Accionado')),
                  DropdownMenuItem(value: 'descartado', child: Text('Descartado')),
                ],
                onChanged: (v) => _changeStatus(v ?? 'pendiente'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: Card(
              clipBehavior: Clip.antiAlias,
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                  ? const Center(child: Text('No hay reportes'))
                  : Column(
                children: [
                  const _Header(),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _rows[i];
                        return ListTile(
                          dense: true,
                          leading: CircleAvatar(child: Text(r.categoria.isNotEmpty ? r.categoria[0].toUpperCase() : '?')),
                          title: Text('Reporte ${r.id.substring(0, 8)} — ${r.categoria}'),
                          subtitle: Text(
                            'Reporter: ${r.reporterId.substring(0,8)} | Reportado: ${r.reportedId.substring(0,8)}\n'
                                '${r.mensaje}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: PopupMenuButton<String>(
                            tooltip: 'Cambiar estado',
                            onSelected: (v) => _setReportStatus(r, v),
                            itemBuilder: (_) => const [
                              PopupMenuItem(value: 'pendiente', child: Text('Pendiente')),
                              PopupMenuItem(value: 'revisado', child: Text('Revisado')),
                              PopupMenuItem(value: 'accionado', child: Text('Accionado')),
                              PopupMenuItem(value: 'descartado', child: Text('Descartado')),
                            ],
                            child: Chip(
                              label: Text(r.status),
                              color: WidgetStatePropertyAll(_statusColor(r.status)),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const Divider(height: 1),
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
                          ],
                          onChanged: (v) => v == null ? null : _changePageSize(v),
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
                            final last = _total == 0 ? 0 : ((_total - 1) ~/ _pageSize);
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

  static Color _statusColor(String s) {
    switch (s) {
      case 'pendiente':
        return Colors.amber.withOpacity(.18);
      case 'revisado':
        return Colors.blue.withOpacity(.18);
      case 'accionado':
        return Colors.green.withOpacity(.18);
      case 'descartado':
        return Colors.grey.withOpacity(.18);
      default:
        return Colors.grey.withOpacity(.18);
    }
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    TextStyle? th(BuildContext c) =>
        Theme.of(c).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          SizedBox(width: 140, child: Text('ID', style: th(context))),
          Expanded(flex: 2, child: Text('Categoría', style: th(context))),
          Expanded(flex: 4, child: Text('Mensaje', style: th(context))),
          Expanded(child: Text('Estado', style: th(context))),
        ],
      ),
    );
  }
}
