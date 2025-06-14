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

    // Current user ID (always present – this app requires authentication)
    this.currentUserId = this.element.dataset.mapCurrentUserId;
    if (this.currentUserId) {
      this.currentUserId = parseInt(this.currentUserId, 10);
    }
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
        this.addHousePopup(house);
      });

      // Attach polygon to house for later styling / searching
      house.polygon = polygon;
      this.houses.push(house);

      // Add to map initially; filtering will toggle later
      polygon.addTo(this.map);

      // Add any status icons to the house
      this.addHouseIcons(house);
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
        // Permission to hide data: only record ownership
        const canHide = (resident.user_id && parseInt(resident.user_id, 10) === this.currentUserId);
        modalEl.innerHTML = _.template(templateHtml)({ resident, canHide });
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
    return compiled({ house });
  }

  attachResidentFormHandlers(resident, house) {
    const modalEl = document.getElementById('modal');

    // ================= Hide field toggles =================
    modalEl.querySelectorAll('.toggle-hide-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const fieldKey = e.currentTarget.dataset.targetField; // e.g. hide_email
        const checkbox = modalEl.querySelector(`input[data-resident-field="${fieldKey}"]`);
        const inputFieldKey = fieldKey.replace('hide_', '');
        const input = modalEl.querySelector(`[data-resident-field="${inputFieldKey}"]`);
        if (!checkbox) return;
        checkbox.checked = !checkbox.checked;
        if (input) {
          input.disabled = checkbox.checked;
          input.classList.toggle('opacity-50', checkbox.checked);
          input.classList.toggle('cursor-not-allowed', checkbox.checked);
        }

        // Swap icons
        const eye = e.currentTarget.querySelector('.icon-eye');
        const eyeSlash = e.currentTarget.querySelector('.icon-eye-slash');
        if (eye && eyeSlash) {
          if (checkbox.checked) {
            eye.style.display = 'none';
            eyeSlash.style.display = 'inline';
          } else {
            eye.style.display = 'inline';
            eyeSlash.style.display = 'none';
          }
        }
      });
    });

    // Hide all information checkbox handler
    const hideAllCheckbox = modalEl.querySelector('#resident-hide-all');
    if (hideAllCheckbox) {
      hideAllCheckbox.addEventListener('change', (e) => {
        const hide = e.target.checked;
        modalEl.querySelectorAll('[data-resident-field]').forEach(el => {
          const fieldName = el.dataset.residentField;
          if (fieldName.startsWith('hide_') || fieldName === 'hidden') return; // skip hide checkboxes themselves & hidden flag
          if (el.type !== 'checkbox') {
            el.disabled = hide;
            el.classList.toggle('opacity-50', hide);
            el.classList.toggle('cursor-not-allowed', hide);
          }
        });
      });
    }

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

    // Birthdate picker enhancement
    this.enhanceBirthdateField(modalEl);

    // Enter key submission
    modalEl.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const saveBtn = modalEl.querySelector('.save-resident-btn');
        if (saveBtn && !saveBtn.disabled) {
          saveBtn.click();
        }
      }
    });

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

    // Birthdate picker enhancement
    this.enhanceBirthdateField(modalEl);

    // Enter key submission
    modalEl.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey) {
        e.preventDefault();
        const saveBtn = modalEl.querySelector('.add-resident-save-btn');
        if (saveBtn && !saveBtn.disabled) {
          saveBtn.click();
        }
      }
    });

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
      if (field.type === 'checkbox') {
        formData[fieldName] = field.checked;
      } else {
        formData[fieldName] = field.value;
      }
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
      if (field.type === 'checkbox') {
        formData[fieldName] = field.checked;
      } else {
        formData[fieldName] = field.value;
      }
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

    enhanceBirthdateField(modalEl) {
    const birthdateField = modalEl.querySelector('#resident-birthdate');
    if (!birthdateField) return;

    // Create a wrapper div for the date picker
    const wrapper = document.createElement('div');
    wrapper.className = 'relative';

    // Insert wrapper before the input field
    birthdateField.parentNode.insertBefore(wrapper, birthdateField);
    wrapper.appendChild(birthdateField);

    // Create a hidden date input for the picker - only cover the icon area
    const dateInput = document.createElement('input');
    dateInput.type = 'date';
    dateInput.className = 'absolute right-0 top-0 w-10 h-full opacity-0 cursor-pointer';
    dateInput.style.zIndex = '2';

    // Set initial value if birthdate exists
    if (birthdateField.value) {
      const mmdd = birthdateField.value;
      const parts = mmdd.split('-');
      if (parts.length === 2) {
        const month = parts[0].padStart(2, '0');
        const day = parts[1].padStart(2, '0');
        // Use current year as placeholder
        const currentYear = new Date().getFullYear();
        dateInput.value = `${currentYear}-${month}-${day}`;
      }
    }

    wrapper.appendChild(dateInput);

    // Add calendar icon
    const calendarIcon = document.createElement('div');
    calendarIcon.className = 'absolute right-3 top-1/2 transform -translate-y-1/2 pointer-events-none text-gray-400';
    calendarIcon.innerHTML = `
      <svg xmlns="http://www.w3.org/2000/svg" class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" />
      </svg>
    `;
    wrapper.appendChild(calendarIcon);

    // Handle date picker changes
    dateInput.addEventListener('change', (e) => {
      const selectedDate = e.target.value;
      if (selectedDate) {
        const date = new Date(selectedDate);
        const month = (date.getMonth() + 1).toString().padStart(2, '0');
        const day = date.getDate().toString().padStart(2, '0');
        birthdateField.value = `${month}-${day}`;

        // Trigger validation
        birthdateField.dispatchEvent(new Event('input', { bubbles: true }));
      }
    });

    // Handle manual text input
    birthdateField.addEventListener('input', (e) => {
      const value = e.target.value;
      const mmddPattern = /^(0[1-9]|1[0-2])-(0[1-9]|[12][0-9]|3[01])$/;

      if (mmddPattern.test(value)) {
        const parts = value.split('-');
        const month = parts[0];
        const day = parts[1];
        const currentYear = new Date().getFullYear();
        dateInput.value = `${currentYear}-${month}-${day}`;
      }
    });

    // Style the text input to accommodate the icon
    birthdateField.style.paddingRight = '2.5rem';
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



  // Add status icons to a house polygon
  addHouseIcons(house) {
    if (!house.polygon) return;

    // Get the center of the polygon for icon placement
    const bounds = house.polygon.getBounds();
    const center = bounds.getCenter();

    // Collect all icons that should be displayed
    const icons = this.getHouseIcons(house);

    if (icons.length === 0) return;

    // Create a container for multiple icons
    const iconContainer = L.divIcon({
      className: 'house-icons-container',
      html: this.renderIconsHtml(icons),
      iconSize: [20, 20],
      iconAnchor: [10, 10]
    });

    // Add the icon marker to the map
    const iconMarker = L.marker(center, { icon: iconContainer }).addTo(this.map);

    // Store reference for cleanup
    house.iconMarker = iconMarker;

    // Make sure icon marker also triggers house popup
    iconMarker.on('click', () => {
      this.addHousePopup(house);
    });
  }

      // Get array of icons that should be displayed for a house
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
}
