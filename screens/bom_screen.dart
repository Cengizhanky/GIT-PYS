import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:excel/excel.dart';
import 'package:excel/excel.dart' as excel;
import 'package:universal_html/html.dart' as html;
import 'package:flutter/foundation.dart';
import 'dart:io';

class BomScreen extends StatefulWidget {
  final int jobId;
  final String projectName;

  const BomScreen({Key? key, required this.jobId, required this.projectName}) : super(key: key);

  @override
  _BomScreenState createState() => _BomScreenState();
}

class _BomScreenState extends State<BomScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<dynamic> _bomList = [];
  List<dynamic> _users = [];
  Map<String, List<dynamic>> _groupedBomList = {};
  bool _isLoading = false;
  String? _selectedGroup;

  // Yeni eklenen state değişkenleri
  String _searchTerm = '';
  String _selectedOrderStatus = 'Tümü';
  String _selectedDeliveryStatus = 'Tümü';
  List<String> _selectedProductGroups = []; // Ürün grubu filtresi için liste

  @override
  void initState() {
    super.initState();
    _fetchBomList();
  }

  // Yeni eklenen yardımcı metot
  List<dynamic> _filterBomList(List<dynamic> list) {
    return list.where((item) {
      final matchesSearchTerm = item['parca_adi']?.contains(_searchTerm) ?? true;
      final matchesOrderStatus = _selectedOrderStatus == 'Tümü' || (item['siparis_verildi'] == true ? 'OK' : 'NOK') == _selectedOrderStatus;
      final matchesDeliveryStatus = _selectedDeliveryStatus == 'Tümü' || (item['teslim_alindi'] == true ? 'OK' : 'NOK') == _selectedDeliveryStatus;
      final matchesProductGroup = _selectedProductGroups.isEmpty || _selectedProductGroups.contains(item['urun_grubu']);
      return matchesSearchTerm && matchesOrderStatus && matchesDeliveryStatus && matchesProductGroup;
    }).toList();
  }

  /// Supabase'den BOM listesini çek ve urun_grubu'na göre grupla
  Future<void> _fetchBomList() async {
    setState(() => _isLoading = true);
    final response = await _supabase.from('job_details').select().eq('job_id', widget.jobId);
    final userResponse = await _supabase.from('users').select().eq('role', 'Lojistik ve Satın Alma');
    setState(() {
      _groupedBomList = _groupByUrunGrubu(response);
      _users = userResponse;
      _isLoading = false;
    });
  }

  Map<String, List<dynamic>> _groupByUrunGrubu(List<dynamic> list) {
    // Sadece "İMALAT LİSTE" ve "SATIN ALMA LİSTESİ" gruplarını oluştur
    Map<String, List<dynamic>> groupedMap = {"İMALAT LİSTESİ": [], "SATIN ALMA LİSTESİ": []};
    for (var item in list) {
      String key = item['urun_grubu'] ?? 'Diğer';
      groupedMap["İMALAT LİSTESİ"]!.add(item);

      // "SATIN ALMA LİSTESİ"ne ekleme kriteri
      if (key != "MONTAJ" && key != "KAYNAK") {
        groupedMap["SATIN ALMA LİSTESİ"]!.add(item);
      }
    }
    return groupedMap;
  }

  Future<void> _exportToExcel() async {
    try {
      var excel = Excel.createExcel();
      String sheetName = "BOM_Listesi";

      excel.delete(excel.getDefaultSheet()!);
      excel.rename(excel.sheets.keys.first, sheetName);
      Sheet sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue("Parça Adı"),
        TextCellValue("Adet"),
        TextCellValue("Malzeme"),
        TextCellValue("Isıl İşleme"),
        TextCellValue("Sertlik"),
        TextCellValue("Kaplama"),
        TextCellValue("Boya"),
        TextCellValue("Ölçü"),
        TextCellValue("Ürün Grubu"),
        TextCellValue("Gelen Kütük"),
        TextCellValue("Açıklama"),
        TextCellValue("İlgili Kişi"),
        TextCellValue("Sipariş Verildi"),
        TextCellValue("Sipariş Verilme Tarihi"),
        TextCellValue("Muhtemel Varış Tarihi"),
        TextCellValue("Teslim Alındı"),
        TextCellValue("Teslim Alınma Tarihi"),
      ]);

      for (var group in _groupedBomList.keys) {
        for (var item in _groupedBomList[group]!) {
          sheet.appendRow([
            TextCellValue(item['parca_adi'] ?? ''),
            TextCellValue(item['adet'] ?? ''),
            TextCellValue(item['malzeme'] ?? ''),
            TextCellValue(item['isil_isleme'] ?? ''),
            TextCellValue(item['sertlik'] ?? ''),
            TextCellValue(item['kaplama'] ?? ''),
            TextCellValue(item['boya'] ?? ''),
            TextCellValue(item['olcu'] ?? ''),
            TextCellValue(item['urun_grubu'] ?? ''),
            TextCellValue(item['gelen_kutuk'] ?? ''),
            TextCellValue(item['aciklama'] ?? ''),
            TextCellValue(item['ilgili_kisi'] ?? ''),
            TextCellValue(item['siparis_verildi'] == true ? 'Evet' : 'Hayır'),
            TextCellValue(item['siparis_verilme_tarihi'] ?? 'Belirtilmemiş'),
            TextCellValue(item['muhtemel_varis_tarihi'] ?? 'Belirtilmemiş'),
            TextCellValue(item['teslim_alindi'] == true ? 'Evet' : 'Hayır'),
            TextCellValue(item['teslim_alinma_tarihi'] ?? 'Belirtilmemiş'),
          ]);
        }
      }

      var fileBytes = excel.encode();

      if (fileBytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([Uint8List.fromList(fileBytes)],
              'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          final anchor = html.AnchorElement(href: url)
            ..setAttribute("download", "${widget.projectName}_BOM.xlsx")
            ..click();
          html.Url.revokeObjectUrl(url);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Excel başarıyla indirildi!")),
          );
        } else {
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
          } else if (Platform.isIOS) {
            directory = await getApplicationDocumentsDirectory();
          } else {
            throw Exception("Bu platform desteklenmiyor!");
          }

          final filePath = '${directory.path}/${widget.projectName}_BOM.xlsx';
          final file = File(filePath);

          file.createSync(recursive: true);
          file.writeAsBytesSync(fileBytes);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Excel başarıyla indirildi: $filePath")),
          );
        }
      } else {
        throw Exception("Excel dosyası oluşturulamadı!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Excel dışa aktarılırken hata oluştu: $e")),
      );
    }
  }


  void _showManualEntryDialog() {
    final controllers = List.generate(
      11,
          (index) => TextEditingController(),
    );

    final labels = [
      "Parça Adı",
      "Adet",
      "Malzeme",
      "Isıl İşleme",
      "Sertlik",
      "Kaplama",
      "Boya",
      "Ölçü",
      "Ürün Grubu",
      "Gelen Kütük",
      "Açıklama"
    ];

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "Manuel Parça Ekle",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              children: List.generate(
                labels.length,
                    (index) => _buildTextField(labels[index], controllers[index]),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () async {
                await _supabase.from('job_details').insert({
                  'job_id': widget.jobId,
                  'parca_adi': controllers[0].text,
                  'adet': controllers[1].text,
                  'malzeme': controllers[2].text,
                  'isil_isleme': controllers[3].text,
                  'sertlik': controllers[4].text,
                  'kaplama': controllers[5].text,
                  'boya': controllers[6].text,
                  'olcu': controllers[7].text,
                  'urun_grubu': controllers[8].text,
                  'gelen_kutuk': controllers[9].text,
                  'aciklama': controllers[10].text,
                });
                Navigator.pop(context);
                _fetchBomList();
              },
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
  }

  void _showExcelUploadDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          title: const Text(
            "Excel ile Yükle",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton(
                onPressed: _downloadTemplate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Şablonu İndir", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: _uploadExcel,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueAccent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Yükle", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _downloadTemplate() async {
    try {
      var excel = Excel.createExcel();
      String sheetName = "Şablon";

      excel.delete(excel.getDefaultSheet()!);

      excel.rename(excel.sheets.keys.first, sheetName);

      Sheet sheet = excel[sheetName];

      sheet.appendRow([
        TextCellValue("Parça Adı"),
        TextCellValue("Adet"),
        TextCellValue("Malzeme"),
        TextCellValue("Isıl İşleme"),
        TextCellValue("Sertlik"),
        TextCellValue("Kaplama"),
        TextCellValue("Boya"),
        TextCellValue("Ölçü"),
        TextCellValue("Ürün Grubu"),
        TextCellValue("Gelen Kütük"),
        TextCellValue("Açıklama"),
      ]);

      var fileBytes = excel.encode();

      if (fileBytes != null) {
        if (kIsWeb) {
          final blob = html.Blob([Uint8List.fromList(fileBytes)], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
          final url = html.Url.createObjectUrlFromBlob(blob);
          html.Url.revokeObjectUrl(url);
        } else {
          Directory? directory;
          if (Platform.isAndroid) {
            directory = Directory('/storage/emulated/0/Download');
          } else if (Platform.isIOS) {
            directory = await getApplicationDocumentsDirectory();
          } else {
            throw Exception("Bu platform desteklenmiyor!");
          }

          final filePath = '${directory.path}/bom_template.xlsx';
          final file = File(filePath);

          file.createSync(recursive: true);
          file.writeAsBytesSync(fileBytes);

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Şablon başarıyla indirildi: $filePath")),
          );
        }
      } else {
        throw Exception("Excel dosyası oluşturulamadı!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Şablon indirirken hata oluştu: $e")),
      );
    }
  }

  void _uploadExcel() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['xlsx'],
      );

      if (result != null) {
        Uint8List? fileBytes;
        if (kIsWeb) {
          fileBytes = result.files.single.bytes;
        } else {
          File file = File(result.files.single.path!);
          fileBytes = file.readAsBytesSync();
        }

        var excel = Excel.decodeBytes(fileBytes!);
        int rowCount = 0;

        for (var table in excel.tables.keys) {
          var sheet = excel.tables[table]!;
          for (var row in sheet.rows.skip(1)) {
            if (row.isNotEmpty && row[0]?.value != null) {
              await _supabase.from('job_details').insert({
                'job_id': widget.jobId,
                'parca_adi': _safeValue(row[0]?.value),
                'adet': _safeValue(row[1]?.value),
                'malzeme': _safeValue(row[2]?.value),
                'isil_isleme': _safeValue(row[3]?.value),
                'sertlik': _safeValue(row[4]?.value),
                'kaplama': _safeValue(row[5]?.value),
                'boya': _safeValue(row[6]?.value),
                'olcu': _safeValue(row[7]?.value),
                'urun_grubu': _safeValue(row[8]?.value),
                'gelen_kutuk': _safeValue(row[9]?.value),
                'aciklama': _safeValue(row[10]?.value),
              });
              rowCount++;
            }
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("$rowCount parça başarıyla yüklendi.")),
        );

        _fetchBomList();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Excel yüklenirken hata oluştu: $e")),
      );
    }
  }

  String _safeValue(dynamic value) {
    return (value == null || value.toString().trim().isEmpty) ? '' : value.toString();
  }

  Widget _buildTextField(String label, TextEditingController controller) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: const Icon(Icons.edit, color: Colors.blueAccent),
          filled: true,
          fillColor: Colors.blueAccent.withOpacity(0.1),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildGroupList() {
    // Eğer BOM listesi boşsa, kullanıcıya henüz iş yüklenmediğini bildirin
    if (_groupedBomList.isEmpty) {
      return Center(
        child: Text(
          "Henüz bir iş yüklenmedi.",
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blueGrey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12.0),
      itemCount: _groupedBomList.keys.length,
      itemBuilder: (context, index) {
        String group = _groupedBomList.keys.elementAt(index);

        // Teslim alınan parça sayısını ve toplam parça sayısını hesapla
        int totalParts = _groupedBomList[group]?.length ?? 0;
        int deliveredParts = _groupedBomList[group]?.where((item) => item['teslim_alindi'] == true)?.length ?? 0;

        // Eğer totalParts 0 ise ratio'yu 0 olarak ayarla
        double ratio = totalParts > 0 ? deliveredParts / totalParts : 0;
        Color cardColor = Color.lerp(Colors.white, Colors.green, ratio)!;

        return Card(
          margin: const EdgeInsets.symmetric(vertical: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [cardColor, Colors.white],
                stops: [ratio, ratio],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
              borderRadius: BorderRadius.circular(15),
            ),
            child: ListTile(
              title: Text(group, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              subtitle: Text('Teslim Alınan Parça: $deliveredParts / $totalParts'),
              onTap: () => setState(() => _selectedGroup = group),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBomList(String group) {
    List<dynamic> filteredBomList = _filterBomList(_groupedBomList[group]!);

    // Ürün grubu seçeneklerini elde etme
    Set<String> productGroupOptions = filteredBomList.map<String>((item) => item['urun_grubu']?.toString() ?? 'Diğer').toSet();

    return Column(
      children: [
        ListTile(
          title: const Text(
            "🔙 Geri",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          leading: const Icon(Icons.arrow_back, color: Colors.blueAccent),
          onTap: () => setState(() => _selectedGroup = null),
        ),
        // Yeni eklenen arama ve filtreleme bileşenleri
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: TextField(
            onChanged: (value) {
              setState(() {
                _searchTerm = value;
              });
            },
            decoration: InputDecoration(
              labelText: 'Parça Adı Ara',
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedOrderStatus,
                      items: ['Tümü', 'OK', 'NOK']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedOrderStatus = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Sipariş Durumu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDeliveryStatus,
                      items: ['Tümü', 'OK', 'NOK']
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          _selectedDeliveryStatus = value!;
                        });
                      },
                      decoration: InputDecoration(
                        labelText: 'Teslim Alındı Durumu',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 8),
              // Ürün Grubu için çoklu seçim checkbox'ları
              Wrap(
                spacing: 8.0,
                children: productGroupOptions.map((String option) {
                  return FilterChip(
                    label: Text(option),
                    selected: _selectedProductGroups.contains(option),
                    onSelected: (bool selected) {
                      setState(() {
                        if (selected) {
                          _selectedProductGroups.add(option);
                        } else {
                          _selectedProductGroups.remove(option);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: ConstrainedBox(
                constraints: BoxConstraints(minWidth: MediaQuery.of(context).size.width),
                child: DataTable(
                  border: TableBorder.all(
                    color: Colors.grey.shade400,
                    width: 1.5,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  headingRowColor: MaterialStateColor.resolveWith((states) => Colors.blueGrey[900]!),
                  headingTextStyle: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  dataRowHeight: 55,
                  columnSpacing: 20,
                  columns: const [
                    DataColumn(label: Text('Parça Adı')),
                    DataColumn(label: Text('Adet')),
                    DataColumn(label: Text('Malzeme')),
                    DataColumn(label: Text('Isıl İşleme')),
                    DataColumn(label: Text('Sertlik')),
                    DataColumn(label: Text('Kaplama')),
                    DataColumn(label: Text('Boya')),
                    DataColumn(label: Text('Ölçü')),
                    DataColumn(label: Text('Ürün Grubu')),
                    DataColumn(label: Text('Gelen Kütük')),
                    DataColumn(label: Text('Açıklama')),
                    DataColumn(label: Text('Detay Gör')), // Yeni sütun
                  ],
                  rows: filteredBomList.map((item) {
                    Color? rowColor;
                    if (item['teslim_alindi'] == true) {
                      rowColor = Colors.green[200]; // 🟢 Teslim alındıysa yeşil
                    } else if (item['muhtemel_varis_tarihi'] != null && _isPastOrToday(item['muhtemel_varis_tarihi'])) {
                      rowColor = Colors.red[200]; // 🔴 Tarih geçmişse kırmızı
                    } else if (item['siparis_verildi'] == true) {
                      rowColor = Colors.yellow[100]; // 🟡 Sipariş verildi ama tarih geçmedi
                    }

                    return DataRow(
                      color: MaterialStateProperty.resolveWith<Color?>((states) => rowColor),
                      cells: [
                        DataCell(Text(item['parca_adi'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['adet'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['malzeme'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['isil_isleme'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['sertlik'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['kaplama'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['boya'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['olcu'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['urun_grubu'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(Text(item['gelen_kutuk'] ?? '', style: TextStyle(fontSize: 14))),
                        DataCell(
                          InkWell(
                            onTap: () {
                              _showDescriptionDialog(item);
                            },
                            child: Tooltip(
                              message: item['aciklama'] ?? 'Açıklama yok',
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.black87,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              textStyle: const TextStyle(color: Colors.white),
                              child: Container(
                                width: 200,
                                height: 40,
                                alignment: Alignment.center,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Text(
                                  (item['aciklama']?.length ?? 0) > 20
                                      ? "${item['aciklama']?.substring(0, 20)}..."
                                      : item['aciklama'] ?? '',
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 14, color: Colors.black87),
                                ),
                              ),
                            ),
                          ),
                        ),
                        // "Detay Gör" butonu
                        DataCell(
                          IconButton(
                            icon: Icon(Icons.visibility, color: Colors.blueAccent),
                            onPressed: () {
                              _showDetailPopup(item);
                            },
                          ),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        )
      ],
    );
  }

  void _showDetailPopup(Map<String, dynamic> item) {
    String? selectedUser = item['ilgili_kisi'];
    bool siparisVerildi = item['siparis_verildi'] ?? false;
    bool teslimAlindi = item['teslim_alindi'] ?? false;
    String? siparisVerilmeTarihi = item['siparis_verilme_tarihi'];
    String? varisTarihi = item['muhtemel_varis_tarihi'];
    String? teslimAlinmaTarihi = item['teslim_alinma_tarihi'];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          item['parca_adi'] ?? "Detaylar",
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.red),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),

                    // 📌 İlgili Kişi/Kurum Seçimi
                    _buildDropdownField(
                      icon: Icons.person,
                      label: "İlgili Kişi/Kurum",
                      value: selectedUser,
                      items: _users.map<DropdownMenuItem<String>>((user) {
                        return DropdownMenuItem<String>(
                          value: user['username'],
                          child: Text(user['username'] ?? ''),
                        );
                      }).toList(),
                      onChanged: (value) {
                        if (value != null) {
                          setModalState(() => selectedUser = value); // ✅ Önce UI'yi güncelle
                          _updateIlgiliKisi(item, value);
                        }
                      },
                    ),
                    const SizedBox(height: 15),

                    // 📌 Sipariş Verildi
                    _buildSwitchField(
                      icon: Icons.shopping_cart,
                      label: "Sipariş Verildi",
                      value: siparisVerildi,
                      onChanged: (newValue) {
                        String? newDate = newValue ? _getFormattedDateTime() : null;

                        setModalState(() {
                          siparisVerildi = newValue;
                          siparisVerilmeTarihi = newDate;
                        });

                        _updateSiparisDurumu(item, newValue);
                      },
                    ),

                    if (siparisVerildi)
                      _buildInfoRow(Icons.date_range, "Sipariş Verilme Tarihi:", siparisVerilmeTarihi),

                    // 📌 Muhtemel Varış Tarihi
                    _buildDatePickerField(
                      icon: Icons.calendar_today,
                      label: "Muhtemel Varış Tarihi",
                      value: varisTarihi,
                      onSelectDate: (pickedDate) {
                        String formattedDate =
                            "${pickedDate.year}-${pickedDate.month.toString().padLeft(2, '0')}-${pickedDate.day.toString().padLeft(2, '0')}";

                        setModalState(() => varisTarihi = formattedDate); // ✅ Önce UI'yi güncelle
                        _updateVarisTarihi(item, pickedDate);
                      },
                    ),

                    const SizedBox(height: 10),

                    // 📌 Teslim Alındı
                    _buildSwitchField(
                      icon: Icons.check_circle,
                      label: "Teslim Alındı",
                      value: teslimAlindi,
                      onChanged: (newValue) {
                        String? newDate = newValue ? _getFormattedDateTime() : null;

                        setModalState(() {
                          teslimAlindi = newValue;
                          teslimAlinmaTarihi = newDate;
                        });

                        _updateTeslimDurumu(item, newValue);
                      },
                    ),

                    if (teslimAlindi)
                      _buildInfoRow(Icons.assignment_turned_in, "Teslim Alınma Tarihi:", teslimAlinmaTarihi),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }


// ✅ Dropdown Field
  Widget _buildDropdownField({
    required IconData icon,
    required String label,
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required Function(String?) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: DropdownButtonFormField<String>(
            value: value,
            items: items,
            onChanged: onChanged,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
      ],
    );
  }

// ✅ Switch Field (Görsel olarak daha modern)
  Widget _buildSwitchField({
    required IconData icon,
    required String label,
    required bool value,
    required Function(bool) onChanged,
  }) {
    return Row(
      children: [
        Icon(icon, color: value ? Colors.green : Colors.grey),
        SizedBox(width: 10),
        Text(label, style: TextStyle(fontSize: 16)),
        Spacer(),
        Switch(
          value: value,
          activeColor: Colors.green,
          onChanged: (newValue) async {
            // Onay dialogu göster
            bool? confirmed = await _showConfirmationDialog(
              title: "Emin misiniz?",
              content: newValue
                  ? "Bu işlemi onaylıyor musunuz?"
                  : "Bu işlemi iptal etmek istediğinize emin misiniz?",
            );

            if (confirmed == true) {
              onChanged(newValue); // ✅ Önce UI'yi güncelle, sonra veritabanına kaydet
            }
          },
        ),
      ],
    );
  }

// ✅ Onay Dialogu
  Future<bool?> _showConfirmationDialog({required String title, required String content}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("İptal", style: TextStyle(color: Colors.red)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
              child: Text("Onayla", style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }


// ✅ Bilgi Gösterimi (Statik metinler için)
  Widget _buildInfoRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, color: Colors.grey),
          SizedBox(width: 10),
          Text(label, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          Spacer(),
          Text(
            value ?? "Henüz Girilmedi",
            style: TextStyle(
              fontSize: 16,
              color: value != null ? Colors.black87 : Colors.grey,
            ),
          ),
        ],
      ),
    );
  }

// ✅ Tarih Seçme Butonu
  Widget _buildDatePickerField({
    required IconData icon,
    required String label,
    required String? value,
    required Function(DateTime) onSelectDate,
  }) {
    return Row(
      children: [
        Icon(icon, color: Colors.blueAccent),
        SizedBox(width: 10),
        Text("$label:", style: TextStyle(fontSize: 16)),
        Spacer(),
        InkWell(
          onTap: () async {
            DateTime? pickedDate = await showDatePicker(
              context: context,
              initialDate: DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime(2100),
            );

            if (pickedDate != null) {
              onSelectDate(pickedDate); // ✅ UI'yi hemen güncelle
            }
          },
          child: Text(
            value ?? "Tarih Seç",
            style: TextStyle(
              fontSize: 16,
              color: value != null ? Colors.black : Colors.blueAccent,
            ),
          ),
        ),
      ],
    );
  }

  void _updateSiparisDurumu(Map<String, dynamic> item, bool newValue) async {
    try {
      String? siparisVerilmeTarihi = newValue ? _getFormattedDateTime() : null;

      final response = await _supabase
          .from('job_details')
          .update({
        'siparis_verildi': newValue,
        'siparis_verilme_tarihi': siparisVerilmeTarihi,
      })
          .eq('id', item['id'])
          .select();

      if (response.isNotEmpty) {
        setState(() {
          item['siparis_verildi'] = newValue;
          item['siparis_verilme_tarihi'] = siparisVerilmeTarihi;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? "✅ Sipariş verildi: $siparisVerilmeTarihi"
                : "❌ Sipariş durumu sıfırlandı."),
          ),
        );
      } else {
        throw Exception("Güncelleme başarısız!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Sipariş durumu güncellenirken hata oluştu: $e")),
      );
    }
  }

  void _updateTeslimDurumu(Map<String, dynamic> item, bool newValue) async {
    try {
      String? teslimAlinmaTarihi = newValue ? _getFormattedDateTime() : null;

      final response = await _supabase
          .from('job_details')
          .update({
        'teslim_alindi': newValue,
        'teslim_alinma_tarihi': teslimAlinmaTarihi,
      })
          .eq('id', item['id'])
          .select();

      if (response.isNotEmpty) {
        setState(() {
          item['teslim_alindi'] = newValue;
          item['teslim_alinma_tarihi'] = teslimAlinmaTarihi;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newValue
                ? "✅ Teslim alındı: $teslimAlinmaTarihi"
                : "❌ Teslim durumu sıfırlandı."),
          ),
        );
      } else {
        throw Exception("Güncelleme başarısız!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("⚠️ Teslim durumu güncellenirken hata oluştu: $e")),
      );
    }
  }

  String _getFormattedDateTime() {
    DateTime now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} "
        "${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}";
  }


  bool _isPastOrToday(String dateString) {
    try {
      DateTime parsedDate = DateTime.parse(dateString);
      DateTime today = DateTime.now();

      return parsedDate.isBefore(today) || parsedDate.isAtSameMomentAs(today);
    } catch (e) {
      return false; // Tarih geçerli değilse kırmızıya boyamamak için
    }
  }

  void _updateVarisTarihi(Map<String, dynamic> item, DateTime selectedDate) async {
    try {
      String formattedDate =
          "${selectedDate.year}-${selectedDate.month.toString().padLeft(2, '0')}-${selectedDate.day.toString().padLeft(2, '0')}";

      final response = await _supabase
          .from('job_details')
          .update({'muhtemel_varis_tarihi': formattedDate})
          .eq('id', item['id'])
          .select();

      if (response.isNotEmpty) {
        setState(() {
          item['muhtemel_varis_tarihi'] = formattedDate;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Muhtemel varış tarihi güncellendi!")),
        );
      } else {
        throw Exception("Varış tarihi güncellenemedi!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    }
  }

  void _updateIlgiliKisi(Map<String, dynamic> item, String yeniIlgiliKisi) async {
    try {
      final response = await _supabase
          .from('job_details')
          .update({'ilgili_kisi': yeniIlgiliKisi})
          .eq('id', item['id'])
          .select();

      if (response.isNotEmpty) {
        setState(() {
          item['ilgili_kisi'] = yeniIlgiliKisi;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("İlgili kişi başarıyla güncellendi: $yeniIlgiliKisi")),
        );
      } else {
        throw Exception("İlgili kişi güncellenemedi!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    }
  }

  void _showDescriptionDialog(Map<String, dynamic> item) {
    TextEditingController descriptionController = TextEditingController(text: item['aciklama'] ?? '');

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            item['parca_adi'] ?? "Bilinmeyen Parça",
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          content: Container(
            width: double.maxFinite,
            constraints: const BoxConstraints(maxHeight: 250),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: descriptionController,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: "Açıklama",
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("İptal", style: TextStyle(color: Colors.red, fontSize: 16)),
            ),
            ElevatedButton(
              onPressed: () {
                _saveDescription(item, descriptionController.text);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: const Text("Kaydet", style: TextStyle(color: Colors.white, fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  void _saveDescription(Map<String, dynamic> item, String newDescription) async {
    try {
      // Supabase'de güncelleme işlemi
      final response = await _supabase
          .from('job_details')
          .update({'aciklama': newDescription})
          .eq('id', item['id'])
          .select();  // ✅ Güncellenen veriyi çek!

      if (response.isNotEmpty) {
        setState(() {
          item['aciklama'] = newDescription; // ✅ Açıklamayı güncelle
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Açıklama başarıyla güncellendi!")),
        );
      } else {
        throw Exception("Açıklama güncellenemedi!");
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Hata oluştu: $e")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.projectName,
          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        backgroundColor: Colors.blueGrey[900],
        elevation: 4,
        actions: [
          // 📌 **Excel Export Butonu**
          IconButton(
            icon: const Icon(Icons.download, color: Colors.white),
            tooltip: "Excel'e Aktar",
            onPressed: _exportToExcel,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _selectedGroup == null
          ? _buildGroupList()
          : _buildBomList(_selectedGroup!),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showModalBottomSheet(
            context: context,
            builder: (context) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    leading: const Icon(Icons.edit, color: Colors.blueAccent),
                    title: const Text("Manuel Ekle"),
                    onTap: () {
                      Navigator.pop(context);
                      _showManualEntryDialog();
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.upload, color: Colors.blueAccent),
                    title: const Text("Excel ile Yükle"),
                    onTap: () {
                      Navigator.pop(context);
                      _showExcelUploadDialog();
                    },
                  ),
                ],
              );
            },
          );
        },
        backgroundColor: Colors.blueAccent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 6,
        child: const Icon(Icons.add, color: Colors.white, size: 28),
      ),
    );
  }
}
