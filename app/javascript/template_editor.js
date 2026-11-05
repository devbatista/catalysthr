// The toolbar of the contracts' editor (spec 07, RN-07-041, D-648): it only writes the
// simple markup in the text; the text can always be typed.
const replaceSelection = (area, text, start = area.selectionStart, end = area.selectionEnd) => {
  area.setRangeText(text, start, end, "end")
  area.focus()
}

const wrap = (area, mark) => {
  const selected = area.value.slice(area.selectionStart, area.selectionEnd)
  replaceSelection(area, `${mark}${selected}${mark}`)
}

const prefixLine = (area, prefix) => {
  const start = area.value.lastIndexOf("\n", area.selectionStart - 1) + 1
  replaceSelection(area, prefix, start, start)
}

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-wrap], [data-line-prefix], [data-insert]")
  const area = button?.closest("[data-template-editor]")?.querySelector("[data-template-body]")
  if (!area) return

  if (button.dataset.wrap) wrap(area, button.dataset.wrap)
  else if (button.dataset.linePrefix) prefixLine(area, button.dataset.linePrefix)
  else replaceSelection(area, button.dataset.insert)
})

document.addEventListener("change", (event) => {
  const select = event.target.closest("[data-variable]")
  const area = select?.closest("[data-template-editor]")?.querySelector("[data-template-body]")
  if (!area || !select.value) return

  replaceSelection(area, `{{${select.value}}}`)
  select.value = ""
})

// A page waiting for something generated in the background reloads by itself.
const waiting = document.querySelector("[data-reload-after]")
if (waiting) setTimeout(() => window.location.reload(), Number(waiting.dataset.reloadAfter))
