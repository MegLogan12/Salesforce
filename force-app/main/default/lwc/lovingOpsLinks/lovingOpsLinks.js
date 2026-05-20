import { LightningElement, api } from 'lwc';

const LINKS = {
    wex:      'https://www.wexinc.com/solutions/fleet-cards/',
    weather:  'https://forecast.weather.gov/MapClick.php?CityName=Charlotte&state=NC&site=GSP&textField1=35.2271&textField2=-80.8431',
    rippling: 'https://app.rippling.com',
    maps:     'https://www.google.com/maps/search/Charlotte,+NC/@35.2271,-80.8431,12z'
};

export default class LovingOpsLinks extends LightningElement {
    @api label;
    openWex()      { window.open(LINKS.wex,      '_blank'); }
    openWeather()  { window.open(LINKS.weather,  '_blank'); }
    openRippling() { window.open(LINKS.rippling, '_blank'); }
    openMaps()     { window.open(LINKS.maps,     '_blank'); }
}