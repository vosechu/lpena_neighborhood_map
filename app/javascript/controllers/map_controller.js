import { Controller } from "@hotwired/stimulus"
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
  static targets = [
    "canvas",
    "searchInput",
    "newResidentsToggle"
  ]

  static values = {
    newResidentDays: { type: Number, default: 30 }
  }

  connect() {
    console.log("Map controller connected")

    // Initialize Leaflet map on the dedicated canvas target (not the controller root)
    this.map = L.map(this.canvasTarget).setView([27.77441168140785, -82.72030234336854], 17)
    window.map = this.map

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(this.map)

    // Load all houses and cache their data + polygon for filtering later
    this.houses = [];
    fetch("/api/houses")
      .then(res => res.json())
      .then(data => {
        data.forEach((house) => {
          this.addHousePolygon(house);
        });
        this.updateHighlight();
      });

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

    // Admin flag from dataset
    this.isAdmin = this.element.dataset.mapAdminValue === 'true';
  }

  disconnect() {
    // Remove Escape key handler
    document.removeEventListener('keydown', this._handleEscape);
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
        // TODO: Render the house details with resident details and edit buttons
        this.addHousePopup(house);
        // TODO: Attach modal actions to the edit buttons
      });

      // Attach polygon to house for later styling / searching
      house.polygon = polygon;
      this.houses.push(house);

      // Add to map initially; filtering will toggle later
      polygon.addTo(this.map);
    }
  }

  addHousePopup(house) {
    // Render the house details with resident details and edit buttons in a leaflet popup
    const popup = L.popup({
      closeOnClick: false,
      keepInView: true,
      autoPan: true
    }).setLatLng([house.latitude, house.longitude]).setContent(this.renderHouseAndResidentsDetails(house));
    popup.openOn(this.map);

    // Once popup is in the DOM attach listeners immediately (no async timeout)
    const popupEl = popup.getElement();
    if (popupEl) {
      this.bindHousePopupListeners(popupEl, house);
    }
  }

  // Attach edit/add buttons inside popup
  bindHousePopupListeners(popupEl, house) {
    // Edit resident buttons
    popupEl.querySelectorAll('.resident-name .edit-resident-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const residentId = e.currentTarget.dataset.residentId;
        const resident = house.residents.find(r => r.id === parseInt(residentId));
        if (!resident) return;

        const modalEl = document.getElementById('modal');
        const templateHtml = document.getElementById('resident-edit-form-template').innerHTML;
        modalEl.innerHTML = _.template(templateHtml)({ resident });
        modalEl.style.display = 'block';
        this.attachResidentFormHandlers(resident, house);
      });
    });

    // Add resident button (there is only one)
    const addBtn = popupEl.querySelector('.add-resident-btn');
    if (addBtn) {
      addBtn.addEventListener('click', () => this.showAddResidentModal(house));
    }
  }

  renderHouseAndResidentsDetails(house) {
    const templateHtml = document.getElementById('house-edit-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    return compiled({ house, isAdmin: this.isAdmin });
  }

  attachResidentFormHandlers(resident, house) {
    const modalEl = document.getElementById('modal');

    // Save button
    const saveBtn = modalEl.querySelector('.save-resident-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => {
        e.preventDefault();
        this.saveResident(resident, house);
      });
    }

    // Homepage normalization
    const homepageField = modalEl.querySelector('#resident-homepage');
    if (homepageField) {
      homepageField.addEventListener('blur', (e) => this.normalizeHomepageUrl(e.target));
    }

    // Close modal on backdrop click
    modalEl.addEventListener('click', (e) => {
      if (e.target === modalEl) modalEl.style.display = 'none';
    });
  }

  showAddResidentModal(house) {
    const modalEl = document.getElementById('modal');
    const templateHtml = document.getElementById('add-resident-form-template').innerHTML;
    modalEl.innerHTML = _.template(templateHtml)({ house });
    modalEl.style.display = 'block';
    this.attachAddResidentFormHandlers(house);
  }

  attachAddResidentFormHandlers(house) {
    const modalEl = document.getElementById('modal');

    const saveBtn = modalEl.querySelector('.add-resident-save-btn');
    if (saveBtn) {
      saveBtn.addEventListener('click', (e) => {
        e.preventDefault();
        this.addNewResident(house);
      });
    }

    const homepageField = modalEl.querySelector('#resident-homepage');
    if (homepageField) {
      homepageField.addEventListener('blur', (e) => this.normalizeHomepageUrl(e.target));
    }

    modalEl.addEventListener('click', (e) => {
      if (e.target === modalEl) modalEl.style.display = 'none';
    });
  }

  addNewResident(house) {
    const modalEl = document.getElementById('modal');

    // Normalize homepage URL before saving
    const homepageField = modalEl.querySelector('#resident-homepage');
    if (homepageField) {
      this.normalizeHomepageUrl(homepageField);
    }

    // Collect form data
    const formData = { house_id: house.id };
    const formFields = modalEl.querySelectorAll('[data-resident-field]');

    formFields.forEach(field => {
      const fieldName = field.dataset.residentField;
      formData[fieldName] = field.value;
    });

    // Validate required fields
    if (!formData.display_name || formData.display_name.trim() === '') {
      this.showErrorMessage('Name is required.');
      return;
    }

    // If official_name not provided (no longer collected from UI), default to display_name
    if (!formData.official_name) {
      formData.official_name = formData.display_name;
    }

    // Disable save button and show loading state
    const saveBtn = modalEl.querySelector('.add-resident-save-btn');
    if (saveBtn) {
      saveBtn.disabled = true;
      saveBtn.textContent = 'Adding...';
    }

    // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    const headers = {
      'Content-Type': 'application/json'
    };

    if (csrfToken) {
      headers['X-CSRF-Token'] = csrfToken.getAttribute('content');
    }

    // Make API call to create resident
    fetch('/api/residents', {
      method: 'POST',
      headers: headers,
      body: JSON.stringify({ resident: formData })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(newResident => {
      console.log('Resident created successfully:', newResident);

      // Add new resident to house object
      house.residents = house.residents || [];
      house.residents.push(newResident);

      // Close modal
      modalEl.style.display = 'none';

      // Update popup content with new data
      this.map.closePopup();
      this.addHousePopup(house);

      // Show success message
      this.showSuccessMessage('Resident added successfully!');
    })
    .catch(error => {
      console.error('Error creating resident:', error);

      // Re-enable save button
      if (saveBtn) {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Add Resident';
      }

      // Show error message
      this.showErrorMessage('Failed to add resident. Please try again.');
    });
  }

  saveResident(resident, house) {
    const modalEl = document.getElementById('modal');

    // Normalize homepage URL before saving
    const homepageField = modalEl.querySelector('#resident-homepage');
    if (homepageField) {
      this.normalizeHomepageUrl(homepageField);
    }

    // Collect form data
    const formData = {};
    const formFields = modalEl.querySelectorAll('[data-resident-field]');

    formFields.forEach(field => {
      const fieldName = field.dataset.residentField;
      formData[fieldName] = field.value;
    });

    // Disable save button and show loading state
    const saveBtn = modalEl.querySelector('.save-resident-btn');
    if (saveBtn) {
      saveBtn.disabled = true;
      saveBtn.textContent = 'Saving...';
    }

        // Get CSRF token
    const csrfToken = document.querySelector('meta[name="csrf-token"]');
    const headers = {
      'Content-Type': 'application/json'
    };

    if (csrfToken) {
      headers['X-CSRF-Token'] = csrfToken.getAttribute('content');
    }

    // Make API call to update resident
    fetch(`/api/residents/${resident.id}`, {
      method: 'PATCH',
      headers: headers,
      body: JSON.stringify({ resident: formData })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }
      return response.json();
    })
    .then(updatedResident => {
      console.log('Resident updated successfully:', updatedResident);

      // Update resident data in house object
      const residentIndex = house.residents.findIndex(r => r.id === resident.id);
      if (residentIndex !== -1) {
        house.residents[residentIndex] = { ...house.residents[residentIndex], ...updatedResident };
      }

      // Close modal
      modalEl.style.display = 'none';

      // Update popup content with new data
      this.map.closePopup();
      this.addHousePopup(house);

      // Show success message
      this.showSuccessMessage('Resident updated successfully!');
    })
    .catch(error => {
      console.error('Error updating resident:', error);

      // Re-enable save button
      if (saveBtn) {
        saveBtn.disabled = false;
        saveBtn.textContent = 'Save Changes';
      }

      // Show error message
      this.showErrorMessage('Failed to update resident. Please try again.');
    });
  }

  showSuccessMessage(message) {
    // Simple success notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-green-500 text-white px-4 py-2 rounded shadow-lg z-50';
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
      notification.remove();
    }, 3000);
  }

  showErrorMessage(message) {
    // Simple error notification
    const notification = document.createElement('div');
    notification.className = 'fixed top-4 right-4 bg-red-500 text-white px-4 py-2 rounded shadow-lg z-50';
    notification.textContent = message;
    document.body.appendChild(notification);

    setTimeout(() => {
      notification.remove();
    }, 5000);
  }

  normalizeHomepageUrl(inputField) {
    let url = inputField.value.trim();

    // Don't process empty values
    if (!url) {
      return;
    }

    // Convert to lowercase for checking
    const lowerUrl = url.toLowerCase();

    // If it doesn't start with http:// or https://, add https://
    if (!lowerUrl.startsWith('http://') && !lowerUrl.startsWith('https://')) {
      // Handle common cases like "www.example.com" or "example.com"
      url = 'https://' + url;
      inputField.value = url;

      // Add a subtle visual feedback to show the URL was normalized
      inputField.style.backgroundColor = '#f0f9ff'; // Light blue background
      inputField.style.transition = 'background-color 0.3s ease';

      setTimeout(() => {
        inputField.style.backgroundColor = '';
        setTimeout(() => {
          inputField.style.transition = '';
        }, 300);
      }, 1000);
    }
  }

  // ============== Search Highlighting =================
  updateHighlight() {
    const query = (this.hasSearchInputTarget ? this.searchInputTarget.value : '').trim().toLowerCase();
    const filterNew = this.hasNewResidentsToggleTarget ? this.newResidentsToggleTarget.checked : false;

    if (!this.houses) return;

    const now = new Date();
    const cutoff = new Date(now);
    cutoff.setDate(now.getDate() - this.newResidentDaysValue);

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

      const matchesNew = filterNew ? hasNewResident : true;

      const isMatch = matchesSearch && matchesNew;

      if (house.polygon) {
        if (isMatch) {
          house.polygon.setStyle({ color: '#3388ff', fillOpacity: 0.5, weight: 2 });
          if (!this.map.hasLayer(house.polygon)) {
            house.polygon.addTo(this.map);
          }
        } else {
          house.polygon.setStyle({ color: '#cccccc', fillOpacity: 0.1, weight: 1 });
        }
      }
    });
  }

  applySearch() {
    this.updateHighlight();
  }
}
