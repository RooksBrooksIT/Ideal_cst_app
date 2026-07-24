import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ideal_cst/screens/manager/config_material_information.dart';
import 'package:ideal_cst/screens/manager/Site_Supervisor_Config.dart';
import 'package:ideal_cst/screens/manager/config_mat_sub_cat.dart';
import 'package:ideal_cst/screens/manager/config_materialavailability.dart';
import 'package:ideal_cst/screens/manager/conflig_Materials.dart';
import 'package:ideal_cst/screens/manager/config_layout_and_drawing.dart';
import 'package:ideal_cst/screens/manager/contractor_entry_page.dart';
import 'package:ideal_cst/screens/manager/contractor_page.dart';
import 'package:ideal_cst/screens/manager/labour_screen.dart';
import 'package:ideal_cst/screens/manager/manager_expenses_homescreen.dart';
import 'package:ideal_cst/screens/manager/material_screen.dart';
import 'package:ideal_cst/screens/manager/project_category_screen.dart';
import 'package:ideal_cst/screens/manager/project_contract_screen.dart';
import 'package:ideal_cst/screens/manager/project_screen.dart';
import 'package:ideal_cst/screens/manager/project_stage_config.dart';
import 'package:ideal_cst/screens/manager/project_sub_category_screen.dart';
import 'package:ideal_cst/screens/manager/site_screen.dart';
import 'package:ideal_cst/screens/manager/site_supervisor_map_screen.dart';
import 'package:ideal_cst/screens/organization/tools_inventory_report.dart';
import 'package:ideal_cst/screens/manager/tools_master_page.dart';
import 'package:ideal_cst/screens/manager/tools_movement_page.dart';
import 'package:ideal_cst/screens/manager/vehicle_config_page.dart';
import 'package:ideal_cst/screens/manager/vehicle_details_page.dart';
import 'package:ideal_cst/screens/manager/vehicle_driver_config_page.dart';
import 'package:ideal_cst/screens/manager/vehicle_inventory_page.dart';
import 'package:ideal_cst/screens/manager/worker_summary_report_page.dart';
import 'package:ideal_cst/screens/manager/workers_config_page.dart';
import 'package:ideal_cst/screens/manager/workers_site_mapping_page.dart';

class ConfigAccountDashboard extends StatelessWidget {
  static const routeName = '/config-dashboard';

  const ConfigAccountDashboard({super.key});

  final Map<String, List<DashboardItem>> groupedItems = const {
    "Project Configuration": [
      DashboardItem(
        'Project Category',
        'Manage project category settings',
        Icons.category_rounded,
        Colors.orange,
      ),
      DashboardItem(
        'Project Sub Category',
        'Configure project sub-categories',
        Icons.subtitles_rounded,
        Colors.purple,
      ),
      DashboardItem(
        'Project Stage',
        'Define stages for project tracking',
        Icons.flag_rounded,
        Colors.red,
      ),
      DashboardItem(
        'Project Contract',
        'Manage project contracts and details',
        Icons.assignment_rounded,
        Colors.teal,
      ),
    ],
    "Material Configuration": [
      DashboardItem(
        'Material Master',
        'Manage master material list',
        Icons.upload_file_rounded,
        Colors.green,
      ),
      DashboardItem(
        'Material Sub Category',
        'Configure material sub-categories',
        Icons.category_rounded,
        Colors.blue,
      ),
      DashboardItem(
        'Material Config',
        'Configure material items and units',
        Icons.build_rounded,
        Colors.deepOrange,
      ),
      DashboardItem(
        'Material Movements',
        'Track movement of materials',
        Icons.toggle_on_outlined,
        Colors.deepPurple,
      ),
      DashboardItem(
        'Material Availability',
        'Check stock & material availability',
        Icons.build_circle_outlined,
        Colors.indigo,
      ),
    ],
    "Tools Configuration": [
      DashboardItem(
        'Tools',
        'Manage master list of tools',
        Icons.handyman_rounded,
        Colors.indigo,
      ),
    ],
    "Labour Configuration": [
      DashboardItem(
        'Labour',
        'Configure labour rates and details',
        Icons.engineering_rounded,
        Colors.brown,
      ),
    ],
    "Contractor Configuration": [
      DashboardItem(
        'Contractor',
        'Manage contractor details & profiles',
        Icons.person_4_rounded,
        Colors.deepPurple,
      ),
    ],
    "Diagrams Configuration": [
      DashboardItem(
        'Layout and Drawings',
        'Upload & manage site layouts & drawings',
        Icons.upload_file_rounded,
        Colors.cyan,
      ),
    ],
    "Site Configuration": [
      DashboardItem(
        'Site',
        'Manage site locations & details',
        Icons.place_rounded,
        Colors.green,
      ),
      DashboardItem(
        'Project',
        'Configure construction projects',
        Icons.work_rounded,
        Colors.orangeAccent,
      ),
      DashboardItem(
        'Supervisor',
        'Manage site supervisors',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
      ),
      DashboardItem(
        'Site-Supervisor Map',
        'Map supervisors to construction sites',
        Icons.map_rounded,
        Colors.redAccent,
      ),
    ],
    "Tools Tracking": [
      DashboardItem(
        'Tools Movement',
        'Track tools movement across sites',
        Icons.directions_walk_rounded,
        Colors.deepOrangeAccent,
      ),
      DashboardItem(
        'Tools Inventory',
        'Check tools inventory status',
        Icons.inventory_rounded,
        Colors.pink,
      ),
    ],
    "Expenses": [
      DashboardItem(
        'Manager Expenses',
        'Track and manage manager expenses',
        Icons.account_balance_wallet_rounded,
        Colors.blue,
      ),
    ],
    "Workers Management": [
      DashboardItem(
        'Workers Configuration',
        'Configure worker settings & details',
        Icons.work_rounded,
        Color.fromARGB(255, 130, 57, 179),
      ),
      DashboardItem(
        'Workers Site Mapping',
        'Assign workers to specific sites',
        Icons.work_history,
        Color.fromARGB(255, 243, 145, 33),
      ),
      DashboardItem(
        'Workers Attendance',
        'Track worker attendance & salary',
        Icons.supervisor_account_rounded,
        Colors.blueGrey,
      ),
    ],
    "Vehicle Management": [
      DashboardItem(
        'Vehicle Configuration',
        'Add and configure vehicles',
        Icons.fire_truck_sharp,
        Colors.red,
      ),
      DashboardItem(
        'Vehicle Driver Configuration',
        'Assign drivers to vehicles',
        Icons.fire_truck_outlined,
        Colors.blue,
      ),
      DashboardItem(
        'Vehicle Details',
        'View vehicle details & status',
        Icons.directions_car_rounded,
        Colors.green,
      ),
      DashboardItem(
        'Vehicle Inventory',
        'Vehicle inventory reports',
        Icons.inventory_rounded,
        Color.fromARGB(255, 185, 62, 223),
      ),
    ],
  };

  void _showLogoutConfirmation(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Confirm Logout',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'No',
              style: TextStyle(
                color: Colors.grey[600],
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF166534),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Yes',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );

    if (result == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();

      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(
        context,
        '/dashboard',
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) {
          if (Navigator.canPop(context)) {
            Navigator.pop(context);
          } else {
            _showLogoutConfirmation(context);
          }
        }
      },
      child: Scaffold(
        backgroundColor: const Color.fromARGB(255, 218, 238, 220), // Light Green Background
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
            children: [
              _buildHeader(context),
              const SizedBox(height: 16),

              ...groupedItems.entries.expand((entry) {
                return [
                  _buildSectionHeader(entry.key),
                  ...entry.value.map(
                    (item) => _buildActionCard(
                      title: item.title,
                      subtitle: item.subtitle,
                      icon: item.icon,
                      color: item.color,
                      onTap: () => _navigateToScreen(context, item.title),
                    ),
                  ),
                ];
              }),

              const SizedBox(height: 32),
            ],
          ),
        ),
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
            if (Navigator.canPop(context)) ...[
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF1E1E2D),
                    size: 22,
                  ),
                ),
              ),
              const SizedBox(width: 14),
            ],
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text(
                  'Configuration',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4),
                Text(
                  'Dashboard',
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
        GestureDetector(
          onTap: () => _showLogoutConfirmation(context),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF166534),
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.18),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(Icons.logout, color: Colors.white, size: 24),
          ),
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Color(0xFF1E1E2D),
          letterSpacing: -0.5,
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
          child: Row(
            children: [
              Container(
                height: 48,
                width: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(icon, color: color, size: 24),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1E1E2D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToScreen(BuildContext context, String title) {
    final routeMap = {
      'Project Category': const ProjectCategoryScreen(),
      'Project Sub Category': const ProjectSubCategoryScreen(),
      'Project Stage': const ProjectStageConfig(),
      'Project Contract': const ProjectContractScreen(),
      'Site': const SiteScreen(),
      'Supervisor': const SiteSupervisorConfig(),
      'Site-Supervisor Map': SiteSupervisorMapScreen(),
      'Material': MaterialScreen(),
      'Project': ProjectScreen(),
      'Labour': LabourScreen(),
      'Tools': ToolMasterPage(),
      'Tools Movement': ToolsMovementPage(),
      'Manager Expenses': const ManagerExpensesHomeScreen(),
      'Layout and Drawings': const LayoutAndDrawingsPage(),
      'Tools Inventory': const ToolsInventoryPage(),
      'Material Master': const MatlsScreen(),
      'Material Sub Category': const MatlsSubCat(),
      'Material Config': const MaterialScreen(),
      'Material Movements': const MaterialInfoScreen(),
      "Material Availability": const MaterialAvailability(),
      'Contractor': const ContractorPage(),
      'Contractor Entry': ContractorEntryPage(
        userName: '',
        userDetails: const {},
      ),
      'Workers Configuration': WorkersConfigPage(),
      'Workers Site Mapping': WorkerMappingPage(),
      'Workers Attendance': WorkerAttendanceSalaryPage(),
      'Vehicle Configuration': AddVehicleLogPage(),
      'Vehicle Driver Configuration': VehicleDriverConfigPage(),
      "Vehicle Details": VehicleDetailsPage(),
      "Vehicle Inventory": VehicleInventoryReportPage(),
    };

    final screen = routeMap[title];
    if (screen != null) {
      Navigator.push(context, MaterialPageRoute(builder: (context) => screen));
    }
  }
}

class DashboardItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  const DashboardItem(this.title, this.subtitle, this.icon, this.color);
}
