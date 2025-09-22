import 'package:flutter/material.dart';
import '../../services/users_service.dart';

class UserDetailDrawer extends StatefulWidget {
  final String userId;
  const UserDetailDrawer({super.key, required this.userId});

  @override
  State<UserDetailDrawer> createState() => _UserDetailDrawerState();
}

class _UserDetailDrawerState extends State<UserDetailDrawer> {
  final _svc = UsersService();

  AdminUser? _user;
  bool _loading = true;
  bool _saving = false;
  Map<String, int> _stats = const {}; // reportes, chats, favoritos, pisos, etc.

  final _nameCtrl = TextEditingController();
  final _edadCtrl = TextEditingController();
  String? _genero; // UI: 'Hombre' | 'Mujer' | 'Otro' | null
  String? _rol;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _edadCtrl.dispose();
    super.dispose();
  }

  // ---- Helpers de normalización de género ----
  String? _normalizeGeneroUi(String? g) {
    if (g == null) return null;
    final s = g.trim().toLowerCase();
    if (s == 'm' || s == 'hombre' || s == 'masculino') return 'Hombre';
    if (s == 'f' || s == 'mujer' || s == 'femenino') return 'Mujer';
    return 'Otro';
  }

  String? _mapGeneroUiToDb(String? g) {
    // Si prefieres guardar 'Hombre/Mujer/Otro' tal cual en tu BD, cambia a: return g;
    switch (g) {
      case 'Hombre':
        return 'M';
      case 'Mujer':
        return 'F';
      case 'Otro':
      default:
        return 'Otro';
    }
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await _svc.getUserById(widget.userId);
      final st = await _svc.getUserStats(widget.userId);
      if (!mounted) return;
      setState(() {
        _user = u;
        _stats = st;
        _nameCtrl.text = u?.nombre ?? '';
        _edadCtrl.text = (u?.edad ?? '').toString();
        _genero = _normalizeGeneroUi(u?.genero); // <- normaliza para el dropdown
        _rol = st['rol_name_str'] != null ? st['rol_name_str'].toString() : null;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Error cargando usuario: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveBasics() async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      await _svc.updateUserBasics(
        id: _user!.id,
        nombre: _nameCtrl.text.trim(),
        edad: int.tryParse(_edadCtrl.text.trim()),
        genero: _mapGeneroUiToDb(_genero), // <- mapea a formato BD
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Datos guardados')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Error al guardar: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggleBan() async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      await _svc.toggleBan(_user!.id, !_user!.baneado);
      await _load();
      if (!mounted) return;
      final msg = _user!.baneado ? 'Usuario desbaneado' : 'Usuario baneado';
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(SnackBar(content: Text(msg)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Error al banear: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _resetSwipes() async {
    if (_user == null) return;
    setState(() => _saving = true);
    try {
      await _svc.resetSwipes(_user!.id);
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Swipes reseteados')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Error al resetear swipes: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _updateRole(String? role) async {
    if (_user == null || role == null) return;
    setState(() => _saving = true);
    try {
      await _svc.setRole(_user!.id, role);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(const SnackBar(content: Text('Rol actualizado')));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(context)
          ?.showSnackBar(SnackBar(content: Text('Error al actualizar rol: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width.clamp(420.0, 560.0);
    return Align(
      alignment: Alignment.centerRight,
      child: Material(
        elevation: 12,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          bottomLeft: Radius.circular(16),
        ),
        child: SizedBox(
          width: width,
          height: double.infinity,
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _user == null
              ? const Center(child: Text('Usuario no encontrado'))
              : DefaultTabController(
            length: 3,
            child: Column(
              children: [
                _Header(
                  user: _user!,
                  onClose: () =>
                      Navigator.of(context, rootNavigator: true).pop(),
                ),
                const TabBar(tabs: [
                  Tab(text: 'Perfil'),
                  Tab(text: 'Actividad'),
                  Tab(text: 'Acciones'),
                ]),
                Expanded(
                  child: TabBarView(
                    children: [
                      _PerfilTab(
                        nameCtrl: _nameCtrl,
                        edadCtrl: _edadCtrl,
                        genero: _genero,
                        onGeneroChanged: (v) =>
                            setState(() => _genero = v),
                        saving: _saving,
                        onSave: _saveBasics,
                        email: _user!.email,
                        createdAt: _user!.createdAt,
                        rol: _rol,
                        onRoleChanged: _updateRole,
                      ),
                      _ActividadTab(stats: _stats),
                      _AccionesTab(
                        isBanned: _user!.baneado,
                        onToggleBan: _toggleBan,
                        onResetSwipes: _resetSwipes,
                        saving: _saving,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final AdminUser user;
  final VoidCallback onClose;
  const _Header({required this.user, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
      child: Row(
        children: [
          CircleAvatar(
            child: Text(
              user.nombre.isNotEmpty
                  ? user.nombre[0].toUpperCase()
                  : user.email[0].toUpperCase(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.nombre.isEmpty ? 'Sin nombre' : user.nombre,
                  style: theme.textTheme.titleMedium,
                ),
                Text(user.email, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}

class _PerfilTab extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController edadCtrl;
  final String? genero; // 'Hombre' | 'Mujer' | 'Otro' | null
  final void Function(String?) onGeneroChanged;
  final bool saving;
  final VoidCallback onSave;
  final String email;
  final DateTime createdAt;
  final String? rol;
  final Future<void> Function(String?) onRoleChanged;

  const _PerfilTab({
    required this.nameCtrl,
    required this.edadCtrl,
    required this.genero,
    required this.onGeneroChanged,
    required this.saving,
    required this.onSave,
    required this.email,
    required this.createdAt,
    required this.rol,
    required this.onRoleChanged,
  });

  @override
  Widget build(BuildContext context) {
    const generoItems = ['Hombre', 'Mujer', 'Otro'];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nombre'),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: edadCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Edad'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: DropdownButtonFormField<String>(
                value: (genero != null && generoItems.contains(genero))
                    ? genero
                    : null, // evita value inválido
                items: const [
                  DropdownMenuItem(value: 'Hombre', child: Text('Hombre')),
                  DropdownMenuItem(value: 'Mujer', child: Text('Mujer')),
                  DropdownMenuItem(value: 'Otro', child: Text('Otro')),
                ],
                onChanged: onGeneroChanged,
                decoration: const InputDecoration(labelText: 'Género'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: rol,
          items: const [
            DropdownMenuItem(value: 'user', child: Text('user')),
            DropdownMenuItem(value: 'admin', child: Text('admin')),
            DropdownMenuItem(value: 'moderator', child: Text('moderator')),
          ],
          onChanged: (v) => onRoleChanged(v),
          decoration: const InputDecoration(labelText: 'Rol'),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: saving ? null : onSave,
          icon: const Icon(Icons.save_outlined),
          label: const Text('Guardar cambios'),
        ),
        const SizedBox(height: 16),
        Text('Metadatos', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Text('Alta: ${createdAt.toLocal()}'),
        Text('Email: $email'),
      ],
    );
  }
}

class _ActividadTab extends StatelessWidget {
  final Map<String, int> stats;
  const _ActividadTab({required this.stats});

  @override
  Widget build(BuildContext context) {
    final items = <_StatItem>[
      _StatItem('Reportes recibidos', stats['reportes_recibidos'] ?? 0, Icons.report),
      _StatItem('Reportes enviados', stats['reportes_enviados'] ?? 0, Icons.outgoing_mail),
      _StatItem('Chats', stats['chats'] ?? 0, Icons.chat_bubble_outline),
      _StatItem('Favoritos (personas)', stats['favoritos_personas'] ?? 0, Icons.favorite_border),
      _StatItem('Favoritos (pisos)', stats['favoritos_piso'] ?? 0, Icons.home_outlined),
      _StatItem('Publicaciones piso', stats['publicaciones_piso'] ?? 0, Icons.apartment_outlined),
      _StatItem('Amigos', stats['amigos'] ?? 0, Icons.group_outlined),
    ];

    return GridView.count(
      crossAxisCount: 2,
      padding: const EdgeInsets.all(16),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      children: [
        for (final it in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(it.icon),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(it.label),
                        const SizedBox(height: 4),
                        Text('${it.value}',
                            style: Theme.of(context).textTheme.titleLarge),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _StatItem {
  final String label;
  final int value;
  final IconData icon;
  _StatItem(this.label, this.value, this.icon);
}

class _AccionesTab extends StatelessWidget {
  final bool isBanned;
  final VoidCallback onToggleBan;
  final VoidCallback onResetSwipes;
  final bool saving;

  const _AccionesTab({
    required this.isBanned,
    required this.onToggleBan,
    required this.onResetSwipes,
    required this.saving,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        FilledButton.icon(
          onPressed: saving ? null : onToggleBan,
          icon: Icon(isBanned ? Icons.lock_open : Icons.lock_outline),
          label: Text(isBanned ? 'Desbanear' : 'Banear'),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: saving ? null : onResetSwipes,
          icon: const Icon(Icons.refresh),
          label: const Text('Reset swipes a 10'),
        ),
        const SizedBox(height: 12),
        // Más acciones aquí: limpiar favoritos, borrar fotos, etc.
      ],
    );
  }
}
