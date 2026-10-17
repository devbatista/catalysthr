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
