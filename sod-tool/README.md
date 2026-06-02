# LOVING Sod Measurement Tool

Netlify deployment package.

## How to deploy

1. Go to Netlify.
2. Choose "Add new site" > "Deploy manually".
3. Drag and drop this ZIP file into Netlify.
4. Open the deployed site URL in Chrome.
5. Upload a plot plan PDF/image, rotate if needed, calibrate a known linear distance in feet, trace the lot/building/patio/driveway/other deductions, and calculate sod.

## Notes

- This is a static browser app.
- PDF rendering uses PDF.js from a CDN, so the deployed site needs internet access.
- Image uploads work directly in the browser.
- Calibration uses linear feet, not square feet.
- Pallets calculate at 500 square feet per pallet.

## New in this version

- Wider right-side takeoff panel.
- Smaller canvas labels.
- Labels hot button to hide/show labels when they are in the way.
- Save Photo button exports the current plan view as a PNG.

## Distance measuring

After calibration, choose Measure distance from the toolbar, then click two points on the plan. The app labels and lists the straight-line distance in feet. Use this for items like measuring from the end of a lot to a dotted easement/setback line.

## Curved measurements

Use Curve On while drawing an area if the boundary is curved, such as a rounded patio, sidewalk, or bed edge. Use Measure curved path to click several points along a sidewalk/curb/bed edge, then click Finish Path or press Enter to get linear feet.

## Pulled curve measurement

Choose Measure curved path, click a start point, click an end point, then drag the orange diamond handle to pull the line into a curve. Click Lock Curve when the curve matches the sidewalk, curb, or bed edge.
