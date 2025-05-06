import { Controller } from "@hotwired/stimulus"

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
        const geometry = house.boundary_geometry;
        if (geometry && geometry.rings && geometry.rings[0]) {
          const latlngs = geometry.rings[0].map(fromWebMercator);
          const polygon = L.polygon(latlngs, {
            color: "#3388ff",
            weight: 1,
            fillOpacity: 0.3
          }).addTo(this.map);

          // Owners list
          let owners = (house.residents || []).map(resident => resident.display_name || resident.official_name).filter(Boolean);
          let ownersHtml = owners.length > 0 ? `<ul>${owners.map(o => `<li>${o}</li>`).join('')}</ul>` : 'None';

          polygon.bindPopup(`
            <strong>${house.street_number} ${house.street_name}</strong><br>
            ${house.city}, ${house.state} ${house.zip || ''}<br>
            <b>Owners:</b> ${ownersHtml}
          `);
        }
      })
    })
  }
}
