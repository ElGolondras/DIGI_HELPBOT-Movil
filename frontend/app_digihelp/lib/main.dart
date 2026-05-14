import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

// ─── Colores de acento — idénticos a la versión PC ───────────────────────────
const Map<String, Color> kAcentos = {
  'Azul':    Color(0xFF2563EB),
  'Violeta': Color(0xFF7C3AED),
  'Verde':   Color(0xFF16A34A),
  'Rojo':    Color(0xFFDC2626),
  'Naranja': Color(0xFFEA580C),
  'Rosa':    Color(0xFFDB2777),
};

// ─── Paletas de tema — idénticas a la versión PC ─────────────────────────────
const Map<String, Map<String, Color>> kTemas = {
  'oscuro': {
    'bg_app':      Color(0xFF0F172A),
    'sidebar_bg':  Color(0xFF0A0F1E),
    'sidebar_hover': Color(0xFF1E293B),
    'bubble_ia':   Color(0xFF1E293B),
    'text_dark':   Color(0xFFF1F5F9),
    'text_muted':  Color(0xFF64748B),
    'input_bg':    Color(0xFF1E293B),
    'border':      Color(0xFF334155),
    'card':        Color(0xFF1E293B),
    'header_bg':   Color(0xFF0F172A),
  },
  'claro': {
    'bg_app':      Color(0xFFF0F2F5),
    'sidebar_bg':  Color(0xFF1B2A4A),
    'sidebar_hover': Color(0xFF243557),
    'bubble_ia':   Color(0xFFFFFFFF),
    'text_dark':   Color(0xFF1E293B),
    'text_muted':  Color(0xFF94A3B8),
    'input_bg':    Color(0xFFFFFFFF),
    'border':      Color(0xFFCBD5E1),
    'card':        Color(0xFFFFFFFF),
    'header_bg':   Color(0xFFFFFFFF),
  },
};

const String kBaseUrl = 'https://digi-helpbot-api.onrender.com';

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
    } catch (e) {
      setState(() => _msg = 'Error: ${e.toString().substring(0, e.toString().length.clamp(0, 150))}');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Fondo oscuro igual que la versión PC
    const bgColor     = Color(0xFF0F172A);
    const cardColor   = Color(0xFF1E293B);
    const borderColor = Color(0xFF334155);
    const accentColor = Color(0xFF2563EB);
    const textMuted   = Color(0xFF94A3B8);

    return Scaffold(
      backgroundColor: bgColor,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              children: [
                // ── Logo igual que sidebar PC ──────────────────────────────
                Container(
                  width: 96, height: 96,
                  decoration: BoxDecoration(
                    color: accentColor,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: accentColor.withOpacity(0.4), blurRadius: 20, spreadRadius: 2)],
                  ),
                  child: ClipOval(
                    child: Image.asset('assets/avatar.png', fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(Icons.support_agent, size: 52, color: Colors.white)),
                  ),
                ),
                const SizedBox(height: 20),
                const Text('DigiHelp AI',
                  style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                const Text('Soporte IT Corporativo',
                  style: TextStyle(color: textMuted, fontSize: 14)),
                const SizedBox(height: 40),
                // ── Card contenedor — igual que card PC ───────────────────
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: borderColor),
                    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 16, offset: const Offset(0, 4))],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Usuario', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _userCtrl,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Introduce tu usuario',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          prefixIcon: const Icon(Icons.person_outline, color: textMuted),
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accentColor, width: 2)),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 16),
                      const Text('Contraseña', style: TextStyle(color: textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _passCtrl,
                        obscureText: _obscure,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Introduce tu contraseña',
                          hintStyle: const TextStyle(color: Color(0xFF475569)),
                          prefixIcon: const Icon(Icons.lock_outline, color: textMuted),
                          filled: true,
                          fillColor: bgColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                          enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: borderColor)),
                          focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: accentColor, width: 2)),
                          suffixIcon: IconButton(
                            icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility, color: textMuted),
                            onPressed: () => setState(() => _obscure = !_obscure),
                          ),
                        ),
                        onSubmitted: (_) => _login(),
                      ),
                      const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity, height: 52,
                        child: _loading
                          ? const Center(child: CircularProgressIndicator(color: accentColor))
                          : ElevatedButton(
                              onPressed: _login,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accentColor,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 0,
                              ),
                              child: const Text('Entrar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                            ),
                      ),
                      if (_msg.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        Text(_msg, style: const TextStyle(color: Colors.redAccent, fontSize: 13), textAlign: TextAlign.center),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Soporte IT · v2.0', style: TextStyle(color: Color(0xFF475569), fontSize: 12)),
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

      final resStream = await request.send().timeout(const Duration(seconds: 60));
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
    } catch (e) {
      setState(() => _mensajes.add({
        'rol': 'assistant',
        'texto': '❌ Error de conexión: ${e.toString().substring(0, e.toString().length.clamp(0, 120))}',
        'timestamp': _nowTimestamp()
      }));
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
      String urlFinal = url;
      if (!url.startsWith('http')) {
        urlFinal = 'https://drive.google.com/file/d/$url/preview';
      } else if (url.contains('drive.google.com/file/d/')) {
        final id = url.split('/file/d/')[1].split('/')[0].split('?')[0];
        urlFinal = 'https://drive.google.com/file/d/$id/preview';
      } else if (url.contains('drive.google.com') && url.contains('id=')) {
        final id = url.split('id=')[1].split('&')[0];
        urlFinal = 'https://drive.google.com/file/d/$id/preview';
      }
      final uri = Uri.parse(urlFinal);
      if (!await launchUrl(uri, mode: LaunchMode.inAppWebView)) {
        if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No se pudo abrir el tutorial')));
        }
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error al abrir el vídeo: $e')));
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

  // ── Helpers de color según tema PC ───────────────────────────────────────────
  Map<String, Color> get _t => kTemas[_darkMode ? 'oscuro' : 'claro']!;
  Color get _accent => kAcentos[_acento] ?? const Color(0xFF2563EB);

  // ── BUILD ─────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final t = _t;
    return Scaffold(
      backgroundColor: t['bg_app'],
      appBar: AppBar(
        backgroundColor: t['header_bg'],
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        iconTheme: IconThemeData(color: t['text_dark']),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_titulo, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: t['text_dark'])),
            Row(children: [
              Container(width: 7, height: 7, margin: const EdgeInsets.only(right: 5),
                decoration: const BoxDecoration(color: Color(0xFF22C55E), shape: BoxShape.circle)),
              Text('En línea', style: TextStyle(fontSize: 11, color: t['text_muted'])),
            ]),
          ],
        ),
        bottom: PreferredSize(preferredSize: const Size.fromHeight(1),
          child: Container(height: 1, color: t['border'])),
        actions: [
          IconButton(icon: Icon(Icons.tune, color: t['text_dark']), tooltip: 'Personalización', onPressed: _abrirPersonalizacion),
          IconButton(icon: Icon(Icons.logout, color: t['text_dark']), tooltip: 'Cerrar sesión',
            onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen()))),
        ],
      ),

      // ── Drawer / sidebar — azul marino igual que PC ────────────────────────
      drawer: Drawer(
        backgroundColor: _t['sidebar_bg'],
        child: Column(children: [
          // Header sidebar — logo + nombre
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(16, 52, 16, 20),
            color: _t['sidebar_bg'],
            child: Column(children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(color: _accent, shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: _accent.withOpacity(0.4), blurRadius: 12)]),
                child: ClipOval(
                  child: Image.asset('assets/avatar.png', fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(Icons.support_agent, size: 32, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
              const Text('DigiHelp AI', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text(widget.nombreUsuario, style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12), overflow: TextOverflow.ellipsis),
              Text(widget.departamentoUsuario, style: const TextStyle(color: Color(0xFF64748B), fontSize: 11)),
            ]),
          ),
          // Botón nuevo chat — igual que PC
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nuevo Chat', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accent,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () { _nuevoChat(); Navigator.pop(context); },
              ),
            ),
          ),
          Divider(color: const Color(0xFF243557), height: 12),
          // Lista de chats
          Expanded(
            child: _chatsGuardados.isEmpty
              ? Center(child: Text('Sin chats guardados', style: TextStyle(color: _t['text_muted'])))
              : ListView.builder(
                  itemCount: _chatsGuardados.length,
                  itemBuilder: (_, i) {
                    final chat = _chatsGuardados[i];
                    final esChatActual = chat['chat_id'] == _chatId;
                    return ListTile(
                      selected: esChatActual,
                      selectedTileColor: const Color(0xFF243557),
                      leading: Icon(Icons.chat_bubble_outline,
                        color: esChatActual ? _accent : const Color(0xFF64748B), size: 18),
                      title: Text(chat['titulo'], maxLines: 1, overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: esChatActual ? _accent : Colors.white,
                          fontWeight: esChatActual ? FontWeight.bold : FontWeight.normal, fontSize: 13)),
                      subtitle: Text(chat['fecha'], style: const TextStyle(fontSize: 10, color: Color(0xFF64748B))),
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline, color: Color(0xFF64748B), size: 18),
                        onPressed: () async {
                          final confirmar = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              title: const Text('Eliminar chat'),
                              content: const Text('¿Seguro que quieres eliminarlo?'),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
                                FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Eliminar')),
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
          Divider(color: const Color(0xFF243557), height: 1),
          // Footer — cerrar sesión igual que PC
          Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.power_settings_new, size: 18),
                label: const Text('Cerrar sesión', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFDC2626),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Text('Soporte IT · v2.0', style: TextStyle(color: Color(0xFF475569), fontSize: 11)),
          const SizedBox(height: 12),
        ]),
      ),

      // ── Cuerpo ────────────────────────────────────────────────────────────────
      body: Column(children: [
        // Preview archivo seleccionado
        if (_archivo != null)
          Container(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: _t['card'],
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _accent),
            ),
            child: Row(children: [
              Icon(Icons.attach_file, size: 18, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: Text(_archivo!.name, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: _t['text_dark'], fontSize: 13))),
              IconButton(
                icon: Icon(Icons.close, size: 18, color: _t['text_muted']),
                onPressed: () => setState(() => _archivo = null),
              ),
            ]),
          ),

        // Mensajes
        Expanded(
          child: Container(
            color: _t['bg_app'],
            child: _mensajes.isEmpty
              ? _pantallaBienvenida()
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
                  itemCount: _mensajes.length,
                  itemBuilder: (_, i) => _buildBurbuja(_mensajes[i], Theme.of(context).colorScheme),
                ),
          ),
        ),

        // Indicador de escritura
        if (_escribiendo)
          Container(
            color: _t['bg_app'],
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(children: [
              SizedBox(width: 16, height: 16,
                child: CircularProgressIndicator(strokeWidth: 2, color: _accent)),
              const SizedBox(width: 10),
              Text('DigiHelp analizando…', style: TextStyle(color: _t['text_muted'], fontSize: 13)),
            ]),
          ),

        // Barra de entrada
        _buildEntrada(),
      ]),
    );
  }

  // ── Pantalla de bienvenida — estética PC ────────────────────────────────────
  Widget _pantallaBienvenida() {
    return Container(
      color: _t['bg_app'],
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 88, height: 88,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: _accent.withOpacity(0.3), blurRadius: 16)]),
              child: ClipOval(
                child: Image.asset('assets/avatar.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.support_agent, size: 48, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Bienvenido a DigiHelp AI',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: _t['text_dark']),
              textAlign: TextAlign.center),
            const SizedBox(height: 10),
            Text('Describe tu incidencia IT y te ayudaré a resolverla paso a paso.',
              style: TextStyle(color: _t['text_muted'], fontSize: 14), textAlign: TextAlign.center),
            const SizedBox(height: 28),
            // Sugerencias — igual que cards de bienvenida del PC
            Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center,
              children: [
                'Mi impresora no conecta a la red',
                'No puedo acceder a la VPN',
                'Mi equipo está muy lento',
                'Olvidé mi contraseña de dominio',
              ].map((s) => GestureDetector(
                onTap: () { _msgCtrl.text = s; _enviar(); },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: _t['card'],
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: _accent),
                  ),
                  child: Text(s, style: TextStyle(color: _accent, fontSize: 13, fontWeight: FontWeight.w500)),
                ),
              )).toList(),
            ),
          ]),
        ),
      ),
    );
  }

  // ── Burbuja de mensaje — colores idénticos a versión PC ─────────────────────
  Widget _buildBurbuja(Map<String, dynamic> msg, ColorScheme cs) {
    final isUser = msg['rol'] == 'user';
    final texto  = msg['texto'] as String? ?? '';
    final ts     = msg['timestamp'] as String? ?? '';
    final video  = msg['ruta_video'] as String?;
    final t      = _t;

    final bubbleColor  = isUser ? _accent : t['bubble_ia']!;
    final textColor    = isUser ? Colors.white : t['text_dark']!;
    final borderColor  = isUser ? Colors.transparent : t['border']!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        mainAxisAlignment: isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Avatar IA — logo igual que sidebar PC
          if (!isUser) ...[
            Container(
              width: 32, height: 32,
              decoration: BoxDecoration(color: _accent, shape: BoxShape.circle),
              child: ClipOval(
                child: Image.asset('assets/avatar.png', fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.support_agent, size: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: [
                // Nombre + timestamp
                Padding(
                  padding: const EdgeInsets.only(bottom: 4, left: 2, right: 2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(isUser ? 'Tú' : 'DigiHelp AI',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: _accent)),
                      if (ts.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Text(ts, style: TextStyle(fontSize: 10, color: t['text_muted'])),
                      ],
                    ],
                  ),
                ),
                // Burbuja — igual que PC
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: BorderRadius.only(
                      topLeft:     const Radius.circular(14),
                      topRight:    const Radius.circular(14),
                      bottomLeft:  Radius.circular(isUser ? 14 : 4),
                      bottomRight: Radius.circular(isUser ? 4  : 14),
                    ),
                    border: Border.all(color: borderColor, width: isUser ? 0 : 1),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(texto,
                        style: TextStyle(color: textColor, fontSize: _fontSize, height: 1.5)),
                      if (video != null) ...[
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () => _abrirVideo(video),
                          icon: const Icon(Icons.play_circle_fill, size: 18),
                          label: const Text('Ver Videotutorial', style: TextStyle(fontWeight: FontWeight.bold)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFDC2626),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
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

  // ── Barra de entrada — estética PC ──────────────────────────────────────────
  Widget _buildEntrada() {
    final bottomPadding = MediaQuery.of(context).padding.bottom + 10;
    return Container(
      padding: EdgeInsets.fromLTRB(10, 10, 10, bottomPadding),
      decoration: BoxDecoration(
        color: _t['header_bg'],
        border: Border(top: BorderSide(color: _t['border']!)),
      ),
      child: Row(children: [
        // Botón adjuntar — igual que PC
        Container(
          width: 44, height: 44,
          decoration: BoxDecoration(
            color: _t['card'],
            shape: BoxShape.circle,
            border: Border.all(color: _archivo != null ? _accent : _t['border']!),
          ),
          child: IconButton(
            icon: Icon(Icons.attach_file, size: 20,
              color: _archivo != null ? _accent : _t['text_muted']),
            onPressed: () async {
              final r = await FilePicker.platform.pickFiles();
              if (r != null) setState(() => _archivo = r.files.first);
            },
          ),
        ),
        const SizedBox(width: 8),
        // Campo de texto — pill igual que PC
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: _t['input_bg'],
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: _t['border']!),
            ),
            child: TextField(
              controller: _msgCtrl,
              maxLines: null,
              textInputAction: TextInputAction.send,
              style: TextStyle(color: _t['text_dark'], fontSize: _fontSize),
              onSubmitted: (_) => _enviar(),
              decoration: InputDecoration(
                hintText: 'Describe tu incidencia IT aquí...',
                hintStyle: TextStyle(color: _t['text_muted'], fontSize: 13),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        // Botón enviar circular — color acento igual que PC
        SizedBox(
          width: 48, height: 48,
          child: ElevatedButton(
            onPressed: _escribiendo ? null : _enviar,
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.white,
              shape: const CircleBorder(),
              padding: EdgeInsets.zero,
              elevation: 0,
            ),
            child: const Icon(Icons.send, size: 20),
          ),
        ),
      ]),
    );
  }
}