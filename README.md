Sample specification:
Best to use with samples at 48000 sample rate, 24 bit, stereo, wav.

Audio output:
Stereo, 48000 sample rate (this should be set before launching the application in system audio settings together with the audio device).

Notes:
Folder structure should suppose to stay as it is for the program to work. 

Desired folder structure:
```
play-...-latest.scd
presets/
├── performance
└── etc...
samples/
├── 160HzCelloCairo EXT.wav
└── etc
```

Installation guide:
1. if not already on your device, download and install SuperCollider 3.13.0 (https://supercollider.github.io/downloads) (tested, it can be that it works also with later or earlier)
2. download this folder as zip from github ([https://github.com/andrejs-poikans/compos-mentis-5-0](https://github.com/andrejs-poikans/for-rebecca))
3. unzip the file in a desired location on your device
4. open play-...-latest.scd (currently v2) via your desidred supercollider version, evaluate the code in the file
5. after a short loading time, the GUI should appear, that's all!

Trouble-shooting:
Samples do not load...
1. make sure that the samples exist in the correct location, if not, copy them inside 'samples' folder just as a list of files – not within other folders
2. close supercollider and reopen it

<img width="1440" height="811" alt="Screenshot 2026-02-24 at 14 20 05" src="https://github.com/user-attachments/assets/ac392448-1a1a-4f33-be9f-df97f2634592" />

