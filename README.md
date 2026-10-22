# CIA UI Lib

A dark, grey, Minecraft-client style UI library for Roblox, shipped as a **single LocalScript** (`main.lua`).

**Build 7 · v1**

- Three display modes you can switch between at any time: a **2D** window, a **3D** hub that floats in front of your character, and floating **Tabs** panels along the top of the screen
- Modules with smooth expanding settings, toggles, sliders, dropdowns (single or multi-select), buttons, keybinds and labels
- A built-in floating **island** at the top middle of the screen: your local time with a blinking colon, a show/hide button, a mode button beside it, and a live FPS / ping readout on the other side. The library builds it itself, so nothing has to exist in `StarterGui`
- **Interactive Elements**: flipping a toggle on or off plays an effect from exactly where you clicked, in the theme colour, that stays inside its tab (Ripple, 1's and 0's, or Glass Crack). It has its own **When On** / **When Off** switches
- **Custom Backgrounds**: animated backdrops for every tab in 2D, 3D and Tabs mode: Waves, Stormy Night (rain, splashes, lightning) and Cherry Blossom
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
    InteractiveElements = true,         -- toggles play an effect from where you click
    EffectAnimation = "Ripple",         -- "Ripple" | "1's and 0's" | "Glass Crack"
    EffectWhenOn = true,                -- ...when a toggle is switched on
    EffectWhenOff = true,               -- ...when a toggle is switched off
    CustomBackgrounds = false,          -- animated backdrop behind every tab
    Background = "Waves",               -- "Waves" | "Stormy Night" | "Cherry Blossom"

    -- Advanced
    Secure = false,                     -- true = parent to CoreGui instead of PlayerGui (see below)
})
UI:CreateSettingsTab()                  -- built-in Settings tab (mode, scale, 3D placement, theme)
```

#### Interactive Elements

A toggle in the **Settings** tab that holds its own configs: switch it on or off, and right-click it (or use its arrow) to open them.

| Config | What it does |
| --- | --- |
| **Effect Animation** | Which effect plays (below). `Ripple` is the default. |
| **When On** | Play the effect when a toggle is switched **on** (default on). |
| **When Off** | Play the effect when a toggle is switched **off** (default on). |

Clicking a toggle (or clicking a module on or off) plays the effect **from the exact spot you clicked**, in the theme colour. If the click didn't come from the pointer (a script, a keybind) it starts from the middle of the toggle instead.

| Effect | What it does |
| --- | --- |
| `Ripple` | Rings spread out from the click and fade away. |
| `1's and 0's` | A burst of 1s and 0s is thrown out of the click, scrambling as they fly, then fading. |
| `Glass Crack` | Procedurally generated cracks jump outward from the click in steps, with forks, then break up and fade in irregular beats like shattering glass. |

Effects are drawn on a clipped layer covering just that tab's content area (the panel body in Tabs mode), so they can't escape it. Changes made from code don't play them. Set the defaults with `InteractiveElements`, `EffectAnimation`, `EffectWhenOn` and `EffectWhenOff` in `Library.new`, or play one yourself with `UI:PlayEffect(origin, tab)`.

#### Custom Backgrounds

Another toggle in **Settings**, with a **Background** dropdown. It puts an animated backdrop behind every tab: the window in 2D and 3D, and each panel in Tabs mode. It is off by default.

| Background | What it does |
| --- | --- |
| `Waves` | Water that swells up and down on a spring model; random impulses send waves racing along the surface and sloshing back. Tinted with the theme colour. |
| `Stormy Night` | A dark night with rain that falls at a slant and splashes at the bottom of the tab, each splash leaving a puddle that fades out quickly, and random lightning that strikes with a jagged bolt and a choppy double flash that lights the whole tab. |
| `Cherry Blossom` | Blocky, pixel-art cherry trees on a grass strip. Petals drift off the canopies with a smooth left-and-right sway, land and stop, then fade away. |

Turn it on from code with `CustomBackgrounds = true` and `Background = "Stormy Night"` in `Library.new`, or `UI:SetBackgroundEnabled(true)` and `UI:SetBackground("Waves")`.

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
| `UI:SetBackgroundEnabled(bool)` / `UI:SetBackground(name)` | Turn Custom Backgrounds on or off, or pick `"Waves"`, `"Stormy Night"` or `"Cherry Blossom"`. |
| `UI:PlayEffect(origin, tab)` | Play the current Interactive Elements effect from a GuiObject or a screen position inside `tab`'s space. |
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
