import re

with open("lib/screens/daily_labour_entry_screen.dart", "r") as f:
    content = f.read()

edit_method = """  void editWorker(int index) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => AddLabourEntryModal(
        siteId: widget.siteId,
        siteName: widget.siteName,
        supervisorId: widget.supervisorId,
        supervisorName: widget.supervisorName,
        date: today,
        existingEntries: workersList,
        initialWorker: workersList[index],
        onWorkerAdded: (worker) {
          setState(() {
            final existingIndex = workersList.indexWhere(
              (w) => w['workerId'] == worker['workerId'],
            );
            if (existingIndex >= 0) {
              workersList[existingIndex] = worker;
            } else {
              workersList.add(worker);
            }
          });
          calculateSummary();
        },
      ),
    );
  }"""

content = re.sub(
    r"  void editWorker\(int index\) \{\n\s*// TODO: Implement edit worker functionality\n\s*\}",
    edit_method,
    content
)

with open("lib/screens/daily_labour_entry_screen.dart", "w") as f:
    f.write(content)

