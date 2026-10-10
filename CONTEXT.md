# harbor — domain language

**Bank** — the workspaces that belong to one monitor. With
`split-monitor-workspaces`, DP-1 owns 1–10 and HDMI-A-1 owns 11–20. A bank is
read from Hyprland (`workspace.monitor`), never from a hard-coded range.

**Workspace number** — the 1-based position of a workspace inside its bank,
shown as `1`…`9`, `0` for the tenth (matching the `SUPER + <n>` keys). Workspace
11 on HDMI-A-1 has number `1`. The Hyprland id (11) is the **workspace id**.

**Strip** — the bar widget: one button per workspace number of the bar's
monitor.

**Notch** — the surface that slides down from the bottom border of the top
bar while the pointer rests on a strip button. It shows the **preview** (a
to-scale live picture of that workspace) and the **app row** (one icon per
window on that workspace).

**Dock** — the surface at the bottom edge of each monitor. It lists the
windows on that monitor and every group.

**Group** — a named set of windows the user builds by hand. A group lives
until the user deletes it, even when it has no members. Members are window
addresses, so membership does not survive a logout.

**Move** — sending a window, or every member of a group, to a workspace with
`follow = false`: the user stays where they are.
