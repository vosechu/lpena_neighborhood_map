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
      data.features.forEach((feature) => {
        const propertyGeometry = feature.geometry
        const propertyDetails = feature.attributes

        if (propertyGeometry && propertyGeometry.rings) {
          const latlngs = propertyGeometry.rings[0].map(fromWebMercator)

          const polygon = L.polygon(latlngs, {
            color: "#3388ff",
            weight: 1,
            fillOpacity: 0.3
          }).addTo(this.map)

          const getOwnerList = (details) => {
            const owners = [
              details.OWNER1_PU,
              details.OWNER2_PU,
              details.OWNER3_PU
            ].filter(owner => owner && owner !== "N/A") // Remove null/undefined and N/A values

            return owners.map(owner =>
              `<li>${owner.replace(/<[^>]*>/g, '')}</li>`
            ).join('')
          }

          polygon.bindPopup(`
              <strong>${propertyDetails.SITE_ADDR}</strong><br>
              Owner name(s):
              <ul>${getOwnerList(propertyDetails)}</ul>
            `)
          }
        })
      })
    }
  }
