import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:ideal_cst/screens/organization/components/custom_dropdown.dart';

class MaterialReportPage extends StatefulWidget {
  const MaterialReportPage({super.key});

  @override
  State<MaterialReportPage> createState() => _MaterialReportPageState();
}

class _MaterialReportPageState extends State<MaterialReportPage> {
  final Color mainColor = const Color(0xFF003768);

  List<String> materialNames = [];
  String? selectedMaterial;

  bool isLoadingNames = true;
  bool isReportLoading = false;
  List<_SiteMaterialRow> reportRows = [];

  @override
  void initState() {
    super.initState();
    _fetchMaterialNames();
  }

  Future<void> _fetchMaterialNames() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('materialsInventory')
          .get();

      final names = snapshot.docs
          .map((doc) => (doc.data()['materialName'] ?? '').toString().trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      names.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));

      if (mounted) {
        setState(() {
          materialNames = names;
          isLoadingNames = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isLoadingNames = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load materials: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      });
    }
  }

  Future<void> _fetchMaterialReport(String materialName) async {
    setState(() {
      isReportLoading = true;
      reportRows = [];
    });

    try {
      final q = await FirebaseFirestore.instance
          .collection('materialsInventory')
          .where('materialName', isEqualTo: materialName)
          .get();

      final Map<String, double> qtyBySite = {};
      for (final doc in q.docs) {
        final data = doc.data();
        final sites = data['sites'];
        if (sites is List) {
          for (final s in sites) {
            if (s is Map<String, dynamic>) {
              final siteId = (s['siteId'] ?? s['siteid'] ?? '')
                  .toString()
                  .trim();
              if (siteId.isEmpty) continue;
              final qtyRaw = s['materialQty'];
              final qty = _parseNumber(qtyRaw);
              qtyBySite.update(
                siteId,
                (prev) => prev + qty,
                ifAbsent: () => qty,
              );
            }
          }
        }
      }

      final rows = qtyBySite.entries
          .map((e) => _SiteMaterialRow(siteId: e.key, qty: e.value))
          .toList()
        ..sort(
          (a, b) => a.siteId.toLowerCase().compareTo(b.siteId.toLowerCase()),
        );

      if (mounted) {
        setState(() {
          reportRows = rows;
          isReportLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => isReportLoading = false);
      }
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load report: $e'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            backgroundColor: Colors.red[400],
          ),
        );
      });
    }
  }

  double _parseNumber(dynamic v) {
    if (v == null) return 0.0;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.replaceAll(RegExp(r'[^0-9.+-]'), '');
      final parsed = double.tryParse(cleaned);
      return parsed ?? 0.0;
    }
    return 0.0;
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
                  'Material Inventory',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Stock Report',
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
        InkWell(
          onTap: () {
            if (selectedMaterial != null) {
              _fetchMaterialReport(selectedMaterial!);
            }
          },
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
            child: Icon(Icons.refresh, color: mainColor, size: 22),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        color: Color(0xFF1E1E2D),
        fontSize: 14,
      ),
    );
  }

  Widget _buildReportTable(BuildContext context) {
    return Container(
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
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: mainColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainColor.withValues(alpha: 0.15)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total Sites with Stock:',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF1E1E2D),
                  ),
                ),
                Text(
                  reportRows.length.toString(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: mainColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainColor.withValues(alpha: 0.2)),
            ),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                columnSpacing: 60,
                horizontalMargin: 20,
                headingRowHeight: 48,
                dataRowHeight: 40,
                headingRowColor: WidgetStateProperty.all(mainColor),
                headingTextStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                  fontSize: 13,
                ),
                columns: const [
                  DataColumn(label: Text('SITE ID')),
                  DataColumn(numeric: true, label: Text('QUANTITY')),
                ],
                rows: reportRows
                    .map(
                      (r) => DataRow(
                        cells: [
                          DataCell(
                            Text(
                              r.siteId,
                              style: const TextStyle(
                                color: Color(0xFF1E1E2D),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          DataCell(
                            Text(
                              r.qty.toStringAsFixed(r.qty % 1 == 0 ? 0 : 2),
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
        ],
      ),
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
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
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
                            Row(
                              children: [
                                Icon(Icons.search, color: mainColor),
                                const SizedBox(width: 8),
                                _buildSectionTitle('Select Material to View Stock'),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (isLoadingNames)
                              const Center(child: CircularProgressIndicator())
                            else
                              CustomDropdown<String>(
                                hintText: 'Choose Material',
                                value: selectedMaterial,
                                mainColor: mainColor,
                                items: materialNames
                                    .map(
                                      (name) => DropdownMenuItem<String>(
                                        value: name,
                                        child: Text(
                                          name,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF1E1E2D),
                                          ),
                                        ),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  setState(() => selectedMaterial = val);
                                  if (val != null) {
                                    _fetchMaterialReport(val);
                                  }
                                },
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (selectedMaterial != null) ...[
                        Row(
                          children: [
                            Icon(Icons.assessment_outlined, color: mainColor, size: 22),
                            const SizedBox(width: 8),
                            _buildSectionTitle('STOCK REPORT FOR: $selectedMaterial'),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isReportLoading)
                          Center(child: CircularProgressIndicator(color: mainColor))
                        else if (reportRows.isNotEmpty)
                          _buildReportTable(context)
                        else
                          Container(
                            padding: const EdgeInsets.all(30),
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
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(Icons.inventory_2_outlined, size: 50, color: mainColor.withValues(alpha: 0.4)),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No stock data available',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF1E1E2D),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'No site quantities found for $selectedMaterial',
                                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SiteMaterialRow {
  final String siteId;
  final double qty;
  _SiteMaterialRow({required this.siteId, required this.qty});
}
