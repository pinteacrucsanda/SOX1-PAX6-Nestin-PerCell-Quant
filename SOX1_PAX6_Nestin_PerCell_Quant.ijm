// 0. Open CZI with Bio-Formats
inputPath = File.openDialog("Choose CZI file");
run("Bio-Formats Importer",
    "open=[" + inputPath + "] " +
    "autoscale color_mode=Default view=Hyperstack stack_order=XYCZT");
// Keep original hyperstack title (if you need it later)
origTitle = getTitle();

// ---- Z PROJECTION: MAX INTENSITY OVER Z ----
run("Z Project...", "projection=[Max Intensity]");
projTitle = getTitle();    // title of the projected image

selectWindow(projTitle);
run("Make Composite");

// ---- SPLIT CHANNELS (C1..C4) ----
run("Split Channels");

// Channels will now be named: "C1-"+projTitle, "C2-"+projTitle, etc.
nestinTitle = "C1-" + projTitle;  // 488
pax6Title   = "C2-" + projTitle;  // 647
sox1Title   = "C3-" + projTitle;  // 568
dapiTitle   = "C4-" + projTitle;  // DAPI

// Rename each channel to simpler, fixed names
selectWindow("C1-" + projTitle);
rename("Nestin");
nestinTitle = "Nestin";

selectWindow("C2-" + projTitle);
rename("PAX6");
pax6Title = "PAX6";

selectWindow("C3-" + projTitle);
rename("SOX1");
sox1Title = "SOX1";

selectWindow("C4-" + projTitle);
rename("DAPI");
dapiTitle = "DAPI";

// =============================================
// OPTIONAL: SELECT THRESHOLD FOR EACH ANALYZED CHANNEL
// =============================================

// ---- SOX1 ----
selectWindow(sox1Title);
run("Duplicate...", "title=SOX1_threshold_preview");
selectWindow("SOX1_threshold_preview");
run("8-bit");  
run("Enhance Contrast", "saturated=0.35");

// Open threshold window
run("Threshold...");
// Threshold selection will only apply for Nestin - VORONOI.
// Pulse OK 
waitForUser("Ajusta el umbral de SOX1 (negativo/positivo) y pulsa OK.");

// save Threshold values
getThreshold(sox1ThrMin, sox1ThrMax);
print("SOX1 threshold elegido = " + sox1ThrMin + " - " + sox1ThrMax);

// close preview
close();

// ---- PAX6 ----
selectWindow(pax6Title);
run("Duplicate...", "title=PAX6_threshold_preview");
selectWindow("PAX6_threshold_preview");
run("8-bit");
run("Enhance Contrast", "saturated=0.35");
run("Threshold...");
waitForUser("Ajusta el umbral de PAX6 (negativo/positivo) y pulsa OK.");

getThreshold(pax6ThrMin, pax6ThrMax);
print("PAX6 threshold elegido = " + pax6ThrMin + " - " + pax6ThrMax);
close();

// ---- NESTIN ----
selectWindow(nestinTitle);
run("Duplicate...", "title=Nestin_threshold_preview");
selectWindow("Nestin_threshold_preview");
run("8-bit");
run("Enhance Contrast", "saturated=0.35");
run("Threshold...");
waitForUser("Ajusta el umbral de Nestin (negativo/positivo) y pulsa OK.");

getThreshold(nestinThrMin, nestinThrMax);
print("Nestin threshold elegido = " + nestinThrMin + " - " + nestinThrMax);
close();

// From this point onward everything remains the same: DAPI segmentation, ROIs, measurements, Voronoi, etc.
// The thresholds are saved in:
//   sox1ThrMin, sox1ThrMax
//   pax6ThrMin, pax6ThrMax
//   nestinThrMin, nestinThrMax
// and you can find them in the Log window to use later in the analysis.



// ========= DAPI NUCLEAR SEGMENTATION =========

selectWindow(dapiTitle);
run("Duplicate...", "title=DAPI_work");
selectWindow("DAPI_work");
run("8-bit");  

// 2) CLAHE
run("Enhance Local Contrast (CLAHE)", 
    "blocksize=50 histogram=256 maximum=3 mask=*None*");

// 3) Gaussian smoothing before thresholding
run("Gaussian Blur...", "sigma=1.5");

// 4) Auto Local Threshold - Bernsen
run("Auto Local Threshold", 
    "method=Bernsen radius=15 parameter_1=0 parameter_2=0 white");

// 5) Binary cleanup: fill holes + watershed
run("Fill Holes");
run("Watershed");

// 6) FIRST pass of Analyze Particles to estimate mean nuclear area
roiManager("Reset");
run("Clear Results");

run("Set Measurements...", "area redirect=None decimal=3");
run("Analyze Particles...", 
    "size=20-200 show=Nothing display clear");  // no ROIs yet, just measure

n = nResults;
totalArea = 0;
for (i = 0; i < n; i++) {
    totalArea += getResult("Area", i);
}
meanArea = totalArea / n;
print("Mean nuclear area (all objects) = " + meanArea);

// Define final size limits: 20%–200% of mean nuclear area
minArea = 0.20 * meanArea;
maxArea = 2.00 * meanArea;

// 7) SECOND pass of Analyze Particles with area filters + exclude edges
run("Clear Results");
roiManager("Reset");

run("Analyze Particles...",
    "size=" + minArea + "-" + maxArea + 
    " circularity=0.00-1.00 show=Masks display clear add exclude");

// The image that has just been created is the nuclear mask in DAPI.
dapiMaskTitle = getTitle();
rename("DAPI_nuclei_mask");
dapiMaskTitle = "DAPI_nuclei_mask";

// *** NESTIN *** save nuclear ROIs in a temporary ZIP to restore them later
tempDir = getDirectory("temp");
roiZip  = tempDir + "nuclei_temp.zip";
roiManager("Save", roiZip);

// Assume ROI Manager contains all nuclear ROIs
nROIs = roiManager("count");
if (nROIs == 0) exit("No ROIs in ROI Manager.");


// ----- SOX1 -----
selectWindow(sox1Title);  // "SOX1"
run("Clear Results");
run("Set Measurements...", "area mean redirect=None decimal=3");

// Measure all ROIs at once in SOX1
roiManager("Measure");

n = nResults;  // number of nuclei

// Store area and mean SOX1 in arrays
areaArray   = newArray(n);
meanSOX1Arr = newArray(n);

for (i = 0; i < n; i++) {
    areaArray[i]   = getResult("Area", i);
    meanSOX1Arr[i] = getResult("Mean", i);
}

// ----- PAX6 -----
selectWindow(pax6Title);  // "PAX6"
run("Clear Results");
run("Set Measurements...", "area mean redirect=None decimal=3");

// Measure all ROIs at once in PAX6
roiManager("Measure");

// Store mean PAX6 in another array
meanPAX6Arr = newArray(n);
for (i = 0; i < n; i++) {
    meanPAX6Arr[i] = getResult("Mean", i);
}

// SOX1 nuclear mask
selectWindow(sox1Title);   // "SOX1"
getDimensions(w, h, c, z, t);
newImage("SOX1_nuclei_mask", "8-bit black", w, h, 1);
selectWindow("SOX1_nuclei_mask");
setForegroundColor(255,255,255);

for (i = 0; i < nROIs; i++) {
    roiManager("Select", i);
    run("Fill");
}
sox1MaskTitle = "SOX1_nuclei_mask";

// PAX6 nuclear mask
selectWindow(pax6Title);   // "PAX6"
getDimensions(w, h, c, z, t);
newImage("PAX6_nuclei_mask", "8-bit black", w, h, 1);
selectWindow("PAX6_nuclei_mask");
setForegroundColor(255,255,255);

for (i = 0; i < nROIs; i++) {
    roiManager("Select", i);
    run("Fill");
}
pax6MaskTitle = "PAX6_nuclei_mask";

// ========= NESTIN VIA VORONOI (cytoplasmic) =========
// 1) we start from the DAPI nuclear mask as seeds
selectWindow(dapiMaskTitle);
setOption("BlackBackground", true);
run("Convert to Mask");
run("Duplicate...", "title=VoronoiSeeds");
vorTitle = getTitle();

// 2) Voronoi
selectWindow(vorTitle);
run("Voronoi");

// 3) convert the Voronoi lines into cell territories
setThreshold(1, 255);      
run("Convert to Mask");    
run("Invert");             

// 4) obtain one ROI per Voronoi cell

roiManager("Reset");
minCellArea = 50;        
run("Analyze Particles...", "size="+minCellArea+"-Infinity show=Nothing clear add");

// 5) measure ONLY Nestin+ within each Voronoi cell

selectWindow(nestinTitle); // "Nestin"
run("Clear Results");

// --- NESTIN THRESHOLD (ADJUST THESE VALUES TO YOUR IMAGE) ---

nestinMin = 20;       
nestinMax = 255;    
setThreshold(nestinMin, nestinMax);

// 'limit' => only counts pixels within the Nestin+ threshold inside each ROI
run("Set Measurements...", "area mean min max integrated limit redirect=None decimal=3");
roiManager("Measure");

nNestin = nResults;
meanNestinArr = newArray(nNestin);
for (i = 0; i < nNestin; i++) {
    meanNestinArr[i] = getResult("Mean", i);
}

// NOTE: the "Area" shown here is the Nestin+ area within each cell,
// not the total area of the Voronoi cell.

// 6) create Voronoi cell mask (to save)
selectWindow(nestinTitle);
getDimensions(w, h, c, z, t);
newImage("Nestin_voronoi_mask", "8-bit black", w, h, 1);
selectWindow("Nestin_voronoi_mask");
setForegroundColor(255,255,255);
for (i = 0; i < roiManager("count"); i++) {
    roiManager("Select", i);
    run("Fill");
}
nestinVorMaskTitle = "Nestin_voronoi_mask";

// 6b) create a Nestin overlay with the Voronoi cells drawn
selectWindow(nestinTitle);
roiManager("Show All");
run("Flatten");                     // creation of new image Nestin + Voronoi cells
rename("Nestin_voronoi_overlay");
nestinVorOverlayTitle = "Nestin_voronoi_overlay";
roiManager("Show None");

// 7) restore nuclear ROIs from the temporary ZIP
roiManager("Reset");
roiManager("Open", roiZip);
nROIs = roiManager("count");

// quick consistency check
if (nNestin != nROIs) {
    print("WARNING: Voronoi cells = " + nNestin + " ; nuclear ROIs = " + nROIs);
}

// ===== SELECT FOLDER AND DEFINE BASE NAME =====
outDir = getDirectory("Choose output folder");

// base name derived from the original CZI filename (without .czi)
base = origTitle;
dot = lastIndexOf(base, ".");
if (dot != -1) base = substring(base, 0, dot);

// ===== SAVE MASKS =====
selectWindow(dapiMaskTitle);
saveAs("Tiff", outDir + base + "_DAPI_nuclei_mask.tif");

selectWindow(sox1MaskTitle);
saveAs("Tiff", outDir + base + "_SOX1_nuclei_mask.tif");

selectWindow(pax6MaskTitle);
saveAs("Tiff", outDir + base + "_PAX6_nuclei_mask.tif");

selectWindow(nestinVorMaskTitle);
saveAs("Tiff", outDir + base + "_Nestin_voronoi_mask.tif");

// ===== OVERLAYS NUCLEARES (DAPI, SOX1, PAX6)  Show All + Flatten =====

// DAPI overlay (nuclei)
selectWindow(dapiTitle); // "DAPI"
roiManager("Show All");
run("Flatten");
rename("DAPI_overlay");
saveAs("Tiff", outDir + base + "_DAPI_overlay.tif");
close();

// SOX1 overlay (nuclei analyzed for SOX1)
selectWindow(sox1Title); // "SOX1"
roiManager("Show All");
run("Flatten");
rename("SOX1_overlay");
saveAs("Tiff", outDir + base + "_SOX1_overlay.tif");
close();

// PAX6 overlay (nuclei analyzed for PAX6)
selectWindow(pax6Title); // "PAX6"
roiManager("Show All");
run("Flatten");
rename("PAX6_overlay");
saveAs("Tiff", outDir + base + "_PAX6_overlay.tif");
close();

roiManager("Show None");

// ===== OVERLAY NESTIN + VORONOI =====
selectWindow(nestinVorOverlayTitle);
saveAs("Tiff", outDir + base + "_Nestin_voronoi_overlay.tif");
close();


// ===== FINAL PER-CELL TABLE (Area + SOX1 + PAX6 + Nestin Voronoi) =====
// *** NESTIN ***

run("Clear Results");

// for safety, use the minimum between n (SOX1/PAX6) and nNestin

nCells = n;
if (nNestin < nCells) nCells = nNestin;

for (i = 0; i < nCells; i++) {
    setResult("Cell", i, i+1);
    setResult("Area", i, areaArray[i]);
    setResult("Mean_SOX1", i, meanSOX1Arr[i]);
    setResult("Mean_PAX6", i, meanPAX6Arr[i]);
    setResult("Mean_Nestin_Voronoi", i, meanNestinArr[i]);
}
updateResults();

saveAs("Results", outDir + base + "_per_cell_results.csv");

// ===== CLOSE EVERYTHING AND END MESSAGE =====
run("Close All");
showMessage("END", "Analysis completed.\nEND.");

