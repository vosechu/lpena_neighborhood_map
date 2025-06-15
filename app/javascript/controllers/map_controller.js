import { Controller } from "@hotwired/stimulus"
import { MapRenderer } from "controllers/map_renderer"
import { ModalService } from "controllers/modal_service"

_.templateSettings.interpolate = /{{=([\s\S]+?)}}/g;
_.templateSettings.evaluate = /{{([\s\S]+?)}}/g;

export default class extends Controller {
  static targets = [
    "canvas",
    "searchInput",
    "newResidentsToggle",
    "modal",
    "searchToggle",
    "searchBox"
  ]

  connect() {
    console.log("Map controller connected")

    // Initialize map renderer
    this.mapRenderer = new MapRenderer(this.canvasTarget);

    // Initialize modal service with modal target
    this.modalService = new ModalService(this.modalTarget);

    // Set up modal callbacks
    this.modalService.onResidentSave = (resident, house, formData) => this.saveResident(resident, house, formData);
    this.modalService.onResidentAdd = (house, formData) => this.addNewResident(house, formData);

    // Load and render houses
    this.loadHouses();

    // Set up modal backdrop click handler
    this.modalTarget.addEventListener('click', this._handleModalClick);

    // Set up house click handler
    this.mapRenderer.setHouseClickCallback((house) => this.showHousePopup(house));

    // Escape key handler for modal and popup
    document.addEventListener('keydown', this._handleEscape);

    // Click outside handler for search box
    document.addEventListener('click', this._handleClickOutside);

    // Current user ID (always present – this app requires authentication)
    this.currentUserId = this.element.dataset.mapCurrentUserId;
    if (this.currentUserId) {
      this.currentUserId = parseInt(this.currentUserId, 10);
    }
  }

  disconnect() {
    // Remove event listeners
    document.removeEventListener('keydown', this._handleEscape);
    document.removeEventListener('click', this._handleClickOutside);
    this.modalTarget.removeEventListener('click', this._handleModalClick);
  }

  // Handle modal backdrop click
  _handleModalClick = (e) => {
    if (e.target === this.modalTarget) {
      this.modalService.hide();
    }
  }

  // Handle Escape key for modal and popup
  _handleEscape = (e) => {
    if (e.key === 'Escape') {
      // Check if modal is open first - close modal if visible
      if (this.modalService.isVisible()) {
        this.modalService.hide();
      } else if (!this.searchBoxTarget.classList.contains('hidden') && window.innerWidth < 768) {
        // Close search box on mobile if open (both portrait and landscape)
        this.toggleSearch();
      } else {
        // Only close popup if no modal is open and search is not open
        this.mapRenderer.closePopup();
      }
    }
  }

  // Handle clicks outside the search box
  _handleClickOutside = (e) => {
    // Only handle mobile search box
    if (window.innerWidth >= 768) return;

    // Don't close if clicking the toggle button
    if (this.searchToggleTarget.contains(e.target)) return;

    // Don't close if clicking inside the search box
    if (this.searchBoxTarget.contains(e.target)) return;

    // Close the search box if it's open
    if (!this.searchBoxTarget.classList.contains('hidden')) {
      this.toggleSearch();
    }
  }

  // Load house data and pass to renderer
  async loadHouses() {
    try {
      const response = await fetch("/api/houses");
      const houses = await response.json();
      this.mapRenderer.loadHouses(houses);
    } catch (error) {
      console.error('Error loading houses:', error);
      this.showErrorMessage('Failed to load map data. Please refresh the page.');
    }
  }

  // Show popup for a house
  showHousePopup(house) {
    const content = this.renderHouseAndResidentsDetails(house);
    const popup = this.mapRenderer.showPopupAt(house.latitude, house.longitude, content);

    // Once popup is in the DOM attach listeners immediately (no async timeout)
    const popupEl = popup.getElement();
    if (popupEl) {
      this.bindHousePopupListeners(popupEl, house);
    }
  }

  renderHouseAndResidentsDetails(house) {
    const templateHtml = document.getElementById('house-edit-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    return compiled({ house });
  }

  // Attach edit/add buttons inside popup
  bindHousePopupListeners(popupEl, house) {
    // Edit resident buttons
    popupEl.querySelectorAll('.resident-name .edit-resident-btn').forEach(btn => {
      btn.addEventListener('click', (e) => {
        const residentId = e.currentTarget.dataset.residentId;
        const resident = house.residents.find(r => r.id === parseInt(residentId));
        if (!resident) return;

        this.modalService.showResidentEditModal(resident, house, this.currentUserId);
      });
    });

    // Add resident button
    const addBtn = popupEl.querySelector('.add-resident-btn');
    if (addBtn) {
      addBtn.addEventListener('click', () => {
        this.modalService.showAddResidentModal(house);
      });
    }
  }

  // Save resident (called by modal service)
  saveResident(resident, house, formData) {
    // Normalize homepage URL before saving
    if (formData.homepage) {
      formData.homepage = this.modalService.normalizeHomepageUrl(formData.homepage);
    }

    // Disable save button and show loading state
    const saveBtn = document.querySelector('.save-resident-btn');
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

      // Update house data in map renderer
      this.mapRenderer.updateHouse(house.id, house);

      // Close modal
      this.modalService.hide();

      // Update popup content with new data
      this.mapRenderer.closePopup();
      this.showHousePopup(house);

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

  // Add new resident (called by modal service)
  addNewResident(house, formData) {
    // Add house_id to form data
    formData.house_id = house.id;

    // Normalize homepage URL before saving
    if (formData.homepage) {
      formData.homepage = this.modalService.normalizeHomepageUrl(formData.homepage);
    }

    // Disable save button and show loading state
    const saveBtn = document.querySelector('.add-resident-save-btn');
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

      // Update house data in map renderer
      this.mapRenderer.updateHouse(house.id, house);

      // Close modal
      this.modalService.hide();

      // Update popup content with new data
      this.mapRenderer.closePopup();
      this.showHousePopup(house);

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

  // ============== Search Highlighting =================
  updateHighlight() {
    const query = (this.hasSearchInputTarget ? this.searchInputTarget.value : '').trim();
    const filterNew = this.hasNewResidentsToggleTarget ? this.newResidentsToggleTarget.checked : false;

    this.mapRenderer.updateHighlight(query, filterNew);
  }

  applySearch() {
    this.updateHighlight();
  }

  // Toggle search box visibility on mobile
  toggleSearch() {
    const isLandscape = window.innerWidth > window.innerHeight;
    this.searchBoxTarget.classList.toggle('hidden');

    // Only toggle md:block in portrait mode
    if (!isLandscape) {
      this.searchBoxTarget.classList.toggle('md:block');
    }

    // Focus the search input when showing
    if (!this.searchBoxTarget.classList.contains('hidden')) {
      this.searchInputTarget.focus();
    }
  }

  // Close modal (called by close button)
  closeModal() {
    this.modalService.hide();
  }
}
