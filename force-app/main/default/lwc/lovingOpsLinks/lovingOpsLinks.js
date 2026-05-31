import { LightningElement, api } from 'lwc';

export default class LovingOpsLinks extends LightningElement {
    @api label;
    @api wexUrl      = 'https://online.wexfleet.com';
    @api weatherUrl  = 'https://forecast.weather.gov/';
    @api ripplingUrl = 'https://app.rippling.com';
    @api mapsUrl     = 'https://www.google.com/maps';

    openWex()      { if (this.wexUrl)      window.open(this.wexUrl,      '_blank'); }
    openWeather()  { if (this.weatherUrl)  window.open(this.weatherUrl,  '_blank'); }
    openRippling() { if (this.ripplingUrl) window.open(this.ripplingUrl, '_blank'); }
    openMaps()     { if (this.mapsUrl)     window.open(this.mapsUrl,     '_blank'); }
}
