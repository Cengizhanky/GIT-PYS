import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'bom_screen.dart';

class ImalatScreen extends StatefulWidget {
  const ImalatScreen({Key? key}) : super(key: key);

  @override
  _ImalatScreenState createState() => _ImalatScreenState();
}

class _ImalatScreenState extends State<ImalatScreen> with SingleTickerProviderStateMixin {
  final SupabaseClient _supabase = Supabase.instance.client;
  final TextEditingController _projectController = TextEditingController();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  List<dynamic> _jobs = [];
  List<dynamic> _hierarchy = [];
  bool _isLoading = false;
  String? _selectedCompany;
  String? _selectedProject;
  String? _selectedLine;
  String? _selectedStation;

  late TabController _tabController;
  List<String> _companies = [];

  @override
  void initState() {
    super.initState();
    _fetchJobs();
    _fetchHierarchy();
  }

  Future<void> _fetchJobs() async {
    setState(() => _isLoading = true);
    final response = await _supabase.from('jobs').select();
    setState(() {
      _jobs = response;
      _isLoading = false;
    });
    }

  Future<void> _fetchHierarchy() async {
    final response = await _supabase.from('job_hierarchy').select();
    setState(() {
      _hierarchy = response;
      _companies = _getUniqueValues("company");
      _tabController = TabController(length: _companies.length, vsync: this);
    });
    }

  List<String> _getUniqueValues(String key) {
    return _hierarchy.map((e) => e[key] as String).toSet().toList();
  }

  List<String> _getFilteredValues(String targetKey, String filterKey, String filterValue) {
    return _hierarchy
        .where((e) => e[filterKey] == filterValue)
        .map((e) => e[targetKey] as String)
        .toSet()
        .toList();
  }

  void _showAddJobDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
              title: const Text(
                "Yeni İş Ekle",
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildDropdown(
                      hint: "Firma Seçiniz",
                      value: _selectedCompany,
                      items: _getUniqueValues("company"),
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedCompany = value;
                          _selectedProject = null;
                          _selectedLine = null;
                          _selectedStation = null;
                        });
                      },
                    ),
                    _buildDropdown(
                      hint: "Proje Seçiniz",
                      value: _selectedProject,
                      items: _selectedCompany != null
                          ? _getFilteredValues("project", "company", _selectedCompany!)
                          : [],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedProject = value;
                          _selectedLine = null;
                          _selectedStation = null;
                        });
                      },
                    ),
                    _buildDropdown(
                      hint: "Hat Seçiniz",
                      value: _selectedLine,
                      items: _selectedProject != null
                          ? _getFilteredValues("line", "project", _selectedProject!)
                          : [],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedLine = value;
                          _selectedStation = null;
                        });
                      },
                    ),
                    _buildDropdown(
                      hint: "İstasyon Seçiniz",
                      value: _selectedStation,
                      items: _selectedLine != null
                          ? _getFilteredValues("station", "line", _selectedLine!)
                          : [],
                      onChanged: (value) {
                        setDialogState(() {
                          _selectedStation = value;
                        });
                      },
                    ),
                    TextField(
                      controller: _codeController,
                      decoration: InputDecoration(
                        labelText: "Proje İş Kodu",
                        prefixIcon: const Icon(Icons.code, color: Colors.blueAccent),
                        filled: true,
                        fillColor: Colors.blueAccent.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                    TextField(
                      controller: _descriptionController,
                      decoration: InputDecoration(
                        labelText: "Açıklama",
                        prefixIcon: const Icon(Icons.description, color: Colors.blueAccent),
                        filled: true,
                        fillColor: Colors.blueAccent.withOpacity(0.1),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _clearControllers();
                  },
                  child: const Text("İptal", style: TextStyle(color: Colors.red)),
                ),
                ElevatedButton(
                  onPressed: _addJob,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text("Kaydet", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildDropdown({
    required String hint,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: hint,
          prefixIcon: const Icon(Icons.arrow_drop_down, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.blueAccent.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        value: value,
        items: items.map((e) => DropdownMenuItem<String>(value: e, child: Text(e))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Future<void> _addJob() async {
    if (_selectedCompany == null ||
        _selectedProject == null ||
        _selectedLine == null ||
        _selectedStation == null ||
        _codeController.text.trim().isEmpty ||
        _descriptionController.text.trim().isEmpty) {
      return;
    }

    await _supabase.from('jobs').insert({
      'company': _selectedCompany,
      'project': _selectedProject,
      'line': _selectedLine,
      'station': _selectedStation,
      'project_code': _codeController.text.trim(),
      'description': _descriptionController.text.trim(),
    });

    _clearControllers();
    Navigator.pop(context);
    _fetchJobs();
  }

  void _clearControllers() {
    _projectController.clear();
    _codeController.clear();
    _descriptionController.clear();
    setState(() {
      _selectedCompany = null;
      _selectedProject = null;
      _selectedLine = null;
      _selectedStation = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "İmalat Yönetimi",
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        elevation: 4,
        bottom: _companies.isNotEmpty
            ? TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: _companies.map((company) => Tab(text: company)).toList(),
        )
            : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? const Center(
        child: Text(
          "Henüz iş bulunmamaktadır.",
          style: TextStyle(fontSize: 18, color: Colors.grey),
        ),
      )
          : TabBarView(
        controller: _tabController,
        children: _companies.map((company) {
          final companyJobs = _jobs.where((job) => job['company'] == company).toList();
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: companyJobs.isEmpty
                ? const Center(
              child: Text(
                "Henüz iş bulunmamaktadır.",
                style: TextStyle(fontSize: 18, color: Colors.grey),
              ),
            )
                : ListView.builder(
              itemCount: companyJobs.length,
              itemBuilder: (context, index) {
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ListTile(
                    leading: const Icon(Icons.build, color: Colors.blueAccent, size: 30),
                    title: Text(
                      "${companyJobs[index]['project']} - ${companyJobs[index]['project_code']}",
                      style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Hat: ${companyJobs[index]['line']}"),
                        Text("İstasyon: ${companyJobs[index]['station']}"),
                        Text("Açıklama: ${companyJobs[index]['description']}"),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 18, color: Colors.grey),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BomScreen(
                            jobId: companyJobs[index]['id'],
                            projectName: companyJobs[index]['description'],
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          );
        }).toList(),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddJobDialog,
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}