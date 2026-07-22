import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'tools_inventory_details.dart';

class ToolsInventoryPage extends StatefulWidget {
  const ToolsInventoryPage({super.key});

  @override
  State<ToolsInventoryPage> createState() => _ToolsInventoryPageState();
}

class _ToolsInventoryPageState extends State<ToolsInventoryPage> {
  final Color mainColor = const Color(0xFF003768);

  DataState _dataState = DataState.loading;
  List<ToolInventory> _toolsAtCompany = [];
  List<ToolInventory> _toolsAtSite = [];
  List<String> _allToolCodes = [];
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadInventoryData();
  }

  Future<void> _loadInventoryData() async {
    setState(() => _dataState = DataState.loading);
    try {
      final results = await Future.wait([
        FirebaseFirestore.instance.collection('toolsAtCompany').get(),
        FirebaseFirestore.instance.collection('toolsAtSite').get(),
        FirebaseFirestore.instance.collection('tools').get(),
      ]);

      final companyData = results[0].docs
          .map((doc) => ToolInventory.fromMap(doc.data()))
          .toList();
      final siteData =
          results[1].docs.map((doc) => ToolInventory.fromMap(doc.data())).toList();
      final toolCodes = results[2].docs
          .map((doc) => doc.data()['toolCode']?.toString() ?? '')
          .where((code) => code.isNotEmpty)
          .toList();

      if (mounted) {
        setState(() {
          _toolsAtCompany = companyData;
          _toolsAtSite = siteData;
          _allToolCodes = toolCodes;
          _dataState = DataState.loaded;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dataState = DataState.error;
          _errorMessage = 'Failed to load inventory: ${e.toString()}';
        });
      }
    }
  }

  List<ToolInventorySummary> get _mergedInventory {
    final allToolCodes = {
      ..._toolsAtCompany.map((e) => e.toolCode),
      ..._toolsAtSite.map((e) => e.toolCode),
      ..._allToolCodes,
    };

    return allToolCodes.map((code) {
      final companyCount = _toolsAtCompany
          .firstWhere((e) => e.toolCode == code, orElse: () => ToolInventory.empty())
          .availableCount;
      final siteCount = _toolsAtSite
          .firstWhere((e) => e.toolCode == code, orElse: () => ToolInventory.empty())
          .availableCount;

      return ToolInventorySummary(
        toolCode: code,
        atCompany: companyCount,
        atSite: siteCount,
      );
    }).toList();
  }

  List<ToolInventorySummary> get _filteredInventory {
    if (_searchQuery.isEmpty) return _mergedInventory;

    return _mergedInventory
        .where((tool) =>
            tool.toolCode.toLowerCase().contains(_searchQuery.toLowerCase()))
        .toList();
  }

  void _navigateToToolDetails(ToolInventorySummary tool) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ToolsInventoryDetailsPage(toolCode: tool.toolCode),
      ),
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
                  'Tools & Machinery',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Inventory Summary',
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
          onTap: _loadInventoryData,
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

  Widget _buildSummaryCards() {
    final totalAtCompany =
        _toolsAtCompany.fold(0, (sum, tool) => sum + tool.availableCount);
    final totalAtSite =
        _toolsAtSite.fold(0, (sum, tool) => sum + tool.availableCount);
    final totalTools = totalAtCompany + totalAtSite;

    return Row(
      children: [
        Expanded(
          child: _SummaryCard(
            title: 'TOTAL TOOLS',
            value: totalTools,
            icon: Icons.construction,
            mainColor: mainColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'AT COMPANY',
            value: totalAtCompany,
            icon: Icons.business,
            mainColor: mainColor,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SummaryCard(
            title: 'AT SITE',
            value: totalAtSite,
            icon: Icons.location_city,
            mainColor: mainColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return TextField(
      decoration: InputDecoration(
        hintText: 'Search by tool code...',
        hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
        prefixIcon: Icon(Icons.search, color: mainColor),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor.withValues(alpha: 0.2)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: mainColor, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                color: mainColor,
                onPressed: () {
                  setState(() {
                    _searchQuery = '';
                  });
                },
              )
            : null,
      ),
      style: const TextStyle(color: Colors.black87, fontSize: 14),
      onChanged: (value) {
        setState(() {
          _searchQuery = value;
        });
      },
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 48, color: mainColor.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            'No tools found for "$_searchQuery"',
            style: TextStyle(fontSize: 15, color: Colors.grey[600], fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              setState(() {
                _searchQuery = '';
              });
            },
            child: Text('Clear search', style: TextStyle(color: mainColor, fontWeight: FontWeight.bold)),
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
              const SizedBox(height: 16),
              if (_dataState == DataState.loading)
                Expanded(child: Center(child: CircularProgressIndicator(color: mainColor)))
              else if (_dataState == DataState.error)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.error_outline, color: Colors.red, size: 48),
                        const SizedBox(height: 16),
                        Text(_errorMessage ?? 'Unknown error', style: const TextStyle(color: Colors.red)),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadInventoryData,
                          style: ElevatedButton.styleFrom(backgroundColor: mainColor),
                          child: const Text('Retry', style: TextStyle(color: Colors.white)),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                _buildSummaryCards(),
                const SizedBox(height: 14),
                _buildSearchBar(),
                const SizedBox(height: 14),
                Expanded(
                  child: _filteredInventory.isEmpty && _searchQuery.isNotEmpty
                      ? _buildNoResults()
                      : ListView.builder(
                          itemCount: _filteredInventory.length,
                          itemBuilder: (context, index) {
                            final tool = _filteredInventory[index];
                            return _ToolInventoryCard(
                              tool: tool,
                              mainColor: mainColor,
                              onTap: () => _navigateToToolDetails(tool),
                              isHighlighted: tool.toolCode
                                  .toLowerCase()
                                  .contains(_searchQuery.toLowerCase()),
                            );
                          },
                        ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final String title;
  final int value;
  final IconData icon;
  final Color mainColor;

  const _SummaryCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.mainColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: mainColor.withValues(alpha: 0.8),
                    letterSpacing: 0.5,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Icon(icon, color: mainColor, size: 16),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: mainColor,
            ),
          ),
        ],
      ),
    );
  }
}

class _ToolInventoryCard extends StatelessWidget {
  final ToolInventorySummary tool;
  final Color mainColor;
  final VoidCallback onTap;
  final bool isHighlighted;

  const _ToolInventoryCard({
    required this.tool,
    required this.mainColor,
    required this.onTap,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.construction, color: mainColor, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        tool.toolCode,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.chevron_right, color: mainColor),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _InventoryBadge(
                    label: 'Company',
                    count: tool.atCompany,
                    color: mainColor,
                  ),
                  const SizedBox(width: 10),
                  _InventoryBadge(
                    label: 'Site',
                    count: tool.atSite,
                    color: Colors.green.shade800,
                  ),
                  const Spacer(),
                  Text(
                    'View Details',
                    style: TextStyle(
                      color: mainColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InventoryBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _InventoryBadge({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "$label: ",
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          Text(
            count.toString(),
            style: TextStyle(
              color: color,
              fontSize: 13,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}

enum DataState { loading, loaded, error }

class ToolInventory {
  final String toolCode;
  final int availableCount;

  const ToolInventory({
    required this.toolCode,
    required this.availableCount,
  });

  factory ToolInventory.fromMap(Map<String, dynamic> map) {
    return ToolInventory(
      toolCode: map['toolCode']?.toString() ?? '',
      availableCount: map['availableCount'] as int? ?? 0,
    );
  }

  factory ToolInventory.empty() =>
      const ToolInventory(toolCode: '', availableCount: 0);
}

class ToolInventorySummary {
  final String toolCode;
  final int atCompany;
  final int atSite;

  const ToolInventorySummary({
    required this.toolCode,
    required this.atCompany,
    required this.atSite,
  });

  factory ToolInventorySummary.empty() =>
      const ToolInventorySummary(toolCode: 'N/A', atCompany: 0, atSite: 0);
}
