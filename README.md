# My scripts and effects plugins for Cockos REAPER DAW

## Extract Chords from Selected Audio Item (Chordino)

*ExtractChordsFromAudio.lua*

### What is this?

This ReaScript automatically extracts chords from a selected audio item (e.g., guitar, keyboard, or even full mix) and creates a dedicated track with chord names as text items.  
It leverages [Sonic Annotator](https://www.vamp-plugins.org/sonic-annotator/) and the [Chordino VAMP plugin](https://www.vamp-plugins.org/plugin-doc/qm-vamp-plugins.html#id6).

---


### Requirements

- **REAPER 6.0** or newer (Windows recommended)
- [Sonic Annotator](https://www.vamp-plugins.org/sonic-annotator/)  
- [Chordino VAMP plugin](https://github.com/tonalities/Chordino)  
- Project must be saved to disk before running the script.

---

## Installation & Setup

### 1. Install Sonic Annotator

- Download from: https://www.vamp-plugins.org/sonic-annotator/
- Unzip or install to a convenient folder (e.g., `C:\Program Files\sonic-annotator`).

### 2. Install Chordino VAMP Plugin

- Download from [the official site](https://github.com/tonalities/Chordino) or [VAMP Plugins Pack](https://code.soundsoftware.ac.uk/attachments/download/2863/Vamp%20Plugin%20Pack%20Installer%202.0.exe).
- Install all files (including `qm-vamp-plugins.dll`) into your `C:\Program Files\Vamp Plugins` directory  
  *(or any other VAMP plugin directory on your system).*

### 3. Configure the Script

- Open the script in REAPER (via Actions list > ReaScript).
- **Edit this line at the top:**
  ```lua
  local SONIC_ANNOTATOR_EXE = [[D:\Sound.dir\sonic-annotator\sonic-annotator.exe]]


### 4. Save Your REAPER Project

The script requires your project to be saved on disk before it can run (it needs a valid project folder for temp files).

### Usage

    Select any audio item (guitar, piano, mix, etc).

    Run the script (from Actions list, toolbar, or via hotkey).

    The script will process the audio and add a “Chords (Extracted)” track with text items indicating detected chords, each at the correct position.

### Troubleshooting

    If you see errors about "Sonic Annotator not launched", check the path and ensure Sonic Annotator is installed.
    If you see "CSV file was not created", verify that Chordino is properly installed and visible to Sonic Annotator.
    For best results, use relatively isolated guitar or keyboard parts; dense mixes or noisy sources may reduce accuracy.
    
    The script does not alter your original audio.

## Compensator

A universal JSFX gain compensator for Reaper. One plugin (sender) is placed before the VST chain and measures the input volume. The second (receiver) is placed at the output and attempts to return the volume to the level of the first.
The sender and receiver can be on different tracks, so the volume of one instrument can be adjusted based on the volume of the other.

## Installation & Setup
Put following files
- Compensator - Sender.jsfx
- Compensator - Receiver.jsfx

  into your reaper\effects folder. 
