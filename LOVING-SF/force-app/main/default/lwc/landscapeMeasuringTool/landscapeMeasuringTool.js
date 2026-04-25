import { LightningElement, api, track } from 'lwc';
import { loadScript, loadStyle } from 'lightning/platformResourceLoader';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';
import LeafletJS from '@salesforce/resourceUrl/LeafletJS';
import getWorkOrderData from '@salesforce/apex/LOVING_LandscapeMeasureController.getWorkOrderData';
import saveTakeoffMeasurements from '@salesforce/apex/LOVING_LandscapeMeasureController.saveTakeoffMeasurements';

const DEFAULT_LAT  = 30.3;
const DEFAULT_LNG  = -97.7;
const DEFAULT_ZOOM = 17;
const METERS_TO_FT = 3.28084;
const SQM_TO_SQFT  = 10.7639;

// Color per draw mode
const MODE_COLORS = {
    sod:     '#22c55e',
    bed:     '#a16207',
    linear:  '#f97316',
    grading: '#6366f1'
};

export default class LandscapeMeasuringTool extends LightningElement {

    @api recordId;

    @track currentMode = 'sod';
    @track selectedPlantType = 'shrubs1G';

    // Area/linear totals (computed from drawn shapes list)
    @track _sodPolygons     = [];
    @track _bedPolygons     = [];
    @track _linearLines     = [];
    @track _gradingLines    = [];

    // Plant counters
    @track _shrubs1G = 0;
    @track _shrubs3G = 0;
    @track _shrubs7G = 0;
    @track _trees15G = 0;
    @track _trees30G = 0;
    @track _trees45G = 0;
    @track _lights   = 0;

    // Grading state
    @track gradeHorizontalFt = null;
    @track gradeVerticalIn   = null;
    @track gradingNotes      = '';

    @track isSaving = false;

    _leafletLoaded = false;
    _map           = null;
    _drawLayer     = null;
    _drawnItems    = null;

    // ── Lifecycle ──────────────────────────────────────────────────────────────

    renderedCallback() {
        if (this._leafletLoaded) return;
        this._leafletLoaded = true;

        Promise.all([
            loadStyle(this, LeafletJS + '/leaflet.css'),
            loadStyle(this, LeafletJS + '/leaflet.draw.css'),
            loadScript(this, LeafletJS + '/leaflet.js')
        ])
        .then(() => loadScript(this, LeafletJS + '/leaflet.draw.js'))
        .then(() => this._initMap())
        .catch(err => {
            this._toast('Map failed to load', err.message || String(err), 'error');
        });
    }

    // ── Map initialisation ─────────────────────────────────────────────────────

    _initMap() {
        // Fix default icon paths to our static resource
        // eslint-disable-next-line no-undef
        delete L.Icon.Default.prototype._getIconUrl;
        // eslint-disable-next-line no-undef
        L.Icon.Default.mergeOptions({
            iconUrl:       LeafletJS + '/images/marker-icon.png',
            iconRetinaUrl: LeafletJS + '/images/marker-icon-2x.png',
            shadowUrl:     LeafletJS + '/images/marker-shadow.png'
        });

        const container = this.template.querySelector('.map-container');
        // eslint-disable-next-line no-undef
        this._map = L.map(container, { attributionControl: false })
            .setView([DEFAULT_LAT, DEFAULT_LNG], DEFAULT_ZOOM);

        // ESRI World Imagery satellite tiles (no API key required)
        // eslint-disable-next-line no-undef
        L.tileLayer(
            'https://server.arcgisonline.com/ArcGIS/rest/services/World_Imagery/MapServer/tile/{z}/{y}/{x}',
            { maxZoom: 22 }
        ).addTo(this._map);

        // Layer group for all drawn items
        // eslint-disable-next-line no-undef
        this._drawnItems = new L.FeatureGroup();
        this._map.addLayer(this._drawnItems);

        this._refreshDrawControl();
        this._bindDrawEvents();
        this._loadWorkOrderData();
    }

    _refreshDrawControl() {
        if (this._drawLayer) {
            this._map.removeControl(this._drawLayer);
        }

        const isPolygonMode = this.currentMode === 'sod' || this.currentMode === 'bed';
        const isLineMode    = this.currentMode === 'linear' || this.currentMode === 'grading';
        const color         = MODE_COLORS[this.currentMode] || '#3388ff';

        // eslint-disable-next-line no-undef
        this._drawLayer = new L.Control.Draw({
            edit: { featureGroup: this._drawnItems },
            draw: {
                polygon:   isPolygonMode ? { shapeOptions: { color, fillOpacity: 0.25 } } : false,
                polyline:  isLineMode    ? { shapeOptions: { color, weight: 3 } }         : false,
                rectangle: false,
                circle:    false,
                circlemarker: false,
                marker:    false
            }
        });
        this._map.addControl(this._drawLayer);
    }

    _bindDrawEvents() {
        this._map.on('draw:created', evt => {
            const { layer, layerType } = evt;
            this._drawnItems.addLayer(layer);
            this._handleDrawCreated(layer, layerType);
        });
    }

    _handleDrawCreated(layer, layerType) {
        if (layerType === 'polygon') {
            const sqft = this._polygonAreaSqft(layer.getLatLngs()[0]);
            if (this.currentMode === 'sod') {
                this._sodPolygons = [...this._sodPolygons, { sqft }];
            } else if (this.currentMode === 'bed') {
                this._bedPolygons = [...this._bedPolygons, { sqft }];
            }
        } else if (layerType === 'polyline') {
            const ft = this._polylineLengthFt(layer.getLatLngs());
            if (this.currentMode === 'linear') {
                this._linearLines = [...this._linearLines, { ft }];
            } else if (this.currentMode === 'grading') {
                this.gradeHorizontalFt = parseFloat(ft.toFixed(1));
                this._gradingLines = [...this._gradingLines, { ft }];
            }
        }
    }

    // Load existing takeoff values and centre map on lot address
    _loadWorkOrderData() {
        if (!this.recordId) return;
        getWorkOrderData({ workOrderId: this.recordId })
            .then(data => {
                // Pre-populate plant counts from saved values
                this._shrubs1G = data.shrubs1G || 0;
                this._shrubs3G = data.shrubs3G || 0;
                this._shrubs7G = data.shrubs7G || 0;
                this._trees15G = data.trees15G || 0;
                this._trees30G = data.trees30G || 0;
                this._trees45G = data.trees45G || 0;
                this._lights   = data.lights   || 0;
                if (data.slopePct) {
                    this.gradeHorizontalFt = null;
                    this.gradeVerticalIn   = null;
                }
                this.gradingNotes = data.gradingNotes || '';

                // Centre map
                if (data.lat && data.lng) {
                    this._map.setView([data.lat, data.lng], DEFAULT_ZOOM);
                } else if (data.streetAddress) {
                    this._geocodeAddress(
                        `${data.streetAddress}, ${data.city || ''}, ${data.state || ''} ${data.zip || ''}`
                    );
                }
            })
            .catch(err => {
                this._toast('Could not load work order data', err.body?.message || String(err), 'warning');
            });
    }

    _geocodeAddress(address) {
        // Nominatim open geocoder — works without API key
        const encoded = encodeURIComponent(address);
        fetch(`https://nominatim.openstreetmap.org/search?q=${encoded}&format=json&limit=1`)
            .then(r => r.json())
            .then(results => {
                if (results && results.length > 0) {
                    this._map.setView([parseFloat(results[0].lat), parseFloat(results[0].lon)], DEFAULT_ZOOM);
                }
            })
            .catch(() => {/* stay at default view */});
    }

    // ── Geometry helpers ───────────────────────────────────────────────────────

    _polygonAreaSqft(latlngs) {
        // Spherical excess formula (accurate for small polygons like lots)
        // Converts degrees→radians, computes signed area on sphere, returns sq ft
        const R = 6371000; // Earth radius metres
        const n = latlngs.length;
        if (n < 3) return 0;

        let area = 0;
        for (let i = 0; i < n; i++) {
            const j    = (i + 1) % n;
            const lat1 = (latlngs[i].lat * Math.PI) / 180;
            const lat2 = (latlngs[j].lat * Math.PI) / 180;
            const dLng = ((latlngs[j].lng - latlngs[i].lng) * Math.PI) / 180;
            area += (dLng) * (2 + Math.sin(lat1) + Math.sin(lat2));
        }
        const sqm = Math.abs((area * R * R) / 2);
        return sqm * SQM_TO_SQFT;
    }

    _polylineLengthFt(latlngs) {
        let metres = 0;
        for (let i = 0; i < latlngs.length - 1; i++) {
            // eslint-disable-next-line no-undef
            metres += latlngs[i].distanceTo(latlngs[i + 1]);
        }
        return metres * METERS_TO_FT;
    }

    // ── Computed getters — summary values ─────────────────────────────────────

    get sodSqft() {
        return Math.round(this._sodPolygons.reduce((s, p) => s + p.sqft, 0));
    }
    get bedSqft() {
        return Math.round(this._bedPolygons.reduce((s, p) => s + p.sqft, 0));
    }
    get linearFt() {
        return Math.round(this._linearLines.reduce((s, l) => s + l.ft, 0));
    }
    get shrubs1G() { return this._shrubs1G; }
    get shrubs3G() { return this._shrubs3G; }
    get shrubs7G() { return this._shrubs7G; }
    get trees15G() { return this._trees15G; }
    get trees30G() { return this._trees30G; }
    get trees45G() { return this._trees45G; }
    get lights()   { return this._lights;   }

    get slopePct() {
        if (!this.gradeHorizontalFt || !this.gradeVerticalIn || this.gradeHorizontalFt === 0) return null;
        const riseFt = this.gradeVerticalIn / 12;
        return ((riseFt / this.gradeHorizontalFt) * 100).toFixed(2);
    }
    get hasGradeValue() {
        return this.slopePct !== null;
    }
    get gradeStatus() {
        const pct = parseFloat(this.slopePct);
        if (isNaN(pct)) return '';
        if (pct <= 5)  return 'Good drainage';
        if (pct <= 12) return 'Steep — monitor erosion';
        return 'Requires engineering review';
    }
    get gradeBadgeClass() {
        const pct = parseFloat(this.slopePct);
        if (isNaN(pct)) return 'grade-badge';
        if (pct <= 5)  return 'grade-badge grade-good';
        if (pct <= 12) return 'grade-badge grade-warn';
        return 'grade-badge grade-danger';
    }

    // ── Mode helpers ───────────────────────────────────────────────────────────

    get isSodMode()     { return this.currentMode === 'sod'; }
    get isBedMode()     { return this.currentMode === 'bed'; }
    get isLinearMode()  { return this.currentMode === 'linear'; }
    get isPlantsMode()  { return this.currentMode === 'plants'; }
    get isGradingMode() { return this.currentMode === 'grading'; }

    get sodVariant()     { return this.currentMode === 'sod'     ? 'brand' : 'neutral'; }
    get bedVariant()     { return this.currentMode === 'bed'     ? 'brand' : 'neutral'; }
    get linearVariant()  { return this.currentMode === 'linear'  ? 'brand' : 'neutral'; }
    get plantsVariant()  { return this.currentMode === 'plants'  ? 'brand' : 'neutral'; }
    get gradingVariant() { return this.currentMode === 'grading' ? 'brand' : 'neutral'; }

    get modeIconName() {
        const icons = { sod: 'utility:edit', bed: 'utility:edit', linear: 'utility:edit_form', plants: 'utility:trail', grading: 'utility:chart' };
        return icons[this.currentMode] || 'utility:edit';
    }
    get modeInstruction() {
        const instructions = {
            sod:     'Draw polygons to outline sod areas. Each closed shape is summed to total sq ft.',
            bed:     'Draw polygons to outline mulch/planting beds. Each closed shape is summed to total sq ft.',
            linear:  'Draw lines to measure edging, walls, or fence runs. Each line adds to the linear ft total.',
            plants:  'Use the panel to count shrubs, trees, and lighting units by size.',
            grading:'Draw a line from the high point to the low point of the slope, then enter the vertical rise.'
        };
        return instructions[this.currentMode] || '';
    }

    get plantTypeOptions() {
        return [
            { label: 'Shrub — 1 Gallon',  value: 'shrubs1G' },
            { label: 'Shrub — 3 Gallon',  value: 'shrubs3G' },
            { label: 'Shrub — 7 Gallon',  value: 'shrubs7G' },
            { label: 'Tree — 15 Gallon',  value: 'trees15G' },
            { label: 'Tree — 30 Gallon',  value: 'trees30G' },
            { label: 'Tree — 45 Gallon',  value: 'trees45G' },
            { label: 'Lighting Unit',     value: 'lights'   }
        ];
    }

    // ── Event handlers ─────────────────────────────────────────────────────────

    setMode(evt) {
        const mode = evt.currentTarget.value;
        if (mode === this.currentMode) return;
        this.currentMode = mode;
        if (this._map) {
            this._refreshDrawControl();
        }
    }

    handlePlantTypeChange(evt) {
        this.selectedPlantType = evt.detail.value;
    }

    addPlant() {
        this[`_${this.selectedPlantType}`] = (this[`_${this.selectedPlantType}`] || 0) + 1;
    }

    removePlant() {
        const current = this[`_${this.selectedPlantType}`] || 0;
        this[`_${this.selectedPlantType}`] = Math.max(0, current - 1);
    }

    handleHorizontalChange(evt) {
        this.gradeHorizontalFt = parseFloat(evt.detail.value) || null;
    }

    handleVerticalChange(evt) {
        this.gradeVerticalIn = parseFloat(evt.detail.value) || null;
    }

    handleGradingNotesChange(evt) {
        this.gradingNotes = evt.detail.value;
    }

    clearAll() {
        if (this._drawnItems) {
            this._drawnItems.clearLayers();
        }
        this._sodPolygons  = [];
        this._bedPolygons  = [];
        this._linearLines  = [];
        this._gradingLines = [];
        this.gradeHorizontalFt = null;
        this.gradeVerticalIn   = null;
    }

    saveMeasurements() {
        this.isSaving = true;

        const payload = {
            sodSqft:      this.sodSqft,
            bedSqft:      this.bedSqft,
            linearFt:     this.linearFt,
            shrubs1G:     this._shrubs1G,
            shrubs3G:     this._shrubs3G,
            shrubs7G:     this._shrubs7G,
            trees15G:     this._trees15G,
            trees30G:     this._trees30G,
            trees45G:     this._trees45G,
            lights:       this._lights,
            slopePct:     this.slopePct ? parseFloat(this.slopePct) : null,
            gradingNotes: this.gradingNotes,
            geoJson:      this._buildGeoJson()
        };

        saveTakeoffMeasurements({
            workOrderId:     this.recordId,
            measureDataJson: JSON.stringify(payload)
        })
        .then(() => {
            this._toast('Takeoff Saved', 'Measurements saved and takeoff marked complete.', 'success');
        })
        .catch(err => {
            this._toast('Save Failed', err.body?.message || String(err), 'error');
        })
        .finally(() => {
            this.isSaving = false;
        });
    }

    // ── Helpers ────────────────────────────────────────────────────────────────

    _buildGeoJson() {
        if (!this._drawnItems) return null;
        const features = [];
        this._drawnItems.eachLayer(layer => {
            if (layer.toGeoJSON) {
                features.push(layer.toGeoJSON());
            }
        });
        return JSON.stringify({ type: 'FeatureCollection', features });
    }

    _toast(title, message, variant) {
        this.dispatchEvent(new ShowToastEvent({ title, message, variant }));
    }
}
