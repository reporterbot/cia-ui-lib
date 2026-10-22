# CIA UI Lib

A dark, grey, Minecraft-client style UI library for Roblox, shipped as a **single LocalScript** (`main.lua`).

**Build 6 · v1**

- Three display modes you can switch between at any time: a **2D** window, a **3D** hub that floats in front of your character, and floating **Tabs** panels along the top of the screen
- Modules with smooth expanding settings, toggles, sliders, dropdowns (single or multi-select), buttons, keybinds and labels
- A built-in floating **island** at the top middle of the screen: your local time with a blinking colon, a show/hide button, a mode button beside it, and a live FPS / ping readout on the other side. The library builds it itself, so nothing has to exist in `StarterGui`
- **Interactive Elements**: switching a toggle on plays an effect from the toggle, in the theme colour, that stays inside its tab (Ripple, 1's and 0's, or Glass Crack)
- Notifications with a pulsing outline, a draining time bar and a close button
- Array list of enabled modules
- Automatic scaling and positioning for different screen sizes

## Install

1. In Roblox Studio, create a `Folder` in `StarterGui` (for example `CIALib-v1`).
2. Create a `LocalScript` inside it and paste the contents of [`main.lua`](main.lua).
3. Press Play. Press **RightShift** to show or hide the hub.

The script builds its own GUI at runtime and only ever creates one hub per client, so it is safe in `StarterGui` (which is re-cloned on respawn).

### The island

The island is created by the library: a dark rounded bar centred at the top of the screen with the title, the clock and the show/hide arrow. The **Mode** button sits 10 px to its left and the **FPS / PING** readout 10 px to its right. Clicking the arrow shows or hides the whole hub, and the arrow flips and dims while it's hidden.

If you'd rather use your own design, pass a frame in and the library will wire it up instead of creating one:

```lua
Library.new({ Island = myFrame })   -- needs a TextLabel named "time" and an ImageButton inside it
```

The arrow icon is `rbxassetid://134387593103194`; change it with `IslandIcon = "rbxassetid://..."`. The notification close button loads `rbxassetid://116396312853810`, and the Tabs-mode collapse arrow loads `rbxassetid://134161790366779`. All three assets must be available to your experience.

## Display modes

| Mode | What it is |
| --- | --- |
| `2D` | A draggable window. It scales down to fit small screens and always stays fully on screen, below the island row. |
| `3D` | The whole hub on a non-colliding, unanchored part that eases after your **character** (not the camera) and stays in front of it. The front face flips if the camera ends up on the other side so it is never back-facing. Placement is set with `Distance`, `Height`, `Side` and `Size` in Settings. |
| `Tabs` | One floating panel per tab, packed from the top left to the top right. The row scales down when there are too many tabs for the screen. Each panel has a down arrow in its header: click it (or the header) and the panel's contents slide up and fade into the header; click again and it drops back down. |

Switch with the **Mode** button beside the island (it cycles 2D → 3D → Tabs), the pill in the window's title bar, the Mode dropdown in Settings, or `UI:SetMode("3D")`.

## Usage

`main.lua` exposes itself on `shared.CIALib`, so other scripts can add to it:

```lua
local lib = shared.CIALib
local UI = lib.UI

local Combat = UI:Tab("Combat")

local Aura = Combat:Module({
    Name = "KillAura",
    Description = "Attacks nearby targets",
    Callback = function(enabled) print("KillAura", enabled) end,
})

Aura:Slider({ Name = "Range", Min = 1, Max = 8, Default = 4, Increment = 0.1, Suffix = " st", Callback = print })
Aura:Toggle({ Name = "Through Walls", Default = false, Callback = print })
Aura:Dropdown({ Name = "Mode", Options = { "Single", "Switch", "Multi" }, Default = "Single", Callback = print })
Aura:Dropdown({ Name = "Targets", Options = { "Players", "NPCs" }, Default = { "Players" }, Multi = true, Callback = print })
Aura:Button({ Name = "Reset", Callback = function() end })
Aura:Keybind({ Name = "Bind", Default = Enum.KeyCode.R, Toggles = true })

UI:Notify({ Title = "CIA", Content = "Ready", Type = "Success", Duration = 4 })
```

Left-click a module to turn it on or off, right-click it (or use its arrow) to open its settings.

### Configuration

```lua
local UI = Library.new({
    Title = "CIA",                      -- window / notification title
    Version = "v1",
    Keybind = Enum.KeyCode.RightShift,  -- show / hide
    Accent = Color3.fromRGB(188, 188, 194),
    ArrayList = true,                   -- list of enabled modules, top right
    Stats = true,                       -- FPS / ping next to the island
    Island = nil,                       -- optional: your own island Frame
    IslandIcon = "rbxassetid://134387593103194", -- arrow on the island's show / hide button
    InteractiveElements = true,         -- toggles play an effect when switched on
    EffectAnimation = "Ripple",         -- "Ripple" | "1's and 0's" | "Glass Crack"

    -- Advanced
    Secure = false,                     -- true = parent to CoreGui instead of PlayerGui (see below)
})
UI:CreateSettingsTab()                  -- built-in Settings tab (mode, scale, 3D placement, theme)
```

#### Interactive Elements

Found in **Settings → Theme**. With **Interactive Elements** on (the default), switching a toggle on, or turning a module on with a click, plays an effect that starts at that toggle. **Effect Animation** picks which one:

| Effect | What it does |
| --- | --- |
| `Ripple` (default) | Rings in the theme colour spread out from the toggle and fade away. |
| `1's and 0's` | A burst of 1s and 0s is thrown out of the toggle, scrambling as they fly, then fading. |
| `Glass Crack` | Procedurally generated cracks in the theme colour jump outward from the toggle in steps, with forks, then break up and fade in irregular beats like shattering glass. |

Effects are drawn on a clipped layer covering just that tab's content area (the panel body in Tabs mode), so they can't escape it. Switching a toggle *off* plays nothing, and neither do changes made from code. Set the defaults with `InteractiveElements = false` and `EffectAnimation = "Glass Crack"` in `Library.new`, or play one yourself with `UI:PlayEffect(guiObject, tab)`.

#### Advanced: `Secure`

With `Secure = true` (or `Advanced = { Secure = true }`) every GUI the library makes, including the 3D hub's `SurfaceGui`, is parented to `CoreGui` instead of the player's `PlayerGui`.

Roblox only allows certain contexts to parent into CoreGui (plugins and some elevated environments). A regular `LocalScript` can't, so in that case the library prints one warning, `[CIALib] Secure is on but CoreGui can't be used from this context; using PlayerGui instead`, and carries on in PlayerGui rather than failing.

### API

**Library**

| Call | Description |
| --- | --- |
| `UI:Tab(name, icon?)` | Adds a tab. `icon` is an optional image asset id. |
| `UI:CreateSettingsTab()` | Adds the built-in Settings tab. |
| `UI:Notify({ Title, Content, Type, Duration })` | `Type` is `Info` (default, uses the accent), `Success`, `Warning` or `Error`. Returns `{ Close = function }`. |
| `UI:SetMode("2D" \| "3D" \| "Tabs")` | Switch display mode. |
| `UI:SetVisible(bool)` / `UI:Toggle()` | Show or hide the hub. |
| `UI:SetPanelOpen(tab, bool)` | Collapse or open a tab's panel in Tabs mode (`tab` is the Tab object or its name). The state is remembered when you switch modes. |
| `UI:SetAccent(Color3)` | Change the accent colour. Presets are in `Library.ACCENTS`. |
| `UI:SetScale(n)` | Extra 2D scale on top of the automatic fit (0.5 – 1.5). |
| `UI:SetOffset3D(side, up, forward)` / `UI:SetScale3D(n)` | 3D hub placement relative to your character. |
| `UI:SetArrayList(bool)` / `UI:SetStatsVisible(bool)` | Toggle the array list / the island stats. |
| `UI:Destroy()` | Remove everything. |

**Tab**

| Call | Description |
| --- | --- |
| `Tab:Module({ Name, Description, Default, Callback, Toggleable, Open, HideInArray })` | A module with an on/off state and expandable settings. |
| `Tab:Section({ Name, Description, Open })` | Like a module, but it only expands (no on/off state). |

**Module** (`module.Enabled` holds the state)

| Call | Description |
| --- | --- |
| `Module:Set(bool)` / `Module:Flip()` | Turn the module on or off from code. |
| `Module:Toggle({ Name, Default, Callback })` | Switch. Returns a control with `:Set(v)` / `:Get()`. |
| `Module:Slider({ Name, Min, Max, Default, Increment, Suffix, Callback })` | Slider with `:Set(v)` / `:Get()`. |
| `Module:Dropdown({ Name, Options, Default, Multi, Callback })` | Dropdown with `:Set(v)`, `:Get()`, `:SetOptions(list)`. Multi-select takes and returns a list. |
| `Module:Button({ Name, Callback })` | Button. |
| `Module:Keybind({ Name, Default, Toggles, OnPress, Callback })` | Click, then press a key to bind (Backspace clears, Escape cancels). `Toggles = true` makes the key flip the module. |
| `Module:Label(text)` | Text with `:SetText(s)`. |

Callbacks are wrapped in `pcall`, so an error in one will print a warning instead of breaking the UI.

## Notes

- FPS is averaged twice a second. Ping uses the network stats item when it can be read and otherwise falls back to the player's own network ping, so it may read a few milliseconds in Studio.
- Text boxes are not supported (typing into a 3D `SurfaceGui` is unreliable).
- Mouse interaction on the 3D hub is mapped from the cursor onto the part, so sliders keep working while you drag outside it.
