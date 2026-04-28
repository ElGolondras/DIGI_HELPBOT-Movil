import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart'; 

void main() {
  runApp(const DigiHelpApp());
}

class DigiHelpApp extends StatelessWidget {
  const DigiHelpApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DigiHelp',
      theme: ThemeData.dark(),
      home: const LoginScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _userController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  String _mensaje = '';
  bool _cargando = false;

  Future<void> _hacerLogin() async {
    setState(() { _cargando = true; _mensaje = ''; });

    final url = Uri.parse('http://10.0.2.2:8000/login'); 
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'username': _userController.text, 'password': _passController.text}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        final userMap = data['usuario'];

        if (!mounted) return;

        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(
            builder: (context) => ChatScreen(
              usuarioId: userMap['id'], 
              nombreUsuario: userMap['nombre_completo'], 
              emailUsuario: userMap['email'],           
              departamentoUsuario: userMap['departamento'] ?? 'Informatica', 
            ),
          ),
        );
      } else {
        setState(() => _mensaje = 'Error: Usuario o contraseña incorrectos');
      }
    } catch (e) {
      setState(() => _mensaje = 'Error de conexión con el servidor');
    } finally {
      setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.support_agent, size: 100, color: Colors.blueAccent),
              const SizedBox(height: 20),
              const Text('DigiHelp AI', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
              const Text('Soporte IT Corporativo', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 50),
              TextField(controller: _userController, decoration: const InputDecoration(labelText: 'Usuario', prefixIcon: Icon(Icons.person), border: OutlineInputBorder())),
              const SizedBox(height: 20),
              TextField(controller: _passController, obscureText: true, decoration: const InputDecoration(labelText: 'Contraseña', prefixIcon: Icon(Icons.lock), border: OutlineInputBorder())),
              const SizedBox(height: 40),
              _cargando 
                ? const CircularProgressIndicator()
                : ElevatedButton(
                    onPressed: _hacerLogin,
                    style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                    child: const Text('Iniciar Sesión', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
              const SizedBox(height: 20),
              Text(_mensaje, style: const TextStyle(color: Colors.redAccent)),
            ],
          ),
        ),
      ),
    );
  }
}

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
  final TextEditingController _mensajeController = TextEditingController();
  List<Map<String, dynamic>> _mensajes = [];
  bool _escribiendoIA = false;
  PlatformFile? _archivoSeleccionado;
  int _intentos = 0; 
  List<dynamic> _listaChatsGuardados = [];
  String _chatIdActual = '';
  String _tituloActual = 'Nuevo Chat';

  String _calcularUrgencia() {
    String charla = _mensajes.map((m) => m['texto']).join(" ").toLowerCase();
    if (charla.contains("urgente") || charla.contains("no enciende") || charla.contains("bloqueado")) return "alta";
    if (charla.contains("lento") || charla.contains("impresora") || charla.contains("internet")) return "media";
    return "baja";
  }

  @override
  void initState() {
    super.initState();
    _iniciarNuevoChat();
    _cargarHistorialDelServidor();
  }

  void _iniciarNuevoChat() {
    setState(() {
      _mensajes.clear();
      _intentos = 0;
      _chatIdActual = 'chat_${DateTime.now().millisecondsSinceEpoch}';
      _tituloActual = 'Nuevo Chat';
    });
  }

  Future<void> _cargarHistorialDelServidor() async {
    final url = Uri.parse('http://10.0.2.2:8000/cargar_chats/${widget.usuarioId}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        setState(() { _listaChatsGuardados = data['chats']; });
      }
    } catch (e) { print("Error historial: $e"); }
  }

  Future<void> _dispararIncidenciaAutomatica(String respuestaIA, [String? rutaVideo]) async {
    final url = Uri.parse('http://10.0.2.2:8000/crear_incidencia');
    String urgencia = _calcularUrgencia();
    
    String charlaCompleta = _mensajes.map((m) => "${m['rol']}: ${m['texto']}").join("\n");
    
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario': widget.nombreUsuario, 
          'problema': charlaCompleta,
          'urgencia': urgencia,
          'email': widget.emailUsuario,
          'departamento': widget.departamentoUsuario,
        }),
      );

      final data = jsonDecode(utf8.decode(response.bodyBytes));

      if (data['status'] == 'ok') {
        setState(() {
          _mensajes.add({
            'rol': 'assistant',
            'texto': '🤖 **SISTEMA:** He detectado que no podemos solucionar el problema por aquí. He abierto una incidencia para **${widget.departamentoUsuario}** con urgencia **$urgencia**. Un técnico te contactará en **${widget.emailUsuario}**.'
          });
          _intentos = 0; 
        });
      } else if (data['status'] == 'ignorado') {
        setState(() {
          _mensajes.add({'rol': 'assistant', 'texto': respuestaIA, 'ruta_video': rutaVideo});
          _intentos = 0; 
        });
      }
    } catch (e) { 
      setState(() {
        _mensajes.add({'rol': 'assistant', 'texto': respuestaIA, 'ruta_video': rutaVideo});
        _intentos = 0;
      });
    }
  }

  Future<void> _guardarChatEnServidor() async {
    if (_mensajes.isEmpty) return;
    if (_tituloActual == 'Nuevo Chat') {
      String primerMsj = _mensajes.firstWhere((m) => m['rol'] == 'user')['texto'];
      _tituloActual = primerMsj.length > 25 ? '${primerMsj.substring(0, 25)}...' : primerMsj;
    }

    final url = Uri.parse('http://10.0.2.2:8000/guardar_chat');
    try {
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'usuario_id': widget.usuarioId,
          'chat_id': _chatIdActual,
          'titulo': _tituloActual,
          'fecha': "${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}",
          // Guardamos 'ruta_video' en el servidor
          'mensajes': _mensajes.map((m) => {'role': m['rol'], 'content': m['texto'], 'ruta_video': m['ruta_video']}).toList(),
        }),
      );
      _cargarHistorialDelServidor();
    } catch (e) { print("Error guardado: $e"); }
  }

  void _cargarChatAntiguo(Map<String, dynamic> chat) {
    setState(() {
      _chatIdActual = chat['chat_id'];
      _tituloActual = chat['titulo'];
      _intentos = 0;
      List<dynamic> msgs = chat['mensajes'];
      _mensajes = msgs.map((m) => {
        'rol': (m['rol'] ?? m['role'] ?? 'user').toString(),
        'texto': (m['texto'] ?? m['content'] ?? '').toString(),
        'ruta_video': m['ruta_video'] 
      }).toList();
    });
    Navigator.pop(context); 
  }

  // 👉 FUNCIÓN PARA ABRIR LA URL
  Future<void> _abrirVideo(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se pudo abrir el enlace")));
    }
  }

  Future<void> _enviarMensaje() async {
    String texto = _mensajeController.text.trim();
    if (texto.isEmpty && _archivoSeleccionado == null) return;

    setState(() {
      _mensajes.add({'rol': 'user', 'texto': _archivoSeleccionado != null ? "📎 ${_archivoSeleccionado!.name}\n$texto" : texto});
      _mensajeController.clear();
      _escribiendoIA = true;
    });

    final url = Uri.parse('http://10.0.2.2:8000/chat_multimodal');
    try {
      var request = http.MultipartRequest('POST', url);
      request.fields['mensaje'] = texto;
      request.fields['historial'] = jsonEncode(_mensajes);

      if (_archivoSeleccionado != null) {
        request.files.add(await http.MultipartFile.fromPath('archivo', _archivoSeleccionado!.path!));
      }

      var resStream = await request.send();
      var response = await http.Response.fromStream(resStream);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes));
        
        _intentos++; 
        
        if (_intentos < 5) {
          setState(() {
            _mensajes.add({
              'rol': 'assistant', 
              'texto': data['respuesta'],
              'ruta_video': data['ruta_video'] // 👉 Ahora usa tu variable exacta
            });
          });
        } else {
          await _dispararIncidenciaAutomatica(data['respuesta'], data['ruta_video']);
        }

        _guardarChatEnServidor();
      }
    } catch (e) {
      setState(() => _mensajes.add({'rol': 'assistant', 'texto': '❌ Error de conexión.'}));
    } finally {
      setState(() { _escribiendoIA = false; _archivoSeleccionado = null; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tituloActual),
        backgroundColor: Colors.blueAccent,
        actions: [
          IconButton(icon: const Icon(Icons.logout), onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginScreen())))
        ],
      ),
      drawer: Drawer(
        backgroundColor: Colors.grey[900],
        child: Column(
          children: [
            const DrawerHeader(decoration: BoxDecoration(color: Colors.blueAccent), child: Center(child: Text('Mis Chats', style: TextStyle(color: Colors.white, fontSize: 24)))),
            ListTile(leading: const Icon(Icons.add), title: const Text('Nuevo Chat'), onTap: () { _iniciarNuevoChat(); Navigator.pop(context); }),
            const Divider(),
            Expanded(
              child: ListView.builder(
                itemCount: _listaChatsGuardados.length,
                itemBuilder: (context, index) {
                  final chat = _listaChatsGuardados[index];
                  return ListTile(
                    title: Text(chat['titulo'], maxLines: 1),
                    subtitle: Text(chat['fecha']),
                    onTap: () => _cargarChatAntiguo(chat),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _mensajes.length,
              itemBuilder: (context, index) {
                final msg = _mensajes[index];
                final isUser = msg['rol'] == 'user';
                return Align(
                  alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(color: isUser ? Colors.blueAccent : Colors.grey[800], borderRadius: BorderRadius.circular(15)),
                    // 👉 DIBUJA EL BOTÓN SI EXISTE LA RUTA
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(msg['texto'] ?? '', style: const TextStyle(color: Colors.white)),
                        if (msg['ruta_video'] != null) ...[
                          const SizedBox(height: 10),
                          ElevatedButton.icon(
                            onPressed: () => _abrirVideo(msg['ruta_video']), 
                            icon: const Icon(Icons.play_circle_fill, color: Colors.white), 
                            label: const Text("Ver Videotutorial", style: TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
                          )
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_escribiendoIA) const Padding(padding: EdgeInsets.all(8), child: Text("DigiHelp analizando...", style: TextStyle(color: Colors.grey))),
          Container(
            padding: const EdgeInsets.all(8),
            color: Colors.grey[900],
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.attach_file), onPressed: () async {
                  FilePickerResult? res = await FilePicker.platform.pickFiles();
                  if (res != null) setState(() => _archivoSeleccionado = res.files.first);
                }),
                Expanded(child: TextField(controller: _mensajeController, decoration: const InputDecoration(hintText: 'Escribe aquí...'))),
                IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _enviarMensaje),
              ],
            ),
          ),
        ],
      ),
    );
  }
}