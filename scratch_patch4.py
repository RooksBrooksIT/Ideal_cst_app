import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

init_state_old = """  @override
  void initState() {
    super.initState();

    loadWorkers();
    loadContractors();
    _loadLabours();
    _loadWorkersOnOtherSitesToday();
    searchController.addListener(filterWorkers);
  }"""

init_state_new = """  @override
  void initState() {
    super.initState();

    _initializeData();
    searchController.addListener(filterWorkers);
  }

  Future<void> _initializeData() async {
    await Future.wait([
      _loadLabours(),
      _loadWorkersOnOtherSitesToday(),
    ]);
    await Future.wait([
      loadWorkers(),
      loadContractors(),
    ]);
    _prefillFromInitialWorker();
  }"""

content = content.replace(init_state_old, init_state_new)

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)

