# nocom-extractor Summary
Divide the nocom blocks file into 1.69gb files, filter each blocks file into only a certain block type and combine csv into one way smaller database of only a certain block, filter and search for blocks near a coordinate and cluster them into potential bases.

# Requirements

- Windows 11 (Maybe 10 will work?)
- (IMPORTANT - REQUIRED) PowerShell 7.5 https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.5
- 16 GB RAM - You can edit the code to use less cores/less ram if you have lower specs.

# Split-Blocks.ps1
This file splits large .sql files into smaller chunks. Change the exact size of the file by editing the code. Set to 1.69GB by default, which should split the nocom blocks file into about 218 parts.
Lines 4,5 set the input/output directories
Run powershell as admin and run Split-Blocks.ps1 with
``& 'yourDriveLetter:\Split-Blocks.ps1'``

# extract_shulkers_parallel.ps1
This file filters .sql files that are already split and follow a specific naming convention that is generated using the Split-Blocks.ps1 file (can be edited) for certain blocks, such as every block state of Shulkers, which are already coded in.
Lines 7-11 Change the configuration input, output, pattern for the filename, and how many files to scan in parallel. If you have a lot of RAM, you can go above 4, the default. If you have very little ram you will need to go lower until your program doesn't crash.
Run powershell as admin and run extract_shulkers_parallel.ps1 with
``& 'yourDriveLetter:\extract_shulkers_parallel.ps1'``

# FilterShulkers.ps1
Give you a lot of options on how to search for blocks and how to cluster them (Into small stashes, big bases, or just every instance of that item). If you're trying to filter for other blocks, I would suggest you change the range in extract_shulkers_parallel.ps1 and don't bother changing the naming of the file outputs.
Run powershell as admin and run FilterShulkers.ps1 with
``& 'yourDriveLetter:\FilterShulkers.ps1'``
