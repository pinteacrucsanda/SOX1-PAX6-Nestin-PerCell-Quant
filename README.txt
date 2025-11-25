SOX1_PAX6_Nestin_PerCell_Quant.ijm
-------------------------------------------------------------
Automated per-cell quantification of SOX1, PAX6 and Nestin in 
iPSC-derived neural progenitors using Fiji/ImageJ.

Author: Rucsanda Pinteac
Date: 2025
Requires: Fiji with Bio-Formats
-------------------------------------------------------------

1. OVERVIEW
-----------
This macro performs a complete single-cell analysis of 4-channel 
CZI images containing:
  - DAPI (nuclei)
  - SOX1 (nuclear)
  - PAX6 (nuclear)
  - Nestin (cytoplasmic)

The pipeline includes:
  - Z-projection and channel splitting
  - Manual threshold selection for each marker
  - Automated nuclear segmentation from DAPI
  - Per-nucleus measurement of SOX1 and PAX6
  - Voronoi-based cytoplasmic territory assignment
  - Measurement of Nestin+ area and intensity per cell
  - Automatic saving of masks, overlays, and a final table

-------------------------------------------------------------

2. INPUT
--------
- A 4-channel `.czi` file acquired with:
    C1 = Nestin (488)
    C2 = PAX6 (647)
    C3 = SOX1 (568)
    C4 = DAPI

- The macro asks the user to select:
    a) The input file
    b) Thresholds for SOX1, PAX6 and Nestin
    c) The output folder

-------------------------------------------------------------

3. PROCESSING STEPS
-------------------

3.1. Preprocessing
- Open CZI with Bio-Formats
- Max Intensity Z-projection
- Convert to composite and split channels
- Rename channels for downstream consistency

3.2. Manual threshold selection
The macro will open preview windows for:
  - SOX1
  - PAX6
  - Nestin

You must adjust the threshold manually and press OK.
Thresholds are stored internally for later use.

3.3. Nuclear segmentation (DAPI)
- CLAHE
- Gaussian blur
- Local threshold (Bernsen)
- Fill holes + Watershed
- Two-pass filtering based on mean nuclear area

Output:
  - Binary DAPI_nuclei_mask.tif
  - One ROI per nucleus in ROI Manager

3.4. Nuclear marker quantification
- Measure mean intensity of SOX1 and PAX6 inside each nuclear ROI
- Generate nuclear masks for both markers

3.5. Voronoi cytoplasmic quantification (Nestin)
- DAPI nuclei used as Voronoi seeds
- Convert Voronoi lines to cell territories
- Create one ROI per Voronoi cell
- Apply Nestin threshold and measure:
     * Nestin+ area
     * Mean, min, max intensity
     * Integrated signal

3.6. Final per-cell table
For each cell the macro records:
  - Area (nuclear)
  - SOX1 intensity
  - PAX6 intensity
  - Nestin intensity (Voronoi-based)

Saved as: `<basename>_per_cell_results.csv`

-------------------------------------------------------------

4. OUTPUT FILES
---------------
The macro automatically generates:

 1. Masks
    - *_DAPI_nuclei_mask.tif
    - *_SOX1_nuclei_mask.tif
    - *_PAX6_nuclei_mask.tif
    - *_Nestin_voronoi_mask.tif

 2. Overlays (for QC)
    - *_DAPI_overlay.tif
    - *_SOX1_overlay.tif
    - *_PAX6_overlay.tif
    - *_Nestin_voronoi_overlay.tif

 3. Quantification table
    - *_per_cell_results.csv

All files use the original CZI file name as a base.

-------------------------------------------------------------

5. REQUIREMENTS
---------------
- Fiji (recommended version > 2023)
- Bio-Formats Importer
- Auto Local Threshold plugin
- Access to ROI Manager
- Standard ImageJ Voronoi operation

-------------------------------------------------------------

6. NOTES
--------
- Nestin threshold is applied to cytoplasmic Voronoi regions,
  not to nuclei.
- The macro uses `limit` mode to only measure Nestin+ pixels.
- The number of Voronoi cells must match the number of nuclei;
  if not, the macro prints a warning.
- The macro closes all windows at the end.

-------------------------------------------------------------

7. CONTACT
----------
For questions or extensions:
Rucsanda Pinteac
pinteac.rucsanda@gmail.com