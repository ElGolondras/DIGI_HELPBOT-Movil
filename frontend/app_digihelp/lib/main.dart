import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Colores de acento disponibles ────────────────────────────────────────────
const Map<String, Color> kAcentos = {
  'Azul':    Color(0xFF2563EB),
  'Violeta': Color(0xFF7C3AED),
  'Verde':   Color(0xFF16A34A),
  'Rojo':    Color(0xFFDC2626),
  'Naranja': Color(0xFFEA580C),
  'Rosa':    Color(0xFFDB2777),
};

const String kBaseUrl = 'http://10.0.2.2:8000';

void main() {
  runApp(const DigiHelpApp());
}

// ─── App root con ThemeNotifier ────────────────────────────────────────────────
class DigiHelpApp extends StatefulWidget {
  const DigiHelpApp({super.key});
  static _DigiHelpAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_DigiHelpAppState>();

  @override
  State<DigiHelpApp> createState() => _DigiHelpAppState();
}

class _DigiHelpAppState extends State<DigiHelpApp> {
  bool darkMode = true;
  String acento = 'Azul';
  double fontSize = 14;

  void applyPrefs(Map<String, dynamic> prefs) {
    setState(() {
      darkMode = (prefs['tema'] ?? 'oscuro') == 'oscuro';
      acento   = prefs['acento'] ?? 'Azul';
      fontSize = (prefs['fuente'] ?? 14).toDouble();
    });
  }

  @override
  Widget build(BuildContext context) {
    final seed = kAcentos[acento] ?? const Color(0xFF2563EB);
    return MaterialApp(
      title: 'DigiHelp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: seed,
        brightness: darkMode ? Brightness.dark : Brightness.light,
        useMaterial3: true,
      ),
      home: const LoginScreen(),
    );
  }
}

// ─── LOGIN ─────────────────────────────────────────────────────────────────────
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _userCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  String _msg = '';
  bool _loading = false;
  bool _obscure = true;

  Future<void> _login() async {
    setState(() { _loading = true; _msg = ''; });
    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _userCtrl.text.trim(), 'password': _passCtrl.text}),
      );
      if (res.statusCode == 200) {
        final u = jsonDecode(utf8.decode(res.bodyBytes))['usuario'];
        if (!mounted) return;
        Navigator.pushReplacement(context, MaterialPageRoute(
          builder: (_) => ChatScreen(
            usuarioId:          u['id'],
            nombreUsuario:      u['nombre_completo'],
            emailUsuario:       u['email'],
            departamentoUsuario: u['departamento'] ?? 'Informatica',
          ),
        ));
      } else {
        setState(() => _msg = 'Usuario o contraseña incorrectos');
      }
    } catch (_) {
      setState(() => _msg = 'Error de conexión con el servidor');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                CircleAvatar(radius: 48, backgroundColor: cs.primaryContainer,
                  child: Icon(Icons.support_agent, size: 52, color: cs.primary)),
                const SizedBox(height: 20),
                Text('DigiHelp AI',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: cs.onSurface)),
                Text('Soporte IT Corporativo',
                  style: TextStyle(color: cs.onSurfaceVariant)),
                const SizedBox(height: 48),
                TextField(
                  controller: _userCtrl,
                  decoration: const InputDecoration(labelText: 'Usuario',
                    prefixIcon: Icon(Icons.person_outline), border: OutlineInputBorder()),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  decoration: InputDecoration(
                    labelText: 'Contraseña',
                    prefixIcon: const Icon(Icons.lock_outline),
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setState(() => _obscure = !_obscure),
                    ),
                  ),
                  onSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity, height: 52,
                  child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : FilledButton(
                        onPressed: _login,
                        child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 16)),
                      ),
                ),
                if (_msg.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text(_msg, style: const TextStyle(color: Colors.redAccent)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── CHAT SCREEN ───────────────────────────────────────────────────────────────
class ChatScreen extends StatefulWidget {
  final int usuarioId;
  final String nombreUsuario;
  final String emailUsuario;
  final String departamentoUsuario;

  const ChatScreen({
    super.key,
    required this.usuarioId,
    required this.nombreUsuario,
    required this.emailUsuario,
    required this.departamentoUsuario,
  });
  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _msgCtrl        = TextEditingController();
  final _scrollCtrl     = ScrollController();
  List<Map<String, dynamic>> _mensajes = [];
  bool _escribiendo     = false;
  PlatformFile? _archivo;
  int _intentos         = 0;
  List<dynamic> _chatsGuardados = [];
  String _chatId        = '';
  String _titulo        = 'Nuevo Chat';

  // Prefs
  bool   _darkMode  = true;
  String _acento    = 'Azul';
  double _fontSize  = 14;

  Color get _seed => kAcentos[_acento] ?? const Color(0xFF2563EB);

  @override
  void initState() {
    super.initState();
    _nuevoChat();
    _cargarHistorial();
    _cargarPrefs();
  }

  // ── Prefs ────────────────────────────────────────────────────────────────────
  Future<void> _cargarPrefs() async {
    try {
      final res = await http.get(Uri.parse('$kBaseUrl/cargar_prefs/${widget.usuarioId}'));
      if (res.statusCode == 200) {
        final p = jsonDecode(utf8.decode(res.bodyBytes))['prefs'] as Map<String, dynamic>;
        setState(() {
          _darkMode = (p['tema'] ?? 'oscuro') == 'oscuro';
          _acento   = p['acento'] ?? 'Azul';
          _fontSize = (p['fuente'] ?? 14).toDouble();
        });
        DigiHelpApp.of(context)?.applyPrefs(p);
      }
    } catch (_) {}
  }

  Future<void> _guardarPrefs(Map<String, dynamic> prefs) async {
    try {
      await http.post(
        Uri.parse('$kBaseUrl/guardar_prefs/${widget.usuarioId}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(prefs),
      );
    } catch (_) {}
  }

  // ── Chat helpers ─────────────────────────────────────────────────────────────
  void _nuevoChat() => setState(() {
    _mensajes.clear();
    _intentos = 0;
    _chatId   = 'chat_${DateTime.now().millisecondsSinceEpoch}';
    _titulo   = 'Nuevo Chat';
  });

  String _urgencia() {
    final t = _mensajes.map((m) => m['texto'] ?? '').join(' ').toLowerCase();
    if (['urgente','no enciende','bloqueado','virus','servidor'].any(t.contains)) return 'alta';
    if (['lento','impresora','internet','wifi','contraseña'].any(t.contains)) return 'media';
    return 'baja';
  }

  String _nowTimestamp() {
    final n = DateTime.now();
    return '${n.hour.toString().padLeft(2,'0')}:${n.minute.toString().padLeft(2,'0')}';
  }

  void _scrollAbajo() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(_scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
      }
    });
  }

  // ── Cargar historial ─────────────────────────────────────────────────────────
  Future<void> _cargarHistorial() async {
    try {
      final res = await http.get(Uri.parse('$kBaseUrl/cargar_chats/${widget.usuarioId}'));
      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        setState(() => _chatsGuardados = data['chats']);
      }
    } catch (_) {}
  }

  void _cargarChatAntiguo(Map<String, dynamic> chat) {
    setState(() {
      _chatId  = chat['chat_id'];
      _titulo  = chat['titulo'];
      _intentos = 0;
      _mensajes = (chat['mensajes'] as List).map((m) => {
        'rol':       (m['rol'] ?? m['role'] ?? 'user').toString(),
        'texto':     (m['texto'] ?? m['content'] ?? '').toString(),
        'ruta_video': m['ruta_video'],
        'timestamp': m['timestamp'] ?? '',
      }).toList();
    });
    Navigator.pop(context);
    _scrollAbajo();
  }

  // ── Eliminar chat ─────────────────────────────────────────────────────────────
  Future<void> _eliminarChat(String chatId) async {
    try {
      await http.delete(Uri.parse('$kBaseUrl/eliminar_chat/${widget.usuarioId}/$chatId'));
      await _cargarHistorial();
      if (_chatId == chatId) _nuevoChat();
    } catch (_) {}
  }

  // ── Guardar chat ──────────────────────────────────────────────────────────────
  Future<void> _guardarChat() async {
    if (_mensajes.isEmpty) return;
    if (_titulo == 'Nuevo Chat') {
      final primero = _mensajes.firstWhere((m) => m['rol'] == 'user', orElse: () => {'texto': 'Chat'});
      final t = primero['texto'] as String;
      _titulo = t.length > 28 ? '${t.substring(0, 28)}…' : t;
    }
    try {
      await http.post(
        Uri.parse('$kBaseUrl/guardar_chat'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'chat_id':    _chatId,
          'titulo':     _titulo,
          'fecha':      '${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}',
          'mensajes':   _mensajes.map((m) => {
            'role':      m['rol'],
            'content':   m['texto'],
            'ruta_video': m['ruta_video'],
            'timestamp': m['timestamp'] ?? '',
          }).toList(),
        }),
      );
      _cargarHistorial();
    } catch (_) {}
  }

  // ── Enviar mensaje ────────────────────────────────────────────────────────────
  Future<void> _enviar() async {
    final texto = _msgCtrl.text.trim();
    if (texto.isEmpty && _archivo == null) return;
    final ts = _nowTimestamp();

    setState(() {
      _mensajes.add({
        'rol':   'user',
        'texto': _archivo != null ? '📎 ${_archivo!.name}\n$texto' : texto,
        'timestamp': ts,
      });
      _msgCtrl.clear();
      _escribiendo = true;
    });
    _scrollAbajo();

    try {
      var request = http.MultipartRequest('POST', Uri.parse('$kBaseUrl/chat_multimodal'));
      request.fields['mensaje']  = texto;
      request.fields['historial'] = jsonEncode(_mensajes);
      if (_archivo != null) {
        request.files.add(await http.MultipartFile.fromPath('archivo', _archivo!.path!));
      }

      final resStream = await request.send();
      final res       = await http.Response.fromStream(resStream);

      if (res.statusCode == 200) {
        final data = jsonDecode(utf8.decode(res.bodyBytes));
        _intentos++;
        if (_intentos < 5) {
          setState(() {
            _mensajes.add({
              'rol':       'assistant',
              'texto':     data['respuesta'],
              'ruta_video': data['ruta_video'],
              'timestamp': _nowTimestamp(),
            });
          });
        } else {
          await _dispararIncidencia(data['respuesta'], data['ruta_video']);
        }
        _guardarChat();
        _scrollAbajo();
      }
    } catch (_) {
      setState(() => _mensajes.add({'rol': 'assistant', 'texto': '❌ Error de conexión.', 'timestamp': _nowTimestamp()}));
    } finally {
      setState(() { _escribiendo = false; _archivo = null; });
    }
  }

  // ── Incidencia automática ─────────────────────────────────────────────────────
  Future<void> _dispararIncidencia(String respuestaIA, String? rutaVideo) async {
    final charla = _mensajes.map((m) => '${m["rol"]}: ${m["texto"]}').join('\n');
    try {
      final res = await http.post(
        Uri.parse('$kBaseUrl/crear_incidencia'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario':     widget.nombreUsuario,
          'problema':    charla,
          'urgencia':    _urgencia(),
          'email':       widget.emailUsuario,
          'departamento': widget.departamentoUsuario,
        }),
      );
      final data = jsonDecode(utf8.decode(res.bodyBytes));
      setState(() {
        if (data['status'] == 'ok') {
          // Usamos el mensaje formateado que devuelve el backend (igual que versión PC)
          _mensajes.add({
            'rol':   'assistant',
            'texto': data['mensaje'],
            'timestamp': _nowTimestamp(),
          });
        } else {
          // FALSA_ALARMA o error — mostrar la respuesta de la IA normal
          _mensajes.add({'rol': 'assistant', 'texto': respuestaIA, 'ruta_video': rutaVideo, 'timestamp': _nowTimestamp()});
        }
        _intentos = 0;
      });
    } catch (_) {
      setState(() {
        _mensajes.add({'rol': 'assistant', 'texto': respuestaIA, 'ruta_video': rutaVideo, 'timestamp': _nowTimestamp()});
        _intentos = 0;
      });
    }
  }

  // ── Abrir video ───────────────────────────────────────────────────────────────
  Future<void> _abrirVideo(String url) async {
    try {
      // Convertir ID o URL de Drive a enlace de previsualización web
      String urlFinal = url;
      if (!url.startsWith('http')) {
        // Es un ID de Drive directamente
        urlFinal = 'https://drive.google.com/file/d/$url/preview';
      } else if (url.contains('drive.google.com/file/d/')) {
        final id = url.split('/file/d/')[1].split('/')[0].split('?')[0];
        urlFinal = 'https://drive.google.com/file/d/$id/preview';
      } else if (url.contains('drive.google.com') && url.contains('id=')) {
        final id = url.split('id=')[1].split('&')[0];
        urlFinal = 'https://drive.google.com/file/d/$id/preview';
      }
      final Uri uri = Uri.parse(urlFinal);
      // Abrir en navegador interno para evitar el error de cuenta de Google
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el tutorial')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el vídeo: \$e')));
    }
  }

  // ── Panel de personalización ──────────────────────────────────────────────────
  void _abrirPersonalizacion() {
    String temaTmp  = _darkMode ? 'oscuro' : 'claro';
    String acentoTmp = _acento;
    double fuenteTmp = _fontSize;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle
              Center(child: Container(width: 40, height: 4,
                decoration: BoxDecoration(color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              const Text('⚙️  Personalización',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 24),

              // Tema
              const Text('Tema', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Row(children: [
                _temaBtn(ctx, setModal, 'claro',  '☀️  Claro',  temaTmp,  (v) => temaTmp = v),
                const SizedBox(width: 12),
                _temaBtn(ctx, setModal, 'oscuro', '🌙  Oscuro', temaTmp, (v) => temaTmp = v),
              ]),
              const SizedBox(height: 24),

              // Acento
              const Text('Color de acento', style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: kAcentos.entries.map((e) {
                final sel = e.key == acentoTmp;
                return GestureDetector(
                  onTap: () => setModal(() => acentoTmp = e.key),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 80, height: 36,
                    decoration: BoxDecoration(
                      color: e.value,
                      borderRadius: BorderRadius.circular(8),
                      border: sel ? Border.all(color: Colors.white, width: 3) : null,
                    ),
                    child: Center(child: Text(e.key,
                      style: const TextStyle(color: Colors.white,
                        fontWeight: FontWeight.bold, fontSize: 12))),
                  ),
                );
              }).toList()),
              const SizedBox(height: 24),

              // Fuente
              Row(children: [
                const Text('Tamaño de fuente', style: TextStyle(fontWeight: FontWeight.w600)),
                const Spacer(),
                Text('${fuenteTmp.toInt()} px',
                  style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
              ]),
              Slider(
                value: fuenteTmp, min: 11, max: 18, divisions: 7,
                onChanged: (v) => setModal(() => fuenteTmp = v),
              ),
              const SizedBox(height: 24),

              // Botones
              Row(children: [
                Expanded(child: OutlinedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                )),
                const SizedBox(width: 12),
                Expanded(child: FilledButton(
                  onPressed: () {
                    final prefs = {'tema': temaTmp, 'acento': acentoTmp, 'fuente': fuenteTmp.toInt()};
                    setState(() {
                      _darkMode = temaTmp == 'oscuro';
                      _acento   = acentoTmp;
                      _fontSize = fuenteTmp;
                    });
                    DigiHelpApp.of(context)?.applyPrefs(prefs);
                    _guardarPrefs(prefs);
                    Navigator.pop(ctx);
                  },
                  child: const Text('Aplicar'),
                )),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _temaBtn(BuildContext ctx, StateSetter setModal, String val, String label,
      String current, void Function(String) onSelect) {
    final sel = current == val;
    final cs  = Theme.of(ctx).colorScheme;
    return Expanded(
      child: GestureDetector(
        onTap: () => setModal(() => onSelect(val)),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: sel ? cs.primaryContainer : cs.surfaceVariant,
            borderRadius: BorderRadius.circular(10),
            border: sel ? Border.all(color: cs.primary, width: 2) : null,
          ),
          child: Center(child: Text(label,
            style: TextStyle(fontWeight: sel ? FontWeight.bold : FontWeight.normal))),
        ),
      ),
    );
  }

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titulo, overflow: TextOverflow.ellipsis),
        backgroundColor: cs.primaryContainer,
        actions: [
          IconButton(
            icon: const Icon(Icons.tune),
            tooltip: 'Personalización',
            onPressed: _abrirPersonalizacion,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushReplacement(context,
              MaterialPageRoute(builder: (_) => const LoginScreen())),
          ),
        ],
      ),

      // ── Drawer / sidebar ──────────────────────────────────────────────────────
      drawer: Drawer(
        child: Column(children: [
          DrawerHeader(
            decoration: BoxDecoration(color: cs.primaryContainer),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Icon(Icons.support_agent, size: 48, color: cs.primary),
              const SizedBox(height: 8),
              Text('Mis Chats',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: cs.onPrimaryContainer)),
            ]),
          ),
          ListTile(
            leading: Icon(Icons.add_circle_outline, color: cs.primary),
            title: const Text('Nuevo Chat', style: TextStyle(fontWeight: FontWeight.w600)),
            onTap: () { _nuevoChat(); Navigator.pop(context); },
          ),
          const Divider(),
          Expanded(
            child: _chatsGuardados.isEmpty
              ? Center(child: Text('Sin chats guardados',
                  style: TextStyle(color: cs.onSurfaceVariant)))
              : ListView.builder(
                  itemCount: _chatsGuardados.length,
                  itemBuilder: (_, i) {
                    final chat = _chatsGuardados[i];
                    final esChatActual = chat['chat_id'] == _chatId;
                    return ListTile(
                      selected: esChatActual,
                      selectedTileColor: cs.primaryContainer.withOpacity(0.4),
                      leading: Icon(Icons.chat_bubble_outline,
                        color: esChatActual ? cs.primary : cs.onSurfaceVariant, size: 20),
                      title: Text(chat['titulo'],
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: esChatActual ? FontWeight.bold : FontWeight.normal)),
                      subtitle: Text(chat['fecha'],
                        style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant)),
                      trailing: IconButton(
                        icon: Icon(Icons.delete_outline, color: cs.error, size: 20),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar chat'),
                              content: const Text('¿Seguro que quieres eliminarlo?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancelar')),
                                FilledButton(onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Eliminar')),
                              ],
                            ),
                          );
                          if (confirmar == true) _eliminarChat(chat['chat_id']);
                        },
                      ),
                      onTap: () => _cargarChatAntiguo(chat),
                    );
                  },
                ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(widget.nombreUsuario,
              style: TextStyle(color: cs.onSurfaceVariant, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),

      // ── Cuerpo ────────────────────────────────────────────────────────────────
      body: Column(children: [
        // Archivo seleccionado
        if (_archivo != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cs.secondaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(children: [
              Icon(Icons.attach_file, size: 18, color: cs.secondary),
              const SizedBox(width: 8),
              Expanded(child: Text(_archivo!.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: cs.onSecondaryContainer, fontSize: 13))),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _archivo = null),
              ),
            ]),
          ),

        // Mensajes
        Expanded(
          child: _mensajes.isEmpty
            ? _pantallaBienvenida(cs)
            : ListView.builder(
                controller: _scrollCtrl,
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                itemCount: _mensajes.length,
                itemBuilder: (_, i) => _buildBurbuja(_mensajes[i], cs),
              ),
        ),

        // Indicador de escritura
        if (_escribiendo)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: cs.primary)),
              const SizedBox(width: 10),
              Text('DigiHelp analizando…',
                style: TextStyle(color: cs.onSurfaceVariant, fontSize: 13)),
            ]),
          ),

        // Barra de entrada
        _buildEntrada(cs),
      ]),
    );
  }

  // ── Pantalla de bienvenida ────────────────────────────────────────────────────
  Widget _pantallaBienvenida(ColorScheme cs) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          CircleAvatar(radius: 44, backgroundColor: cs.primaryContainer,
            child: Icon(Icons.support_agent, size: 48, color: cs.primary)),
          const SizedBox(height: 20),
          Text('👋 Bienvenido, ${widget.nombreUsuario.split(' ').first}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center),
          const SizedBox(height: 12),
          Text('Describe tu incidencia IT y te ayudaré a resolverla paso a paso.',
            style: TextStyle(color: cs.onSurfaceVariant, fontSize: 15),
            textAlign: TextAlign.center),
          const SizedBox(height: 32),
          // Sugerencias rápidas
          Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
            children: ['🖨️ Impresora', '🌐 Internet', '💻 Ordenador lento', '🔑 Contraseña'].map((s) =>
              ActionChip(
                label: Text(s),
                onPressed: () {
                  _msgCtrl.text = s.substring(2).trim();
                  _enviar();
                },
              ),
            ).toList(),
          ),
        ]),
      ),
    );
  }

  // ── Burbuja de mensaje ────────────────────────────────────────────────────────
  Widget _buildBurbuja(Map<String, dynamic> msg, ColorScheme cs) {
    final isUser  = msg['rol'] == 'user';
    final texto   = msg['texto'] as String? ?? '';
    final ts      = msg['timestamp'] as String? ?? '';
    final video   = msg['ruta_video'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isUser) ...[
            CircleAvatar(radius: 16, backgroundColor: cs.primaryContainer,
              child: Icon(Icons.support_agent, size: 18, color: cs.primary)),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Nombre + timestamp
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 4, right: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isUser ? 'Tú' : 'DigiHelp AI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: isUser ? cs.primary : cs.secondary)),
                      if (ts.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(ts, style: TextStyle(fontSize: 10, color: cs.onSurfaceVariant)),
                      ],
                    ],
                  ),
                ),
                // Burbuja
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isUser ? cs.primary : cs.surfaceVariant,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(16),
                      topRight:    const Radius.circular(16),
                      bottomLeft:  Radius.circular(isUser ? 16 : 4),
                      bottomRight: Radius.circular(isUser ? 4  : 16),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(texto,
                        style: TextStyle(
                          color: isUser ? cs.onPrimary : cs.onSurfaceVariant,
                          fontSize: _fontSize,
                          height: 1.4,
                        ),
                      ),
                      if (video != null) ...[
                        const SizedBox(height: 10),
                        FilledButton.icon(
                          onPressed: () => _abrirVideo(video),
                          icon: const Icon(Icons.play_circle_fill, size: 18),
                          label: const Text('Ver Videotutorial'),
                          style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isUser) const SizedBox(width: 4),
        ],
      ),
    );
  }

  // ── Barra de entrada ──────────────────────────────────────────────────────────
  Widget _buildEntrada(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(children: [
        IconButton(
          icon: Icon(Icons.attach_file,
            color: _archivo != null ? cs.primary : cs.onSurfaceVariant),
          onPressed: () async {
            final r = await FilePicker.platform.pickFiles();
            if (r != null) setState(() => _archivo = r.files.first);
          },
        ),
        Expanded(
          child: TextField(
            controller: _msgCtrl,
            maxLines: null,
            textInputAction: TextInputAction.send,
            onSubmitted: (_) => _enviar(),
            decoration: InputDecoration(
              hintText: 'Describe tu problema…',
              filled: true,
              fillColor: cs.surfaceVariant,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        FilledButton(
          onPressed: _escribiendo ? null : _enviar,
          style: FilledButton.styleFrom(
            shape: const CircleBorder(),
            padding: const EdgeInsets.all(14),
          ),
          child: const Icon(Icons.send, size: 20),
        ),
      ]),
    );
  }
}