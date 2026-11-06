// The push of the notices (spec 15, RN-15-003, RN-15-004, D-654): the subscription of this
// browser, the invite on the portal's start and the card in "Minhas notificações". The
// browser's request only comes from a button, after the text that explains it (RN-16-066).
const key = document.querySelector('meta[name="push-public-key"]')
const supported = "serviceWorker" in navigator && "PushManager" in window && "Notification" in window

const send = (method, body) => fetch("/push-subscriptions", {
  method,
  credentials: "same-origin",
  headers: { "Content-Type": "application/json", "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content },
  body: JSON.stringify(body)
})

const bytes = (base64url) => Uint8Array.from(atob(base64url.replaceAll("-", "+").replaceAll("_", "/")), (char) => char.charCodeAt(0))

const current = async () => {
  const registration = await navigator.serviceWorker.getRegistration("/")
  return registration ? registration.pushManager.getSubscription() : null
}

const activate = async () => {
  if ((await Notification.requestPermission()) !== "granted") return false

  const { pushManager } = await navigator.serviceWorker.ready
  await (await pushManager.getSubscription())?.unsubscribe()
  const subscription = await pushManager.subscribe({ userVisibleOnly: true, applicationServerKey: bytes(key.content) })
  const response = await send("POST", subscription.toJSON())
  if (response.ok) return true

  await subscription.unsubscribe()
  return false
}

const deactivate = async () => {
  const subscription = await current()
  if (!subscription) return

  await send("DELETE", { endpoint: subscription.endpoint })
  await subscription.unsubscribe()
}

// Clicking Sair takes this browser's subscription away, here and in the server, so a shared
// device stops getting the person's notices (D-654). A session that only expires keeps it.
export const forgetPush = async (form) => {
  if (!supported) return

  const subscription = await current()
  if (!subscription) return

  const field = document.createElement("input")
  field.type = "hidden"
  field.name = "push_endpoint"
  field.value = subscription.endpoint
  form.append(field)
  await subscription.unsubscribe()
}

if (key && supported && key.dataset.sync === "true" && Notification.permission === "granted") {
  current().then((subscription) => { if (subscription) send("POST", subscription.toJSON()) }).catch(() => {})
}

// The invite on the start: one invite at a time, so it gives way to the install invite while
// that one shows. Only these interface choices stay in the browser (RN-16-063).
const invite = document.querySelector("[data-push-invite]")
if (invite && key && supported) {
  const store = {
    get: (name) => { try { return window.localStorage.getItem(name) } catch { return null } },
    set: (name, value) => { try { window.localStorage.setItem(name, value) } catch { /* private mode */ } }
  }
  const seen = store.get("push_invite.seen")
  const dismissedAt = Number(store.get("push_invite.dismissed_at") || 0)
  if (!seen) store.set("push_invite.seen", String(Date.now()))

  if (seen && Notification.permission === "default" && Date.now() - dismissedAt > 30 * 24 * 60 * 60 * 1000) {
    current().then((subscription) => {
      if (subscription) return

      const installInvite = document.querySelector("[data-install-invite]")
      const place = () => { invite.hidden = Boolean(installInvite && !installInvite.hidden) }
      if (installInvite) new MutationObserver(place).observe(installInvite, { attributes: true, attributeFilter: [ "hidden" ] })
      place()
    }).catch(() => {})
  }

  invite.querySelector("[data-push-invite-enable]").addEventListener("click", async () => {
    try {
      await activate()
    } finally {
      invite.remove()
    }
  })
  invite.querySelector("[data-push-invite-dismiss]").addEventListener("click", () => {
    store.set("push_invite.dismissed_at", String(Date.now()))
    invite.remove()
  })
}

// The card in "Minhas notificações": the state of this device. The iPhone only offers push
// to the app installed on the home screen.
const device = document.querySelector("[data-push-device]")
if (device) {
  const error = device.querySelector("[data-push-error]")
  const show = (state) => {
    device.querySelectorAll("[data-push-state]").forEach((element) => { element.hidden = element.dataset.pushState !== state })
  }
  const refresh = async () => {
    if (!supported) {
      const iphone = /iPhone|iPad|iPod/.test(navigator.userAgent) || (navigator.platform === "MacIntel" && navigator.maxTouchPoints > 1)
      return show(iphone ? "ios" : "unsupported")
    }
    if (Notification.permission === "denied") return show("denied")
    show((await current().catch(() => null)) ? "on" : "off")
  }
  const act = async (action) => {
    error.hidden = true
    try {
      const done = await action()
      if (done === false && Notification.permission !== "denied") error.hidden = false
    } catch {
      error.hidden = false
    }
    await refresh()
  }

  device.querySelector("[data-push-enable]").addEventListener("click", () => act(activate))
  device.querySelector("[data-push-disable]").addEventListener("click", () => act(deactivate))
  refresh()
}
