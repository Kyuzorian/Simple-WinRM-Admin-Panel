# SWAP — Simple WinRM Admin Panel

SWAP is a lightweight, PowerShell-based remote administration tool for Windows servers. It gives you a single WinForms desktop panel to sign in with domain credentials, connect to one or more Windows servers over WinRM, and manage services, processes, disks, and reboots — all without opening an RDP session.

## Why SWAP

- **No RDP required.** Everything runs over WinRM, so you get a scriptable, low-overhead admin channel instead of a full remote desktop session.
- **One panel, many servers.** Connect to multiple servers at once and switch between them from a sidebar list without re-entering credentials.
- **Safe by default.** Destructive actions (like restarting a server) require explicit confirmation, and the UI clearly shows connection state at all times.

## Features

### Authentication
- Sign in with a domain username and password directly from the app (inline login panel, no separate dialog window).
- Credentials are validated against Active Directory and used to create a net-only logon token — nothing is cached to disk.

### Multi-Server Management
- Add and connect to any number of servers after your initial sign-in.
- Switching between connected servers reuses your existing credentials — no need to re-authenticate.
- Disconnect from individual servers, or sign out entirely to close all sessions at once.

### Services
- View all Windows services on the selected server, with live status and startup type.
- Search/filter the service list in real time.
- Start, stop, or restart a service with one click. Restarts are polled in the background until the service reports "Running" or a timeout is reached.

### Processes
- View running processes sorted by CPU usage, including memory consumption.
- Search/filter by process name.
- End a process with a confirmation prompt to avoid accidental termination.

### Disks
- View all logical disks on the server with used/free/total space.
- Visual usage bars that shift color as a disk fills up (healthy → warning → critical).

### Server Restart
- Restart the remote server from the panel.
- Requires typing `RESTART` into a confirmation field before the action is sent — no accidental reboots.
- After a restart, SWAP automatically polls the server and reconnects once it's back online, updating the reboot-pending indicator.

### Reboot Status
- Automatically checks whether a server has a pending reboot (Windows Update, Component-Based Servicing, or pending file rename operations) and displays it in the sidebar.

### Activity Log
- A running log at the bottom of the window records every action (connections, service/process changes, failures) with timestamps, color-coded by outcome.

## Architecture

SWAP is split into three files for maintainability:

| File | Responsibility |
|---|---|
| `Core.psm1` | Authentication, server/session state, and the WinRM transport layer used to run remote actions. |
| `Gui.psm1` | The WinForms presentation layer — building the window, panels, and wiring up UI events. |
| `Start-AdminPanel.ps1` | Entry point that loads the modules and launches the panel. |

## Requirements

- Windows with PowerShell 5.1+ (WinForms-based UI)
- WinRM enabled and reachable on target servers
- A domain account with permission to connect to and manage the target servers

## Getting Started

```powershell
git clone https://github.com/<your-org>/swap.git
cd swap
./Start-AdminPanel.ps1
```

Sign in with your domain credentials, add a server, and you're in.

## Disclaimer

SWAP performs real administrative actions (starting/stopping services, ending processes, restarting servers) against live infrastructure. Use it in a way that fits your organization's change-management practices, and always confirm you're targeting the right server before restarting it.
