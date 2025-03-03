import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'imalat_screen.dart';

class MainScreen extends StatefulWidget {
  final String username;
  final String role;
  final bool isAdmin;

  const MainScreen({
    Key? key,
    required this.username,
    required this.role,
    required this.isAdmin,
  }) : super(key: key);

  @override
  _MainScreenState createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  bool isExpanded = false;
  bool showText = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          _buildNavigationBar(context),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.blueGrey.shade800, Colors.blueGrey.shade600],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.white,
                    child: Icon(Icons.person, size: 50, color: Colors.blueGrey.shade800),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    "Hoş Geldiniz, ${widget.username}!",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    widget.role,
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.white70,
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

  Widget _buildNavigationBar(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() {
        isExpanded = true;
        Future.delayed(const Duration(milliseconds: 50), () {
          setState(() => showText = true);
        });
      }),
      onExit: (_) => setState(() {
        isExpanded = false;
        showText = false;
      }),
      child: AnimatedContainer(
        duration: Duration(milliseconds: 100),
        width: isExpanded ? 260 : 80,
        decoration: BoxDecoration(
          color: Colors.blueGrey.shade900,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(3, 0),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            _buildNavItem(Icons.dashboard, "Dashboard", () {}),
            Divider(color: Colors.white54, thickness: 1),
            _buildNavItem(Icons.build_rounded, "İmalat", () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ImalatScreen()),
              );
            }),
            _buildNavItem(Icons.local_shipping_rounded, "Sevk", () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Sevk ekranı açılacak..."),
                  backgroundColor: Colors.orange,
                ),
              );
            }),
            Spacer(),
            Divider(color: Colors.white54, thickness: 1),
            _buildNavItem(Icons.logout, "Çıkış Yap", () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            }, Colors.redAccent),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, VoidCallback? onTap, [Color? color]) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Row(
          children: [
            Icon(icon, color: color ?? Colors.white, size: 30),
            if (showText)
              const SizedBox(width: 10),
            if (showText)
              Expanded(
                child: Text(label, style: TextStyle(color: color ?? Colors.white, fontSize: 18)),
              ),
          ],
        ),
      ),
    );
  }
}
