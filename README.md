## Emu48 for macOS 27 (Golden Gate)

## Overview

This project is an update of the classic **Emu48** calculator emulator for modern macOS.

The original Emu48 emulator was created by **Christoph Giesselink** and **Sebastien Carlier**. The original **OS X port was done by Da Woon Jung**.

This update brings the OS X version forward so that it can be built and run on **macOS 27 (Golden Gate)** while retaining the original emulator functionality and calculator support.

The goal was not to rewrite Emu48, but to modernize the macOS application layer around the existing emulator so that it works naturally with current versions of macOS and Xcode.  A few enhancements have also been added.

---

### Modern macOS / Xcode compatibility

The project was brought forward to build cleanly with a current version of Xcode and the macOS 27 SDK.

The work included updating portions of the older AppKit code and project configuration that no longer fit comfortably with the current macOS development environment.

The underlying Emu48 emulation code remains based on the original project.

### New Features

#### Calculator Gallery

A new calculator gallery was added to make selecting and launching calculators easier.

The gallery supports:

- **Card view** with calculator artwork, title, model, rom and KML filenames.
- **List view** for a more compact calculator browser.

#### Zoom

- Zoom and auto-zoom options.

#### Enhanced Keyboard Handling

- Enhanced keyboard interaction.
- Support for numeric keypad

#### Misc

- An information button for calculator details.

### ROM Files (or lack thereof)

Due to copyright issues, ROM files are not provided.

### KML calculator files

KML files are also not included.  They can be found online (see hpcalc.org)

Calculator definition files (.kml) are discovered from the user's Document directory (under emu48/kml/).

The calculator directory is refreshed when the application starts so that newly added calculators are available without having to rebuild the application.

### Startup behavior

The startup preferences were updated to provide a better experience when launching Emu48.

The application can:

1. Do nothing.
2. Open the last saved calculator state.
3. Open a configured startup calculator.
4. Display the calculator chooser.

---

## Building

The project is intended to be built with Xcode using the current macOS SDK.

The resulting application is:

```text
Emu48.app
```

For development builds, Xcode places the application in its normal DerivedData build-products directory.

---

## Credits

### Original Emu48

**Christoph Giesselink**  
**Sebastien Carlier**

Creators of the original Emu48 emulator.

### OS X Port

**Da Woon Jung**

Author of the original OS X port.

### This Update

This project builds on their work to bring Emu48 forward for modern macOS, including **macOS 27 (Golden Gate)**.

The original emulator and OS X port deserve the credit for making this project possible. This update focuses on maintaining that work and adapting the macOS application to the current platform.

---

## Version

This update is released as:

**v1.5.0**

---

## License / Original Project

Please refer to the original Emu48 project and source distribution for the applicable license and original copyright information.

This project is an update of the macOS port and retains the original Emu48 heritage and attribution.
