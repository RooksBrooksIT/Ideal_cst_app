import re

with open("lib/screens/daily_labour_entry_screen.dart", "r") as f:
    content = f.read()

# Remove openMealsBusFareModal
start_idx = content.find("  void openMealsBusFareModal() {")
if start_idx != -1:
    end_idx = content.find("  Future<void> _saveMealsBusFare(", start_idx)
    if end_idx != -1:
        content = content[:start_idx] + content[end_idx:]

with open("lib/screens/daily_labour_entry_screen.dart", "w") as f:
    f.write(content)

