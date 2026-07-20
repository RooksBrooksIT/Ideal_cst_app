import re

with open("lib/screens/add_labour_entry_modal.dart", "r") as f:
    content = f.read()

content = content.replace(
    """      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),""",
    """      child: Material(
        color: Colors.transparent,
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),"""
)

# Also need to close the Material widget
content = content.replace(
    """        onTap: () {
          setState(() {
            selectedWorker = doc;
          });
          _recalculateOtHours();
        },
      ),
    );""",
    """        onTap: () {
          setState(() {
            selectedWorker = doc;
          });
          _recalculateOtHours();
        },
      ),
      ),
    );"""
)

with open("lib/screens/add_labour_entry_modal.dart", "w") as f:
    f.write(content)
