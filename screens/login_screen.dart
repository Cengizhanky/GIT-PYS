import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _logoUrl;
  bool _isSvg = false;

  @override
  void initState() {
    super.initState();
    _fetchLogoUrl();
  }

  /// Supabase Storage'dan logo URL'sini al
  Future<void> _fetchLogoUrl() async {
    try {
      final storage = Supabase.instance.client.storage.from('logos');
      final pngUrl = storage.getPublicUrl('git_pys_logo.png');
      final svgUrl = storage.getPublicUrl('git_pys_logo.svg');

      setState(() {
        _logoUrl = pngUrl;
        _isSvg = false;

        if (svgUrl.isNotEmpty) {
          _logoUrl = svgUrl;
          _isSvg = true;
        }
      });

      debugPrint("Logo URL: $_logoUrl");
    } catch (e) {
      debugPrint("Logo yüklenirken hata oluştu: $e");
    }
  }

  void _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    String username = _usernameController.text.trim();
    String password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı adı ve şifre boş olamaz!", style: TextStyle(color: hexToColor("#FFFFFF"))), // HEX ile renk
            backgroundColor: hexToColor("#FF0000"), // HEX ile kırmızı arka plan
          ));
      setState(() {
        _isLoading = false;
      });
      return;
    }

    try {
      final response = await Supabase.instance.client
          .from('users')
          .select('username, role, is_admin')
          .eq('username', username)
          .eq('password', password)
          .maybeSingle();

      if (response == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Kullanıcı adı veya şifre yanlış!", style: TextStyle(color: hexToColor("#FFFFFF"))),
              backgroundColor: hexToColor("#FF0000")),
        );
      } else {
        String role = response['role'] ?? "Bilinmeyen";
        bool isAdmin = response['is_admin'] ?? false;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainScreen(
              username: username,
              role: role,
              isAdmin: isAdmin,
            ),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Giriş sırasında bir hata oluştu: $e", style: TextStyle(color: hexToColor("#FFFFFF"))),
            backgroundColor: hexToColor("#FF0000")),
      );
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              hexToColor("#37474F"), // Arka planın üst kısmı
              hexToColor("#607D8B"), // Arka planın alt kısmı
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _logoUrl == null
                    ? CircularProgressIndicator(color: hexToColor("#FFFFFF"))
                    : _isSvg
                    ? SvgPicture.network(
                  _logoUrl!,
                  height: 100,
                  width: 100,
                  placeholderBuilder: (context) =>
                      CircularProgressIndicator(color: hexToColor("#FFFFFF")),
                )
                    : Image.network(
                  _logoUrl!,
                  height: 100,
                  width: 100,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 20),

                // **Giriş Formu Kartı**
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 8,
                  color: hexToColor("#FFFFFF"),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text(
                          "Hoş Geldiniz!",
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            color: hexToColor("#0093d6"),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          "Lütfen giriş yapın",
                          style: TextStyle(
                            fontSize: 16,
                            color: hexToColor("#455A64"),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // **Kullanıcı Adı Alanı**
                        TextField(
                          controller: _usernameController,
                          decoration: InputDecoration(
                            labelText: "Kullanıcı Adı",
                            labelStyle: TextStyle(color: hexToColor("#0093d6")), // HEX ile renk
                            prefixIcon: Icon(Icons.person, color: hexToColor("#0093d6")),
                            filled: true,
                            fillColor: hexToColor("#E3F2FD"),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // **Şifre Alanı**
                        TextField(
                          controller: _passwordController,
                          obscureText: true,
                          decoration: InputDecoration(
                            labelText: "Şifre",
                            labelStyle: TextStyle(color: hexToColor("#0093d6")),
                            prefixIcon: Icon(Icons.lock, color: hexToColor("#0093d6")),
                            filled: true,
                            fillColor: hexToColor("#E3F2FD"),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(30),
                              borderSide: BorderSide.none,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // **Giriş Yap Butonu**
                        ElevatedButton(
                          onPressed: _isLoading ? null : _handleLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: hexToColor("#0093d6"),
                            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(30),
                            ),
                            elevation: 5,
                          ),
                          child: _isLoading
                              ? CircularProgressIndicator(color: hexToColor("#FFFFFF"))
                              : Text(
                            "Giriş Yap",
                            style: TextStyle(fontSize: 18, color: hexToColor("#FFFFFF")),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color hexToColor(String hexCode) {
    hexCode = hexCode.replaceAll("#", "");
    if (hexCode.length == 6) {
      hexCode = "FF$hexCode";
    }
    return Color(int.parse(hexCode, radix: 16));
  }
}
