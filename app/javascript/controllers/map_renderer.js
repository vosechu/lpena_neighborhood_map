// MapRenderer handles all Leaflet map operations and rendering
export class MapRenderer {
  constructor(canvasElement, options = {}) {
    this.canvas = canvasElement;
    this.options = {
      center: [27.77441168140785, -82.72030234336854],
      zoom: 17,
      newResidentDays: 30,  // Default configuration
      ...options
    };

    this.houses = [];
    this.map = null;
    this.initializeMap();
  }

  initializeMap() {
    this.map = L.map(this.canvas).setView(this.options.center, this.options.zoom);
    window.map = this.map; // For debugging

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map);
  }

  // Render houses from provided data
  loadHouses(houses) {
    houses.forEach(house => this.addHouse(house));
    this.updateHighlight();
    return houses;
  }

  // Add a single house to the map
  addHouse(house) {
    this.addHousePolygon(house);
    this.addHouseIcons(house);
    this.houses.push(house);
  }

  // Create and add polygon for a house
  addHousePolygon(house) {
    const geometry = house.boundary_geometry;
    if (!geometry?.rings?.[0]) return;

    // Check if any resident in the house has an email
    const hasResidentWithEmail = house.residents && house.residents.some(resident => 
      resident.email && resident.email.trim() !== ''
    );

    const latlngs = geometry.rings[0].map(this.fromWebMercator);
    const polygon = L.polygon(latlngs, {
      color: hasResidentWithEmail ? "#22c55e" : "#3388ff", // green if has email, blue otherwise
      weight: 1,
      fillOpacity: 0.3
    }).addTo(this.map);

    polygon.on('click', () => {
      this.onHouseClick?.(house);
    });

    house.polygon = polygon;
  }

  // Add status icons to a house
  addHouseIcons(house) {
    if (!house.polygon) return;

    const bounds = house.polygon.getBounds();
    const center = bounds.getCenter();
    const icons = this.getHouseIcons(house);

    if (icons.length === 0) return;

    const iconContainer = L.divIcon({
      className: 'house-icons-container',
      html: this.renderIconsHtml(icons),
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });

    const iconMarker = L.marker(center, { icon: iconContainer }).addTo(this.map);
    house.iconMarker = iconMarker;

    iconMarker.on('click', () => {
      this.onHouseClick?.(house);
    });
  }

  // Get array of icons for a house
  getHouseIcons(house) {
    if (!house.icon_type) return [];

    const eventCount = house.events ? house.events.length : 0;

    if (house.icon_type === 'star') {
      return [{
        type: 'celebration',
        svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="w-4 h-4 text-yellow-500">
          <path fill-rule="evenodd" d="M8 1.75a.75.75 0 0 1 .692.462l1.41 3.393 3.664.293a.75.75 0 0 1 .428 1.317l-2.791 2.39.853 3.575a.75.75 0 0 1-1.12.814L7.998 12.08l-3.135 1.915a.75.75 0 0 1-1.12-.814l.852-3.574-2.79-2.39a.75.75 0 0 1 .427-1.318l3.663-.293 1.41-3.393A.75.75 0 0 1 8 1.75Z" clip-rule="evenodd" />
        </svg>`,
        title: `${eventCount} exciting things happening here!`
      }];
    }

    if (house.icon_type === 'birthday') {
      return [{
        type: 'birthday',
        svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="w-4 h-4 text-pink-600">
          <path d="m4.75 1-.884.884a1.25 1.25 0 1 0 1.768 0L4.75 1ZM11.25 1l-.884.884a1.25 1.25 0 1 0 1.768 0L11.25 1ZM8.884 1.884 8 1l-.884.884a1.25 1.25 0 1 0 1.768 0ZM4 7a2 2 0 0 0-2 2v1.034c.347 0 .694-.056 1.028-.167l.47-.157a4.75 4.75 0 0 1 3.004 0l.47.157a3.25 3.25 0 0 0 2.056 0l.47-.157a4.75 4.75 0 0 1 3.004 0l.47.157c.334.111.681.167 1.028.167V9a2 2 0 0 0-2-2V5.75a.75.75 0 0 0-1.5 0V7H8.75V5.75a.75.75 0 0 0-1.5 0V7H5.5V5.75a.75.75 0 0 0-1.5 0V7ZM14 11.534a4.749 4.749 0 0 1-1.502-.244l-.47-.157a3.25 3.25 0 0 0-2.056 0l-.47.157a4.75 4.75 0 0 1-3.004 0l-.47-.157a3.25 3.25 0 0 0-2.056 0l.47.157A4.748 4.748 0 0 1 2 11.534V13a1 1 0 0 0 1 1h10a1 1 0 0 0 1-1v-1.466Z" />
        </svg>`,
        title: 'Upcoming birthday in the next 30 days!'
      }];
    }

    if (house.icon_type === 'new_residents') {
      return [{
        type: 'new_residents',
        svg: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 16 16" fill="currentColor" class="w-4 h-4 text-green-600">
          <path fill-rule="evenodd" d="M3.75 3.5c0 .563.186 1.082.5 1.5H2a1 1 0 0 0 0 2h5.25V5h1.5v2H14a1 1 0 1 0 0-2h-2.25A2.5 2.5 0 0 0 8 1.714 2.5 2.5 0 0 0 3.75 3.5Zm3.499 0v-.038A1 1 0 1 0 6.25 4.5h1l-.001-1Zm2.5-1a1 1 0 0 0-1 .962l.001.038v1h.999a1 1 0 0 0 0-2Z" clip-rule="evenodd" />
          <path d="M7.25 8.5H2V12a2 2 0 0 0 2 2h3.25V8.5ZM8.75 14V8.5H14V12a2 2 0 0 1-2 2H8.75Z" />
        </svg>`,
        title: 'New residents in the last 30 days!'
      }];
    }

    return [];
  }

  // Render HTML for multiple icons
  renderIconsHtml(icons) {
    return `<div class="flex gap-1 items-center justify-center bg-white bg-opacity-90 rounded-full p-1 shadow-sm">
      ${icons.map(icon => `<span title="${icon.title}">${icon.svg}</span>`).join('')}
    </div>`;
  }

    // Show popup at coordinates with content
  showPopupAt(lat, lng, content) {
    const popup = L.popup({
      closeOnClick: false,
      keepInView: true,
      autoPan: true
    }).setLatLng([lat, lng]).setContent(content);

    popup.openOn(this.map);
    return popup;
  }

  // Close any open popup
  closePopup() {
    this.map.closePopup();
  }

  // Update highlighting based on search and filters
  updateHighlight(searchQuery = '', showNewOnly = false) {
    const query = searchQuery.trim().toLowerCase();

    const now = new Date();
    const cutoff = new Date(now);
    cutoff.setDate(now.getDate() - this.options.newResidentDays);

    this.houses.forEach((house) => {
      const address = `${house.street_number} ${house.street_name}`.toLowerCase();
      const residents = house.residents || [];

      const residentMatch = residents.some(r => {
        return (r.display_name && r.display_name.toLowerCase().includes(query)) ||
               (r.official_name && r.official_name.toLowerCase().includes(query));
      });

      const matchesSearch = query === '' ? true : (address.includes(query) || residentMatch);

      const hasNewResident = residents.some(r => {
        if (!r.first_seen_at) return false;
        const firstSeen = new Date(r.first_seen_at);
        return firstSeen >= cutoff;
      });

      const matchesNew = showNewOnly ? hasNewResident : true;
      const isMatch = matchesSearch && matchesNew;

      if (house.polygon) {
        if (isMatch) {
          // Check if any resident in the house has an email
          const hasResidentWithEmail = residents.some(resident => 
            resident.email && resident.email.trim() !== ''
          );
          const highlightColor = hasResidentWithEmail ? '#22c55e' : '#3388ff'; // green if has email, blue otherwise
          
          house.polygon.setStyle({ color: highlightColor, fillOpacity: 0.5, weight: 2 });
          if (!this.map.hasLayer(house.polygon)) {
            house.polygon.addTo(this.map);
          }
        } else {
          house.polygon.setStyle({ color: '#cccccc', fillOpacity: 0.1, weight: 1 });
        }
      }
    });
  }

  // Convert Web Mercator coordinates to lat/lng
  fromWebMercator([x, y]) {
    const lng = (x / 20037508.34) * 180;
    const lat = (y / 20037508.34) * 180;
    const latRad = (Math.PI / 180) * lat;
    const latFinal = (180 / Math.PI) * (2 * Math.atan(Math.exp(latRad)) - Math.PI / 2);
    return [latFinal, lng];
  }

  // Set callback for house clicks
  setHouseClickCallback(callback) {
    this.onHouseClick = callback;
  }

  // Get the underlying Leaflet map instance
  getMap() {
    return this.map;
  }

  // Find house by ID
  findHouse(houseId) {
    return this.houses.find(house => house.id === houseId);
  }

  // Update house data (after resident changes)
  updateHouse(houseId, updatedHouse) {
    const index = this.houses.findIndex(house => house.id === houseId);
    if (index !== -1) {
      // Preserve polygon and iconMarker references
      const { polygon, iconMarker } = this.houses[index];
      this.houses[index] = { ...updatedHouse, polygon, iconMarker };

      // Update icons if they changed
      if (iconMarker) {
        this.map.removeLayer(iconMarker);
        delete this.houses[index].iconMarker;
      }
      this.addHouseIcons(this.houses[index]);
    }
  }
}
