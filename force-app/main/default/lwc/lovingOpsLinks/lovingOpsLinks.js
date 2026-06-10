import { LightningElement, api, wire } from 'lwc';
import getLinks from '@salesforce/apex/LovingExternalLinkController.getLinks';

const TERRITORY_COORDS = {
    'Charlotte Metro':  { lat: 35.2271, lon: -80.8431, city: 'Charlotte,+NC',  nws: 'Charlotte&state=NC&site=GSP' },
    'Charlotte - North':{ lat: 35.3271, lon: -80.7431, city: 'Charlotte,+NC',  nws: 'Charlotte&state=NC&site=GSP' },
    'Triad':            { lat: 36.0726, lon: -79.7920, city: 'Greensboro,+NC', nws: 'Greensboro&state=NC&site=RAH' },
    'Triangle':         { lat: 35.7796, lon: -78.6382, city: 'Raleigh,+NC',    nws: 'Raleigh&state=NC&site=RAH' },
    'Greenville':       { lat: 34.8526, lon: -82.3940, city: 'Greenville,+SC', nws: 'Greenville&state=SC&site=GSP' },
    'Upstate SC':       { lat: 34.9496, lon: -81.9319, city: 'Spartanburg,+SC',nws: 'Spartanburg&state=SC&site=GSP' },
    'Columbia':         { lat: 34.0007, lon: -81.0348, city: 'Columbia,+SC',   nws: 'Columbia&state=SC&site=CAE' },
    'Midlands SC':      { lat: 34.0007, lon: -81.0348, city: 'Columbia,+SC',   nws: 'Columbia&state=SC&site=CAE' },
    'Asheville':        { lat: 35.5951, lon: -82.5515, city: 'Asheville,+NC',  nws: 'Asheville&state=NC&site=RNK' },
    'Western NC':       { lat: 35.5951, lon: -82.5515, city: 'Asheville,+NC',  nws: 'Asheville&state=NC&site=RNK' }
};
const DEFAULT_TERRITORY = 'Charlotte Metro';

export default class LovingOpsLinks extends LightningElement {
    @api label;
    @api division;

    externalLinks = [];

    @wire(getLinks)
    wiredLinks({ data }) {
        if (data) this.externalLinks = data;
    }

    get _coords() {
        const key = this.division && TERRITORY_COORDS[this.division]
            ? this.division
            : DEFAULT_TERRITORY;
        return TERRITORY_COORDS[key];
    }

    get weatherLabel() {
        return this._coords.city.replace(/,\+/g, ', ');
    }

    get mapsLabel() {
        return this._coords.city.replace(/,\+/g, ', ');
    }

    get linksByCategory() {
        const groups = {};
        const order = [];
        for (const l of this.externalLinks) {
            if (!groups[l.category]) {
                groups[l.category] = [];
                order.push(l.category);
            }
            groups[l.category].push(l);
        }
        return order.map(cat => ({ category: cat, links: groups[cat] }));
    }

    handleLinkClick(event) {
        const url = event.currentTarget.dataset.url;
        if (url) window.open(url, '_blank', 'noopener');
    }

    openWeather() {
        const c = this._coords;
        window.open(
            `https://forecast.weather.gov/MapClick.php?CityName=${c.nws}&textField1=${c.lat}&textField2=${c.lon}`,
            '_blank',
            'noopener'
        );
    }

    openMaps() {
        const c = this._coords;
        window.open(
            `https://www.google.com/maps/search/${c.city}/@${c.lat},${c.lon},12z`,
            '_blank',
            'noopener'
        );
    }
}
