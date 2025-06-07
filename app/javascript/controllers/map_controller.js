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
