// The browser's half of the passkeys (spec 16, section 4.8, D-425): registering, signing in by
// the button and by the autofill, and confirming before sensitive data. Without support,
// everything here stays hidden and the password does the work (RN-16-080). The formats of
// the WebAuthn fields are converted by hand: the browser's own converters are newer than
// the oldest browser supported (D-428).
const supported = Boolean(window.PublicKeyCredential && navigator.credentials)

const toBuffer = (text) => {
  const base64 = text.replace(/-/g, "+").replace(/_/g, "/")
  return Uint8Array.from(atob(base64.padEnd(Math.ceil(base64.length / 4) * 4, "=")), (char) => char.charCodeAt(0)).buffer
}

const toText = (buffer) => {
  if (!buffer) return null
  return btoa(String.fromCharCode(...new Uint8Array(buffer))).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "")
}

const descriptors = (list) => (list || []).map((item) => ({ ...item, id: toBuffer(item.id) }))

const creationOptions = (options) => ({
  ...options,
  challenge: toBuffer(options.challenge),
  user: { ...options.user, id: toBuffer(options.user.id) },
  excludeCredentials: descriptors(options.excludeCredentials)
})

const requestOptions = (options) => ({
  ...options,
  challenge: toBuffer(options.challenge),
  allowCredentials: descriptors(options.allowCredentials)
})

const baseCredential = (credential) => ({
  type: credential.type,
  id: credential.id,
  rawId: toText(credential.rawId),
  authenticatorAttachment: credential.authenticatorAttachment,
  clientExtensionResults: credential.getClientExtensionResults()
})

const createdCredential = (credential) => ({
  ...baseCredential(credential),
  response: {
    clientDataJSON: toText(credential.response.clientDataJSON),
    attestationObject: toText(credential.response.attestationObject),
    transports: credential.response.getTransports?.() || []
  }
})

const usedCredential = (credential) => ({
  ...baseCredential(credential),
  response: {
    clientDataJSON: toText(credential.response.clientDataJSON),
    authenticatorData: toText(credential.response.authenticatorData),
    signature: toText(credential.response.signature),
    userHandle: toText(credential.response.userHandle)
  }
})

const send = async (url, body = {}) => {
  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Accept: "application/json",
      "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
    },
    body: JSON.stringify(body)
  })
  // A session that ended answers with the sign-in page, and it opens.
  if (response.redirected) {
    window.location.assign(response.url)
    return null
  }
  const answer = await response.json().catch(() => ({}))
  if (!response.ok) throw new Error(answer.error || "")
  return answer
}

// The new page. A redirect to the same page with an anchor would only scroll, and show the
// old list.
const open = (path) => {
  const target = new URL(path, window.location.href)
  const samePage = target.pathname === window.location.pathname
  window.location.assign(target)
  if (samePage) window.location.reload()
}

const say = (box, text) => {
  const message = box.querySelector("[data-passkey-message]")
  message.textContent = text
  message.hidden = !text
}

// The person closed the device's window, or the page aborted it: not an error to show.
const quiet = (error) => error.name === "NotAllowedError" || error.name === "AbortError"

const explain = (box, error) => {
  if (!quiet(error)) say(box, error.message || box.dataset.failure)
}

// The sign-in: the autofill waits while the page is open, and the button takes its place.
const signInBox = document.querySelector("[data-passkey-sign-in]")
if (signInBox && supported) {
  signInBox.hidden = false
  let autofill = null

  const finish = async (credential) => {
    const answer = await send(signInBox.dataset.url, { credential: usedCredential(credential) })
    if (answer) open(answer.redirect_to)
  }

  const askDevice = async (conditional) => {
    const options = await send(signInBox.dataset.challengeUrl)
    if (!options) return
    autofill = conditional ? new AbortController() : null
    const credential = await navigator.credentials.get({
      publicKey: requestOptions(options),
      ...(conditional ? { mediation: "conditional", signal: autofill.signal } : {})
    })
    await finish(credential)
  }

  const armAutofill = async () => {
    if (!(await PublicKeyCredential.isConditionalMediationAvailable?.())) return
    try {
      await askDevice(true)
    } catch (error) {
      explain(signInBox, error)
    }
  }

  signInBox.querySelector("[data-passkey-button]").addEventListener("click", async () => {
    say(signInBox, "")
    autofill?.abort()
    try {
      await askDevice(false)
    } catch (error) {
      explain(signInBox, error)
      armAutofill()
    }
  })

  armAutofill()
}

// Registering, in Segurança: the password first (RN-16-070), then the device.
const registerBox = document.querySelector("[data-passkey-register]")
if (registerBox) {
  const form = registerBox.querySelector("form")
  if (supported) form.hidden = false
  else registerBox.querySelector("[data-passkey-unsupported]").hidden = false

  form.addEventListener("submit", async (event) => {
    event.preventDefault()
    say(registerBox, "")
    const submit = form.querySelector('[type="submit"]')
    submit.disabled = true
    try {
      const options = await send(registerBox.dataset.challengeUrl, {
        nickname: form.elements.nickname.value,
        current_password: form.elements.current_password.value
      })
      if (!options) return
      const credential = await navigator.credentials.create({ publicKey: creationOptions(options) })
      const answer = await send(registerBox.dataset.url, { credential: createdCredential(credential) })
      if (answer) open(answer.redirect_to)
    } catch (error) {
      explain(registerBox, error)
    } finally {
      submit.disabled = false
    }
  })
}

// Confirming before sensitive data (RN-16-073).
const confirmBox = document.querySelector("[data-passkey-confirm]")
if (confirmBox && supported) {
  confirmBox.hidden = false
  confirmBox.querySelector("[data-passkey-button]").addEventListener("click", async () => {
    say(confirmBox, "")
    try {
      const options = await send(confirmBox.dataset.challengeUrl)
      if (!options) return
      const credential = await navigator.credentials.get({ publicKey: requestOptions(options) })
      const answer = await send(confirmBox.dataset.url, { credential: usedCredential(credential), return_to: confirmBox.dataset.returnTo })
      if (answer) open(answer.redirect_to)
    } catch (error) {
      explain(confirmBox, error)
    }
  })
}

// The invite on the start (RN-16-022, D-647): only on a device with fingerprint or face, and
// one invite at a time, so it gives way to the install invite while that one shows.
// Dismissed, it comes back in 30 days. Only this choice stays in the browser (RN-16-063).
const invite = document.querySelector("[data-passkey-invite]")
if (invite && supported) {
  const store = {
    get: (key) => { try { return window.localStorage.getItem(key) } catch { return null } },
    set: (key, value) => { try { window.localStorage.setItem(key, value) } catch { /* private mode */ } }
  }
  const dismissed = Date.now() - Number(store.get("passkey_invite.dismissed_at") || 0) < 30 * 24 * 60 * 60 * 1000

  if (!dismissed) {
    PublicKeyCredential.isUserVerifyingPlatformAuthenticatorAvailable().then((available) => {
      if (!available) return
      const installInvite = document.querySelector("[data-install-invite]")
      const place = () => { invite.hidden = Boolean(installInvite && !installInvite.hidden) }
      if (installInvite) new MutationObserver(place).observe(installInvite, { attributes: true, attributeFilter: [ "hidden" ] })
      place()
    }).catch(() => {})
  }

  invite.querySelector("[data-passkey-invite-dismiss]").addEventListener("click", () => {
    store.set("passkey_invite.dismissed_at", String(Date.now()))
    invite.remove()
  })
}
