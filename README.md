![coldrock-banner-itch-960x110](https://github.com/coldrockgames/.github/blob/main/public_images/repo-banner-trans.png)

https://github.com/user-attachments/assets/1b712c46-6bb2-47b6-88b2-b91ca2a02ded

![Godot Version](https://img.shields.io/badge/Godot-4.6+-blue.svg) ![License](https://img.shields.io/badge/License-MIT-green.svg) ![Version](https://img.shields.io/badge/Version-2610.1-orange)

# Coldrock CSV Translation Plugin
This repository contains the SeeAsWheee! Plugin, a visual, keyboard-driven CSV translation & localization editor for Godot 4.x

# Visual CSV Localization

Streamline your game's localization workflow directly within Godot. This plugin provides a dedicated visual editor for creating, managing, and editing CSV translation files without relying on external spreadsheet applications.

Engineered for high-throughput translation workflows, it handles complex text formatting, BBCode tags, multiline strings, and multi-language layouts with full **RFC 4180** CSV spec compliance.

### Key Features

* **Dedicated Visual UI:** Manage localization keys and language fields side-by-side with auto-adapting horizontal and vertical layouts.
* **Keyboard-Driven Workflow:** Rapidly add, edit, and navigate translations using ergonomic shortcuts (`INSERT` for new keys, `TAB` field jumping, `DELETE` for removal).
* **Smart Clipboard Import ("Paste CSV"):** Ingest single or multi-line CSV translations directly from LLMs (Gemini, ChatGPT) or external editors in a single click.
* **RFC 4180 Compliant:** Robust parsing engine with full support for escaped double quotes (`""`), enclosed line breaks (`\n`), and special character sets.
* **Safe Column Management:** Add or remove language columns dynamically with built-in data destruction confirmations.
* **Git-Friendly Data Persistence:** Preserves physical key positioning in source files during renames to prevent noisy version control diffs.
* **Project File Integration:** Auto-detects project CSV files, offers manual refreshes, and supports optional `addons/` directory scanning.

### Requirements & Compatibility
* **Engine:** Godot 4.x
* **Implementation:** 100% Pure GDScript (`@tool` plugin, zero external dependencies)
