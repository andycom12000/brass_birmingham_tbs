---
name: tts-xml-ui
description: Use when writing or debugging Tabletop Simulator XML UI — screen-overlay Buttons, Panels, Text, HUD elements. Covers rectAlignment/offsetXY positioning, HorizontalLayout/VerticalLayout sizing, onClick callbacks, UI.setAttribute runtime changes, active/visibility toggling, and createButton for object-level UI. Use this whenever TTS UI elements are invisible, mispositioned, or onClick doesn't fire.
---

# TTS XML UI Reference

## Overview

TTS has a screen-overlay XML UI system. Elements are positioned via `rectAlignment` + `offsetXY`, NOT `position` (which is a 3D parallax attribute). Layout group children use `preferredWidth`/`preferredHeight`, not `width`/`height`.

## Critical Mistakes (Will Cause Invisible UI)

| Wrong | Right | Why |
|-------|-------|-----|
| `position="0 350 0"` | `rectAlignment="UpperCenter" offsetXY="0 -55"` | `position` is 3D parallax, not screen coords |
| `<Button width="80">` inside layout | `<Button preferredWidth="80">` | Layout children ignore `width`/`height` |
| No `color` on Panel | `color="#1A1A2EE0"` | Panels without `color` are invisible |
| No `width`/`height` on root element | Always set explicit dimensions | Auto-sizing rarely works as expected |

## Positioning System

```
rectAlignment = anchor point on screen
  UpperLeft    UpperCenter    UpperRight
  MiddleLeft   MiddleCenter   MiddleRight
  LowerLeft    LowerCenter    LowerRight

offsetXY = pixel offset FROM anchor
  "x y" where +x=right, +y=up (inverted from typical screen coords for Upper anchors)
  Example: rectAlignment="UpperCenter" offsetXY="0 -55" = 55px below top-center
```

**Do NOT use** `position` for screen UI. It's for 3D world-space parallax effects only.

## Minimal Working Example

```xml
<Ui>
    <Defaults>
        <Button fontSize="14" fontStyle="Bold" textColor="#FFFFFF"/>
    </Defaults>

    <Panel id="myPanel" rectAlignment="UpperCenter" offsetXY="0 -10"
           width="300" height="40" color="#333333E0" active="true">
        <Text id="myText" text="Hello" fontSize="16" color="#FFFFFF"
              rectAlignment="MiddleCenter"/>
    </Panel>

    <Button id="myBtn" onClick="onMyBtn"
            rectAlignment="UpperCenter" offsetXY="0 -60"
            width="120" height="40"
            color="#8B2500" textColor="#FFD700">Click Me</Button>
</Ui>
```

## Layout Groups

`HorizontalLayout` and `VerticalLayout` **override child dimensions**. Use layout-specific attributes:

```xml
<Panel rectAlignment="UpperCenter" offsetXY="0 -100"
       width="400" height="50" color="#00000000">
    <HorizontalLayout spacing="8" padding="0 0 0 0"
                      rectAlignment="MiddleCenter">
        <!-- Use preferredWidth/Height, NOT width/height -->
        <Button onClick="onA" preferredWidth="90" preferredHeight="40"
                color="#4A7C59" textColor="#FFF">Action A</Button>
        <Button onClick="onB" preferredWidth="90" preferredHeight="40"
                color="#5B6A8A" textColor="#FFF">Action B</Button>
    </HorizontalLayout>
</Panel>
```

## onClick Callbacks

XML buttons call **Global script** functions by default.

```xml
<Button onClick="onMyAction">Do Thing</Button>
```

```lua
-- Lua callback signature: (player, value, id)
function onMyAction(player, value, id)
    local color = player.color  -- "White", "Red", etc.
    -- do something
end
```

To target an object's script instead: `onClick="abc123/onMyAction"` (GUID prefix).

## Runtime Manipulation (Lua)

```lua
-- Show/hide
UI.setAttribute("myPanel", "active", "true")   -- show
UI.setAttribute("myPanel", "active", "false")  -- hide

-- Change text
UI.setAttribute("myText", "text", "New text here")

-- Change color
UI.setAttribute("myBtn", "color", "#FF0000")

-- Read attribute
local isActive = UI.getAttribute("myPanel", "active")

-- Hide element (different from active=false: removes from layout flow)
UI.hide("myPanel")
UI.show("myPanel")
```

## Important Gotchas

- `UI.setAttribute` values are **ALWAYS strings**: `"true"` not `true`, `"42"` not `42`
- `padding` format: `"left right top bottom"` (NOT CSS order: top right bottom left)
- `childAlignment` on layout groups: `UpperLeft`, `MiddleCenter`, `LowerRight` etc.
- XML parse errors appear in **TTS chat** (red text with line/char position) — check there first if UI doesn't render
- `UI.hide`/`UI.show` removes element from layout flow; `active="false"` keeps layout space but hides visually

## Debugging Invisible UI

1. Check TTS chat for XML parse errors (red text with line/char position)
2. Verify `active="true"` on the element AND all parent Panels
3. Check `color` attribute exists on Panels (no color = invisible)
4. If inside layout group: use `preferredWidth`/`preferredHeight`
5. If using `position`: STOP — use `rectAlignment` + `offsetXY` instead
6. Check `visibility` attribute isn't restricting to other players

## Color Format

`#RRGGBB` or `#RRGGBBAA` (with alpha). Examples:
- `#333333E0` = dark grey, ~88% opaque
- `#00000000` = fully transparent (invisible container)
- `#8B2500` = dark red, fully opaque

## Common Patterns

### Toggle panel visibility from Lua

```lua
function UIManager.showPanel()
    UI.setAttribute("panelId", "active", "true")
end
function UIManager.hidePanel()
    UI.setAttribute("panelId", "active", "false")
end
```

### Defaults section for consistent styling

```xml
<Defaults>
    <Button fontSize="14" fontStyle="Bold" textColor="#FFFFFF"/>
    <Panel color="#1A1A2EE0"/>
</Defaults>
```

All `<Button>` elements inherit these defaults unless overridden.

### Visibility per player

```xml
<Button visibility="Red|Blue">Only Red and Blue see this</Button>
```

Omit `visibility` = visible to all.

## Object-Level UI (createButton)

For buttons attached to physical TTS objects (not screen overlay), use Lua `createButton`:

```lua
self.createButton({
    click_function = "onClick",
    function_owner = self,
    label          = "",               -- empty = invisible button
    tooltip        = "Click me",       -- hover text
    position       = {0, 0.5, 0},      -- relative to object
    width          = 800,
    height         = 800,
    color          = {1, 1, 1, 0},     -- RGBA, alpha 0 = transparent
    font_color     = {0, 0, 0, 0},
})
```

This is separate from XML UI. Use for clickable physical objects (setup buttons, tokens).

## Related: deck.deal() and Hand Zones

Not part of XML UI, but commonly needed alongside it.

```lua
deckObj.deal(count, playerColor)  -- deals cards to player's hand zone
```

Requires `HandTrigger` objects with `Hands=true` and correct `FogColor` per player. Without hand zones, cards scatter to world origin.

## Quick Checklist

- [ ] Using `rectAlignment` + `offsetXY` (NOT `position`)
- [ ] Layout children use `preferredWidth`/`preferredHeight`
- [ ] Panels have explicit `color` attribute
- [ ] Root elements have explicit `width` and `height`
- [ ] `active="true"` on elements that should be visible initially
- [ ] onClick targets correct script (Global by default)
- [ ] Callback function exists with `(player, value, id)` signature
