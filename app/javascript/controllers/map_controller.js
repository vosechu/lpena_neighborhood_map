import { Controller } from "@hotwired/stimulus"
import { fetchData } from "../services/data_service"
_.templateSettings.interpolate = /{{=([\s\S]+?)}}/g;
_.templateSettings.evaluate = /{{([\s\S]+?)}}/g;

function fromWebMercator([x, y]) {
  const lng = (x / 20037508.34) * 180
  const lat = (y / 20037508.34) * 180
  const latRad = (Math.PI / 180) * lat
  const latFinal = (180 / Math.PI) * (2 * Math.atan(Math.exp(latRad)) - Math.PI / 2)
  return [latFinal, lng]
}

export default class extends Controller {
  connect() {
    console.log("Map controller connected")

    this.loadMapData();

    // Add Escape key handler
    this._handleEscape = (e) => {
      if (e.key === 'Escape') {
        // Hide modal
        var modal = document.getElementById('modal');
        if (modal) { modal.style.display = 'none'; }
        // Close any open Leaflet popup
        if (this.map && this.map.closePopup) {
          this.map.closePopup();
        }
      }
    };
    document.addEventListener('keydown', this._handleEscape);
  }

  disconnect() {
    // Remove Escape key handler
    document.removeEventListener('keydown', this._handleEscape);
  }

  async loadMapData() {
    try {
      const data = await fetchData('/api/houses');
      this.initializeMap(data);
    } catch (error) {
      console.error('Failed to load map data:', error);
    }
  }

  // Initialize the map and add house markers
  initializeMap(data) {
    // Initialize Leaflet map (if not already initialized)
    if (!this.map) {
      this.map = L.map(this.element).setView([27.77441168140785, -82.72030234336854], 17)
      window.map = this.map

      L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
        attribution: "&copy; OpenStreetMap contributors"
      }).addTo(this.map)
    } else {
      // Clear existing layers except the tile layer
      this.map.eachLayer((layer) => {
        if (layer instanceof L.Marker || layer instanceof L.Polygon) {
          this.map.removeLayer(layer);
        }
      });
    }

    // Add house polygons and markers
    data.forEach(house => {
      this.addHousePolygon(house);
    });
  }

  addHousePolygon(house) {
    const geometry = house.boundary_geometry;
    if (geometry && geometry.rings && geometry.rings[0]) {
      const latlngs = geometry.rings[0].map(fromWebMercator);
      const polygon = L.polygon(latlngs, {
        color: "#3388ff",
        weight: 1,
        fillOpacity: 0.3
      }).addTo(this.map);

      polygon.on('click', () => {
        this.addHousePopup(house);
      });
    } else if (house.latitude && house.longitude) {
      // Fallback to marker if no polygon data
      const marker = L.marker([house.latitude, house.longitude]).addTo(this.map);
      marker.on('click', () => {
        this.addHousePopup(house);
      });
    }
  }

  // Add popup content for each house marker
  addHousePopup(house) {
    // Render the house details with resident details and edit buttons in a leaflet popup
    const popup = L.popup({
      closeOnClick: false,
      keepInView: true,
      autoPan: true
    }).setLatLng([house.latitude, house.longitude]).setContent(this.renderHouseAndResidentsDetails(house));
    
    // Wait for the popup to be rendered before attaching event listeners
    setTimeout(() => {
      // Handle house edit buttons (all, in case there are multiple)
      const editHouseBtns = document.querySelectorAll('.edit-house-btn');
      editHouseBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          // Show a placeholder modal for house editing
          const modalEl = document.getElementById('modal');
          modalEl.innerHTML = `
            <div class="text-center">
              <h2 class="text-xl font-bold mb-4">House Editing</h2>
              <p class="mb-4">House editing functionality is not yet implemented.</p>
              <button class="close-modal-btn bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-2 px-4 rounded" onclick="document.getElementById('modal').style.display='none'">Close</button>
            </div>
          `;
          modalEl.style.display = 'block';
        });
      });

      // Handle resident edit buttons
      const editResidentBtns = document.querySelectorAll('.resident-name .edit-resident-btn');
      editResidentBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
          const residentId = e.target.closest('button').dataset.residentId;
          const resident = house.residents.find(r => r.id === parseInt(residentId));

          if (resident) {
            this.showResidentEditForm(resident);
          }
        });
      });

      // Handle hide resident buttons
      const hideResidentBtns = document.querySelectorAll('.hide-resident-btn');
      hideResidentBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
          const residentId = e.target.closest('button').dataset.residentId;
          this.hideResident(residentId);
        });
      });

      // Handle delete resident buttons  
      const deleteResidentBtns = document.querySelectorAll('.delete-resident-btn');
      deleteResidentBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
          const residentId = e.target.closest('button').dataset.residentId;
          if (confirm('Are you sure you want to delete this resident? This action cannot be undone.')) {
            this.deleteResident(residentId);
          }
        });
      });

      // Handle add resident button
      const addResidentBtn = document.querySelector('.add-resident-btn');
      if (addResidentBtn) {
        addResidentBtn.addEventListener('click', (e) => {
          const houseId = e.target.dataset.houseId;
          this.showNewResidentForm(houseId);
        });
      }
    }, 0);
    popup.openOn(this.map);
  }

  showResidentEditForm(resident) {
    const modalEl = document.getElementById('modal');
    const templateHtml = document.getElementById('resident-edit-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    modalEl.innerHTML = compiled({ resident });
    modalEl.style.display = 'block';

    // Handle save button
    const saveBtn = modalEl.querySelector('.save-resident-btn');
    saveBtn.addEventListener('click', () => {
      this.saveResident(resident.id);
    });
  }

  showNewResidentForm(houseId) {
    const modalEl = document.getElementById('modal');
    const templateHtml = document.getElementById('new-resident-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    modalEl.innerHTML = compiled({ houseId });
    modalEl.style.display = 'block';

    // Handle create button
    const createBtn = modalEl.querySelector('.create-resident-btn');
    createBtn.addEventListener('click', () => {
      this.createResident(houseId);
    });
  }

  async saveResident(residentId) {
    const modalEl = document.getElementById('modal');
    const formData = this.extractFormData(modalEl);

    try {
      const response = await fetch(`/api/residents/${residentId}`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ resident: formData })
      });

      if (response.ok) {
        modalEl.style.display = 'none';
        // Reload map data to reflect changes
        this.loadMapData();
      } else {
        const errors = await response.json();
        this.displayErrors(errors);
      }
    } catch (error) {
      console.error('Failed to save resident:', error);
      alert('Failed to save resident. Please try again.');
    }
  }

  async createResident(houseId) {
    const modalEl = document.getElementById('modal');
    const formData = this.extractFormData(modalEl);

    // Official name is required for creating residents
    if (!formData.official_name || formData.official_name.trim() === '') {
      alert('Official name is required.');
      return;
    }

    try {
      const response = await fetch(`/api/houses/${houseId}/residents`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        },
        body: JSON.stringify({ resident: formData })
      });

      if (response.ok) {
        modalEl.style.display = 'none';
        // Reload map data to reflect changes
        this.loadMapData();
      } else {
        const errors = await response.json();
        this.displayErrors(errors);
      }
    } catch (error) {
      console.error('Failed to create resident:', error);
      alert('Failed to create resident. Please try again.');
    }
  }

  async hideResident(residentId) {
    try {
      const response = await fetch(`/api/residents/${residentId}/hide`, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      });

      if (response.ok) {
        // Reload map data to reflect changes
        this.loadMapData();
      } else {
        const error = await response.json();
        alert(`Failed to hide resident: ${error.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('Failed to hide resident:', error);
      alert('Failed to hide resident. Please try again.');
    }
  }

  async deleteResident(residentId) {
    try {
      const response = await fetch(`/api/residents/${residentId}`, {
        method: 'DELETE',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      });

      if (response.ok) {
        // Reload map data to reflect changes
        this.loadMapData();
      } else {
        const error = await response.json();
        alert(`Failed to delete resident: ${error.error || 'Unknown error'}`);
      }
    } catch (error) {
      console.error('Failed to delete resident:', error);
      alert('Failed to delete resident. Please try again.');
    }
  }

  extractFormData(modalEl) {
    const formData = {};
    const fields = modalEl.querySelectorAll('[data-resident-field]');
    
    fields.forEach(field => {
      const fieldName = field.dataset.residentField;
      
      if (field.type === 'checkbox') {
        formData[fieldName] = field.checked;
      } else {
        formData[fieldName] = field.value;
      }
    });

    return formData;
  }

  displayErrors(errors) {
    let errorMessage = 'Please fix the following errors:\n';
    for (const [field, messages] of Object.entries(errors)) {
      errorMessage += `${field}: ${messages.join(', ')}\n`;
    }
    alert(errorMessage);
  }

  renderHouseAndResidentsDetails(house) {
    const templateHtml = document.getElementById('house-edit-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    return compiled({ house });
  }
}
