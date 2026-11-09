// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "passkeys"
import "template_editor"
import { forgetPush } from "push"

// Forms with data-confirm ask before submitting, for actions that remove access.
document.addEventListener("submit", (event) => {
  const message = event.target.dataset.confirm
  if (message && !window.confirm(message)) event.preventDefault()
})

// Leaving the session clears the app's caches on the device (spec 16, RN-16-061,
// CA-16-008). They hold only the shell, never data, but nothing stays after a sign-out, and
// the push of this browser goes too (D-654).
document.addEventListener("submit", async (event) => {
  const form = event.target
  if (event.defaultPrevented || form.dataset.cachesCleared || !("caches" in window)) return
  if (new URL(form.action, window.location.href).pathname !== "/sign-out") return

  event.preventDefault()
  try {
    await forgetPush(form).catch(() => {})
    await Promise.all((await caches.keys()).map((key) => caches.delete(key)))
  } finally {
    form.dataset.cachesCleared = "true"
    form.requestSubmit()
  }
})

// A form is sent once. A double click, or Enter and then a click, would send it twice, and
// the second request can fail where the first one worked, as with the single-use MFA code.
// The mark clears when the page comes back from the history, and after a while for forms
// that do not leave the page.
document.addEventListener("submit", (event) => {
  const form = event.target
  if (event.defaultPrevented) return
  if (form.dataset.submitting) {
    event.preventDefault()
    return
  }
  form.dataset.submitting = "true"
  setTimeout(() => delete form.dataset.submitting, 10000)
})

window.addEventListener("pageshow", () => {
  document.querySelectorAll("form[data-submitting]").forEach((form) => delete form.dataset.submitting)
})

// The banners on top of the page (impersonate, support entry, read only) push the sidebar
// down: it starts below them and fits the rest of the screen, so its footer stays visible.
const topBanners = document.querySelector("[data-top-banners]")
if (topBanners) {
  const measure = () => document.documentElement.style.setProperty("--top-banners", `${topBanners.offsetHeight}px`)
  new ResizeObserver(measure).observe(topBanners)
  measure()
}

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

// A button with data-copy copies the field it names, as the invoice's PIX code (D-622).
// Without the clipboard, the code is selected for the person to copy.
document.addEventListener("click", async (event) => {
  const button = event.target.closest("[data-copy]")
  const field = button && document.getElementById(button.dataset.copy)
  if (!field) return
  try {
    await navigator.clipboard.writeText(field.value)
    button.textContent = button.dataset.copied
  } catch {
    field.select()
  }
})

// The bell's unread count, fetched every 60 seconds without WebSocket (RN-15-001). A failed
// fetch keeps the last count.
const bell = document.querySelector("[data-bell]")

if (bell) {
  const badge = bell.querySelector("[data-bell-count]")
  const refresh = async () => {
    try {
      const response = await fetch(bell.dataset.bell, { headers: { Accept: "application/json" } })
      if (!response.ok) return
      const { count } = await response.json()
      badge.textContent = count
      badge.classList.toggle("hidden", count === 0)
      bell.setAttribute("aria-label", count === 0 ? bell.dataset.label : bell.dataset.labelUnread.replace("COUNT", count))
    } catch {
      // Offline or signed out: try again on the next round.
    }
  }
  setInterval(refresh, 60_000)
}

// The unit's form: the address by CEP (D-215) and the position on the map, which the HR
// confirms or moves (RN-04-012, D-216). The person's record reuses the CEP lookup, with
// its own field names (data-address-scope). Without JavaScript, the fields are filled by
// hand.
const unitForm = document.querySelector("[data-unit-form]")

if (unitForm) {
  const scope = unitForm.dataset.addressScope || "unit"
  const field = (name) => unitForm.querySelector(`[name="${scope}[${name}]"]`)
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

// The position's CBO, searched in the official table by code or title (RN-04-031).
// Choosing an occupation fills the code; without JavaScript, the code is typed.
document.querySelectorAll("[data-cbo-picker]").forEach((picker) => {
  const query = picker.querySelector("[data-cbo-query]")
  const results = picker.querySelector("[data-cbo-results]")
  const code = picker.querySelector("[data-cbo-code]")
  let timer = null

  const close = () => results.classList.add("hidden")
  const show = (occupations) => {
    results.replaceChildren()
    if (occupations.length === 0) {
      const empty = document.createElement("li")
      empty.className = "px-3 py-2 text-ink-muted"
      empty.textContent = picker.dataset.empty
      results.append(empty)
    }
    occupations.forEach((occupation) => {
      const item = document.createElement("li")
      const button = document.createElement("button")
      button.type = "button"
      button.className = "w-full cursor-pointer px-3 py-2 text-left hover:bg-canvas"
      button.textContent = `${occupation.code} · ${occupation.title}`
      button.addEventListener("click", () => {
        code.value = occupation.code
        query.value = button.textContent
        close()
      })
      item.append(button)
      results.append(item)
    })
    results.classList.remove("hidden")
  }

  query.addEventListener("input", () => {
    clearTimeout(timer)
    if (query.value.trim().length < 2) return close()

    timer = setTimeout(async () => {
      const response = await fetch(`${picker.dataset.url}?q=${encodeURIComponent(query.value.trim())}`, { headers: { Accept: "application/json" } })
      if (response.ok) show(await response.json())
    }, 250)
  })
  query.addEventListener("keydown", (event) => { if (event.key === "Escape") close() })
})

// The portal's upload (RN-08-012, P-08-06): the photos from the rear camera are added one
// at a time, so the front and the back go together, and a large image is made smaller in
// the browser before it leaves, to stay under 10 MB and go fast in 4G. The files are sent
// only on submit; without DataTransfer, the fields send them as they are.
const UPLOAD_MAX_SIDE = 2400
const UPLOAD_KEEP_BELOW = 1.5 * 1024 * 1024

const shrinkImage = async (file) => {
  if (!file.type.startsWith("image/") || (file.type === "image/jpeg" && file.size < UPLOAD_KEEP_BELOW)) return file
  try {
    const bitmap = await createImageBitmap(file, { imageOrientation: "from-image" })
    const scale = Math.min(1, UPLOAD_MAX_SIDE / Math.max(bitmap.width, bitmap.height))
    const canvas = document.createElement("canvas")
    canvas.width = Math.round(bitmap.width * scale)
    canvas.height = Math.round(bitmap.height * scale)
    const context = canvas.getContext("2d")
    context.fillStyle = "#FFFFFF"
    context.fillRect(0, 0, canvas.width, canvas.height)
    context.drawImage(bitmap, 0, 0, canvas.width, canvas.height)
    const blob = await new Promise((resolve) => canvas.toBlob(resolve, "image/jpeg", 0.85))
    if (!blob || blob.size >= file.size) return file
    return new File([ blob ], file.name.replace(/\.[^.]+$/, "") + ".jpg", { type: "image/jpeg" })
  } catch {
    return file
  }
}

const canTransferFiles = () => {
  try {
    return new DataTransfer().items !== undefined
  } catch {
    return false
  }
}

document.querySelectorAll("[data-portal-upload]").forEach((box) => {
  if (!canTransferFiles()) return

  const form = box.closest("form")
  const output = box.querySelector("[data-upload-output]")
  const list = box.querySelector("[data-upload-list]")
  const max = Number(box.dataset.maxFiles || 5)
  let files = []

  const render = () => {
    list.replaceChildren(...files.map((file, index) => {
      const item = document.createElement("li")
      item.className = "flex items-center justify-between gap-3 rounded-lg border border-line-soft bg-white px-3 py-2"
      const name = document.createElement("span")
      name.className = "min-w-0 truncate"
      name.textContent = file.name
      const remove = document.createElement("button")
      remove.type = "button"
      remove.className = "link-button min-h-11 text-sm"
      remove.textContent = list.dataset.removeLabel
      remove.addEventListener("click", () => {
        files.splice(index, 1)
        render()
      })
      item.append(name, remove)
      return item
    }))
  }

  box.querySelectorAll("[data-upload-input]").forEach((input) => {
    input.removeAttribute("name")
    input.addEventListener("change", () => {
      files = files.concat([ ...input.files ])
      if (files.length > max) {
        files = files.slice(0, max)
        window.alert(list.dataset.limitMessage)
      }
      input.value = ""
      render()
    })
  })

  form.addEventListener("submit", async (event) => {
    if (form.dataset.prepared) return
    event.preventDefault()
    const transfer = new DataTransfer()
    for (const file of await Promise.all(files.map(shrinkImage))) transfer.items.add(file)
    output.files = transfer.files
    output.disabled = false
    form.dataset.prepared = "true"
    form.requestSubmit()
  })
})

// The app's shell (spec 16, RN-16-061, RN-16-064, D-424): the service worker keeps only the
// files with a digest and the page without connection. A new version waits until the
// person taps "Atualizar", or opens the app again.
if ("serviceWorker" in navigator && document.querySelector('link[rel="manifest"]')) {
  const banner = document.querySelector("[data-sw-update]")
  const offer = (worker) => {
    if (!banner || !navigator.serviceWorker.controller) return
    banner.hidden = false
    banner.querySelector("[data-sw-update-button]").onclick = () => worker.postMessage("activate")
  }

  navigator.serviceWorker.register("/service-worker.js").then(async (registration) => {
    if (registration.waiting) offer(registration.waiting)
    // After a sign-out the caches are empty: the shell comes back, still without data.
    if (registration.active && "caches" in window && (await caches.keys()).length === 0) registration.active.postMessage("precache")
    registration.addEventListener("updatefound", () => {
      const worker = registration.installing
      worker?.addEventListener("statechange", () => {
        if (worker.state === "installed") offer(worker)
      })
    })
  }).catch(() => {})

  let reloading = false
  navigator.serviceWorker.addEventListener("controllerchange", () => {
    if (reloading) return
    reloading = true
    window.location.reload()
  })
}

// A browser older than the supported ones (D-428, RN-16-080) sees the notice, and the
// pages keep working.
if (!(typeof structuredClone === "function" && window.CSS?.supports?.("selector(:has(*))"))) {
  document.querySelector("[data-old-browser]")?.removeAttribute("hidden")
}

// The invite to install the app on the start (spec 16, RN-16-065, D-427, CA-16-006): from
// the second visit on, never once installed; the browser's "Instalar" on Android and on the
// computer, and the steps on the iPhone, which also free the push. Dismissed, it comes back
// in 30 days. Only these interface choices stay in the browser (RN-16-063).
const installInvite = document.querySelector("[data-install-invite]")
if (installInvite) {
  const store = {
    get: (key) => { try { return window.localStorage.getItem(key) } catch { return null } },
    set: (key, value) => { try { window.localStorage.setItem(key, value) } catch { /* private mode */ } }
  }
  const standalone = window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true
  const dismissedAt = Number(store.get("install_invite.dismissed_at") || 0)
  const seen = store.get("install_invite.seen")
  const show = (variant) => {
    installInvite.querySelector(`[data-install-variant="${variant}"]`).hidden = false
    installInvite.hidden = false
  }

  if (!seen) store.set("install_invite.seen", String(Date.now()))
  const eligible = seen && !standalone && Date.now() - dismissedAt > 30 * 24 * 60 * 60 * 1000
  const iphone = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)

  installInvite.querySelector("[data-install-dismiss]").addEventListener("click", () => {
    store.set("install_invite.dismissed_at", String(Date.now()))
    installInvite.hidden = true
  })

  if (eligible && iphone) show("ios")
  if (eligible && !iphone) {
    window.addEventListener("beforeinstallprompt", (event) => {
      event.preventDefault()
      show("prompt")
      installInvite.querySelector("[data-install-button]").onclick = async () => {
        event.prompt()
        await event.userChoice
        installInvite.hidden = true
      }
    })
  }
  window.addEventListener("appinstalled", () => { installInvite.hidden = true })
}

// The HR panel (spec 17, D-657): each block in its own request, all at once, so a slow
// block never holds the others (RN-17-090, CA-17-012). Each says when its numbers were made;
// the line shows the oldest, and "Atualizar" asks every block again, past the 60 seconds of
// the cache (RN-17-091). A block that fails says so and keeps the others.
const dashboard = document.querySelector("[data-dashboard]")

if (dashboard) {
  const blocks = dashboard.querySelectorAll("[data-dashboard-block]")
  const updated = dashboard.querySelector("[data-dashboard-updated]")
  let generatedAt = []

  const showUpdated = () => {
    if (generatedAt.length === 0) return
    const seconds = Math.max(0, Math.round(Date.now() / 1000 - Math.min(...generatedAt)))
    if (seconds < 5) updated.textContent = dashboard.dataset.updatedNow
    else if (seconds < 120) updated.textContent = dashboard.dataset.updatedSeconds.replace("COUNT", seconds)
    else updated.textContent = dashboard.dataset.updatedMinutes.replace("COUNT", Math.floor(seconds / 60))
  }

  const loadBlock = async (block, refresh) => {
    const url = new URL(block.dataset.dashboardBlock, window.location.href)
    if (refresh) url.searchParams.set("refresh", "1")
    block.setAttribute("aria-busy", "true")
    try {
      const response = await fetch(url, { headers: { Accept: "text/html" } })
      if (!response.ok) throw new Error(response.status)
      block.innerHTML = await response.text()
      const at = Number(response.headers.get("X-Generated-At"))
      if (at) generatedAt.push(at)
      showUpdated()
    } catch {
      const failed = document.createElement("p")
      failed.className = "card card-body text-sm text-ink-soft"
      failed.textContent = dashboard.dataset.failed
      block.replaceChildren(failed)
    } finally {
      block.removeAttribute("aria-busy")
    }
  }

  const loadAll = (refresh) => {
    generatedAt = []
    blocks.forEach((block) => loadBlock(block, refresh))
  }

  dashboard.querySelector("[data-dashboard-refresh]").addEventListener("click", () => loadAll(true))
  loadAll(false)
  setInterval(showUpdated, 5_000)
}

// The portal opened as the installed app (spec 17, RN-17-041, D-657): the server keeps only
// the date, for the partner's adoption figures. Once a day per device; the day stays in the
// browser, never anything about the person (RN-16-063).
const appOpened = document.querySelector("[data-app-opened]")
if (appOpened && (window.matchMedia("(display-mode: standalone)").matches || window.navigator.standalone === true)) {
  const today = new Date().toISOString().slice(0, 10)
  let last = null
  try { last = window.localStorage.getItem("app_opened.day") } catch { /* private mode */ }
  if (last !== today) {
    fetch(appOpened.dataset.appOpened, {
      method: "POST",
      headers: { "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || "" }
    }).then((response) => {
      if (response.ok) try { window.localStorage.setItem("app_opened.day", today) } catch { /* private mode */ }
    }).catch(() => { /* offline: tries again on the next opening */ })
  }
}
