import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

# Remove the broken prefill block I added at line 84
broken_code = """
    if (widget.initialWorker != null) {
      final w = widget.initialWorker!;
      selectedAttendanceType = w['attendanceType'] ?? 'Full Day';
      inTimeController.text = w['inTime'] ?? '';
      outTimeController.text = w['outTime'] ?? '';
      otHoursController.text = (w['otHours'] ?? '').toString();
      remarksController.text = w['remarks'] ?? '';
      
      final isContractor = w['isContractor'] == true ||
          (w['labourType'] == 'Sub Contractor' &&
              (w['contractor'] == null ||
                  w['contractor'].toString().isEmpty ||
                  w['contractor'] == w['workerName']));
                  
      if (isContractor) {
        selectedContractor = w['workerName'] ?? w['contractorName'];
      } else {
        selectedWorkerId = w['workerId'];
      }
      _isNewWorker = false;
    }
"""

content = content.replace(broken_code, "")

# Instead, add a method `_prefillFromInitialWorker()` which we can call AFTER loading workers/contractors
prefill_method = """
  void _prefillFromInitialWorker() {
    if (widget.initialWorker != null) {
      final w = widget.initialWorker!;
      setState(() {
        selectedAttendanceType = w['attendanceType'] ?? 'Full Day';
        inTimeController.text = w['inTime'] ?? '';
        outTimeController.text = w['outTime'] ?? '';
        otHoursController.text = (w['otHours'] ?? '').toString();
        remarksController.text = w['remarks'] ?? '';
        
        final isContractor = w['isContractor'] == true ||
            (w['labourType'] == 'Sub Contractor' &&
                (w['contractor'] == null ||
                    w['contractor'].toString().isEmpty ||
                    w['contractor'] == w['workerName']));
                    
        isAddingNewWorker = false;
        
        // Find the document snapshot in the loaded lists
        final workerId = w['workerId'];
        if (isContractor) {
          try {
            selectedWorker = contractors.firstWhere((doc) => doc.id == workerId);
          } catch (_) {
            // Not found
          }
        } else {
          try {
            selectedWorker = workers.firstWhere((doc) => doc.id == workerId);
          } catch (_) {
            // Not found
          }
        }
      });
    }
  }
"""

content = content.replace("  void filterWorkers() {", prefill_method + "\n  void filterWorkers() {")

# Now we need to call _prefillFromInitialWorker after loadWorkers and loadContractors complete.
# The init sequence is: await Future.wait([loadLabours(), loadContractors(), loadWorkers()]);
# Then _prefillFromInitialWorker() inside initState. But initState doesn't await. 
# Wait, let's see how initState fetches.
with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

