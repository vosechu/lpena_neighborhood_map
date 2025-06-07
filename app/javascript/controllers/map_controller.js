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
          const modalEl = document.getElementById('modal');
          const houseTemplateHtml = document.getElementById('house-edit-modal-template').innerHTML;
          const compiledHouse = _.template(houseTemplateHtml);
          modalEl.innerHTML = compiledHouse({ house });
          modalEl.style.display = 'block';

          // Attach save handler after content injection
          const saveHouseBtn = modalEl.querySelector('.save-house-btn');
          saveHouseBtn.addEventListener('click', () => {
            const houseId = saveHouseBtn.dataset.houseId;

            // Gather updated values
            const updatedHouse = {
              street_number: modalEl.querySelector('[data-house-field="street_number"]').value,
              street_name: modalEl.querySelector('[data-house-field="street_name"]').value,
              city: modalEl.querySelector('[data-house-field="city"]').value,
              state: modalEl.querySelector('[data-house-field="state"]').value,
              zip: modalEl.querySelector('[data-house-field="zip"]').value,
            };

            fetch(`/api/houses/${houseId}`, {
              method: 'PATCH',
              headers: {
                'Content-Type': 'application/json',
                'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
              },
              body: JSON.stringify({ house: updatedHouse })
            })
              .then(res => {
                if (!res.ok) { throw new Error('Failed to update house'); }
                return res.json();
              })
              .then(updated => {
                // Update local house object and re-render popup
                Object.assign(house, updated);
                modalEl.style.display = 'none';
                // Re-render popup content
                this.addHousePopup(house);
              })
              .catch(err => {
                console.error(err);
                alert('There was an error saving the house details.');
              });
          });
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

            const saveResidentBtn = modalEl.querySelector('.save-resident-btn');
            saveResidentBtn.addEventListener('click', () => {
              const residentId = saveResidentBtn.dataset.residentId;

              // Collect updated values
              const updatedResident = {
                display_name: modalEl.querySelector('[data-resident-field="display_name"]').value,
                phone: modalEl.querySelector('[data-resident-field="phone"]').value,
                email: modalEl.querySelector('[data-resident-field="email"]').value,
                homepage: modalEl.querySelector('[data-resident-field="homepage"]').value,
                birthdate: modalEl.querySelector('[data-resident-field="birthdate"]').value,
                skills: modalEl.querySelector('[data-resident-field="skills"]').value,
                comments: modalEl.querySelector('[data-resident-field="comments"]').value,
              };

              fetch(`/api/residents/${residentId}`, {
                method: 'PATCH',
                headers: {
                  'Content-Type': 'application/json',
                  'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').getAttribute('content')
                },
                body: JSON.stringify({ resident: updatedResident })
              })
                .then(res => {
                  if (!res.ok) { throw new Error('Failed to update resident'); }
                  return res.json();
                })
                .then(updated => {
                  // Replace resident in house.residents array
                  const index = house.residents.findIndex(r => r.id === updated.id);
                  if (index !== -1) {
                    house.residents[index] = updated;
                  }
                  modalEl.style.display = 'none';
                  // Re-render popup content to reflect changes
                  this.addHousePopup(house);
                })
                .catch(err => {
                  console.error(err);
                  alert('There was an error saving the resident details.');
                });
            });
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
}
