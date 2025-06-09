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
  connect() {
    console.log("Map controller connected")

    this.map = L.map(this.element).setView([27.77441168140785, -82.72030234336854], 17)
    window.map = this.map

    L.tileLayer("https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png", {
      attribution: "&copy; OpenStreetMap contributors"
    }).addTo(map)

    fetch("/api/houses")
      .then(res => res.json())
      .then(data => {
        data.forEach((house) => {
          this.addHousePolygon(house);
        })
      })

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
    }
  }

  addHousePopup(house) {
    // Render the house details with resident details and edit buttons in a leaflet popup
    const popup = L.popup({
      closeOnClick: false,
      keepInView: true,
      autoPan: true
    }).setLatLng([house.latitude, house.longitude]).setContent(this.renderHouseAndResidentsDetails(house));
    // Add event listeners after the popup content is added to the DOM
    setTimeout(() => {
      // Handle house edit buttons (all, in case there are multiple)
      const editHouseBtns = document.querySelectorAll('.house-name .edit-house-btn');
      editHouseBtns.forEach(btn => {
        btn.addEventListener('click', () => {
          // Show a placeholder modal for house editing
          const modalEl = document.getElementById('modal');
          modalEl.innerHTML = `
            <div class="p-6">
              <h3 class="text-lg font-semibold mb-4">Edit House Details</h3>
              <p class="text-gray-600">(House editing form coming soon!)</p>
              <div class="mt-6 flex justify-end">
                <button class="close-modal-btn bg-gray-200 hover:bg-gray-300 text-gray-800 font-semibold py-2 px-4 rounded" onclick="document.getElementById('modal').style.display='none'">Close</button>
              </div>
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
            const modalEl = document.getElementById('modal');
            const templateHtml = document.getElementById('resident-edit-form-template').innerHTML;
            const compiled = _.template(templateHtml);
            modalEl.innerHTML = compiled({ resident });
            modalEl.style.display = 'block';

            // Add save button handler after modal content is set
            this.attachResidentFormHandlers(resident, house);
          }
        });
      });

      // Handle add resident button
      const addResidentBtn = document.querySelector('.add-resident-btn');
      if (addResidentBtn) {
        addResidentBtn.addEventListener('click', () => {
          // TODO: Implement add resident form template and handler
        });
      }
    }, 0);
    popup.openOn(this.map);
  }

  renderHouseAndResidentsDetails(house) {
    const templateHtml = document.getElementById('house-edit-form-template').innerHTML;
    const compiled = _.template(templateHtml);
    return compiled({ house });
  }

  attachResidentFormHandlers(resident, house) {
    // Wait for next tick to ensure DOM is ready
    setTimeout(() => {
      const saveBtn = document.querySelector('.save-resident-btn');
      if (saveBtn) {
        saveBtn.addEventListener('click', (e) => {
          e.preventDefault();
          this.saveResident(resident, house);
        });
      }

      // Add homepage URL normalization
      const homepageField = document.querySelector('#resident-homepage');
      if (homepageField) {
        homepageField.addEventListener('blur', (e) => {
          this.normalizeHomepageUrl(e.target);
        });
      }

      // Add cancel/close handlers
      const modalEl = document.getElementById('modal');
      if (modalEl) {
        // Close on background click
        modalEl.addEventListener('click', (e) => {
          if (e.target === modalEl) {
            modalEl.style.display = 'none';
          }
        });
      }
    }, 0);
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
}
