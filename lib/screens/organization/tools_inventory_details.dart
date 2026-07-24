import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class ToolsInventoryDetailsPage extends StatefulWidget {
  final String toolCode;
  const ToolsInventoryDetailsPage({super.key, required this.toolCode});

  @override
  State<ToolsInventoryDetailsPage> createState() =>
      _ToolsInventoryDetailsPageState();
}

class _ToolsInventoryDetailsPageState
    extends State<ToolsInventoryDetailsPage> {
  List<Map<String, dynamic>> inventoryData = [];
  bool isLoading = true;
  String? errorMessage;
  String toolName = "";
  String toolCategory = "";

  final Color mainColor = const Color(0xFF003768);

  @override
  void initState() {
    super.initState();
    _fetchInventoryData();
  }

  Future<void> _fetchInventoryData() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      final query = await FirebaseFirestore.instance
          .collection('toolsInventory')
          .where('toolCode', isEqualTo: widget.toolCode)
          .get();

      if (query.docs.isNotEmpty) {
        final doc = query.docs.first;
        final sites = doc.data()['sites'] as List<dynamic>? ?? [];

        Map<String, int> siteCounts = {};

        for (var site in sites) {
          final siteId = site['siteId'] ?? '';
          final count = (site['count'] ?? 0) as int;
          if (siteCounts.containsKey(siteId)) {
            siteCounts[siteId] = siteCounts[siteId]! + count;
          } else {
            siteCounts[siteId] = count;
          }
        }

        inventoryData = siteCounts.entries
            .where((entry) => entry.value > 0)
            .map((entry) {
              return {'siteId': entry.key, 'toolsCount': entry.value};
            })
            .toList();
      } else {
        inventoryData = [];
      }
    } catch (e) {
      errorMessage = 'Failed to load data: ${e.toString()}';
    }
    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _generatePdf(BuildContext context) async {
    final font = await PdfGoogleFonts.notoSansRegular();
    final fontBold = await PdfGoogleFonts.notoSansBold();
    final pdfTheme = pw.ThemeData.withFont(base: font, bold: fontBold);

    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        theme: pdfTheme,
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                "Tools Distribution Report",
                style: pw.TextStyle(
                  fontSize: 26,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF003768),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF003768)),
              pw.SizedBox(height: 8),
              pw.Text(
                "Tool Code: ${widget.toolCode}",
                style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                "Distribution by Site",
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromInt(0xFF003768),
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Table.fromTextArray(
                headers: ['Site ID', 'Tools Count'],
                data: inventoryData
                    .map(
                      (item) => [item['siteId'], item['toolsCount'].toString()],
                    )
                    .toList(),
                headerStyle: pw.TextStyle(
                  color: PdfColors.white,
                  fontWeight: pw.FontWeight.bold,
                ),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(8),
                border: pw.TableBorder.all(
                  color: PdfColor.fromInt(0xFF003768),
                  width: 1,
                ),
                headerDecoration: pw.BoxDecoration(
                  color: PdfColor.fromInt(0xFF003768),
                ),
              ),
              pw.Spacer(),
              pw.Divider(thickness: 2, color: PdfColor.fromInt(0xFF003768)),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text(
                  "Total Tools: ${inventoryData.fold<int>(0, (sum, item) => sum + (item['toolsCount'] as int))}",
                  style: pw.TextStyle(
                    fontSize: 16,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromInt(0xFF003768),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat format) async => pdf.save(),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Row(
          children: [
            InkWell(
              onTap: () => Navigator.pop(context),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new, color: mainColor, size: 20),
              ),
            ),
            const SizedBox(width: 16),
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tool Distribution',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Site Details',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1E1E2D),
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 207, 226, 243),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),
              if (isLoading)
                Expanded(child: Center(child: CircularProgressIndicator(color: mainColor)))
              else if (errorMessage != null)
                Expanded(
                  child: Center(
                    child: Text(
                      errorMessage!,
                      style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                    ),
                  ),
                )
              else ...[
                // Info Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: mainColor.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.construction, color: mainColor, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Tool Code: ${widget.toolCode}",
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: mainColor,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              "Distributed across ${inventoryData.length} sites",
                              style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Table Section
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Distribution by Site",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: mainColor,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: Container(
                            clipBehavior: Clip.antiAlias,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: mainColor.withValues(alpha: 0.2)),
                            ),
                            child: SingleChildScrollView(
                              scrollDirection: Axis.vertical,
                              child: SizedBox(
                                width: double.infinity,
                                child: DataTable(
                                  headingRowColor: WidgetStateProperty.all(mainColor),
                                  headingTextStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  columnSpacing: 40,
                                  horizontalMargin: 20,
                                  columns: const [
                                    DataColumn(label: Text('SITE ID')),
                                    DataColumn(
                                      label: Text('COUNT'),
                                      numeric: true,
                                    ),
                                  ],
                                  rows: inventoryData
                                      .map(
                                        (data) => DataRow(
                                          cells: [
                                            DataCell(
                                              Text(
                                                data['siteId'],
                                                style: const TextStyle(
                                                  color: Color(0xFF1E1E2D),
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            DataCell(
                                              Text(
                                                data['toolsCount'].toString(),
                                                style: TextStyle(
                                                  color: mainColor,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => _generatePdf(context),
                        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                        label: const Text(
                          "GENERATE PDF",
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainColor,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          side: BorderSide(color: mainColor, width: 1.5),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          "BACK",
                          style: TextStyle(
                            color: mainColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
