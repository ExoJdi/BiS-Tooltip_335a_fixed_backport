## 🛠️ BiSTooltip – Backport for WotLK 3.3.5a Fixes & Improvements
https://www.curseforge.com/wow/addons/bis-tooltip

This update focuses on **full compatibility with WoW 3.3.5a**, stability, and performance.

<img width="450" height="500" alt="image" src="https://github.com/user-attachments/assets/b8b13f55-ea86-424c-97de-95cdc31857ef" /><img width="450" height="500" alt="image" src="https://github.com/user-attachments/assets/560c6831-9cc8-4aa8-95d6-58e25f290e8b" />
<img width="318" height="500" alt="image" src="https://github.com/user-attachments/assets/e6da7235-b148-45fc-a9c5-3f79759da682" />      <img width="318" height="500" alt="image" src="https://github.com/user-attachments/assets/ae6bec86-7b53-4094-9f1b-73622563060f" />






### Core & Initialization
- Fixed broken addon initialization caused by missing global object (`BistooltipAddon`).
- Ensured `BistooltipAddon` is safely created in all core files, removing dependency on file load order.
- Fixed multiple `nil` method calls (`initBislists`, `createMainFrame`) caused by incomplete initialization.
- Corrected `.toc` load order and removed invalid whitespace that prevented files from loading.

### Lua Errors & Stability
- Fixed multiple critical Lua errors:
  - `attempt to index nil value (DataStore_Inventory)`
  - `attempt to call method 'initBislists' (a nil value)`
  - `attempt to call method 'createMainFrame' (a nil value)`
  - `ipairs(nil)` crashes when BIS data was missing for class/spec/phase
- Added full nil-guards for optional dependencies (DataStore, external tooltip hooks).
- 
<img width="600" height="580" alt="image" src="https://github.com/user-attachments/assets/71d424c9-8b86-4abc-aee3-fb57da294869" />

### Item & Icon Loading (3.3.5a)
- Reworked item loading logic to handle `GetItemInfo()` returning `nil` on WoW 3.3.5a.
- Implemented safe polling-based item icon loading (no `GET_ITEM_INFO_RECEIVED` dependency).
- Ensured icons correctly update once item data is cached.
- Prevented polling loops from leaking memory when the UI is closed.

### BIS Data & Loot Tables
- Restored missing **T7** and **T8** BIS tables for all classes.
- Fixed missing or invalid loot sources for multiple WotLK items.
- Improved handling of incomplete BIS data (no crashes when data is missing).
- Corrected Horde → Alliance item ID mapping logic.

### Enchants
- Fixed missing BIS enchants caused by unsupported spell-based enchant handling.
- Added proper support for spell-based enchants in tooltips.
- Prevented invalid enchant IDs from breaking tooltip rendering.

### Memory & Performance
- Removed unused legacy BIS data files from loading path.
- Fixed AceGUI widget leaks by properly releasing UI children on rebuild/close.
- Ensured temporary tables and polling references are cleared to allow Lua garbage collection.
- Reduced overall memory usage and prevented linear memory growth during UI interaction.

### UI & Compatibility
- Fixed minimap icon not appearing due to broken initialization.
- Fixed configuration panel not opening.
- Improved compatibility with ElvUI, Aux, GearScore, and other tooltip-modifying addons.
