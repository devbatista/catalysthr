// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails

// Forms with data-confirm ask before submitting, for actions that remove access.
document.addEventListener("submit", (event) => {
  const message = event.target.dataset.confirm
  if (message && !window.confirm(message)) event.preventDefault()
})

// On small screens the sidebar opens as a drawer (D-597).
const setSidebarOpen = (shell, open) => {
  shell.dataset.sidebarOpen = open
  shell.querySelectorAll("button[aria-expanded][data-sidebar-toggle]").forEach((button) => button.setAttribute("aria-expanded", open))
}

document.addEventListener("click", (event) => {
  const toggle = event.target.closest("[data-sidebar-toggle]")
  const shell = toggle?.closest("[data-shell]")
  if (shell) setSidebarOpen(shell, shell.dataset.sidebarOpen !== "true")
})

document.addEventListener("keydown", (event) => {
  const shell = document.querySelector("[data-shell][data-sidebar-open='true']")
  if (event.key === "Escape" && shell) setSidebarOpen(shell, false)
})

// The unit's form: the address by CEP (D-215) and the position on the map, which the HR
// confirms or moves (RN-04-012, D-216). Without JavaScript, the fields are filled by hand.
const unitForm = document.querySelector("[data-unit-form]")

if (unitForm) {
  const field = (name) => unitForm.elements[`unit[${name}]`]
  const setStatus = (selector, text) => { unitForm.querySelector(selector).textContent = text }

  unitForm.querySelector("[data-postal-code-lookup]")?.addEventListener("click", async (event) => {
    const button = event.currentTarget
    const code = field("postal_code").value.replace(/\D/g, "")
    if (code.length !== 8) return setStatus("[data-lookup-status]", button.dataset.invalid)

    const response = await fetch(button.dataset.url.replace("CEP", code), { headers: { Accept: "application/json" } })
    if (!response.ok) return setStatus("[data-lookup-status]", button.dataset.notFound)

    const address = await response.json()
    unitForm.querySelectorAll("[data-address-field]").forEach((input) => {
      const value = address[input.dataset.addressField]
      if (value) input.value = value
    })
    setStatus("[data-lookup-status]", "")
  })

  const mapElement = unitForm.querySelector("[data-unit-map]")
  if (mapElement) {
    import("leaflet").then((L) => {
      const latitude = field("latitude")
      const longitude = field("longitude")
      const brazil = [-14.235, -51.925]
      const position = () => latitude.value && longitude.value ? [Number(latitude.value), Number(longitude.value)] : null

      const map = L.map(mapElement).setView(position() || brazil, position() ? 17 : 4)
      L.tileLayer("https://tile.openstreetmap.org/{z}/{x}/{y}.png", {
        maxZoom: 19, attribution: "&copy; OpenStreetMap"
      }).addTo(map)

      const icon = L.divIcon({ className: "", html: '<span class="block size-5 rounded-full border-2 border-white bg-brand-primary shadow"></span>', iconSize: [20, 20], iconAnchor: [10, 10] })
      let marker = null
      const place = ([lat, lng], zoom) => {
        latitude.value = lat.toFixed(6)
        longitude.value = lng.toFixed(6)
        if (marker) marker.setLatLng([lat, lng])
        else {
          marker = L.marker([lat, lng], { draggable: true, icon }).addTo(map)
          marker.on("dragend", () => place([marker.getLatLng().lat, marker.getLatLng().lng]))
        }
        if (zoom) map.setView([lat, lng], zoom)
      }
      if (position()) place(position())

      // Without an address found, the HR marks the spot directly on the map (D-216).
      map.on("click", (event) => place([event.latlng.lat, event.latlng.lng]))
      ;[latitude, longitude].forEach((input) => input.addEventListener("change", () => position() && place(position(), 17)))

      unitForm.querySelector("[data-geocode]").addEventListener("click", async (event) => {
        const button = event.currentTarget
        setStatus("[data-geocode-status]", mapElement.dataset.searching)
        const params = new URLSearchParams({
          street: field("street").value, number: field("street_number").value, city: field("city").value,
          state: field("state").value, postal_code: field("postal_code").value
        })
        const response = await fetch(`${button.dataset.url}?${params}`, { headers: { Accept: "application/json" } })
        if (!response.ok) return setStatus("[data-geocode-status]", mapElement.dataset.notFound)

        const found = await response.json()
        place([Number(found.latitude), Number(found.longitude)], 17)
        setStatus("[data-geocode-status]", mapElement.dataset.found)
      })
    })
  }
}
